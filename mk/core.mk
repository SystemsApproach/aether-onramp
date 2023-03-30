# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

CORE_PHONY := 4g-core 5g-core core-clean

4g-core: node-prep net-prep
4g-core: $(M)/4g-core
$(M)/4g-core:
	@if [[ "${LOCAL_CHARTS}" == "true" ]]; then \
		helm dep up $(SD_CORE_CHART); \
	else \
		helm repo update; \
	fi
	NODE_IP=${NODE_IP} DATA_IFACE=${DATA_IFACE} RAN_SUBNET=${RAN_SUBNET} envsubst < $(4G_CORE_VALUES) | \
	helm upgrade --create-namespace --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace omec \
		--values - \
		sd-core \
		$(SD_CORE_CHART)
	@if [[ "${ENABLE_RANSIM}" == "false" ]]; then \
		$(eval mme_ip := $(shell ip -4 -o addr show $${DATA_IFACE} | awk '{print $$4}' | cut -d'/' -f1)) \
		echo "Your MME IP is $(mme_ip)"; \
	fi
	@touch $@

5g-core: net-prep net-prep
5g-core: $(M)/5g-core
$(M)/5g-core:
	@if [[ "${LOCAL_CHARTS}" == "true" ]]; then \
	        helm dep up $(SD_CORE_CHART); \
	else \
	        helm repo update; \
	fi
	NODE_IP=${NODE_IP} DATA_IFACE=${DATA_IFACE} RAN_SUBNET=${RAN_SUBNET} ENABLE_RANSIM=${ENABLE_RANSIM} envsubst < $(5G_CORE_VALUES) | \
	helm upgrade --create-namespace --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace omec \
		--values - \
		sd-core \
		$(SD_CORE_CHART)
	touch $@

core-clean:
	helm delete -n omec $$(helm -n omec ls -qa) || true
	@echo ""
	@echo "Wait for all pods to terminate..."
	kubectl wait -n omec --for=delete --all=true -l app!=ue pod --timeout=180s || true
	cd $(M); rm -f *-core

#
# Include testing targets for 5G only (assume 4G core with physical radios)
#

5g-test: | 5g-core
	@echo "Test: Registration + UE initiated PDU Session Establishment + User Data packets"
	@sleep 60
	@rm -f /tmp/gnbsim.out
	@if [[ ${GNBSIM_COLORS} == "true" ]]; then \
		kubectl -n omec exec gnbsim-0 -- ./gnbsim 2>&1 | tee /tmp/gnbsim.out; \
	else \
		kubectl -n omec exec gnbsim-0 -- ./gnbsim 2>&1 | sed -u "s,\x1B\[[0-9;]*[a-zA-Z],,g" | tee /tmp/gnbsim.out; \
	fi
	@grep -q "Simulation Result: PASS\|Profile Status: PASS" /tmp/gnbsim.out

reset-dbtestapp:
	helm uninstall --namespace omec 5g-test-app

dbtestapp:
	helm repo update
	if [ "$(LOCAL_CHARTS)" == "true" ]; then helm dep up $(5G_TEST_APPS_CHART); fi
	helm upgrade --install --wait $(HELM_GLOBAL_ARGS) \
		--namespace omec \
		5g-test-app \
		--values $(TEST_APP_VALUES) \
		$(5G_TEST_APPS_CHART)
	@echo "Finished to dbtestapp"

