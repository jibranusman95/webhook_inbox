# frozen_string_literal: true

require "spec_helper"

RSpec.describe WebhookInbox::ProcessJob do
  let(:config) { WebhookInbox::Configuration.new }

  before do
    WebhookInbox.configuration = config
  end

  def create_event(attrs = {})
    WebhookInbox::Event.create!({
      provider: "stripe",
      event_id: "evt_#{SecureRandom.hex(4)}",
      event_type: "invoice.payment_succeeded",
      payload: '{"amount":1000}',
      status: "pending",
      attempts: 0
    }.merge(attrs))
  end

  describe "#perform" do
    context "with a registered handler" do
      it "calls the handler with the event" do
        received = []
        config.on(:stripe, "invoice.payment_succeeded") { |e| received << e }
        event = create_event

        described_class.new.perform(event.id)

        expect(received.length).to eq(1)
        expect(received.first).to eq(event)
      end

      it "marks the event as processed" do
        config.on(:stripe, "invoice.payment_succeeded") { |_e| }
        event = create_event

        described_class.new.perform(event.id)

        expect(event.reload.status).to eq("processed")
      end

      it "sets processed_at timestamp" do
        config.on(:stripe, "invoice.payment_succeeded") { |_e| }
        event = create_event

        described_class.new.perform(event.id)

        expect(event.reload.processed_at).not_to be_nil
      end

      it "increments attempts" do
        config.on(:stripe, "invoice.payment_succeeded") { |_e| }
        event = create_event

        described_class.new.perform(event.id)

        expect(event.reload.attempts).to eq(1)
      end
    end

    context "with multiple handlers" do
      it "calls all registered handlers in order" do
        order = []
        config.on(:stripe, "charge.succeeded") { |_e| order << :first }
        config.on(:stripe, "charge.succeeded") { |_e| order << :second }
        event = create_event(event_type: "charge.succeeded")

        described_class.new.perform(event.id)

        expect(order).to eq(%i[first second])
      end

      it "calls wildcard handler alongside exact handler" do
        called = []
        config.on(:stripe, "charge.succeeded") { |_e| called << :exact }
        config.on(:stripe, "*") { |_e| called << :wildcard }
        event = create_event(event_type: "charge.succeeded")

        described_class.new.perform(event.id)

        expect(called).to include(:exact, :wildcard)
      end
    end

    context "with no registered handler" do
      it "still marks event as processed" do
        event = create_event(event_type: "unregistered.event")
        described_class.new.perform(event.id)
        expect(event.reload.status).to eq("processed")
      end

      it "does not raise" do
        event = create_event(event_type: "unregistered.event")
        expect { described_class.new.perform(event.id) }.not_to raise_error
      end
    end

    context "when handler raises" do
      it "marks event as failed" do
        config.on(:stripe, "invoice.payment_succeeded") { raise "handler exploded" }
        event = create_event

        expect { described_class.new.perform(event.id) }.to raise_error("handler exploded")
        expect(event.reload.status).to eq("failed")
      end

      it "stores error_message" do
        config.on(:stripe, "invoice.payment_succeeded") { raise "handler exploded" }
        event = create_event

        expect { described_class.new.perform(event.id) }.to raise_error(RuntimeError)
        expect(event.reload.error_message).to include("RuntimeError")
        expect(event.reload.error_message).to include("handler exploded")
      end

      it "re-raises so ActiveJob retry_on can handle backoff" do
        config.on(:stripe, "invoice.payment_succeeded") { raise "boom" }
        event = create_event

        expect { described_class.new.perform(event.id) }.to raise_error("boom")
      end
    end

    context "when event does not exist" do
      it "returns without error" do
        expect { described_class.new.perform(99_999) }.not_to raise_error
      end
    end

    context "when event is already processed" do
      it "skips processing" do
        called = false
        config.on(:stripe, "invoice.payment_succeeded") { called = true }
        event = create_event(status: "processed")

        described_class.new.perform(event.id)

        expect(called).to be(false)
      end
    end

    context "when event is already processing" do
      it "skips duplicate processing" do
        called = false
        config.on(:stripe, "invoice.payment_succeeded") { called = true }
        event = create_event(status: "processing")

        described_class.new.perform(event.id)

        expect(called).to be(false)
      end
    end
  end
end
