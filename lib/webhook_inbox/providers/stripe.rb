# frozen_string_literal: true

require "openssl"
require "json"
require "active_support/security_utils"

module WebhookInbox
  module Providers
    class Stripe < Base
      SIG_HEADER = "HTTP_STRIPE_SIGNATURE"

      def event_id(raw_body, _request)
        JSON.parse(raw_body)["id"]
      rescue JSON::ParserError
        nil
      end

      def event_type(raw_body, _request)
        JSON.parse(raw_body)["type"] || "unknown"
      rescue JSON::ParserError
        "unknown"
      end

      # Stripe signature format: "t=<timestamp>,v1=<hmac>,v0=<hmac>"
      # We verify v1 (HMAC-SHA256 of "timestamp.body" signed with the webhook secret).
      # Raises WebhookInbox::SignatureError if invalid.
      def verify!(raw_body, request, secret:)
        sig_header = request.env[SIG_HEADER]
        raise WebhookInbox::SignatureError, "Missing Stripe-Signature header" if sig_header.blank?

        parts = sig_header.split(",").each_with_object({}) do |part, hash|
          k, v = part.split("=", 2)
          hash[k] = v if k && v
        end
        timestamp = parts["t"]
        received  = parts["v1"]

        raise WebhookInbox::SignatureError, "Malformed Stripe-Signature header" unless timestamp && received

        signed_payload = "#{timestamp}.#{raw_body}"
        expected = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)

        return if ActiveSupport::SecurityUtils.secure_compare(expected, received)

        raise WebhookInbox::SignatureError, "Stripe signature verification failed"
      end
    end
  end
end
