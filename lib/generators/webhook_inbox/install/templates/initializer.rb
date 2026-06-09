# frozen_string_literal: true

WebhookInbox.configure do |config|
  # Register handlers for each provider + event type you want to handle.
  # The block receives a WebhookInbox::Event object.
  #
  # config.on(:stripe, "customer.subscription.created") do |event|
  #   CreateSubscriptionJob.perform_later(event.parsed_payload)
  # end
  #
  # config.on(:stripe, "invoice.payment_failed") do |event|
  #   NotifyPaymentFailedJob.perform_later(event.parsed_payload)
  # end
  #
  # Catch-all for all Stripe events:
  # config.on(:stripe, "*") do |event|
  #   Rails.logger.info "[WebhookInbox] Received #{event.event_type}"
  # end

  # Queue name for ProcessJob (default: "webhooks")
  # config.queue_name = "webhooks"

  # Dashboard auth lambda — return truthy to allow access.
  # Required in production. Uncomment and customize:
  # config.dashboard_auth = ->(controller) { controller.current_user&.admin? }
end
