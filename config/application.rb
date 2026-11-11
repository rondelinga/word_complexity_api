require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module WordComplexityApi
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.api_only = true

    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
      g.test_framework :rspec
    end

    config.active_job.queue_adapter = :sidekiq

    config.cache_store = :redis_cache_store, {
      url: ENV.fetch("REDIS_CACHE_URL", "redis://localhost:6379/1"),
      namespace: "word_complexity",
      error_handler: ->(method:, returning:, exception:) {
        Rails.logger.warn("[cache] #{method} failed: #{exception.class}: #{exception.message}")
      }
    }

    config.x.dictionary_api = ActiveSupport::OrderedOptions.new.tap do |d|
      d.base_url = ENV.fetch("DICTIONARY_API_URL", "https://api.dictionaryapi.dev/api/v2/entries/en")
      d.open_timeout = ENV.fetch("DICTIONARY_API_OPEN_TIMEOUT", 3).to_f
      d.read_timeout = ENV.fetch("DICTIONARY_API_READ_TIMEOUT", 5).to_f
      d.max_retries = ENV.fetch("DICTIONARY_API_MAX_RETRIES", 2).to_i
      d.retry_interval = ENV.fetch("DICTIONARY_API_RETRY_INTERVAL", 0.3).to_f
      d.max_retry_interval = ENV.fetch("DICTIONARY_API_MAX_RETRY_INTERVAL", 2).to_f
      d.cache_ttl = ENV.fetch("DICTIONARY_CACHE_TTL", 1.day.to_i).to_i.seconds
      d.not_found_cache_ttl = ENV.fetch("DICTIONARY_NOT_FOUND_CACHE_TTL", 1.hour.to_i).to_i.seconds
    end

    config.x.complexity = ActiveSupport::OrderedOptions.new.tap do |c|
      c.max_words = ENV.fetch("MAX_WORDS_PER_REQUEST", 100).to_i
      c.max_word_length = ENV.fetch("MAX_WORD_LENGTH", 64).to_i
    end
  end
end
