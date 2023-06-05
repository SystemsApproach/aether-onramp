# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

AMP_PHONY := roc 4g-roc 5g-roc roc-clean monitoring 4g-monitoring 5g-monitoring monitoring-clean

roc: $(M)/roc
$(M)/roc: $(M)/helm-ready
	kubectl get namespace aether-roc 2> /dev/null || kubectl create namespace aether-roc
	helm repo update
	if [ "$(LOCAL_CHARTS)" == "true" ]; then helm dep up $(AETHER_ROC_UMBRELLA_CHART); fi
	if [ "$(BLUEPRINT)" == "release-2.0" ]; then \
		helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
			--namespace kube-system \
			--values $(ROC_VALUES) \
			atomix-controller \
			$(ATOMIX_CONTROLLER_CHART); \
		helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
			--namespace kube-system \
			--values $(ROC_VALUES) \
			atomix-raft-storage \
			$(ATOMIX_RAFT_STORAGE_CHART); \
	else \
		helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
			--namespace kube-system \
			--values $(ROC_VALUES) \
			atomix-runtime \
			$(ATOMIX_RUNTIME_CHART); \
		kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml --wait=true; \
		kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'; \
	fi
	helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace kube-system \
		--values $(ROC_VALUES) \
		onos-operator \
		$(ONOS_OPERATOR_CHART)
	helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace aether-roc \
		--values $(ROC_VALUES) \
		aether-roc-umbrella \
		$(AETHER_ROC_UMBRELLA_CHART)
	touch $@

# Load the ROC 4G models.
4g-roc: $(M)/roc
	@$(eval ONOS_CLI_POD := $(shell kubectl -n aether-roc get pods -l name=onos-cli -o name))
	echo "ONOS CLI pod: ${ONOS_CLI_POD}"
	@$(eval API_SERVICE := $(shell kubectl -n aether-roc get --no-headers=true services -l app.kubernetes.io/name=aether-roc-api | awk '{print $$1}'))
	echo "API SERVICE : ${API_SERVICE}"
	until kubectl -n aether-roc exec ${ONOS_CLI_POD} -- \
		curl -s -f -L -X PATCH "http://${API_SERVICE}:8181/aether-roc-api" \
		--header 'Content-Type: application/json' \
		--data-raw "$$(cat ${ROC_4G_MODELS})"; do sleep 5; done

# Load the ROC 5G models.
5g-roc: $(M)/roc
	@$(eval ONOS_CLI_POD := $(shell kubectl -n aether-roc get pods -l name=onos-cli -o name))
	echo "ONOS CLI pod: ${ONOS_CLI_POD}"
	@$(eval API_SERVICE := $(shell kubectl -n aether-roc get --no-headers=true services -l app.kubernetes.io/name=aether-roc-api | awk '{print $$1}'))
	echo "API SERVICE : ${API_SERVICE}"
	until kubectl -n aether-roc exec ${ONOS_CLI_POD} -- \
		curl -s -f -L -X PATCH "http://${API_SERVICE}:8181/aether-roc-api" \
		--header 'Content-Type: application/json' \
		--data-raw "$$(cat ${ROC_5G_MODELS})"; do sleep 5; done

roc-clean:
	@echo "This could take 2-3 minutes..."
	kubectl delete namespace aether-roc || true
	rm -f $(M)/roc

monitoring: $(M)/monitoring
$(M)/monitoring: $(M)/helm-ready
	helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace=cattle-monitoring-system \
		--create-namespace \
		--values=$(MONITORING_VALUES) \
		rancher-monitoring-crd \
		$(RANCHER_MONITORING_CRD_CHART)
	helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace=cattle-monitoring-system \
		--create-namespace \
		--values=$(MONITORING_VALUES) \
		rancher-monitoring \
		$(RANCHER_MONITORING_CHART)
	touch $(M)/monitoring

4g-monitoring: $(M)/monitoring
	kubectl create namespace omec || true
	kubectl create namespace cattle-dashboards || true
	kubectl apply -k resources/4g-monitoring

5g-monitoring: $(M)/monitoring
	kubectl create namespace omec || true
	kubectl create namespace cattle-dashboards || true
	kubectl apply -k resources/5g-monitoring

monitoring-clean:
	helm -n cattle-monitoring-system delete rancher-monitoring || true
	helm -n cattle-monitoring-system delete rancher-monitoring-crd || true
	kubectl delete namespace cattle-dashboards cattle-monitoring-system || true
	rm -f $(M)/monitoring
