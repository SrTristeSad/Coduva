# Execute na pasta raiz do Coduva (Windows PowerShell).
# Requer Flutter >= 3.38 e Android SDK configurados.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$android = Join-Path $root 'android'
if (Test-Path $android) {
    Write-Host 'Android ja foi preparado. Nada sera sobrescrito.'
    exit 0
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter nao encontrado no PATH. Instale o Flutter SDK antes.'
}
$temp = Join-Path $env:TEMP ('coduva-scaffold-' + [guid]::NewGuid().ToString('N'))
try {
    flutter create --empty --platforms=android --project-name=coduva --org=dev.coduva $temp
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar scaffold Android.' }
    Copy-Item (Join-Path $temp 'android') $android -Recurse
    $manifest = Join-Path $android 'app/src/main/AndroidManifest.xml'
    $raw = [System.IO.File]::ReadAllText($manifest)
    $raw = $raw.Replace('<application', '<application android:networkSecurityConfig="@xml/coduva_network_security"')
    if (-not $raw.Contains('android.permission.INTERNET')) {
        $raw = $raw.Replace('<application', '<uses-permission android:name="android.permission.INTERNET" />' + [Environment]::NewLine + '    <application')
    }
    [System.IO.File]::WriteAllText($manifest, $raw)
    $xmlFolder = Join-Path $android 'app/src/main/res/xml'
    New-Item -ItemType Directory -Path $xmlFolder -Force | Out-Null
    @'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
'@ | Set-Content -Path (Join-Path $xmlFolder 'coduva_network_security.xml') -Encoding UTF8
    Write-Host 'Android preparado com INTERNET e acesso HTTP somente a localhost.'
    Set-Location $root
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Falha no flutter pub get.' }
    Write-Host 'Proximo passo: flutter run'
} finally {
    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
}
