#!/bin/bash
mkdir cert

echo "Creating CA key"
openssl genrsa -out cert/rootCA.key 2048 2> /dev/null

echo "Selfsigning the CA key"
openssl req -x509 -new -nodes -key cert/rootCA.key -sha256 -days 1024 -out cert/rootCA.pem -subj "/C=SE/ST=Sweden/O=Snorbuse/OU=Kubernetes on Arch linux/CN=Root CA" 2> /dev/null
