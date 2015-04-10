FROM samsaffron/discourse_22:1.0.0

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN cd /var/www/discourse &&\
      chown -R discourse . &&\
      rm -fr .bundle &&\
      sudo -u discourse git pull &&\
      sudo -u discourse bundle install --standalone &&\
      chown -R discourse /var/run/postgresql

WORKDIR /var/www/discourse
ENV LANG en_US.UTF-8
ENTRYPOINT sudo -E -u discourse ruby script/docker_test.rb
