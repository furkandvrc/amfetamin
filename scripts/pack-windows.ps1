# Package amfetamin-windows.zip for release (run on Windows)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$staging = Join-Path $root 'dist\amfetamin-windows-staging'
$zip = Join-Path $root 'dist\amfetamin-windows.zip'
$buildPs1 = Join-Path $root 'build.ps1'

Write-Host '=== amfetamin Windows release pack ==='

if (-not (Test-Path (Join-Path $root 'Amfetamin.exe'))) {
    if (-not (Test-Path $buildPs1)) { throw 'build.ps1 not found' }
    Write-Host 'Amfetamin.exe missing, building...'
    & $buildPs1
}

if (-not (Test-Path (Join-Path $root 'Amfetamin.exe'))) {
    throw 'Amfetamin.exe build failed'
}

Remove-Item $staging, $zip -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $staging | Out-Null

$items = @(
    'Amfetamin.exe',
    'amfetamin.ico',
    'config.json',
    'diagnose.ps1',
    'diagnose.bat',
    'LICENSE',
    'README.md'
)
foreach ($name in $items) {
    $src = Join-Path $root $name
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $staging $name) -Force
    }
}

$libSrc = Join-Path $root 'lib'
$libDst = Join-Path $staging 'lib'
New-Item -ItemType Directory -Force -Path $libDst | Out-Null
Get-ChildItem $libSrc -File | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $libDst $_.Name) -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $root 'dist') | Out-Null
Compress-Archive -Path "$staging\*" -DestinationPath $zip -Force
Remove-Item $staging -Recurse -Force
Write-Host "Release ready: $zip ($((Get-Item $zip).Length) bytes)"
