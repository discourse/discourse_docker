#!/bin/bash
set -e

# version check: https://github.com/ImageMagick/ImageMagick/releases
IMAGE_MAGICK_VERSION="7.1.0-20"
IMAGE_MAGICK_HASH="c7526ca8b341e42f026f8157632b1722555f0d015c281861d9c4d314c0c8f78c"

# We use debian, but GitHub CI is stuck on Ubuntu Bionic, so this must be compatible with both
LIBJPEGTURBO=$(cat /etc/issue | grep -qi Debian && echo 'libjpeg62-turbo libjpeg62-turbo-dev' || echo 'libjpeg-turbo8 libjpeg-turbo8-dev')

PREFIX=/usr/local
WDIR=/tmp/imagemagick

# Install build deps
apt -y -q remove imagemagick
apt -y -q install git make gcc pkg-config autoconf curl g++ yasm cmake \
    libde265-0 libde265-dev ${LIBJPEGTURBO} x265 libx265-dev libtool \
    libpng16-16 libpng-dev ${LIBJPEGTURBO} libwebp6 libwebp-dev libgomp1 \
    libwebpmux3 libwebpdemux2 ghostscript libxml2-dev libxml2-utils \
    libltdl7-dev libbz2-dev gsfonts libtiff-dev libfreetype6-dev libjpeg-dev

# Use backports instead of compiling it
apt -y -q install -t bullseye-backports libheif1 libaom-dev libheif-dev

mkdir -p $WDIR
cd $WDIR

# Build and install ImageMagick
wget -q -O $WDIR/ImageMagick.tar.gz "https://github.com/ImageMagick/ImageMagick/archive/$IMAGE_MAGICK_VERSION.tar.gz"
sha256sum $WDIR/ImageMagick.tar.gz
echo "$IMAGE_MAGICK_HASH $WDIR/ImageMagick.tar.gz" | sha256sum -c
IMDIR=$WDIR/$(tar tzf $WDIR/ImageMagick.tar.gz --wildcards "ImageMagick-*/configure" |cut -d/ -f1)
tar zxf $WDIR/ImageMagick.tar.gz -C $WDIR
cd $IMDIR
PKG_CONF_LIBDIR=$PREFIX/lib LDFLAGS=-L$PREFIX/lib CFLAGS=-I$PREFIX/include ./configure \
          --prefix=$PREFIX \
          --enable-static \
          --enable-bounds-checking \
          --enable-hdri \
          --enable-hugepages \
          --with-threads \
          --with-modules \
          --with-quantum-depth=16 \
          --without-magick-plus-plus \
          --with-bzlib \
          --with-zlib \
          --without-autotrace \
          --with-freetype \
          --with-jpeg \
          --without-lcms \
          --with-lzma \
          --with-png \
          --with-tiff \
          --with-heic \
          --with-webp
make all && make install

cd $HOME
rm -rf $WDIR
ldconfig /usr/local/lib

# Validate ImageMagick install
test $(convert -version | grep -o -e png -e tiff -e jpeg -e freetype -e heic -e webp | wc -l) -eq 6
