# Risk Service API 测试脚本

$baseUrl = "http://localhost:8080"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Risk Service API 测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 测试 1: 健康检查
Write-Host "测试 1: 健康检查" -ForegroundColor Yellow
Write-Host "GET $baseUrl/health" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/health" -Method Get -ErrorAction Stop
    Write-Host "✓ 状态: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "✓ 响应: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "✗ 错误: $_" -ForegroundColor Red
}
Write-Host ""

# 测试 2: 低风险场景
Write-Host "测试 2: 低风险场景（正常用户，工作时间，中国地区）" -ForegroundColor Yellow
$body = @{
    userId = "user123"
    roles = @("user")
    resource = "orders"
    action = "read"
    ip = "1.2.3.4"
    userAgent = "Mozilla/5.0"
    geo = "CN"
    time = "2024-01-01T12:00:00Z"
    failedLoginCount = 0
} | ConvertTo-Json

Write-Host "POST $baseUrl/score" -ForegroundColor Gray
Write-Host "Body: $body" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/score" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
    Write-Host "✓ 状态: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "✓ 响应: $($response.Content)" -ForegroundColor Green
    $json = $response.Content | ConvertFrom-Json
    Write-Host "  风险分: $($json.score)" -ForegroundColor Cyan
    Write-Host "  原因: $($json.reasons -join ', ')" -ForegroundColor Cyan
} catch {
    Write-Host "✗ 错误: $_" -ForegroundColor Red
}
Write-Host ""

# 测试 3: 高风险场景
Write-Host "测试 3: 高风险场景（多次失败登录，非中国地区，夜间，缺失UA）" -ForegroundColor Yellow
$body = @{
    userId = "user456"
    roles = @("user")
    resource = "orders"
    action = "read"
    ip = "1.2.3.4"
    userAgent = ""
    geo = "US"
    time = "2024-01-01T23:00:00Z"
    failedLoginCount = 5
} | ConvertTo-Json

Write-Host "POST $baseUrl/score" -ForegroundColor Gray
Write-Host "Body: $body" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/score" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
    Write-Host "✓ 状态: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "✓ 响应: $($response.Content)" -ForegroundColor Green
    $json = $response.Content | ConvertFrom-Json
    Write-Host "  风险分: $($json.score)" -ForegroundColor Red
    Write-Host "  原因: $($json.reasons -join ', ')" -ForegroundColor Red
} catch {
    Write-Host "✗ 错误: $_" -ForegroundColor Red
}
Write-Host ""

# 测试 4: 管理员操作
Write-Host "测试 4: 管理员操作（特权操作）" -ForegroundColor Yellow
$body = @{
    userId = "admin123"
    roles = @("admin")
    resource = "users"
    action = "admin"
    ip = "1.2.3.4"
    userAgent = "Mozilla/5.0"
    geo = "CN"
    time = "2024-01-01T12:00:00Z"
    failedLoginCount = 0
} | ConvertTo-Json

Write-Host "POST $baseUrl/score" -ForegroundColor Gray
Write-Host "Body: $body" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/score" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
    Write-Host "✓ 状态: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "✓ 响应: $($response.Content)" -ForegroundColor Green
    $json = $response.Content | ConvertFrom-Json
    Write-Host "  风险分: $($json.score)" -ForegroundColor Cyan
    Write-Host "  原因: $($json.reasons -join ', ')" -ForegroundColor Cyan
} catch {
    Write-Host "✗ 错误: $_" -ForegroundColor Red
}
Write-Host ""

# 测试 5: 夜间访问
Write-Host "测试 5: 夜间访问（22:00-06:00）" -ForegroundColor Yellow
$body = @{
    userId = "user789"
    roles = @("user")
    resource = "orders"
    action = "read"
    ip = "1.2.3.4"
    userAgent = "Mozilla/5.0"
    geo = "CN"
    time = "2024-01-01T02:30:00Z"
    failedLoginCount = 0
} | ConvertTo-Json

Write-Host "POST $baseUrl/score" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/score" -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
    Write-Host "✓ 状态: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "✓ 响应: $($response.Content)" -ForegroundColor Green
    $json = $response.Content | ConvertFrom-Json
    Write-Host "  风险分: $($json.score)" -ForegroundColor Cyan
    Write-Host "  原因: $($json.reasons -join ', ')" -ForegroundColor Cyan
} catch {
    Write-Host "✗ 错误: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "测试完成！" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

