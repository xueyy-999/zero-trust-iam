 #!/usr/bin/env pwsh
 # 本地一键启动脚本 - Windows PowerShell
 # 用途：快速启动 risk-service + web-portal 进行本地演示
 
 $ErrorActionPreference = 'Stop'
 
 Write-Host '=== Zero Trust IAM Local Runner ===' -ForegroundColor Cyan
 
 function Join-PathSafe {
     param(
         [Parameter(Mandatory = $true)][string]$Base,
         [Parameter(Mandatory = $true)][string[]]$Parts
     )
     $p = $Base
     foreach ($part in $Parts) {
         $p = Join-Path $p $part
     }
     return $p
 }
 
 $scriptPath = $PSCommandPath
 if (-not $scriptPath) {
     $scriptPath = $MyInvocation.MyCommand.Path
 }
 if (-not $scriptPath) {
     throw 'cannot determine script path'
 }
 
 $scriptDir = Split-Path -Parent $scriptPath
 $projectRoot = (Get-Item -LiteralPath (Join-Path $scriptDir '..')).FullName
 if (-not $projectRoot) {
     throw 'projectRoot is empty'
 }
 
 $riskDir = Join-PathSafe -Base $projectRoot -Parts @('services', 'risk-service')
 $webDir  = Join-PathSafe -Base $projectRoot -Parts @('services', 'web-portal')
 
 $riskExe = Join-Path $riskDir 'risk-service.exe'
 $webExe  = Join-Path $webDir 'web-portal.exe'
 
 if (-not (Test-Path -LiteralPath $riskDir)) {
     throw ('missing directory: ' + $riskDir)
 }
 if (-not (Test-Path -LiteralPath $webDir)) {
     throw ('missing directory: ' + $webDir)
 }
 
 if (-not (Test-Path -LiteralPath $riskExe)) {
     Write-Host '[build] risk-service...' -ForegroundColor Yellow
     Push-Location $riskDir
     go build -v -o risk-service.exe .
     Pop-Location
 }
 
 if (-not (Test-Path -LiteralPath $webExe)) {
     Write-Host '[build] web-portal...' -ForegroundColor Yellow
     Push-Location $webDir
     go build -v -o web-portal.exe .
     Pop-Location
 }
 
 Write-Host '[start] risk-service (8080)...' -ForegroundColor Green
 $riskProc = Start-Process -FilePath $riskExe -WorkingDirectory $riskDir -PassThru
 Start-Sleep -Seconds 1
 if ($riskProc.HasExited) {
     throw ('risk-service exited early, exit_code=' + $riskProc.ExitCode)
 }
 
 Start-Sleep -Seconds 2
 
 Write-Host '[start] web-portal (8081)...' -ForegroundColor Green
 $env:RISK_SERVICE_URL = 'http://localhost:8080/score'
 $env:OPA_URL = 'http://localhost:8181'
 $webProc = Start-Process -FilePath $webExe -WorkingDirectory $webDir -PassThru
 Start-Sleep -Seconds 1
 if ($webProc.HasExited) {
     throw ('web-portal exited early, exit_code=' + $webProc.ExitCode)
 }
 
 Start-Sleep -Seconds 2
 
 Write-Host ''
 Write-Host '=== Services Started ===' -ForegroundColor Cyan
 Write-Host '  risk-service:  http://localhost:8080' -ForegroundColor White
 Write-Host '  web-portal:    http://localhost:8081' -ForegroundColor White
 Write-Host ''
 
 Start-Sleep -Seconds 1
 Start-Process 'http://localhost:8081'
