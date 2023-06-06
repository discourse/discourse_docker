ARG from=discourse/base
ARG tag=build_slim

FROM $from:$tag

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle config --local deployment true &&\
    sudo -u discourse bundle config --local path ./vendor/bundle &&\
    sudo -u discourse bundle config --local without test development &&\
    sudo -u discourse bundle install --jobs 4 &&\
    sudo -u discourse yarn install --frozen-lockfile &&\
    sudo -u discourse yarn cache clean &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +
