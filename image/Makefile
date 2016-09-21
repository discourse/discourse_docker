IMAGE_VERSION := 1.3.7

SHELL         := /bin/bash
OS            := $(shell uname | tr '[:upper:]' '[:lower:]')

SQUASH        ?= YES

DOCKER_SQUASH_URL := https://github.com/jwilder/docker-squash/releases/download/v0.2.0/docker-squash-${OS}-amd64-v0.2.0.tar.gz



# omitting discourse_fast_switch from 'all' as it seems obsolete.
all: base discourse discourse_dev discourse_test discourse_bench
.PHONY: all base discourse discourse_dev discourse_test discourse_bench discourse_fast_switch

base: base-deps
# discourse: discourse-deps
discourse_dev: discourse_dev-deps
# discourse_test: discourse_test-deps
# discourse_bench: discourse_bench-deps
# discourse_fast_switch: discourse_fast_switch-deps

base:
	@IMAGE_DIR=$@ IS_BASE=YES ${MAKE} build-image

discourse discourse_fast_switch discourse_dev discourse_test discourse_bench:
	@IMAGE_DIR=$@ ${MAKE} build-image


base-deps: base/phantomjs
.PHONY: base-deps

base/phantomjs:
	@echo "Fetching phantomjs..."
	cd base && ./download_phantomjs

discourse_dev-deps:
	@echo "Copying postgres and redis templates..."
	sed -e 's/\(db_name: discourse\)/\1_development/' ../templates/postgres.template.yml > discourse_dev/postgres.template.yml
	cp ../templates/redis.template.yml discourse_dev/redis.template.yml
.PHONY: discourse_dev-deps

# If you don't want to docker-squash the image, prefix your command line with
# SQUASH=NO, like:
#     SQUASH=NO make discourse_dev
build-image: docker-squash update-dockerfile
	@echo "----- building image: discourse/${IMAGE_DIR}:${IMAGE_VERSION} -----"
ifeq (${SQUASH}, YES)
	docker build ${IMAGE_DIR} | tee .build.out
	@echo "squashing $$(tail -1 .build.out | awk '/^Successfully built / {print $$3}')..."
	docker save -o img.tar $$(tail -1 .build.out | awk '/^Successfully built / {print $$3}')
	sudo ./docker-squash -verbose -i img.tar -o squash.tar $(if $(IS_BASE),-from root) -t discourse/${IMAGE_DIR}:${IMAGE_VERSION}
	docker load -i squash.tar
	rm -f squash.tar
	rm -f img.tar
	rm -f .build.out
else
	docker build -t discourse/${IMAGE_DIR}:${IMAGE_VERSION} ${IMAGE_DIR}
endif
.PHONY: build-image

docker-squash:
	wget ${DOCKER_SQUASH_URL} --output-document=$@.tar.gz
	tar -xzvf $@.tar.gz
	rm -f $@.tar.gz

# We want to ensure that the Dockerfiles all have an appropriate header
# comment, and any FROM line refers to the version we're currently building.
# Also, if there's a line that echoes into VERSION, replace the value with the
# current version.  (Dockerfiles support environment expansion, but not for
# FROM or RUN statements.)
update-dockerfile:
	@echo "----- updating ${IMAGE_DIR}/Dockerfile for ${IMAGE_VERSION} -----"
	@sed -i '' -e 's/^\(# NAME:\).*$$/\1     discourse\/${IMAGE_DIR}/' ${IMAGE_DIR}/Dockerfile
	@sed -i '' -e 's/^\(# VERSION:\).*$$/\1  ${IMAGE_VERSION}/' ${IMAGE_DIR}/Dockerfile
	@sed -i '' -e 's/^\(FROM discourse\/[^:]*:\).*/\1${IMAGE_VERSION}/' ${IMAGE_DIR}/Dockerfile
	@sed -i '' -e 's/^\(RUN echo "\)[^"]*\(" > \/VERSION\)$$/\1${IMAGE_VERSION}\2/' ${IMAGE_DIR}/Dockerfile
.PHONY: update-dockerfile
