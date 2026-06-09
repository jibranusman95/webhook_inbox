# frozen_string_literal: true

module WebhookInbox
  module DashboardHelper
    STATUS_CLASSES = {
      "pending"    => "badge-pending",
      "processing" => "badge-processing",
      "processed"  => "badge-processed",
      "failed"     => "badge-failed"
    }.freeze

    def status_badge(status)
      css = STATUS_CLASSES.fetch(status, "badge-pending")
      content_tag(:span, status, class: "wi-badge #{css}")
    end
  end
end
