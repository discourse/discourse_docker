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
      rm -fr .bundle &&\
      sudo -u discourse git pull &&\
      sudo -u discourse bundle install --standalone --jobs=4

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - &&\
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list &&\
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - &&\
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list &&\
    apt update &&\
    apt install -y libgconf-2-4 libxss1 google-chrome-stable yarn nodejs &&\
    npm install -g eslint babel-eslint &&\
    cd /var/www/discourse && sudo -E -u discourse -H yarn install

RUN cd /var/www/discourse && sudo -E -u discourse -H bundle exec rake plugin:install_all_official &&\
    sudo -E -u discourse -H bundle exec rake plugin:install_all_gems &&\
    chown -R discourse /var/run/postgresql

WORKDIR /var/www/discourse
ENV LANG en_US.UTF-8
ENTRYPOINT sudo -E -u discourse -H ruby script/docker_test.rb
