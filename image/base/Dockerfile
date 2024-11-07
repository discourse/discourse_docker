# NAME:     discourse/base
# VERSION:  release

ARG DEBIAN_RELEASE=bookworm
FROM discourse/ruby:3.3.6-${DEBIAN_RELEASE}-slim AS builder
ADD install-imagemagick /tmp/install-imagemagick
# From https://nginx.org/en/pgp_keys.html
ADD nginx_public_keys.key /tmp/nginx_public_keys.key
ADD install-nginx /tmp/install-nginx
RUN apt update && \
DEBIAN_FRONTEND=noninteractive apt-get -y install wget \
    autoconf build-essential \
    git \
    cmake \
    gnupg \
    libpcre3-dev \
    libbrotli-dev
RUN /tmp/install-imagemagick
RUN gpg --import /tmp/nginx_public_keys.key &&\
    rm /tmp/nginx_public_keys.key &&\
    /tmp/install-nginx

ADD thpoff.c /src/thpoff.c
RUN gcc -o /usr/local/sbin/thpoff /src/thpoff.c && rm /src/thpoff.c

FROM discourse/ruby:3.3.6-${DEBIAN_RELEASE}-slim AS discourse_dependencies

ARG DEBIAN_RELEASE
ENV PG_MAJOR=13 \
    RUBY_ALLOCATOR=/usr/lib/libjemalloc.so \
    LEFTHOOK=0 \
    DEBIAN_RELEASE=${DEBIAN_RELEASE} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

#LABEL maintainer="Sam Saffron \"https://twitter.com/samsaffron\""

ADD install-oxipng install-jemalloc /tmp/

# Ensures that the gid and uid of the following users are consistent to avoid permission issues on directories in the
# mounted volumes.
RUN --mount=type=tmpfs,target=/var/log \
  --mount=type=tmpfs,target=/root/.npm \
    groupadd --gid 104 postgres &&\
    useradd --uid 101 --gid 104 --home /var/lib/postgresql --shell /bin/bash -c "PostgreSQL administrator,,," postgres &&\
    groupadd --gid 106 redis &&\
    useradd --uid 103 --gid 106 --home /var/lib/redis --shell /usr/sbin/nologin redis &&\
    groupadd --gid 1000 discourse &&\
    useradd --uid 1000 --gid 1000 -m --shell /bin/bash discourse &&\
# add version
    echo 2.0.`date +%Y%m%d` > /VERSION &&\
    echo "deb http://deb.debian.org/debian ${DEBIAN_RELEASE}-backports main" > "/etc/apt/sources.list.d/${DEBIAN_RELEASE}-backports.list" &&\
    echo "debconf debconf/frontend select Teletype" | debconf-set-selections &&\
    apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install gnupg sudo curl fping locales \
    ca-certificates rsync \
    cmake g++ pkg-config patch \
    libxslt-dev libcurl4-openssl-dev \
    libssl-dev libyaml-dev libtool \
    libpcre3 libpcre3-dev zlib1g zlib1g-dev \
    libxml2-dev gawk parallel \
    libreadline-dev anacron wget \
    psmisc whois brotli libunwind-dev \
    libtcmalloc-minimal4 \
    pngquant ripgrep poppler-utils \
# imagemagick runtime dependencies
    libheif1 libjbig0 libtiff6 libpng16-16 libfontconfig1 \
    libwebpdemux2 libwebpmux3 libxext6 librsvg2-2 libgomp1 \
    fonts-urw-base35 \
# nginx runtime dependencies
    nginx-common &&\
# install these without recommends to avoid pulling in e.g.
# X11 libraries, mailutils
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends git rsyslog logrotate cron ssh-client less &&\
# postgres packages
    install -d /usr/share/postgresql-common/pgdg &&\
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc &&\
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${DEBIAN_RELEASE}-pgdg main" > /etc/apt/sources.list.d/pgdg.list &&\
# yarn packages
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - &&\
    echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list &&\
# node packages
    curl --silent --location https://deb.nodesource.com/setup_18.x | sudo bash - &&\
