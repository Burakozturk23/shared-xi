$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Android = Join-Path $Root "android"
$Keystore = Join-Path $Android "upload-keystore.jks"
$KeyProperties = Join-Path $Android "key.properties"
$ReportDir = Join-Path $Root "reports\production\06a"
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool -and $env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    if (Test-Path $candidate) { $keytool = $candidate }
}
if (-not $keytool) {
    throw "keytool bulunamadi. JDK/JAVA_HOME kontrol et."
}

if (-not (Test-Path $Keystore)) {
    Write-Host ""
    Write-Host "Yeni Linkball upload keystore olusturulacak." -ForegroundColor Cyan
    Write-Host "Key password sorusunda ENTER'a bas; store password ile ayni olsun." -ForegroundColor Yellow
    Write-Host "Bu sifreyi kaybetme ve kimseyle paylasma." -ForegroundColor Yellow
    Write-Host ""

    & $keytool -genkeypair -v `
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
    Write-Host "[PASS] upload-keystore.jks zaten mevcut."
}

Write-Host ""
Write-Host "Keystore STORE password'unu tekrar gir." -ForegroundColor Cyan
$secure1 = Read-Host "Store password" -AsSecureString
$secure2 = Read-Host "Store password tekrar" -AsSecureString

function SecureToPlain([Security.SecureString]$secure) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$pass1 = SecureToPlain $secure1
$pass2 = SecureToPlain $secure2

if ($pass1 -ne $pass2) { throw "Password'ler ayni degil." }
if ([string]::IsNullOrWhiteSpace($pass1)) { throw "Bos password kullanilamaz." }

& $keytool -list -keystore $Keystore -storepass $pass1 -alias upload | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Keystore password/alias dogrulanamadi." }

$content = @"
storePassword=$pass1
keyPassword=$pass1
keyAlias=upload
storeFile=../upload-keystore.jks
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($KeyProperties, $content, $utf8NoBom)

$fingerprintOut = & $keytool -list -v -keystore $Keystore -storepass $pass1 -alias upload
$fingerprintPath = Join-Path $ReportDir "upload_key_fingerprints.txt"
[System.IO.File]::WriteAllLines($fingerprintPath, $fingerprintOut, $utf8NoBom)

$pass1 = $null
$pass2 = $null

Write-Host ""
Write-Host "[OK] android\upload-keystore.jks" -ForegroundColor Green
Write-Host "[OK] android\key.properties" -ForegroundColor Green
Write-Host "[OK] upload_key_fingerprints.txt" -ForegroundColor Green
Write-Host "[IMPORTANT] Keystore + password'u offline yedekle." -ForegroundColor Yellow
