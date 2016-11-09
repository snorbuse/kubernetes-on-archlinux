#!/bin/bash
mkdir cert 2> /dev/null

echo "Creating CA key"
openssl genrsa -out cert/rootCA-key.pem 2048 2> /dev/null

echo "Selfsigning the CA key"
openssl req -x509 -new -nodes -key cert/rootCA-key.pem -sha256 -days 1024 -out cert/rootCA.pem -subj "/C=SE/ST=Sweden/O=Snorbuse/OU=Kubernetes on Arch linux/CN=Root CA" 2> /dev/null
