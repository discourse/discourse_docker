# Current version 1.0.12
FROM samsaffron/discourse_base:1.0.12

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

# Discourse specific bits
RUN useradd discourse -s /bin/bash -m -U &&\
    mkdir -p /var/www && cd /var/www &&\
     git clone https://github.com/discourse/discourse.git &&\
     cd discourse &&\
      git remote set-branches --add origin tests-passed &&\
    chown -R discourse:discourse /var/www/discourse &&\
    cd /var/www/discourse &&\
     sudo -u discourse bundle install --deployment \
         --without test --without development &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +


# For a smaller but less flexible image:
#RUN apt-get -y autoremove build-essential gcc gcc-4.7 .+-dev
#RUN echo image size: $(du -hsx /)
