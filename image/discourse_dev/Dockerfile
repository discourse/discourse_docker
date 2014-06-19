FROM samsaffron/discourse_21:2.1.2.1

MAINTAINER Sam Saffron "https://twitter.com/samsaffron"

RUN apt-get install -y vim &&\
      wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2
RUN tar -xjf phantomjs-1.9.7-linux-x86_64.tar.bz2
RUN rm phantomjs-1.9.7-linux-x86_64.tar.bz2
RUN cp phantomjs-1.9.7-linux-x86_64/bin/phantomjs /bin/phantomjs
RUN rm -fr phantomjs-1.9.7-linux-x86_64
RUN cd opt && git clone https://github.com/SamSaffron/vim-setup.git
RUN cd opt/vim-setup && git submodule update --init
RUN ln -s /opt/vim-setup/vimrc /etc/vim/vimrc.local
RUN ln -s /opt/vim-setup/vimfiles/bundle /etc/vim/bundle
RUN apt-get -y install ctags
RUN apt-get -y install silversearcher-ag
RUN cd /var/www/discourse && rm -fr .bundle && sudo -u discourse bundle install --standalone
