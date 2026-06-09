# frozen_string_literal: true

require "rails"

module WebhookInbox
  class Engine < Rails::Engine
    isolate_namespace WebhookInbox

    initializer "webhook_inbox.initialize" do
      WebhookInbox.configuration ||= WebhookInbox::Configuration.new
    end

    initializer "webhook_inbox.autoload_receiver" do
      ActiveSupport.on_load(:action_controller) do
        require "webhook_inbox/receiver"
      end
    end
  end
end
