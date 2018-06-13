# NAME:     discourse/discourse_fast_switch
# VERSION:  1.5.0

# Allow to easily switch Ruby version in images that derive off this
FROM discourse/base:2.0.20180608

#LABEL maintainer="Sam Saffron \"https://twitter.com/samsaffron\""

RUN apt-get -y install ruby bison autoconf &&\
    cd /src && git clone https://github.com/sstephenson/ruby-build.git &&\
    /src/ruby-build/install.sh &&\
    sudo ruby-build 2.4.4 /usr/ruby_24 &&\
    cp -R /usr/ruby_24/bin/* /usr/local/bin/ &&\
    cp -R /usr/ruby_24/lib/* /usr/local/lib/ &&\
    cp -R /usr/ruby_24/share/* /usr/local/share/ &&\
    cp -R /usr/ruby_24/include/* /usr/local/include/ &&\
    apt-get -y remove ruby

RUN cd / && ruby-build 2.5.1 /usr/ruby_25

ADD create_switch.rb /src/create_switch.rb

RUN ruby /src/create_switch.rb
