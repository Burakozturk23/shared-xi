param(
  [string]$RepoPath = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path $RepoPath).Path
Set-Location $repo

$required = @(
  "docs/design/monetization-a-d-closure.md",
  "docs/design/monetization-e-foundation.md",
  "lib/services/monetization_analytics.dart",
  "test/monetization_analytics_test.dart"
)

foreach ($file in $required) {
  if (-not (Test-Path (Join-Path $repo $file))) {
    throw "E foundation file is missing: $file"
  }
}

$foundation = Get-Content (Join-Path $repo "docs/design/monetization-e-foundation.md") -Raw
foreach ($marker in @(
  "FOUNDATION READY — SEASON PASS IMPLEMENTATION BLOCKED",
  "Free + Pro kozmetik ilerleme yolu",
  "Rekabetçi avantaj vermeyecek",
  "ikinci para birimi",
  "Loot box"
)) {
  if (-not $foundation.Contains($marker)) {
    throw "E foundation guard is missing: $marker"
  }
}

$analytics = Get-Content (Join-Path $repo "lib/services/monetization_analytics.dart") -Raw
foreach ($marker in @(
  "monetization_surface_view",
  "purchase_started",
  "purchase_completed",
  "store_offer_completed"
)) {
  if (-not $analytics.Contains($marker)) {
    throw "Cohort analytics marker is missing: $marker"
  }
}

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

flutter analyze --no-fatal-warnings --no-fatal-infos lib test integration_test
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed" }

flutter test --reporter expanded
if ($LASTEXITCODE -ne 0) { throw "flutter test failed" }

Write-Host ""
Write-Host "[OK] Monetization E foundation is ready. Season Pass remains blocked until live cohort data exists." -ForegroundColor Green
