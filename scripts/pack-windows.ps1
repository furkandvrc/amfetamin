# Package amfetamin-windows.zip for release (run on Windows)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$win = Join-Path $root 'windows'
$staging = Join-Path $root 'dist\amfetamin-windows-staging'
$zip = Join-Path $root 'dist\amfetamin-windows.zip'
$buildPs1 = Join-Path $win 'build.ps1'

Write-Host '=== amfetamin Windows release pack ==='

if (-not (Test-Path $buildPs1)) { throw 'windows/build.ps1 not found' }
Write-Host 'Building Amfetamin.exe...'
& $buildPs1

if (-not (Test-Path (Join-Path $win 'Amfetamin.exe'))) {
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
    $src = if ($name -in @('LICENSE', 'README.md')) {
        Join-Path $root $name
    } else {
        Join-Path $win $name
    }
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $staging $name) -Force
    }
}

$libSrc = Join-Path $win 'lib'
$libDst = Join-Path $staging 'lib'
New-Item -ItemType Directory -Force -Path $libDst | Out-Null
Get-ChildItem $libSrc -File | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $libDst $_.Name) -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $root 'dist') | Out-Null
Compress-Archive -Path "$staging\*" -DestinationPath $zip -Force
Remove-Item $staging -Recurse -Force
Write-Host "Release ready: $zip ($((Get-Item $zip).Length) bytes)"
