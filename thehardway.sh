#!/bin/bash

# kubernetes 1.15.3
# containerd 1.2.9
# coredns v1.6.3
# cni v0.7.1
# etcd v3.4.0

# change hostname
TEMP_LOCAL_IP=$(ip add | grep 172.16 | awk '{print($2)}' | rev | cut -c4- | rev)
if [[ $TEMP_LOCAL_IP == '172.16.0.11' ]]; then
  hostnamectl set-hostname master01
  TEMP_LOCAL_HOSTNAME='master01'
fi
if [[ $TEMP_LOCAL_IP == '172.16.0.12' ]]; then
  hostnamectl set-hostname master02
  TEMP_LOCAL_HOSTNAME='master02'
fi
if [[ $TEMP_LOCAL_IP == '172.16.0.21' ]]; then
  hostnamectl set-hostname k8s-w1
  TEMP_LOCAL_HOSTNAME='worker01'
fi
if [[ $TEMP_LOCAL_IP == '172.16.0.22' ]]; then
  hostnamectl set-hostname k8s-w2
  TEMP_LOCAL_HOSTNAME='worker02'
fi
if [[ $TEMP_LOCAL_IP == '172.16.0.23' ]]; then
  hostnamectl set-hostname k8s-w3
  TEMP_LOCAL_HOSTNAME='worker03'
fi

# Add DNS records
echo 172.16.0.11  master01 >> /etc/hosts
echo 172.16.0.12  master02 >> /etc/hosts
echo 172.16.0.21  worker01 >> /etc/hosts
echo 172.16.0.22  worker02 >> /etc/hosts
echo 172.16.0.23  worker03 >> /etc/hosts

# update packages
yum update -y
yum install -y wget net-tools tcpdump git

# disable FW
systemctl stop firewalld
systemctl disable firewalld

# Turn off swap and update fstab
swapoff -a
sed -i  '/swap/d' /etc/fstab

# Get cfssl util
wget -q \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssl \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssljson
chmod +x cfssl cfssljson
mv cfssl cfssljson /usr/local/bin/

# Install kubectl
wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/

# Provision a Certificate Authority that can be used to generate additional TLS certificates
# Generate the CA configuration file, certificate, and private key
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
#
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF
#
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Generate client and server certificates for each Kubernetes component and a client certificate for the Kubernetes admin user
# Generate the admin client certificate and private key
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Toronto",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ontario"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
  
  
for instance in worker01 worker02 worker03; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Toronto",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ontario"
    }
  ]
}
EOF

if [[ $instance == 'worker01' ]]; then
  EXTERNAL_IP=10.0.0.231
  INTERNAL_IP=172.16.0.21
elif [[ $instance == 'worker01' ]]; then
  EXTERNAL_IP=10.0.0.232
  INTERNAL_IP=172.16.0.22
elif [[ $instance == 'worker01' ]]; then
  EXTERNAL_IP=10.0.0.233
  INTERNAL_IP=172.16.0.23
fi

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

# Generate the kube-controller-manager client certificate and private key
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Toronto",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ontario"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

# Generate the kube-proxy client certificate and private key
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Toronto",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ontario"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

# Generate the kube-scheduler client certificate and private key
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Toronto",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ontario"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
  
# Generate the Kubernetes API Server certificate and private key
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Toronto",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ontario"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,10.0.0.231,127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
  
# Generate the service-account certificate and private key
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Toronto",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Ontario"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
  
 # copy keys to respective nodes
 # add CLIs
  
  
