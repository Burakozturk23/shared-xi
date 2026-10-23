# Run from the reviewed checkout. Firebase CLI must already be installed and signed in.
param([switch]$CheckOnly, [switch]$EnableOnlineModes)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
  if ($CheckOnly) {
    node scripts/check-online-services.js
    if ($LASTEXITCODE -ne 0) { throw 'Some online endpoints are missing or unverified.' }
    return
  }
  npm --prefix functions ci
  if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
  npm --prefix functions run lint
  if ($LASTEXITCODE -ne 0) { throw 'Functions lint failed.' }
  npm --prefix functions test
  if ($LASTEXITCODE -ne 0) { throw 'Functions tests failed. Deployment stopped.' }
  $targets = node scripts/check-online-services.js --deploy-targets
  if ($LASTEXITCODE -ne 0) { throw 'Could not build the online deployment list.' }
  $items = $targets.Split(',')
  for ($index = 0; $index -lt $items.Count; $index += 4) {
    $last = [Math]::Min($index + 3, $items.Count - 1)
    $batch = $items[$index..$last] -join ','
    firebase deploy --only $batch --project sharedix --non-interactive
    if ($LASTEXITCODE -ne 0) { throw 'Deployment failed. No runtime flags were changed.' }
  }
  node scripts/check-online-services.js
  if ($LASTEXITCODE -ne 0) { throw 'Endpoint verification failed. No runtime flags were changed.' }
  if ($EnableOnlineModes) {
    # Patch the mode entry gates only. Preserve rewards, energy, per-mode overrides,
    # disabled data and the managerRankedVerified acceptance gate.
    $policies = @{
      pvp = '{"friendEnabled":true,"rankedEnabled":true}'
      fakeClub = '{"dataEnabled":true,"friendsEnabled":true,"rankedEnabled":true}'
    }
    foreach ($name in $policies.Keys) {
      $temporaryPolicy = New-TemporaryFile
      try {
        [System.IO.File]::WriteAllText($temporaryPolicy.FullName, $policies[$name])
        firebase database:update "/runtimeConfig/$name" $temporaryPolicy.FullName --project sharedix --force
        if ($LASTEXITCODE -ne 0) { throw "Could not enable $name. Earlier patches remain applied; rerunning is safe." }
      } finally { Remove-Item $temporaryPolicy.FullName -ErrorAction SilentlyContinue }
    }
  }
  Write-Host 'Online functions deployed. Verify all 13 modes with two linked accounts. Manager ranked still requires its acceptance gate.'
} finally { Pop-Location }
