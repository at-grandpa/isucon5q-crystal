#!/bin/bash

setup: install/anyenv

ANYENV_DIR=$(HOME)/.anyenv
ANYENV=$(ANYENV_DIR)/bin/anyenv
CRENV=$(ANYENV_DIR)/envs/crenv/bin/crenv
CRYSTAL_VERSION=$(shell $(CRENV) install --list | tail -1)
BASHRC=$(HOME)/.bashrc

install/anyenv:
	-test ! -e $(ANYENV_DIR) && git clone https://github.com/riywo/anyenv $(ANYENV_DIR)
	-test $(shell cat $(BASHRC) | grep -c 'export PATH="$(ANYENV_DIR)/bin:$$PATH"') -eq 0 && echo 'export PATH="$(ANYENV_DIR)/bin:$$PATH"' >> $(BASHRC)
	-test $(shell cat $(BASHRC) | grep -c 'eval "$$(anyenv init -)"') -eq 0 && echo 'eval "$$(anyenv init -)"' >> $(BASHRC)
	@echo "\n"
	@echo "  Please reload $(BASHRC)."
	@echo ""
	@echo "   run:  exec \$$SHELL -l"
	@echo "  next:  make install/crenv"
	@echo "\n"

install/crenv:
	-$(ANYENV) install crenv
	@echo "\n"
	@echo "  Please reload $(BASHRC)."
	@echo ""
	@echo "   run:  exec \$$SHELL -l"
	@echo "  next:  make install/crystal"
	@echo "\n"

install/crystal:
	-test $(shell $(CRENV) versions | grep -c $(CRYSTAL_VERSION)) -eq 0 && $(CRENV) install $(CRYSTAL_VERSION)
	$(CRENV) global $(CRYSTAL_VERSION)
	@echo "\n"
	@echo "  Please setup webapp."
	@echo ""
	@echo "  run:  make setup/webapp"
	@echo "\n"

setup/webapp: cp/isuxi.crystal create/webapp/crystal start/isuxi.crystal build/app

cp/isuxi.crystal:
	sudo cp resources/isuxi.crystal.service /etc/systemd/system/
	sudo chown root /etc/systemd/system/isuxi.crystal.service
	sudo chgrp root /etc/systemd/system/isuxi.crystal.service
	sudo chmod 644  /etc/systemd/system/isuxi.crystal.service

create/webapp/crystal:
	mkdir -p $(HOME)/webapp/crystal
	cp -r $(HOME)/webapp/static $(HOME)/webapp/crystal/public

start/isuxi.crystal:
	sudo systemctl daemon-reload
	sudo systemctl stop isuxi.go
	sudo systemctl stop isuxi.java
	sudo systemctl stop isuxi.perl
	sudo systemctl stop isuxi.php
	sudo systemctl stop isuxi.python
	sudo systemctl stop isuxi.ruby
	sudo systemctl stop isuxi.scala
	sudo systemctl start isuxi.crystal

build/app:
	cd $(HOME)/isucon5q-crystal
	shards update
	crystal build -o $(HOME)/webapp/crystal/app $(HOME)/isucon5q-crystal/src/isucon5q-crystal.cr --error-trace
	sudo systemctl restart isuxi.crystal

build: start/isuxi.crystal build/app

REPOSITORY=isucon5q-crystal
TAG=default

HOST_WORKDIR=$(PWD)
CONTAINER_WORKDIR=/root/isucon

docker/build:
	docker build --tag=$(REPOSITORY):$(TAG) .

docker/attach:
	docker run -v $(HOST_WORKDIR):$(CONTAINER_WORKDIR) -it $(REPOSITORY):$(TAG)
