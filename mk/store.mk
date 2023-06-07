# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

STORE_PHONY :=  store-prep local-path-ready store-clean

store-prep: node-prep
ifeq ($(STORE),local-path)
store-prep: $(M)/local-path-ready $(M)/store-prep
else
store-prep: $(M)/store-prep
endif
$(M)/store-prep:
	touch $@

$(M)/local-path-ready:
	@$(eval STORAGE_CLASS := $(shell /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get storageclass -o name))
	@echo "STORAGE_CLASS: ${STORAGE_CLASS}"
	if [ "$(STORAGE_CLASS)" == "" ]; then \
		sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/$(LPP_VERSION)/deploy/local-path-storage.yaml --wait=true; \
		sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'; \
	fi
	touch $@

store-clean:
	@cd $(M); rm -f store-prep local-path-ready
