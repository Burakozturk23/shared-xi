$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $Root

$ReportDir = Join-Path $Root "reports\production\08b24"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

function Resolve-Project {
    $FirebaseJson = Join-Path $Root "firebase.json"
    $FirebaseRc = Join-Path $Root ".firebaserc"

    if (Test-Path $FirebaseJson) {
        try {
            $Data = Get-Content $FirebaseJson -Raw | ConvertFrom-Json
            $Project = $Data.flutter.platforms.android.default.projectId
            if ($Project) {
                return [string]$Project
            }
        } catch {}
    }

    if (Test-Path $FirebaseRc) {
        try {
            $Data = Get-Content $FirebaseRc -Raw | ConvertFrom-Json
            $Project = $Data.projects.default
            if ($Project) {
                return [string]$Project
            }
        } catch {}
    }

    return ""
}

Write-Host "=========================================================="
Write-Host "LINKBALL STEP 08B.2.4 - ACCOUNT DELETION BACKEND VERIFY"
Write-Host "=========================================================="
Write-Host ""
Write-Host "READ-ONLY."
Write-Host "No Function will be called and no user data will be deleted."
Write-Host ""

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    throw "Firebase CLI was not found."
}

$Project = Resolve-Project
if (-not $Project) {
    throw "Firebase project id could not be resolved."
}

Write-Host "[PASS] Firebase project: $Project"
Write-Host ""
Write-Host "[RUN] firebase functions:list --project $Project --json"

$Raw = & firebase functions:list --project $Project --json 2>&1
$Rc = $LASTEXITCODE

$Raw | Set-Content `
    -Path (Join-Path $ReportDir "functions_list_raw.txt") `
    -Encoding UTF8

if ($Rc -ne 0) {
    Write-Host ""
    Write-Host "[FAIL] Firebase Functions list could not be read." -ForegroundColor Red
    Write-Host $Raw
    exit 2
}

$Joined = ($Raw | Out-String)

# Firebase CLI output format varies by CLI version.
# Look for both the exact exported id and common fully qualified variants.
$Found = (
    $Joined -match '"id"\s*:\s*"deleteMyAccount"' -or
    $Joined -match '"functionId"\s*:\s*"deleteMyAccount"' -or
    $Joined -match '\bdeleteMyAccount\b'
)

$RegionOk = (
    $Joined -match 'europe-west1' -or
    $Joined -notmatch 'region'
)

if (-not $Found) {
    Write-Host ""
    Write-Host "[STOP] deleteMyAccount is NOT visible in deployed Functions." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Do NOT test account deletion in the app yet."
    Write-Host "Next run:"
    Write-Host "  run_step08b24_deploy_delete_function.bat"
    exit 3
}

Write-Host "[PASS] Deployed Function found: deleteMyAccount"

if ($RegionOk) {
    Write-Host "[PASS] Region evidence is compatible with europe-west1"
} else {
    Write-Host "[WARN] Function found, but region could not be confirmed."
}

Write-Host ""
Write-Host "=========================================================="
Write-Host "[OK] STEP 08B.2.4 BACKEND VERIFY PASS" -ForegroundColor Green
Write-Host "=========================================================="
Write-Host ""
Write-Host "Safe to proceed with the Android TEST-account deletion smoke."
