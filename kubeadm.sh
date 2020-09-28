# CentOS
hostnamectl set-hostname <>
systemctl stop firewalld
systemctl disable firewalld
swapoff -a
sed -i  '/swap/d' /etc/fstab
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo yum install -y docker kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet
systemctl daemon-reload
systemctl restart kubelet

sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -p /etc/sysctl.conf

sudo systemctl enable service.docker
sudo systemctl start service.docker

usermod -aG root ubuntu

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config




