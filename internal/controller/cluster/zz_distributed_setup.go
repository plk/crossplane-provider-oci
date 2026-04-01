/*
Copyright 2022 Upbound Inc.
*/

package controller

import (
	ctrl "sigs.k8s.io/controller-runtime"

	"github.com/crossplane/upjet/v2/pkg/controller"

	databasedistributedautonomousdatabase "github.com/oracle/provider-oci/internal/controller/cluster/distributed/databasedistributedautonomousdatabase"
	databasedistributeddatabase "github.com/oracle/provider-oci/internal/controller/cluster/distributed/databasedistributeddatabase"
	databasedistributeddatabaseprivateendpoint "github.com/oracle/provider-oci/internal/controller/cluster/distributed/databasedistributeddatabaseprivateendpoint"
)

// Setup_distributed creates all controllers with the supplied logger and adds them to
// the supplied manager.
func Setup_distributed(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		databasedistributedautonomousdatabase.Setup,
		databasedistributeddatabase.Setup,
		databasedistributeddatabaseprivateendpoint.Setup,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}

// SetupGated_distributed creates all controllers with the supplied logger and adds them to
// the supplied manager gated.
func SetupGated_distributed(mgr ctrl.Manager, o controller.Options) error {
	for _, setup := range []func(ctrl.Manager, controller.Options) error{
		databasedistributedautonomousdatabase.SetupGated,
		databasedistributeddatabase.SetupGated,
		databasedistributeddatabaseprivateendpoint.SetupGated,
	} {
		if err := setup(mgr, o); err != nil {
			return err
		}
	}
	return nil
}
