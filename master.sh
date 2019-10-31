#!/bin/bash

# kubernetes 1.15.3
# containerd 1.2.9
# coredns v1.6.3
# cni v0.7.1
# etcd v3.4.0

TEMP_LOCAL_IP=$(ip add | grep 172.16 | awk '{print($2)}' | rev | cut -c4- | rev)
KUBERNETES_PUBLIC_ADDRESS="10.0.0.230" 

# change hostname
echo -----\> Chaning hostname \<------
if [[ $TEMP_LOCAL_IP == '172.16.0.11' ]]; then
  hostnamectl set-hostname master01
  TEMP_LOCAL_HOSTNAME='master01'
elif [[ $TEMP_LOCAL_IP == '172.16.0.12' ]]; then
  hostnamectl set-hostname master03
  TEMP_LOCAL_HOSTNAME='master02'
elif [[ $TEMP_LOCAL_IP == '172.16.0.13' ]]; then
  hostnamectl set-hostname master03
  TEMP_LOCAL_HOSTNAME='master03'  
fi

# Add DNS records
echo -----\> Modifying localhost entries \<------
echo 172.16.0.11  master01 >> /etc/hosts
echo 172.16.0.12  master02 >> /etc/hosts
echo 172.16.0.13  master03 >> /etc/hosts
echo 172.16.0.21  worker01 >> /etc/hosts
echo 172.16.0.22  worker02 >> /etc/hosts
echo 172.16.0.23  worker03 >> /etc/hosts

# Adding keys to known hosts
echo -----\> SSH Keys \<------
mkdir /root/.ssh
touch /root/.ssh/known_hosts
echo master02 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo master03 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo worker01 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo worker02 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo worker03 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo 172.16.0.12 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo 172.16.0.13 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo 172.16.0.21 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo 172.16.0.22 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo 172.16.0.23 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
touch /root/.ssh/config
echo "Host *" >> /root/.ssh/config
echo "  StrictHostKeyChecking no" >> /root/.ssh/config

# update packages
echo -----\> Updating Packages \<------
yum update -y
yum install -y wget net-tools tcpdump git sshpass

# disable FW
echo -----\> Disabling FW \<------
systemctl stop firewalld
systemctl disable firewalld

# Turn off swap and update fstab
echo -----\> Swap OFF \<------
swapoff -a
sed -i  '/swap/d' /etc/fstab

# Get cfssl util
echo -----\> Downloading CFSSL \<------
wget -q \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssl \
  https://storage.googleapis.com/kubernetes-the-hard-way/cfssl/linux/cfssljson
chmod +x cfssl cfssljson
mv cfssl cfssljson /usr/local/bin/

# Install kubectl
echo -----\> Installing kubectl \<------
wget https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/

