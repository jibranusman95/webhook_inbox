# frozen_string_literal: true

module WebhookInbox
  class ProcessJob < ActiveJob::Base
    queue_as { WebhookInbox.configuration.queue_name }

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(event_id)
      event = WebhookInbox::Event.find_by(id: event_id)
      unless event
        logger.warn "[WebhookInbox] ProcessJob: event #{event_id} not found — skipping"
        return
      end

      return unless event.status.in?(%w[pending])

      event.update!(status: "processing", attempts: event.attempts + 1)

      handlers = WebhookInbox.configuration.handlers_for(event.provider, event.event_type)

      if handlers.empty?
        logger.info "[WebhookInbox] No handlers registered for #{event.provider}:#{event.event_type}"
      else
        handlers.each { |handler| handler.call(event) }
      end

      event.update!(status: "processed", processed_at: Time.current, error_message: nil)
    rescue StandardError => e
      event&.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
      )
      raise # let ActiveJob retry_on handle re-enqueueing
    end
  end
end
