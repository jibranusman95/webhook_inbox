# frozen_string_literal: true

require "active_job"

ActiveJob::Base.queue_adapter = :test

RSpec.configure do |config|
  config.before do
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear
  end
end
