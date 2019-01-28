# NAME:     discourse/discourse_bench
# VERSION:  1.4.0
FROM discourse/discourse_test:1.4.0

#LABEL maintainer="Gerhard Schlager <mail@gerhard-schlager.at>"

# Install ApacheBench
RUN apt-get install -y apache2-utils libsqlite3-dev

RUN git pull &&\
    sudo -u discourse bundle install --standalone

RUN gem install facter &&\
    gem install mailcatcher

# reconfigure PostgreSQL template databases to use UTF-8
# otherwise rake db:create fails
RUN pg_dropcluster --stop 9.5 main &&\
    pg_createcluster --start -e UTF-8 9.5 main

# create role "discourse"
RUN /etc/init.d/postgresql start &&\
    sleep 5 &&\
    sudo -u postgres createuser --superuser discourse

ADD run_bench.sh /tmp/run_bench.sh
RUN chmod +x /tmp/run_bench.sh

ENTRYPOINT ["/tmp/run_bench.sh"]
