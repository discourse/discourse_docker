ARG from=discourse/base
ARG tag=build_slim
ARG SSH_KEY
ENV SSH_KEY=$SSH_KEY

FROM $from:$tag

ENV RAILS_ENV=production

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle config --local deployment true &&\
    sudo -u discourse bundle config --local path ./vendor/bundle &&\
    sudo -u discourse bundle config --local without test development &&\
    sudo -u discourse bundle config --local jobs 4 && \
    sudo -u discourse bundle install &&\
    sudo -u discourse yarn install --frozen-lockfile &&\
    sudo -u discourse yarn cache clean &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +
