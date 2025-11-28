# PowerShell script - Deploy to CentOS

param(
    [string]$HostIP = "192.168.76.129",
    [string]$User = "root",
    [string]$Password = "1"
)

Write-Host "=========================================="
Write-Host "Starting remote deployment"
Write-Host "=========================================="
Write-Host ""

# Create SSH command
$sshCmd = @"
#!/bin/bash
set -e

echo '=========================================='
echo 'Starting deployment'
echo '=========================================='

# Stop old Risk Service
echo 'Stopping old Risk Service...'
pkill -f risk-service || true
sleep 1

# Start Risk Service
echo 'Starting Risk Service...'
nohup /home/bs/services/risk-service/risk-service > /tmp/risk-service.log 2>&1 &
sleep 2

echo ''
echo '=========================================='
echo 'Deployment complete!'
echo '=========================================='
echo ''
echo 'Service status:'
ps aux | grep risk-service | grep -v grep

echo ''
echo 'Access URLs:'
echo '  Risk Service:  http://192.168.76.129:8080/health'
echo '  Risk Score:    http://192.168.76.129:8080/score'

echo ''
echo 'View logs:'
echo '  tail -f /tmp/risk-service.log'

echo ''
echo 'Test API:'
curl -s http://localhost:8080/health
echo ''
"@

# Save script to temp file
$tempScript = [System.IO.Path]::GetTempFileName()
$sshCmd | Out-File -FilePath $tempScript -Encoding ASCII

Write-Host "Uploading deployment script..."
# Upload script using SCP
& scp -o StrictHostKeyChecking=no $tempScript "${User}@${HostIP}:/tmp/deploy-remote.sh" 2>&1 | Out-Null

Write-Host "Executing deployment..."
# Execute script using SSH
& ssh -o StrictHostKeyChecking=no "${User}@${HostIP}" "bash /tmp/deploy-remote.sh"

# Cleanup
Remove-Item $tempScript -Force

Write-Host ""
Write-Host "Deployment complete!"

