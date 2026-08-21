# NAME:     discourse/base
# VERSION:  release

ARG DEBIAN_RELEASE=trixie
ARG RUBY_VERSION=3.4.10
ARG FROM_DOCKER_IMAGE_TAG=${RUBY_VERSION}-${DEBIAN_RELEASE}-slim

FROM discourse/ruby:${FROM_DOCKER_IMAGE_TAG} AS builder
ARG DEBIAN_RELEASE
ENV DEBIAN_RELEASE=${DEBIAN_RELEASE}
RUN echo "deb http://deb.debian.org/debian ${DEBIAN_RELEASE}-backports main" > "/etc/apt/sources.list.d/${DEBIAN_RELEASE}-backports.list"
RUN apt update &&\
DEBIAN_FRONTEND=noninteractive apt-get -y install wget \
    autoconf build-essential \
    git \
    cmake \
    gnupg \
    libpcre2-dev \
    libfreetype-dev \
    libbrotli-dev

FROM builder AS libheif-builder
ADD install-libheif /tmp/install-libheif
RUN /tmp/install-libheif

FROM libheif-builder AS imagemagick_builder
ADD install-imagemagick /tmp/install-imagemagick
RUN /tmp/install-imagemagick

FROM builder AS jpegli-builder
ADD packages/jpegli /tmp/jpegli-packaging
ADD install-jpegli /tmp/install-jpegli
RUN /tmp/install-jpegli

FROM libheif-builder AS vips-builder
COPY --from=jpegli-builder /tmp/jpegli-packages /tmp/jpegli-debs
ADD packages/vips /tmp/vips-packaging
ADD install-vips /tmp/install-vips
RUN /tmp/install-vips

FROM builder AS thpoff-builder
# This tool allows us to disable huge page support for our current process
# since the flag is preserved through forks and execs it can be used on any
# process
ADD thpoff.c /src/thpoff.c
RUN gcc -o /usr/local/sbin/thpoff /src/thpoff.c && rm /src/thpoff.c

FROM builder AS jemalloc-builder
ADD install-jemalloc /tmp/install-jemalloc
RUN /tmp/install-jemalloc

FROM builder AS oxipng-builder
ADD install-oxipng /tmp/install-oxipng
RUN /tmp/install-oxipng

FROM discourse/ruby:${FROM_DOCKER_IMAGE_TAG} AS discourse-runtime-base

ARG DEBIAN_RELEASE
ARG PG_MAJOR=18
ARG PG_MAJOR_OLD=15
ENV PG_MAJOR=${PG_MAJOR} \
    PG_MAJOR_OLD=${PG_MAJOR_OLD} \
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

RUN echo 2.0.`date +%Y%m%d` > /VERSION
RUN echo "deb http://deb.debian.org/debian ${DEBIAN_RELEASE}-backports main" > "/etc/apt/sources.list.d/${DEBIAN_RELEASE}-backports.list"

