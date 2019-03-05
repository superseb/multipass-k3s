# k3s cluster on multipass instances

This script will create a configurable amount of instances using [multipass](https://github.com/CanonicalLtd/multipass/), install [k3s](https://github.com/rancher/k3s) server (no HA yet), and add the agent instances to the cluster.

## Requirements

* multipass (See [multipass: Getting it](https://github.com/CanonicalLtd/multipass#getting-it))

This is tested on MacOS, Ubuntu Linux 16.04 and 18.04 and Windows 10.

## Running it

Clone this repo, and run the script:

```
bash multipass-k3s.sh
```

This will (defaults):

* Generate random name for your cluster (configurable using `NAME`)
* Create cloud-init file for server to install k3s server.
* Create one instance for server with 1 CPU (`CPU_MACHINE`), 5G disk (`DISK_MACHINE`) and 1G of memory (`MEMORY_MACHINE`) using Ubuntu xenial (`IMAGE`)
* Create cloud-init file for agent to join the cluster.
* Create one machine (configurable using `AGENT_COUNT_MACHINE`) with 1 CPU (`CPU_MACHINE`), 5G disk (`DISK_MACHINE`) and 1G of memory (`MEMORY_MACHINE`) using Ubuntu xenial (`IMAGE`)
* Wait for the nodes to be joined to the cluster


## Quickstart Ubuntu 16.04 droplet

```
sudo snap install multipass --beta --classic
wget https://raw.githubusercontent.com/superseb/multipass-k3s/master/multipass-k3s.sh
bash multipass-k3s.sh
curl -Lo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x /usr/local/bin/kubectl
kubectl --kubeconfig *-kubeconfig.yaml get nodes
```

## Clean up

The files that are created are:

* `$NAME-agent-cloud-init.yaml`
* `$NAME-cloud-init.yaml`
* `$NAME-kubeconfig.yaml`
* `$NAME-node-token`

You can clean up the instances by running `multipass delete k3s-server-$NAME-1 --purge` and `multipass delete k3s-agent-$NAME-{1,2,3}` or (**WARNING** this deletes and purges all instances): `multipass delete --all --purge`
