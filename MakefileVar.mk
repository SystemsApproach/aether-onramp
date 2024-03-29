# Copyright 2018-present Open Networking Foundation
#
# SPDX-License-Identifier: Apache-2.0

BLUEPRINT  ?=  latest

SHELL		:= /bin/bash
MAKEDIR		:= $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
BUILD		?= $(MAKEDIR)/build
M           	?= $(BUILD)/milestones
SCRIPTDIR	:= $(MAKEDIR)/scripts
RESOURCEDIR	:= $(MAKEDIR)/resources
BLUEPRINTDIR	:= $(MAKEDIR)/blueprints/$(BLUEPRINT)
WORKSPACE	?= $(HOME)
VENV		?= $(BUILD)/venv/aiab

GET_HELM              = get_helm.sh

DOCKER_VERSION    ?= '20.10'
HELM_VERSION	  ?= v3.6.3
KUBECTL_VERSION   ?= v1.23.0

RKE2_K8S_VERSION  ?= v1.23.4+rke2r1
LPP_VERSION       ?= v0.0.24
K8S_VERSION       ?= v1.20.11

ENABLE_ROUTER ?= true
ENABLE_SUBSCRIBER_PROXY ?= false
GNBSIM_COLORS ?= true

K8S_INSTALL ?= rke2
CTR_CMD     := sudo /var/lib/rancher/rke2/bin/ctr --address /run/k3s/containerd/containerd.sock --namespace k8s.io

PROXY_ENABLED   ?= false
HTTP_PROXY      ?= ${http_proxy}
HTTPS_PROXY     ?= ${https_proxy}
NO_PROXY        ?= ${no_proxy}

HELM_GLOBAL_ARGS ?=

# Include blueprint-specific configuration parameters
include $(BLUEPRINTDIR)/config
