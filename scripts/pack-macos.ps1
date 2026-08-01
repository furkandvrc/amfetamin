# Package amfetamin-macos.zip with LF line endings for shell scripts
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'macos'
$staging = Join-Path $root 'dist\amfetamin-macos-staging'
$zip = Join-Path $root 'dist\amfetamin-macos.zip'

$shellPatterns = @('*.sh', 'amfetamin', 'diagnose.sh')

function Write-LfFile([string]$sourcePath, [string]$destPath) {
    $bytes = [System.IO.File]::ReadAllBytes($sourcePath)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $text = $text -replace "`r`n", "`n" -replace "`r", "`n"
    $dir = Split-Path $destPath -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($destPath, $text, [System.Text.UTF8Encoding]::new($false))
}

function Copy-Tree([string]$from, [string]$to) {
    Get-ChildItem -Path $from -Force | ForEach-Object {
        $target = Join-Path $to $_.Name
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
            Copy-Tree $_.FullName $target
        } else {
            $isShell = $false
            foreach ($pat in $shellPatterns) {
                if ($_.Name -like $pat) { $isShell = $true; break }
            }
            if ($isShell) { Write-LfFile $_.FullName $target }
            else { Copy-Item $_.FullName $target -Force }
        }
    }
}

Remove-Item $staging, $zip -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $staging | Out-Null
Copy-Tree $src $staging
Compress-Archive -Path "$staging\*" -DestinationPath $zip -Force
Remove-Item $staging -Recurse -Force
Write-Host "Created: $zip ($((Get-Item $zip).Length) bytes)"
