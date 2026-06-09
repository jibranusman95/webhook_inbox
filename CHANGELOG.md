# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-06-09

### Added

- `WebhookInbox::Receiver` controller concern — `receive_from :stripe, secret: -> { ENV["..."] }` + `receive_webhook!` runs the full receive pipeline (verify → store → enqueue → respond).
- `WebhookInbox::Event` ActiveRecord model — `text` payload column (cross-DB compatible), status enum (`pending` / `processing` / `processed` / `failed`), scopes (`.pending`, `.failed`, `.for_provider`), and `retry!` for replay.
- `WebhookInbox::ProcessJob` ActiveJob — looks up registered handlers for `[provider, event_type]`, marks event status through its lifecycle, stores error messages on failure, re-raises for ActiveJob retry backoff.
- Handler registry via `WebhookInbox.configure { |c| c.on(:stripe, "event.type") { |e| ... } }`. Supports multiple handlers per event type, wildcard `"*"` catch-all per provider, and independent handlers per provider.
- `WebhookInbox::Providers::Stripe` — HMAC-SHA256 signature verification (manual implementation, no stripe gem required), event ID and event type extraction from raw body. Raises `WebhookInbox::SignatureError` on failure.
- `WebhookInbox::Providers::Base` — interface class for building additional provider adapters.
- `rails generate webhook_inbox:install` — generates the migration (with unique index on `[provider, event_id]`) and a commented initializer stub.
- Dashboard Rails Engine at `/webhook_inbox` — event list with status/provider filters, event detail with full JSON payload, replay button, error message display. Plain HTML + inline CSS, no JavaScript framework.
- Dashboard auth lambda `config.dashboard_auth = ->(controller) { ... }` — passthrough in development, enforced in production.
- `WebhookInbox::RSpecHelpers` — `deliver_webhook(:stripe, "event.type", payload: {})` posts a correctly HMAC-signed request, matching Stripe's live webhook format. Auto-included in request specs via `require "webhook_inbox/rspec"`.
- Race-condition-safe deduplication: relies exclusively on the DB unique constraint (not application-level `exists?` checks). Rescues `ActiveRecord::RecordNotUnique`, returns `200` silently.
- Request body rewind: reads and rewinds `request.body` before passing to the adapter, so middleware that consumes the body before the controller does not break signature verification.
