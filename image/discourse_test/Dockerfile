# NAME:     discourse/discourse_test
# VERSION:  1.4.0
FROM discourse/discourse:1.4.0

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN gem update bundler &&\
      cd /var/www/discourse &&\
      chown -R discourse . &&\
      rm -fr .bundle &&\
      sudo -u discourse git pull &&\
      sudo -u discourse bundle install --standalone &&\
      chown -R discourse /var/run/postgresql

RUN npm install -g eslint babel-eslint

WORKDIR /var/www/discourse
ENV LANG en_US.UTF-8
ENTRYPOINT sudo -E -u discourse ruby script/docker_test.rb
