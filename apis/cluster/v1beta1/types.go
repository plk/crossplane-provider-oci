/*
Copyright 2022 Upbound Inc.
*/

package v1beta1

import (
	xpv2 "github.com/crossplane/crossplane-runtime/v2/apis/common/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// A ProviderConfigSpec defines the desired state of a ProviderConfig.
type ProviderConfigSpec struct {
	// Credentials required to authenticate to this provider.
	Credentials ProviderCredentials `json:"credentials"`
}

// ProviderCredentials required to authenticate.
type ProviderCredentials struct {
	// Source of the provider credentials.
	// +kubebuilder:validation:Enum=Secret;InjectedIdentity;Environment;Filesystem
	Source xpv2.CredentialsSource `json:"source"`

	xpv2.CommonCredentialSelectors `json:",inline"`
}

// A ProviderConfigStatus reflects the observed state of a ProviderConfig.
type ProviderConfigStatus struct {
	xpv2.ProviderConfigStatus `json:",inline"`
}

// +kubebuilder:object:root=true

// A ProviderConfig configures a Oracle Cloud Infrastructure (OCI) provider.
// +kubebuilder:printcolumn:name="AGE",type="date",JSONPath=".metadata.creationTimestamp"
// +kubebuilder:resource:scope=Cluster,categories={crossplane,provider,oci}
// +kubebuilder:subresource:status
type ProviderConfig struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ProviderConfigSpec   `json:"spec"`
	Status ProviderConfigStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// ProviderConfigList contains a list of ProviderConfig.
type ProviderConfigList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ProviderConfig `json:"items"`
}

// A ProviderConfigUsage indicates that a resource is using a ProviderConfig.
// +kubebuilder:object:root=true
// +kubebuilder:resource:scope=Cluster,categories={crossplane,provider,oci}
type ProviderConfigUsage struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	xpv2.ProviderConfigUsage `json:",inline"`
}

// GetProviderConfigReference of this ProviderConfigUsage.
func (pc *ProviderConfigUsage) GetProviderConfigReference() xpv2.Reference {
	return pc.ProviderConfigReference
}

// GetResourceReference of this ProviderConfigUsage.
func (pc *ProviderConfigUsage) GetResourceReference() xpv2.TypedReference {
	return pc.ResourceReference
}

// SetProviderConfigReference of this ProviderConfigUsage.
func (pc *ProviderConfigUsage) SetProviderConfigReference(r xpv2.Reference) {
	pc.ProviderConfigReference = r
}

// SetResourceReference of this ProviderConfigUsage.
func (pc *ProviderConfigUsage) SetResourceReference(r xpv2.TypedReference) {
	pc.ResourceReference = r
}

// +kubebuilder:object:root=true

// ProviderConfigUsageList contains a list of ProviderConfigUsage.
type ProviderConfigUsageList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ProviderConfigUsage `json:"items"`
}
