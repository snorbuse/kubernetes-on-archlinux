# kubernetes-on-archlinux

```
./create-ca.sh
./create-etcd-cert.sh
```

```
ansible-playbook playbooks/hosts.yaml -i hosts --ask-sudo-pass
```

```
ansible-playbook playbooks/etcd.yaml -i hosts --ask-sudo-pass
```
