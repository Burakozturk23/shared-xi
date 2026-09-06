$ErrorActionPreference = "Continue"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ReportDir = Join-Path $Root "reports\production\08b25"
$LogcatFile = Join-Path $ReportDir "account_delete_logcat.txt"
$SummaryFile = Join-Path $ReportDir "account_delete_crash_summary.txt"
$FunctionsFile = Join-Path $ReportDir "deleteMyAccount_functions_log.txt"
$FlutterSourceFile = Join-Path $ReportDir "flutter_framework_6268.txt"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
Set-Location $Root

function Write-Summary([string]$Text) {
    $Text | Tee-Object -FilePath $SummaryFile -Append | Out-Host
}

"" | Set-Content $SummaryFile -Encoding UTF8

Write-Summary "=========================================================="
Write-Summary "LINKBALL STEP 08B.2.5 - ACCOUNT DELETE CRASH FORENSICS"
Write-Summary "=========================================================="
Write-Summary ""
Write-Summary "READ-ONLY."
Write-Summary "No account deletion is triggered by this script."
Write-Summary ""

# -----------------------------------------------------------
# Resolve adb.exe
# -----------------------------------------------------------
$Adb = $null

$SavedAdbPath = Join-Path $Root "reports\production\05c\adb_path.txt"
if (Test-Path $SavedAdbPath) {
    $Candidate = (Get-Content $SavedAdbPath -Raw).Trim().Trim('"')
    if ($Candidate -and (Test-Path $Candidate)) {
        $Adb = $Candidate
    }
}

if (-not $Adb) {
    $Cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($Cmd) {
        $Adb = $Cmd.Source
    }
}

if (-not $Adb -and $env:LOCALAPPDATA) {
    $Candidate = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $Candidate) {
        $Adb = $Candidate
    }
}

if ($Adb) {
    Write-Summary ("[PASS] adb: " + $Adb)

    $Devices = & $Adb devices 2>&1
    Write-Summary ""
    Write-Summary "--- adb devices ---"
    foreach ($Line in $Devices) {
        Write-Summary ([string]$Line)
    }
    Write-Summary "--- end adb devices ---"
    Write-Summary ""

    & $Adb logcat -d -v threadtime 2>&1 |
        Set-Content -Path $LogcatFile -Encoding UTF8

    $Raw = Get-Content $LogcatFile -Raw -ErrorAction SilentlyContinue

    if ($Raw) {
        $Needles = @(
            "_dependencies.isEmpty",
            "privacy_account_page.dart",
            "account_deletion_service.dart",
            "FlutterError",
            "E/flutter",
            "framework.dart"
        )

        Write-Summary "FLUTTER / APP ERROR MARKERS:"
        $FoundAny = $false

        foreach ($Needle in $Needles) {
            $Matches = Select-String `
                -Path $LogcatFile `
                -Pattern ([regex]::Escape($Needle)) `
                -Context 12,28 `
                -ErrorAction SilentlyContinue

            if ($Matches) {
                $FoundAny = $true
                Write-Summary ""
                Write-Summary ("--- marker: " + $Needle + " ---")
                foreach ($Match in $Matches | Select-Object -First 3) {
                    foreach ($Line in $Match.Context.PreContext) {
                        Write-Summary ([string]$Line)
                    }
                    Write-Summary ([string]$Match.Line)
                    foreach ($Line in $Match.Context.PostContext) {
                        Write-Summary ([string]$Line)
                    }
                }
                Write-Summary ("--- end marker: " + $Needle + " ---")
            }
        }

        if (-not $FoundAny) {
            Write-Summary "  [WARN] The current logcat buffer no longer contains the crash stack."
        }
    } else {
        Write-Summary "[WARN] logcat dump was empty."
    }
} else {
    Write-Summary "[WARN] adb.exe could not be resolved."
}

