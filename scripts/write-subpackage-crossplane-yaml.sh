#!/usr/bin/env bash
# Write crossplane.yaml for a sub-package.
# Usage: write-subpackage-crossplane-yaml.sh <service> <pkg-name> <output-file>
set -euo pipefail

SERVICE="$1"
PKG_NAME="$2"
OUTPUT="$3"

if [ "${SERVICE}" = "config" ]; then
  cat > "${OUTPUT}" <<EOF
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
  cat > "${OUTPUT}" <<EOF
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
