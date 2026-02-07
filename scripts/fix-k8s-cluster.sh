#!/bin/bash
# Kubernetes集群修复脚本
# 用途：重新初始化Kubernetes集群

set -e

echo "=========================================="
echo "Kubernetes 集群重新初始化"
echo "=========================================="
echo ""

# 获取当前IP
CURRENT_IP=$(hostname -I | awk '{print $1}')
echo "当前虚拟机IP: $CURRENT_IP"
echo ""

# 1. 清理旧的集群配置
echo "=== 1. 清理旧配置 ==="
kubeadm reset -f
rm -rf /etc/kubernetes/*
rm -rf /var/lib/etcd/*
rm -rf ~/.kube
echo "✓ 清理完成"
echo ""

# 2. 重新初始化集群
echo "=== 2. 初始化Kubernetes集群 ==="
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$CURRENT_IP \
  --control-plane-endpoint=$CURRENT_IP:6443

echo "✓ 集群初始化完成"
echo ""

# 3. 配置kubectl
echo "=== 3. 配置kubectl ==="
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf
echo "✓ kubectl配置完成"
echo ""

# 4. 安装CNI网络插件（Flannel）
echo "=== 4. 安装Flannel网络插件 ==="
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
echo "✓ Flannel安装完成"
echo ""

# 5. 移除master节点的污点（允许在master上调度Pod）
echo "=== 5. 配置单节点集群 ==="
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true
echo "✓ 单节点配置完成"
echo ""

# 6. 等待节点就绪
echo "=== 6. 等待节点就绪 ==="
echo "等待中..."
for i in {1..60}; do
    if kubectl get nodes | grep -q " Ready"; then
        echo "✓ 节点已就绪"
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

# 7. 验证集群状态
echo "=== 7. 验证集群状态 ==="
kubectl get nodes -o wide
echo ""
kubectl get pods -A
echo ""

echo "=========================================="
echo "Kubernetes 集群初始化完成！"
echo "=========================================="
echo ""
echo "下一步："
echo "1. 等待所有系统Pod变为Running状态（约2-3分钟）"
echo "2. 运行 Ansible playbook 部署应用："
echo "   cd /path/to/project"
echo "   ansible-playbook ansible/playbooks/10-apps.yml"
echo ""
