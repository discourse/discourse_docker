ARG from_tag=build

FROM discourse/base:$from_tag AS base
ENV RAILS_ENV test

WORKDIR /var/www/discourse
ENV LANG en_US.UTF-8
ENTRYPOINT sudo -E -u discourse -H ruby script/docker_test.rb

# configure Git to suppress warnings
RUN sudo -E -u discourse -H git config --global user.email "you@example.com" &&\
    sudo -E -u discourse -H git config --global user.name "Your Name"

RUN chown -R discourse . &&\
    chown -R discourse /var/run/postgresql &&\
    bundle config unset deployment &&\
    bundle config unset without

FROM base AS with_browsers

RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - &&\
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list &&\
    apt update &&\
    apt install -y libgconf-2-4 libxss1 google-chrome-stable firefox-esr &&\
    cd /tmp && wget -q "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US" -O firefox.tar.bz2 &&\
    tar xjvf firefox.tar.bz2 && mv /tmp/firefox /opt/firefox-evergreen &&\
    apt clean

FROM with_browsers AS release

RUN cd /var/www/discourse &&\
    sudo -u discourse bundle install --jobs=4 &&\
    sudo -E -u discourse -H yarn install &&\
    sudo -u discourse yarn cache clean

RUN cd /var/www/discourse && sudo -E -u discourse -H bundle exec rake plugin:install_all_official &&\
    sudo -E -u discourse -H bundle exec rake plugin:install_all_gems
