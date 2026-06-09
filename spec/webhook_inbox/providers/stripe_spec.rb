# frozen_string_literal: true

require "spec_helper"
require "ostruct"

RSpec.describe WebhookInbox::Providers::Stripe do
  subject(:provider) { described_class.new }

  let(:secret)     { "whsec_test_secret" }
  let(:timestamp)  { Time.now.to_i.to_s }
  let(:event_id)   { "evt_1ABC123" }
  let(:event_type) { "customer.subscription.created" }
  let(:payload_hash) do
    { "id" => event_id, "type" => event_type, "data" => { "object" => {} } }
  end
  let(:raw_body) { JSON.generate(payload_hash) }
  let(:signature) { OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}") }
  let(:sig_header) { "t=#{timestamp},v1=#{signature}" }

  def fake_request(sig: sig_header)
    OpenStruct.new(env: { "HTTP_STRIPE_SIGNATURE" => sig })
  end

  describe "#event_id" do
    it "extracts the id field from the raw body" do
      expect(provider.event_id(raw_body, fake_request)).to eq(event_id)
    end

    it "returns nil for unparseable body" do
      expect(provider.event_id("not json", fake_request)).to be_nil
    end

    it "returns nil when id key is missing" do
      body = JSON.generate({ "type" => "something" })
      expect(provider.event_id(body, fake_request)).to be_nil
    end
  end

  describe "#event_type" do
    it "extracts the type field from the raw body" do
      expect(provider.event_type(raw_body, fake_request)).to eq(event_type)
    end

    it "returns 'unknown' for unparseable body" do
      expect(provider.event_type("not json", fake_request)).to eq("unknown")
    end

    it "returns 'unknown' when type key is missing" do
      body = JSON.generate({ "id" => "evt_123" })
      expect(provider.event_type(body, fake_request)).to eq("unknown")
    end
  end

  describe "#verify!" do
    it "passes verification for a correctly signed payload" do
      expect { provider.verify!(raw_body, fake_request, secret: secret) }.not_to raise_error
    end

    it "raises SignatureError when signature does not match" do
      wrong_sig = "t=#{timestamp},v1=badhexdeadbeef"
      expect { provider.verify!(raw_body, fake_request(sig: wrong_sig), secret: secret) }
        .to raise_error(WebhookInbox::SignatureError)
    end

    it "raises SignatureError when signed with wrong secret" do
      wrong_sig = "t=#{timestamp},v1=#{OpenSSL::HMAC.hexdigest('SHA256', 'wrong_secret', "#{timestamp}.#{raw_body}")}"
      expect { provider.verify!(raw_body, fake_request(sig: wrong_sig), secret: secret) }
        .to raise_error(WebhookInbox::SignatureError)
    end

    it "raises SignatureError when Stripe-Signature header is absent" do
      req = OpenStruct.new(env: {})
      expect { provider.verify!(raw_body, req, secret: secret) }
        .to raise_error(WebhookInbox::SignatureError, /Missing/)
    end

    it "raises SignatureError when header is malformed (no t= or v1=)" do
      req = fake_request(sig: "garbage_header")
      expect { provider.verify!(raw_body, req, secret: secret) }
        .to raise_error(WebhookInbox::SignatureError, /Malformed/)
    end

    it "raises SignatureError when body has been tampered with" do
      tampered = raw_body + "extra"
      expect { provider.verify!(tampered, fake_request, secret: secret) }
        .to raise_error(WebhookInbox::SignatureError)
    end

    it "uses secure_compare to prevent timing attacks" do
      expect(ActiveSupport::SecurityUtils).to receive(:secure_compare).and_call_original
      provider.verify!(raw_body, fake_request, secret: secret)
    end
  end
end
