#!/bin/bash
# 简化版K8s初始化脚本 - 毕设演示用
# 目标：能跑起来就行，不追求完美

set -e

echo "=== 简化版K8s集群初始化（毕设演示用）==="
echo ""

# 1. 清理旧配置（如果有）
echo "[1/5] 清理旧配置..."
kubeadm reset -f 2>/dev/null || true
rm -rf /etc/kubernetes/* 2>/dev/null || true
rm -rf ~/.kube 2>/dev/null || true

# 2. 初始化集群（最简配置）
echo "[2/5] 初始化K8s集群..."
CURRENT_IP=$(hostname -I | awk '{print $1}')
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$CURRENT_IP

# 3. 配置kubectl
echo "[3/5] 配置kubectl..."
mkdir -p ~/.kube
cp /etc/kubernetes/admin.conf ~/.kube/config

# 4. 安装网络插件（Flannel - 最简单）
echo "[4/5] 安装网络插件..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 5. 允许在master节点调度（单节点必须）
echo "[5/5] 配置单节点..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true

echo ""
echo "✓ K8s集群初始化完成！"
echo ""
echo "等待节点就绪（约1-2分钟）..."
sleep 60

kubectl get nodes
echo ""
echo "提示：如果节点还是NotReady，再等1分钟后运行: kubectl get nodes"
