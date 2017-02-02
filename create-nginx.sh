#!/bin/bash

CERT_FILE='nginx.pem'
KEY_FILE='nginx-key.pem'
CSR_FILE='nginx.csr'

echo -n "Kbn nginx IP addresses: "
read IP_LIST

echo -ne "subjectAltName = DNS:nginx.example.com, IP:10.32.0.1" > extfile.cnf
for IP in $IP_LIST; do
  echo -ne ", IP:$IP" >> extfile.cnf
done

echo "Creating Kbn nginx private key"
openssl genrsa -out cert/$KEY_FILE 2048 2> /dev/null

echo "Creating certificate signing request (csr)" 
openssl req -new -key cert/$KEY_FILE -out cert/$CSR_FILE -subj "/C=SE/ST=Sweden/O=Snorbuse/OU=Kubernetes on Arch linux/CN=nginx.example.com" 2> /dev/null

echo "Signing the CRS"
openssl x509 -req -in cert/$CSR_FILE -CA cert/rootCA.pem -CAkey cert/rootCA-key.pem -CAcreateserial -out cert/$CERT_FILE -days 500 -sha256 -extfile extfile.cnf 2> /dev/null

# Cleaning up
rm extfile.cnf
rm cert/$CSR_FILE
