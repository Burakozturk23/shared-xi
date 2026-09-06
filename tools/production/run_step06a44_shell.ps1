$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Report = Join-Path $Root "reports\production\06a"
New-Item -ItemType Directory -Force -Path $Report | Out-Null

$firebase = (Get-Command firebase.cmd -ErrorAction SilentlyContinue)
if (-not $firebase) {
    $firebase = (Get-Command firebase -ErrorAction SilentlyContinue)
}
if (-not $firebase) {
    throw "firebase CLI bulunamadi."
}
$FirebasePath = $firebase.Source

Write-Host "[PASS] Firebase CLI:" -ForegroundColor Green
Write-Host "  $FirebasePath"
Write-Host ""

# Clean old candidates.
Get-ChildItem -Path $Report -Filter "candidate_*.google-services.json" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

$appsJson = Join-Path $Report "firebase_apps_android.json"

Write-Host "[RUN] firebase apps:list android --json" -ForegroundColor Cyan
& $FirebasePath apps:list android --project sharedix --json *> $appsJson
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Host ""
    Write-Host "[FAIL] firebase apps:list shell call failed: $code" -ForegroundColor Red
    if (Test-Path $appsJson) {
        Get-Content $appsJson
    }
    exit $code
}

Write-Host "[PASS] Android apps list saved." -ForegroundColor Green

python (Join-Path $Root "tools\production\parse_step06a44_apps.py")
if ($LASTEXITCODE -ne 0) {
    throw "Android app list parse failed."
}

$idFile = Join-Path $Report "firebase_android_app_ids.txt"
$appIds = Get-Content $idFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if (-not $appIds -or $appIds.Count -eq 0) {
    throw "No Firebase Android app IDs."
}

$i = 0
foreach ($appId in $appIds) {
    $i++
    $candidate = Join-Path $Report ("candidate_{0}.google-services.json" -f $i)

    Write-Host ""
    Write-Host "[CHECK $i/$($appIds.Count)] $appId" -ForegroundColor Cyan

    & $FirebasePath apps:sdkconfig android $appId -o $candidate --project sharedix
    $code = $LASTEXITCODE

    if ($code -ne 0) {
        Write-Host "[WARN] sdkconfig failed for $appId; continuing." -ForegroundColor Yellow
        Remove-Item $candidate -Force -ErrorAction SilentlyContinue
    }
}

python (Join-Path $Root "tools\production\select_step06a44_config.py")
if ($LASTEXITCODE -ne 0) {
    throw "Exact production Firebase config could not be selected."
}

python (Join-Path $Root "tools\production\verify_step06a44.py")
if ($LASTEXITCODE -ne 0) {
    throw "Step 06A.4.4 verification failed."
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "[OK] STEP 06A.4.4 PASS" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Cyan
Write-Host "  run_step06a4_release_verify.bat"
