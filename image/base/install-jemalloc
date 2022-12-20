#!/bin/bash
set -e

# version check: https://github.com/jemalloc/jemalloc/releases

# jemalloc stable
mkdir /jemalloc-stable
cd /jemalloc-stable

wget -q https://github.com/jemalloc/jemalloc/releases/download/3.6.0/jemalloc-3.6.0.tar.bz2
sha256sum jemalloc-3.6.0.tar.bz2
echo "e16c2159dd3c81ca2dc3b5c9ef0d43e1f2f45b04548f42db12e7c12d7bdf84fe jemalloc-3.6.0.tar.bz2" | sha256sum -c
tar --strip-components=1 -xjf jemalloc-3.6.0.tar.bz2
./configure --prefix=/usr && make && make install
cd / && rm -rf /jemalloc-stable

# jemalloc new
mkdir /jemalloc-new
cd /jemalloc-new

wget -q https://github.com/jemalloc/jemalloc/releases/download/5.2.1/jemalloc-5.2.1.tar.bz2
sha256sum jemalloc-5.2.1.tar.bz2
echo "34330e5ce276099e2e8950d9335db5a875689a4c6a56751ef3b1d8c537f887f6 jemalloc-5.2.1.tar.bz2" | sha256sum -c
tar --strip-components=1 -xjf jemalloc-5.2.1.tar.bz2 
./configure --prefix=/usr --with-install-suffix=5.2.1 && make build_lib && make install_lib
cd / && rm -rf /jemalloc-new
