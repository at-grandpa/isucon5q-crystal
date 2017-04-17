FROM ubuntu:16.04

RUN mkdir -p /root/setup
WORKDIR /root/setup

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install software-properties-common
RUN apt-add-repository ppa:ansible/ansible
RUN apt-get -y install curl git vim ansible apparmor-profiles tzdata sudo

RUN rm -rf ansible-isucon
RUN git clone https://github.com/matsuu/ansible-isucon.git
WORKDIR /root/setup/ansible-isucon/isucon5-qualifier
RUN PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -i local bench/ansible/playbook.yml
RUN apt-get install -y libsslcommon2-dev
RUN apt-get install -y libssl-dev
rUN apt-get install -y pkg-config
rUN apt-get install -y libcurl4-openssl-dev

RUN PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -i local image/ansible/playbook.yml

RUN apt-get -y install apt-transport-https
RUN curl https://dist.crystal-lang.org/apt/setup.sh | sudo bash
RUN apt-get -y install crystal

RUN cp /home/isucon/isucon5q-crystal/resources/isuxi.crystal.service /etc/systemd/system/
RUN chown root /etc/systemd/system/isuxi.crystal.service
RUN chgrp root /etc/systemd/system/isuxi.crystal.service
RUN chmod 644  /etc/systemd/system/isuxi.crystal.service
RUN sudo -u isucon mkdir -p $(HOME)/webapp/crystal
RUN sudo -u isucon cp -r $(HOME)/webapp/static $(HOME)/webapp/crystal/public
