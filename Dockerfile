FROM ubuntu:15.04

RUN mkdir -p /root/setup
WORKDIR /root/setup

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install software-properties-common
RUN apt-add-repository ppa:ansible/ansible
RUN apt-get -y install curl git vim ansible apparmor-profiles tzdata sudo libbz2-dev systemd-sysv

RUN update-ca-certificates -f
RUN apt purge -y mysql-server mysql-server-5.6 mysql-server-core-5.6
# RUN echo "mysql-server-5.6 mysql-server/root_password password root" | debconf-set-selections
# RUN echo "mysql-server-5.6 mysql-server/root_password_again password root" | debconf-set-selections
# RUN apt-get -y install mysql-server-5.6

RUN set -e
RUN sed -i.bak -e "s@http://us\.archive\.ubuntu\.com/ubuntu/@mirror://mirrors.ubuntu.com/mirrors.txt@g" /etc/apt/sources.list
ENV DEBIAN_FRONTEND noninteractive

RUN rm -rf ansible-isucon
RUN git clone https://github.com/matsuu/ansible-isucon.git
WORKDIR /root/setup/ansible-isucon/isucon5-qualifier
RUN PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -i local bench/ansible/playbook.yml


# RUN apt-get install -y libsslcommon2-dev
# RUN apt-get install -y libssl-dev
# RUN apt-get install -y pkg-config
# RUN apt-get install -y libcurl4-openssl-dev
# RUN apt-get install -y autoconf g++ make openssl libssl-dev libsasl2-dev
# RUN dpkg -i mysql-apt-config_w.x.y-z_all.deb
# RUN apt-get -y update
# RUN apt-get install -y mysql-server

# RUN PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -i local image/ansible/playbook.yml
#
#RUN apt-get -y install apt-transport-https
#RUN curl https://dist.crystal-lang.org/apt/setup.sh | sudo bash
#RUN apt-get -y install crystal=0.22.0
#
#RUN cp /home/isucon/isucon5q-crystal/resources/isuxi.crystal.service /etc/systemd/system/
#RUN chown root /etc/systemd/system/isuxi.crystal.service
#RUN chgrp root /etc/systemd/system/isuxi.crystal.service
#RUN chmod 644  /etc/systemd/system/isuxi.crystal.service
#RUN sudo -u isucon mkdir -p /home/isucon//webapp/crystal
#RUN sudo -u isucon cp -r /home/isucon/webapp/static /home/isucon/webapp/crystal/public
