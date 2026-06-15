# NAME:     discourse/base
# VERSION:  release

ARG DEBIAN_RELEASE=bookworm
ARG RUBY_VERSION=3.4.9
ARG FROM_DOCKER_IMAGE_TAG=${RUBY_VERSION}-${DEBIAN_RELEASE}-slim

FROM discourse/ruby:${FROM_DOCKER_IMAGE_TAG} AS builder
ARG DEBIAN_RELEASE
ENV DEBIAN_RELEASE=${DEBIAN_RELEASE}

RUN echo "no op to see if cache is working"

RUN echo "deb http://deb.debian.org/debian ${DEBIAN_RELEASE}-backports main" > "/etc/apt/sources.list.d/${DEBIAN_RELEASE}-backports.list" &&\
# keep downloaded .debs so the apt cache mounts below survive across builds;
# builder stages are throwaway, so the retained archives never ship anywhere
    rm -f /etc/apt/apt.conf.d/docker-clean &&\
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,id=apt-builder apt update && \
DEBIAN_FRONTEND=noninteractive apt-get -y install wget \
    autoconf build-essential \
    git \
    cmake \
    gnupg \
    libpcre3-dev \
    libfreetype6-dev \
    libbrotli-dev
# sha-pinned downloader backed by a BuildKit cache mount at /var/cache/assets;
# entries are keyed by checksum, so the cache is safely shared between the
# amd64 and arm64 builds
ADD fetch-asset /usr/local/bin/fetch-asset

# builder substages run in parallel, so each gets its own apt cache id to
# avoid apt lock contention on a shared mount
FROM builder AS imagemagick_builder
ADD install-imagemagick /tmp/install-imagemagick
RUN --mount=type=cache,target=/var/cache/assets \
  --mount=type=cache,target=/var/cache/apt,id=apt-imagemagick \
  /tmp/install-imagemagick

FROM builder AS vips-builder
ADD install-vips /tmp/install-vips
RUN --mount=type=cache,target=/var/cache/assets \
  --mount=type=cache,target=/var/cache/apt,id=apt-vips \
  /tmp/install-vips

FROM builder AS nginx-builder
# From https://nginx.org/en/pgp_keys.html
ADD nginx_public_keys.key /tmp/nginx_public_keys.key
ADD install-nginx /tmp/install-nginx
RUN --mount=type=cache,target=/var/cache/assets \
  --mount=type=cache,target=/var/cache/apt,id=apt-nginx \
  gpg --import /tmp/nginx_public_keys.key &&\
  rm /tmp/nginx_public_keys.key &&\
  /tmp/install-nginx

FROM builder AS thpoff-builder
# This tool allows us to disable huge page support for our current process
# since the flag is preserved through forks and execs it can be used on any
# process
ADD thpoff.c /src/thpoff.c
RUN gcc -o /usr/local/sbin/thpoff /src/thpoff.c && rm /src/thpoff.c

FROM builder AS jemalloc-builder
ADD install-jemalloc /tmp/install-jemalloc
RUN --mount=type=cache,target=/var/cache/assets \
  --mount=type=cache,target=/var/cache/apt,id=apt-jemalloc \
  /tmp/install-jemalloc

FROM builder AS oxipng-builder
ADD install-oxipng /tmp/install-oxipng
RUN --mount=type=cache,target=/var/cache/assets \
  --mount=type=cache,target=/var/cache/apt,id=apt-oxipng \
  /tmp/install-oxipng

FROM builder AS cjpegli-builder
ADD install-cjpegli /tmp/install-cjpegli
RUN --mount=type=cache,target=/var/cache/assets \
  --mount=type=cache,target=/var/cache/apt,id=apt-cjpegli \
  /tmp/install-cjpegli

FROM discourse/ruby:${FROM_DOCKER_IMAGE_TAG} AS discourse-runtime-base

ARG DEBIAN_RELEASE
ARG PG_MAJOR=15
ENV PG_MAJOR=${PG_MAJOR} \
    RUBY_ALLOCATOR=/usr/lib/libjemalloc.so \
    LEFTHOOK=0 \
    DEBIAN_RELEASE=${DEBIAN_RELEASE}

# Ensures that the gid and uid of the following users are consistent to avoid permission issues on directories in the
# mounted volumes.
RUN groupadd --gid 104 postgres &&\
    useradd --uid 101 --gid 104 --home /var/lib/postgresql --shell /bin/bash -c "PostgreSQL administrator,,," postgres &&\
    groupadd --gid 106 redis &&\
    useradd --uid 103 --gid 106 --home /var/lib/redis --shell /usr/sbin/nologin redis &&\
    groupadd --gid 1000 discourse &&\
    useradd --uid 1000 --gid 1000 -m --shell /bin/bash discourse

