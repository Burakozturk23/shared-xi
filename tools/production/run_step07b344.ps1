$ErrorActionPreference = "Continue"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ReportDir = Join-Path $Root "reports\production\07b344"
$Log = Join-Path $ReportDir "prepush_run.log"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
Set-Location $Root

function Write-Log {
    param([string]$Text)
    $Text | Tee-Object -FilePath $Log -Append | Out-Host
}

# Start fresh log.
"==========================================================" | Set-Content -Path $Log -Encoding UTF8
Write-Log "LINKBALL STEP 07B.3.4.4 - PRE-PUSH RUNNER FIX"
Write-Log "=========================================================="
Write-Log ""
Write-Log ("Started: " + (Get-Date))
Write-Log ("Repo: " + $Root)
Write-Log ""

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Log "[FAIL] python not found in PATH."
    Write-Host ""
    Write-Host "[STOP] Python bulunamadi." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Log "[FAIL] git not found in PATH."
    Write-Host ""
    Write-Host "[STOP] Git bulunamadi." -ForegroundColor Red
    Read-Host "Press ENTER to close"
    exit 1
}

$Patch = "tools\production\patch_step07b342_gitignore.py"
$Audit = "tools\production\audit_step07b342_git_aware.py"

foreach ($File in @($Patch, $Audit)) {
    if (-not (Test-Path (Join-Path $Root $File))) {
        Write-Log ("[FAIL] Missing helper: " + $File)
        Write-Host ""
        Write-Host "[STOP] Paket eksik cikartilmis." -ForegroundColor Red
        Read-Host "Press ENTER to close"
        exit 2
    }
}

Write-Log "--- GITIGNORE HARDENING ---"
Write-Log ("[RUN] python " + $Patch)

# Important: output goes to host/log, NOT into the return-code variable.
& python $Patch 2>&1 |
    Tee-Object -FilePath $Log -Append |
    Out-Host

$PatchRc = $LASTEXITCODE
Write-Log ("[EXIT] " + $PatchRc)
Write-Log ""

if ($PatchRc -ne 0) {
    Write-Host ""
    Write-Host "[STOP] Gercek .gitignore hatasi." -ForegroundColor Red
    Write-Host "Log:"
    Write-Host "  reports\production\07b344\prepush_run.log"
    Write-Host ""
    Read-Host "Press ENTER to close"
    exit $PatchRc
}

Write-Log "--- GIT-AWARE PRE-PUSH AUDIT ---"
Write-Log ("[RUN] python " + $Audit)

& python $Audit 2>&1 |
    Tee-Object -FilePath $Log -Append |
    Out-Host

$AuditRc = $LASTEXITCODE
Write-Log ("[EXIT] " + $AuditRc)
Write-Log ""

Write-Host ""
Write-Host "=========================================================="
if ($AuditRc -eq 0) {
    Write-Host "[OK] STEP 07B.3.4.4 GITHUB PRE-PUSH PASS" -ForegroundColor Green
} elseif ($AuditRc -eq 2) {
    Write-Host "[STOP] REAL PUSH BLOCKER(S) REMAIN" -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Audit calisamadi. Exit code: $AuditRc" -ForegroundColor Red
}
Write-Host "=========================================================="
Write-Host ""
Write-Host "Full log:"
Write-Host "  reports\production\07b344\prepush_run.log"
Write-Host ""
Write-Host "Bu pencere otomatik kapanmayacak."
Write-Host ""

Read-Host "Press ENTER to close"
exit $AuditRc
