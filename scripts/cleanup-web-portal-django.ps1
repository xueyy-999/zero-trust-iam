$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $root '..\services\web-portal-django' | Resolve-Path -ErrorAction SilentlyContinue
if ($null -ne $target) {
  Remove-Item -Recurse -Force $target
  Write-Host "Removed $target"
} else {
  Write-Host "Not found: services/web-portal-django"
}

