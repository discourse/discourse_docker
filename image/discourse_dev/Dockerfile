FROM samsaffron/discourse_fast_switch:1.0.13

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN use_22
RUN rm -fr /usr/local/include/ruby-2.0.0

RUN chown -R discourse:discourse /usr/ruby_22

RUN rm /var/www/discourse/.bundle/config

RUN cd /var/www/discourse && git pull && sudo -u discourse bundle install
RUN use_22

# CLEANUP
RUN rm -fr /var/www/discourse/vendor/bundle/ruby
RUN rm -fr /usr/ruby_20


# get redis going
ADD redis.template.yml /pups/redis.yml
RUN /pups/bin/pups /pups/redis.yml

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# get postgres going
ADD postgres.template.yml /pups/postgres.yml
RUN LANG=en_US.UTF-8 /pups/bin/pups /pups/postgres.yml

# move pg out of the way
RUN mv /shared/postgres_data /shared/postgres_data_orig

# We got gems ... we need no source in the image ...
RUN rm -fr /var/www/discourse

ADD ensure-database /etc/runit/1.d/ensure-database
