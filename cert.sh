#!/bin/bash
#set -x


BASEDIR="certificate"
CA="$BASEDIR/rootCA"
CAFILE="$BASEDIR/rootCA.pem"
CAKEY="$BASEDIR/rootCA-key.pem"
KUBELET="$BASEDIR/kubelet"
APISERVER="$BASEDIR/apiserver"
CNF=extfile.cnf
#DN="/C=SE/ST=Sweden/O=ORGANIZATION/OU=UNIT/CN=CNAME"
DN="/C=US/ST=Oregon/L=Portland/O=ORGANIZATION/OU=UNIT/CN=CNAME"

#C = US, ST = Oregon, L = Portland, O = system:masters, OU = Kubernetes The Hard Way, CN = admin

if [ ! -d $BASEDIR ]; then
  mkdir -p $BASEDIR
fi


function info    { 
  name=$1
  shift

  printf "%-10s [ %-23s ] %s\n" [INFO] $name "$*"
}
function warning { 
  echo "[WARNING] $*" 
}
function error { 
  echo "[ERROR]   $*" 
  exit 1
}

function createCNF {
    echo "keyUsage = critical,digitalSignature,keyEncipherment" > $CNF
    echo "extendedKeyUsage = serverAuth,clientAuth" >> $CNF
    echo "basicConstraints = critical,CA:false" >> $CNF
    echo "subjectKeyIdentifier = hash" >> $CNF
    echo "authorityKeyIdentifier = keyid" >> $CNF
    
    for args in "$@"; do
      echo $args >> $CNF
    done
}

function deleteCNF {
  rm $CNF
}

function generateKey {
  if [ "$#" -ne 1 ]; then
    error "Generate key did not get any key-file, Got '$*'"
  fi
  
  key=${1}
  openssl genrsa -out $key 2048 2> /dev/null 
}

function createCsr {
  key=$1
  csr=$2
  o=$3
  ou=$4
  cn=$5

  tmp=${DN/ORGANIZATION/$o}
  tmp=${tmp/UNIT/$ou}
  tmp=${tmp/CNAME/$cn}

  openssl req -new \
    -key $key \
    -out $csr \
    -subj "$tmp"
}

function signCsr {
  if [ "$#" -ne 2 ]; then
    error "Crf signing did not get 2 arguments. Got: '$*'"
  fi

  csr=${1}
  cert=${2}

  openssl x509 -req \
    -in $csr \
    -CA  $CAFILE \
    -CAkey $CAKEY \
    -CAcreateserial \
    -out $cert \
    -days 500 \
    -sha256 \
    -extfile extfile.cnf \
    2> /dev/null 
  rm $csr
}


function createCA {
  if [ ! -f $CAFILE ]; then
    info "CA" "Creating CA key"
    generateKey $CAKEY
  fi

  if [ ! -f $CA.pem ]; then
    info "CA" "Selfsigning the CA key"
    openssl req -x509 -new \
      -nodes \
      -key $CAKEY \
      -sha256 \
      -days 1024 \
      -out $CA.pem \
      -subj "/C=US/ST=Oregon/L=Portland/O=Kubernetes/OU=CA/CN=Kubernetes" \
       2> /dev/null
#      -subj "/C=SE/ST=Sweden/O=Kubernetes/OU=CA/CN=Kubernetes Root CA"\
  fi
}

function createKubelet {
  for IP in "$@"; do
    KEY=$KUBELET-$IP-key.pem 
    CSR=$KUBELET-$IP.csr 

    if [ ! -f $KEY ]; then
      createCNF "subjectAltName = IP: $IP" 

      info "KUBELET" "($IP) - Creating private key"
      generateKey $KEY

      info "KUBELET" "($IP) - Creating certificate signing request (csr)" 
      createCsr $KEY $CSR "system:nodes" "Kubernetes The Hard Way" "system:node:$IP"

      info "KUBELET" "($IP) - Signing the CRS"
      signCsr $CSR $KUBELET-$IP.pem 
    fi
  done
}

function createApiServer {
  for IP in "$@"; do
    KEY=$APISERVER-$IP-key.pem 
    CSR=$APISERVER-$IP.csr 

    if [ ! -f $KEY ]; then
      createCNF "subjectAltName = DNS: kubernetes.default, IP: 127.0.0.1, IP: $IP" 

      info "APISERVER" "($IP) - Creating private key"
      generateKey $KEY

      info "APISERVER" "($IP) - Creating certificate signing request (csr)" 
      createCsr $KEY $CSR "Kubernetes" "Kubernetes The Hard Way" "kubernetes"

      info "APISERVER" "($IP) - Signing the CRS"
      signCsr $CSR $APISERVER-$IP.pem 
    fi
  done
}


function createInfra {
  if [ "$#" -ne 3 ]; then
    error "CreateInfra did not get 3 arguments. Got: '$*'"
  fi
  
  file=$1
  o=$2
  cn=$3

  KEY="$BASEDIR/$file-key.pem" 
  CERT="$BASEDIR/$file.pem"
  CSR="$BASEDIR/$file.csr"

  if [ ! -f $KEY ]; then
    createCNF
    
    info ${file^^} "Creating private key"
    generateKey $KEY

    info ${file^^} "Creating certificate signing request (csr)" 
    createCsr $KEY $CSR $o "Kubernetes The Hard Way" $cn

    info ${file^^} "Signing the CRS"
    signCsr $CSR $CERT  
  fi
}

function findMasters {
  grep -B 100 \\[worker\\] ansible/hosts | grep --color=auto -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"
}

function findWorkers {
  grep -A 100 \\[worker\\] ansible/hosts | grep --color=auto -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b"
}

createCA

for IP in `findMasters`; do
  createApiServer $IP
done
for IP in `findWorkers`; do
  createKubelet $IP
done
createInfra "admin" "system:masters" "admin"
createInfra "kube-proxy" "system:node-proxier" "system:kube-proxy"
createInfra "serviceaccount" "Kubernetes" "service-accounts" 
createInfra "kube-scheduler" "system:kube-scheduler" "system:kube-scheduler"
createInfra "kube-controller-manager" "system:kube-controller-manager" "system:kube-controller-manager"

deleteCNF
