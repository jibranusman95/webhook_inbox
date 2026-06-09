# frozen_string_literal: true

require "active_record"
require "sqlite3"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :webhook_inbox_events, force: true do |t|
    t.string   :provider,      null: false
    t.string   :event_id,      null: false
    t.string   :event_type
    t.text     :payload,       null: false, default: "{}"
    t.string   :status,        null: false, default: "pending"
    t.integer  :attempts,      null: false, default: 0
    t.text     :error_message
    t.datetime :processed_at
    t.timestamps
  end

  add_index :webhook_inbox_events, %i[provider event_id], unique: true
  add_index :webhook_inbox_events, :status
  add_index :webhook_inbox_events, :created_at
end

RSpec.configure do |config|
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
