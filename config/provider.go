/*
 * Copyright (c) 2023 Oracle and/or its affiliates
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package config

import (
	// Note(turkenh): we are importing this to embed provider schema document
	_ "embed"

	"github.com/crossplane/upjet/v2/pkg/config"

	reference "github.com/crossplane/upjet/v2/pkg/registry/reference"
	hack "github.com/oracle/provider-oci/hack"

	budgetCluster					"github.com/oracle/provider-oci/config/cluster/budget"
	certificatesmanagementCluster	"github.com/oracle/provider-oci/config/cluster/certificatesmanagement"
	containerengineCluster			"github.com/oracle/provider-oci/config/cluster/containerengine"
	coreCluster						"github.com/oracle/provider-oci/config/cluster/core"
	databaseCluster					"github.com/oracle/provider-oci/config/cluster/database"
	dnsCluster						"github.com/oracle/provider-oci/config/cluster/dns"
	emailCluster					"github.com/oracle/provider-oci/config/cluster/email"
	functionsCluster				"github.com/oracle/provider-oci/config/cluster/functions"
	healthchecksCluster				"github.com/oracle/provider-oci/config/cluster/healthchecks"
	identityCluster					"github.com/oracle/provider-oci/config/cluster/identity"
	kmsCluster						"github.com/oracle/provider-oci/config/cluster/kms"
	loadbalancerCluster				"github.com/oracle/provider-oci/config/cluster/loadbalancer"
	monitoringCluster				"github.com/oracle/provider-oci/config/cluster/monitoring"
	mysqlCluster					"github.com/oracle/provider-oci/config/cluster/mysql"
	networkfirewallCluster			"github.com/oracle/provider-oci/config/cluster/networkfirewall"
	networkloadbalancerCluster		"github.com/oracle/provider-oci/config/cluster/networkloadbalancer"
	nosqlCluster					"github.com/oracle/provider-oci/config/cluster/nosql"
	objectstorageCluster			"github.com/oracle/provider-oci/config/cluster/objectstorage"
	psqlCluster						"github.com/oracle/provider-oci/config/cluster/psql"
	recoveryCluster					"github.com/oracle/provider-oci/config/cluster/recovery"
	redisCluster					"github.com/oracle/provider-oci/config/cluster/redis"
	streamingCluster				"github.com/oracle/provider-oci/config/cluster/streaming"


	budgetNamespaced					"github.com/oracle/provider-oci/config/namespaced/budget"
	certificatesmanagementNamespaced	"github.com/oracle/provider-oci/config/namespaced/certificatesmanagement"
	containerengineNamespaced			"github.com/oracle/provider-oci/config/namespaced/containerengine"
	coreNamespaced						"github.com/oracle/provider-oci/config/namespaced/core"
	databaseNamespaced					"github.com/oracle/provider-oci/config/namespaced/database"
	dnsNamespaced						"github.com/oracle/provider-oci/config/namespaced/dns"
	emailNamespaced						"github.com/oracle/provider-oci/config/namespaced/email"
	functionsNamespaced					"github.com/oracle/provider-oci/config/namespaced/functions"
	healthchecksNamespaced				"github.com/oracle/provider-oci/config/namespaced/healthchecks"
	identityNamespaced					"github.com/oracle/provider-oci/config/namespaced/identity"
	kmsNamespaced						"github.com/oracle/provider-oci/config/namespaced/kms"
	loadbalancerNamespaced				"github.com/oracle/provider-oci/config/namespaced/loadbalancer"
	monitoringNamespaced				"github.com/oracle/provider-oci/config/namespaced/monitoring"
	mysqlNamespaced						"github.com/oracle/provider-oci/config/namespaced/mysql"
	networkfirewallNamespaced			"github.com/oracle/provider-oci/config/namespaced/networkfirewall"
	networkloadbalancerNamespaced		"github.com/oracle/provider-oci/config/namespaced/networkloadbalancer"
	nosqlNamespaced						"github.com/oracle/provider-oci/config/namespaced/nosql"
	objectstorageNamespaced				"github.com/oracle/provider-oci/config/namespaced/objectstorage"
	psqlNamespaced						"github.com/oracle/provider-oci/config/namespaced/psql"
	recoveryNamespaced					"github.com/oracle/provider-oci/config/namespaced/recovery"
	redisNamespaced						"github.com/oracle/provider-oci/config/namespaced/redis"
	streamingNamespaced					"github.com/oracle/provider-oci/config/namespaced/streaming"

)

const (
	resourcePrefix = "oci"
	modulePath     = "github.com/oracle/provider-oci"
)

//go:embed schema.json
var providerSchema string

//go:embed provider-metadata.yaml
var providerMetadata string

var ServiceWildcards = []string{
	".*",
}

// GetProvider returns provider configuration
func GetProvider() *config.Provider {
	pc := config.NewProvider([]byte(providerSchema), resourcePrefix, modulePath, []byte(providerMetadata),
		config.WithRootGroup("oci.upbound.io"),
		// This will include manually configured resources + resources corresponding to services listed in wildcards
		config.WithIncludeList(append(ExternalNameConfigured(), ServiceWildcards...)),
		config.WithSkipList(ProblematicResources()),
		config.WithDefaultResourceOptions(
			GroupKindOverrides(),
			ExternalNameConfigurations(),
			AutoExternalNameConfiguration(), // Automatic external name for unconfigured resources

		),
		config.WithReferenceInjectors([]config.ReferenceInjector{
			reference.NewInjector(modulePath),
			NewStaticReferenceInjector(),
		}),
		config.WithFeaturesPackage("internal/features"),
		config.WithMainTemplate(hack.MainTemplate),
	)

	for _, configure := range []func(provider *config.Provider){
		// add custom config functions
		objectstorageCluster.Configure,
		identityCluster.Configure,
		coreCluster.Configure,
		kmsCluster.Configure,
		containerengineCluster.Configure,
		networkloadbalancerCluster.Configure,
		dnsCluster.Configure,
		healthchecksCluster.Configure,
		functionsCluster.Configure,
		networkfirewallCluster.Configure,
		monitoringCluster.Configure,
		loadbalancerCluster.Configure,
		certificatesmanagementCluster.Configure,
		streamingCluster.Configure,
		mysqlCluster.Configure,
		psqlCluster.Configure,
		redisCluster.Configure,
		databaseCluster.Configure,
		recoveryCluster.Configure,
		nosqlCluster.Configure,
		emailCluster.Configure,
		budgetCluster.Configure,
	} {
		configure(pc)
	}

	pc.ConfigureResources()
	return pc
}

// GetProviderNamespaced returns namespaced provider configuration
func GetProviderNamespaced() *config.Provider {
	pc := config.NewProvider([]byte(providerSchema), resourcePrefix, modulePath, []byte(providerMetadata),
		config.WithRootGroup("oci.m.upbound.io"),
		// This will include manually configured resources + resources corresponding to services listed in wildcards
		config.WithIncludeList(append(ExternalNameConfigured(), ServiceWildcards...)),
		config.WithSkipList(ProblematicResources()),
		config.WithDefaultResourceOptions(
			GroupKindOverrides(),
			ExternalNameConfigurations(),
			AutoExternalNameConfiguration(), // Automatic external name for unconfigured resources

		),
		config.WithReferenceInjectors([]config.ReferenceInjector{
			reference.NewInjector(modulePath),
			NewStaticReferenceInjector(),
		}),
		config.WithFeaturesPackage("internal/features"),
		config.WithMainTemplate(hack.MainTemplate),
	)

	for _, configure := range []func(provider *config.Provider){
		// add custom config functions
		objectstorageNamespaced.Configure,
		identityNamespaced.Configure,
		coreNamespaced.Configure,
		kmsNamespaced.Configure,
		containerengineNamespaced.Configure,
		networkloadbalancerNamespaced.Configure,
		dnsNamespaced.Configure,
		healthchecksNamespaced.Configure,
		functionsNamespaced.Configure,
		networkfirewallNamespaced.Configure,
		monitoringNamespaced.Configure,
		loadbalancerNamespaced.Configure,
		certificatesmanagementNamespaced.Configure,
		streamingNamespaced.Configure,
		mysqlNamespaced.Configure,
		psqlNamespaced.Configure,
		redisNamespaced.Configure,
		databaseNamespaced.Configure,
		recoveryNamespaced.Configure,
		nosqlNamespaced.Configure,
		emailNamespaced.Configure,
		budgetNamespaced.Configure,
	} {
		configure(pc)
	}

	pc.ConfigureResources()
	return pc
}
