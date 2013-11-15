# DOCKER-VERSION 0.6.4

# 13.10 - 04 has a missing ppa for postgresql 9.2 at the moment (26/10/2013)
FROM ubuntu:12.10

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN apt-get -y update &&\
    apt-get -y upgrade &&\
    apt-get -y install software-properties-common &&\
    add-apt-repository -y ppa:rwky/redis &&\
    add-apt-repository -y ppa:nginx/stable &&\
    add-apt-repository -y ppa:pitti/postgresql &&\
    add-apt-repository ppa:chris-lea/node.js &&\
    apt-get -y update &&\
    apt-get install -y build-essential git curl libxml2-dev \
                    libxslt-dev libcurl4-openssl-dev \
                    libssl-dev libyaml-dev libtool \
                    libxslt-dev libxml2-dev gawk curl \
                    pngcrush imagemagick \
                    postgresql-9.2 postgresql-client-9.2 \
                    postgresql-contrib-9.2 libpq-dev libreadline-dev \
                    nginx wget language-pack-en sudo cron \
                    psmisc &&\
    dpkg-divert --local --rename --add /sbin/initctl &&\
    ln -s /bin/true /sbin/initctl &&\
    apt-get install -y redis-server haproxy openssh-server &&\
    echo 'gem: --no-document' >> /etc/gemrc &&\
    mkdir /src && cd /src &&\
     git clone https://github.com/sstephenson/ruby-build.git && cd / &&\
    cd /src/ruby-build &&\
     ./install.sh && cd / &&\
    rm -rf /src/ruby-build &&\
    ruby-build 2.0.0-p247 /usr/local &&\
    gem update --system &&\
    gem install bundler --pre &&\
    cd / && git clone https://github.com/SamSaffron/pups.git &&\
    mkdir /jemalloc && cd /jemalloc &&\
      wget http://www.canonware.com/download/jemalloc/jemalloc-3.4.1.tar.bz2 &&\
      tar -xvjf jemalloc-3.4.1.tar.bz2 && cd jemalloc-3.4.1 && ./configure && make &&\
      mv lib/libjemalloc.so.1 /usr/lib && cd / && rm -rf /jemalloc &&\
    apt-get install -y runit && apt-get clean && locale-gen en_US

# Discourse specific bits
RUN useradd discourse -s /bin/bash -m -U &&\
    mkdir /var/www && cd /var/www &&\
     git clone --depth 1 https://github.com/discourse/discourse.git &&\
     chown -R discourse:discourse /var/www/discourse && cd / &&\
    cd /var/www/discourse &&\
     sudo -u discourse RAILS4=1 bundle install -j4 --deployment \
         --without test --without development &&\
    cd /var/www/discourse/vendor/bundle &&\
       find . -name tmp -type d | xargs rm -rf && cd /


# For a smaller but less flexible image:
#RUN apt-get -y autoremove build-essential gcc gcc-4.7 .+-dev
#RUN echo image size: $(du -hsx /)

# RUN cd /var/www/discourse && bundle exec rake db:test:prepare && bundle exec rspec

# mkdir -p /src/godeb && cd /src/godeb && curl -O https://godeb.s3.amazonaws.com/godeb-amd64.tar.gz &&\
# cd /src/godeb && tar -xzvf godeb-amd64.tar.gz &&\
# cd /src/godeb && ./godeb install &&\
# cd /src &&  git clone https://github.com/coreos/etcd.git &&\
# cd /src/etcd && ./build &&\
# cp /src/etcd/etcd /usr/local/bin &&\
