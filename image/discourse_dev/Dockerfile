# NAME:     discourse/discourse_dev
# VERSION:  release

ARG from_tag=discourse/base:slim

FROM axllent/mailpit:v1.30.6@sha256:7f33095f80e901f6ad08028f06ca284aa58fe84942be5496008d041d3b9f4d4d AS mailpit

FROM $from_tag AS repo-fetcher
WORKDIR /repo
RUN chown discourse .
USER discourse
RUN git clone https://github.com/discourse/discourse . --depth 1

FROM $from_tag

#LABEL maintainer="Sam Saffron \"https://twitter.com/samsaffron\""

# Install Postgres
RUN --mount=type=tmpfs,target=/var/log \
  apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  postgresql-${PG_MAJOR} postgresql-contrib-${PG_MAJOR} postgresql-${PG_MAJOR}-pgvector \
  postgresql-${PG_MAJOR_OLD} postgresql-contrib-${PG_MAJOR_OLD} postgresql-${PG_MAJOR_OLD}-pgvector

# Install Redis
RUN apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install redis

# Remove the code added on base image
RUN rm -rf /var/www/*

# Give discourse user no-passwd sudo permissions (for bundle install)
COPY sudoers.discourse /etc/sudoers.d/discourse

RUN sudo -u discourse bundle config set --global path /home/discourse/.bundle/gems

# Add user-install ruby gems to PATH
RUN echo 'PATH="$(ruby -r rubygems -e "puts Gem.user_dir")/bin:$PATH"' >> /home/discourse/.profile

# get redis going
COPY --from=templates /redis.template.yml /pups/redis.yml
RUN /pups/bin/pups /pups/redis.yml

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# get postgres going
COPY --from=templates /postgres.${PG_MAJOR}.template.yml /pups/postgres.template.yml
RUN sed -e 's/\(db_name: discourse\)/\1_development/' /pups/postgres.template.yml > /pups/postgres.yml
RUN LANG=en_US.UTF-8 /pups/bin/pups /pups/postgres.yml

# add dev databases
COPY postgres_dev.template.yml /pups/postgres_dev.yml
RUN /pups/bin/pups /pups/postgres_dev.yml

# move default postgres_data out of the way
RUN mv /shared/postgres_data /shared/postgres_data_orig

# re-instantiate data on boot if needed (this will allow it to persist across
# invocations when used with a mounted volume)
COPY ensure-database /etc/runit/1.d/ensure-database

# Install Mailpit, retaining the old binary name for discourse/bin/docker compatibility
COPY --from=mailpit --chmod=0755 /mailpit /usr/local/bin/mailpit
RUN ln -s mailpit /usr/local/bin/mailhog

USER discourse

# Warm global bundle cache, then delete the compressed `cache/` versions (`/gem/` are enough)
RUN --mount=type=bind,src=/repo,from=repo-fetcher,target=/tmp/discourse-clone,readwrite \
    cd /tmp/discourse-clone \
    && env BUNDLE_DEPLOYMENT=true bundle install \
    && rm -rf /home/discourse/.bundle/gems/ruby/*/cache/*

# Warm global yarn cache
RUN --mount=type=bind,src=/repo,from=repo-fetcher,target=/tmp/discourse-clone,readwrite \
    cd /tmp/discourse-clone \
    && (if [ -f yarn.lock ]; then yarn install; else CI=1 pnpm install; fi)

USER root
