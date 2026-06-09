# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - unreleased

### Added
- `WebhookInbox::Receiver` controller concern with `receive_from` and `receive_webhook!`
- `WebhookInbox::Event` ActiveRecord model with status enum, scopes, and `retry!`
- `WebhookInbox::ProcessJob` ActiveJob for async handler dispatch with status tracking
- `WebhookInbox::Providers::Stripe` — HMAC-SHA256 signature verification, event_id/event_type extraction
- Handler registry via `config.on(:provider, "event.type") { |event| ... }` with wildcard `"*"` support
- `rails generate webhook_inbox:install` — generates migration + initializer stub
- Dashboard Rails Engine mounted at `/webhook_inbox` — event list, detail, replay button
- Dashboard auth lambda `config.dashboard_auth = ->(controller) { ... }`
- `WebhookInbox::RSpecHelpers` — `deliver_webhook(:stripe, "event.type", payload: {})` test helper
- Race-condition-safe deduplication via DB unique constraint on `[provider, event_id]`
- `after_commit`-safe job enqueue pattern via `retry!` and `ProcessJob`
