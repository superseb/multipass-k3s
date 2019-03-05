#!/usr/bin/env bash

# Configure your settings
# Name for the cluster/configuration files
NAME=""
# Ubuntu image to use (xenial/bionic)
IMAGE="xenial"
# How many machines to create
SERVER_COUNT_MACHINE="1"
# How many machines to create
AGENT_COUNT_MACHINE="1"
# How many CPUs to allocate to each machine
SERVER_CPU_MACHINE="1"
AGENT_CPU_MACHINE="1"
# How much disk space to allocate to each machine
SERVER_DISK_MACHINE="3G"
AGENT_DISK_MACHINE="3G"
# How much memory to allocate to each machine
SERVER_MEMORY_MACHINE="512M"
AGENT_MEMORY_MACHINE="256M"

## Nothing to change after this line
if [ -x "$(command -v multipass.exe)" > /dev/null 2>&1 ]; then
    # Windows
    MULTIPASSCMD="multipass.exe"
elif [ -x "$(command -v multipass)" > /dev/null 2>&1 ]; then
    # Linux/MacOS
    MULTIPASSCMD="multipass"
else
    echo "The multipass binary (multipass or multipass.exe) is not available or not in your \$PATH"
    exit 1
fi

# Cloud init template
read -r -d '' SERVER_CLOUDINIT_TEMPLATE << EOM
#cloud-config

runcmd:
 - '\curl -sfL https://get.k3s.io | sh -'
 - '\bash -c "until test -f /var/lib/rancher/k3s/server/node-token; do sleep 1; done; cp /var/lib/rancher/k3s/server/node-token /home/multipass/node-token; chown multipass /home/multipass/node-token"'
EOM

# Cloud init template
read -r -d '' AGENT_CLOUDINIT_TEMPLATE << EOM
#cloud-config

runcmd:
 - '\sudo wget -O /usr/local/bin/k3s https://github.com/rancher/k3s/releases/download/v0.1.0/k3s'
 - '\sudo chmod +x /usr/local/bin/k3s'
 - '\sudo /usr/local/bin/k3s agent -s __SERVER_URL__ -t __NODE_TOKEN__ &'
EOM

# Check if name is given or create random string
if [ -z $NAME ]; then
    NAME=$(cat /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1 | tr '[:upper:]' '[:lower:]')
    echo "No name given, generated name: ${NAME}"
fi

echo "Creating cluster ${NAME} with ${SERVER_COUNT_MACHINE} servers and ${AGENT_COUNT_MACHINE} agents"

# Prepare cloud-init
echo "$SERVER_CLOUDINIT_TEMPLATE" > "${NAME}-cloud-init.yaml"
echo "Cloud-init is created at ${NAME}-cloud-init.yaml"

for i in $(eval echo "{1..$SERVER_COUNT_MACHINE}"); do
    echo "Running $MULTIPASSCMD launch --cpus $SERVER_CPU_MACHINE --disk $SERVER_DISK_MACHINE --mem $SERVER_MEMORY_MACHINE $IMAGE --name k3s-server-$NAME-$i --cloud-init ${NAME}-cloud-init.yaml"                                                                                                                                           
    $MULTIPASSCMD launch --cpus $SERVER_CPU_MACHINE --disk $SERVER_DISK_MACHINE --mem $SERVER_MEMORY_MACHINE $IMAGE --name k3s-server-$NAME-$i --cloud-init "${NAME}-cloud-init.yaml"
    if [ $? -ne 0 ]; then
        echo "There was an error launching the instance"
        exit 1
    fi
done

for i in $(eval echo "{1..$SERVER_COUNT_MACHINE}"); do
    echo "Checking for Node being Ready on k3s-server-${NAME}-${i}"
    $MULTIPASSCMD exec k3s-server-$NAME-$i -- /bin/bash -c 'while [[ $(k3s kubectl get nodes --no-headers 2>/dev/null | grep -c -v "NotReady") -eq 0 ]]; do sleep 2; done'
    echo "Node is Ready on k3s-server-${NAME}-${i}"
done

# Retrieve info to join agent to cluster
SERVER_IP=$($MULTIPASSCMD info k3s-server-$NAME-1 | grep IPv4 | awk '{ print $2 }')
URL="https://$(echo $SERVER_IP | sed -e 's/[[:space:]]//g'):6443"
$MULTIPASSCMD copy-files k3s-server-$NAME-1:/home/multipass/node-token $NAME-node-token
NODE_TOKEN=$(cat $NAME-node-token)

# Prepare agent cloud-init
echo "$AGENT_CLOUDINIT_TEMPLATE" | sed -e "s^__SERVER_URL__^$URL^" -e "s^__NODE_TOKEN__^$NODE_TOKEN^" > "${NAME}-agent-cloud-init.yaml"
echo "Cloud-init is created at ${NAME}-agent-cloud-init.yaml"

for i in $(eval echo "{1..$AGENT_COUNT_MACHINE}"); do
    echo "Running $MULTIPASSCMD launch --cpus $AGENT_CPU_MACHINE --disk $AGENT_DISK_MACHINE --mem $AGENT_MEMORY_MACHINE $IMAGE --name k3s-agent-$NAME-$i --cloud-init ${NAME}-agent-cloud-init.yaml"
    $MULTIPASSCMD launch --cpus $AGENT_CPU_MACHINE --disk $AGENT_DISK_MACHINE --mem $AGENT_MEMORY_MACHINE $IMAGE --name k3s-agent-$NAME-$i --cloud-init "${NAME}-agent-cloud-init.yaml"
    if [ $? -ne 0 ]; then
        echo "There was an error launching the instance"
        exit 1
    fi
    echo "Checking for Node k3s-agent-$NAME-$i being registered"
    $MULTIPASSCMD exec k3s-server-$NAME-1 -- bash -c "until k3s kubectl get nodes --no-headers | grep -c k3s-agent-$NAME-1 >/dev/null; do sleep 2; done" 
    echo "Checking for Node k3s-agent-$NAME-$i being Ready"
    $MULTIPASSCMD exec k3s-server-$NAME-1 -- bash -c "until k3s kubectl get nodes --no-headers | grep k3s-agent-$NAME-1 | grep -c -v NotReady >/dev/null; do sleep 2; done" 
    echo "Node k3s-agent-$NAME-$i is Ready on k3s-server-${NAME}-1"
done

$MULTIPASSCMD copy-files k3s-server-$NAME-1:/etc/rancher/k3s/k3s.yaml $NAME-kubeconfig-orig.yaml
sed "/^[[:space:]]*server:/ s_:.*_: \"https://$(echo $SERVER_IP | sed -e 's/[[:space:]]//g'):6443\"_" $NAME-kubeconfig-orig.yaml > $NAME-kubeconfig.yaml

echo "k3s setup finished"
$MULTIPASSCMD exec k3s-server-$NAME-1 -- k3s kubectl get nodes
echo "You can now use the following command to connect to your cluster"
echo "$MULTIPASSCMD exec k3s-server-${NAME}-1 -- k3s kubectl get nodes"
echo "Or use kubectl directly"
echo "kubectl --kubeconfig ${NAME}-kubeconfig.yaml get nodes"
