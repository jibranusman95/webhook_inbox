# frozen_string_literal: true

require "webhook_inbox/rspec/helpers"

RSpec.configure do |config|
  config.include WebhookInbox::RSpecHelpers, type: :request
end
