# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

# This approach to network configuration is derived from AiaB
# Target "router-pod" is used when the RAN is emulated
# Target "router-host" is used when using external gNB
#
# Main Makefile depends on "interface-check"
# SD-Core Makefile depends on "router-pod" or "router-host"

NET_PHONY :=  net-prep router-pod router-host net-clean


DATA_IFACE ?= data
ifeq ($(DATA_IFACE), data)
	RAN_SUBNET := 192.168.251.0/24
else
	RAN_SUBNET := $(shell ip route | grep $${DATA_IFACE} | awk '/kernel/ {print $$1}' | head -1)
	DATA_IFACE_PATH := $(shell find /*/systemd/network -maxdepth 1 -not -type d -name '*$(DATA_IFACE).network' -print)
	DATA_IFACE_CONF ?= $(shell basename $(DATA_IFACE_PATH)).d
endif

# systemd-networkd and systemd configs
LO_NETCONF            := /etc/systemd/network/20-aiab-lo.network
OAISIM_NETCONF        := $(LO_NETCONF) /etc/systemd/network/10-aiab-enb.netdev /etc/systemd/network/20-aiab-enb.network
ROUTER_POD_NETCONF    := /etc/systemd/network/10-aiab-dummy.netdev /etc/systemd/network/20-aiab-dummy.network
ROUTER_HOST_NETCONF   := /etc/systemd/network/10-aiab-access.netdev /etc/systemd/network/20-aiab-access.network /etc/systemd/network/10-aiab-core.netdev /etc/systemd/network/20-aiab-core.network /etc/systemd/network/$(DATA_IFACE_CONF)/macvlan.conf
UE_NAT_CONF           := /etc/systemd/system/aiab-ue-nat.service

NODE_IP ?= $(shell ip route get 8.8.8.8 | grep -oP 'src \K\S+')
ifndef NODE_IP
$(error NODE_IP is not set)
endif


$(M)/interface-check: | $(M)
ifeq ($(DATA_IFACE_CONF), .d)
	@echo
	@echo FATAL: Could not find systemd-networkd config for interface $(DATA_IFACE), exiting now!; exit 1
endif
	@echo "Add network configuration for enb interface"
	@if [[ "${ONECLOUD}" ==  "true" ]]; then \
		sudo cp netplan/01-enb-static-config.yaml /etc/netplan ; \
		sudo netplan apply ; \
		sleep 1 ; \
	fi
	touch $@

net-prep: node-prep
ifeq ($(ENABLE_ROUTER),true)
ifeq ($(ENABLE_RANSIM),true)
net-prep: $(M)/router-pod
else
net-prep: $(M)/router-host
endif
endif
net-prep: $(M)/net-prep
$(M)/net-prep:
	touch $@


router-pod: | $(M)/router-pod
$(M)/router-pod: $(ROUTER_POD_NETCONF)
	sudo systemctl restart systemd-networkd
	DATA_IFACE=$(DATA_IFACE) envsubst < $(RESOURCEDIR)/router.yaml | kubectl apply -f -
	kubectl wait pod -n default --for=condition=Ready -l app=router --timeout=300s
	@touch $@


$(M)/router-host: $(ROUTER_HOST_NETCONF) $(UE_NAT_CONF)
	sudo systemctl daemon-reload
	sudo systemctl enable aiab-ue-nat.service
	sudo systemctl start aiab-ue-nat.service
	sudo systemctl restart systemd-networkd
	$(eval oiface := $(shell ip route list default | awk -F 'dev' '{ print $$2; exit }' | awk '{ print $$1 }'))
	@touch $@


/etc/systemd/%:
	@sudo mkdir -p $(@D)
	@sed 's/DATA_IFACE/$(DATA_IFACE)/g' $(MAKEDIR)/systemd/$(@F) > /tmp/$(@F)
	@sudo cp /tmp/$(@F) $@
	echo "Installed $@"


net-clean:
	@kubectl delete net-attach-def router-net 2>/dev/null || true
	@kubectl delete po router 2>/dev/null || true
	kubectl wait --for=delete -l app=router pod --timeout=180s 2>/dev/null || true
	sudo ip link del access || true
	sudo ip link del core || true
	$(eval oiface := $(shell ip route list default | awk -F 'dev' '{ print $$2; exit }' | awk '{ print $$1 }'))
	sudo iptables -t nat -D POSTROUTING -s 172.250.0.0/16 -o $(oiface) -j MASQUERADE || true
	@sudo ip link del data 2>/dev/null || true
	cd /etc/systemd/network && sudo rm -f 10-aiab* 20-aiab* */macvlan.conf
	cd /etc/systemd/system && sudo rm -f aiab*.service && sudo systemctl daemon-reload
	@cd $(M); rm -f router-pod router-host net-prep
