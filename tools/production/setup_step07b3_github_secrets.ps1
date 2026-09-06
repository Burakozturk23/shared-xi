$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$KeyProps = Join-Path $Repo "android\key.properties"

Write-Host "=========================================================="
Write-Host "LINKBALL STEP 07B.3 - GITHUB SIGNING SECRETS"
Write-Host "=========================================================="
Write-Host ""
Write-Host "This sends the existing LOCAL upload-signing values directly"
Write-Host "to GitHub Actions Secrets through the GitHub CLI."
Write-Host ""
Write-Host "Secret values are NOT printed and are NOT written into reports."
Write-Host ""

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "[STOP] GitHub CLI (gh) was not found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Manual GitHub Actions secret names:"
    Write-Host "  LINKBALL_UPLOAD_KEYSTORE_BASE64"
    Write-Host "  LINKBALL_UPLOAD_STORE_PASSWORD"
    Write-Host "  LINKBALL_UPLOAD_KEY_ALIAS"
    Write-Host "  LINKBALL_UPLOAD_KEY_PASSWORD"
    exit 2
}

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated. Run: gh auth login"
}

if (-not (Test-Path $KeyProps)) {
    throw "android/key.properties was not found."
}

$props = @{}
Get-Content $KeyProps | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#") -or -not $line.Contains("=")) {
        return
    }
    $parts = $line.Split("=", 2)
    $props[$parts[0].Trim()] = $parts[1].Trim()
}

foreach ($key in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
    if (-not $props.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($props[$key])) {
        throw "Missing key.properties value: $key"
    }
}

$storeFile = $props["storeFile"]
$candidates = @()

if ([System.IO.Path]::IsPathRooted($storeFile)) {
    $candidates += $storeFile
} else {
    $candidates += (Join-Path $Repo ("android\app\" + $storeFile))
    $candidates += (Join-Path $Repo ("android\" + $storeFile))
    $candidates += (Join-Path $Repo $storeFile)
}

$Keystore = $null
foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
        $Keystore = (Resolve-Path $candidate).Path
        break
    }
}

if (-not $Keystore) {
    throw "Upload keystore could not be resolved from key.properties storeFile."
}

Write-Host "[PASS] key.properties found"
Write-Host "[PASS] upload keystore found"
Write-Host ""
$confirmation = Read-Host "Type SET to upload the four signing secrets to this GitHub repository"
if ($confirmation -ne "SET") {
    Write-Host "Cancelled. No GitHub secret was changed."
    exit 1
}

function Set-GhSecret([string] $Name, [string] $Value) {
    $Value | & gh secret set $Name
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set GitHub secret: $Name"
    }
    Write-Host "[SET] $Name"
}

$keystoreBase64 = [Convert]::ToBase64String(
    [System.IO.File]::ReadAllBytes($Keystore)
)

Set-GhSecret "LINKBALL_UPLOAD_KEYSTORE_BASE64" $keystoreBase64
Set-GhSecret "LINKBALL_UPLOAD_STORE_PASSWORD" $props["storePassword"]
Set-GhSecret "LINKBALL_UPLOAD_KEY_ALIAS" $props["keyAlias"]
Set-GhSecret "LINKBALL_UPLOAD_KEY_PASSWORD" $props["keyPassword"]

Write-Host ""
Write-Host "[OK] GitHub signing secrets configured." -ForegroundColor Green
Write-Host "Values were never printed."