# VERSION_DATE busts this layer (and the runtime apt layers below it) once a
# day even when building from a registry cache; the compile-heavy builder
# stages are parallel branches and stay cached
ARG VERSION_DATE
RUN echo 2.0.${VERSION_DATE:-`date +%Y%m%d`} > /VERSION
RUN echo "deb http://deb.debian.org/debian ${DEBIAN_RELEASE}-backports main" > "/etc/apt/sources.list.d/${DEBIAN_RELEASE}-backports.list"

# /var/lib/apt is a cache mount so apt-get update reuses package lists across
# builds (and between amd64/arm64 — list files are arch-qualified). docker-clean
# stays active in the runtime chain, so .debs are still discarded and images
# deriving from this one don't bloat.
RUN --mount=type=tmpfs,target=/var/log \
  --mount=type=tmpfs,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt,id=apt-lists-runtime \
    echo "debconf debconf/frontend select Teletype" | debconf-set-selections; \
    apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
# discourse runtime requirements
  gnupg sudo curl fping locales \
  ca-certificates rsync \
    gawk anacron wget \
    psmisc whois brotli \
    pngcrush pngquant ripgrep poppler-utils \
    catdoc antiword parallel \
# nginx runtime dependencies
    libpcre3 zlib1g \
# imagemagick runtime dependencies
    libjbig0 libtiff6 libpng16-16 libfontconfig1 \
    libwebpdemux2 libwebpmux3 libxext6 librsvg2-2 libgomp1 \
    fonts-urw-base35 libheif1/${DEBIAN_RELEASE}-backports \
# oxipng dependencies \
    advancecomp jpegoptim libjpeg-turbo-progs \
# libvips runtime dependencies (safe_image; vips itself is built from source
# in vips-builder — the libvips42 deb is avoided because it hard-depends on
# libmagickcore, which drags ghostscript into the image via apt recommends)
    libglib2.0-0 libexpat1 libjpeg62-turbo libexif12 liblcms2-2 \
    liborc-0.4-0 libcgif0 libimagequant0 libjxl0.7 libwebp7 \
    libpango-1.0-0 libpangocairo-1.0-0 libcairo2 \
# nginx runtime dependencies \
    nginx-common && \
# install these without recommends to avoid pulling in e.g.
# X11 libraries, mailutils
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends git rsyslog logrotate cron ssh-client less; \
# postgres packages
    install -d /usr/share/postgresql-common/pgdg &&\
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc &&\
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${DEBIAN_RELEASE}-pgdg main" > /etc/apt/sources.list.d/pgdg.list; \
# setup anacron, rsyslog, initctl
    sed -i -e 's/start -q anacron/anacron -s/' /etc/cron.d/anacron; \
    sed -i.bak 's/$ModLoad imklog/#$ModLoad imklog/' /etc/rsyslog.conf; \
    sed -i.bak 's/module(load="imklog")/#module(load="imklog")/' /etc/rsyslog.conf; \
    dpkg-divert --local --rename --add /sbin/initctl; \
    sh -c "test -f /sbin/initctl || ln -s /bin/true /sbin/initctl"; \
    apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install runit socat \
    libpq-dev postgresql-client-${PG_MAJOR} &&\
    mkdir -p /etc/runit/1.d

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
RUN sed -i "s/^# $LANG/$LANG/" /etc/locale.gen; \
    locale-gen

COPY --from=nginx-builder /usr/sbin/nginx /usr/sbin

# Copy binary and configuration files for magick
COPY --from=imagemagick_builder /usr/local/bin/magick /usr/local/bin/magick
COPY --from=imagemagick_builder /usr/local/etc/ImageMagick-7 /usr/local/etc/ImageMagick-7
COPY --from=imagemagick_builder /usr/local/share/ImageMagick-7 /usr/local/share/ImageMagick-7
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
  test $(magick -version | grep -o -e png -e tiff -e jpeg -e freetype -e heic -e webp | wc -l) -eq 6

# libvips built without the ImageMagick fallback loader. safe_image dlopens
# the library by soname, so a single regular file is all the runtime needs.
COPY --from=vips-builder /usr/local/lib/libvips.so.42 /usr/local/lib/libvips.so.42
RUN ldconfig &&\
  ruby -rfiddle -e 'Fiddle.dlopen("libvips.so.42")'

