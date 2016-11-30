FROM centos:7
ENV container docker
MAINTAINER ManageIQ https://github.com/ManageIQ/manageiq-appliance-build

# Set ENV, LANG only needed if building with docker-1.8
ENV LANG en_US.UTF-8
ENV TERM xterm
#ENV RUBY_GEMS_ROOT /opt/rubies/ruby-2.3.1/lib/ruby/gems/2.3.0
#ENV APP_ROOT /var/www/miq/vmdb

# Fetch pglogical and manageiq repo
RUN curl -sSLko /etc/yum.repos.d/ncarboni-pglogical-SCL-epel-7.repo \
      https://copr.fedorainfracloud.org/coprs/ncarboni/pglogical-SCL/repo/epel-7/ncarboni-pglogical-SCL-epel-7.repo
RUN curl -sSLko /etc/yum.repos.d/manageiq-ManageIQ-epel-7.repo \
      https://copr.fedorainfracloud.org/coprs/manageiq/ManageIQ/repo/epel-7/manageiq-ManageIQ-epel-7.repo

## Install EPEL repo, yum necessary packages for the build without docs, clean all caches
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum -y install centos-release-scl-rh && \
    yum -y install --setopt=tsflags=nodocs \
                   bison                   \
                   bzip2                   \
                   cmake                   \
                   file                    \
                   gcc-c++                 \
                   git                     \
                   libffi-devel            \
                   libtool                 \
                   libxml2-devel           \
                   libxslt-devel           \
                   libyaml-devel           \
                   make                    \
                   memcached               \
                   net-tools               \
                   nodejs                  \
                   openssl-devel           \
                   patch                   \
                   rh-postgresql95-postgresql-server \
                   rh-postgresql95-postgresql-devel  \
                   rh-postgresql95-postgresql-pglogical-output \
                   rh-postgresql95-postgresql-pglogical \
                   rh-postgresql95-repmgr  \
                   readline-devel          \
                   sqlite-devel            \
                   sysvinit-tools          \
                   which                   \
                   &&                      \
    yum clean all


## Enable Memchached on boot.
RUN systemctl enable memcached appliance-initialize evmserverd evminit evm-watchdog miqvmstat miqtop

## Enable Postgress
RUN yum -y install postgresql-setup initdb && \
    yum -y install grep -q '^local\s' /var/lib/pgsql/data/pg_hba.conf || echo "local all all trust" | tee -a /var/lib/pgsql/data/pg_hba.conf && \
    yum -y install sed -i.bak 's/\(^local\s*\w*\s*\w*\s*\)\(peer$\)/\1trust/' /var/lib/pgsql/data/pg_hba.conf && \
    yum -y install systemctl enable postgresql && \
    yum -y install systemctl start postgresql && \
    yum -y install -u postgres psql -c "CREATE ROLE root SUPERUSER LOGIN PASSWORD 'smartvm'"

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
    yum clean all

## Install Bundler
RUN gem install bundler

## Download manageiq
RUN mkdir -p /manageiq && git clone --depth 1 https://github.com/ManageIQ/manageiq /manageiq
RUN mkdir -p /manageiq
ADD . /manageiq

## Change WORKDIR to clone dir, copy docker_setup, start all, docker_setup, shutdown all, clean all
WORKDIR /manageiq

## Expose required container ports
EXPOSE 80 443

CMD bin/setup && \
    bundle exec rake evm:start


