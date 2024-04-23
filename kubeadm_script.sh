#!/bin/bash

sudo su

echo "Installing kubeadm"
hostnamectl set-hostname controlNode

echo "disable swapping temporarily"
sudo swapoff -a
echo "permanently disable swap"
sudo sed -i '/\s\+swap\s\+/s/^\(.*\)$/#\1/g' /etc/fstab

echo "Enabling IPv4 packet forwarding"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

echo "Installing Containerd"
wget https://github.com/containerd/containerd/releases/download/v1.7.15/containerd-1.7.15-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-1.7.15-linux-amd64.tar.gz
rm -f containerd-1.7.15-linux-amd64.tar.gz

echo "Getting containerd.service file"
sudo wget -P /usr/local/lib/systemd/system/ https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

systemctl daemon-reload
systemctl enable --now containerd
  
echo "Installing runc"
wget https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

echo "Installing CNI"
wget https://github.com/containernetworking/plugins/releases/download/v1.4.1/cni-plugins-linux-amd64-v1.4.1.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.4.1.tgz
rm -f cni-plugins-linux-amd64-v1.4.1.tgz

echo "Installing crictl"
VERSION="v1.26.0" # check latest version in /releases page
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

echo "setting crictl endput"
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

echo "Intergrating the containerd with systemd"
mkdir /etc/containerd

echo "[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true" > /etc/containerd/config.toml

sudo systemctl daemon-reload
sudo systemctl enable containerd
sudo systemctl start containerd

echo "Installing kubeadm and kubelet"
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes


sudo systemctl enable --now kubelet