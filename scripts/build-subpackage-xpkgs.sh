#!/usr/bin/env bash
# Build individual xpkg files for each OCI service sub-package.
#
# Usage:
#   ./scripts/build-subpackage-xpkgs.sh [service1 service2 ...]
#
# If no services are given, builds xpkgs for all services found in the CRD output.
# Output xpkg files are written to _output/subpackage-xpkgs/
#
# Each sub-package xpkg embeds a service-specific runtime image built from the
# per-service binary (cmd/provider/<service>), NOT the monolith.
#
# Requirements:
#   - make kustomize-crds (or make build) must have been run first so
#     _output/package/crds/ is populated
#   - Docker must be running

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRD_DIR="${REPO_ROOT}/_output/package/crds"
EXAMPLES_DIR="${REPO_ROOT}/examples/namespaced"
OUTPUT_DIR="${REPO_ROOT}/_output/subpackage-xpkgs"
HOST_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_ARCH_RAW=$(uname -m)
case "${HOST_ARCH_RAW}" in
  x86_64) TOOLS_ARCH="amd64" ;;
  arm64|aarch64) TOOLS_ARCH="arm64" ;;
  *) TOOLS_ARCH="${HOST_ARCH_RAW}" ;;
esac
CROSSPLANE_CLI="${REPO_ROOT}/.cache/tools/${HOST_OS}_${TOOLS_ARCH}/crossplane-cli-v2.2.0"
VERSION=$(cd "${REPO_ROOT}" && git describe --dirty --always --tags 2>/dev/null || echo "v0.0.0")

# Derive the same BUILD_REGISTRY that make uses
BUILD_REGISTRY="build-$(echo "$(hostname)-${REPO_ROOT}" | shasum -a 256 | cut -c1-8)"

if [ ! -d "${CRD_DIR}" ]; then
  echo "ERROR: CRD directory not found: ${CRD_DIR}"
  echo "Run 'make kustomize-crds' or 'make build' first."
  exit 1
fi

if [ ! -x "${CROSSPLANE_CLI}" ]; then
  echo "ERROR: crossplane CLI not found at ${CROSSPLANE_CLI}"
  echo "Run 'make build' once to download tools."
  exit 1
fi

