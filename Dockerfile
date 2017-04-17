FROM ubuntu:16.04

RUN mkdir -p /root/setup
WORKDIR /root/setup

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install curl
RUN apt-get -y install git
RUN apt-get -y install vim

RUN rm -rf ansible-isucon
RUN git clone https://github.com/matsuu/ansible-isucon.git

RUN mkdir -p /root/isucon
WORKDIR /root/isucon
