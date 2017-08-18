# NAME:     discourse/discourse_test
# VERSION:  release
ARG tag=build
FROM discourse/base:$tag

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN gem update bundler &&\
      cd /var/www/discourse &&\
      chown -R discourse . &&\
      rm -fr .bundle &&\
      sudo -u discourse git pull &&\
      sudo -u discourse bundle install --standalone &&\
      chown -R discourse /var/run/postgresql

RUN npm install -g eslint babel-eslint

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - &&\
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list &&\
    apt-get update &&\
    apt-get install -y google-chrome-stable

RUN sudo -E -u discourse -H npm install chrome-launcher chrome-remote-interface

WORKDIR /var/www/discourse
ENV LANG en_US.UTF-8
ENTRYPOINT sudo -E -u discourse -H ruby script/docker_test.rb
