Aether OnRamp
===============

Aether OnRamp is intended to provide an incremental path for users to

* First learn about and play with Aether;
* Then develop for and contribute to Aether; 
* And finally deploy and operate Aether.

Aether OnRamp is derived from `Aether-in-a-Box (AiaB) <https://docs.aetherproject.org/master/developer/aiab.html#>`_, 
initially refactored to support only a streamlined sequenece of configurations,
but over time, augmented to support more scalable deployments.

As a first pass, Aether OnRamp is being debugged on a stand-alone server.
The plan is to go back and document how to bring Aether up on a VM on
your laptop, but this simpler configuration is already well documented
by AiaB, and so we do not include it here. (And in general, any time Aether
OnRamp documentation proves lacking, the answer is probably in the AiaB
guide.)

To initialize Aether OnRamp, first clone the following repository on the target
deployment machine.

    cd ~
    git clone "https://github.com/llpeterson/aether-onramp"
    cd ~/aether-onramp

Then execute the following sequence of Make targets, where after each, running

    kubectl get pods --all-namespaces

will show that the set of Kubernetes namespaces that are now operational.

Bring Up Kubernetes Cluster
---------------------------------

The first step is to bring up an RKE2.0 Kubernetes cluster on your target server.
Do this by typing:

    make node-prep

`kubectl` will show the `kube-sysetm` and `calico-system` namespaces running.

Connect Kubernetes to the Network
---------------------------------------

Since Aether ultimately provides a 5G connectivity service, how the cluster you just
installed connects to the network is an important (and difficult to get right) detail.
As a first pass, Aether OnRamp borrows a configuration from AiaB; eventually, support
for optimizations like SR-IOV will also need to be included.

    make router-pod

This target primarily configures Linux (via `systemctl`), but also starts a Quagga
router running inside the cluster.

Bring Up Aether Management Platform (AMP)
-----------------------------------------------

The runtime management of Aether is implemented by two Kubernetes
applications: Runtime Control (ROC) and a Monitoring Service. They can
be deployed on the same cluster with the following two Make targets:

	CHARTS=latest make roc-5g-models
	make 5g-monitoring

The first command both brings up ROC and loads it with a data model for the
latest API. `kubectl` will show the `aether-roc` and `cattle-monitoring-system`
namespaces now running in support of these two services, respectively  (plus new
`atomic-runtime` pods in the `kube-system` name space).

Bring Up SD-Core
-------------------------

Now we are ready to bring up the 5G version of the SD-Core:

	CHARTS=latest make 5g-core

`kubectl` will show the `omec` namespace running. (For historical reasons, the
Core is called `omec` instead of `sd-core`).

Run Emulated Test of SD-Core
-------------------------------------------

You can now test SD-Core with emulated traffic by typing:

	make 5g-test

You can watch the monitoring dashboard as two emulated gNBs come online
and five emulated UEs connect to them. (Click on the "5G Dashboard" once you
connect to the main page of the monitoring dashboard.)

This make target can be executed multiple times without restarting the SD-Core.
(Note that `5g-test` runs "outside" Kubernetes; it runs a workload against Aether,
but is not part of Aether, per se.)

Clean Up
-----------------

Working in reverse order, the following Make targets tear down the three applications
you just installed, restoring you to the base Kubernetes cluster, plus Quagga router:

	make omec-clean
	make monitoring-clean
	make roc-clean

If you want to also tear down Kubernetes for a fresh install, type:

	make router-clean
	make clean

Alternatively, leave Kubernetes (and the router) running, and instead
work deploy the three applications using Fleet (as described next).

GitOps Tooling
------------------------

The Make targets given above directly invoke Helm to install the applications,
using application-specific `values.yaml` files found the cloned directory
(e.g.,`~/aether-onramp/roc-values.yaml` overrides the values for the ROC
helm chart). In an operational setting, all the information needed to deploy
a set of Kubernetes applications is checked into a Git repo, with a tool like Fleet
automatically updating the deployment whenever changes to the configuration
are checked into the repo.

To see how this works, look at the `deploy.yaml` file included in the cloned
directory:

	apiVersion: fleet.cattle.io/v1alpha1
	kind: GitRepo
	metadata:
		name: aiab
		namespace: fleet-local
	spec:
		repo: "https://github.com/llpeterson/fleet-aiab"  # Replace with your fork
		branch: main
		paths:
		- aether-2.1-alpha   # Specify one of "aether-2.0" or "aether-2.1-alpha"

This particular version uses `https://github.com/llpeterson/fleet-aiab` as its
"source" repo. You should fork that repo and edit `deploy.yaml` accordingly.
Then install Fleet on your Kubernetes cluster by typing

	make fleet-ready

Once complete, `kubectl` will show the `fleet-system` running. All that's left is
to type the following to "activate" Fleet:

	kubectl apply -f deploy.yaml

The following command will let you track Fleet as it makes progress installing bundles:

	kubectl -n fleet-local get bundles

Once complete, you can run the same emulated test against Aether:

	make 5g-test

