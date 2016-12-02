# kubernetes-on-archlinux
Create the necessary certificates
```
./create-ca.sh
./create-etcd-cert.sh
./create-master.sh
./create-worker.sh

# Copy the certificates to corresponding directories
./copy-cert.sh
```

Run the Ansible playbooks to install Kuberneted
```
ansible-playbook playbooks/etcd.yaml -i hosts --ask-sudo-pass
```


## Curl
```
# From the node
curl -e /var/lib/kubernetes/kubernetesmaster-key.pem --cacert /var/lib/kubernetes/rootCA.pem -v https://192.168.1.57:6443/api/v1/namespaces/default/services/kubernetes -H "Authorization: Bearer secretPassW0rd"

# From inside a pod
curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -v https://10.32.0.1:443/api/v1/namespaces/default/services/kubernetes -H "Authorization: Bearer secretPassW0rd"
```
