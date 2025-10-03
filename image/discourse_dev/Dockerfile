# NAME:     discourse/discourse_dev
# VERSION:  release

ARG from_tag=slim

FROM discourse/base:$from_tag AS repo-fetcher
WORKDIR /repo
RUN chown discourse .
USER discourse
RUN git clone https://github.com/discourse/discourse . --depth 1

FROM discourse/base:$from_tag

#LABEL maintainer="Sam Saffron \"https://twitter.com/samsaffron\""

# Install Postgres and Redis
RUN --mount=type=tmpfs,target=/var/log \
  apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  postgresql-${PG_MAJOR} postgresql-contrib-${PG_MAJOR} postgresql-${PG_MAJOR}-pgvector
RUN /tmp/install-redis

# Remove the code added on base image
RUN rm -rf /var/www/*

# Give discourse user no-passwd sudo permissions (for bundle install)
ADD sudoers.discourse /etc/sudoers.d/discourse

RUN sudo -u discourse bundle config set --global path /home/discourse/.bundle/gems

# Add user-install ruby gems to PATH
RUN echo 'PATH="$(ruby -r rubygems -e "puts Gem.user_dir")/bin:$PATH"' >> /home/discourse/.profile

# get redis going
ADD redis.template.yml /pups/redis.yml
RUN /pups/bin/pups /pups/redis.yml

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# get postgres going
ADD postgres.template.yml /pups/postgres.yml
RUN LANG=en_US.UTF-8 /pups/bin/pups /pups/postgres.yml

# add dev databases
ADD postgres_dev.template.yml /pups/postgres_dev.yml
RUN /pups/bin/pups /pups/postgres_dev.yml

# move default postgres_data out of the way
RUN mv /shared/postgres_data /shared/postgres_data_orig

# re-instantiate data on boot if needed (this will allow it to persist across
# invocations when used with a mounted volume)
ADD ensure-database /etc/runit/1.d/ensure-database

# Install & Configure MailHog (https://github.com/mailhog/MailHog)
RUN wget -qO /tmp/mailhog https://github.com/mailhog/MailHog/releases/download/v1.0.1/MailHog_linux_amd64\
    && echo "e2ed634ded49929f089b20045581955ed217672078fd86082dd7a6c67c5d09c7 /tmp/mailhog" | sha256sum -c -\
    && mv /tmp/mailhog /usr/local/bin/mailhog\
    && chmod +x /usr/local/bin/mailhog\
    && rm -rf /tmp/*

USER discourse

# Warm global bundle cache, then delete the compressed `cache/` versions (`/gem/` are enough)
RUN --mount=type=bind,src=/repo,from=repo-fetcher,target=/tmp/discourse-clone,readwrite \
    cd /tmp/discourse-clone \
    && bundle install --deployment \
    && rm -rf /home/discourse/.bundle/gems/ruby/*/cache/*

# Warm global yarn cache
RUN --mount=type=bind,src=/repo,from=repo-fetcher,target=/tmp/discourse-clone,readwrite \
    cd /tmp/discourse-clone \
    && (if [ -f yarn.lock ]; then yarn install; else CI=1 pnpm install; fi)

USER root
