#!/bin/bash

# 完整系统部署脚本 - 使用 Podman 直接部署所有服务
# 不使用 Kubernetes，直接部署到 CentOS

set -e

echo "=========================================="
echo "🚀 开始部署完整系统"
echo "=========================================="

# 配置
MYSQL_ROOT_PASSWORD="rootpass123"
KEYCLOAK_ADMIN_USER="admin"
KEYCLOAK_ADMIN_PASSWORD="admin123"
RISK_SERVICE_PORT=8080
KEYCLOAK_PORT=8081
MYSQL_PORT=3306
OPA_PORT=8282

# 创建网络
echo "📡 创建 Podman 网络..."
podman network create iam-network 2>/dev/null || true

# 1. 启动 MySQL
echo "📦 启动 MySQL..."
podman run -d \
  --name mysql \
  --network iam-network \
  -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
  -e MYSQL_DATABASE=iam \
  -p $MYSQL_PORT:3306 \
  -v mysql-data:/var/lib/mysql \
  mysql:8 \
  --default-authentication-plugin=mysql_native_password

echo "⏳ 等待 MySQL 启动..."
sleep 10

# 2. 启动 Risk Service (直接运行二进制)
echo "🎯 启动 Risk Service..."
nohup /home/bs/services/risk-service/risk-service > /tmp/risk-service.log 2>&1 &
sleep 2
echo "✅ Risk Service 已启动"

# 3. 启动 Keycloak (跳过，因为需要网络)
echo "🔐 Keycloak 需要网络访问，跳过..."

# 4. 启动 OPA (跳过，因为需要网络)
echo "📋 OPA 需要网络访问，跳过..."

# 显示状态
echo ""
echo "=========================================="
echo "✅ 部署完成！"
echo "=========================================="
echo ""
echo "📊 服务状态："
ps aux | grep -E 'risk-service|mysql' | grep -v grep

echo ""
echo "🌐 访问地址："
echo "  Risk Service:  http://localhost:$RISK_SERVICE_PORT/health"
echo "  Risk Score:    http://localhost:$RISK_SERVICE_PORT/score"

echo ""
echo "📝 查看日志："
echo "  Risk Service:  tail -f /tmp/risk-service.log"
echo "  MySQL:         podman logs -f mysql"

echo ""
echo "🧹 停止服务："
echo "  pkill -f risk-service"
echo "  podman stop mysql"

