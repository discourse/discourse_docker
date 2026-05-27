ARG from_tag=build

FROM discourse/base:$from_tag AS base
ENV RAILS_ENV test

WORKDIR /var/www/discourse
ENV LANG en_US.UTF-8

# configure Git to suppress warnings
RUN sudo -E -u discourse -H git config --global user.email "you@example.com" &&\
    sudo -E -u discourse -H git config --global user.name "Your Name"

# Include postgres and redis on test images
RUN --mount=type=tmpfs,target=/var/log \
  apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  postgresql-${PG_MAJOR} postgresql-contrib-${PG_MAJOR} postgresql-${PG_MAJOR}-pgvector
RUN /tmp/install-redis

RUN chown -R discourse . &&\
    chown -R discourse /var/run/postgresql &&\
    bundle config unset deployment &&\
    bundle config unset without

FROM base AS with_browsers

ENV TESTEM_DEFAULT_BROWSER Chrome
ADD install-chrome /tmp/install-chrome
RUN /tmp/install-chrome &&\
    apt update &&\
    apt install -y libgconf-2-4 libxss1 firefox-esr &&\
    cd /tmp && wget -q "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US" -O firefox.tar.xz &&\
    tar xJvf firefox.tar.xz && mv /tmp/firefox /opt/firefox-evergreen &&\
    apt clean &&\
    rm /tmp/firefox.tar.xz

FROM with_browsers AS release

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle install --jobs $(($(nproc) - 1)) &&\
    sudo -E -u discourse -H /bin/bash -c 'CI=1 pnpm install'

RUN cd /var/www/discourse && sudo -E -u discourse -H bundle exec rake plugin:install_all_official &&\
    LOAD_PLUGINS=1 sudo -E -u discourse -H bundle exec rake plugin:install_all_gems &&\
    sudo -E -u discourse -H bundle exec ruby script/install_minio_binaries.rb

RUN cd /var/www/discourse && \
    pnpm playwright install ffmpeg

RUN cd /var/www/discourse && \
    sudo -E -u discourse -H pnpm playwright install --no-shell chromium

ENTRYPOINT ["sudo", "-E", "-u", "discourse", "-H", "ruby", "script/docker_test.rb"]
