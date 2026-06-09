# frozen_string_literal: true

require "spec_helper"

RSpec.describe WebhookInbox::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "sets queue_name to 'webhooks'" do
      expect(config.queue_name).to eq("webhooks")
    end

    it "sets dashboard_auth to nil" do
      expect(config.dashboard_auth).to be_nil
    end
  end

  describe "#on" do
    it "registers a handler for a provider + event_type" do
      block = proc { |e| e }
      config.on(:stripe, "customer.subscription.created", &block)
      expect(config.handlers_for(:stripe, "customer.subscription.created")).to include(block)
    end

    it "registers multiple handlers for the same event" do
      block1 = proc {}
      block2 = proc {}
      config.on(:stripe, "invoice.payment_failed", &block1)
      config.on(:stripe, "invoice.payment_failed", &block2)
      expect(config.handlers_for(:stripe, "invoice.payment_failed")).to eq([block1, block2])
    end

    it "registers handlers for different events independently" do
      block1 = proc {}
      block2 = proc {}
      config.on(:stripe, "charge.succeeded", &block1)
      config.on(:stripe, "charge.failed", &block2)
      expect(config.handlers_for(:stripe, "charge.succeeded")).to eq([block1])
      expect(config.handlers_for(:stripe, "charge.failed")).to eq([block2])
    end

    it "raises ArgumentError when no block given" do
      expect { config.on(:stripe, "event.type") }.to raise_error(ArgumentError, /block required/i)
    end

    it "accepts string provider names" do
      block = proc {}
      config.on("stripe", "customer.created", &block)
      expect(config.handlers_for("stripe", "customer.created")).to include(block)
    end
  end

  describe "#handlers_for" do
    it "returns empty array when no handlers registered" do
      expect(config.handlers_for(:stripe, "unregistered.event")).to eq([])
    end

    it "includes wildcard handlers alongside exact handlers" do
      exact    = proc {}
      wildcard = proc {}
      config.on(:stripe, "invoice.paid", &exact)
      config.on(:stripe, "*", &wildcard)

      result = config.handlers_for(:stripe, "invoice.paid")
      expect(result).to include(exact)
      expect(result).to include(wildcard)
    end

    it "returns only wildcard handler when no exact match" do
      wildcard = proc {}
      config.on(:stripe, "*", &wildcard)
      expect(config.handlers_for(:stripe, "any.unregistered.event")).to eq([wildcard])
    end

    it "returns exact handlers before wildcard handlers" do
      exact    = proc {}
      wildcard = proc {}
      config.on(:stripe, "*", &wildcard)
      config.on(:stripe, "invoice.paid", &exact)

      result = config.handlers_for(:stripe, "invoice.paid")
      expect(result.index(exact)).to be < result.index(wildcard)
    end

    it "does not mix handlers across providers" do
      stripe_block = proc {}
      config.on(:stripe, "charge.succeeded", &stripe_block)
      expect(config.handlers_for(:shopify, "charge.succeeded")).to eq([])
    end
  end

  describe "queue_name=" do
    it "allows overriding the queue name" do
      config.queue_name = "critical"
      expect(config.queue_name).to eq("critical")
    end
  end

  describe "dashboard_auth=" do
    it "stores the auth lambda" do
      auth = ->(c) { c.admin? }
      config.dashboard_auth = auth
      expect(config.dashboard_auth).to eq(auth)
    end
  end
end
