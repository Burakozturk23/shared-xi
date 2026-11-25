# Builds the signed Play Store app bundle (AAB) from the last commit.
#
# Gradle refuses the project path (the "İ" in "LİNKBALL PROJE"), so the committed
# code is exported to an ASCII folder, the release signing files are copied next to
# it, the bundle is built there and copied back to build\app\outputs\bundle\release.
# Uncommitted changes are NOT included: commit (and push) what the release needs first.
# The signing files are deleted from the temporary folder afterwards.
#
# Before running: raise "version:" in pubspec.yaml (e.g. 1.0.1+2 -> 1.0.2+3) and commit;
# Google Play refuses a build number it already has.
#
# Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File .\tools\build_play_aab.ps1
param(
    [string]$WorkDir = (Join-Path $env:TEMP "linkball-aab")
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$keyProperties = Join-Path $projectRoot "android\key.properties"
if (-not (Test-Path $keyProperties -PathType Leaf)) {
    throw "android\key.properties is missing. Restore the release signing files (docs/android-signing.md)."
}
$storeFile = (Get-Content $keyProperties | Where-Object { $_ -match '^\s*storeFile\s*=' }) -replace '^\s*storeFile\s*=\s*', ''
$keystore = Join-Path $projectRoot ("android\app\" + $storeFile)
if (-not (Test-Path $keystore -PathType Leaf)) { throw "Keystore not found: android\app\$storeFile" }

$dirty = git status --porcelain --untracked-files=no
if ($dirty) {
    Write-Host "Note: uncommitted changes are left out of the bundle:" -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "  $_" }
}
$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value
Write-Host "Building Linkball $version from commit $(git rev-parse --short HEAD)."

if (Test-Path $WorkDir) { Remove-Item -Recurse -Force $WorkDir }
New-Item -ItemType Directory -Path $WorkDir | Out-Null
$archive = Join-Path $env:TEMP "linkball-aab.tar"
git archive --format=tar -o $archive HEAD
tar -xf $archive -C $WorkDir
Remove-Item $archive

$workKeystore = Join-Path $WorkDir ("android\app\" + $storeFile)
try {
    Copy-Item $keyProperties (Join-Path $WorkDir "android\key.properties")
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $workKeystore) | Out-Null
    Copy-Item $keystore $workKeystore

    Push-Location $WorkDir
    try {
        & flutter pub get
        if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }
        & flutter build appbundle --release
        if ($LASTEXITCODE -ne 0) { throw "AAB build failed. Check the first error above." }
    } finally {
        Pop-Location
    }

    $built = Join-Path $WorkDir "build\app\outputs\bundle\release\app-release.aab"
    $outDir = Join-Path $projectRoot "build\app\outputs\bundle\release"
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    Copy-Item $built $outDir -Force
    Write-Host "AAB ready: $(Join-Path $outDir 'app-release.aab') ($version)" -ForegroundColor Green
    Write-Host "Upload it in Play Console: Test ve yayınla > Kapalı test > Yeni sürüm oluştur."
} finally {
    # Never leave the signing key in the temporary folder.
    Remove-Item -Force -ErrorAction SilentlyContinue $workKeystore, (Join-Path $WorkDir "android\key.properties")
}