COPY --from=thpoff-builder /usr/local/sbin/thpoff /usr/local/sbin
COPY --from=jemalloc-builder /usr/lib/libjemalloc.so /usr/lib
COPY --from=oxipng-builder /usr/local/bin/jhead /usr/local/bin
COPY --from=oxipng-builder /usr/local/bin/oxipng /usr/local/bin
COPY --from=cjpegli-builder /usr/local/bin/cjpegli /usr/local/bin

ADD fetch-asset /usr/local/bin/fetch-asset
ADD install-redis /tmp/install-redis

# version check: https://rubygems.org/gems/pups
RUN --mount=type=cache,target=/var/cache/assets \
    cd /tmp &&\
    fetch-asset "https://rubygems.org/downloads/pups-1.4.0.gem" "5809731d6f4819defe1aac694e614c4b3d9958b5f378a70edf761f3808877052" /tmp/pups-1.4.0.gem &&\
    gem install --local --force pups-1.4.0.gem &&\
    rm pups-1.4.0.gem &&\
    mkdir -p /pups/bin/ &&\
    ln -s /usr/local/bin/pups /pups/bin/pups

# this is required for aarch64 which uses buildx
# see https://github.com/docker/buildx/issues/150
RUN rm -f /etc/service

COPY etc/  /etc
COPY sbin/ /sbin

# ghostscript must never ship in this image: it historically rode in via apt
# recommends (libvips42 -> libmagickcore -> ghostscript) and is a recurring
# RCE vector in image pipelines. Fail the build if it ever comes back.
RUN if dpkg-query -W -f '${Package} ${db:Status-Status}\n' ghostscript libgs10 2>/dev/null | grep -q ' installed$' || command -v gs >/dev/null; then \
      echo "ERROR: ghostscript must not be present in this image"; exit 1; \
    fi

FROM discourse-runtime-base AS discourse-build-base
# From https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key
# fingerprint: 6F71 F525 2828 41EE DAF8 51B4 2F59 B5F9 9B1B E0B4
ADD nodesource-repo.gpg.key /usr/share/keyrings/nodesource.asc
# From https://dl.yarnpkg.com/debian/pubkey.gpg
# fingerprint: 72EC F46A 56B4 AD39 C907 BBB7 1646 B01B 86E5 0310
ADD yarn-pubkey.gpg.key /usr/share/keyrings/yarn.asc
RUN --mount=type=tmpfs,target=/var/log \
  --mount=type=tmpfs,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt,id=apt-lists-runtime \
# yarn packages
    echo "deb [signed-by=/usr/share/keyrings/yarn.asc] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list; \
# node packages
    printf 'Types: deb\nURIs: https://deb.nodesource.com/node_22.x\nSuites: nodistro\nComponents: main\nSigned-By: /usr/share/keyrings/nodesource.asc\n' > /etc/apt/sources.list.d/nodesource.sources; \
    printf 'Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 600\n' > /etc/apt/preferences.d/nodejs; \
    echo "debconf debconf/frontend select Teletype" | debconf-set-selections; \
    apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
# gem build dependencies
    cmake g++ pkg-config patch \
    libtool \
    libxslt-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libyaml-dev \
    libxml2-dev \
    libreadline-dev \
    libunwind-dev \
# node
    nodejs yarn
# pnpm (npm re-verifies cached tarballs against their integrity hashes)
RUN --mount=type=cache,target=/root/.npm,id=npm \
    npm install -g pnpm@10

FROM discourse-build-base AS discourse-slim
ARG DISCOURSE_BRANCH=main

# Discourse specific bits
RUN install -dm 0755 -o discourse -g discourse /var/www/discourse &&\
    sudo -u discourse git clone --branch $DISCOURSE_BRANCH --filter=tree:0 https://github.com/discourse/discourse.git /var/www/discourse

FROM discourse-slim AS discourse-web-only
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

FROM discourse-web-only AS discourse-release
RUN --mount=type=tmpfs,target=/var/log \
  --mount=type=tmpfs,target=/var/cache/apt \
  --mount=type=cache,target=/var/lib/apt,id=apt-lists-runtime \
  apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  postgresql-${PG_MAJOR} postgresql-contrib-${PG_MAJOR} postgresql-${PG_MAJOR}-pgvector
RUN --mount=type=cache,target=/var/cache/assets /tmp/install-redis

# Re-check on the final stage: anything installed after the runtime-base
# guard (gem build deps, node, postgres, redis) must not bring ghostscript.
RUN if dpkg-query -W -f '${Package} ${db:Status-Status}\n' ghostscript libgs10 2>/dev/null | grep -q ' installed$' || command -v gs >/dev/null; then \
      echo "ERROR: ghostscript must not be present in this image"; exit 1; \
    fi
