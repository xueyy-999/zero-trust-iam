#!/usr/bin/env pwsh
# 审计日志测试脚本
# 用途：测试审计日志功能是否正常工作

$ErrorActionPreference = 'Stop'

Write-Host '=== Audit Logging Test ===' -ForegroundColor Cyan

$riskUrl = "http://localhost:8080/score"
$metricsUrl = "http://localhost:8080/metrics"

Write-Host '[1] Testing risk-service health...' -ForegroundColor Yellow
try {
    $null = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get
    Write-Host '  ✓ Risk service is healthy' -ForegroundColor Green
} catch {
    Write-Host '  ✗ Risk service is not running' -ForegroundColor Red
    Write-Host '  Please start risk-service first' -ForegroundColor Red
    exit 1
}

Write-Host '[2] Sending test requests...' -ForegroundColor Yellow

$testCases = @(
    @{
        name = "Low Risk"
        data = @{
            userId = "user1"
            roles = @("user")
            resource = "orders"
            action = "read"
            ip = "192.168.1.1"
            userAgent = "Mozilla/5.0"
            geo = "CN"
            time = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            failedLoginCount = 0
        }
    },
    @{
        name = "Medium Risk"
        data = @{
            userId = "user2"
            roles = @("user")
            resource = "orders"
            action = "read"
            ip = "1.2.3.4"
            userAgent = "Mozilla/5.0"
            geo = "US"
            time = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            failedLoginCount = 2
        }
    },
    @{
        name = "High Risk"
        data = @{
            userId = "admin1"
            roles = @("admin")
            resource = "users"
            action = "admin"
            ip = "1.2.3.4"
            userAgent = ""
            geo = "RU"
            time = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            failedLoginCount = 5
        }
    }
)

foreach ($test in $testCases) {
    Write-Host "  Testing: $($test.name)..." -ForegroundColor White
    
    try {
        $json = $test.data | ConvertTo-Json
        $response = Invoke-RestMethod -Uri $riskUrl -Method Post -Body $json -ContentType "application/json"
        
        Write-Host "    Score: $($response.score)" -ForegroundColor Cyan
        Write-Host "    Reasons: $($response.reasons -join ', ')" -ForegroundColor Cyan
        Write-Host "    ✓ Request successful" -ForegroundColor Green
    } catch {
        Write-Host "    ✗ Request failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Start-Sleep -Milliseconds 500
}

Write-Host '[3] Checking metrics...' -ForegroundColor Yellow
try {
    $metrics = Invoke-RestMethod -Uri $metricsUrl -Method Get
    
    Write-Host "  Total Requests: $($metrics.total_requests)" -ForegroundColor White
    Write-Host "  Success Requests: $($metrics.success_requests)" -ForegroundColor Green
    Write-Host "  Failed Requests: $($metrics.failed_requests)" -ForegroundColor Red
    Write-Host "  High Risk Count: $($metrics.high_risk_count)" -ForegroundColor Red
    Write-Host "  Medium Risk Count: $($metrics.medium_risk_count)" -ForegroundColor Yellow
    Write-Host "  Low Risk Count: $($metrics.low_risk_count)" -ForegroundColor Green
    Write-Host '  ✓ Metrics endpoint working' -ForegroundColor Green
} catch {
    Write-Host '  ✗ Failed to get metrics' -ForegroundColor Red
}

Write-Host ''
Write-Host '=== Test Complete ===' -ForegroundColor Cyan
Write-Host 'Note: To enable audit logging to MySQL, set MYSQL_DSN environment variable' -ForegroundColor Yellow
Write-Host 'Example: $env:MYSQL_DSN = "user:password@tcp(localhost:3306)/iam_db"' -ForegroundColor Yellow
