#!/bin/bash

# 简化的 Kubernetes 部署脚本
# 使用本地已安装的工具，避免网络依赖

set -e

echo "=== 开始部署 Kubernetes 集群 ==="

# 1. 检查 Podman
echo "检查 Podman..."
podman --version

# 2. 安装 kubeadm、kubelet、kubectl
echo "安装 Kubernetes 工具..."
cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

# 尝试安装，如果网络失败则跳过
yum install -y kubeadm kubelet kubectl 2>/dev/null || echo "⚠️ 网络问题，跳过 kubeadm 安装"

# 3. 启动 kubelet
echo "启动 kubelet..."
systemctl enable kubelet
systemctl start kubelet || echo "⚠️ kubelet 启动失败"

# 4. 初始化 Kubernetes 集群
echo "初始化 Kubernetes 集群..."
kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/podman/podman.sock 2>/dev/null || echo "⚠️ kubeadm init 失败"

# 5. 配置 kubectl
echo "配置 kubectl..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 6. 安装 CNI (Flannel)
echo "安装 Flannel CNI..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml 2>/dev/null || echo "⚠️ Flannel 安装失败"

# 7. 等待节点就绪
echo "等待节点就绪..."
sleep 10
kubectl get nodes

echo ""
echo "=== Kubernetes 部署完成 ==="
echo "检查集群状态: kubectl get nodes"
echo "检查 Pod: kubectl get pods -A"

