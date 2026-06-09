# frozen_string_literal: true

module WebhookInbox
  class Event < ActiveRecord::Base
    self.table_name = "webhook_inbox_events"

    # payload is stored as text, deserialized as Hash on read
    attribute :payload, :string

    STATUSES = %w[pending processing processed failed].freeze

    validates :provider,   presence: true
    validates :event_id,   presence: true
    validates :status,     inclusion: { in: STATUSES }

    scope :pending,    -> { where(status: "pending") }
    scope :processing, -> { where(status: "processing") }
    scope :processed,  -> { where(status: "processed") }
    scope :failed,     -> { where(status: "failed") }
    scope :for_provider, ->(name) { where(provider: name.to_s) }

    # parsed_payload returns the payload as a Hash regardless of how it was stored
    def parsed_payload
      return payload if payload.is_a?(Hash)

      JSON.parse(payload)
    rescue JSON::ParserError
      {}
    end

    # Enqueue for reprocessing. Resets status to pending.
    def retry!
      update!(status: "pending", error_message: nil)
      WebhookInbox::ProcessJob.set(queue: WebhookInbox.configuration.queue_name)
                              .perform_later(id)
    end
  end
end