# Collect all services from CRD filenames (e.g. "adm" from "adm.oci.m.upbound.io_*.yaml")
# Use only the .m.upbound.io CRDs (namespaced variants)
ALL_SERVICES=$(ls "${CRD_DIR}"/*.oci.m.upbound.io_*.yaml 2>/dev/null \
  | xargs -n1 basename \
  | sed 's/\.oci\.m\.upbound\.io_.*//' \
  | sort -u)

# Filter to requested services if provided
if [ $# -gt 0 ]; then
  SERVICES="$*"
else
  SERVICES="${ALL_SERVICES}"
fi

echo "Building xpkgs for services: ${SERVICES}"
echo "Version: ${VERSION}"
echo ""

SUCCESS=()
FAILED=()

for SERVICE in ${SERVICES}; do
  PKG_WORK_DIR=$(mktemp -d)
  trap "rm -rf ${PKG_WORK_DIR}" EXIT

  # "config" is a special alias for provider-family-oci, backed by oci.m.upbound.io CRDs
  if [ "${SERVICE}" = "config" ]; then
    PKG_NAME="provider-family-oci"
    SERVICE_CRDS=$(ls "${CRD_DIR}/oci.m.upbound.io_"*.yaml "${CRD_DIR}/oci.upbound.io_"*.yaml 2>/dev/null || true)
    IS_FAMILY=true
  else
    PKG_NAME="provider-oci-${SERVICE}"
    SERVICE_CRDS=$(ls "${CRD_DIR}/${SERVICE}.oci.m.upbound.io_"*.yaml "${CRD_DIR}/${SERVICE}.oci.upbound.io_"*.yaml 2>/dev/null || true)
    IS_FAMILY=false
  fi

  if [ -z "${SERVICE_CRDS}" ]; then
    echo "SKIP: ${SERVICE} — no CRDs found"
    continue
  fi

  echo "[ .. ] Building ${PKG_NAME}-${VERSION}.xpkg"

  # Build the per-service binary and Docker image
  RUNTIME_IMAGE="${BUILD_REGISTRY}/${PKG_NAME}-${TOOLS_ARCH}"
  echo "       Building binary for ${SERVICE}..."
  if ! (cd "${REPO_ROOT}" && make build.subpackage."${SERVICE}" PLATFORMS="linux_${TOOLS_ARCH}" 2>&1 | tail -5); then
    echo "[FAIL] Could not build binary for ${SERVICE}"
    FAILED+=("${SERVICE}")
    rm -rf "${PKG_WORK_DIR}"
    trap - EXIT
    continue
  fi

  # Build a Docker image containing the per-service binary
  BINARY_PATH="${REPO_ROOT}/_output/bin/linux_${TOOLS_ARCH}/${SERVICE}"
  if [ ! -f "${BINARY_PATH}" ]; then
    echo "[FAIL] Binary not found after build: ${BINARY_PATH}"
    FAILED+=("${SERVICE}")
    rm -rf "${PKG_WORK_DIR}"
    trap - EXIT
    continue
  fi

  echo "       Building runtime image ${RUNTIME_IMAGE}..."
  # Use a temp context dir with the binary at the path the Dockerfile expects
  IMG_CTX=$(mktemp -d)
  trap "rm -rf ${IMG_CTX}" EXIT
  mkdir -p "${IMG_CTX}/bin/linux_${TOOLS_ARCH}"
  cp "${BINARY_PATH}" "${IMG_CTX}/bin/linux_${TOOLS_ARCH}/provider"
  cp "${REPO_ROOT}/cluster/images/provider-oci/terraformrc.hcl" "${IMG_CTX}/" 2>/dev/null || true

  # Read Terraform versions — these are exported by the Makefile, but if not set
  # in the environment we read them from the Makefile directly.
  TERRAFORM_VERSION=${TERRAFORM_VERSION:-$(grep -E '^export TERRAFORM_VERSION' "${REPO_ROOT}/Makefile" | head -1 | sed 's/.*?= *//')}
  TERRAFORM_PROVIDER_SOURCE=${TERRAFORM_PROVIDER_SOURCE:-$(grep -E '^export TERRAFORM_PROVIDER_SOURCE' "${REPO_ROOT}/Makefile" | head -1 | sed 's/.*:= *//')}
  TERRAFORM_PROVIDER_VERSION=${TERRAFORM_PROVIDER_VERSION:-$(grep -E '^export TERRAFORM_PROVIDER_VERSION ' "${REPO_ROOT}/Makefile" | head -1 | sed 's/.*:= *//')}
  TERRAFORM_PROVIDER_DOWNLOAD_NAME=${TERRAFORM_PROVIDER_DOWNLOAD_NAME:-$(grep -E '^export TERRAFORM_PROVIDER_DOWNLOAD_NAME' "${REPO_ROOT}/Makefile" | head -1 | sed 's/.*:= *//')}
  TERRAFORM_NATIVE_PROVIDER_BINARY="terraform-provider-oci_v${TERRAFORM_PROVIDER_VERSION}"
  USER_AGENT_PROVIDER_NAME=${USER_AGENT_PROVIDER_NAME:-"Oracle-CrossplaneProvider provider-oci"}

  if ! docker build \
      --platform "linux/${TOOLS_ARCH}" \
      --build-arg "TARGETOS=linux" \
      --build-arg "TARGETARCH=${TOOLS_ARCH}" \
      --build-arg "TERRAFORM_VERSION=${TERRAFORM_VERSION}" \
      --build-arg "TERRAFORM_PROVIDER_SOURCE=${TERRAFORM_PROVIDER_SOURCE}" \
      --build-arg "TERRAFORM_PROVIDER_VERSION=${TERRAFORM_PROVIDER_VERSION}" \
      --build-arg "TERRAFORM_PROVIDER_DOWNLOAD_NAME=${TERRAFORM_PROVIDER_DOWNLOAD_NAME}" \
      --build-arg "TERRAFORM_NATIVE_PROVIDER_BINARY=${TERRAFORM_NATIVE_PROVIDER_BINARY}" \
      --build-arg "USER_AGENT_PROVIDER_NAME=${USER_AGENT_PROVIDER_NAME}" \
      -t "${RUNTIME_IMAGE}" \
      -f "${REPO_ROOT}/cluster/images/provider-oci/Dockerfile" \
      "${IMG_CTX}" 2>&1 | tail -10; then
    echo "[FAIL] Could not build runtime image for ${SERVICE}"
    FAILED+=("${SERVICE}")
    rm -rf "${PKG_WORK_DIR}" "${IMG_CTX}"
    trap - EXIT
    continue
  fi
  rm -rf "${IMG_CTX}"
  trap - EXIT

  # Set up package directory
  mkdir -p "${PKG_WORK_DIR}/crds"
  cp ${SERVICE_CRDS} "${PKG_WORK_DIR}/crds/"

  # Write crossplane.yaml
  if [ "${IS_FAMILY}" = "true" ]; then
    cat > "${PKG_WORK_DIR}/crossplane.yaml" <<EOF
apiVersion: meta.pkg.crossplane.io/v1
kind: Provider
metadata:
  name: ${PKG_NAME}
  annotations:
    meta.crossplane.io/maintainer: Oracle Cloud Infrastructure
    meta.crossplane.io/source: github.com/oracle/crossplane-provider-oci
    meta.crossplane.io/license: Apache-2.0
    meta.crossplane.io/description: |
      OCI family provider package providing authentication configuration and
      ProviderConfig management for all OCI service providers.
    friendly-name.meta.crossplane.io: OCI Provider Family
spec:
  crossplane:
    version: ">=v1.14.0"
EOF
  else
    cat > "${PKG_WORK_DIR}/crossplane.yaml" <<EOF
apiVersion: meta.pkg.crossplane.io/v1
kind: Provider
metadata:
  name: ${PKG_NAME}
  labels:
    pkg.crossplane.io/provider-family: provider-family-oci
  annotations:
    meta.crossplane.io/maintainer: Oracle Cloud Infrastructure
    meta.crossplane.io/source: github.com/oracle/crossplane-provider-oci
    meta.crossplane.io/license: Apache-2.0
    meta.crossplane.io/description: |
      Oracle Cloud Infrastructure (OCI) provider for the ${SERVICE} service.
    friendly-name.meta.crossplane.io: OCI Provider (${SERVICE})
spec:
  crossplane:
    version: ">=v1.14.0"
  dependsOn:
    - provider: xpkg.upbound.io/upbound/provider-family-oci
      version: ">=v0.0.1"
EOF
  fi

  # Set up examples directory (optional — skip if not present)
  EXAMPLES_SVC_DIR="${EXAMPLES_DIR}/${SERVICE}"
  EXAMPLES_ARG=""
  if [ -d "${EXAMPLES_SVC_DIR}" ]; then
    EXAMPLES_ARG="--examples-root ${EXAMPLES_SVC_DIR}"
  fi

  # Build the xpkg
  mkdir -p "${OUTPUT_DIR}"
  OUTPUT_FILE="${OUTPUT_DIR}/${PKG_NAME}-${VERSION}.xpkg"

  if "${CROSSPLANE_CLI}" xpkg build \
      --package-root "${PKG_WORK_DIR}" \
      --embed-runtime-image "${RUNTIME_IMAGE}" \
      ${EXAMPLES_ARG} \
      --ignore "kustomization.yaml,auth.yaml" \
      --package-file "${OUTPUT_FILE}" 2>&1; then
    echo "[ OK ] Built ${OUTPUT_FILE}"
    SUCCESS+=("${SERVICE}")
  else
    echo "[FAIL] Failed to build xpkg for ${SERVICE}"
    FAILED+=("${SERVICE}")
  fi

  rm -rf "${PKG_WORK_DIR}"
  trap - EXIT
done

echo ""
echo "Done. ${#SUCCESS[@]} succeeded, ${#FAILED[@]} failed."
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "Failed services: ${FAILED[*]}"
  exit 1
fi
