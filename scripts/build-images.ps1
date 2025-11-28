#!/usr/bin/env pwsh
# Docker 镜像构建脚本 - Windows PowerShell
# 用途：构建 risk-service 和 web-portal 镜像

$ErrorActionPreference = 'Stop'

Write-Host "=== Docker 镜像构建脚本 ===" -ForegroundColor Cyan

$REGISTRY = "localhost"
$TAG = "latest"

# 可选：从参数读取
if ($args.Count -ge 1) {
    $REGISTRY = $args[0]
}
if ($args.Count -ge 2) {
    $TAG = $args[1]
}

Write-Host "镜像仓库: $REGISTRY" -ForegroundColor Yellow
Write-Host "镜像标签: $TAG" -ForegroundColor Yellow
Write-Host ""

# 构建 risk-service
Write-Host "[1/2] 构建 risk-service..." -ForegroundColor Green
docker build -t "${REGISTRY}/risk-service:${TAG}" services/risk-service
if ($LASTEXITCODE -ne 0) {
    Write-Error "risk-service 构建失败"
    exit 1
}

# 构建 web-portal
Write-Host "[2/2] 构建 web-portal..." -ForegroundColor Green
docker build -t "${REGISTRY}/web-portal:${TAG}" services/web-portal
if ($LASTEXITCODE -ne 0) {
    Write-Error "web-portal 构建失败"
    exit 1
}

Write-Host ""
Write-Host "=== 构建完成 ===" -ForegroundColor Cyan
docker images | Select-String -Pattern "risk-service|web-portal"

Write-Host ""
Write-Host "下一步：" -ForegroundColor Yellow
Write-Host "  1. 推送镜像（如需）: docker push ${REGISTRY}/risk-service:${TAG}" -ForegroundColor White
Write-Host "  2. 部署到 K8s: ansible-playbook ansible/playbooks/10-apps.yml" -ForegroundColor White

