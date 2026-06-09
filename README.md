# webhook_inbox

**Production-ready transactional inbox for Rails webhooks. Two lines.**

[![CI](https://github.com/jibranusman95/webhook_inbox/actions/workflows/ci.yml/badge.svg)](https://github.com/jibranusman95/webhook_inbox/actions)
[![Gem Version](https://badge.fury.io/rb/webhook_inbox.svg)](https://badge.fury.io/rb/webhook_inbox)
[![Downloads](https://img.shields.io/gem/dt/webhook_inbox)](https://rubygems.org/gems/webhook_inbox)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

> **[Screenshot: /webhook_inbox dashboard — table of Stripe events with green "processed", red "failed", yellow "pending" badges. One row expanded to show full JSON payload and a "Replay" button.]**

---

Every Rails app that accepts webhooks has written this controller:

```ruby
def create
  payload    = request.body.read
  sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
  event      = Stripe::Webhook.construct_event(payload, sig_header, ENV["STRIPE_SECRET"])

  return head :ok if StripeEvent.exists?(stripe_id: event.id)

  StripeEvent.create!(stripe_id: event.id, payload: payload)
  HandleStripeEventJob.perform_later(event.id)
  head :ok
rescue Stripe::SignatureVerificationError
  head :unauthorized
rescue ActiveRecord::RecordNotUnique
  head :ok
end
```

And every Rails app has had a production incident when it broke.

Here's the same thing with webhook_inbox:

```ruby
class StripeWebhooksController < ApplicationController
  include WebhookInbox::Receiver
  receive_from :stripe, secret: -> { ENV["STRIPE_WEBHOOK_SECRET"] }

  def create
    receive_webhook!
  end
end
```

Signature verification, deduplication, async processing, replay, and a dashboard. All included. No Redis, no extra services, no copy-paste.

---

## What you get

**Deduplication** — DB unique constraint on `[provider, event_id]`. Two identical deliveries arriving simultaneously? Both pass the `exists?` check? Doesn't matter. The constraint is enforced at the database level. Duplicates silently return 200.

**Async processing** — events are stored first, then processed via your existing job queue. Stripe gets its 200 immediately. Your handler can take as long as it needs.

**Replay** — any event can be re-run from the dashboard or via `event.retry!`. Debug handlers, recover from bugs, reprocess failed deliveries.

**Dashboard** — `/webhook_inbox` shows every event, its status, full JSON payload, error details, and a replay button. Protected by a configurable auth lambda.

**RSpec helpers** — `deliver_webhook(:stripe, "event.type", payload: {})` posts a correctly-signed request in your tests. No mocking, no fixtures.

---

## Install

```ruby
# Gemfile
gem "webhook_inbox"
```

```bash
bundle install
rails generate webhook_inbox:install
rails db:migrate
```

Mount the dashboard:

```ruby
# config/routes.rb
post "/webhooks/stripe", to: "stripe_webhooks#create"
mount WebhookInbox::Engine => "/webhook_inbox"
```

---

## Configuration

```ruby
# config/initializers/webhook_inbox.rb
WebhookInbox.configure do |config|
  # Register handlers — block receives a WebhookInbox::Event object
  config.on(:stripe, "customer.subscription.created") do |event|
    CreateSubscriptionJob.perform_later(event.parsed_payload)
  end

  config.on(:stripe, "invoice.payment_failed") do |event|
    NotifyPaymentFailedJob.perform_later(event.parsed_payload)
  end

  # Catch-all — runs for every Stripe event with no exact match
  config.on(:stripe, "*") do |event|
    Rails.logger.info "[webhook] Unhandled #{event.event_type}"
  end

  # Queue name (default: "webhooks")
  config.queue_name = "webhooks"

  # Dashboard auth — return truthy to allow access. Required in production.
  config.dashboard_auth = ->(controller) { controller.current_user&.admin? }
end
```

---

## Controller

```ruby
class StripeWebhooksController < ApplicationController
  include WebhookInbox::Receiver
  receive_from :stripe, secret: -> { ENV["STRIPE_WEBHOOK_SECRET"] }

  def create
    receive_webhook!
    # receive_webhook! always responds — nothing needed after it
  end
end
```

`receive_webhook!` runs the full pipeline:

1. Verify Stripe signature → `401` on failure
2. Insert event into DB → silent `200` on duplicate (race-condition-safe)
3. Enqueue `WebhookInbox::ProcessJob`
4. Respond `200 OK`

---

## Working with events

```ruby
# Query
WebhookInbox::Event.pending.count
WebhookInbox::Event.failed.each(&:retry!)
WebhookInbox::Event.for_provider(:stripe).where(event_type: "invoice.payment_failed")

# Event object passed to handlers
event.provider       # => "stripe"
event.event_id       # => "evt_1ABC..."
event.event_type     # => "customer.subscription.created"
event.parsed_payload # => Hash (parsed from stored JSON)
event.attempts       # => 1
event.status         # => "pending" | "processing" | "processed" | "failed"
event.error_message  # => "RuntimeError: handler exploded\n..." (on failure)

# Replay a specific event
WebhookInbox::Event.find_by(event_id: "evt_1ABC...").retry!
```

---

## Processing flow

```
POST /webhooks/stripe
        │
        ▼
  WebhookInbox::Receiver
        │
        ├── 1. Verify signature           (401 on failure)
        ├── 2. INSERT webhook_inbox_events (200 silent on duplicate)
        ├── 3. Enqueue ProcessJob
        └── 4. Respond 200 OK
                │
                ▼ (async, via your queue)
  WebhookInbox::ProcessJob
        │
        ├── 1. Find event, mark: processing
        ├── 2. Look up handlers for [provider, event_type]
        ├── 3. Call each handler block
        ├── 4a. Success → status: processed, processed_at: now
        └── 4b. Failure → status: failed, error_message stored, re-raise for retry
```

---

## RSpec helpers

```ruby
# spec/rails_helper.rb
require "webhook_inbox/rspec"

# In request specs (auto-included)
RSpec.describe "Stripe billing", type: :request do
  it "creates a subscription on webhook" do
    deliver_webhook(:stripe, "customer.subscription.created", payload: {
      data: { object: { id: "sub_123", customer: "cus_456" } }
    })

    perform_enqueued_jobs

    expect(Subscription.find_by(stripe_id: "sub_123")).to be_active
  end

  it "ignores duplicate deliveries" do
    2.times do
      deliver_webhook(:stripe, "customer.subscription.created",
                      event_id: "evt_fixed_id", payload: {})
    end
    expect(WebhookInbox::Event.count).to eq(1)
  end
end
```

`deliver_webhook` signs the request using the same HMAC-SHA256 scheme as Stripe's live webhooks. The signature will pass `receive_webhook!` verification without any mocking. Pass `secret:` to match your test initializer (default: `"test_secret"`).

---

## Dashboard

Mount in `config/routes.rb`:

```ruby
mount WebhookInbox::Engine => "/webhook_inbox"
```

Configure auth in the initializer:

```ruby
config.dashboard_auth = ->(controller) { controller.current_user&.admin? }
```

In development, the dashboard is open when `dashboard_auth` is not set. In production, it blocks with a clear error if auth is not configured.

The dashboard shows:
- All events with status badges (pending / processing / processed / failed)
- Filter by status or provider
- Full JSON payload for each event
- Error message and stack trace on failures
- Replay button — re-enqueues the handler job

---

## Why not stripe_event?

[stripe_event](https://github.com/integrallis/stripe_event) is a great event router — 14.5M downloads. It dispatches to handlers. That's all it does.

It has no storage, no deduplication, no replay, no dashboard. You still write the controller, the dedup migration, the job, and the retry logic.

webhook_inbox handles the layer below: receive, store, deduplicate, process, replay. They're complementary. If you already use stripe_event for routing, webhook_inbox can sit underneath it as the storage and dedup layer.

---

## Database schema

```ruby
create_table :webhook_inbox_events do |t|
  t.string   :provider,      null: false
  t.string   :event_id,      null: false
  t.string   :event_type
  t.text     :payload,       null: false, default: "{}"
  t.string   :status,        null: false, default: "pending"
  t.integer  :attempts,      null: false, default: 0
  t.text     :error_message
  t.datetime :processed_at
  t.timestamps
end

add_index :webhook_inbox_events, [:provider, :event_id], unique: true
add_index :webhook_inbox_events, :status
add_index :webhook_inbox_events, :created_at
```

`payload` is `text` (not `jsonb`) for cross-database compatibility — identical behavior on SQLite, MySQL, and PostgreSQL.

---

## Requirements

- Ruby >= 3.1
- Rails >= 7.0
- ActiveRecord, ActiveJob, ActionController

---

## Contributing

```bash
git clone https://github.com/jibranusman95/webhook_inbox
cd webhook_inbox
bundle install
bundle exec rspec
bundle exec rubocop
```

---

## From the same author

| Gem | What it does |
|-----|-------------|
| [llm_cassette](https://github.com/jibranusman95/llm_cassette) | VCR for LLMs — streaming-aware cassette recorder for OpenAI and Anthropic |
| [turbo_presence](https://github.com/jibranusman95/turbo_presence) | Figma-style live cursors, avatar stacks, and typing indicators for Rails — one line |
| [http_decoy](https://github.com/jibranusman95/http_decoy) | A real Rack server that runs inside your RSpec tests — test HTTP contracts, not stubs |
| [promptscrub](https://github.com/jibranusman95/promptscrub) | PII redaction middleware for LLM calls |
| [agent_jail](https://github.com/jibranusman95/agent_jail) | Fork-based sandbox for LLM tool calls — timeout, memory limit, and filesystem restrictions |

---

## License

MIT. See [LICENSE](LICENSE).
