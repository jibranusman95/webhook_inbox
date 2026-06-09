# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/module/attribute_accessors"

require_relative "webhook_inbox/version"
require_relative "webhook_inbox/configuration"
require_relative "webhook_inbox/providers/base"
require_relative "webhook_inbox/providers/stripe"

module WebhookInbox
  mattr_accessor :configuration

  class SignatureError < StandardError; end
  class UnknownProviderError < StandardError; end

  PROVIDERS = {
    stripe: WebhookInbox::Providers::Stripe
  }.freeze

  class << self
    def configure
      self.configuration ||= Configuration.new
      yield configuration
    end

    def provider_for(name)
      klass = PROVIDERS[name.to_sym]
      raise UnknownProviderError, "Unknown provider: #{name}. Available: #{PROVIDERS.keys.join(', ')}" unless klass
      klass.new
    end
  end
end

require_relative "webhook_inbox/engine" if defined?(Rails::Engine)
