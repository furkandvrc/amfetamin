# amfetamin — DPI bypass launcher
# by furkan divarcı
. (Join-Path $PSScriptRoot 'lib\AmfetaminCore.ps1')
. (Join-Path $PSScriptRoot 'lib\AmfetaminUI.ps1')

if (-not (Test-IsAdmin)) {
    if (-not (Request-Admin)) { exit }
    exit
}

Show-AmfetaminSplash
Show-AmfetaminMainForm
