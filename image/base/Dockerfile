# Official repo only has a ppa for postgresql 9.3 at the moment (14/3/2014)
# When new LTS ships we can upgrade

# NAME:     discourse_base
# VERSION:  1.0.14

FROM ubuntu:14.04

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN echo "debconf debconf/frontend select Teletype" | debconf-set-selections &&\
    echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main restricted universe" > /etc/apt/sources.list &&\
    echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-updates main restricted universe" >> /etc/apt/sources.list &&\
    echo "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc)-security main restricted universe" >> /etc/apt/sources.list &&\
    apt-get update && apt-get -y install fping &&\
    sh -c "fping proxy && echo 'Acquire { Retries \"0\"; HTTP { Proxy \"http://proxy:3128\";}; };' > /etc/apt/apt.conf.d/40proxy && apt-get update || true" &&\
    apt-get -y install software-properties-common &&\
    apt-mark hold initscripts &&\
    apt-get -y upgrade &&\
    add-apt-repository -y ppa:rwky/redis &&\
    add-apt-repository -y ppa:nginx/development &&\
    apt-get install -y curl && curl http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add - &&\
    echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" | \
        tee /etc/apt/sources.list.d/postgres.list &&\
    curl --silent --location https://deb.nodesource.com/setup_4.x | sudo bash - &&\
    apt-get -y update &&\
    apt-get -y install build-essential git curl wget \
                       libxslt-dev libcurl4-openssl-dev \
                       libssl-dev libyaml-dev libtool \
                       libxml2-dev gawk \
                       postgresql-9.3 postgresql-client-9.3 \
                       postgresql-contrib-9.3 libpq-dev libreadline-dev \
                       nginx language-pack-en sudo cron anacron \
                       psmisc rsyslog vim whois &&\
    sed -i -e 's/start -q anacron/anacron -s/' /etc/cron.d/anacron &&\
    sed -i.bak 's/$ModLoad imklog/#$ModLoad imklog/' /etc/rsyslog.conf &&\
    dpkg-divert --local --rename --add /sbin/initctl &&\
    sh -c "test -f /sbin/initctl || ln -s /bin/true /sbin/initctl" &&\
    apt-get -y install redis-server haproxy openssh-server &&\
    cd / &&\
    apt-get -y install runit monit socat &&\
    mkdir -p /etc/runit/1.d &&\
    apt-get clean &&\
    rm -f /etc/apt/apt.conf.d/40proxy &&\
    locale-gen en_US &&\
    wget http://static.jonof.id.au/dl/kenutils/pngout-20150319-linux.tar.gz &&\
      tar -xf pngout-20150319-linux.tar.gz &&\
      rm pngout-20150319-linux.tar.gz &&\
      cp pngout-20150319-linux/x86_64/pngout /bin/pngout &&\
      rm -rf pngout-20150319-linux &&\
    apt-get install -y nodejs &&\
    npm install uglify-js -g &&\
    npm install svgo -g &&\
    apt-get -y install advancecomp jhead jpegoptim libjpeg-progs optipng

# TODO check when binary packages are ready (not yet)
RUN wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.8-linux-x86_64.tar.bz2 &&\
      tar -xjf phantomjs-1.9.8-linux-x86_64.tar.bz2 &&\
      rm phantomjs-1.9.8-linux-x86_64.tar.bz2 &&\
      cp phantomjs-1.9.8-linux-x86_64/bin/phantomjs /bin/phantomjs &&\
      rm -fr phantomjs-1.9.8-linux-x86_64

RUN mkdir /jemalloc && cd /jemalloc &&\
      wget http://www.canonware.com/download/jemalloc/jemalloc-3.6.0.tar.bz2 &&\
      tar -xjf jemalloc-3.6.0.tar.bz2 && cd jemalloc-3.6.0 && ./configure && make &&\
      mv lib/libjemalloc.so.1 /usr/lib && cd / && rm -rf /jemalloc

ADD install-imagemagick /tmp/install-imagemagick
RUN /tmp/install-imagemagick

ADD install-pngcrush /tmp/install-pngcrush
RUN /tmp/install-pngcrush

ADD install-gifsicle /tmp/install-gifsicle
RUN /tmp/install-gifsicle

ADD install-pngquant /tmp/install-pngquant
RUN /tmp/install-pngquant

RUN add-apt-repository ppa:ubuntu-toolchain-r/test &&\
    apt-get update &&\
    apt-get install -y gcc-4.9 &&\
    (cd /usr/bin && rm gcc && ln -s gcc-4.9 gcc) &&\
    echo 'gem: --no-document' >> /usr/local/etc/gemrc &&\
    mkdir /src && cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    cd /src/ruby-build && ./install.sh &&\
    cd / && rm -rf /src/ruby-build && ruby-build 2.0.0-p647 /usr/local &&\
    gem update --system &&\
    gem install bundler &&\
    rm -rf /usr/local/share/ri/2.0.0/system &&\
    cd / && git clone https://github.com/SamSaffron/pups.git

# clean up for docker squash
RUN rm -fr /usr/share/man && rm -fr /usr/share/doc && mkdir -p /etc/runit/3.d

ADD runit-1 /etc/runit/1
ADD runit-1.d-cleanup-pids /etc/runit/1.d/cleanup-pids
ADD runit-1.d-anacron /etc/runit/1.d/anacron
ADD runit-2 /etc/runit/2
ADD runit-3 /etc/runit/3
ADD boot /sbin/boot

ADD cron /etc/service/cron/run
ADD rsyslog /etc/service/rsyslog/run
