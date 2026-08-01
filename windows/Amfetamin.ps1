# amfetamin — DPI bypass launcher
# by furkandvrc
$ErrorActionPreference = 'Stop'

try {
    . (Join-Path $PSScriptRoot 'lib\AmfetaminCore.ps1')
    . (Join-Path $PSScriptRoot 'lib\AmfetaminUI.ps1')
    Initialize-AmfetaminI18n

    Write-AmfetaminLog -Message 'amfetamin baslatildi' -Level INFO -Audit

    if (-not (Test-IsAdmin)) {
        Write-AmfetaminLog -Message 'Yonetici degil — elevation isteniyor' -Level WARN
        Request-Admin | Out-Null
        exit 0
    }

    Show-AmfetaminSplash
    Show-AmfetaminMainForm
} catch {
    Write-AmfetaminError -Message 'Kritik baslatma hatasi' -Exception $_.Exception
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, (T 'app_name'), 'OK', 'Error')
    } catch {
        Write-Host $_.Exception.Message
        Read-Host (T 'prompt_press_enter')
    }
    exit 1
}
