ARG tag=build_slim

FROM discourse/base:$tag

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle install --deployment --jobs 4 --without test development &&\
    sudo -u discourse yarn install --production &&\
    sudo -u discourse yarn cache clean &&\
    bundle exec rake maxminddb:get &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +
