# NAME:     discourse/base
# VERSION:  release
FROM ubuntu:16.04

ENV PG_MAJOR 10
ENV RUBY_ALLOCATOR /usr/lib/libjemalloc.so.1
ENV COMPRESS_BROTLI 1

#LABEL maintainer="Sam Saffron \"https://twitter.com/samsaffron\""

RUN echo 2.0.`date +%Y%m%d` > /VERSION

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
RUN curl --silent --location https://deb.nodesource.com/setup_8.x | sudo bash -
RUN apt-get -y update
RUN apt-get -y install build-essential git wget \
                       libxslt-dev libcurl4-openssl-dev \
                       libssl-dev libyaml-dev libtool \
                       libxml2-dev gawk parallel \
                       postgresql-${PG_MAJOR} postgresql-client-${PG_MAJOR} \
                       postgresql-contrib-${PG_MAJOR} libpq-dev libreadline-dev \
                       language-pack-en cron anacron \
                       psmisc rsyslog vim whois brotli libunwind-dev \
                       libtcmalloc-minimal4
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
    npm install -g uglify-js@"<3" &&\
    npm install -g svgo &&\
    npm install -g prettier@1.14.0

ADD install-nginx /tmp/install-nginx
RUN /tmp/install-nginx

RUN apt-get -y install advancecomp jhead jpegoptim libjpeg-turbo-progs optipng

RUN mkdir /jemalloc-stable && cd /jemalloc-stable &&\
      wget https://github.com/jemalloc/jemalloc/releases/download/3.6.0/jemalloc-3.6.0.tar.bz2 &&\
      tar -xjf jemalloc-3.6.0.tar.bz2 && cd jemalloc-3.6.0 && ./configure --prefix=/usr && make && make install &&\
      cd / && rm -rf /jemalloc-stable

RUN mkdir /jemalloc-new && cd /jemalloc-new &&\
      wget https://github.com/jemalloc/jemalloc/releases/download/5.1.0/jemalloc-5.1.0.tar.bz2 &&\
      tar -xjf jemalloc-5.1.0.tar.bz2 && cd jemalloc-5.1.0 && ./configure --prefix=/usr --with-install-suffix=5.1.0 && make build_lib && make install_lib &&\
      cd / && rm -rf /jemalloc-new

RUN echo 'gem: --no-document' >> /usr/local/etc/gemrc &&\
    mkdir /src && cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    cd /src/ruby-build && ./install.sh &&\
    cd / && rm -rf /src/ruby-build && (ruby-build 2.5.1 /usr/local)

RUN gem update --system

RUN gem install bundler --force &&\
    rm -rf /usr/local/share/ri/2.5.1/system &&\
    cd / && git clone https://github.com/discourse/pups.git

ADD install-imagemagick /tmp/install-imagemagick
RUN /tmp/install-imagemagick

# Validate install
RUN ruby -Eutf-8 -e "v = \`convert -version\`; %w{png tiff jpeg freetype}.each { |f| unless v.include?(f); STDERR.puts('no ' + f +  ' support in imagemagick'); exit(-1); end }"

ADD install-pngcrush /tmp/install-pngcrush
RUN /tmp/install-pngcrush

ADD install-gifsicle /tmp/install-gifsicle
RUN /tmp/install-gifsicle

ADD install-pngquant /tmp/install-pngquant
RUN /tmp/install-pngquant

# This tool allows us to disable huge page support for our current process
# since the flag is preserved through forks and execs it can be used on any
# process
ADD thpoff.c /src/thpoff.c
RUN gcc -o /usr/local/sbin/thpoff /src/thpoff.c && rm /src/thpoff.c

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


# Discourse specific bits
RUN useradd discourse -s /bin/bash -m -U &&\
    mkdir -p /var/www &&\
    cd /var/www &&\
    git clone https://github.com/discourse/discourse.git &&\
    cd discourse &&\
    git remote set-branches --add origin tests-passed &&\
    chown -R discourse:discourse /var/www/discourse &&\
    cd /var/www/discourse &&\
    sudo -u discourse bundle install --deployment \
         --without test --without development &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +
