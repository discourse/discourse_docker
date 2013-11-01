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
                    nginx wget language-pack-en sudo &&\
    dpkg-divert --local --rename --add /sbin/initctl &&\
    ln -s /bin/true /sbin/initctl &&\
    apt-get install -y redis-server &&\
    apt-get install -y haproxy openssh-server &&\
    mkdir /src && cd /src &&\
    git clone https://github.com/sstephenson/ruby-build.git &&\
    cd ruby-build && \
    /src/ruby-build/install.sh &&\
    cd / &&\
    rm -rf /src/ruby-build &&\
    ruby-build 2.0.0-p247 /usr/local &&\
    gem update --system &&\
    gem install bundler &&\
    useradd discourse &&\
    mkdir /var/www &&\
    cd /var/www &&\
    git clone https://github.com/discourse/discourse.git &&\
    chown -R discourse /var/www/discourse &&\
    cd /var/www/discourse &&\
    sudo -u discourse RAILS4=1 bundle install --deployment &&\
    apt-get install -y runit &&\
    locale-gen en_US

# RUN cd /var/www/discourse && bundle exec rake db:test:prepare && bundle exec rspec

# mkdir -p /src/godeb && cd /src/godeb && curl -O https://godeb.s3.amazonaws.com/godeb-amd64.tar.gz &&\
# cd /src/godeb && tar -xzvf godeb-amd64.tar.gz &&\
# cd /src/godeb && ./godeb install &&\
# cd /src &&  git clone https://github.com/coreos/etcd.git &&\
# cd /src/etcd && ./build &&\
# cp /src/etcd/etcd /usr/local/bin &&\
