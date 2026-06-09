# frozen_string_literal: true

require_relative "lib/webhook_inbox/version"

Gem::Specification.new do |spec|
  spec.name = "webhook_inbox"
  spec.version = WebhookInbox::VERSION
  spec.authors = ["Jibran Usman"]
  spec.email = ["jibran.usman@eunasolutions.com"]

  spec.summary = "Transactional inbox for Rails webhook receivers — deduplication, async processing, replay, and a dashboard."
  spec.description = "Drop-in Rails Engine that gives every app a production-ready webhook inbox. Signature verification, DB deduplication via unique constraint, async processing via ActiveJob, and a /webhook_inbox dashboard with replay. Provider adapters for Stripe (v0.1)."
  spec.homepage = "https://github.com/jibranusman95/webhook_inbox"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.0"
  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "activejob", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"
end
