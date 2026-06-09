# frozen_string_literal: true

require "spec_helper"

RSpec.describe WebhookInbox do
  describe ".configure" do
    after { described_class.configuration = nil }

    it "yields a Configuration object" do
      described_class.configure do |config|
        expect(config).to be_a(WebhookInbox::Configuration)
      end
    end

    it "stores the configuration" do
      described_class.configure { |c| c.queue_name = "critical" }
      expect(described_class.configuration.queue_name).to eq("critical")
    end

    it "initializes a new configuration on first call" do
      described_class.configuration = nil
      described_class.configure {}
      expect(described_class.configuration).to be_a(WebhookInbox::Configuration)
    end

    it "reuses existing configuration on subsequent calls" do
      described_class.configure { |c| c.queue_name = "first" }
      described_class.configure { |c| c.queue_name = "second" }
      expect(described_class.configuration.queue_name).to eq("second")
    end
  end

  describe ".provider_for" do
    it "returns a Stripe provider for :stripe" do
      expect(described_class.provider_for(:stripe)).to be_a(WebhookInbox::Providers::Stripe)
    end

    it "returns a Stripe provider for 'stripe' string" do
      expect(described_class.provider_for("stripe")).to be_a(WebhookInbox::Providers::Stripe)
    end

    it "raises UnknownProviderError for an unregistered provider" do
      expect { described_class.provider_for(:unknown_provider) }
        .to raise_error(WebhookInbox::UnknownProviderError, /unknown_provider/)
    end

    it "includes available provider names in the error message" do
      expect { described_class.provider_for(:github) }
        .to raise_error(WebhookInbox::UnknownProviderError, /stripe/)
    end
  end

  describe "PROVIDERS constant" do
    it "includes :stripe" do
      expect(WebhookInbox::PROVIDERS).to have_key(:stripe)
    end

    it "maps :stripe to the Stripe provider class" do
      expect(WebhookInbox::PROVIDERS[:stripe]).to eq(WebhookInbox::Providers::Stripe)
    end
  end

  describe "VERSION" do
    it "is a semver string" do
      expect(WebhookInbox::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
