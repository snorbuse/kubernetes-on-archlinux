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

### Ingress
When you have the DNS up and running it's time to create the ingress resources. Copy the kubernetes directory to one of the master nodes

Login to the master node and create the ingress resouces
```bash
user@desktop$ ssh kbn-master01
user@kbn-master01$ kubectl create -f kubernetes/ingress/

# Verify that the DNS pod is up and running
user@kbn-master01$ kubectl get pods 
NAME                             READY     STATUS    RESTARTS   AGE
default-http-backend-h4lp8       1/1       Running   0          1h
nginx-1x50k                      1/1       Running   0          1h
nginx-ingress-controller-48jgv   1/1       Running   0          1h
nginx-ingress-controller-ctgnp   1/1       Running   0          1h
nginx-ingress-controller-v75xg   1/1       Running   0          1h

# And verify that the ingress resource is created
dread@kbn-master01:~/kubernetes/ingress$ kubectl get ingress
NAME            HOSTS               ADDRESS            PORTS     AGE
example-nginx   nginx.example.com   192.168.1.95,...   80        1h

# Make sure the ingress routing is working
user@kbn-master01$ curl http://192.168.1.95 -H "Host: nginx.example.com"
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

### Ingress TLS
Next up is to secure the ingress connections. Create a key and cert for the nginx-resource by running the script create-nginx.sh.
```
# Base64-encode the cert and 
user@desktop$ cat cert/nginx.pem |base64 -w 0 > nginx.enc
user@desktop$ cat cert/nginx-key.pem |base64 -w 0 > nginx-key.enc

# Create the tls secret for Nginx
user@desktop$ cat nginx-tls-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nginxtls
  namespace: default
type: Opaque
data:
  tls.crt: <content of nginx.enc>
  tls.key: <content of nginx-key.enc>

# Copy the yaml to one of the master nodes
user@desktop$ scp nginx-tls-secret.yaml @kbn-master01:

# Create the secret
user@kbn-master01$ kubectl create -f nginx-tls-secret.yaml

# Modify the ingress resource for Nginx by adding the TLS part:
#  tls:
#  - hosts:
#    - nginx.example.com
#    secretName: tlsnginx
user@kbn-master01$ kubectl get ingress example-nginx -o yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: example-nginx
  namespace: default
spec:
  rules:
  - host: nginx.example.com
    http:
      paths:
      - backend:
          serviceName: nginxservice
          servicePort: 80
        path: /
  tls:
  - hosts:
    - nginx.example.com
    secretName: nginxtls

# Verify that it works
user@desktop$ curl -v --cacert cert/rootCA.pem https://nginx.example.com --resolve "nginx.example.com:443:192.168.1.144"
* Added nginx.example.com:443:192.168.1.144 to DNS cache
* Rebuilt URL to: https://nginx.example.com/
* Hostname nginx.example.com was found in DNS cache
*   Trying 192.168.1.144...
[...]
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>


```


## Storage
I use GlusterFS as a storage engine. It assumes that the masters has a 40GB volume at /dev/sdb1 
To create that volume, 
1. Open virt-manager and select one of the master machines
1. Add hardware --> Storage --> Add a 40gb LVM storage
1. Reboot the machine
1. Login to the machine
1. Partition the new disk with 'sudo fdisk /dev/sdb'
1. Press 'n' to create a new volume and select everything default
1. Press 'w' to write and quit fdisk
1. Verify that the disk is created with 'lsblk'

Repeat with the other master.

To install and configure GlusterFS just run it's playbook

```
ansible-playbook gluster.yaml -i hosts --ask-sudo-pass 
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
