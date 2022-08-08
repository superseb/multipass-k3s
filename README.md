# k3s cluster on multipass instances

This script will create a configurable amount of instances using [multipass](https://github.com/CanonicalLtd/multipass/), install [k3s](https://github.com/rancher/k3s) server(s) (HA using embedded etcd), and add the agent instances to the cluster.

## Requirements

* multipass (See [multipass: Install Multipass](https://github.com/canonical/multipass#install-multipass))

This is tested on MacOS, Ubuntu Linux 20.04 and Windows 10.

## Running it

Clone this repo, and run the script:

```
bash multipass-k3s.sh
```

This will (defaults):

* Generate random name for your cluster (configurable using `NAME`)
* Create init-cloud-init file for server to install the first k3s server with embedded etcd (contains --cluster-init to activate embedded etcd)
* Create one instance for the first server with 2 CPU (`SERVER_CPU_MACHINE`), 10G disk (`SERVER_DISK_MACHINE`) and 1G of memory (`SERVER_MEMORY_MACHINE`) using Ubuntu focal (`IMAGE`)
* Create cloud-init file for server to install additional k3s servers with embedded etcd.
* Create one instance for additional server (configurable using `SERVER_COUNT_MACHINE`)
* Create cloud-init file for agent to join the cluster.
* Create one machine (configurable using `AGENT_COUNT_MACHINE`) with 1 CPU (`AGENT_CPU_MACHINE`), 3G disk (`AGENT_DISK_MACHINE`) and 512M of memory (`AGENT_MEMORY_MACHINE`) using Ubuntu focal (`IMAGE`)
* Wait for the nodes to be joined to the cluster
* Optionally merge the generated kubeconfig with the existing $KUBECONFIG (`MERGE_KUBECONFIG`)

## Quickstart Ubuntu 20.04 droplet

```
sudo snap install multipass
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
* `$NAME-kubeconfig-orig.yaml`
* `$NAME-kubeconfig-backup.yaml` (if `MERGE_KUBECONFIG` is set)
* `$NAME-kubeconfig-merged.yaml` (if `MERGE_KUBECONFIG` is set)

You can clean up the instances by running `multipass delete k3s-server-$NAME-1 --purge` and `multipass delete k3s-agent-$NAME-{1,2,3}` or (**WARNING** this deletes and purges all instances): `multipass delete --all --purge`
