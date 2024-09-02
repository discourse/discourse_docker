ARG from=discourse/base
ARG tag=build_slim

FROM $from:$tag

ENV RAILS_ENV=production

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle config --local deployment true &&\
    sudo -u discourse bundle config --local path ./vendor/bundle &&\
    sudo -u discourse bundle config --local without test development &&\
    sudo -u discourse bundle install --jobs $(($(nproc) - 1)) &&\
    sudo -u discourse /bin/bash -c 'if [ -f yarn.lock ]; then; yarn install --frozen-lockfile && yarn cache clean; else; pnpm install --frozen-lockfile; fi' &&\
    find /var/www/discourse/vendor/bundle -name cache -not -path '*/gems/*' -type d -exec rm -rf {} + &&\
    find /var/www/discourse/vendor/bundle -name tmp -type d -exec rm -rf {} +
