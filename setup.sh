#!/bin/bash

source ~/.bashrc
cd /root/setup/ansible-isucon/isucon5-qualifier/ && \
    PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -i local /root/setup/ansible-isucon/isucon5-qualifier/image/ansible/playbook.yml
if [ $? -ne 0 ]; then
    exit 1;
fi

cd /home/isucon/isucon5q-crystal && cp resources/isuxi.crystal.service /etc/systemd/system/
chown root /etc/systemd/system/isuxi.crystal.service
chgrp root /etc/systemd/system/isuxi.crystal.service
chmod 644  /etc/systemd/system/isuxi.crystal.service
sudo -u isucon mkdir -p /home/isucon/webapp/crystal
sudo -u isucon cp -r /home/isucon/webapp/static /home/isucon/webapp/crystal/public

sudo systemctl daemon-reload
sudo systemctl stop isuxi.go
sudo systemctl stop isuxi.java
sudo systemctl stop isuxi.perl
sudo systemctl stop isuxi.php
sudo systemctl stop isuxi.python
sudo systemctl stop isuxi.ruby
sudo systemctl stop isuxi.scala
sudo systemctl start isuxi.crystal
