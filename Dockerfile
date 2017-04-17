FROM ubuntu:16.04

RUN mkdir -p /root/setup
WORKDIR /root/setup

RUN apt-add-repository ppa:ansible/ansible
RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install curl git vim software-properties-common ansible apparmor-profiles tzdata sudo

RUN rm -rf ansible-isucon
RUN git clone https://github.com/matsuu/ansible-isucon.git
WORKDIR /root/setup/ansible-isucon/isucon5-qualifier
RUN PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -i local bench/ansible/playbook.yml

RUN mkdir -p /root/isucon
WORKDIR /root/isucon
