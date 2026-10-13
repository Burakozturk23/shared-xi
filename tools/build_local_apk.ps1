param(
    [ValidateSet("android-arm", "android-arm64", "android-x64", "android-arm,android-arm64,android-x64")]
    [string]$TargetPlatform = "android-arm,android-arm64,android-x64"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
$previousLocalApk = $env:ORG_GRADLE_PROJECT_linkballLocalApk
Push-Location $projectRoot
try {
    # This opt-in lives only during this script, including on build failure.
    $env:ORG_GRADLE_PROJECT_linkballLocalApk = "true"
    Write-Host "Building a local release-mode APK with the Android debug certificate."
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "Flutter dependency installation failed." }
    & flutter build apk --release --target-platform $TargetPlatform
    if ($LASTEXITCODE -ne 0) { throw "APK build failed. Check the first error above." }
    $apk = Join-Path $projectRoot "build/app/outputs/flutter-apk/app-release.apk"
    if (-not (Test-Path $apk -PathType Leaf)) { throw "APK output was not found." }
    Write-Host "APK ready: $apk"
    Write-Host "Local testing only. Use your existing upload key for Play Store builds."
} finally {
    if ($null -eq $previousLocalApk) {
        Remove-Item Env:ORG_GRADLE_PROJECT_linkballLocalApk -ErrorAction SilentlyContinue
    } else {
        $env:ORG_GRADLE_PROJECT_linkballLocalApk = $previousLocalApk
    }
    Pop-Location
}
