# frozen_string_literal: true

require "spec_helper"
require "support/database"
require "support/active_job"
require "action_controller"

# Minimal test doubles
module FakeRails
  def self.logger
    @logger ||= Logger.new(IO::NULL)
  end
end

RSpec.describe WebhookInbox::Receiver do
  let(:secret)     { "test_stripe_secret" }
  let(:timestamp)  { Time.now.to_i.to_s }
  let(:event_id)   { "evt_receiver_test_#{SecureRandom.hex(4)}" }
  let(:event_type) { "customer.subscription.created" }
  let(:payload_hash) do
    { "id" => event_id, "type" => event_type, "data" => {} }
  end
  let(:raw_body) { JSON.generate(payload_hash) }
  let(:signature) { OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{raw_body}") }
  let(:sig_header) { "t=#{timestamp},v1=#{signature}" }

  def build_controller(provider: :stripe, &secret_block)
    secret_block ||= -> { secret }
    klass = Class.new do
      include WebhookInbox::Receiver
      receive_from provider, secret: secret_block

      attr_reader :response_status, :head_called_with

      def head(status)
        @head_called_with = status
        @response_status  = status
      end

      def request
        @request
      end

      def set_request(req)
        @request = req
      end
    end
    klass.new
  end

  def fake_request(body: raw_body, sig: sig_header)
    double("request",
      body: StringIO.new(body),
      env:  { "HTTP_STRIPE_SIGNATURE" => sig }
    )
  end

  before do
    WebhookInbox.configuration = WebhookInbox::Configuration.new
  end

  describe ".receive_from" do
    it "stores provider and secret resolver on the class" do
      klass = Class.new do
        include WebhookInbox::Receiver
        receive_from :stripe, secret: -> { "s3cr3t" }
      end
      expect(klass._webhook_provider).to eq(:stripe)
      expect(klass._webhook_secret_resolver.call).to eq("s3cr3t")
    end
  end

  describe "#receive_webhook!" do
    it "responds 200 for a valid signed request" do
      controller = build_controller
      controller.set_request(fake_request)
      controller.receive_webhook!
      expect(controller.head_called_with).to eq(:ok)
    end

    it "creates a WebhookInbox::Event record" do
      controller = build_controller
      controller.set_request(fake_request)
      expect { controller.receive_webhook! }
        .to change(WebhookInbox::Event, :count).by(1)
    end

    it "stores the correct provider on the event" do
      controller = build_controller
      controller.set_request(fake_request)
      controller.receive_webhook!
      expect(WebhookInbox::Event.last.provider).to eq("stripe")
    end

    it "stores the correct event_id" do
      controller = build_controller
      controller.set_request(fake_request)
      controller.receive_webhook!
      expect(WebhookInbox::Event.last.event_id).to eq(event_id)
    end

    it "stores the correct event_type" do
      controller = build_controller
      controller.set_request(fake_request)
      controller.receive_webhook!
      expect(WebhookInbox::Event.last.event_type).to eq(event_type)
    end

    it "enqueues a ProcessJob" do
      controller = build_controller
      controller.set_request(fake_request)
      expect { controller.receive_webhook! }
        .to have_enqueued_job(WebhookInbox::ProcessJob)
    end

    it "responds 401 for a bad signature" do
      bad_sig = "t=#{timestamp},v1=badhexdeadbeef"
      controller = build_controller
      controller.set_request(fake_request(sig: bad_sig))
      controller.receive_webhook!
      expect(controller.head_called_with).to eq(:unauthorized)
    end

    it "does not create an event on bad signature" do
      bad_sig = "t=#{timestamp},v1=badhexdeadbeef"
      controller = build_controller
      controller.set_request(fake_request(sig: bad_sig))
      expect { controller.receive_webhook! }
        .not_to change(WebhookInbox::Event, :count)
    end

    it "responds 200 silently on duplicate delivery" do
      # First delivery
      controller = build_controller
      controller.set_request(fake_request)
      controller.receive_webhook!

      # Second delivery with same event_id — new request object, same body
      controller2 = build_controller
      controller2.set_request(fake_request)
      expect { controller2.receive_webhook! }
        .not_to change(WebhookInbox::Event, :count)
      expect(controller2.head_called_with).to eq(:ok)
    end

    it "does not enqueue a job on duplicate delivery" do
      controller = build_controller
      controller.set_request(fake_request)
      controller.receive_webhook!
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      controller2 = build_controller
      controller2.set_request(fake_request)
      expect { controller2.receive_webhook! }
        .not_to have_enqueued_job(WebhookInbox::ProcessJob)
    end

    it "rewinds the body before reading, so middleware reads don't break it" do
      io = StringIO.new(raw_body)
      io.read # simulate middleware consuming the body
      req = double("request", body: io, env: { "HTTP_STRIPE_SIGNATURE" => sig_header })
      controller = build_controller
      controller.set_request(req)
      # Because receiver calls rewind, body should still be readable
      controller.receive_webhook!
      expect(controller.head_called_with).to eq(:ok)
    end
  end
end
