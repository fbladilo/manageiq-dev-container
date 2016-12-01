FROM centos:7
ENV container docker
MAINTAINER Nimrod Shneor https://github.com/nimrodshn/manageiq-dev-container

# Set ENV, LANG only needed if building with docker-1.8
ENV LANG en_US.UTF-8
ENV TERM xterm

RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

RUN yum -y install                         \
    git-all                                \
    memcached                              \
    postgresql-devel postgresql-server     \
    bzip2 libffi-devel readline-devel      \
    libxml2-devel libxslt-devel patch      \
    sqlite-devel                           \
    gcc-c++                                \
    libcurl-devel                          \
    openssl-devel                          \
    nodejs                                 \
    cmake                                  \
    clean all

RUN npm install -g bower

# Add persistent data volume for postgres
VOLUME [ "/var/opt/rh/rh-postgresql95/lib/pgsql/data" ]

RUN (cd /lib/systemd/system/sysinit.target.wants && for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -vf $i; done) && \
    rm -vf /lib/systemd/system/multi-user.target.wants/* && \
    rm -vf /etc/systemd/system/*.wants/* && \
    rm -vf /lib/systemd/system/local-fs.target.wants/* && \
    rm -vf /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -vf /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -vf /lib/systemd/system/basic.target.wants/* && \
    rm -vf /lib/systemd/system/anaconda.target.wants/*

## Enable Memchached on boot.
RUN /usr/bin/memcached -uroot &
#RUN systemctl enable memcached
#RUN systemctl start memcached

## Enable Postgress
RUN postgresql-setup initdb && \
    grep -q '^local\s' /var/lib/pgsql/data/pg_hba.conf || echo "local all all trust" | tee -a /var/lib/pgsql/data/pg_hba.conf && \
    sed -i.bak 's/\(^local\s*\w*\s*\w*\s*\)\(peer$\)/\1trust/' /var/lib/pgsql/data/pg_hba.conf
    #systemctl enable postgresql && \
    #systemctl start postgresql
    #postgres -D /var/lib/pgsql1/data
    #postgres psql -c "CREATE ROLE root SUPERUSER LOGIN PASSWORD 'smartvm'"

# Download chruby and chruby-install, install, setup environment, clean all
RUN curl -sL https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz | tar xz && \
    cd chruby-0.3.9 && \
    make install && \
    scripts/setup.sh && \
    echo "gem: --no-ri --no-rdoc --no-document" > ~/.gemrc && \
    echo "source /usr/local/share/chruby/chruby.sh" >> ~/.bashrc && \
    curl -sL https://github.com/postmodern/ruby-install/archive/v0.6.0.tar.gz | tar xz && \
    cd ruby-install-0.6.0 && \
    make install && \
    ruby-install ruby\ 2.3.1 -- --disable-install-doc && \
    echo "chruby ruby-2.3.1" >> ~/.bash_profile && \
    rm -rf /chruby-* && \
    rm -rf /usr/local/src/* && \
    clean all

## Install Bundler
RUN gem install bundler

## Download manageiq
RUN mkdir -p /manageiq && git clone --depth 1 https://github.com/ManageIQ/manageiq /manageiq
ADD . /manageiq

## Change WORKDIR to clone dir, copy docker_setup, start all, docker_setup, shutdown all, clean all
WORKDIR /manageiq

## Expose required container ports
EXPOSE 80 443

CMD bin/setup && \
    bundle exec rake evm:start


