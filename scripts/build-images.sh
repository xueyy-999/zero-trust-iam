#!/usr/bin/env bash
# Docker 镜像构建脚本 - Linux/macOS
# 用途：构建 risk-service 和 web-portal 镜像

set -euo pipefail

echo "=== Docker 镜像构建脚本 ==="

REGISTRY="${1:-localhost}"
TAG="${2:-latest}"

echo "镜像仓库: $REGISTRY"
echo "镜像标签: $TAG"
echo ""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# 构建 risk-service
echo "[1/2] 构建 risk-service..."
docker build -t "${REGISTRY}/risk-service:${TAG}" services/risk-service

# 构建 web-portal
echo "[2/2] 构建 web-portal..."
docker build -t "${REGISTRY}/web-portal:${TAG}" services/web-portal

echo ""
echo "=== 构建完成 ==="
docker images | grep -E "risk-service|web-portal" || true

echo ""
echo "下一步："
echo "  1. 推送镜像（如需）: docker push ${REGISTRY}/risk-service:${TAG}"
echo "  2. 部署到 K8s: ansible-playbook ansible/playbooks/10-apps.yml"

