param(
  [string]$RepoPath = $PSScriptRoot,
  [string]$ProjectId = "sharedix",
  [switch]$NoDeploy,
  [switch]$SkipFlutterChecks
)

$ErrorActionPreference = "Stop"

function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )
  Write-Host ""
  Write-Host "==> $Label" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE."
  }
}

$repo = (Resolve-Path $RepoPath).Path
Set-Location $repo

$required = @(
  "functions/index.js",
  "functions/coin_purchases.js",
  "lib/services/coin_billing_service.dart",
  "lib/screens/coin_packs_page.dart",
  "docs/design/monetization-c.md"
)
foreach ($file in $required) {
  if (-not (Test-Path (Join-Path $repo $file))) {
    throw "Stage C file is missing: $file"
  }
}

$index = Get-Content (Join-Path $repo "functions/index.js") -Raw
foreach ($marker in @(
  "MONETIZATION_C_COIN_PURCHASES_START",
  "exports.getCoinPurchaseCatalog",
  "exports.verifyCoinPurchase",
  "exports.reconcileCoinPurchases"
)) {
  if (-not $index.Contains($marker)) {
    throw "Stage C marker is missing from functions/index.js: $marker"
  }
}

Invoke-Native "Install Functions dependencies" { npm --prefix functions ci }
Invoke-Native "Lint Functions" { npm --prefix functions run lint }
Invoke-Native "Run Functions tests" { npm --prefix functions test }
Invoke-Native "Check Functions syntax" { node --check functions/index.js }

if (-not $SkipFlutterChecks) {
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter is not available on PATH. Install Flutter or rerun with -SkipFlutterChecks only after GitHub CI has passed."
  }
  Invoke-Native "Install Flutter dependencies" { flutter pub get }
  Invoke-Native "Analyze Flutter app and tests" {
    flutter analyze --no-fatal-warnings --no-fatal-infos lib test integration_test
  }
  Invoke-Native "Run Flutter tests" { flutter test --reporter expanded }
  Invoke-Native "Build Android debug APK" { flutter build apk --debug }
}

if ($NoDeploy) {
  Write-Host ""
  Write-Host "[OK] Stage C verification passed. Deployment skipped (-NoDeploy)." -ForegroundColor Green
  exit 0
}

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw "Firebase CLI is not available on PATH. Install/login first: npm install -g firebase-tools; firebase login"
}

# A economy contract (15) + account deletion (1) + B rewarded ads (4) + C purchases (3) = 23.
# Deploying the complete shared wallet writer set prevents mixed economy normalizers
# (especially refund-created negative balances) from running at the same time.
$functions = @(
  "getEconomyContract",
  "syncMyWallet",
  "claimAchievementReward",
  "getStoreCatalog",
  "purchaseEconomyOffer",
  "getMyProgression",
  "claimDailyReward",
  "syncRankedMissions",
  "syncDailyMissions",
  "getMyMissions",
  "claimMissionReward",
  "getMySquadChallenge",
  "startSquadChallenge",
  "finishSquadChallenge",
  "abandonSquadChallenge",
  "deleteMyAccount",
  "getRewardedAdStatus",
  "prepareRewardedAd",
  "cancelRewardedAd",
  "admobRewardCallback",
  "getCoinPurchaseCatalog",
  "verifyCoinPurchase",
  "reconcileCoinPurchases"
)

if ($functions.Count -ne 23) {
  throw "Internal deploy target count mismatch: expected 23, got $($functions.Count)."
}

$only = ($functions | ForEach-Object { "functions:$_" }) -join ","

Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Yellow
Write-Host "Targets: $($functions.Count) Firebase Functions" -ForegroundColor Yellow
Write-Host "Coin sales remain controlled by Server Remote Config: linkball_coin_sales_enabled=false" -ForegroundColor Yellow

Invoke-Native "Deploy Stage C Firebase Functions" {
  firebase deploy --project $ProjectId --only $only
}

Write-Host ""
Write-Host "[OK] Stage C server deployment completed." -ForegroundColor Green
Write-Host "Next: configure Play Console products/API/App Check, upload an Internal Testing AAB, then enable linkball_coin_sales_enabled and run the real-device acceptance matrix." -ForegroundColor Green
