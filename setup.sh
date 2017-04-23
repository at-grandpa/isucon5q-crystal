#!/bin/bash

source ~/.bashrc
cd /root/setup/ansible-isucon/isucon5-qualifier
PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ansible-playbook -i local image/ansible/playbook.yml

