# frozen_string_literal: true

require "openssl"
require "json"

module WebhookInbox
  module RSpecHelpers
    # Simulate a signed webhook delivery to the given path.
    # Signs the payload using the provider's scheme so signature verification passes.
    #
    # @param provider [Symbol] e.g. :stripe
    # @param event_type [String] e.g. "customer.subscription.created"
    # @param payload [Hash] the event payload (will be JSON-encoded)
    # @param path [String] the route to POST to (default: "/webhooks/#{provider}")
    # @param event_id [String] override the generated event ID
    # @param secret [String] the webhook secret (default: "test_secret")
    def deliver_webhook(provider, event_type, payload: {}, path: nil, event_id: nil, secret: "test_secret")
      path ||= "/webhooks/#{provider}"
      headers = build_webhook_headers(provider, event_type, payload, event_id: event_id, secret: secret)
      post path, params: headers[:body], headers: headers[:headers]
    end

    private

    def build_webhook_headers(provider, event_type, payload, event_id:, secret:)
      case provider.to_sym
      when :stripe
        build_stripe_headers(event_type, payload, event_id: event_id, secret: secret)
      else
        raise ArgumentError, "No RSpec helper for provider: #{provider}"
      end
    end

    def build_stripe_headers(event_type, payload, event_id:, secret:)
      id   = event_id || "evt_test_#{SecureRandom.hex(8)}"
      body = JSON.generate({ id: id, type: event_type, data: payload })
      ts   = Time.now.to_i.to_s
      sig  = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{ts}.#{body}")

      {
        body: body,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "HTTP_STRIPE_SIGNATURE" => "t=#{ts},v1=#{sig}"
        }
      }
    end
  end
end
