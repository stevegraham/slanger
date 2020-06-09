SHELL := bash

VERSION_VALUE ?= $(shell git rev-parse --short HEAD 2>/dev/null)
DOCKER_IMAGE_REPO ?= travisci/slanger
DOCKER_DEST ?= $(DOCKER_IMAGE_REPO):$(VERSION_VALUE)
QUAY ?= quay.io
QUAY_IMAGE ?= $(QUAY)/$(DOCKER_IMAGE_REPO)

ifdef $$QUAY_ROBOT_HANDLE
	QUAY_ROBOT_HANDLE := $$QUAY_ROBOT_HANDLE
endif

ifdef $$QUAY_ROBOT_TOKEN
	QUAY_ROBOT_TOKEN := $$QUAY_ROBOT_TOKEN
endif

ifndef $$TRAVIS_BRANCH
	TRAVIS_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
endif
BRANCH = $(shell echo "$(TRAVIS_BRANCH)" | sed 's/\//_/')

ifdef $$TRAVIS_PULL_REQUEST
	TRAVIS_PULL_REQUEST := $$TRAVIS_PULL_REQUEST
endif

DOCKER ?= docker

.PHONY: docker-build
docker-build:
	$(DOCKER) build -t $(DOCKER_DEST) .

.PHONY: docker-login
docker-login:
	$(DOCKER) login -u=$(QUAY_ROBOT_HANDLE) -p=$(QUAY_ROBOT_TOKEN) $(QUAY)

.PHONY: docker-push-latest-master
docker-push-latest-master:
	$(DOCKER) tag $(DOCKER_DEST) $(QUAY_IMAGE):$(VERSION_VALUE)
	$(DOCKER) push $(QUAY_IMAGE):$(VERSION_VALUE)
	$(DOCKER) tag $(DOCKER_DEST) $(QUAY_IMAGE):latest
	$(DOCKER) push $(QUAY_IMAGE):latest

.PHONY: docker-push-branch
docker-push-branch:
	$(DOCKER) tag $(DOCKER_DEST) $(QUAY_IMAGE):$(VERSION_VALUE)-$(BRANCH)
	$(DOCKER) push $(QUAY_IMAGE):$(VERSION_VALUE)-$(BRANCH)

.PHONY: ship
ship: docker-build docker-login

ifeq ($(TRAVIS_BRANCH),master)
ifeq ($(TRAVIS_PULL_REQUEST),false)
ship: docker-push-latest-master
endif
else
ship: docker-push-branch
endif
