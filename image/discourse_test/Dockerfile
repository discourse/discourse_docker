# NAME:     discourse/discourse_test
# VERSION:  release
ARG tag=build
FROM discourse/base:$tag

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN gem update bundler --force &&\
      cd /var/www/discourse &&\
      chown -R discourse . &&\
      rm -fr .bundle &&\
      sudo -u discourse git pull &&\
      sudo -u discourse bundle install --standalone &&\
      chown -R discourse /var/run/postgresql

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - &&\
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list &&\
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - &&\
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list &&\
    apt-get update &&\
    apt-get install -y google-chrome-stable yarn &&\
    npm install -g eslint babel-eslint &&\
    cd /var/www/discourse && yarn install

WORKDIR /var/www/discourse
ENV LANG en_US.UTF-8
ENTRYPOINT sudo -E -u discourse -H ruby script/docker_test.rb
