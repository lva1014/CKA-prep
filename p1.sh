#!/bin/bash
# k8s-install on CentOS
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

# Turn off Swap
swapoff -a

# removed swap from /etc/fstab and reloaded
sed -i  '/swap/d' /etc/fstab

# Install Docker as per:
# https://docs.docker.com/install/linux/docker-ce/centos/
sudo yum remove -y docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-engine
sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
#sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo yum install -y containerd.io
sudo yum update && yum install -y docker-ce-18.06.2.ce
mkdir /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker
systemctl enable docker.service
sudo docker run hello-world

# Installing Kubernetes
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

# Restart probably required

# Install etcd on master nodes
if [[ $TEMP_LOCAL_HOSTNAME == 'master01' ]] || [[ $TEMP_LOCAL_HOSTNAME == 'master02' ]]; then
  cd /root
  mkdir archives
  cd archives
  export etcdVersion=v3.4.3
  wget https://github.com/coreos/etcd/releases/download/$etcdVersion/etcd-$etcdVersion-linux-amd64.tar.gz
  tar -xvf etcd-$etcdVersion-linux-amd64.tar.gz -C /usr/local/bin/ --strip-components=1
  touch /etc/etcd.env
  echo PEER_NAME=$TEMP_LOCAL_HOSTNAME > /etc/etcd.env
  echo PRIVATE_IP=$TEMP_LOCAL_IP >> /etc/etcd.env
  touch /etc/systemd/system/etcd.service
  echo [Unit] > /etc/systemd/system/etcd.service
  echo Description=etcd >> /etc/systemd/system/etcd.service
  echo Documentation=https://github.com/coreos/etcd >> /etc/systemd/system/etcd.service
  echo Conflicts=etcd.service >> /etc/systemd/system/etcd.service
  echo Conflicts=etcd2.service >> /etc/systemd/system/etcd.service
  echo >> /etc/systemd/system/etcd.service
  echo [Service] > /etc/systemd/system/etcd.service
  echo EnvironmentFile=/etc/etcd.env >> /etc/systemd/system/etcd.service
  echo Type=notify >> /etc/systemd/system/etcd.service
  echo Restart=always >> /etc/systemd/system/etcd.service
  echo RestartSec=5s >> /etc/systemd/system/etcd.service
  echo LimitNOFILE=40000 >> /etc/systemd/system/etcd.service
  echo TimeoutStartSec=0 >> /etc/systemd/system/etcd.service
  echo >> /etc/systemd/system/etcd.service
  echo ExecStart=/usr/local/bin/etcd --name $TEMP_LOCAL_HOSTNAME --initial-advertise-peer-urls http://$TEMP_LOCAL_IP:2380  \\ >> /etc/systemd/system/etcd.service
  echo   --listen-peer-urls http://$TEMP_LOCAL_IP:2380  \\ >> /etc/systemd/system/etcd.service
  echo   --listen-client-urls http://$TEMP_LOCAL_IP:2379,http://127.0.0.1:2379  \\ >> /etc/systemd/system/etcd.service
  echo   --advertise-client-urls http://$TEMP_LOCAL_IP:2379  \\ >> /etc/systemd/system/etcd.service
  echo   --initial-cluster-token 9489bf67bdfe1b3ae077d6fd9e7efefa  \\ >> /etc/systemd/system/etcd.service
  echo   --initial-cluster master01=http://172.16.0.11:2380,master02=http://172.16.0.12:2380  \\ >> /etc/systemd/system/etcd.service
  echo   --initial-cluster-state new  >> /etc/systemd/system/etcd.service
  echo >> /etc/systemd/system/etcd.service
  echo [Install] >> /etc/systemd/system/etcd.service
  echo WantedBy=multi-user.target >> /etc/systemd/system/etcd.service
fi

# Enable etcd on startup
systemctl enable etcd

# Preparion for Kubeadm
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

# System reboot
reboot
# end of part 1
