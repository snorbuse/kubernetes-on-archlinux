#!/bin/bash

BASEDIR="configuration"
CERTDIR="certificate"
# The IP of the master(s)
PUBLIC_ADDRESS="192.168.1.66"

if [ ! -d $BASEDIR ]; then
  mkdir -p $BASEDIR
fi

function createKubelet {
  for IP in "$@"; do
      kubectl config set-cluster kubernetes-the-hard-way \
      --certificate-authority=$CERTDIR/rootCA.pem \
      --embed-certs=true \
      --server=https://${PUBLIC_ADDRESS}:6443 \
      --kubeconfig=$BASEDIR/kubelet-${IP}.kubeconfig

    kubectl config set-credentials system:node:${IP} \
      --client-certificate=$CERTDIR/kubelet-${IP}.pem \
      --client-key=$CERTDIR/kubelet-${IP}-key.pem \
      --embed-certs=true \
      --kubeconfig=$BASEDIR/kubelet-${IP}.kubeconfig

    kubectl config set-context default \
      --cluster=kubernetes-the-hard-way \
      --user=system:node:${IP} \
      --kubeconfig=$BASEDIR/kubelet-${IP}.kubeconfig

    kubectl config use-context default --kubeconfig=kubelet-${IP}.kubeconfig
  done
}

function createProxy {
 kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=$CERTDIR/rootCA.pem \
    --embed-certs=true \
    --server=https://${PUBLIC_ADDRESS}:6443 \
    --kubeconfig=$BASEDIR/kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=$CERTDIR/kube-proxy.pem \
    --client-key=$CERTDIR/kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=$BASEDIR/kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=$BASEDIR/kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=$BASEDIR/kube-proxy.kubeconfig
}

function createControllerManager {
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=$CERTDIR/rootCA.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=$BASEDIR/kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=$CERTDIR/kube-controller-manager.pem \
    --client-key=$CERTDIR/kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=$BASEDIR/kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=$BASEDIR/kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=$BASEDIR/kube-controller-manager.kubeconfig
}

function createScheduler {
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=$CERTDIR/rootCA.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=$BASEDIR/kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=$CERTDIR/kube-scheduler.pem \
    --client-key=$CERTDIR/kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=$BASEDIR/kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=$BASEDIR/kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=$BASEDIR/kube-scheduler.kubeconfig
}

function createAdmin {
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=$CERTDIR/rootCA.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=$BASEDIR/admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=$CERTDIR/admin.pem \
    --client-key=$CERTDIR/admin-key.pem \
    --embed-certs=true \
    --kubeconfig=$BASEDIR/admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=$BASEDIR/admin.kubeconfig

  kubectl config use-context default --kubeconfig=$BASEDIR/admin.kubeconfig
}

function createEncryptionKey {
  ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

  cat > $BASEDIR/encryption-config.yaml <<EOF
  kind: EncryptionConfig
  apiVersion: v1
  resources:
    - resources:
        - secrets
      providers:
        - aescbc:
            keys:
              - name: key1
                secret: ${ENCRYPTION_KEY}
        - identity: {}
EOF

}

createKubelet "10.0.1.10" "10.0.1.11"
createProxy
createControllerManager
createScheduler
createAdmin
createEncryptionKey
