# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

AMP_PHONY := roc 4g-roc 5g-roc roc-clean monitoring 4g-monitoring 5g-monitoring monitoring-clean

roc: $(M)/roc
$(M)/roc: $(M)/helm-ready
	kubectl get namespace aether-roc 2> /dev/null || kubectl create namespace aether-roc
	helm repo update
	if [ "$(CHARTS)" == "roc-local" ]; then helm dep up $(AETHER_ROC_UMBRELLA_CHART); fi
	if [ "$(CHARTS)" == "release-2.0" -o "$(CHARTS)" == "release-1.6" ]; then \
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

# Load the ROC 4G models.  Disable loading network slice from SimApp.
4g-roc: $(M)/roc
	sed -i 's/provision-network-slice: true/provision-network-slice: false/' $(4G_CORE_VALUES)
	sed -i 's/# syncUrl/syncUrl/' $(4G_CORE_VALUES)
	if [ "${ENABLE_SUBSCRIBER_PROXY}" == "true" ] ; then \
		sed -i 's/# sub-proxy-endpt:/sub-proxy-endpt:/' $(4G_CORE_VALUES) ; \
		sed -i 's/#   addr: sub/  addr: sub/' $(4G_CORE_VALUES) ; \
		sed -i 's/#   port: 5000/  port: 5000/' $(4G_CORE_VALUES) ; \
	fi
	@$(eval ONOS_CLI_POD := $(shell kubectl -n aether-roc get pods -l name=onos-cli -o name))
	echo "ONOS CLI pod: ${ONOS_CLI_POD}"
	@$(eval API_SERVICE := $(shell kubectl -n aether-roc get --no-headers=true services -l app.kubernetes.io/name=aether-roc-api | awk '{print $$1}'))
	echo "API SERVICE : ${API_SERVICE}"
	if [ "$(CHARTS)" != "release-2.0" -a "$(CHARTS)" != "release-1.6" ]; then \
        until kubectl -n aether-roc exec ${ONOS_CLI_POD} -- \
            curl -s -f -L -X PATCH "http://${API_SERVICE}:8181/aether-roc-api" \
            --header 'Content-Type: application/json' \
            --data-raw "$$(cat ${ROC_DEFAULTENT_MODEL})"; do sleep 5; done; \
	fi
	until kubectl -n aether-roc exec ${ONOS_CLI_POD} -- \
		curl -s -f -L -X PATCH "http://${API_SERVICE}:8181/aether-roc-api" \
		--header 'Content-Type: application/json' \
		--data-raw "$$(cat ${ROC_4G_MODELS})"; do sleep 5; done

# Load the ROC 5G models.  Disable loading network slice from SimApp.
5g-roc: $(M)/roc
	sed -i 's/provision-network-slice: true/provision-network-slice: false/' $(5G_CORE_VALUES)
	sed -i 's/# syncUrl/syncUrl/' $(5G_CORE_VALUES)
	if [ "${ENABLE_SUBSCRIBER_PROXY}" == "true" ] ; then \
		sed -i 's/# sub-proxy-endpt:/sub-proxy-endpt:/' $(5G_CORE_VALUES) ; \
		sed -i 's/#   addr: sub/  addr: sub/' $(5G_CORE_VALUES) ; \
		sed -i 's/#   port: 5000/  port: 5000/' $(5G_CORE_VALUES) ; \
	fi
	@$(eval ONOS_CLI_POD := $(shell kubectl -n aether-roc get pods -l name=onos-cli -o name))
	echo "ONOS CLI pod: ${ONOS_CLI_POD}"
	@$(eval API_SERVICE := $(shell kubectl -n aether-roc get --no-headers=true services -l app.kubernetes.io/name=aether-roc-api | awk '{print $$1}'))
	echo "API SERVICE : ${API_SERVICE}"
	if [ "$(CHARTS)" != "release-2.0" -a "$(CHARTS)" != "release-1.6" ]; then \
        until kubectl -n aether-roc exec ${ONOS_CLI_POD} -- \
            curl -s -f -L -X PATCH "http://${API_SERVICE}:8181/aether-roc-api" \
            --header 'Content-Type: application/json' \
            --data-raw "$$(cat ${ROC_DEFAULTENT_MODEL})"; do sleep 5; done; \
	fi
	until kubectl -n aether-roc exec ${ONOS_CLI_POD} -- \
		curl -s -f -L -X PATCH "http://${API_SERVICE}:8181/aether-roc-api" \
		--header 'Content-Type: application/json' \
		--data-raw "$$(cat ${ROC_5G_MODELS})"; do sleep 5; done

roc-clean:
	@echo "This could take 2-3 minutes..."
	sed -i 's/provision-network-slice: false/provision-network-slice: true/' $(4G_CORE_VALUES)
	sed -i 's/  syncUrl/  # syncUrl/' $(4G_CORE_VALUES)
	sed -i 's/  sub-proxy-endpt:/  # sub-proxy-endpt:/' $(4G_CORE_VALUES)
	sed -i 's/    addr: sub/  #   addr: sub/' $(4G_CORE_VALUES)
	sed -i 's/    port: 5000/  #   port: 5000/' $(4G_CORE_VALUES)
	sed -i 's/provision-network-slice: false/provision-network-slice: true/' $(5G_CORE_VALUES)
	sed -i 's/  syncUrl/  # syncUrl/' $(5G_CORE_VALUES)
	sed -i 's/  sub-proxy-endpt:/  # sub-proxy-endpt:/' $(5G_CORE_VALUES)
	sed -i 's/    addr: sub/  #   addr: sub/' $(5G_CORE_VALUES)
	sed -i 's/    port: 5000/  #   port: 5000/' $(5G_CORE_VALUES)
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
