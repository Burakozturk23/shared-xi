$ErrorActionPreference = "Continue"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ReportDir = Join-Path $Root "reports\production\07b343"
$Log = Join-Path $ReportDir "prepush_debug.log"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

"==========================================================" | Tee-Object -FilePath $Log
"LINKBALL STEP 07B.3.4.3 - PRE-PUSH DEBUG WRAPPER" | Tee-Object -FilePath $Log -Append
"==========================================================" | Tee-Object -FilePath $Log -Append
"" | Tee-Object -FilePath $Log -Append
("Started: " + (Get-Date)) | Tee-Object -FilePath $Log -Append
("Repo: " + $Root) | Tee-Object -FilePath $Log -Append
"" | Tee-Object -FilePath $Log -Append

Set-Location $Root

function Run-Capture {
    param(
        [string]$Title,
        [string]$Command
    )

    ("--- " + $Title + " ---") | Tee-Object -FilePath $Log -Append
    ("[RUN] " + $Command) | Tee-Object -FilePath $Log -Append

    cmd.exe /d /s /c $Command 2>&1 |
        Tee-Object -FilePath $Log -Append

    $rc = $LASTEXITCODE
    ("[EXIT] " + $rc) | Tee-Object -FilePath $Log -Append
    "" | Tee-Object -FilePath $Log -Append

    return $rc
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    "[FAIL] python not found in PATH." | Tee-Object -FilePath $Log -Append
    Write-Host ""
    Write-Host "[STOP] Python bulunamadi." -ForegroundColor Red
    Write-Host "Log: $Log"
    Read-Host "Press ENTER to close"
    exit 1
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    "[FAIL] git not found in PATH." | Tee-Object -FilePath $Log -Append
    Write-Host ""
    Write-Host "[STOP] Git bulunamadi." -ForegroundColor Red
    Write-Host "Log: $Log"
    Read-Host "Press ENTER to close"
    exit 1
}

$patch = Join-Path $Root "tools\production\patch_step07b342_gitignore.py"
$audit = Join-Path $Root "tools\production\audit_step07b342_git_aware.py"

if (-not (Test-Path $patch)) {
    "[FAIL] patch_step07b342_gitignore.py missing." | Tee-Object -FilePath $Log -Append
    Write-Host ""
    Write-Host "[STOP] 07B.3.4.2 dosyalari bulunamadi." -ForegroundColor Red
    Write-Host "07B.3.4.2 ZIP'ini shared_xi ana dizinine tekrar cikarin."
    Write-Host "Log: $Log"
    Read-Host "Press ENTER to close"
    exit 2
}

if (-not (Test-Path $audit)) {
    "[FAIL] audit_step07b342_git_aware.py missing." | Tee-Object -FilePath $Log -Append
    Write-Host ""
    Write-Host "[STOP] 07B.3.4.2 audit dosyasi bulunamadi." -ForegroundColor Red
    Write-Host "07B.3.4.2 ZIP'ini shared_xi ana dizinine tekrar cikarin."
    Write-Host "Log: $Log"
    Read-Host "Press ENTER to close"
    exit 2
}

$rc1 = Run-Capture `
    "GITIGNORE HARDENING" `
    'python tools\production\patch_step07b342_gitignore.py'

if ($rc1 -ne 0) {
    Write-Host ""
    Write-Host "[STOP] .gitignore adimi hata verdi." -ForegroundColor Red
    Write-Host "Log kaydedildi:"
    Write-Host "  reports\production\07b343\prepush_debug.log"
    Write-Host ""
    Read-Host "Press ENTER to close"
    exit $rc1
}

$rc2 = Run-Capture `
    "GIT-AWARE PRE-PUSH AUDIT" `
    'python tools\production\audit_step07b342_git_aware.py'

Write-Host ""
Write-Host "=========================================================="
if ($rc2 -eq 0) {
    Write-Host "[OK] STEP 07B.3.4.3 PRE-PUSH PASS" -ForegroundColor Green
} elseif ($rc2 -eq 2) {
    Write-Host "[STOP] REAL PUSH BLOCKER(S) REMAIN" -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Audit could not complete. Exit code: $rc2" -ForegroundColor Red
}
Write-Host "=========================================================="
Write-Host ""
Write-Host "Full log:"
Write-Host "  reports\production\07b343\prepush_debug.log"
Write-Host ""
Write-Host "Bu pencere otomatik kapanmayacak."
Write-Host ""

Read-Host "Press ENTER to close"
exit $rc2
