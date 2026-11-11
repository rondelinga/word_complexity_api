source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.2"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Background processing and cache
gem "sidekiq", "~> 7.3"
# Sidekiq 7 calls TimedStack#pop with a timeout argument removed in connection_pool 3.
gem "connection_pool", "~> 2.5"
gem "redis", "~> 5.3"

# HTTP client for the dictionary API
gem "faraday", "~> 2.12"
gem "faraday-retry", "~> 2.2"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails", "~> 8.0"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "webmock", "~> 3.24"
end
