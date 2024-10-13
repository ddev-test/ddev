
SHELL = /bin/bash

SANITIZED_DOCKER_REPO = $(subst /,_,$(DOCKER_REPO))

DOTFILE_IMAGE = $(subst /,_,$(IMAGE))-$(VERSION)

container: container-name
	docker buildx build -o type=docker -t $(DOCKER_REPO):$(VERSION) $(DOCKER_ARGS) --label "build-info=$(DOCKER_REPO):$(VERSION) commit=$(shell git describe --tags --always)" .

container-name:
	@echo "container: $(DOCKER_REPO):$(VERSION)"

push:
	docker buildx use multi-arch-builder >/dev/null 2>&1 || docker buildx create --name multi-arch-builder --use
	docker buildx build --push --platform $(BUILD_ARCHS) -t $(DOCKER_REPO):$(VERSION) --label "build-info=$(DOCKER_REPO):$(VERSION) commit=$(shell git describe --tags --always) built $$(date) by $$(id -un) on $$(hostname)" --label "maintainer=DDEV <randy@randyfay.com>" $(DOCKER_ARGS) .