COPY --from=libheif-builder /tmp/libheif-packages/libheif1.deb /tmp/libheif1.deb
COPY --from=libheif-builder /tmp/libheif-packages/discourse-libheif-guard.deb /tmp/discourse-libheif-guard.deb
COPY --from=jpegli-builder /tmp/jpegli-packages/discourse-libjpegli62_*.deb /tmp/vips-debs/
COPY --from=vips-builder /tmp/vips-packages/*.deb /tmp/vips-debs/

RUN --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt \
    echo "debconf debconf/frontend select Teletype" | debconf-set-selections &&\
    apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    /tmp/libheif1.deb /tmp/discourse-libheif-guard.deb /tmp/vips-debs/*.deb \
# discourse runtime requirements
    gnupg sudo curl fping locales \
    ca-certificates rsync \
    gawk anacron wget \
    psmisc whois brotli \
    pngcrush pngquant ripgrep poppler-utils \
    catdoc antiword parallel \
# imagemagick runtime dependencies
    libjbig0 libtiff6 libpng16-16 libjpeg62-turbo libfontconfig1 \
    libwebpdemux2 libwebpmux3 libxext6 librsvg2-2 libgomp1 \
    fonts-urw-base35 \
# oxipng dependencies
    advancecomp jpegoptim libjpeg-turbo-progs &&\
# install these without recommends to avoid pulling in e.g.
# X11 libraries, mailutils
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends git rsyslog logrotate cron ssh-client less &&\
# postgres packages
    install -d /usr/share/postgresql-common/pgdg &&\
    curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc &&\
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${DEBIAN_RELEASE}-pgdg main" > /etc/apt/sources.list.d/pgdg.list &&\
# setup anacron, rsyslog, initctl
    sed -i -e 's/start -q anacron/anacron -s/' /etc/cron.d/anacron &&\
    sed -i.bak 's/$ModLoad imklog/#$ModLoad imklog/' /etc/rsyslog.conf &&\
    sed -i.bak 's/module(load="imklog")/#module(load="imklog")/' /etc/rsyslog.conf &&\
    dpkg-divert --local --rename --add /sbin/initctl &&\
    sh -c "test -f /sbin/initctl || ln -s /bin/true /sbin/initctl" &&\
    apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install runit socat \
    libpq-dev postgresql-client-${PG_MAJOR} postgresql-client-${PG_MAJOR_OLD} &&\
    mkdir -p /etc/runit/1.d &&\
    apt-mark hold libheif1 discourse-libheif-guard &&\
    rm /tmp/libheif1.deb /tmp/discourse-libheif-guard.deb /tmp/vips-debs/*.deb &&\
    rmdir /tmp/vips-debs &&\
    test "$(dpkg-query -W -f='${Version}' libheif1)" = "1.23.1-1discourse1"

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
RUN sed -i "s/^# $LANG/$LANG/" /etc/locale.gen &&\
    locale-gen

# nginx
RUN apt update &&\
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    nginx-light \
    libnginx-mod-http-brotli-filter \
    libnginx-mod-http-brotli-static

# Copy binary and configuration files for magick
COPY --from=imagemagick_builder /usr/local/bin/magick /usr/local/bin/magick
COPY --from=imagemagick_builder /usr/local/etc/ImageMagick-7 /usr/local/etc/ImageMagick-7
COPY --from=imagemagick_builder /usr/local/share/ImageMagick-7 /usr/local/share/ImageMagick-7
ADD vips-fixtures /tmp/vips-fixtures
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

RUN ldconfig &&\
  ruby -rfiddle -e 'lib = Fiddle.dlopen("libheif.so.1"); version = Fiddle::Function.new(lib["heif_get_version"], [], Fiddle::TYPE_VOIDP); abort "unexpected libheif version" unless Fiddle::Pointer.new(version.call).to_s == "1.23.1"' &&\
  ruby -rfiddle -e 'Fiddle.dlopen("libvips.so.42")' &&\
  sudo -u discourse vips --version &&\
  sudo -u discourse vipsheader --version &&\
  test "$(command -v vips)" = /usr/bin/vips &&\
  test "$(command -v vipsheader)" = /usr/bin/vipsheader &&\
  dpkg-query -S /usr/bin/vips /usr/bin/vipsheader | grep -q '^discourse-vips-tools:' &&\
  dpkg-query -S /usr/lib/*/libvips.so.42 | grep -q '^discourse-libvips42:' &&\
  dpkg-query -S /usr/lib/*/discourse/jpegli/libjpeg.so.62 | grep -q '^discourse-libjpegli62:' &&\
  ldd /usr/bin/vips | grep -q '/lib/.*/libvips.so.42' &&\
  ldd /usr/bin/vipsheader | grep -q '/lib/.*/libvips.so.42' &&\
  ldd /usr/lib/*/libvips.so.42 | grep -q '/usr/lib/.*/discourse/jpegli/libjpeg.so.62' &&\
  ldd /usr/local/bin/magick | grep 'libjpeg.so.62' | grep -vq '/discourse/jpegli/' &&\
  sudo -u discourse vips black /tmp/vips-jpegli.jpg 1 1 &&\
  sudo -u discourse vipsheader /tmp/vips-jpegli.jpg >/dev/null &&\
  sudo -u discourse magick -size 8x8 gradient: /tmp/vips-baseline.jpg &&\
  sudo -u discourse magick -size 8x8 gradient: -interlace Plane /tmp/vips-progressive.jpg &&\
  sudo -u discourse magick -size 8x8 gradient: -colorspace CMYK /tmp/vips-cmyk.jpg &&\
  base64 -d /tmp/vips-fixtures/orientation-6.jpg.base64 >/tmp/vips-oriented.jpg &&\
  sudo -u discourse vipsheader /tmp/vips-baseline.jpg /tmp/vips-progressive.jpg /tmp/vips-cmyk.jpg /tmp/vips-oriented.jpg >/dev/null &&\
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="red"/></svg>' >/tmp/vips-source.svg &&\
  sudo -u discourse vips copy /tmp/vips-source.svg /tmp/vips-svg.png &&\
  sudo -u discourse vips black /tmp/vips-source.png 8 8 &&\
  sudo -u discourse vips copy /tmp/vips-source.png /tmp/vips-source.webp &&\
  sudo -u discourse vips copy /tmp/vips-source.png /tmp/vips-source.tiff &&\
  sudo -u discourse vips copy /tmp/vips-source.png /tmp/vips-source.jxl &&\
  sudo -u discourse vips copy /tmp/vips-source.png /tmp/vips-source.gif &&\
  sudo -u discourse vips black /tmp/vips-source.heic 8 8 &&\
  sudo -u discourse vips black /tmp/vips-source.avif 8 8 &&\
  sudo -u discourse vips text /tmp/vips-text.png Discourse &&\
  sudo -u discourse vips thumbnail /tmp/vips-source.png /tmp/vips-thumbnail.png 4 &&\
  test "$(sudo -u discourse vipsheader -f orientation /tmp/vips-oriented.jpg)" = 6 &&\
  sudo -u discourse vips autorot /tmp/vips-oriented.jpg /tmp/vips-autorot.jpg &&\
  sudo -u discourse vips xyz /tmp/vips-coordinates.v 8 8 &&\
  sudo -u discourse vips gravity /tmp/vips-coordinates.v /tmp/vips-gravity.v centre 4 4 &&\
  sudo -u discourse vips black /tmp/vips-alpha.png 4 4 --bands 4 &&\
  sudo -u discourse vips flatten /tmp/vips-alpha.png /tmp/vips-flatten.png --background '255 255 255' &&\
  test "$(sudo -u discourse vipsheader -f width /tmp/vips-thumbnail.png)" = 4 &&\
  test "$(sudo -u discourse vipsheader -f height /tmp/vips-thumbnail.png)" = 4 &&\
  test "$(sudo -u discourse vipsheader -f width /tmp/vips-autorot.jpg)" = 4 &&\
  test "$(sudo -u discourse vipsheader -f height /tmp/vips-autorot.jpg)" = 8 &&\
  test "$(sudo -u discourse vipsheader -f orientation /tmp/vips-autorot.jpg)" = 1 &&\
  sudo -u discourse vips getpoint /tmp/vips-gravity.v 0 0 | grep -q '^2 2 *$' &&\
  sudo -u discourse vips getpoint /tmp/vips-gravity.v 3 3 | grep -q '^5 5 *$' &&\
  test "$(sudo -u discourse vipsheader -f bands /tmp/vips-flatten.png)" = 3 &&\
  test "$(sudo -u discourse vips avg /tmp/vips-flatten.png)" = 255.000000 &&\
  sudo -u discourse vipsheader /tmp/vips-svg.png /tmp/vips-source.webp /tmp/vips-source.tiff /tmp/vips-source.jxl /tmp/vips-source.gif /tmp/vips-source.heic /tmp/vips-source.avif /tmp/vips-text.png /tmp/vips-thumbnail.png /tmp/vips-autorot.jpg /tmp/vips-gravity.v /tmp/vips-flatten.png >/dev/null &&\
  apt-get -s install libvips42t64 libvips-tools >/tmp/vips-coinstall.txt &&\
  grep -q '^Remv discourse-libvips42 ' /tmp/vips-coinstall.txt &&\
  grep -q '^Remv discourse-vips-tools ' /tmp/vips-coinstall.txt &&\
  rm -rf /tmp/vips-* &&\
  for op in jpegload jpegsave pngload gifload gifsave webpload tiffload heifload jxlload svgload text thumbnail autorot gravity flatten; do \
    sudo -u discourse vips -l "$op" >/dev/null || { echo "ERROR: vips is missing operation: $op"; exit 1; }; \
  done &&\
  for op in magickload magicksave pdfload; do \
    if sudo -u discourse vips -l "$op" >/dev/null 2>&1; then echo "ERROR: vips exposes forbidden operation: $op"; exit 1; fi; \
  done &&\
  if ldd /usr/lib/*/libvips.so.42 | grep -Eqi 'libMagick|libpoppler|libgs\.so'; then \
    echo "ERROR: vips links to a forbidden image or PDF library"; exit 1; \
  fi &&\
  if dpkg-query -W -f '${Package} ${db:Status-Status}\n' ghostscript libgs10 libgs-common libgs10-common 2>/dev/null | grep -q ' installed$' || command -v gs >/dev/null; then \
    echo "ERROR: ghostscript must not be present in this image"; exit 1; \
  fi

COPY --from=thpoff-builder /usr/local/sbin/thpoff /usr/local/sbin
COPY --from=jemalloc-builder /usr/lib/libjemalloc.so /usr/lib
COPY --from=oxipng-builder /usr/local/bin/jhead /usr/local/bin
COPY --from=oxipng-builder /usr/local/bin/oxipng /usr/local/bin

# version check: https://rubygems.org/gems/pups
RUN cd /tmp &&\
    gem fetch pups --version 1.4.0 &&\
    echo "5809731d6f4819defe1aac694e614c4b3d9958b5f378a70edf761f3808877052 pups-1.4.0.gem" | sha256sum -c &&\
    gem install --local --force pups-1.4.0.gem &&\
    rm pups-1.4.0.gem &&\
    mkdir -p /pups/bin/ &&\
    ln -s /usr/local/bin/pups /pups/bin/pups

# this is required for aarch64 which uses buildx
# see https://github.com/docker/buildx/issues/150
RUN rm -f /etc/service

COPY etc/  /etc
COPY sbin/ /sbin

FROM discourse-runtime-base AS discourse-build-base
# From https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key
# fingerprint: 6F71 F525 2828 41EE DAF8 51B4 2F59 B5F9 9B1B E0B4
ADD nodesource-repo.gpg.key /usr/share/keyrings/nodesource.asc
RUN --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=tmpfs,target=/var/lib/apt \
# node packages
    printf 'Types: deb\nURIs: https://deb.nodesource.com/node_22.x\nSuites: nodistro\nComponents: main\nSigned-By: /usr/share/keyrings/nodesource.asc\n' > /etc/apt/sources.list.d/nodesource.sources &&\
    printf 'Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 600\n' > /etc/apt/preferences.d/nodejs &&\
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
    nodejs

# pnpm
RUN --mount=type=tmpfs,target=/root/.npm \
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
    sudo -u discourse bundle install --jobs $(nproc --ignore=1) &&\
    find /var/www/discourse/vendor/bundle -name cache -not -path '*/gems/*' -type d -exec rm -rf {} + &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +

RUN cd /var/www/discourse &&\
    sudo -u discourse /bin/bash -c 'pnpm install --frozen-lockfile'

FROM discourse-web-only AS discourse-release
RUN --mount=type=tmpfs,target=/var/log \
  apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  postgresql-${PG_MAJOR} postgresql-contrib-${PG_MAJOR} postgresql-${PG_MAJOR}-pgvector
RUN apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install redis
