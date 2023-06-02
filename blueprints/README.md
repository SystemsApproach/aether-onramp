OnRamp Blueprints
===============

Blueprints specify three sets of parameters that define how
Aether is configured and deployed: (1) a set of Makefile
variables that customize the deployment process; (2) a set
of Helm Charts that customize the Kubernetes workload that
gets deployed; and (3) a set of value override (and similar)
files that customize how the microservices in that workload
are configured. All of these parameters are defined in the
blueprint’s ``config`` file. Currently supported blueprints
include:

* ``latest``: Deploys the latest stable version of Aether in a
   single server (or VM), running an emulated RAN. 

* ``4g-radio``: Deploys the latest stable version of Aether in
   a single server (or VM), connected to a physical eNB. 

* ``5g-radio``: Deploys the latest stable version of Aether in
   a single server (or VM), connected to a physical gNB. 

* ``release-2.1.x``: Deploys Aether v2.1.x in a single server
    (or VM), running an emulated RAN.

Note that the first three blueprints do *not* depend on the most
recently published Helm Charts (as is the case for AiaB). All three
blueprints give explicit chart version numbers that have been
certified to work in OnRamp.

The release-numbered blueprints (e.g., ``release-2.1.33``) correspond
to specific versions of the ``AETHER_ROC_UMBRELLA_CHART``.
Since ROC defines and implements Aether's API, this represents the
semantic version of Aether's externally visible interface. A limited
number of such earlier version will be archived in this way.

As new Helm Charts are released, they are first tested and certified in
OnRamp's ``candidate`` branch before being merged into ``master``.

