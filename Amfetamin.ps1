# amfetamin — DPI bypass launcher
# by furkan divarcı
$ErrorActionPreference = 'Stop'

try {
    . (Join-Path $PSScriptRoot 'lib\AmfetaminCore.ps1')
    . (Join-Path $PSScriptRoot 'lib\AmfetaminUI.ps1')

    if (-not (Test-IsAdmin)) {
        Request-Admin | Out-Null
        exit 0
    }

    Show-AmfetaminSplash
    Show-AmfetaminMainForm
} catch {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'amfetamin', 'OK', 'Error')
    } catch {
        Write-Host $_.Exception.Message
        Read-Host 'Devam etmek icin Enter'
    }
    exit 1
}
