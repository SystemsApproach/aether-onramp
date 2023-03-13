# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0


include ./MakefileVar.mk
include ./mk/*.mk

.PHONY: $(NET_PHONY) $(GITOPS_PHONY) $(AMP_PHONY) $(CORE_PHONY) node-prep clean

$(M):
	mkdir -p $(M)

cpu_family	:= $(shell lscpu | grep 'CPU family:' | awk '{print $$3}')
cpu_model	:= $(shell lscpu | grep 'Model:' | awk '{print $$2}')
os_vendor	:= $(shell lsb_release -i -s)
os_release	:= $(shell lsb_release -r -s)
USER		:= $(shell whoami)

$(M)/system-check: | $(M)
	@if [[ $(cpu_family) -eq 6 ]]; then \
		if [[ $(cpu_model) -lt 60 ]]; then \
			echo "FATAL: haswell CPU or newer is required."; \
			exit 1; \
		fi \
	else \
		echo "FATAL: unsupported CPU family."; \
		exit 1; \
	fi
	@if [[ $(os_vendor) =~ (Ubuntu) ]]; then \
		if [[ ! $(os_release) =~ (18.04) ]]; then \
			echo "WARN: $(os_vendor) $(os_release) has not been tested."; \
		fi; \
		if dpkg --compare-versions 4.15 gt $(shell uname -r); then \
			echo "FATAL: kernel 4.15 or later is required."; \
			echo "Please upgrade your kernel by running" \
			"apt install --install-recommends linux-generic-hwe-$(os_release)"; \
			exit 1; \
		fi \
	else \
		echo "FAIL: unsupported OS."; \
		exit 1; \
	fi
	touch $@


ifeq ($(K8S_INSTALL),rke2)
$(M)/initial-setup: | $(M) $(M)/interface-check
	sudo $(SCRIPTDIR)/cloudlab-disksetup.sh
	sudo apt update; sudo apt install -y software-properties-common python3 python3-pip python3-venv jq httpie ipvsadm apparmor apparmor-utils
	systemctl list-units --full -all | grep "docker.service" || sudo apt install -y docker.io
	sudo adduser $(USER) docker || true
	touch $(M)/initial-setup

ifeq ($(PROXY_ENABLED),true)
$(M)/proxy-setting: | $(M)
	echo "Defaults env_keep += \"HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy\"" | sudo EDITOR='tee -a' visudo -f /etc/sudoers.d/proxy
	echo "HTTP_PROXY=$(HTTP_PROXY)" >> rke2-server
	echo "HTTPS_PROXY=$(HTTPS_PROXY)" >> rke2-server
	echo "NO_PROXY=$(NO_PROXY),.cluster.local,.svc,$(NODE_IP),192.168.84.0/24,192.168.85.0/24,$(RAN_SUBNET)" >> rke2-server
	sudo mv rke2-server /etc/default/
	echo "[Service]" >> http-proxy.conf
	echo "Environment='HTTP_PROXY=$(HTTP_PROXY)'" >> http-proxy.conf
	echo "Environment='HTTPS_PROXY=$(HTTPS_PROXY)'" >> http-proxy.conf
	echo "Environment='NO_PROXY=$(NO_PROXY)'" >> http-proxy.conf
	sudo mkdir -p /etc/systemd/system/docker.service.d
	sudo mv http-proxy.conf /etc/systemd/system/docker.service.d
	sudo systemctl daemon-reload
	sudo systemctl restart docker
	touch $(M)/proxy-setting
else
$(M)/proxy-setting: | $(M)
	@echo -n ""
	touch $(M)/proxy-setting
endif

$(M)/setup: | $(M)/initial-setup $(M)/proxy-setting
	touch $@
endif


$(VENV)/bin/activate: | $(M)/setup
	python3 -m venv $(VENV)
	source "$(VENV)/bin/activate" && \
	python -m pip install -U pip && \
	deactivate


ifeq ($(K8S_INSTALL),rke2)
$(M)/k8s-ready: | $(M)/setup
	sudo mkdir -p /etc/rancher/rke2/
	[ -d /usr/local/etc/emulab ] && [ ! -e /var/lib/rancher ] && sudo ln -s /var/lib/rancher /mnt/extra/rancher || true  # that link gets deleted on cleanup
	echo "cni: multus,calico" >> config.yaml
	echo "cluster-cidr: 192.168.84.0/24" >> config.yaml
	echo "service-cidr: 192.168.85.0/24" >> config.yaml
	echo "kubelet-arg:" >> config.yaml
	echo "- --allowed-unsafe-sysctls="net.*"" >> config.yaml
	echo "- --node-ip="$(NODE_IP)"" >> config.yaml
	echo "pause-image: k8s.gcr.io/pause:3.3" >> config.yaml
	echo "kube-proxy-arg:" >> config.yaml
	echo "- --metrics-bind-address="0.0.0.0:10249"" >> config.yaml
	echo "- --proxy-mode="ipvs"" >> config.yaml
	echo "kube-apiserver-arg:" >> config.yaml
	echo "- --service-node-port-range="2000-36767"" >> config.yaml
	sudo mv config.yaml /etc/rancher/rke2/
	curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=$(RKE2_K8S_VERSION) sh -
	sudo systemctl enable rke2-server.service
	sudo systemctl start rke2-server.service
	sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml wait nodes --for=condition=Ready --all --timeout=300s
	sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml wait deployment -n kube-system --for=condition=available --all --timeout=300s
	curl -LO "https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/amd64/kubectl"
	sudo chmod +x kubectl
	sudo mv kubectl /usr/local/bin/
	kubectl version --client
	mkdir -p $(HOME)/.kube
	sudo cp /etc/rancher/rke2/rke2.yaml $(HOME)/.kube/config
	sudo chown -R $(shell id -u):$(shell id -g) $(HOME)/.kube
	touch $@

$(M)/helm-ready: | $(M)/k8s-ready
	curl -fsSL -o ${GET_HELM} https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
	chmod 700 ${GET_HELM}
	sudo DESIRED_VERSION=$(HELM_VERSION) ./${GET_HELM}
	helm repo add incubator https://charts.helm.sh/incubator
	helm repo add cord https://charts.opencord.org
	helm repo add atomix https://charts.atomix.io
	helm repo add onosproject https://charts.onosproject.org
	helm repo add aether https://charts.aetherproject.org
	helm repo add rancher http://charts.rancher.io/
	rm -f ${GET_HELM}
	touch $@
endif


/opt/cni/bin/static: | $(M)/k8s-ready
	mkdir -p $(BUILD)/cni-plugins; cd $(BUILD)/cni-plugins; \
	wget https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz && \
	tar xvfz cni-plugins-linux-amd64-v0.8.2.tgz
	sudo cp $(BUILD)/cni-plugins/static /opt/cni/bin/


node-prep: | $(M)/helm-ready /opt/cni/bin/static


ifeq ($(K8S_INSTALL),rke2)
clean: | roc-clean monitoring-clean core-clean router-clean
	sudo /usr/local/bin/rke2-uninstall.sh || true
	sudo rm -rf /usr/local/bin/kubectl
	rm -rf $(M)
endif

