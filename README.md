# Kubernetes on Archlinux with Ansible

## Purpose
The purpose of this guide is a) for me to learn more about Kubernetes, and since I'm a lazy mf I wanted to automate everything so b) is to learn Ansible.

## Prerequisites
This guide installs Kubernetes on a five node VM setup where all the VM:s runs a freshly installed Arch linux. It also assumes that you have ssh-keys configure so you can reach your VM:s directly from your desktop without using password.

## Installation with Ansible

## Layout
* Server 1 & 2 (192.168.1.11, 192.168.1.12)
  * etcd
  * kube-apiserver
  * kube-scheduler
  * kube-controller-manager
* Server 3, 4 & 5 (192.168.1.101, 192.168.1.102, 192.168.1.103)
  * kubelet
  * kubeproxy
  * flannel

### Certificate
First of all you need the necessary certificates for Etcd and for the master and worker nodes. Just run each script and enter the IP addresses for each of the corresponding servers.

```bash
./create-ca.sh
./create-etcd-cert.sh
./create-master.sh
./create-worker.sh

# Copy the certificates to the Ansible directories
./copy-cert.sh
```

### Installation
Create the hosts file from the hosts.example file, and edit the IP addresses to correspond to the IP addresses of your machines.

```bash
cd ansible/
cp hosts.example hosts
```

Then it's just a matter of running the playbooks

```bash
ansible-playbook site.yaml -i hosts --ask-sudo-pass
```

If everything works fine you should now have a working Kubernetes cluster. Login to one of your master-nodes and check the status.

```bash
user@kbn-master01$ kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok                   
controller-manager   Healthy   ok                   
etcd-0               Healthy   {"health": "true"} 

user@kbn-master01$ kubectl get nodes
NAME           STATUS    AGE
kbn-worker01   Ready     1h
kbn-worker02   Ready     1h
kbn-worker03   Ready     1h
```

### DNS
When you have your cluster up and running it's time to create the internal DNS service. Copy the kubernetes directory to one of the master nodes

```bash
user@desktop$ scp -r kubernetes @kbn-master01:
```

Login to the master node and create the DNS service
```bash
user@desktop$ ssh kbn-master01
user@kbn-master01$ kubectl create -f kubernetes/dns/

# Verify that the DNS pod is up and running
user@kbn-master01$ kubectl get pods -n kube-system
NAME                            READY     STATUS    RESTARTS   AGE
kube-dns-v20-3026914318-bkuvf   3/3       Running   0          2m
```

Let's smoketest the DNS service by creating an Nginx server and then make a DNS-lookup for that server.

```bash
# Create the pods
user@kbn-master01$ kubectl create -f kubernetes/smoketest/nginx.yaml
user@kbn-master01$ kubectl create -f kubernetes/smoketest/busybox-pod.yaml

# Verify that the pods are up and running
user@kbn-master01$ kubectl get pods
NAME                             READY     STATUS    RESTARTS   AGE
busybox                          1/1       Running   0          3m
nginx-alg9j                      1/1       Running   0          3m

# Make the DNS lookup from the Busybox pod to Nginx server
user@kbn-master01$ kubectl exec -it busybox nslookup nginxservice
Server:    10.32.0.10
Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local

Name:      nginxservice
Address 1: 10.32.0.249 nginxservice.default.svc.cluster.local
```

## Misc commands

## Curl the apiserver
```base
# From the node
curl --cacert /var/lib/kubernetes/rootCA.pem -H "Authorization: Bearer secretPassW0rd" https://kbn-master01:6443/ 

# From inside a pod
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt  -H "Authorization: Bearer secretPassW0rd" https://10.32.0.1:443/
```

## ToDo
- GlusterFs volume claims
- Add Docker registry
- Add Jenkins
  - Make Jenkins build Docker-images
- Cluster federation
