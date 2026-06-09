# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  minimum_coverage 90
end

require "active_support/all"
require "active_record"
require "active_job"
require "json"
require "openssl"

# Minimal Rails stub — app/ code that calls Rails.env must not blow up in tests
module Rails
  def self.env
    @env ||= ActiveSupport::StringInquirer.new("test")
  end
end

gem_root = File.expand_path("..", __dir__)

# DB must be set up before requiring any ActiveRecord models
require "support/database"
require "support/active_job"

# Lib files (not autoloaded without a Rails app)
require "webhook_inbox"
require "webhook_inbox/receiver"
require "webhook_inbox/rspec"

# App files (not autoloaded without a Rails engine)
require "#{gem_root}/app/models/webhook_inbox/event"
require "#{gem_root}/app/jobs/webhook_inbox/process_job"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = false
  config.order = :random
  Kernel.srand config.seed
end
