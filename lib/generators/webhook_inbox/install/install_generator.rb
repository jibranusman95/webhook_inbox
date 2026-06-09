# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module WebhookInbox
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates a WebhookInbox migration and initializer in your application."

      def create_migration
        migration_template "create_webhook_inbox_events.rb.erb",
                           "db/migrate/create_webhook_inbox_events.rb"
      end

      def create_initializer
        template "initializer.rb", "config/initializers/webhook_inbox.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
