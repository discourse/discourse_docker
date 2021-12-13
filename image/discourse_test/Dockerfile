# NAME:     discourse/discourse_test
# VERSION:  release
ARG tag=build
FROM discourse/base:$tag
ENV RAILS_ENV test

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

# configure Git to suppress warnings
RUN sudo -E -u discourse -H git config --global user.email "you@example.com" &&\
    sudo -E -u discourse -H git config --global user.name "Your Name"

RUN gem update bundler --force &&\
      cd /var/www/discourse &&\
      chown -R discourse . &&\
      bundle config unset deployment &&\
      bundle config unset without &&\
      sudo -u discourse git pull &&\
      sudo -u discourse bundle install --jobs=4

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - &&\
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list &&\
    apt update &&\
    apt install -y libgconf-2-4 libxss1 google-chrome-stable firefox-esr &&\
    npm install -g eslint babel-eslint &&\
    cd /tmp && wget "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US" -O firefox.tar.bz2 &&\
    tar xjvf firefox.tar.bz2 && mv /tmp/firefox /opt/firefox-evergreen &&\
    cd /var/www/discourse && sudo -E -u discourse -H yarn install

RUN cd /var/www/discourse && sudo -E -u discourse -H bundle exec rake plugin:install_all_official &&\
    sudo -E -u discourse -H bundle exec rake plugin:install_all_gems &&\
    chown -R discourse /var/run/postgresql

WORKDIR /var/www/discourse
ENV LANG en_US.UTF-8
ENTRYPOINT sudo -E -u discourse -H ruby script/docker_test.rb
