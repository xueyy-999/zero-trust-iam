#!/bin/bash

# 简化部署脚本 - 在 CentOS 上直接运行 Risk Service

set -e

echo "=== 简化部署开始 ==="

# 1. 启动 Risk Service
echo "启动 Risk Service..."
cd /home/bs/services/risk-service
chmod +x risk-service
nohup ./risk-service > /tmp/risk-service.log 2>&1 &
RISK_PID=$!
echo "Risk Service PID: $RISK_PID"

# 2. 等待 Risk Service 启动
echo "等待 Risk Service 启动..."
sleep 2

# 3. 测试 Risk Service
echo "测试 Risk Service..."
curl -s http://localhost:8080/health || echo "Health check failed"

# 4. 显示日志
echo ""
echo "=== Risk Service 日志 ==="
tail -20 /tmp/risk-service.log

echo ""
echo "=== 部署完成 ==="
echo "Risk Service 运行在 http://localhost:8080"
echo "日志文件: /tmp/risk-service.log"
echo "PID: $RISK_PID"

