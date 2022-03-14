#!/bin/bash
set -e

# version check: https://github.com/shssoichiro/oxipng/releases
OXIPNG_VERSION="5.0.1"
OXIPNG_FILE="oxipng-${OXIPNG_VERSION}-x86_64-unknown-linux-musl.tar.gz"
OXIPNG_HASH="89240cfd863f8007ab3ad95d88dc2ce15fc003a0421508728d73fec1375f19b6"

# Install other deps
apt -y -q install advancecomp jhead jpegoptim libjpeg-turbo-progs optipng

mkdir /oxipng-install
cd /oxipng-install

wget -q https://github.com/shssoichiro/oxipng/releases/download/v${OXIPNG_VERSION}/${OXIPNG_FILE}
sha256sum ${OXIPNG_FILE}
echo "${OXIPNG_HASH} ${OXIPNG_FILE}" | sha256sum -c

tar --strip-components=1 -xzf $OXIPNG_FILE
cp -v ./oxipng /usr/local/bin
cd / && rm -fr /oxipng-install
