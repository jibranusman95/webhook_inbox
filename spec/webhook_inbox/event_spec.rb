# frozen_string_literal: true

require "spec_helper"

RSpec.describe WebhookInbox::Event do
  let(:valid_attrs) do
    {
      provider: "stripe",
      event_id: "evt_test_#{SecureRandom.hex(4)}",
      event_type: "customer.subscription.created",
      payload: JSON.generate({ id: "sub_123" }),
      status: "pending"
    }
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(described_class.new(valid_attrs)).to be_valid
    end

    it "requires provider" do
      event = described_class.new(valid_attrs.merge(provider: nil))
      expect(event).not_to be_valid
      expect(event.errors[:provider]).to be_present
    end

    it "requires event_id" do
      event = described_class.new(valid_attrs.merge(event_id: nil))
      expect(event).not_to be_valid
    end

    it "rejects unknown status values" do
      event = described_class.new(valid_attrs.merge(status: "unknown_status"))
      expect(event).not_to be_valid
      expect(event.errors[:status]).to be_present
    end

    it "accepts all valid statuses" do
      %w[pending processing processed failed].each do |s|
        event = described_class.new(valid_attrs.merge(status: s))
        expect(event).to be_valid, "expected status '#{s}' to be valid"
      end
    end
  end

  describe "DB unique constraint on [provider, event_id]" do
    it "prevents saving two events with the same provider + event_id" do
      described_class.create!(valid_attrs)
      duplicate = described_class.new(valid_attrs.merge(event_type: "other.event"))
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same event_id for different providers" do
      described_class.create!(valid_attrs)
      other = described_class.new(valid_attrs.merge(provider: "shopify"))
      expect { other.save! }.not_to raise_error
    end
  end

  describe "scopes" do
    before do
      %w[pending processing processed failed].each_with_index do |s, i|
        described_class.create!(valid_attrs.merge(event_id: "evt_scope_#{i}", status: s))
      end
    end

    it ".pending returns only pending events" do
      expect(described_class.pending.pluck(:status)).to all(eq("pending"))
    end

    it ".processing returns only processing events" do
      expect(described_class.processing.pluck(:status)).to all(eq("processing"))
    end

    it ".processed returns only processed events" do
      expect(described_class.processed.pluck(:status)).to all(eq("processed"))
    end

    it ".failed returns only failed events" do
      expect(described_class.failed.pluck(:status)).to all(eq("failed"))
    end

    it ".for_provider filters by provider" do
      described_class.create!(valid_attrs.merge(event_id: "evt_shopify_1", provider: "shopify"))
      expect(described_class.for_provider(:stripe).pluck(:provider)).to all(eq("stripe"))
      expect(described_class.for_provider("shopify").pluck(:provider)).to all(eq("shopify"))
    end
  end

  describe "#parsed_payload" do
    it "returns a Hash for valid JSON payload" do
      event = described_class.create!(valid_attrs.merge(payload: '{"id":"sub_123","amount":100}'))
      expect(event.parsed_payload).to eq({ "id" => "sub_123", "amount" => 100 })
    end

    it "returns empty Hash for invalid JSON" do
      event = described_class.new(valid_attrs.merge(payload: "not json"))
      expect(event.parsed_payload).to eq({})
    end

    it "returns the Hash as-is when payload is already a Hash" do
      event = described_class.new
      allow(event).to receive(:payload).and_return({ "key" => "value" })
      expect(event.parsed_payload).to eq({ "key" => "value" })
    end
  end

  describe "#retry!" do
    before { WebhookInbox.configuration = WebhookInbox::Configuration.new }

    it "resets status to pending" do
      event = described_class.create!(valid_attrs.merge(status: "failed", error_message: "boom"))
      event.retry!
      expect(event.reload.status).to eq("pending")
    end

    it "clears error_message" do
      event = described_class.create!(valid_attrs.merge(status: "failed", error_message: "RuntimeError: boom"))
      event.retry!
      expect(event.reload.error_message).to be_nil
    end

    it "enqueues ProcessJob" do
      WebhookInbox.configuration = WebhookInbox::Configuration.new
      event = described_class.create!(valid_attrs.merge(status: "failed"))
      event.retry!
      jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
      expect(jobs.any? { |j| j[:job] == WebhookInbox::ProcessJob && j[:args].first == event.id }).to be(true)
    end
  end
end
