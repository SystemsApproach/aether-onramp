.. vim: syntax=rst

Aether OnRamp
===============

Aether OnRamp is intended to provide an incremental path for users to

* First learn about and play with Aether;
* Then develop for and contribute to Aether; 
* And finally deploy and operate Aether.

Aether OnRamp is derived from `Aether-in-a-Box
(AiaB)<https://docs.aetherproject.org/master/developer/aiab.html#>`__,
refactored to help users step through a sequence of increasingly
complex configurations.

.. admonition:: ToDo
    The current version is mostly focused on how to bring up Aether.
    Still need to augment with guidance on how to interact with the
    running system, including how to make changes.
    
Configuration Options
-------------------------

To get started, Aether can be configured along three dimensions:

* Wireless Technology: 4G vs 5G.
* Target Server: VM v Physical Machine
* Target Workload: Emulated RAN vs Physical Base Station
	
Once you are familiar with these options (which are sufficient for learning
about Aether and/or developing for Aether), we add more complex
configurations. These include:

* Enabling GitOps deployment tools.
* Optimizing performance by enabling SR-IOV.
* Scaling from a signal server to multiple servers.

.. admonition:: ToDo
   Only the 5G/Physical Server/Emulated RAN configuration has been
   debugged at this point. Support for SR-IOV and multi-server
   clusters is still todo.

Eventually, bringing up multiple Aether clusters under the control of
a centralized management platform will be in scope, but that is a
long-term goal that we do not consider here.

Getting Started
---------------------

To initialize Aether OnRamp, first clone the Aether OnRamp repository on the
target deployment machine.

    cd ~
    git clone https://github.com/llpeterson/aether-onramp
    cd ~/aether-onramp

Then execute the following sequence of Make targets, where after each, run

    kubectl get pods --all-namespaces

to verify the set of Kubernetes namespaces that are now operational.

Bring Up Kubernetes Cluster
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The first step is to bring up an RKE2.0 Kubernetes cluster on your target server.
Do this by typing:

    make node-prep

`kubectl` will show the `kube-system` and `calico-system` namespaces running.

Connect Kubernetes to the Network
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Since Aether ultimately provides a 5G connectivity service, how the cluster you just
installed connects to the network is an important (and difficult to get right) detail.
As a first pass, Aether OnRamp borrows a configuration from AiaB; eventually, support
for optimizations like SR-IOV will also need to be included. Type:

    make router-pod

This target primarily configures Linux (via `systemctl`), but also starts a Quagga
router running inside the cluster.

Bring Up Aether Management Platform (AMP)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The runtime management of Aether is implemented by two Kubernetes
applications: Runtime Control (ROC) and a Monitoring Service. They can
be deployed on the same cluster with the following two Make targets:

	CHARTS=latest make roc-5g-models
	make 5g-monitoring

The first command brings up ROC and loads it with a data model for the
latest API. `kubectl` will show the `aether-roc` and `cattle-monitoring-system`
namespaces now running in support of these two services, respectively  (plus new
`atomic-runtime` pods in the `kube-system` name space).

Bring Up SD-Core
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We are now ready to bring up the 5G version of the SD-Core:

	CHARTS=latest make 5g-core

`kubectl` will show the `omec` namespace running. (For historical reasons, the
Core is called `omec` instead of `sd-core`).

Run Emulated Test of SD-Core
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We can now test SD-Core with emulated traffic by typing:

	make 5g-test

The monitoring dashboard shows two emulated gNBs come online and five
emulated UEs connect to them. (Click on the "5G Dashboard" once you
connect to the main page of the monitoring dashboard.)

This make target can be executed multiple times without restarting the
SD-Core.  (Note that `5g-test` runs an emulator that directs traffic
at Aether. It is not part of Aether, per se.)

Clean Up
~~~~~~~~~~~~~~~~~~~~

Working in reverse order, the following Make targets tear down the three applications
you just installed, restoring the base Kubernetes cluster (plus Quagga router):

	make omec-clean
	make monitoring-clean
	make roc-clean

If you want to also tear down Kubernetes for a fresh install, type:

	make router-clean
	make clean

Alternatively, leave Kubernetes (and the router) running, and instead
deploy the three applications using the GitOps approach (as described next).

GitOps Tooling
------------------------

The Make targets given above directly invoke Helm to install the
applications, using application-specific "values" files found the
cloned directory (e.g.,`~/aether-onramp/roc-values.yaml`) to overrides
the values for the correspond Helm charts. In an operational setting,
all the information needed to deploy a set of Kubernetes applications
is checked into a Git repo, with a tool like Fleet automatically
updating the deployment whenever changes to the configuration are
checked into the repo.

To see how this works, look at the `deploy.yaml` file included in the cloned
directory:

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

This particular version uses
`https://github.com/llpeterson/aether-apps` as its *source repo*. You
should fork that repo and edit `deploy.yaml` to point to your copy.
Then install Fleet on your Kubernetes cluster by typing

	make fleet-ready

Once complete, `kubectl` will show the `cattle-fleet-system` namespace  running.
All that's left is to type the following command to "activate" Fleet:

	kubectl apply -f deploy.yaml

The following command will let you track Fleet as it makes progress installing
bundles:

	kubectl -n fleet-local get bundles

Once complete, you can run the same emulated test against Aether:

	make 5g-test

Note that once you configure your cluster to use Fleet to deploy the Kubernetes
applications (e.g., ROC, Monitoring, SD-Core), the "clean" targets in the Makefile
will no longer work correctly: Fleet will persist in reinstalling any namespaces
that have been deleted. You have to instead first uninstall Fleet by typing:

	make fleet-clean

before executing the other "clean" targets.

.. admonition:: ToDo
   The set of bundles included in `aether-apps` is not complete. Still
   need to add missing pieces (e.g., the monitoring subsystem).
   

Enabling SR-IOV
------------------------

Adding Servers to the Cluster
-----------------------------
