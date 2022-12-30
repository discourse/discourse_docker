# NAME:     discourse/base
# VERSION:  release
FROM debian:bullseye-slim

ENV PG_MAJOR=13 \
    RUBY_ALLOCATOR=/usr/lib/libjemalloc.so.1 \
    RAILS_ENV=production \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ADD build-base-image /tmp/build-base-image
ADD install-imagemagick /tmp/install-imagemagick
ADD install-jemalloc /tmp/install-jemalloc
ADD install-nginx /tmp/install-nginx
ADD install-oxipng /tmp/install-oxipng
ADD install-redis /tmp/install-redis
ADD install-rust /tmp/install-rust
ADD install-ruby /tmp/install-ruby
ADD thpoff.c /src/thpoff.c

RUN /tmp/build-base-image

COPY etc/  /etc
COPY sbin/ /sbin

# Discourse specific bits
RUN useradd discourse -s /bin/bash -m -U &&\
    install -dm 0755 -o discourse -g discourse /var/www/discourse &&\
    sudo -u discourse git clone --depth 1 https://github.com/discourse/discourse.git /var/www/discourse &&\
    sudo -u discourse git -C /var/www/discourse remote set-branches --add origin tests-passed
