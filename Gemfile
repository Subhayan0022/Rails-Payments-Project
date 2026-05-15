source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Background jobs
gem "sidekiq", "~> 7.0"
gem "sidekiq-scheduler", "~> 5.0"

# State machine for payment lifecycle
gem "aasm", "~> 5.5"

# Rate limiting
gem "rack-attack", "~> 6.7"

# CORS
gem "rack-cors", "~> 2.0"

# JSON serialization
gem "oj", "~> 3.16"

# Structured logging
gem "lograge", "~> 0.14"

# HTTP client for webhook delivery
gem "faraday", "~> 2.9"
gem "faraday-retry", "~> 2.2"

# Environment variables
gem "dotenv-rails", "~> 3.1"

# Pagination
gem "kaminari", "~> 1.2"

# Reduces boot times
gem "bootsnap", require: false

# Windows timezone data
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.3"
  gem "shoulda-matchers", "~> 7.0"
  gem "database_cleaner-active_record", "~> 2.2"
  gem "brakeman", require: false
end

group :development do
  gem "bundler-audit", require: false
end

group :test do
  gem "webmock", "~> 3.23"
  gem "timecop", "~> 0.9"
  gem "simplecov", require: false
end
