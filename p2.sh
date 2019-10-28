#!/bin/bash
TEMP_LOCAL_HOSTNAME=$(hostname)
TEMP_LOCAL_IP=$(ip add | grep 172.16 | awk '{print($2)}' | rev | cut -c4- | rev)

# Check nodes and cluster
if [[ $TEMP_LOCAL_HOSTNAME == 'master01' ]] || [[ $TEMP_LOCAL_HOSTNAME == 'master02' ]]; then
  etcdctl member list
  echo
  etcdctl endpoint health
fi

# Enable networking module
modprobe ip_vs
echo ip_vs > /etc/modules-load.d/ip_vs.conf

# Creating initial config for Kubadm on master01
if [[ $TEMP_LOCAL_HOSTNAME == 'master01' ]]; then
  cd /root
  touch kubeadm-init.yaml
  echo apiVersion: kubeadm.k8s.io/v1beta1 >> kubeadm-init.yaml
  echo kind: InitConfiguration >> kubeadm-init.yaml
  echo localAPIEndpoint: >> kubeadm-init.yaml
  echo '  advertiseAddress: 172.16.0.11' >> kubeadm-init.yaml
  echo  >> kubeadm-init.yaml
  echo apiVersion: kubeadm.k8s.io/v1beta1 >> kubeadm-init.yaml
  echo kind: ClusterConfiguration >> kubeadm-init.yaml
  echo kubernetesVersion: stable >> kubeadm-init.yaml
  echo apiServer: >> kubeadm-init.yaml
  echo '  certSANs:' >> kubeadm-init.yaml
  echo '  - 172.16.0.11' >> kubeadm-init.yaml
  echo '  - 172.16.0.12' >> kubeadm-init.yaml
  echo '  - 127.0.0.1' >> kubeadm-init.yaml
  echo controlPlaneEndpoint: $TEMP_LOCAL_IP >> kubeadm-init.yaml
  echo etcd: >> kubeadm-init.yaml
  echo '  external:' >> kubeadm-init.yaml
  echo '    endpoints:' >> kubeadm-init.yaml
  echo '    - http://172.16.0.11:2379' >> kubeadm-init.yaml
  echo '    - http://172.16.0.12:2379' >> kubeadm-init.yaml
  echo networking: >> kubeadm-init.yaml
  echo '  podSubnet: 192.168.0.0/16' >> kubeadm-init.yaml
  echo '  serviceSubnet: "10.96.0.0/12"' >> kubeadm-init.yaml
  echo '  dnsDomain: "cluster.local"' >> kubeadm-init.yaml
fi

# Starting Kubeadm
if [[ $TEMP_LOCAL_HOSTNAME == 'master01' ]]; then
  systemctl start docker.service
  kubeadm config images pull
  kubeadm init  --config=/root/kubeadm-init.yaml --ignore-preflight-errors=all
fi

# Installing networking: Calico on master01
if [[ $TEMP_LOCAL_HOSTNAME == 'master01' ]]; then
  export KUBECONFIG=/etc/kubernetes/admin.conf
#  kubectl apply -f /root/CKA-prep/calico.yaml
  kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
#  #kubectl apply -f https://docs.projectcalico.org/v3.10/manifests/calico.yaml
#fi

# watch -n1 kubectl get pods -A
#if [[ $TEMP_LOCAL_HOSTNAME == 'master01' ]]; then
#  export master2=172.16.0.12
#  scp -r /etc/kubernetes/pki $master2:/etc/kubernetes/
#  # enter password
#fi
#end of part 2
