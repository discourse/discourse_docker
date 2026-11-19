ARG from_tag=discourse/base:build

FROM $from_tag AS base
ENV RAILS_ENV=test

WORKDIR /var/www/discourse
ENV LANG=en_US.UTF-8

# configure Git to suppress warnings
RUN sudo -E -u discourse -H git config --global user.email "you@example.com" &&\
    sudo -E -u discourse -H git config --global user.name "Your Name"

# Include postgres on test images
RUN --mount=type=tmpfs,target=/var/log \
  apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  postgresql-${PG_MAJOR} postgresql-contrib-${PG_MAJOR} postgresql-${PG_MAJOR}-pgvector \
  postgresql-${PG_MAJOR_OLD} postgresql-contrib-${PG_MAJOR_OLD} postgresql-${PG_MAJOR_OLD}-pgvector

# Install Redis
RUN apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install redis

RUN chown -R discourse . &&\
    chown -R discourse /var/run/postgresql &&\
    bundle config unset deployment &&\
    bundle config unset without

FROM base AS playwright-tmp

RUN cd /var/www/discourse &&\
    pnpm install --frozen-lockfile --ignore-scripts --filter @discourse/playwright-runner

FROM base AS with_browsers

ENV PLAYWRIGHT_BROWSERS_PATH=/home/discourse/.cache/ms-playwright
RUN --mount=type=bind,from=playwright-tmp,source=/var/www/discourse,target=/var/www/discourse \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt \
    cd /var/www/discourse &&\
    node_modules/.bin/playwright install-deps chromium &&\
    sudo -E -u discourse -H node_modules/.bin/playwright install --no-shell chromium

FROM with_browsers AS release

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle config --local deployment true &&\
    sudo -u discourse bundle config --local path ./vendor/bundle &&\
    sudo -u discourse bundle config --local with migrations &&\
    sudo -u discourse bundle install --jobs $(nproc --ignore=1) &&\
    sudo -E -u discourse -H /bin/bash -c 'CI=1 pnpm install'

RUN cd /var/www/discourse && sudo -E -u discourse -H bundle exec rake plugin:install_all_official &&\
    LOAD_PLUGINS=1 sudo -E -u discourse -H bundle exec rake plugin:install_all_gems

ENTRYPOINT ["sudo", "-E", "-u", "discourse", "-H", "ruby", "script/docker_test.rb"]
