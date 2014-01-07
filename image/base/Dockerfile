# DOCKER-VERSION 0.6.7 : samsaffron/discourse_base

# 13.10 - 04 has a missing ppa for postgresql 9.2 at the moment (26/10/2013)
FROM ubuntu:12.10

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN echo "debconf debconf/frontend select Teletype" | debconf-set-selections &&\
    apt-get -y update &&\
    apt-get -y upgrade &&\
    apt-get -y install software-properties-common &&\
    apt-add-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main universe" &&\
    add-apt-repository -y ppa:rwky/redis &&\
    add-apt-repository -y ppa:nginx/stable &&\
    add-apt-repository -y ppa:pitti/postgresql &&\
    apt-get -y update &&\
    apt-get -y install build-essential git curl wget \
                       libxslt-dev libcurl4-openssl-dev \
                       libssl-dev libyaml-dev libtool \
                       libxml2-dev gawk \
                       pngcrush imagemagick \
                       postgresql-9.2 postgresql-client-9.2 \
                       postgresql-contrib-9.2 libpq-dev libreadline-dev \
                       nginx language-pack-en sudo cron \
                       psmisc &&\
    dpkg-divert --local --rename --add /sbin/initctl &&\
    ln -s /bin/true /sbin/initctl &&\
    apt-get -y install redis-server haproxy openssh-server &&\
    echo 'gem: --no-document' >> /etc/gemrc &&\
    mkdir /src && cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    cd /src/ruby-build && ./install.sh &&\
    cd / && rm -rf /src/ruby-build && ruby-build 2.0.0-p353 /usr/local &&\
    gem update --system &&\
    gem install bundler &&\
    cd / && git clone https://github.com/SamSaffron/pups.git &&\
    mkdir /jemalloc && cd /jemalloc &&\
      wget http://www.canonware.com/download/jemalloc/jemalloc-3.4.1.tar.bz2 &&\
      tar -xvjf jemalloc-3.4.1.tar.bz2 && cd jemalloc-3.4.1 && ./configure && make &&\
      mv lib/libjemalloc.so.1 /usr/lib && cd / && rm -rf /jemalloc &&\
    apt-get -y install runit monit socat &&\
    apt-get clean &&\
    locale-gen en_US
