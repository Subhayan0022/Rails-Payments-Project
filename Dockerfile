FROM ruby:3.3-slim

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  postgresql-client \
  libyaml-dev \
  curl \
  git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems separately for layer caching
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot
RUN bundle exec bootsnap precompile --gemfile app/ lib/ 2>/dev/null || true

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
