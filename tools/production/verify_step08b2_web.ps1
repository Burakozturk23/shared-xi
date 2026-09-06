$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Config = Join-Path $Root "lib\config\privacy_config.dart"

if (-not (Test-Path $Config)) {
    throw "privacy_config.dart missing"
}

$Text = Get-Content $Config -Raw

$Privacy = [regex]::Match(
    $Text,
    "privacyPolicyUrl = '([^']+)'"
).Groups[1].Value

$Deletion = [regex]::Match(
    $Text,
    "accountDeletionUrl = '([^']+)'"
).Groups[1].Value

if (-not $Privacy -or -not $Deletion) {
    throw "Public URLs could not be resolved"
}

Write-Host "[CHECK] $Privacy"
$P = Invoke-WebRequest -Uri $Privacy -UseBasicParsing -TimeoutSec 30
if ($P.StatusCode -ne 200 -or $P.Content -notmatch "Linkball Gizlilik") {
    throw "Privacy Policy page verification failed"
}
Write-Host "[PASS] Privacy Policy HTTP 200"

Write-Host ""
Write-Host "[CHECK] $Deletion"
$D = Invoke-WebRequest -Uri $Deletion -UseBasicParsing -TimeoutSec 30
if ($D.StatusCode -ne 200 -or $D.Content -notmatch "hesap ve veri silme") {
    throw "Account deletion page verification failed"
}
Write-Host "[PASS] Account deletion resource HTTP 200"

Write-Host ""
Write-Host "[OK] STEP 08B.2 PUBLIC WEB VERIFY PASS"
