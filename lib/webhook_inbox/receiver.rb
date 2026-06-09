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
        self._webhook_provider       = provider.to_sym
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
      secret_proc   = self.class._webhook_secret_resolver

      raise "No provider declared. Call receive_from :stripe, secret: -> { ... }" unless provider_name

      adapter = WebhookInbox.provider_for(provider_name)
      secret  = secret_proc.call

      # Read body once, rewind for each subsequent read
      raw_body = request.body.read
      request.body.rewind

      begin
        adapter.verify!(raw_body, request, secret: secret)
      rescue WebhookInbox::SignatureError
        head :unauthorized and return
      end

      event_id   = adapter.event_id(raw_body, request)
      event_type = adapter.event_type(raw_body, request)

      begin
        event = WebhookInbox::Event.create!(
          provider:   provider_name.to_s,
          event_id:   event_id,
          event_type: event_type,
          payload:    raw_body,
          status:     "pending"
        )
      rescue ActiveRecord::RecordNotUnique
        # Duplicate delivery — idempotent 200
        head :ok and return
      end

      WebhookInbox::ProcessJob.set(queue: WebhookInbox.configuration.queue_name)
                              .perform_later(event.id)

      head :ok
    end
  end
end
