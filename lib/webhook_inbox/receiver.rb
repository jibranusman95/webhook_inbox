# frozen_string_literal: true

module WebhookInbox
  module Receiver
    extend ActiveSupport::Concern

    included do
      class_attribute :_webhook_provider, instance_accessor: false
      class_attribute :_webhook_secret_resolver, instance_accessor: false
    end

    class_methods do
      # Declare the provider and secret for this controller.
      #
      #   receive_from :stripe, secret: -> { ENV["STRIPE_WEBHOOK_SECRET"] }
      def receive_from(provider, secret:)
        self._webhook_provider = provider.to_sym
        self._webhook_secret_resolver = secret
      end
    end

    # Run the full receive pipeline:
    #   1. Verify provider signature (401 on failure)
    #   2. Store event in DB (200 silent on duplicate)
    #   3. Enqueue ProcessJob
    #   4. Respond 200 OK
    def receive_webhook!
      provider_name = self.class._webhook_provider
      raise "No provider declared. Call receive_from :stripe, secret: -> { ... }" unless provider_name

      adapter  = WebhookInbox.provider_for(provider_name)
      secret   = self.class._webhook_secret_resolver.call
      raw_body = read_request_body

      verify_signature!(adapter, raw_body, secret) || return
      store_and_process(adapter, raw_body, provider_name) || return

      head :ok
    end

    private

    def read_request_body
      request.body.rewind # Rewind first — middleware may have consumed the body
      request.body.read
    end

    def verify_signature!(adapter, raw_body, secret)
      adapter.verify!(raw_body, request, secret: secret)
      true
    rescue WebhookInbox::SignatureError
      head :unauthorized
      false
    end

    def store_and_process(adapter, raw_body, provider_name)
      event = WebhookInbox::Event.create!(
        provider: provider_name.to_s,
        event_id: adapter.event_id(raw_body, request),
        event_type: adapter.event_type(raw_body, request),
        payload: raw_body,
        status: "pending"
      )
      WebhookInbox::ProcessJob.set(queue: WebhookInbox.configuration.queue_name)
                              .perform_later(event.id)
      true
    rescue ActiveRecord::RecordNotUnique
      head :ok # Duplicate delivery — idempotent 200
      false
    end
  end
end
