#!/bin/bash

mkdir -p ansible/roles/etcd/files/ 2> /dev/null
cp cert/etcd*.pem ansible/roles/etcd/files/
cp cert/rootCA.pem ansible/roles/etcd/files/

mkdir -p ansible/roles/master/files/ 2> /dev/null
cp cert/kubernetesmaster*.pem ansible/roles/master/files/
cp cert/rootCA.pem ansible/roles/master/files/

mkdir -p ansible/roles/worker/files/ 2> /dev/null
cp cert/kubernetesworker*.pem ansible/roles/worker/files/
cp cert/rootCA.pem ansible/roles/worker/files/

mkdir -p ansible/roles/flannel/files/ 2> /dev/null
cp cert/kubernetesworker*.pem ansible/roles/flannel/files/
cp cert/rootCA.pem ansible/roles/flannel/files/


mkdir -p ansible/roles/flannel-register/files/ 2> /dev/null
cp cert/kubernetesworker*.pem ansible/roles/flannel-register/files/
cp cert/rootCA.pem ansible/roles/flannel-register/files/
