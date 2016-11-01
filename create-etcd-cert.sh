#!/bin/bash

echo -n "Etcd IP addresses: "
read ETCD_IP_LIST

echo -ne "subjectAltName = DNS:etcd01, DNS:etcd02" > etcd-extfile.cnf
for IP in $ETCD_IP_LIST; do
  echo -ne ", IP:$IP" >> etcd-extfile.cnf
done

echo "Creating Etcd private key"
openssl genrsa -out cert/etcd-key.pem 2048 2> /dev/null

echo "Creating certificate signing request (CSR)" 
openssl req -new -key cert/etcd-key.pem -out cert/etcd.csr -subj "/C=SE/ST=Sweden/O=Snorbuse/OU=Kubernetes on Arch linux/CN=Etcd daemon" 2> /dev/null

echo "Signing the CRS"
openssl x509 -req -in cert/etcd.csr -CA cert/rootCA.pem -CAkey cert/rootCA.key -CAcreateserial -out cert/etcd.pem -days 500 -sha256 -extfile etcd-extfile.cnf 2> /dev/null

# Cleaning up
rm etcd-extfile.cnf
rm cert/etcd.csr
