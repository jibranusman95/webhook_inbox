# frozen_string_literal: true

require "spec_helper"

RSpec.describe WebhookInbox::RSpecHelpers do
  subject(:helper) { Object.new.extend(described_class) }

  describe "#deliver_webhook (Stripe)" do
    let(:secret) { "test_secret" }

    def build_headers(event_type, payload: {}, event_id: nil)
      helper.send(:build_webhook_headers, :stripe, event_type, payload,
                  event_id: event_id, secret: secret)
    end

    it "returns a body and headers hash" do
      result = build_headers("customer.created", payload: { id: "cus_123" })
      expect(result).to have_key(:body)
      expect(result).to have_key(:headers)
    end

    it "includes CONTENT_TYPE application/json" do
      result = build_headers("charge.succeeded")
      expect(result[:headers]["CONTENT_TYPE"]).to eq("application/json")
    end

    it "includes HTTP_STRIPE_SIGNATURE header" do
      result = build_headers("charge.succeeded")
      expect(result[:headers]["HTTP_STRIPE_SIGNATURE"]).to match(/^t=\d+,v1=[a-f0-9]+$/)
    end

    it "embeds the event_type in the body" do
      result = build_headers("invoice.payment_failed")
      body   = JSON.parse(result[:body])
      expect(body["type"]).to eq("invoice.payment_failed")
    end

    it "uses the provided event_id" do
      result = build_headers("charge.succeeded", event_id: "evt_custom_123")
      body   = JSON.parse(result[:body])
      expect(body["id"]).to eq("evt_custom_123")
    end

    it "generates a random event_id when not provided" do
      r1 = build_headers("charge.succeeded")
      r2 = build_headers("charge.succeeded")
      id1 = JSON.parse(r1[:body])["id"]
      id2 = JSON.parse(r2[:body])["id"]
      expect(id1).not_to eq(id2)
    end

    it "produces a signature that passes Stripe verification" do
      result  = build_headers("charge.succeeded", payload: { amount: 500 })
      body    = result[:body]
      sig_hdr = result[:headers]["HTTP_STRIPE_SIGNATURE"]
      parts   = sig_hdr.split(",").filter_map { |p| p.split("=", 2) }.to_h
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{parts['t']}.#{body}")
      expect(ActiveSupport::SecurityUtils.secure_compare(expected, parts["v1"])).to be(true)
    end

    it "raises ArgumentError for an unknown provider" do
      expect {
        helper.send(:build_webhook_headers, :github, "push", {}, event_id: nil, secret: "s")
      }.to raise_error(ArgumentError, /github/)
    end
  end
end
