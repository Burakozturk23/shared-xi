# Run from a checkout of the reviewed PR branch. This script never deploys or changes runtime flags.
[CmdletBinding()]
param(
  [switch]$BuildApk,
  [switch]$FunctionsOnly
)
$ErrorActionPreference = 'Stop'
function Invoke-Checked {
  param([string]$Program, [string[]]$Arguments)
  & $Program @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Program failed (exit $LASTEXITCODE). Fix the error before continuing." }
}
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
  $nodeCommand = (Get-Command node -ErrorAction Stop).Source
  $npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if (-not $npmCommand) { $npmCommand = Get-Command npm -ErrorAction Stop }
  $nodeMajor = [int]((& $nodeCommand --version).Trim().TrimStart('v').Split('.')[0])
  if ($nodeMajor -ne 24) { throw 'This project requires Node.js 24. Select Node.js 24 and rerun.' }
  Invoke-Checked $npmCommand.Source @('--prefix', 'functions', 'ci')
  Invoke-Checked $npmCommand.Source @('--prefix', 'functions', 'audit', '--audit-level=moderate')
  Invoke-Checked $npmCommand.Source @('--prefix', 'functions', 'run', 'lint')
  Invoke-Checked $npmCommand.Source @('--prefix', 'functions', 'test')
  Invoke-Checked $nodeCommand @('tools/arcade/build_vectors.js', '--check')
  if (-not $FunctionsOnly) {
    $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
    Invoke-Checked $flutterCommand @('pub', 'get')
    Invoke-Checked $flutterCommand @('analyze', '--no-fatal-infos', '--no-fatal-warnings')
    Invoke-Checked $flutterCommand @('test', '--reporter', 'expanded')
    if ($BuildApk) {
      Invoke-Checked $flutterCommand @('build', 'apk', '--debug')
      Write-Host 'APK: build/app/outputs/flutter-apk/app-debug.apk'
    }
  } elseif ($BuildApk) {
    throw 'Use -BuildApk without -FunctionsOnly to build Android.'
  }
  Write-Host 'Local checks passed. No backend deployment, rollout change or production activation was performed.'
} finally { Pop-Location }
