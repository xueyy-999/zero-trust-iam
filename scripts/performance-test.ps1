#!/usr/bin/env pwsh
# 性能测试脚本 - Risk Service
# 用途：测试 risk-service 的并发性能和响应时间

param(
    [int]$Concurrent = 50,
    [int]$Requests = 1000,
    [string]$Url = "http://localhost:8080/score"
)

Write-Host "=== Risk Service Performance Test ===" -ForegroundColor Cyan
Write-Host "Target URL: $Url" -ForegroundColor White
Write-Host "Concurrent Users: $Concurrent" -ForegroundColor White
Write-Host "Total Requests: $Requests" -ForegroundColor White
Write-Host ""

$testData = @{
    userId = "test-user"
    roles = @("user")
    resource = "orders"
    action = "read"
    ip = "192.168.1.100"
    userAgent = "PerformanceTest/1.0"
    geo = "CN"
    time = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    failedLoginCount = 0
} | ConvertTo-Json

$results = @{
    success = 0
    failed = 0
    totalTime = 0
    minTime = [double]::MaxValue
    maxTime = 0
    times = @()
}

Write-Host "[START] Running performance test..." -ForegroundColor Green

$startTime = Get-Date

$jobs = 1..$Requests | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url, $data)
        
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $response = Invoke-RestMethod -Uri $url -Method Post -Body $data -ContentType "application/json" -TimeoutSec 10
            $sw.Stop()
            return @{
                success = $true
                time = $sw.ElapsedMilliseconds
                score = $response.score
            }
        } catch {
            $sw.Stop()
            return @{
                success = $false
                time = $sw.ElapsedMilliseconds
                error = $_.Exception.Message
            }
        }
    } -ArgumentList $Url, $testData
}

$completed = 0
$total = $jobs.Count

while ($jobs) {
    $finished = $jobs | Where-Object { $_.State -eq 'Completed' -or $_.State -eq 'Failed' }
    
    foreach ($job in $finished) {
        $result = Receive-Job -Job $job
        $completed++
        
        if ($result.success) {
            $results.success++
            $results.totalTime += $result.time
            $results.times += $result.time
            
            if ($result.time -lt $results.minTime) {
                $results.minTime = $result.time
            }
            if ($result.time -gt $results.maxTime) {
                $results.maxTime = $result.time
            }
        } else {
            $results.failed++
        }
        
        Remove-Job -Job $job
        
        if ($completed % 100 -eq 0) {
            $progress = [math]::Round(($completed / $total) * 100, 1)
            Write-Host "Progress: $completed/$total ($progress%)" -ForegroundColor Yellow
        }
    }
    
    $jobs = $jobs | Where-Object { $_.State -ne 'Completed' -and $_.State -ne 'Failed' }
    
    if ($jobs) {
        Start-Sleep -Milliseconds 100
    }
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "=== Test Results ===" -ForegroundColor Cyan
Write-Host "Total Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor White
Write-Host "Successful Requests: $($results.success)" -ForegroundColor Green
Write-Host "Failed Requests: $($results.failed)" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($results.success / $Requests) * 100, 2))%" -ForegroundColor White
Write-Host "Requests/Second: $([math]::Round($Requests / $duration, 2))" -ForegroundColor White
Write-Host ""

if ($results.success -gt 0) {
    $avgTime = $results.totalTime / $results.success
    $sortedTimes = $results.times | Sort-Object
    $p50 = $sortedTimes[[math]::Floor($sortedTimes.Count * 0.5)]
    $p95 = $sortedTimes[[math]::Floor($sortedTimes.Count * 0.95)]
    $p99 = $sortedTimes[[math]::Floor($sortedTimes.Count * 0.99)]
    
    Write-Host "=== Response Time Statistics ===" -ForegroundColor Cyan
    Write-Host "Min: $([math]::Round($results.minTime, 2)) ms" -ForegroundColor White
    Write-Host "Max: $([math]::Round($results.maxTime, 2)) ms" -ForegroundColor White
    Write-Host "Average: $([math]::Round($avgTime, 2)) ms" -ForegroundColor White
    Write-Host "P50 (Median): $([math]::Round($p50, 2)) ms" -ForegroundColor White
    Write-Host "P95: $([math]::Round($p95, 2)) ms" -ForegroundColor White
    Write-Host "P99: $([math]::Round($p99, 2)) ms" -ForegroundColor White
    Write-Host ""
    
    if ($avgTime -lt 50) {
        Write-Host "[EXCELLENT] Average response time < 50ms" -ForegroundColor Green
    } elseif ($avgTime -lt 100) {
        Write-Host "[GOOD] Average response time < 100ms" -ForegroundColor Yellow
    } else {
        Write-Host "[WARNING] Average response time >= 100ms" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
