$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ReportDir = Join-Path $Root "reports\production\07b4"
$Log = Join-Path $ReportDir "remote_ci_verify.txt"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

Set-Location $Root

function Log([string]$Text) {
    $Text | Tee-Object -FilePath $Log -Append | Out-Host
}

"LINKBALL STEP 07B.4 - REMOTE CI VERIFY" | Set-Content -Path $Log -Encoding UTF8
Log ""
Log ("Started: " + (Get-Date))
Log ""

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) not found."
}

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated."
}

$Branch = (& git branch --show-current).Trim()
if (-not $Branch) {
    throw "Current Git branch could not be resolved."
}

Log ("Branch: " + $Branch)

$Head = (& git rev-parse HEAD).Trim()
if (-not $Head) {
    throw "Current Git HEAD could not be resolved."
}
Log ("Local HEAD: " + $Head)
Log ""

# Find the latest run for this exact branch.
$RunsJson = & gh run list `
    --workflow "Linkball CI" `
    --branch $Branch `
    --limit 10 `
    --json databaseId,headSha,status,conclusion,displayTitle,url,createdAt

if ($LASTEXITCODE -ne 0) {
    throw "Could not list Linkball CI runs."
}

$Runs = $RunsJson | ConvertFrom-Json
if (-not $Runs) {
    throw "No Linkball CI run found for branch $Branch."
}

$Run = $Runs | Where-Object { $_.headSha -eq $Head } | Select-Object -First 1

if (-not $Run) {
    Log "[WARN] No run found for the exact local HEAD yet."
    Log "[INFO] Waiting up to 90 seconds for GitHub Actions to register the push..."

    for ($i = 0; $i -lt 9; $i++) {
        Start-Sleep -Seconds 10

        $RunsJson = & gh run list `
            --workflow "Linkball CI" `
            --branch $Branch `
            --limit 10 `
            --json databaseId,headSha,status,conclusion,displayTitle,url,createdAt

        $Runs = $RunsJson | ConvertFrom-Json
        $Run = $Runs | Where-Object { $_.headSha -eq $Head } | Select-Object -First 1

        if ($Run) {
            break
        }
    }
}

if (-not $Run) {
    Log "[STOP] No Linkball CI run found for the current local HEAD."
    Log "Make sure STEP 07B.3.4.10 actually pushed the current branch."
    exit 3
}

$RunId = [string]$Run.databaseId
Log ("Run ID: " + $RunId)
Log ("Run URL: " + $Run.url)
Log ("Initial status: " + $Run.status)
Log ""

if ($Run.status -ne "completed") {
    Log "[RUN] Waiting for GitHub Actions run to complete..."
    & gh run watch $RunId --exit-status
    $WatchRc = $LASTEXITCODE

    # Even if watch returns failure due failed job, continue to collect details.
    Log ("gh run watch exit code: " + $WatchRc)
    Log ""
}

$RunJson = & gh run view $RunId `
    --json status,conclusion,headSha,url,jobs

if ($LASTEXITCODE -ne 0) {
    throw "Could not read final Linkball CI run."
}

$Final = $RunJson | ConvertFrom-Json

Log ("Final status: " + $Final.status)
Log ("Final conclusion: " + $Final.conclusion)
Log ""

$ExpectedJobs = @(
    "Flutter quality gate",
    "Firebase Functions quality gate",
    "Android integration smoke",
    "Signed release AAB"
)

$Failed = @()
$Missing = @()

Log "JOBS:"
foreach ($Expected in $ExpectedJobs) {
    $Job = $Final.jobs | Where-Object { $_.name -eq $Expected } | Select-Object -First 1

    if (-not $Job) {
        Log ("  [MISS] " + $Expected)
        $Missing += $Expected
        continue
    }

    $Conclusion = [string]$Job.conclusion
    Log ("  [" + $Conclusion.ToUpper() + "] " + $Expected)

    if ($Conclusion -ne "success") {
        $Failed += $Expected
    }
}

Log ""

$ArtifactsJson = & gh api `
    ("repos/{owner}/{repo}/actions/runs/" + $RunId + "/artifacts") 2>$null

$AabArtifactFound = $false

if ($LASTEXITCODE -eq 0 -and $ArtifactsJson) {
    $Artifacts = ($ArtifactsJson | ConvertFrom-Json).artifacts
    foreach ($Artifact in $Artifacts) {
        if ($Artifact.name -eq "linkball-release-aab" -and -not $Artifact.expired) {
            $AabArtifactFound = $true
            Log ("[PASS] AAB artifact exists: " + $Artifact.name)
            break
        }
    }
}

if (-not $AabArtifactFound) {
    Log "[FAIL] linkball-release-aab artifact was not found."
}

Log ""

$Ok = (
    $Final.status -eq "completed" -and
    $Final.conclusion -eq "success" -and
    $Failed.Count -eq 0 -and
    $Missing.Count -eq 0 -and
    $AabArtifactFound
)

if (-not $Ok) {
    Log "=========================================================="
    Log "[STOP] STEP 07B.4 REMOTE CI NOT FULLY PASSING"
    Log "=========================================================="
    Log ""
    Log "Open the Run URL above."
    Log "Send the first failing job's first real error block."
    exit 2
}

Log "=========================================================="
Log "[OK] STEP 07B.4 REMOTE CI PASS"
Log "=========================================================="
Log ""
Log "All required jobs passed and signed AAB artifact exists."
Log ""
Log "Next:"
Log "  run_step07b1_ci_test_audit.bat"
