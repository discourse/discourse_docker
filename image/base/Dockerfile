# NAME:     discourse/base
# VERSION:  1.3.7
FROM ubuntu:16.04

ENV PG_MAJOR 9.5
ENV PG_VERSION 9.5.4-1.pgdg16.04+2

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN echo "1.3.7" > /VERSION

RUN apt-get update && apt-get install -y lsb-release sudo curl
RUN echo "debconf debconf/frontend select Teletype" | debconf-set-selections
RUN echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main restricted universe" > /etc/apt/sources.list
RUN echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-updates main restricted universe" >> /etc/apt/sources.list
RUN echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-security main restricted universe" >> /etc/apt/sources.list
RUN apt-get update && apt-get -y install fping
RUN sh -c "fping proxy && echo 'Acquire { Retries \"0\"; HTTP { Proxy \"http://proxy:3128\";}; };' > /etc/apt/apt.conf.d/40proxy && apt-get update || true"
RUN apt-get -y install software-properties-common
RUN apt-mark hold initscripts
RUN apt-get -y upgrade
RUN curl http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" | \
        tee /etc/apt/sources.list.d/postgres.list
RUN curl --silent --location https://deb.nodesource.com/setup_4.x | sudo bash -
RUN apt-get -y update
RUN apt-get -y install build-essential git wget \
                       libxslt-dev libcurl4-openssl-dev \
                       libssl-dev libyaml-dev libtool \
                       libxml2-dev gawk parallel \
                       postgresql-${PG_MAJOR}=${PG_VERSION} postgresql-client-${PG_MAJOR}=${PG_VERSION} \
                       postgresql-contrib-${PG_MAJOR}=${PG_VERSION} libpq-dev libreadline-dev \
                       language-pack-en cron anacron \
                       psmisc rsyslog vim whois brotli
RUN sed -i -e 's/start -q anacron/anacron -s/' /etc/cron.d/anacron
RUN sed -i.bak 's/$ModLoad imklog/#$ModLoad imklog/' /etc/rsyslog.conf
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN sh -c "test -f /sbin/initctl || ln -s /bin/true /sbin/initctl"
RUN apt-get -y install redis-server haproxy openssh-server
RUN cd / &&\
    apt-get -y install runit monit socat &&\
    mkdir -p /etc/runit/1.d &&\
    apt-get clean &&\
    rm -f /etc/apt/apt.conf.d/40proxy &&\
    locale-gen en_US &&\
    apt-get install -y nodejs &&\
    npm install uglify-js -g &&\
    npm install svgo -g

ADD install-nginx /tmp/install-nginx
RUN /tmp/install-nginx

RUN apt-get -y install advancecomp jhead jpegoptim libjpeg-turbo-progs optipng


# consider upgrading this
RUN mkdir /jemalloc && cd /jemalloc &&\
      wget http://www.canonware.com/download/jemalloc/jemalloc-3.6.0.tar.bz2 &&\
      tar -xjf jemalloc-3.6.0.tar.bz2 && cd jemalloc-3.6.0 && ./configure && make &&\
      mv lib/libjemalloc.so.1 /usr/lib && cd / && rm -rf /jemalloc

RUN echo 'gem: --no-document' >> /usr/local/etc/gemrc &&\
    mkdir /src && cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    cd /src/ruby-build && ./install.sh &&\
    cd / && rm -rf /src/ruby-build && ruby-build 2.3.1 /usr/local

RUN gem install bundler &&\
    rm -rf /usr/local/share/ri/2.3.0/system &&\
    cd / && git clone https://github.com/SamSaffron/pups.git

ADD install-imagemagick /tmp/install-imagemagick
RUN /tmp/install-imagemagick

# Validate install
RUN ruby -e "v='`convert -version`'; ['png','tiff','jpeg','freetype'].each{ |f| ((STDERR.puts('no ' + f +  ' support in imagemagick')); exit(-1)) unless v.include?(f)}"

#
ADD install-pngcrush /tmp/install-pngcrush
RUN /tmp/install-pngcrush

ADD install-gifsicle /tmp/install-gifsicle
RUN /tmp/install-gifsicle

ADD install-pngquant /tmp/install-pngquant
RUN /tmp/install-pngquant

ADD phantomjs /usr/local/bin/phantomjs

# Not using the official repo until they compile against a recent openssl
# RUN cd tmp && wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2
# RUN cd tmp && tar jxf phantomjs-2.1.1-linux-x86_64.tar.bz2 && mv /tmp/phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin

# clean up for docker squash
RUN   rm -fr /usr/share/man &&\
      rm -fr /usr/share/doc &&\
      rm -fr /usr/share/vim/vim74/tutor &&\
      rm -fr /usr/share/vim/vim74/doc &&\
      rm -fr /usr/share/vim/vim74/lang &&\
      rm -fr /usr/local/share/doc &&\
      rm -fr /usr/local/share/ruby-build &&\
      rm -fr /root/.gem &&\
      rm -fr /root/.npm &&\
      rm -fr /tmp/* &&\
      rm -fr /usr/share/vim/vim74/spell/en*


# this can probably be done, but I worry that people changing PG locales will have issues
# cd /usr/share/locale && rm -fr `ls -d */ | grep -v en`

RUN mkdir -p /etc/runit/3.d

ADD runit-1 /etc/runit/1
ADD runit-1.d-cleanup-pids /etc/runit/1.d/cleanup-pids
ADD runit-1.d-anacron /etc/runit/1.d/anacron
ADD runit-1.d-00-fix-var-logs /etc/runit/1.d/00-fix-var-logs
ADD runit-2 /etc/runit/2
ADD runit-3 /etc/runit/3
ADD boot /sbin/boot

ADD cron /etc/service/cron/run
ADD rsyslog /etc/service/rsyslog/run
ADD cron.d_anacron /etc/cron.d/anacron

# Create discourse user and /var/www location for both
# discourse and dev images.
RUN useradd discourse -s /bin/bash -m -U &&\
    mkdir -p /var/www
