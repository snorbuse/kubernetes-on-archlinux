#!/bin/bash

CERT_FILE='kubernetesmaster.pem'
KEY_FILE='kubernetesmaster-key.pem'
CSR_FILE='kubernetesmaster.csr'

echo -n "Kbn master IP addresses: "
read IP_LIST

echo -ne "subjectAltName = DNS:kbn-master01, DNS:kbn-master02" > extfile.cnf
for IP in $IP_LIST; do
  echo -ne ", IP:$IP" >> extfile.cnf
done

echo "Creating Kbn master private key"
openssl genrsa -out cert/$KEY_FILE 2048 

echo "Creating certificate signing request (csr)" 
openssl req -new -key cert/$KEY_FILE -out cert/$CSR_FILE -subj "/C=SE/ST=Sweden/O=Snorbuse/OU=Kubernetes on Arch linux/CN=Kubernetes master node" 

echo "Signing the CRS"
openssl x509 -req -in cert/$CSR_FILE -CA cert/rootCA.pem -CAkey cert/rootCA-key.pem -CAcreateserial -out cert/$CERT_FILE -days 500 -sha256 -extfile extfile.cnf 

# Cleaning up
rm extfile.cnf
rm cert/$CSR_FILE
