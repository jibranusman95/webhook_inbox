# frozen_string_literal: true

module WebhookInbox
  class ApplicationController < ActionController::Base
    before_action :authenticate_dashboard!

    private

    def authenticate_dashboard!
      auth = WebhookInbox.configuration&.dashboard_auth

      # In production, require dashboard_auth to be configured.
      if auth.nil?
        if Rails.env.production?
          render plain: "WebhookInbox dashboard requires authentication. " \
                        "Set config.dashboard_auth in your initializer.",
                 status: :forbidden
        end
        # In development/test, allow through.
        return
      end

      unless instance_exec(self, &auth)
        render plain: "Unauthorized", status: :unauthorized
      end
    end
  end
end
