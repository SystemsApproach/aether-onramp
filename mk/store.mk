# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

# Define the storage option here (for now)
# Eventually belongs in blueprints/*/config
#   but also need to modify roc-values.yaml
#   accordingly (currently longhorn-specific)
STORE ?= longhorn

STORE_PHONY :=  store-prep longhorn-ready store-clean

store-prep: node-prep
ifeq ($(STORE),longhorn)
store-prep: $(M)/longhorn-ready
endif

store-prep: $(M)/store-prep
$(M)/store-prep:
	touch $@

$(M)/longhorn-ready:
	sudo systemctl enable iscsid.service
	sudo systemctl start iscsid.service
	curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.4.2/scripts/environment_check.sh | bash
	sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.2/deploy/longhorn.yaml
	sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml wait nodes --for=condition=Ready --all --timeout=300s
	sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml wait deployment -n longhorn-system --for=condition=available --all --timeout=300s
	touch $@

store-clean:
	@echo "This could take 2-3 minutes..."
	kubectl delete namespace longhorn-system || true
	@cd $(M); rm -f longhorn-ready store-prep
