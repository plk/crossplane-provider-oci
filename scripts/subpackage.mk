# Copyright 2025 The Crossplane Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ====================================================================================
# Sub-package xpkg Build Support
#
# Builds individual xpkg files for each OCI service sub-package.
# Each sub-package xpkg embeds a service-specific runtime image built from
# the per-service binary (cmd/provider/<service>), not the monolith.
#
# Usage:
#   make build-subpackages
#   make build-subpackages SUBPACKAGES_FOR_BATCH="config,networking"
#   make build-subpackages BATCH_PLATFORMS=linux_amd64
#   make package.subpackage.networking
#   make publish-subpackages

# ====================================================================================
# Options

SUBPACKAGES_FOR_BATCH ?=
BATCH_PLATFORMS ?= linux_amd64 linux_arm64
SUBPKG_OUTPUT_DIR ?= $(OUTPUT_DIR)/subpackage-xpkgs
SUBPKG_CRD_DIR ?= $(OUTPUT_DIR)/package/crds
SUBPKG_EXAMPLES_DIR ?= $(ROOT_DIR)/examples/namespaced
SUBPKG_IMAGE_DIR ?= $(ROOT_DIR)/cluster/images/provider-oci

# Derive the platform list for sub-package builds (space-separated)
BATCH_PLATFORM_LIST := $(subst $(COMMA), ,$(subst $(SPACE),$(COMMA),$(BATCH_PLATFORMS)))

# ====================================================================================
# Helpers

# Return the package name for a service (config -> provider-family-oci, else provider-oci-<svc>)
# Usage: $(call subpkg.name,<service>)
define subpkg.name
$(if $(filter config,$(1)),provider-family-oci,provider-oci-$(1))
endef

# Return true if this service is the family provider
# Usage: $(call subpkg.is_family,<service>)
define subpkg.is_family
$(filter config,$(1))
endef

# ====================================================================================
# per-service Docker image target
#
# Builds a service-specific binary then builds a Docker image from it.
# Image is tagged $(BUILD_REGISTRY)/<pkgname>-<arch>
#
# Usage: make subpkg.image.<service>.<arch>   e.g. make subpkg.image.networking.arm64

subpkg.image.%:
	$(eval _SVC   := $(word 1,$(subst ., ,$*)))
	$(eval _ARCH  := $(word 2,$(subst ., ,$*)))
	$(eval _PKG   := $(call subpkg.name,$(_SVC)))
	$(eval _IMG   := $(BUILD_REGISTRY)/$(_PKG)-$(_ARCH))
	$(eval _BINDIR := $(OUTPUT_DIR)/bin/linux_$(_ARCH))
	$(eval _BINARY := $(_BINDIR)/$(_SVC))
	$(eval _CTX   := $(shell mktemp -d))
	@$(INFO) Building binary $(_SVC) for linux/$(_ARCH)
	@$(MAKE) build.subpackage.$(_SVC) PLATFORMS="linux_$(_ARCH)"
	@test -f $(_BINARY) || (echo "ERROR: binary not found: $(_BINARY)"; rm -rf $(_CTX); exit 1)
	@$(INFO) Building runtime image $(_IMG)
	@mkdir -p $(_CTX)/bin/linux_$(_ARCH)
	@cp $(_BINARY) $(_CTX)/bin/linux_$(_ARCH)/provider
	@cp $(SUBPKG_IMAGE_DIR)/terraformrc.hcl $(_CTX)/ 2>/dev/null || true
	@docker build \
		--platform linux/$(_ARCH) \
		--build-arg TARGETOS=linux \
		--build-arg TARGETARCH=$(_ARCH) \
		--build-arg TERRAFORM_VERSION=$(TERRAFORM_VERSION) \
		--build-arg TERRAFORM_PROVIDER_SOURCE=$(TERRAFORM_PROVIDER_SOURCE) \
		--build-arg TERRAFORM_PROVIDER_VERSION=$(TERRAFORM_PROVIDER_VERSION) \
		--build-arg TERRAFORM_PROVIDER_DOWNLOAD_NAME=$(TERRAFORM_PROVIDER_DOWNLOAD_NAME) \
		--build-arg TERRAFORM_NATIVE_PROVIDER_BINARY=$(TERRAFORM_NATIVE_PROVIDER_BINARY) \
		--build-arg USER_AGENT_PROVIDER_NAME="$(USER_AGENT_PROVIDER_NAME)" \
		-t $(_IMG) \
		-f $(SUBPKG_IMAGE_DIR)/Dockerfile \
		$(_CTX) || (rm -rf $(_CTX); exit 1)
	@rm -rf $(_CTX)
	@$(OK) Built runtime image $(_IMG)

# ====================================================================================
# Per-service xpkg build target (single platform)
#
# Builds the crossplane.yaml, copies CRDs, and runs crossplane xpkg build.
# Requires the runtime image to already exist (call subpkg.image.%.% first).
#
# Usage: make subpkg.xpkg.<service>.<arch>

