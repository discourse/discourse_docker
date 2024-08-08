#!/bin/bash

# start Redis-Server
redis-server /etc/redis/redis.conf

# start PostgreSQL
/etc/init.d/postgresql start

# get latest source
git pull

# install needed gems
sudo -E -u discourse bundle install --jobs $(($(nproc) - 1))

# start mailcatcher
mailcatcher --http-ip 0.0.0.0

# run the benchmark
sudo -E -u discourse ruby script/bench.rb
