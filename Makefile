# =============================================================================
# Makefile — Local build helpers
# =============================================================================
# Usage:
#   make build VERSION=22.04
#   make build-all
#   make run   VERSION=24.04
#   make scan  VERSION=24.04
#   make lint
#   make clean
# =============================================================================

.DEFAULT_GOAL := help
SHELL         := /bin/bash

REGISTRY     ?= ghcr.io
OWNER        ?= $(shell git config --get remote.origin.url | sed 's|.*github.com[:/]\([^/]*/[^.]*\).*|\1|' | tr '[:upper:]' '[:lower:]')
IMAGE        ?= $(REGISTRY)/$(OWNER)
VERSION      ?= 24.04
PLATFORM     ?= linux/amd64
NO_CACHE     ?=

# Codename lookup
codename_22_04=jammy
codename_24_04=noble
codename_24_10=oracular
codename_25_04=plucky
codename_25_10=questing
codename_26_04=resolute
CODENAME      := $(codename_$(VERSION))

BUILD_ARGS    := \
  --build-arg UBUNTU_VERSION=$(VERSION) \
  --build-arg UBUNTU_CODENAME=$(CODENAME)

CACHE_FLAG    := $(if $(NO_CACHE),--no-cache,)

.PHONY: help build build-all run scan lint clean

## help: Show this help message
help:
	@echo ""
	@echo "  Ubuntu GitHub Actions Runner — Make targets"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""

## build: Build a single image (VERSION=22.04|24.04|25.04|26.04)
build:
	@echo "▶ Building ubuntu-$(VERSION) ($(CODENAME))…"
	docker buildx build $(CACHE_FLAG) \
	  --platform $(PLATFORM) \
	  $(BUILD_ARGS) \
	  --tag $(IMAGE):ubuntu-$(VERSION) \
	  --load \
	  .
	@echo "✓ $(IMAGE):ubuntu-$(VERSION)"

## build-all: Build all four Ubuntu versions
build-all:
	$(MAKE) build VERSION=22.04
	$(MAKE) build VERSION=24.04
	$(MAKE) build VERSION=25.04
	$(MAKE) build VERSION=26.04

## run: Run a shell in the specified image version
run:
	docker run --rm -it \
	  --platform $(PLATFORM) \
	  $(IMAGE):ubuntu-$(VERSION) \
	  bash

## scan: Trivy vulnerability scan on a built image
scan:
	@which trivy >/dev/null 2>&1 || (echo "trivy not found. Install: https://github.com/aquasecurity/trivy" && exit 1)
	trivy image \
	  --severity HIGH,CRITICAL \
	  --ignore-unfixed \
	  $(IMAGE):ubuntu-$(VERSION)

## lint: Lint the Dockerfile with hadolint
lint:
	@which hadolint >/dev/null 2>&1 || \
	  docker run --rm -i hadolint/hadolint hadolint - < Dockerfile && exit 0
	hadolint Dockerfile

## clean: Remove locally-built images
clean:
	@for v in 22.04 24.04 25.04 26.04; do \
	  echo "Removing $(IMAGE):ubuntu-$$v …"; \
	  docker rmi $(IMAGE):ubuntu-$$v 2>/dev/null || true; \
	done
