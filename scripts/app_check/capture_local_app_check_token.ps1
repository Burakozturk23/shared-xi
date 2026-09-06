param(
  [string]$ProjectRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Find-ProjectRoot {
  param([string]$StartPath)
  $current = [System.IO.Path]::GetFullPath($StartPath)
  if (Test-Path $current -PathType Leaf) { $current = Split-Path -Parent $current }
  while ($true) {
    if (Test-Path (Join-Path $current "pubspec.yaml")) { return $current }
    $parent = Split-Path -Parent $current
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
      throw "Could not locate Flutter project root."
    }
    $current = $parent
  }
}

function Get-AndroidFirebaseAppId {
  param([string]$FirebaseOptionsPath)
  $raw = Get-Content $FirebaseOptionsPath -Raw
  $m = [regex]::Match(
    $raw,
    "static\s+const\s+FirebaseOptions\s+android\s*=\s*FirebaseOptions\s*\((?s:.*?)appId\s*:\s*'([^']+)'"
  )
  if (-not $m.Success) { throw "Could not extract Android Firebase appId." }
  return $m.Groups[1].Value
}

function Resolve-AdbPath {
  param([string]$Root)

  $cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
  if ($null -ne $cmd -and (Test-Path $cmd.Source -PathType Leaf)) {
    return $cmd.Source
  }

  $candidates = New-Object System.Collections.Generic.List[string]

  foreach ($sdk in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)) {
    if (-not [string]::IsNullOrWhiteSpace($sdk)) {
      $candidates.Add((Join-Path $sdk "platform-tools\adb.exe"))
    }
  }

  $localProps = Join-Path $Root "android\local.properties"
  if (Test-Path $localProps -PathType Leaf) {
    $line = Get-Content $localProps |
      Where-Object { $_ -match '^\s*sdk\.dir\s*=' } |
      Select-Object -First 1
    if ($null -ne $line) {
      $sdkDir = ($line -replace '^\s*sdk\.dir\s*=\s*', '').Trim()
      # Gradle local.properties on Windows may escape backslashes.
      $sdkDir = $sdkDir.Replace('\\', '\')
      if (-not [string]::IsNullOrWhiteSpace($sdkDir)) {
        $candidates.Add((Join-Path $sdkDir "platform-tools\adb.exe"))
      }
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $candidates.Add((Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"))
  }

  if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    $candidates.Add((Join-Path $env:USERPROFILE "AppData\Local\Android\Sdk\platform-tools\adb.exe"))
  }

  foreach ($candidate in $candidates | Select-Object -Unique) {
    if (Test-Path $candidate -PathType Leaf) {
      return [System.IO.Path]::GetFullPath($candidate)
    }
  }

  throw @"
adb.exe could not be found automatically.

Checked:
- PATH
- ANDROID_SDK_ROOT
- ANDROID_HOME
- android\local.properties (sdk.dir)
- %LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe

Open Android Studio > SDK Manager and confirm Android SDK Platform-Tools is installed.
"@
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
} else {
  $ProjectRoot = Find-ProjectRoot -StartPath $ProjectRoot
}
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

$adb = Resolve-AdbPath -Root $ProjectRoot
$appId = Get-AndroidFirebaseAppId -FirebaseOptionsPath (Join-Path $ProjectRoot "lib\firebase_options.dart")

Write-Host "===== LINKBALL LOCAL APP CHECK DEBUG TOKEN =====" -ForegroundColor Cyan
Write-Host "ADB                    : $adb"
Write-Host "Firebase Android appId : $appId"

$deviceLines = & $adb devices
$devices = @($deviceLines | Select-String "`tdevice$" | ForEach-Object {
  ($_.Line -split "`t")[0]
})

if ($devices.Count -eq 0) {
  throw "No Android emulator/device connected. Start the emulator/device, then run this again."
}

Write-Host "Connected devices      : $($devices -join ', ')"
Write-Host ""

$log = & $adb logcat -d -v brief
$joined = ($log -join "`n")

$patterns = @(
  'Enter this debug secret into the allow list.*?:\s*([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
  'debug secret.*?:\s*([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})'
)

$token = $null
foreach ($pat in $patterns) {
  $matches = [regex]::Matches($joined, $pat, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($matches.Count -gt 0) {
    $token = $matches[$matches.Count - 1].Groups[1].Value
    break
  }
}

if ([string]::IsNullOrWhiteSpace($token)) {
  Write-Host "[INFO] No newly-generated App Check debug token is present in current logcat." -ForegroundColor Yellow
  Write-Host "Firebase usually logs the token only when it is generated."
  Write-Host ""
  Write-Host "Do this once:"
  Write-Host "  1) Close the running app."
  Write-Host "  2) Clear logcat with: `"$adb`" logcat -c"
  Write-Host "  3) Run: flutter run --profile"
  Write-Host "  4) Wait until App Check initializes."
  Write-Host "  5) Run this helper again."
  Write-Host ""
  Write-Host "Do NOT clear app data unless you intentionally want to rotate the local token."
  exit 3
}

Write-Host "LOCAL DEBUG TOKEN:" -ForegroundColor Yellow
Write-Host $token
Write-Host ""
Write-Host "Register it in Firebase Console:" -ForegroundColor Cyan
Write-Host "  App Check > Apps > Android app with appId $appId"
Write-Host "  ... > Manage debug tokens"
Write-Host "  Label: LOCAL-BERAT-EMULATOR"
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Yellow
Write-Host "- Do not paste this token into source code, Git, chat, or committed env files."
Write-Host "- Keep your existing good Console token; add this emulator token separately."
Write-Host "- This helper does not save the token to disk."
