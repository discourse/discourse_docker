# Current version 2.1.2.2
FROM samsaffron/discourse_base_21:2.1.2.1

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN useradd discourse -s /bin/bash -m -U &&\
    mkdir /var/www && cd /var/www &&\
     git clone https://github.com/discourse/discourse.git &&\
     cd discourse &&\
     git remote set-branches origin tests-passed &&\
     cd .. &&\
     chown -R discourse:discourse /var/www/discourse &&\
    cd /var/www/discourse &&\
     sudo -u discourse RAILS4=1 bundle install --deployment \
         --without test --without development &&\
    cd /var/www/discourse/vendor/bundle &&\
       find . -name tmp -type d | xargs rm -rf && cd / &&\
      wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2 &&\
      tar -xjf phantomjs-1.9.7-linux-x86_64.tar.bz2 &&\
      rm phantomjs-1.9.7-linux-x86_64.tar.bz2 &&\
      cp phantomjs-1.9.7-linux-x86_64/bin/phantomjs /bin/phantomjs &&\
      rm -fr phantomjs-1.9.7-linux-x86_64
