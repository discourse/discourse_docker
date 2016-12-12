# NAME:     discourse/discourse_dev
# VERSION:  1.3.9
FROM discourse/base:1.3.9

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

# Create discourse user and /var/www location for both
# discourse and dev images.
RUN useradd discourse -s /bin/bash -m -U &&\
    mkdir -p /var/www

# Give discourse user no-passwd sudo permissions (for bundle install)
ADD sudoers.discourse /etc/sudoers.d/discourse

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

# add dev databases
ADD postgres_dev.template.yml /pups/postgres_dev.yml
RUN /pups/bin/pups /pups/postgres_dev.yml

# move default postgres_data out of the way
RUN mv /shared/postgres_data /shared/postgres_data_orig

# re-instantiate data on boot if needed (this will allow it to persist across
# invocations when used with a mounted volume)
ADD ensure-database /etc/runit/1.d/ensure-database
