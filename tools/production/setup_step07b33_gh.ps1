$ErrorActionPreference = "Stop"

Write-Host "=========================================================="
Write-Host "LINKBALL STEP 07B.3.3 - GITHUB CLI SETUP"
Write-Host "=========================================================="
Write-Host ""

$gh = Get-Command gh -ErrorAction SilentlyContinue

if ($gh) {
    Write-Host "[PASS] GitHub CLI already installed:"
    & gh --version
} else {
    Write-Host "[INFO] GitHub CLI (gh) is not installed."
    Write-Host ""

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host "[STOP] winget was not found." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Install GitHub CLI manually, then rerun this file."
        Write-Host "After install, open a NEW terminal and run:"
        Write-Host "  gh auth login"
        exit 2
    }

    $confirm = Read-Host "Type INSTALL to install GitHub CLI using winget"
    if ($confirm -ne "INSTALL") {
        Write-Host "Cancelled. Nothing was installed."
        exit 1
    }

    Write-Host ""
    Write-Host "[RUN] winget install GitHub CLI..."
    & winget install --id GitHub.cli --exact --source winget --accept-source-agreements --accept-package-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI installation failed."
    }

    # Refresh common PATH location in this process.
    $possible = @(
        "$env:ProgramFiles\GitHub CLI",
        "$env:LOCALAPPDATA\Programs\GitHub CLI"
    )

    foreach ($p in $possible) {
        if ((Test-Path $p) -and (-not ($env:Path -split ";" | Where-Object { $_ -eq $p }))) {
            $env:Path = "$p;$env:Path"
        }
    }

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Host ""
        Write-Host "[INFO] GitHub CLI installed, but this terminal has not refreshed PATH."
        Write-Host "Close this window, open a NEW terminal, and run:"
        Write-Host "  gh auth login"
        exit 3
    }

    Write-Host ""
    Write-Host "[PASS] GitHub CLI installed:"
    & gh --version
}

Write-Host ""
Write-Host "----------------------------------------------------------"
Write-Host "GitHub authentication"
Write-Host "----------------------------------------------------------"
Write-Host ""
Write-Host "A browser/login flow may open."
Write-Host "Use the GitHub account that owns or can manage the Linkball repository."
Write-Host ""

& gh auth status
if ($LASTEXITCODE -ne 0) {
    Write-Host "[RUN] gh auth login"
    & gh auth login

    if ($LASTEXITCODE -ne 0) {
        throw "GitHub authentication did not complete."
    }
}

Write-Host ""
& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is still not authenticated."
}

Write-Host ""
Write-Host "=========================================================="
Write-Host "[OK] STEP 07B.3.3 GITHUB CLI READY"
Write-Host "=========================================================="
Write-Host ""
Write-Host "Next run:"
Write-Host "  run_step07b31_github_secrets_setup.bat"
