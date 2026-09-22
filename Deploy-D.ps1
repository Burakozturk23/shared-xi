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
  "functions/rewarded_ads.js",
  "functions/coin_purchases.js",
  "lib/services/premium_service.dart",
  "lib/services/premium_billing_service.dart",
  "lib/screens/premium_page.dart",
  "lib/screens/player_profile_page.dart",
  "docs/design/monetization-d.md"
)
foreach ($file in $required) {
  if (-not (Test-Path (Join-Path $repo $file))) {
    throw "Stage D file is missing: $file"
  }
}

$index = Get-Content (Join-Path $repo "functions/index.js") -Raw
foreach ($marker in @(
  "linkball_pro_monthly",
  "linkball_pro_yearly",
  "exports.getMyPremiumStatus",
  "exports.verifyPremiumPurchase",
  "exports.reconcilePremiumSubscriptions",
  "lbPlayAccountId(uid)",
  "lbPlayAcknowledgeSubscription",
  ":acknowledge",
  "linkball_pro_sales_enabled"
)) {
  if (-not $index.Contains($marker)) {
    throw "Stage D marker is missing from functions/index.js: $marker"
  }
}

Invoke-Native "Install Functions dependencies" { npm --prefix functions ci }
Invoke-Native "Lint Functions" { npm --prefix functions run lint }
Invoke-Native "Run Functions tests" { npm --prefix functions test }
Invoke-Native "Check Functions syntax" { node --check functions/index.js }

if (-not $SkipFlutterChecks) {
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter is not available on PATH. Install Flutter or use -SkipFlutterChecks only after GitHub CI has passed."
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
  Write-Host "[OK] Stage D verification passed. Deployment skipped (-NoDeploy)." -ForegroundColor Green
  exit 0
}

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  throw "Firebase CLI is not available on PATH. Install/login first: npm install -g firebase-tools; firebase login"
}

# C's 23 shared economy/rewarded/purchase functions plus three Linkball Pro
# functions. Deploying the shared writers together prevents old premium
# normalizers from reintroducing reward multipliers or stale lifecycle state.
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
  "reconcileCoinPurchases",
  "getMyPremiumStatus",
  "verifyPremiumPurchase",
  "reconcilePremiumSubscriptions"
)

if ($functions.Count -ne 26) {
  throw "Internal deploy target count mismatch: expected 26, got $($functions.Count)."
}

$only = ($functions | ForEach-Object { "functions:$_" }) -join ","

Write-Host ""
Write-Host "Project: $ProjectId" -ForegroundColor Yellow
Write-Host "Targets: $($functions.Count) Firebase Functions" -ForegroundColor Yellow
Write-Host "New Pro sales remain OFF until Server Remote Config linkball_pro_sales_enabled=true." -ForegroundColor Yellow

Invoke-Native "Deploy Stage D Firebase Functions" {
  firebase deploy --project $ProjectId --only $only
}

Write-Host ""
Write-Host "[OK] Stage D server deployment completed." -ForegroundColor Green
Write-Host "Play Console setup can remain deferred. Keep linkball_pro_sales_enabled=false until monthly/yearly subscriptions, API access, App Check and Internal Testing are ready." -ForegroundColor Green
