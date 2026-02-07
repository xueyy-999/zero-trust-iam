#!/bin/bash
# CentOS 9 零信任IAM项目完整性检查脚本
# 使用方法：在SSH连接后执行 bash check-centos9-full.sh

echo "=========================================="
echo "零信任IAM系统 - CentOS 9 完整性检查"
echo "=========================================="
echo ""

# 1. 系统信息
echo "=== 1. 系统信息 ==="
echo "操作系统："
cat /etc/os-release | grep PRETTY_NAME
echo ""
echo "内核版本："
uname -r
echo ""
echo "主机名："
hostname
echo ""

# 2. Kubernetes集群状态
echo "=== 2. Kubernetes 集群状态 ==="
echo "节点状态："
kubectl get nodes -o wide
echo ""

# 3. 命名空间检查
echo "=== 3. 命名空间列表 ==="
kubectl get namespaces
echo ""

# 4. Security命名空间详细信息
echo "=== 4. Security 命名空间资源 ==="
if kubectl get namespace security &>/dev/null; then
    echo "✓ security 命名空间存在"
    echo ""
    
    echo "所有资源："
    kubectl -n security get all
    echo ""
    
    echo "Pods详细状态："
    kubectl -n security get pods -o wide
    echo ""
    
    echo "Services详细信息："
    kubectl -n security get svc -o wide
    echo ""
    
    echo "Deployments状态："
    kubectl -n security get deployments
    echo ""
    
    echo "StatefulSets状态："
    kubectl -n security get statefulsets
    echo ""
    
    echo "PersistentVolumeClaims："
    kubectl -n security get pvc
    echo ""
else
    echo "✗ security 命名空间不存在！"
    echo ""
fi

# 5. 最近事件（查看是否有错误）
echo "=== 5. 最近50条事件 ==="
kubectl -n security get events --sort-by=.lastTimestamp 2>/dev/null | tail -n 50
echo ""

# 6. 检查各服务是否运行
echo "=== 6. 核心服务状态检查 ==="

check_service() {
    local service=$1
    local type=$2
    echo -n "检查 $service ... "
    if kubectl -n security get $type $service &>/dev/null; then
        if [ "$type" = "deployment" ]; then
            READY=$(kubectl -n security get deployment $service -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
            DESIRED=$(kubectl -n security get deployment $service -o jsonpath='{.spec.replicas}' 2>/dev/null)
        else
            READY=$(kubectl -n security get statefulset $service -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
            DESIRED=$(kubectl -n security get statefulset $service -o jsonpath='{.spec.replicas}' 2>/dev/null)
        fi
        
        if [ "$READY" = "$DESIRED" ] && [ "$READY" != "" ]; then
            echo "✓ 运行中 ($READY/$DESIRED)"
        else
            echo "✗ 未就绪 ($READY/$DESIRED)"
        fi
    else
        echo "✗ 未部署"
    fi
}

check_service "keycloak" "deployment"
check_service "opa" "deployment"
check_service "risk-service" "deployment"
check_service "web-portal" "deployment"
check_service "mysql" "statefulset"
echo ""

# 7. 容器镜像检查
echo "=== 7. 使用的容器镜像 ==="
kubectl -n security get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' 2>/dev/null
echo ""

# 8. 服务端口检查
echo "=== 8. 对外暴露的端口 (NodePort) ==="
kubectl -n security get svc -o wide | grep NodePort
echo ""

# 9. 持久化存储
echo "=== 9. 持久化存储 ==="
echo "PersistentVolumes："
kubectl get pv
echo ""

# 10. 检查是否有问题的Pod
echo "=== 10. 问题Pod检查 ==="
PROBLEM_PODS=$(kubectl -n security get pods --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null)
if [ -n "$PROBLEM_PODS" ]; then
    echo "发现问题Pod："
    echo "$PROBLEM_PODS"
else
    echo "✓ 所有Pod运行正常"
fi
echo ""

# 11. 资源使用情况
echo "=== 11. 资源使用情况 ==="
kubectl top nodes 2>/dev/null || echo "metrics-server未安装，跳过"
echo ""

echo "=========================================="
echo "检查完成！"
echo "=========================================="
