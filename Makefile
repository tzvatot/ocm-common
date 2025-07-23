#
# Copyright (c) 2023 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
LOCAL_BIN_PATH := $(PROJECT_PATH)/bin

# Add the project-level bin directory into PATH
export PATH := $(LOCAL_BIN_PATH):$(PATH)

# Ensure go modules are enabled:
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org

# Disable CGO so that we always generate static binaries:
export CGO_ENABLED=0

# Unset GOFLAG for CI and ensure we've got nothing accidently set
unexport GOFLAGS

# golangci-lint configuration
GOLANGCI_LINT ?= $(LOCAL_BIN_PATH)/golangci-lint
GOLANGCI_LINT_VERSION ?= v1.54.2
GOLANGCI_LINT_VERSIONED_BIN = $(LOCAL_BIN_PATH)/golangci-lint-$(GOLANGCI_LINT_VERSION)

# Wget retry options for reliability
WGET_RETRIES_OPTIONS = --tries 10 --retry-on-http-error=429 --waitretry=20

.PHONY: build
build:
	go build

.PHONY: test
test:
	go test ./...

.PHONY: coverage
coverage:
	go test -coverprofile=cover.out  ./...

.PHONY: fmt
fmt:
	gofmt -s -l -w cmd pkg

# Note: As documented in https://golangci-lint.run/usage/install/#local-installation
# the recommended installation method is through the golangci-lint install
# script and not through the go install command.
.PHONY: golangci-lint-install
golangci-lint-install:
	@if [ ! -f "$(GOLANGCI_LINT_VERSIONED_BIN)" ]; then \
		echo "Downloading golangci-lint $(GOLANGCI_LINT_VERSION) ..." ; \
		mkdir -p $(LOCAL_BIN_PATH)/tmp ;\
		wget -O- -nv ${WGET_RETRIES_OPTIONS} https://raw.githubusercontent.com/golangci/golangci-lint/$(GOLANGCI_LINT_VERSION)/install.sh | sh -s -- -b $(LOCAL_BIN_PATH)/tmp $(GOLANGCI_LINT_VERSION) ;\
		mv $(LOCAL_BIN_PATH)/tmp/golangci-lint $(GOLANGCI_LINT_VERSIONED_BIN) ;\
		rmdir $(LOCAL_BIN_PATH)/tmp ;\
		chmod u+x $(GOLANGCI_LINT_VERSIONED_BIN) ;\
	fi
	@( cd $(LOCAL_BIN_PATH); ln -f -s golangci-lint-$(GOLANGCI_LINT_VERSION) golangci-lint )

.PHONY: lint
lint: golangci-lint-install
	GOLANGCI_LINT_CACHE=$(LOCAL_BIN_PATH)/.golangci-lint-cache $(GOLANGCI_LINT) run --timeout 5m0s

.PHONY: clean
clean:
	rm -rf \
		ocm-common \
		bin \
		$(NULL)
