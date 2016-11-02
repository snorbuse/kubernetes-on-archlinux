#!/bin/bash

echo -n "Kbn master IP addresses: "
read ETCD_IP_LIST

echo -ne "subjectAltName = DNS:kbn-master01, DNS:kbn-master02" > kbnmaster-extfile.cnf
for IP in $ETCD_IP_LIST; do
  echo -ne ", IP:$IP" >> kbnmaster-extfile.cnf
done

echo "Creating Kbn master private key"
openssl genrsa -out cert/kbnmaster-key.pem 2048 2> /dev/null

echo "Creating certificate signing request (CSR)" 
openssl req -new -key cert/kbnmaster-key.pem -out cert/kbnmaster.csr -subj "/C=SE/ST=Sweden/O=Snorbuse/OU=Kubernetes on Arch linux/CN=Kubernetes master daemon" 2> /dev/null

echo "Signing the CRS"
openssl x509 -req -in cert/kbnmaster.csr -CA cert/rootCA.pem -CAkey cert/rootCA.key -CAcreateserial -out cert/kbnmaster.pem -days 500 -sha256 -extfile kbnmaster-extfile.cnf 2> /dev/null

# Cleaning up
rm kbnmaster-extfile.cnf
rm cert/kbnmaster.csr
