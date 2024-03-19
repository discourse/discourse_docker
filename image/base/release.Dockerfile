ARG from=discourse/base
ARG tag=build_slim

FROM $from:$tag

ENV RAILS_ENV=production

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle config --local deployment true &&\
    sudo -u discourse bundle config --local path ./vendor/bundle &&\
    sudo -u discourse bundle config --local without test development &&\
    sudo -u discourse bundle config --local jobs $(($(nproc) - 1)) && \
    sudo -u discourse bundle install &&\
    sudo -u discourse yarn install --frozen-lockfile &&\
    sudo -u discourse yarn cache clean &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +
