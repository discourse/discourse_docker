#!/bin/bash
set -e

RUBY_VERSION="2.7.6"

mkdir /src
git -C /src clone https://github.com/rbenv/ruby-build.git
cd /src/ruby-build && ./install.sh
cd / && rm -fr /src

ruby-build ${RUBY_VERSION} /usr/local