# Provision a Certificate Authority that can be used to generate additional TLS certificates
# Generate the CA configuration file, certificate, and private key
echo -----\> Generating Certificates \<------
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
cat > $instance-csr.json <<EOF
{
  "CN": "system:node:$instance",
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

# Adding variables
echo -----\> Adding vairables for EXT_IP,INT_IP \<------
if [[ $instance == 'worker01' ]]; then
  EXTERNAL_IP=10.0.0.233
  INTERNAL_IP=172.16.0.21
elif [[ $instance == 'worker01' ]]; then
  EXTERNAL_IP=10.0.0.234
  INTERNAL_IP=172.16.0.22
elif [[ $instance == 'worker01' ]]; then
  EXTERNAL_IP=10.0.0.235
  INTERNAL_IP=172.16.0.23
fi

# Generating Certificate
echo -----\> Generating Certificates \<------
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=$instance,$EXTERNAL_IP,$INTERNAL_IP \
  -profile=kubernetes \
  $instance-csr.json | cfssljson -bare $instance
done

# Generate the kube-controller-manager client certificate and private key
echo -----\> Generaring kube-controller-manager certificates \<------
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
echo -----\> Generating kube-proxy certificates \<------
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
echo -----\> Generating kube-scheduler ceriticates \<------
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
echo -----\> Generating kube-api certificates \<------
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
  -hostname=10.32.0.1,172.16.0.11,172.16.0.12,172.16.0.13,10.0.0.230,127.0.0.1,$KUBERNETES_HOSTNAMES \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
  
# Generate the service-account certificate and private key
echo -----\> Generating service account \<------
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
echo -----\> Copying keys to master nodes \<------
for instance in worker01 worker02 worker03; do
  sshpass -f "/root/password" scp -r ca.pem root@$instance:~/
  sshpass -f "/root/password" scp -r $instance-key.pem root@$instance:~/
  sshpass -f "/root/password" scp -r $instance.pem root@$instance:~/
done

echo -----\> Copying keys to worker nodes \<------
for instance in master02 master03; do
  sshpass -f "/root/password" scp -r ca.pem root@$instance:~/
  sshpass -f "/root/password" scp -r ca-key.pem root@$instance:~/
  sshpass -f "/root/password" scp -r kubernetes-key.pem root@$instance:~/
  sshpass -f "/root/password" scp -r service-account-key.pem root@$instance:~/
  sshpass -f "/root/password" scp -r service-account.pem root@$instance:~/
done
  
# Generate a kubeconfig file for each worker node
echo -----\> Generating kubeconfig for each worker node \<------
for instance in worker01 worker02 worker03; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://$KUBERNETES_PUBLIC_ADDRESS:6443 \
    --kubeconfig=$instance.kubeconfig

  kubectl config set-credentials system:node:$instance \
    --client-certificate=$instance.pem \
    --client-key=$instance-key.pem \
    --embed-certs=true \
    --kubeconfig=$instance.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:$instance \
    --kubeconfig=$instance.kubeconfig

  kubectl config use-context default --kubeconfig=$instance.kubeconfig
done

# Generate a kubeconfig file for the kube-proxy service
echo -----\> Generating kubeconfig for kube-proxy \<------
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://$KUBERNETES_PUBLIC_ADDRESS:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# Generate a kubeconfig file for the kube-controller-manager service
echo -----\> Generating kubeconfig for kube-controller \<------
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# Generate a kubeconfig file for the kube-scheduler service
echo -----\> Generating kubeconfig for kube-scheduler \<------
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.pem \
  --client-key=kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# Generate a kubeconfig file for the admin user
echo -----\> Generating kubeconfig for admin user \<------
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.pem \
  --client-key=admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

# Copy the appropriate kubelet and kube-proxy kubeconfig files to each worker instance
echo -----\> Copying configs to worker nodes \<------
for instance in worker01 worker02 worker03; do
  sshpass -f "/root/password" scp -r $instance.kubeconfig root@$instance:~/
  sshpass -f "/root/password" scp -r kube-proxy.kubeconfig root@$instance:~/
done

# Copy the appropriate kube-controller-manager and kube-scheduler kubeconfig files to each controller instance
echo -----\> Copying configs to master nodes \<------
for instance in master02 master03; do
  sshpass -f "/root/password" scp -r admin.kubeconfig root@$instance:~/
  sshpass -f "/root/password" scp -r kube-controller-manager.kubeconfig root@$instance:~/
  sshpass -f "/root/password" scp -r kube-scheduler.kubeconfig root@$instance:~/
done

# Generate encryption key
echo -----\> Generating enc key \<------
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $ENCRYPTION_KEY
      - identity: {}
EOF

# Copy the encryption-config.yaml encryption config file to each controller instance
echo -----\> Copying enc config to each controller node \<------
for instance in master02 master03; do
  sshpass -f "/root/password" scp -r encryption-config.yaml root@$instance:~/
done

# Download the official etcd release binaries from the etcd GitHub project
wget -q \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.0/etcd-v3.4.0-linux-amd64.tar.gz"

# Extract and install the etcd server and the etcdctl command line utility
echo -----\> Installing ETCD server \<------
tar -xvf etcd-v3.4.0-linux-amd64.tar.gz
mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
mkdir -p /etc/etcd /var/lib/etcd
cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
sshpass -f "/root/password" scp -r ca.pem kubernetes-key.pem kubernetes.pem root@master02:~/
sshpass -f "/root/password" scp -r ca.pem kubernetes-key.pem kubernetes.pem root@master03:~/

# setup etcd on master02 and master03
sfor instance master02 master03; do
if [[ $instance == 'master02' ]]; then
  INTERNAL_IP=1762.16.0.12
  ETCD_NAME=$instance
elif [[ $instance == 'master02' ]]; then
  INTERNAL_IP=1762.16.0.13
  ETCD_NAME=$instance
fi

sshpass -f "/root/password" scp -r etcd-v3.4.0-linux-amd64.tar.gz root@$instance:~/
sshpass -f "/root/password" ssh root@$instance 'tar -xvf /root/etcd-v3.4.0-linux-amd64.tar.gz'
sshpass -f "/root/password" ssh root@$instance 'mv /root/etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/'
sshpass -f "/root/password" ssh root@$instance 'mkdir -p /etc/etcd /var/lib/etcd'
sshpass -f "/root/password" ssh root@$instance 'cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/'

cat <<EOF | sudo tee /root/$instance.temp.etcd
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name $ETCD_NAME \\
#  --cert-file=/etc/etcd/kubernetes.pem \\
#  --key-file=/etc/etcd/kubernetes-key.pem \\
#  --peer-cert-file=/etc/etcd/kubernetes.pem \\
#  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
#  --trusted-ca-file=/etc/etcd/ca.pem \\
#  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
#  --peer-client-cert-auth \\
#  --client-cert-auth \\
#  --initial-advertise-peer-urls https://$INTERNAL_IP:2380 \\
  --initial-advertise-peer-urls http://$INTERNAL_IP:2380 \\
#  --listen-peer-urls https://$INTERNAL_IP:2380 \\
  --listen-peer-urls http://$INTERNAL_IP:2380 \\
#  --listen-client-urls https://$INTERNAL_IP:2379,https://127.0.0.1:2379 \\
  --listen-client-urls http://$INTERNAL_IP:2379,https://127.0.0.1:2379 \\
#  --advertise-client-urls https://$INTERNAL_IP:2379 \\
  --advertise-client-urls http://$INTERNAL_IP:2379 \\
--initial-cluster-token etcd-cluster-0 \\
#  --initial-cluster master01=https://172.16.0.11:2380,master02=https://172.16.0.12:2380,master03=https://172.16.0.13:2380 \\
  --initial-cluster master01=http://172.16.0.11:2380,master02=http://172.16.0.12:2380,master03=http://172.16.0.13:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sshpass -f "/root/password" scp -r /root/$instance.temp.etcd root@$instance:/etc/systemd/system/etcd.service
sshpass -f "/root/password" ssh root@$instance 'systemctl daemon-reload'
sshpass -f "/root/password" ssh root@$instance 'systemctl enable etcd'
rm -f $instance.temp.etcd

done

# Create the etcd.service systemd unit file
echo -----\> Creating ETCD config \<------
ETCD_NAME="master01"
INTERNAL_IP="172.16.0.11"
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name $ETCD_NAME \\
#  --cert-file=/etc/etcd/kubernetes.pem \\
#  --key-file=/etc/etcd/kubernetes-key.pem \\
#  --peer-cert-file=/etc/etcd/kubernetes.pem \\
#  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
#  --trusted-ca-file=/etc/etcd/ca.pem \\
#  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
#  --peer-client-cert-auth \\
#  --client-cert-auth \\
#  --initial-advertise-peer-urls https://$INTERNAL_IP:2380 \\
  --initial-advertise-peer-urls http://$INTERNAL_IP:2380 \\
#  --listen-peer-urls https://$INTERNAL_IP:2380 \\
  --listen-peer-urls http://$INTERNAL_IP:2380 \\
#  --listen-client-urls https://$INTERNAL_IP:2379,https://127.0.0.1:2379 \\
  --listen-client-urls http://$INTERNAL_IP:2379,https://127.0.0.1:2379 \\
#  --advertise-client-urls https://$INTERNAL_IP:2379 \\
  --advertise-client-urls http://$INTERNAL_IP:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
#  --initial-cluster master01=https://172.16.0.11:2380,master02=https://172.16.0.12:2380,master03=https://172.16.0.13:2380 \\
  --initial-cluster master01=http://172.16.0.11:2380,master02=http://172.16.0.12:2380,master03=http://172.16.0.13:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start the etcd Server
echo -----\> Starting ETCD server \<------
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd &
sshpass -f "/root/password" ssh root@master02 'systemctl start etcd &'
sshpass -f "/root/password" ssh root@master03 'systemctl start etcd &'

# Verification
#echo -----\> Verifying ETCD server \<------
#sudo ETCDCTL_API=3 etcdctl member list \
#  --endpoints=https://127.0.0.1:2379 \
#  --cacert=/etc/etcd/ca.pem \
#  --cert=/etc/etcd/kubernetes.pem \
#  --key=/etc/etcd/kubernetes-key.pem

# Provision the Kubernetes Control Plane
# Create the Kubernetes configuration directory
echo -----\> Creating kubernetes configs \<------
mkdir -p /etc/kubernetes/config
wget -q \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl"

# Install the Kubernetes binaries
echo -----\> Installing kubernetes binaries \<------
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

# Configure the Kubernetes API Server
echo -----\> Configuring API Server \<------
mkdir -p /var/lib/kubernetes/

mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
  service-account-key.pem service-account.pem \
  encryption-config.yaml /var/lib/kubernetes/
 
# Setting TEMP_HOSTNAME
echo -----\> Setting TEMP_HOSTNAME \<------
TEMP_HOSTNAME=$(hostname -s)
if [[ $TEMP_HOSTNAME == "master01" ]]; then 
  INTERNAL_IP="172.16.0.11"
elif [[ $TEMP_HOSTNAME == "master02" ]]; then 
  INTERNAL_IP="172.16.0.12"
elif [[ $TEMP_HOSTNAME == "master03" ]]; then 
  INTERNAL_IP="172.16.0.13"
fi

# Create the kube-apiserver.service systemd unit file:
echo -----\> Creating kube-apiserver config \<------
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=$INTERNAL_IP \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://172.16.0.11:2379,https://172.16.0.12:2379,https://172.16.0.13:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Move the kube-controller-manager kubeconfig into place
mv kube-controller-manager.kubeconfig /var/lib/kubernetes/

# Create the kube-controller-manager.service systemd unit file
echo -----\> Creating controller config file \<------
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Move the kube-scheduler kubeconfig into place
echo -----\> Moving kontrollers config into place \<------
mv kube-scheduler.kubeconfig /var/lib/kubernetes/

# Create the kube-scheduler.yaml configuration file
echo -----\> Creating scheduler config into place \<------
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

# Create the kube-scheduler.service systemd unit file
echo -----\> Creating kube-scheduler config \<------
cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start the Controller Services
echo -----\> Starting controller \<------
systemctl daemon-reload
systemctl enable kube-apiserver kube-controller-manager kube-scheduler
systemctl start kube-apiserver kube-controller-manager kube-scheduler

echo Installation Completed..
