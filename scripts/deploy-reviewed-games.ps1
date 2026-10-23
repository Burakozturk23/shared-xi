# Run from the repository after checking out the reviewed branch and passing CI.
# Firebase CLI must already be installed and signed in. No API-Football key needed.
param([switch]$CheckOnly, [switch]$EnableSoloGames)
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
  if ($CheckOnly) {
    node scripts/check-game-services.js
    if ($LASTEXITCODE -ne 0) { throw 'Some game endpoints are missing or could not be verified.' }
    return
  }
  npm --prefix functions ci
  if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }
  npm --prefix functions run lint
  if ($LASTEXITCODE -ne 0) { throw 'Functions lint failed.' }
  npm --prefix functions test
  if ($LASTEXITCODE -ne 0) { throw 'Functions tests failed. Deployment stopped.' }
  $targets = node scripts/check-game-services.js --deploy-targets
  if ($LASTEXITCODE -ne 0) { throw 'Could not build the reviewed deployment list.' }
  # Small sequential groups avoid a burst of function-creation requests.
  $items = $targets.Split(',')
  for ($index = 0; $index -lt $items.Count; $index += 5) {
    $last = [Math]::Min($index + 4, $items.Count - 1)
    $batch = $items[$index..$last] -join ','
    firebase deploy --only $batch --project sharedix --non-interactive
    if ($LASTEXITCODE -ne 0) { throw 'Function deployment failed. No runtime flags were changed.' }
  }
  node scripts/check-game-services.js
  if ($LASTEXITCODE -ne 0) { throw 'Endpoint verification failed. No runtime flags were changed.' }
  if ($EnableSoloGames) {
    # Patch only playability flags; retain rewards, disabled content, energy and online policies.
    $policies = @{
      fakeClub = '{"dataEnabled":true,"soloEnabled":true}'
      dailyWords = '{"enabled":true}'
      arcade = '{"enabled":true}'
      choice = '{"enabled":true}'
    }
    foreach ($name in $policies.Keys) {
      $temporaryPolicy = New-TemporaryFile
      try {
        [System.IO.File]::WriteAllText($temporaryPolicy.FullName, $policies[$name])
        firebase database:update "/runtimeConfig/$name" $temporaryPolicy.FullName --project sharedix --force
        if ($LASTEXITCODE -ne 0) { throw "Could not enable $name. Earlier successful patches remain applied; rerunning is safe." }
      } finally { Remove-Item $temporaryPolicy.FullName -ErrorAction SilentlyContinue }
    }
  }
  Write-Host 'Deployment verified. Test each mode in the updated app. Statistical source gates and reward settings remain in force.'
} finally { Pop-Location }
