Aether OnRamp
===============

Aether OnRamp is intended to provide an incremental path for users to

* First learn about and play with Aether;
* Then develop for and contribute to Aether; 
* And finally deploy and operate Aether.

Aether OnRamp is derived from [Aether-in-a-Box
(AiaB)](https://docs.aetherproject.org/master/developer/aiab.html#),
refactored to help users step through a sequence of increasingly
complex configurations.

> TODO: The current version is mostly focused on how to bring up
> Aether. Need to augment with guidance on how to interact with the
> running system, including how to make changes. Much still to be
> lifted from the AiaB guide.

> TODO: Several "refactoring/cleanup" tasks remain, including: (1) strip
> unused targets and config options from the Makefile and deleted them
> from the repo; and (2) treat different version of Aether (e.g., 2.0 vs 2.1) in
> a uniform way.

> TODO: Still need to give a clear description of how to point your browser
> at the relevant dashboards.

## Configuration Options

Aether supports several configuration options, but the primary goal
of OnRamp is to prescribe a (mostly) linear sequence of steps a new
user can follow to bring up an operational system. This document
also identifies "alternate paths" you can follow, but does not
document them in detail.

With the goal of first learning about Aether, there are two relevant
questions:

* Do you want to bring up a 4G or a 5G network?
* Do you want to run Aether in a VM or on a physical server?
	
All four combinations are supported (see the
[AiaB Guide](https://docs.aetherproject.org/master/developer/aiab.html#)
for more details), but for our purposes, we start with a 5G deployment
running on a physical server. It will include an emulated RAN instead
of a physical base station.

Once you are familiar with this configuration, which is sufficient for learning
about Aether, we add more complex configurations. These include:

* Enabling GitOps deployment tools.
* Connecting a physical base station.
* Optimizing performance by enabling SR-IOV.
* Scaling from a signal server to multiple servers.

Eventually, bringing up multiple Aether clusters under the control of
a centralized management platform will be in scope, but that is a
long-term goal that we do not consider here.

## Stage 1: Bring Up Aether

Aether OnRamp assumes a physical server, which should meet the
following requirements:

* Haswell CPU (or newer), with at least 4 CPUs and 12GB RAM.
* Clean install of Ubuntu 18.04, 20.04, or 22.04, with 4.15 (or later) kernel.

You must be able able to run `sudo` without a password, and there
should be no firewall running on the server, which you can verify as
follows:

* `sudo ufw status` should show inactive;
* `sudo iptables -L` and `sudo nft list` should show a blank configuration.

Once ready, clone the Aether OnRamp repository on this target deployment machine:

```
    cd ~
    git clone https://github.com/llpeterson/aether-onramp
    cd ~/aether-onramp
```

You will then execute the sequence of Makefiles targets described in
the rest of this section. After each of these steps, run the following
command to verify the specified set of Kubernetes namespaces that are
now operational.

```
    kubectl get pods --all-namespaces
```

If you are not familiar with `kubectl` (the CLI for Kubernetes), we
recommend that you start with
[Kubernetes Tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/).


### Install Kubernetes

The first step is to bring up an RKE2.0 Kubernetes cluster on your target server.
Do this by typing:

```
    make node-prep
```

`kubectl` will show the `kube-system` and `calico-system` namespaces running.

### Connect Kubernetes to the Network

Since Aether ultimately provides a connectivity service, how the
cluster you just installed connects to the network is an important
detail. As a first pass, Aether OnRamp borrows a configuration from
AiaB; eventually, support for optimizations like SR-IOV will also need
to be included. Type:

```
    make router-pod
```
This target configures Linux (via `systemctl`), but also starts a Quagga
router running inside the cluster.

### Bring Up Aether Management Platform

The runtime management of Aether is implemented by two Kubernetes
applications: Runtime Control (ROC) and a Monitoring Service. They can
be deployed on the same cluster with the following two Make targets:

```
    CHARTS=latest make roc-5g-models
    make 5g-monitoring
```
	
The first command brings up ROC and loads it with a data model for the
latest API. `kubectl` will show the `aether-roc` and
`cattle-monitoring-system` namespaces now running in support of these
two services, respectively  (plus new `atomic-runtime` pods in the
`kube-system` name space).

> TODO: Need to find a clean way to deal with ROC models and
> Monitoring resources (that will also work with Fleet). Might also
> make sense to combine the two subsystems into a single target
> (e.g., "make amp").

### Bring Up SD-Core

We are now ready to bring up the 5G version of the SD-Core:

```
    CHARTS=latest make 5g-core
```

`kubectl` will show the `omec` namespace running. (For historical
reasons, the Core is called `omec` instead of `sd-core`).

### Run Emulated RAN Test

We can now test SD-Core with emulated traffic by typing:

```
    make 5g-test
```

The monitoring dashboard shows two emulated gNBs come online and five
emulated UEs connect to them. (Click on the "5G Dashboard" once you
connect to the main page of the monitoring dashboard.)

This make target can be executed multiple times without restarting the
SD-Core.  (Note that `5g-test` runs an emulator that directs traffic
at Aether. It is not part of Aether, per se.)

### Clean Up

Working in reverse order, the following Make targets tear down the three applications
you just installed, restoring the base Kubernetes cluster (plus Quagga router):

```
    make omec-clean
    make monitoring-clean
    make roc-clean
```

If you want to also tear down Kubernetes for a fresh install, type:

```
    make router-clean
    make clean
```

Alternatively, leave Kubernetes (and the router) running, and instead
deploy the three applications using the GitOps approach (as described
in the next section).

## Stage 2: Add GitOps Tooling

The Makefile targets given above directly invoke Helm to install the
applications, using application-specific *values files* found the
cloned directory (e.g.,`~/aether-onramp/roc-values.yaml`) to override
the values for the correspond Helm charts. In an operational setting,
all the information needed to deploy a set of Kubernetes applications
is checked into a Git repo, with a tool like Fleet automatically
updating the deployment whenever it detects changes to the configuration
checked into the repo.

To see how this works, look at the `deploy.yaml` file included in the cloned
directory:

```
    apiVersion: fleet.cattle.io/v1alpha1
    kind: GitRepo
    metadata:
        name: aiab
        namespace: fleet-local
    spec:
        repo: "https://github.com/llpeterson/aether-apps"  # Replace with your fork
        branch: main
	    paths:
        - aether-2.1-alpha   # Specify one of "aether-2.0" or "aether-2.1-alpha"
```

This particular version uses
`https://github.com/llpeterson/aether-apps` as its *source repo*. You
should fork that repo and edit `deploy.yaml` to point to your copy.
Then install Fleet on your Kubernetes cluster by typing

```
    make fleet-ready
```

Once complete, `kubectl` will show the `cattle-fleet-system` namespace  running.
All that's left is to type the following command to "activate" Fleet:

```
    kubectl apply -f deploy.yaml
```

The following command will let you track Fleet as it makes progress
installing bundles:

```
    kubectl -n fleet-local get bundles
```

Once complete, you can run the same emulated test against Aether:

```
    make 5g-test
```

Note that once you configure your cluster to use Fleet to deploy the
Kubernetes applications (e.g., ROC, Monitoring, SD-Core), the "clean"
targets in the Makefile will no longer work correctly: Fleet will
persist in reinstalling any namespaces that have been deleted. You
have to instead first uninstall Fleet by typing:

```
    make fleet-clean
```

before executing the other "clean" targets.

> TODO: The set of bundles included in the *aether-apps* repo is not complete.
> Still need to add missing pieces (e.g., the monitoring subsystem).

## Stage 3: Connect Physical Base Station

## Stage 4: Enable SR-IOV

## Stage5:  Add Servers to the Cluster
