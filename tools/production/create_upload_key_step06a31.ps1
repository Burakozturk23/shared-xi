$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Android = Join-Path $Root "android"
$Keystore = Join-Path $Android "upload-keystore.jks"
$KeyProperties = Join-Path $Android "key.properties"
$ReportDir = Join-Path $Root "reports\production\06a"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

function Add-Candidate([System.Collections.Generic.List[string]]$List, [string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
    } catch {
        $full = $Path
    }
    if (-not $List.Contains($full)) {
        $List.Add($full)
    }
}

function Find-Keytool {
    $candidates = New-Object 'System.Collections.Generic.List[string]'

    # 1) PATH
    $cmd = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        Add-Candidate $candidates $cmd.Source
    }

    $cmd2 = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd2 -and $cmd2.Source) {
        Add-Candidate $candidates $cmd2.Source
    }

    # 2) JAVA_HOME
    if ($env:JAVA_HOME) {
        Add-Candidate $candidates (Join-Path $env:JAVA_HOME "bin\keytool.exe")
    }

    # 3) Java resolved from PATH -> sibling keytool
    try {
        $whereJava = & where.exe java.exe 2>$null
        foreach ($javaPath in $whereJava) {
            if ([string]::IsNullOrWhiteSpace($javaPath)) { continue }
            $javaDir = Split-Path $javaPath -Parent
            Add-Candidate $candidates (Join-Path $javaDir "keytool.exe")
        }
    } catch {}

    # 4) Flutter's selected Java (often Android Studio JBR)
    try {
        $doctor = & flutter doctor -v 2>&1
        foreach ($line in $doctor) {
            $s = [string]$line

            # Typical:
            # Java binary at: C:\Program Files\Android\Android Studio\jbr\bin\java
            if ($s -match 'Java binary at:\s*(.+?)(?:\s*$)') {
                $javaBinary = $Matches[1].Trim().Trim('"')
                if (Test-Path $javaBinary) {
                    $javaDir = Split-Path $javaBinary -Parent
                    Add-Candidate $candidates (Join-Path $javaDir "keytool.exe")
                }
            }

            # Some Flutter versions report:
            # Java version OpenJDK ... at C:\...\jbr
            if ($s -match '\bat\s+([A-Za-z]:\\.+?\\jbr)\s*$') {
                $jbr = $Matches[1].Trim().Trim('"')
                Add-Candidate $candidates (Join-Path $jbr "bin\keytool.exe")
            }
        }
    } catch {}

    # 5) Common Android Studio locations
    if ($env:ProgramFiles) {
        Add-Candidate $candidates (
            Join-Path $env:ProgramFiles "Android\Android Studio\jbr\bin\keytool.exe"
        )
        Add-Candidate $candidates (
            Join-Path $env:ProgramFiles "Android\Android Studio\jre\bin\keytool.exe"
        )
    }

    if (${env:ProgramFiles(x86)}) {
        Add-Candidate $candidates (
            Join-Path ${env:ProgramFiles(x86)} "Android\Android Studio\jbr\bin\keytool.exe"
        )
    }

    if ($env:LOCALAPPDATA) {
        Add-Candidate $candidates (
            Join-Path $env:LOCALAPPDATA "Programs\Android Studio\jbr\bin\keytool.exe"
        )
        Add-Candidate $candidates (
            Join-Path $env:LOCALAPPDATA "Android\Android Studio\jbr\bin\keytool.exe"
        )
    }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

$keytoolPath = Find-Keytool

if (-not $keytoolPath) {
    Write-Host ""
    Write-Host "[FAIL] keytool otomatik bulunamadi." -ForegroundColor Red
    Write-Host ""
    Write-Host "Android Studio aciliyorsa genellikle JBR vardir." -ForegroundColor Yellow
    Write-Host "Android Studio > Settings > Build, Execution, Deployment > Build Tools > Gradle" -ForegroundColor Yellow
    Write-Host "ekranindaki Gradle JDK yolunu kontrol et." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Ornek keytool yolu:" -ForegroundColor Yellow
    Write-Host "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    throw "keytool bulunamadi."
}

Write-Host "[PASS] keytool bulundu:" -ForegroundColor Green
Write-Host "  $keytoolPath"
Write-Host ""

if (-not (Test-Path $Keystore)) {
    Write-Host "Yeni Linkball upload keystore olusturulacak." -ForegroundColor Cyan
    Write-Host "Store password belirle." -ForegroundColor Yellow
    Write-Host "Key password sorusunda ENTER'a bas; store password ile ayni olsun." -ForegroundColor Yellow
    Write-Host "Bu sifreyi kaybetme ve kimseyle paylasma." -ForegroundColor Yellow
    Write-Host ""

    & $keytoolPath -genkeypair -v `
        -keystore $Keystore `
        -storetype JKS `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -alias upload `
        -dname "CN=Linkball Upload, OU=Mobile, O=Linkball, L=Istanbul, ST=Istanbul, C=TR"

    if ($LASTEXITCODE -ne 0) {
        throw "keytool keystore olusturamadi."
    }
} else {
    Write-Host "[PASS] upload-keystore.jks zaten mevcut; tekrar olusturulmadi." -ForegroundColor Green
}

Write-Host ""
Write-Host "Keystore STORE password'unu tekrar gir." -ForegroundColor Cyan
$secure1 = Read-Host "Store password" -AsSecureString
$secure2 = Read-Host "Store password tekrar" -AsSecureString

function SecureToPlain([Security.SecureString]$secure) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$pass1 = SecureToPlain $secure1
$pass2 = SecureToPlain $secure2

if ($pass1 -ne $pass2) {
    throw "Password'ler ayni degil. key.properties yazilmadi."
}
if ([string]::IsNullOrWhiteSpace($pass1)) {
    throw "Bos password kullanilamaz."
}

# Verify actual keystore password and alias before writing secrets file.
& $keytoolPath -list `
    -keystore $Keystore `
    -storepass $pass1 `
    -alias upload | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Keystore password veya upload alias dogrulanamadi."
}

$content = @"
storePassword=$pass1
keyPassword=$pass1
keyAlias=upload
storeFile=../upload-keystore.jks
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($KeyProperties, $content, $utf8NoBom)

# Non-secret certificate fingerprints for the next App Check step.
$fingerprintOut = & $keytoolPath -list -v `
    -keystore $Keystore `
    -storepass $pass1 `
    -alias upload

$fingerprintPath = Join-Path $ReportDir "upload_key_fingerprints.txt"
[System.IO.File]::WriteAllLines(
    $fingerprintPath,
    $fingerprintOut,
    $utf8NoBom
)

# Record only the detected JDK/keytool path; no passwords.
$keytoolReport = Join-Path $ReportDir "detected_keytool.txt"
[System.IO.File]::WriteAllText(
    $keytoolReport,
    $keytoolPath,
    $utf8NoBom
)

$pass1 = $null
$pass2 = $null

Write-Host ""
Write-Host "[OK] android\upload-keystore.jks" -ForegroundColor Green
Write-Host "[OK] android\key.properties" -ForegroundColor Green
Write-Host "[OK] reports\production\06a\upload_key_fingerprints.txt" -ForegroundColor Green
Write-Host "[OK] reports\production\06a\detected_keytool.txt" -ForegroundColor Green
Write-Host ""
Write-Host "[IMPORTANT] Keystore + password'u iki guvenli offline yerde yedekle." -ForegroundColor Yellow
Write-Host "[IMPORTANT] Keystore/password'u ChatGPT veya GitHub'a gonderme." -ForegroundColor Yellow
