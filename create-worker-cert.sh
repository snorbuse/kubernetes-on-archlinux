#!/bin/bash

echo -n "Kbn worker IP addresses: "
read ETCD_IP_LIST

echo -ne "subjectAltName = DNS:kbn-worker01, DNS:kbn-worker02, DNS:kbn-worker03" > kbnworker-extfile.cnf
for IP in $ETCD_IP_LIST; do
  echo -ne ", IP:$IP" >> kbnworker-extfile.cnf
done

echo "Creating Kbn worker private key"
openssl genrsa -out cert/kbnworker-key.pem 2048 2> /dev/null

echo "Creating certificate signing request (CSR)" 
openssl req -new -key cert/kbnworker-key.pem -out cert/kbnworker.csr -subj "/C=SE/ST=Sweden/O=Snorbuse/OU=Kubernetes on Arch linux/CN=Kubernetes worker daemon" 2> /dev/null

echo "Signing the CRS"
openssl x509 -req -in cert/kbnworker.csr -CA cert/rootCA.pem -CAkey cert/rootCA.key -CAcreateserial -out cert/kbnworker.pem -days 500 -sha256 -extfile kbnworker-extfile.cnf 2> /dev/null

# Cleaning up
rm kbnworker-extfile.cnf
rm cert/kbnworker.csr
