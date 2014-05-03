# DOCKER-VERSION 0.6.7 : samsaffron/discourse_base

# Official repo only has a ppa for postgresql 9.3 at the moment (14/3/2014)
# When new LTS ships we can upgrade

# VERSION 0.2.0
FROM ubuntu:12.04

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN echo "debconf debconf/frontend select Teletype" | debconf-set-selections &&\
    apt-get -y install fping &&\
    sh -c "fping proxy && echo 'Acquire { Retries \"0\"; HTTP { Proxy \"http://proxy:3128\";}; };' > /etc/apt/apt.conf.d/40proxy || true" &&\
    apt-get -y update &&\
    apt-get -y install python-software-properties &&\
    add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main universe" &&\
    add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-updates main universe" &&\
    apt-get -y update &&\
    apt-mark hold initscripts &&\
    apt-get -y upgrade &&\
    add-apt-repository -y ppa:rwky/redis &&\
    add-apt-repository -y ppa:nginx/stable &&\
    apt-get install -y curl && curl http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add - &&\
    echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" | \
    tee /etc/apt/sources.list.d/postgres.list &&\
    apt-get -y update &&\
    apt-get -y install build-essential git curl wget \
                       libxslt-dev libcurl4-openssl-dev \
                       libssl-dev libyaml-dev libtool \
                       libxml2-dev gawk \
                       pngcrush imagemagick \
                       postgresql-9.3 postgresql-client-9.3 \
                       postgresql-contrib-9.3 libpq-dev libreadline-dev \
                       nginx language-pack-en sudo cron \
                       psmisc rsyslog &&\
    dpkg-divert --local --rename --add /sbin/initctl &&\
    sh -c "test -f /sbin/initctl || ln -s /bin/true /sbin/initctl" &&\
    apt-get -y install redis-server haproxy openssh-server &&\
    echo 'gem: --no-document' >> /usr/local/etc/gemrc &&\
    mkdir /src && cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    cd /src/ruby-build && ./install.sh &&\
    cd / && rm -rf /src/ruby-build &&\
    echo install_package "yaml-0.1.6" "http://pyyaml.org/download/libyaml/yaml-0.1.6.tar.gz#5fe00cda18ca5daeb43762b80c38e06e" --if needs_yaml > /src/2.1.1.discourse &&\
    echo install_package "openssl-1.0.1g" "https://www.openssl.org/source/openssl-1.0.1g.tar.gz#de62b43dfcd858e66a74bee1c834e959" mac_openssl --if has_broken_mac_openssl >> /src/2.1.1.discourse &&\
    echo install_package "ruby-2.1.1_discourse" "https://github.com/SamSaffron/ruby/archive/v2.1.1_discourse.tar.gz#08f9d27173ffb481c30ca3088b222b9c" ldflags_dirs standard verify_openssl >> /src/2.1.1.discourse &&\
    apt-get -y install ruby bison &&\
    ruby-build /src/2.1.1.discourse /usr/local &&\
    apt-get -y remove ruby1.8 &&\
    gem update --system &&\
    gem install bundler &&\
    cd / && git clone https://github.com/SamSaffron/pups.git &&\
    mkdir /jemalloc && cd /jemalloc &&\
      wget http://www.canonware.com/download/jemalloc/jemalloc-3.4.1.tar.bz2 &&\
      tar -xvjf jemalloc-3.4.1.tar.bz2 && cd jemalloc-3.4.1 && ./configure && make &&\
      mv lib/libjemalloc.so.1 /usr/lib && cd / && rm -rf /jemalloc &&\
    apt-get -y install runit monit socat &&\
    apt-get clean &&\
    rm -f /etc/apt/apt.conf.d/40proxy &&\
    locale-gen en_US
