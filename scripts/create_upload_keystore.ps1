param(
    [string]$Alias = 'barberkr-upload'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDirectory = Join-Path $projectRoot 'android'
$keystorePath = Join-Path $androidDirectory 'upload-keystore.jks'
$propertiesPath = Join-Path $androidDirectory 'key.properties'

if ((Test-Path -LiteralPath $keystorePath) -or
    (Test-Path -LiteralPath $propertiesPath)) {
    throw 'A chave de upload já existe. Nada foi sobrescrito.'
}

$keytool = (Get-Command keytool -ErrorAction Stop).Source
$random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$passwordBytes = New-Object byte[] 32
$random.GetBytes($passwordBytes)
$random.Dispose()
$password = [Convert]::ToBase64String($passwordBytes).Replace('+', 'A').Replace('/', 'B').TrimEnd('=')

& $keytool -genkeypair `
    -v `
    -keystore $keystorePath `
    -storetype JKS `
    -storepass $password `
    -keypass $password `
    -alias $Alias `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -dname 'CN=BarberKR Upload, O=Kennedy Ramos, C=BR'

if ($LASTEXITCODE -ne 0) {
    throw 'O keytool não conseguiu gerar a chave de upload.'
}

$properties = @(
    "storePassword=$password"
    "keyPassword=$password"
    "keyAlias=$Alias"
    'storeFile=../upload-keystore.jks'
) -join [Environment]::NewLine
[System.IO.File]::WriteAllText($propertiesPath, $properties)

Write-Host 'Chave de upload criada com sucesso.'
Write-Host "Keystore: $keystorePath"
Write-Host "Configuração: $propertiesPath"
Write-Host 'Faça backup seguro dos dois arquivos. As senhas não serão exibidas.'
