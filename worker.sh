#!/bin/bash

HOSTNAME=$(hostnamectl -s)
POD_CIDR="172.16.0.0/24"
yum install -y wget

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
done

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
done

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
done

# Create the bridge network configuration file
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
  sshpass -f "/root/password" scp -r /etc/cni/net.d/10-bridge.conf root@$instance:/etc/cni/net.d/10-bridge.conf
done

# Create the loopback network configuration file
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF
for instance in worker02 worker03; do
  sshpass -f "/root/password" scp -r /etc/cni/net.d/99-loopback.conf root@$instance:/etc/cni/net.d/99-loopback.conf
done

# Create the containerd configuration file
mkdir -p /etc/containerd/

cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

for instance in worker02 worker03; do
  sshpass -f "/root/password" ssh root@$instance 'mkdir -p /etc/containerd/'
  sshpass -f "/root/password" scp -r /etc/containerd/config.toml root@$instance:/etc/containerd/config.toml
done

# Create the containerd.service systemd unit file
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

for instance in worker02 worker03; do
  sshpass -f "/root/password" scp -r /etc/systemd/system/containerd.service root@$instance:/etc/systemd/system/containerd.service
done

mv $HOSTNAME-key.pem $HOSTNAME.pem /var/lib/kubelet/
mv $HOSTNAME.kubeconfig /var/lib/kubelet/kubeconfig
mv ca.pem /var/lib/kubernetes/

for instance in worker02 worker03; do
  HOSTNAME=$instance
  sshpass -f "/root/password" ssh root@$instance 'mv $HOSTNAME-key.pem $HOSTNAME.pem /var/lib/kubelet/' 
  sshpass -f "/root/password" ssh root@$instance 'mv $HOSTNAME.kubeconfig /var/lib/kubelet/kubeconfig' 
  sshpass -f "/root/password" ssh root@$instance 'mv ca.pem /var/lib/kubernetes/'
done

# Create the kubelet-config.yaml configuration file
for instance in worker01 worker02 worker03; do
  HOSTNAME=$instance
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config-$instance.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "$POD_CIDR"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/$HOSTNAME.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/$HOSTNAME-key.pem"
EOF
done

mv /var/lib/kubelet/kubelet-config-$instance.yaml /var/lib/kubelet/kubelet-config-.yaml

for instance in worker02 worker03; do
  sshpass -f "/root/password" scp -r /var/lib/kubelet/kubelet-config-$instance.yaml root@$instance:/var/lib/kubelet/kubelet-config.yaml
  rm -f /var/lib/kubelet/kubelet-config-$instance.yaml
done

# Create the kubelet.service systemd unit file
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

for instance in worker02 worker03; do
  sshpass -f "/root/password" scp -r /etc/systemd/system/kubelet.service root@$instance:/etc/systemd/system/kubelet.service
done

# Configure the Kubernetes Proxy
mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

for instance in worker02 worker03; do
  sshpass -f "/root/password" scp -r /var/lib/kube-proxy/kubeconfig root@$instance:/var/lib/kube-proxy/kubeconfig
done

# Create the kube-proxy-config.yaml configuration file
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

for instance in worker02 worker03; do
  sshpass -f "/root/password" scp -r /var/lib/kube-proxy/kube-proxy-config.yaml root@$instance:/var/lib/kube-proxy/kube-proxy-config.yaml
done

# Create the kube-proxy.service systemd unit file
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

for instance in worker02 worker03; do
  sshpass -f "/root/password" scp -r /etc/systemd/system/kube-proxy.service root@$instance:/etc/systemd/system/kube-proxy.service
done

# Start the Worker Services
systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy

for instance in worker02 worker03; do
  sshpass -f "/root/password" ssh root@$instance 'systemctl daemon-reload' 
  sshpass -f "/root/password" ssh root@$instance 'systemctl enable containerd kubelet kube-proxy' 
  sshpass -f "/root/password" ssh root@$instance 'systemctl start containerd kubelet kube-proxy'
done