# -----------------------------------------------------------
# Resolve exact Flutter framework source / version
# -----------------------------------------------------------
Write-Summary ""
Write-Summary "FLUTTER VERSION / FRAMEWORK SOURCE:"

$FlutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($FlutterCmd) {
    $FlutterPath = $FlutterCmd.Source
    Write-Summary ("[PASS] flutter: " + $FlutterPath)

    $FlutterVersion = & flutter --version 2>&1
    foreach ($Line in $FlutterVersion) {
        Write-Summary ([string]$Line)
    }

    try {
        $BinDir = Split-Path $FlutterPath -Parent
        $FlutterRoot = Split-Path $BinDir -Parent
        $Framework = Join-Path `
            $FlutterRoot `
            "packages\flutter\lib\src\widgets\framework.dart"

        if (Test-Path $Framework) {
            $Lines = Get-Content $Framework
            $Start = 6254
            $End = 6282

            $Out = @()
            for ($i = $Start; $i -le $End; $i++) {
                if ($i -ge 1 -and $i -le $Lines.Count) {
                    $Prefix = if ($i -eq 6268) { ">>" } else { "  " }
                    $Out += ("{0} {1,5}: {2}" -f $Prefix, $i, $Lines[$i - 1])
                }
            }

            $Out | Set-Content -Path $FlutterSourceFile -Encoding UTF8

            Write-Summary ""
            Write-Summary "--- framework.dart around line 6268 ---"
            foreach ($Line in $Out) {
                Write-Summary $Line
            }
            Write-Summary "--- end framework source ---"
        } else {
            Write-Summary "[WARN] framework.dart could not be located from flutter.bat."
        }
    } catch {
        Write-Summary ("[WARN] Flutter source extraction failed: " + $_.Exception.Message)
    }
} else {
    Write-Summary "[WARN] flutter command was not found in PATH."
}

# -----------------------------------------------------------
# Firebase Function execution evidence
# -----------------------------------------------------------
Write-Summary ""
Write-Summary "DELETE FUNCTION SERVER LOG:"

$FirebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
if ($FirebaseCmd) {
    $Project = "sharedix"

    $FnRaw = & firebase functions:log `
        --only deleteMyAccount `
        --project $Project 2>&1

    $FnRaw | Set-Content -Path $FunctionsFile -Encoding UTF8

    if ($LASTEXITCODE -eq 0) {
        $FnText = ($FnRaw | Out-String)

        if ($FnText -match "Linkball account deletion completed") {
            Write-Summary "[PASS] Server log contains: Linkball account deletion completed"
        } elseif ($FnText -match "Linkball account deletion failed") {
            Write-Summary "[FAIL] Server log contains: Linkball account deletion failed"
        } else {
            Write-Summary "[WARN] No explicit Linkball account deletion completion/failure marker found."
        }

        Write-Summary ""
        Write-Summary "--- recent deleteMyAccount log lines ---"
        foreach ($Line in ($FnRaw | Select-Object -Last 80)) {
            Write-Summary ([string]$Line)
        }
        Write-Summary "--- end function log ---"
    } else {
        Write-Summary "[WARN] firebase functions:log command failed."
        foreach ($Line in ($FnRaw | Select-Object -Last 30)) {
            Write-Summary ([string]$Line)
        }
    }
} else {
    Write-Summary "[WARN] Firebase CLI not found."
}

Write-Summary ""
Write-Summary "=========================================================="
Write-Summary "[OK] STEP 08B.2.5 FORENSICS COMPLETE"
Write-Summary "=========================================================="
Write-Summary ""
Write-Summary "Files:"
Write-Summary "  reports\production\08b25\account_delete_crash_summary.txt"
Write-Summary "  reports\production\08b25\account_delete_logcat.txt"
Write-Summary "  reports\production\08b25\deleteMyAccount_functions_log.txt"
Write-Summary "  reports\production\08b25\flutter_framework_6268.txt"
Write-Summary ""
Write-Summary "Do NOT create/delete another test account yet."
