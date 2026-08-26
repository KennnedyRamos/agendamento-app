param(
    [switch]$SkipChecks
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$propertiesPath = Join-Path $projectRoot 'android\key.properties'
$firebaseConfigPath = Join-Path $projectRoot 'android\app\google-services.json'

if (-not (Test-Path -LiteralPath $propertiesPath)) {
    throw 'android/key.properties não encontrado. Execute scripts/create_upload_keystore.ps1.'
}
if (-not (Test-Path -LiteralPath $firebaseConfigPath)) {
    throw 'android/app/google-services.json não encontrado. Configure o Firebase antes do release.'
}

Push-Location $projectRoot
try {
    flutter pub get
    if (-not $SkipChecks) {
        dart format --output=none --set-exit-if-changed lib test
        flutter analyze
        flutter test
        npm test --prefix functions
        node --check functions/index.js
        node --check functions/mercado_pago.js
    }

    flutter build apk --release
    flutter build appbundle --release

    $apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
    $bundle = Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'
    Get-Item -LiteralPath $apk, $bundle | Select-Object FullName, Length
    foreach ($artifact in @($apk, $bundle)) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifact).Hash
        Write-Host "SHA-256 $artifact`n$hash"
    }
}
finally {
    Pop-Location
}
