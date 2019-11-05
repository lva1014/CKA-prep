#!/bin/bash

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
echo worker02 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo worker03 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo 172.16.0.22 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
echo 172.16.0.23 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDawPicuxImfnUm3P+1zVAjXtW00yn0b5M6EE/JS4pzr16Rmimg/CDXDc59UL/bKEc6446PY04DmUrzdcw/8VWw= > /root/.ssh/known_hosts
touch /root/.ssh/config
echo "Host *" >> /root/.ssh/config
echo "  StrictHostKeyChecking no" >> /root/.ssh/config

# settin up workers:
for instance in worker01 worker02 worker03; do
  sshpass -f "/root/password" ssh root@$instance 'swapoff -a'
  sshpass -f "/root/password" ssh root@$instance "sed -i '/swap/d' /etc/fstab"
  sshpass -f "/root/password" ssh root@$instance 'hostnamectl set-hostname $instance'
  sshpass -f "/root/password" ssh root@$instance 'yum install -y socat conntrack ipset'
fi

# downloading binaries
wget \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz \
  https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet

mkdir -p /opt/cni/bin
mkdir -p /var/lib/kubelet
mkdir -p /var/lib/kube-proxy
mkdir -p /var/lib/kubernetes
mkdir -p /var/run/kubernetes

# copy binaries to all other workers
for instance in worker02 worker03; do
  sshpass -f "/root/password" scp -r crictl-v1.15.0-linux-amd64.tar.gz root@$instance:~/
  sshpass -f "/root/password" scp -r runc.amd64 root@$instance:~/
  sshpass -f "/root/password" scp -r cni-plugins-linux-amd64-v0.8.2.tgz root@$instance:~/
  sshpass -f "/root/password" scp -r containerd-1.2.9.linux-amd64.tar.gz root@$instance:~/
  sshpass -f "/root/password" scp -r kubectl root@$instance:~/
  sshpass -f "/root/password" scp -r kube-proxy root@$instance:~/
  sshpass -f "/root/password" scp -r kubelet root@$instance:~/
  
  sshpass -f "/root/password" ssh root@$instance 'mkdir -p /opt/cni/bin'
  sshpass -f "/root/password" ssh root@$instance 'mkdir -p /var/lib/kubelet'
  sshpass -f "/root/password" ssh root@$instance 'mkdir -p /var/lib/kube-proxy'
  sshpass -f "/root/password" ssh root@$instance 'mkdir -p /var/lib/kubernetes'
  sshpass -f "/root/password" ssh root@$instance 'mkdir -p /var/run/kubernetes'   
fi

# install the binaries on worker01
mkdir containerd
tar -xvf crictl-v1.15.0-linux-amd64.tar.gz
tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C containerd
tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/
mv runc.amd64 runc
chmod +x crictl kubectl kube-proxy kubelet runc 
mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
mv containerd/bin/* /bin/

# install the binaries on worker02, worker03
for instance in worker02 worker03; do
  sshpass -f "/root/password" ssh root@$instance 'mkdir containerd'
  sshpass -f "/root/password" ssh root@$instance 'tar -xvf crictl-v1.15.0-linux-amd64.tar.gz'
  sshpass -f "/root/password" ssh root@$instance 'tar -xvf containerd-1.2.9.linux-amd64.tar.gz -C containerd'
  sshpass -f "/root/password" ssh root@$instance 'tar -xvf cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/'
  sshpass -f "/root/password" ssh root@$instance 'mv runc.amd64 runc'
  sshpass -f "/root/password" ssh root@$instance 'chmod +x crictl kubectl kube-proxy kubelet runc'
  sshpass -f "/root/password" ssh root@$instance 'mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/'
  sshpass -f "/root/password" ssh root@$instance 'mv containerd/bin/* /bin/'
fi

# Create the bridge network configuration file
$POD_CIDR="172.16.0.0/24"
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "$POD_CIDR"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

for instance in worker02 worker03; do
  sshpass -f "/root/password" ssh root@$instance 'touch /etc/cni/net.d/10-bridge.conf'
  sshpass -f "/root/password" scp -r /etc/cni/net.d/10-bridge.conf root@$instance:/etc/cni/net.d/10-bridge.conf
fi

# Create the loopback network configuration file
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF




