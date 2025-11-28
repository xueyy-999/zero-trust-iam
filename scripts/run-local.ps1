#!/usr/bin/env pwsh
# 本地一键启动脚本 - Windows PowerShell
# 用途：快速启动 risk-service + web-portal 进行本地演示

$ErrorActionPreference = 'Stop'

Write-Host "=== 零信任 IAM 本地启动脚本 ===" -ForegroundColor Cyan

# 检查构建产物
$riskBin = "services\risk-service\risk-service.exe"
$webBin = "services\web-portal\web-portal.exe"

if (-not (Test-Path $riskBin)) {
    Write-Host "[构建] risk-service..." -ForegroundColor Yellow
    Push-Location services\risk-service
    go build -v -o risk-service.exe main.go
    Pop-Location
}

if (-not (Test-Path $webBin)) {
    Write-Host "[构建] web-portal..." -ForegroundColor Yellow
    Push-Location services\web-portal
    go build -v -o web-portal.exe main.go
    Pop-Location
}

Write-Host "[启动] risk-service (端口 8080)..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\services\risk-service'; .\risk-service.exe"

Start-Sleep -Seconds 2

Write-Host "[启动] web-portal (端口 8081)..." -ForegroundColor Green
$env:RISK_SERVICE_URL = "http://localhost:8080/score"
$env:OPA_URL = "http://localhost:8181"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\services\web-portal'; `$env:RISK_SERVICE_URL='http://localhost:8080/score'; `$env:OPA_URL='http://localhost:8181'; .\web-portal.exe"

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "=== 服务已启动 ===" -ForegroundColor Cyan
Write-Host "  risk-service:  http://localhost:8080" -ForegroundColor White
Write-Host "  web-portal:    http://localhost:8081" -ForegroundColor White
Write-Host ""
Write-Host "打开浏览器访问: http://localhost:8081" -ForegroundColor Yellow
Write-Host ""
Write-Host "提示: OPA 未启动，授权检查会显示错误（不影响风险评分演示）" -ForegroundColor Gray
Write-Host "      如需完整演示，请先启动 OPA: opa run --server --addr :8181 opa/policies" -ForegroundColor Gray
Write-Host ""

# 自动打开浏览器
Start-Sleep -Seconds 1
Start-Process "http://localhost:8081"

