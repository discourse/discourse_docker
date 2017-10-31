# Used to gather information about CPU and memory
#  reporting it back to statsd

# samsaffron/discourse_monitor
# version 0.0.2

FROM samsaffron/discourse_base:1.0.7
#LABEL maintainer="Sam Saffron \"https://twitter.com/samsaffron\""

ADD src/monitor.rb src/monitor.rb
RUN gem install statsd-ruby docker-api

CMD ruby src/monitor.rb
