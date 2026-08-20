# amfetamin — DPI bypass launcher
# by furkandvrc
$ErrorActionPreference = 'Stop'

if ($PSScriptRoot) {
    $env:AMFETAMIN_ROOT = $PSScriptRoot
    $Script:AmfetaminProjectRoot = $PSScriptRoot
}

try {
    . (Join-Path $PSScriptRoot 'lib\AmfetaminEncoding.ps1')
    . (Get-AmfetaminUtf8ScriptBlock (Join-Path $PSScriptRoot 'lib\AmfetaminCore.ps1'))
    . (Get-AmfetaminUtf8ScriptBlock (Join-Path $PSScriptRoot 'lib\AmfetaminUI.ps1'))
    Initialize-AmfetaminI18n

    Write-AmfetaminLog -Message 'amfetamin baslatildi' -Level INFO -Audit

    if (-not (Test-IsAdmin)) {
        Write-AmfetaminLog -Message 'Yonetici degil — elevation isteniyor' -Level WARN
        Request-Admin | Out-Null
        exit 0
    }

    try {
        Ensure-Dirs
        Repair-DeviceConfig | Out-Null
        Import-SyncedLauncherCore | Out-Null
    } catch {}

    $mutexName = 'Global\Amfetamin.furkandvrc.SingleInstance'
    $mutex = New-Object System.Threading.Mutex($false, $mutexName)
    $ownsMutex = $false
    try {
        $ownsMutex = $mutex.WaitOne(0, $false)
    } catch {
        $ownsMutex = $true
    }
    if (-not $ownsMutex) {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show(
            (T 'msg_app_already_open'),
            (T 'app_name'),
            'OK',
            'Information')
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
