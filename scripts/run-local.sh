#!/usr/bin/env bash
# 本地一键启动脚本 - Linux/macOS
# 用途：快速启动 risk-service + web-portal 进行本地演示

set -euo pipefail

echo "=== 零信任 IAM 本地启动脚本 ==="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 检查构建产物
RISK_BIN="services/risk-service/risk-service"
WEB_BIN="services/web-portal/web-portal"

if [ ! -f "$RISK_BIN" ]; then
    echo "[构建] risk-service..."
    (cd services/risk-service && go build -v -o risk-service main.go)
fi

if [ ! -f "$WEB_BIN" ]; then
    echo "[构建] web-portal..."
    (cd services/web-portal && go build -v -o web-portal main.go)
fi

echo "[启动] risk-service (端口 8080)..."
(cd services/risk-service && ./risk-service) &
RISK_PID=$!

sleep 2

echo "[启动] web-portal (端口 8081)..."
export RISK_SERVICE_URL="http://localhost:8080/score"
export OPA_URL="http://localhost:8181"
(cd services/web-portal && ./web-portal) &
WEB_PID=$!

sleep 2

echo ""
echo "=== 服务已启动 ==="
echo "  risk-service:  http://localhost:8080 (PID: $RISK_PID)"
echo "  web-portal:    http://localhost:8081 (PID: $WEB_PID)"
echo ""
echo "打开浏览器访问: http://localhost:8081"
echo ""
echo "提示: OPA 未启动，授权检查会显示错误（不影响风险评分演示）"
echo "      如需完整演示，请先启动 OPA: opa run --server --addr :8181 opa/policies"
echo ""
echo "停止服务: kill $RISK_PID $WEB_PID"
echo ""

# 等待用户中断
trap "echo ''; echo '停止服务...'; kill $RISK_PID $WEB_PID 2>/dev/null; exit 0" INT TERM
wait

