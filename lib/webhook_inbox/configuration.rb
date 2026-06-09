# frozen_string_literal: true

module WebhookInbox
  class Configuration
    attr_accessor :queue_name, :dashboard_auth

    def initialize
      @queue_name = "webhooks"
      @dashboard_auth = nil
      @handlers = {}
    end

    # Register a handler block for a given provider + event type.
    # Use "*" as event_type to match any event from that provider.
    #
    #   config.on(:stripe, "customer.subscription.created") { |event| ... }
    #   config.on(:stripe, "*") { |event| ... }
    def on(provider, event_type, &block)
      raise ArgumentError, "Handler block required" unless block

      key = handler_key(provider, event_type)
      @handlers[key] ||= []
      @handlers[key] << block
    end

    # Returns all matching handler blocks for [provider, event_type].
    # Includes exact matches and wildcard "*" handlers for the provider.
    def handlers_for(provider, event_type)
      exact    = @handlers[handler_key(provider, event_type)] || []
      wildcard = @handlers[handler_key(provider, "*")] || []
      exact + wildcard
    end

    private

    def handler_key(provider, event_type)
      "#{provider}:#{event_type}"
    end
  end
end