# setup anacron, rsyslog, initctl
    sed -i -e 's/start -q anacron/anacron -s/' /etc/cron.d/anacron &&\
    sed -i.bak 's/$ModLoad imklog/#$ModLoad imklog/' /etc/rsyslog.conf &&\
    sed -i.bak 's/module(load="imklog")/#module(load="imklog")/' /etc/rsyslog.conf &&\
    dpkg-divert --local --rename --add /sbin/initctl &&\
    sh -c "test -f /sbin/initctl || ln -s /bin/true /sbin/initctl" &&\
    apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install runit socat \
    libpq-dev postgresql-client \
    nodejs yarn &&\
    mkdir -p /etc/runit/1.d &&\
    sed -i "s/^# $LANG/$LANG/" /etc/locale.gen && locale-gen &&\
    npm install -g terser uglify-js pnpm &&\
    /tmp/install-oxipng &&\
    /tmp/install-jemalloc

# Copy binary and configuration files for magick
COPY --from=builder /usr/local/bin/magick /usr/local/bin/magick
COPY --from=builder /usr/local/etc/ImageMagick-7 /usr/local/etc/ImageMagick-7
COPY --from=builder /usr/local/share/ImageMagick-7 /usr/local/share/ImageMagick-7
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

# This tool allows us to disable huge page support for our current process
# since the flag is preserved through forks and execs it can be used on any
# process
COPY --from=builder /usr/local/sbin/thpoff /usr/local/sbin/thpoff

# Create symlinks to imagemagick tools
RUN ln -s /usr/local/bin/magick /usr/local/bin/animate &&\
  ln -s /usr/local/bin/magick /usr/local/bin/compare &&\
  ln -s /usr/local/bin/magick /usr/local/bin/composite &&\
  ln -s /usr/local/bin/magick /usr/local/bin/conjure &&\
  ln -s /usr/local/bin/magick /usr/local/bin/convert &&\
  ln -s /usr/local/bin/magick /usr/local/bin/display &&\
  ln -s /usr/local/bin/magick /usr/local/bin/identify &&\
  ln -s /usr/local/bin/magick /usr/local/bin/import &&\
  ln -s /usr/local/bin/magick /usr/local/bin/magick-script &&\
  ln -s /usr/local/bin/magick /usr/local/bin/mogrify &&\
  ln -s /usr/local/bin/magick /usr/local/bin/montage &&\
  ln -s /usr/local/bin/magick /usr/local/bin/stream &&\
  test $(magick -version | grep -o -e png -e tiff -e jpeg -e freetype -e heic -e webp | wc -l) -eq 6 &&\
  echo 'gem: --no-document' >> /usr/local/etc/gemrc &&\
  gem update --system &&\
  gem install pups --force &&\
  mkdir -p /pups/bin/ &&\
  ln -s /usr/local/bin/pups /pups/bin/pups &&\
# this is required for aarch64 which uses buildx
# see https://github.com/docker/buildx/issues/150
  rm -f /etc/service

COPY etc/  /etc
COPY sbin/ /sbin

FROM discourse_dependencies AS discourse_slim
ARG DISCOURSE_BRANCH=main

# Discourse specific bits
RUN install -dm 0755 -o discourse -g discourse /var/www/discourse &&\
    sudo -u discourse git clone --branch $DISCOURSE_BRANCH --filter=tree:0 https://github.com/discourse/discourse.git /var/www/discourse &&\
    gem install bundler --conservative -v $(awk '/BUNDLED WITH/ { getline; gsub(/ /,""); print $0 }' /var/www/discourse/Gemfile.lock)

FROM discourse_slim AS discourse_web
ENV RAILS_ENV=production

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle config --local deployment true &&\
    sudo -u discourse bundle config --local path ./vendor/bundle &&\
    sudo -u discourse bundle config --local without test development &&\
    sudo -u discourse bundle install --jobs $(($(nproc) - 1)) &&\
    find /var/www/discourse/vendor/bundle -name cache -not -path '*/gems/*' -type d -exec rm -rf {} + &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +

RUN cd /var/www/discourse &&\
    sudo -u discourse /bin/bash -c 'if [ -f yarn.lock ]; then yarn install --frozen-lockfile && yarn cache clean; else pnpm install --frozen-lockfile; fi'

FROM discourse_web AS discourse_release
ADD install-redis /tmp/install-redis
RUN --mount=type=tmpfs,target=/var/log \
  apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install postgresql-${PG_MAJOR} postgresql-contrib-${PG_MAJOR} postgresql-${PG_MAJOR}-pgvector &&\
/tmp/install-redis
