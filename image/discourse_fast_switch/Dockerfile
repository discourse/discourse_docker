# Allow to easily switch Ruby version in images that derive off this

FROM samsaffron/discourse:1.0.10

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN apt-get -y install ruby bison autoconf &&\
    echo install_package "openssl-1.0.1l" "https://www.openssl.org/source/openssl-1.0.1l.tar.gz#b2cf4d48fe5d49f240c61c9e624193a6f232b5ed0baf010681e725963c40d1d4" mac_openssl --if has_broken_mac_openssl > /src/2.2.2-github &&\
    echo install_package "ruby-2.2.2-github" "https://github.com/SamSaffron/ruby/archive/2.2.2-github.tar.gz#407654b4fe9dd61ca7e26d8d7e4c8631" autoconf ldflags_dirs standard verify_openssl >> /src/2.2.2-github &&\
    ruby-build /src/2.2.2-github /usr/ruby_22 &&\
    apt-get -y remove ruby

RUN cd / && rm -rf /src/ruby-build && ruby-build 2.0.0-p643 /usr/ruby_20

ADD create_switch.rb /src/create_switch.rb
RUN ruby /src/create_switch.rb
