# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

GITOPS_PHONY := fleet-ready fleet-clean

fleet-ready: $(M)/fleet-ready
$(M)/fleet-ready: $(M)/helm-ready
	helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace=cattle-fleet-system \
		--create-namespace \
		fleet-crd \
		https://github.com/rancher/fleet/releases/download/v0.5.0/fleet-crd-0.5.0.tgz
	helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace=cattle-fleet-system \
		--create-namespace \
		fleet \
		https://github.com/rancher/fleet/releases/download/v0.5.0/fleet-0.5.0.tgz
	touch $(M)/fleet-ready $(M)/5g-core

fleet-clean:
	helm -n cattle-fleet-system delete fleet || true
	helm -n cattle-fleet-system delete fleet-crd || true
	kubectl delete namespace cattle-fleet-system || true
	rm -f $(M)/fleet-ready $(M)/5g-core
