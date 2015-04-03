# Official repo only has a ppa for postgresql 9.3 at the moment (14/3/2014)
# When new LTS ships we can upgrade

# VERSION 0.1.0
FROM samsaffron/discourse_base:1.0.9

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN apt-get -y install ruby bison autoconf &&\
    echo install_package "openssl-1.0.1l" "https://www.openssl.org/source/openssl-1.0.1l.tar.gz#b2cf4d48fe5d49f240c61c9e624193a6f232b5ed0baf010681e725963c40d1d4" mac_openssl --if has_broken_mac_openssl > /src/2.2.2-github &&\
    echo install_package "ruby-2.2.2-github" "https://github.com/SamSaffron/ruby/archive/2.2.2-github.tar.gz#407654b4fe9dd61ca7e26d8d7e4c8631" autoconf ldflags_dirs standard verify_openssl >> /src/2.2.2-github &&\
    ruby-build /src/2.2.2-github /usr/local &&\
    apt-get -y remove ruby &&\
    gem update --system &&\
    gem install bundler &&\
    rm -fr /src/ruby-build
