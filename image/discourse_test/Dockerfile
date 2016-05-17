FROM discourse/discourse_fast_switch:1.0.18

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN use_23 &&\
      gem update bundler &&\
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
