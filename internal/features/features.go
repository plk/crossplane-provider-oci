/*
 Copyright 2022 Upbound Inc
*/

package features

import "github.com/crossplane/crossplane-runtime/v2/pkg/feature"

// Feature flags.
const (
	// EnableBetaManagementPolicies enables beta support for
	// Management Policies. See the below design for more details.
	// https://github.com/crossplane/crossplane/blob/main/design/design-doc-management-policies.md
	EnableBetaManagementPolicies feature.Flag = "EnableBetaManagementPolicies"
)
