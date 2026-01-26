FROM discourse/ruby:3.4-trixie-slim

# Install system dependencies (curl, nc, lsof needed for network checks)
# Note: No Docker CLI needed - we use docker-api gem to talk to the socket
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    netcat-openbsd \
    lsof \
    && curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${TARGETARCH} -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /wizard

# Copy and install gems (ratatui_ruby requires Rust and build tools to compile)
COPY Gemfile Gemfile.lock* ./
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libclang-dev \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal \
    && . "$HOME/.cargo/env" \
    && bundle config set without 'development test' && bundle install \
    && rustup self uninstall -y \
    && apt-get purge -y build-essential libclang-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Copy the wizard logic
COPY lib/ ./lib/
COPY wizard.rb ./

ENTRYPOINT ["ruby", "wizard.rb"]
