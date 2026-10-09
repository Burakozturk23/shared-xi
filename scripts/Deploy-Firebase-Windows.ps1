# Run from the repository root:
#   powershell -ExecutionPolicy Bypass -File .\scripts\Deploy-Firebase-Windows.ps1
# To deploy after validating lint and tests:
#   powershell -ExecutionPolicy Bypass -File .\scripts\Deploy-Firebase-Windows.ps1 -Deploy
param(
  [switch]$Deploy,
  [string]$ProjectId = "sharedix"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root

function Invoke-Checked {
  param([string]$Label, [string]$Executable, [string[]]$Arguments)
  Write-Host "==> $Label" -ForegroundColor Cyan
  & $Executable @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed (exit code $LASTEXITCODE). Deployment aborted."
  }
}

if (-not (Get-Command "npm.cmd" -ErrorAction SilentlyContinue)) {
  throw "npm.cmd not found. Install Node.js and reopen PowerShell."
}

Invoke-Checked "Install Functions dependencies" "npm.cmd" @("--prefix", "functions", "ci")
Invoke-Checked "Lint Functions" "npm.cmd" @("--prefix", "functions", "run", "lint")
Invoke-Checked "Test Functions" "npm.cmd" @("--prefix", "functions", "test")
Invoke-Checked "Check Functions syntax" "node.exe" @("--check", "functions/index.js")

if (-not $Deploy) {
  Write-Host "[OK] Local lint/tests passed. No deployment performed. Use -Deploy to deploy." -ForegroundColor Green
  exit 0
}

if (-not (Get-Command "firebase.cmd" -ErrorAction SilentlyContinue)) {
  throw "firebase.cmd not found. Install firebase-tools, then login with firebase login."
}

# Windows firebase-tools may attempt to spawn the entire predeploy command
# as one executable (ENOENT). Only the TEMPORARY config removes that hook.
# Lint and tests above have ALREADY been required to pass.
$source = Join-Path $root "firebase.json"
$temp = Join-Path $root ".firebase-windows-deploy-temp.json"
if (Test-Path $temp) {
  throw "Temporary config already exists: $temp. Investigate before continuing."
}
$config = Get-Content -LiteralPath $source -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in @($config.functions)) {
  $entry.PSObject.Properties.Remove("predeploy")
}

try {
  $config | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $temp -Encoding UTF8
  Invoke-Checked "Deploy Firebase Functions" "firebase.cmd" @(
    "deploy", "--project", $ProjectId, "--only", "functions", "--config", $temp
  )
  Write-Host "[OK] Firebase Functions deployment completed." -ForegroundColor Green
} finally {
  Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}
