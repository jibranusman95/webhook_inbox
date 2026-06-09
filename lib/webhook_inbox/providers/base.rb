# frozen_string_literal: true

module WebhookInbox
  module Providers
    class Base
      # Extract the unique event ID from the raw body and request.
      # @param raw_body [String] the raw request body string
      # @param request  [ActionDispatch::Request]
      # @return [String]
      def event_id(raw_body, request)
        raise NotImplementedError, "#{self.class}#event_id not implemented"
      end

      # Extract the event type string (e.g. "customer.subscription.created").
      # @param raw_body [String]
      # @param request  [ActionDispatch::Request]
      # @return [String]
      def event_type(raw_body, request)
        raise NotImplementedError, "#{self.class}#event_type not implemented"
      end

      # Verify the provider signature. Raise WebhookInbox::SignatureError on failure.
      # @param raw_body [String]
      # @param request  [ActionDispatch::Request]
      # @param secret   [String]
      def verify!(raw_body, request, secret:)
        raise NotImplementedError, "#{self.class}#verify! not implemented"
      end
    end
  end
end
