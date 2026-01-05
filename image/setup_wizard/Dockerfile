FROM discourse/ruby:3.4-trixie-slim

# Install system dependencies
# Note: No Docker CLI needed - we use docker-api gem to talk to the socket
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    netcat-openbsd \
    lsof \
    procps \
    coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /wizard

# Copy and install gems
COPY Gemfile Gemfile.lock* ./
RUN bundle config set without 'development test'
RUN bundle install

# Copy the wizard logic
COPY lib/ ./lib/
COPY wizard.rb ./

ENTRYPOINT ["ruby", "wizard.rb"]