subpkg.xpkg.%:
	$(eval _SVC   := $(word 1,$(subst ., ,$*)))
	$(eval _ARCH  := $(word 2,$(subst ., ,$*)))
	$(eval _PKG   := $(call subpkg.name,$(_SVC)))
	$(eval _IMG   := $(BUILD_REGISTRY)/$(_PKG)-$(_ARCH))
	$(eval _WORK  := $(shell mktemp -d))
	@test -d $(SUBPKG_CRD_DIR) || (echo "ERROR: CRD dir not found: $(SUBPKG_CRD_DIR). Run 'make kustomize-crds' first."; exit 1)
	@$(INFO) Packaging $(_PKG)-$(VERSION).xpkg
	@# Copy CRDs
	@mkdir -p $(_WORK)/crds
	@if [ "$(_SVC)" = "config" ]; then \
		ls $(SUBPKG_CRD_DIR)/oci.m.upbound.io_*.yaml $(SUBPKG_CRD_DIR)/oci.upbound.io_*.yaml 2>/dev/null | xargs -I{} cp {} $(_WORK)/crds/ || true; \
	else \
		ls $(SUBPKG_CRD_DIR)/$(_SVC).oci.m.upbound.io_*.yaml $(SUBPKG_CRD_DIR)/$(_SVC).oci.upbound.io_*.yaml 2>/dev/null | xargs -I{} cp {} $(_WORK)/crds/ || true; \
	fi
	@test -n "$$(ls $(_WORK)/crds/ 2>/dev/null)" || (echo "SKIP: $(_SVC) — no CRDs found"; rm -rf $(_WORK); exit 0)
	@# Write crossplane.yaml
	@$(ROOT_DIR)/scripts/write-subpackage-crossplane-yaml.sh "$(_SVC)" "$(_PKG)" "$(_WORK)/crossplane.yaml"
	@# Build xpkg
	@mkdir -p $(SUBPKG_OUTPUT_DIR)
	@_examples_arg=""; \
	if [ -d "$(SUBPKG_EXAMPLES_DIR)/$(_SVC)" ]; then \
		_examples_arg="--examples-root $(SUBPKG_EXAMPLES_DIR)/$(_SVC)"; \
	fi; \
	$(CROSSPLANE_CLI) xpkg build \
		--package-root $(_WORK) \
		--embed-runtime-image $(_IMG) \
		$$_examples_arg \
		--ignore "$(XPKG_IGNORE)" \
		--package-file $(SUBPKG_OUTPUT_DIR)/$(_PKG)-$(VERSION).xpkg
	@rm -rf $(_WORK)
	@$(OK) Built $(SUBPKG_OUTPUT_DIR)/$(_PKG)-$(VERSION).xpkg

# ====================================================================================
# package.subpackage.<service> — build image + xpkg for host arch
#
# Usage: make package.subpackage.networking
# Usage: make package.subpackage.networking BATCH_PLATFORMS=linux_amd64

package.subpackage.%: FORCE
	@for platform in $(BATCH_PLATFORM_LIST); do \
		_arch=$$(echo $$platform | cut -d_ -f2); \
		$(MAKE) subpkg.image.$*.$${_arch} && \
		$(MAKE) subpkg.xpkg.$*.$${_arch} || exit 1; \
	done

# ====================================================================================
# Discover all services from CRD dir (namespaced variant)

SUBPKG_ALL_SERVICES = $(shell \
	ls $(SUBPKG_CRD_DIR)/*.oci.m.upbound.io_*.yaml 2>/dev/null \
	| xargs -n1 basename \
	| sed 's/\.oci\.m\.upbound\.io_.*//' \
	| sort -u)

# If SUBPACKAGES_FOR_BATCH is set, use that; otherwise all discovered services
# Use recursive variable so it is evaluated lazily at recipe time, not parse time
SUBPKG_BUILD_LIST = $(if $(SUBPACKAGES_FOR_BATCH),$(subst $(COMMA), ,$(SUBPACKAGES_FOR_BATCH)),$(SUBPKG_ALL_SERVICES))

# ====================================================================================
# build-subpackages — build xpkgs for all (or specified) services

build-subpackages: kustomize-crds
	@$(INFO) Building sub-package xpkgs for: $(SUBPKG_BUILD_LIST)
	@for svc in $(SUBPKG_BUILD_LIST); do \
		$(MAKE) package.subpackage.$$svc BATCH_PLATFORMS="$(BATCH_PLATFORMS)" || exit 1; \
	done
	@$(OK) Done building sub-package xpkgs

# ====================================================================================
# publish-subpackages — build then push xpkgs to registry

SUBPKG_REGISTRY ?= $(firstword $(XPKG_REG_ORGS))

subpkg.push.%:
	$(eval _PKG := $(call subpkg.name,$*))
	@$(INFO) Pushing $(_PKG):$(VERSION) from all platforms
	@$(CROSSPLANE_CLI) xpkg push \
		$(foreach p,$(BATCH_PLATFORM_LIST),--package-files $(SUBPKG_OUTPUT_DIR)/$(call subpkg.name,$*)-$(VERSION).xpkg ) \
		$(SUBPKG_REGISTRY)/$(_PKG):$(VERSION) || $(FAIL)
	@$(OK) Pushed $(SUBPKG_REGISTRY)/$(_PKG):$(VERSION)

publish-subpackages: build-subpackages
	@$(INFO) Pushing sub-package xpkgs to $(SUBPKG_REGISTRY)
	@for svc in $(SUBPKG_BUILD_LIST); do \
		$(MAKE) subpkg.push.$$svc || exit 1; \
	done
	@$(OK) Done publishing sub-package xpkgs

.PHONY: build-subpackages publish-subpackages FORCE
