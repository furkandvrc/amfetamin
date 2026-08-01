# UI smoke test — mocks core, opens main form without admin/splash
$ErrorActionPreference = 'Stop'
$env:AMFETAMIN_LANG = 'tr'
$env:AMFETAMIN_UI_TEST = '1'
$env:AMFETAMIN_ROOT = $PSScriptRoot
$Script:AmfetaminProjectRoot = $PSScriptRoot

. (Join-Path $PSScriptRoot 'lib\AmfetaminEncoding.ps1')
. (Get-AmfetaminUtf8ScriptBlock (Join-Path $PSScriptRoot 'lib\AmfetaminLogger.ps1'))
. (Get-AmfetaminUtf8ScriptBlock (Join-Path $PSScriptRoot 'lib\AmfetaminI18n.ps1'))
Initialize-AmfetaminI18n

function Get-LauncherPath { Join-Path $PSScriptRoot 'Amfetamin.ps1' }
function Get-ProjectRoot { $PSScriptRoot }
function Sync-LauncherToDevice {}
function Get-Config {
    @{
        version = '3.1.4'
        dohUpstream = 'cloudflare'
        fakeTtl = 8
        autoTuneTtl = $true
        warmup = $true
        engineVerbose = $false
        autoTuneDone = $false
    }
}
function Get-AmfetaminStatus {
    [PSCustomObject]@{
        NpcapInstalled = $true
        EngineDownloaded = $true
        EngineRunning = $false
        AutoStartInstalled = $true
        InstallRoot = 'C:\Users\Test\AppData\Local\Amfetamin'
        FakeTtl = 8
        AutoTuneDone = $false
        Version = '3.1.4'
        Process = $null
        ZeroTierRunning = $false
    }
}
function Test-BypassTargetReachable { $false }
function Get-AmfetaminLogTail { param($LogName, $Lines) @('[INFO] test log line 1', '[INFO] test log line 2') }
function Install-ToDevice { 'Mock kurulum tamam' }
function Install-And-Start { 'Mock baslatildi' }
function Stop-Amfetamin { 'Mock durduruldu' }
function Install-NpcapGui { 'Mock npcap' }
function Invoke-AmfetaminCleanup { 'Mock cleanup' }
function Test-AmfetaminConnectivity { @([PSCustomObject]@{ Url='https://discord.com'; Ok=$true; StatusCode=200; Ms=42 }) }
function Invoke-ManualTtlRetune { param($Progress) & $Progress 'Mock TTL'; 'Mock TTL OK' }
function Export-AmfetaminLogs { Join-Path $env:TEMP 'amfetamin-logs.zip' }
function Clear-AmfetaminLogs {}
function Save-AmfetaminSettings { (T 'msg_settings_saved') }
function Get-AmfetaminDiagnosticReport { param($Quiet) "=== MOCK DIAG ===`r`nOK" }
function Save-AmfetaminDiagnosticReport { Join-Path $env:TEMP 'amfetamin-diag.txt' }
function Ensure-Dirs { if (-not $Script:LogDir) { Initialize-AmfetaminLogging } }
function Get-AmfetaminUpdateInfo { [PSCustomObject]@{ UpdateAvailable = $false; Current = '3.1.4'; Latest = '3.1.4' } }
function Uninstall-FromDevice { (T 'msg_uninstalled') }

. (Get-AmfetaminUtf8ScriptBlock (Join-Path $PSScriptRoot 'lib\AmfetaminUI.ps1'))
Write-Host 'UI test basladi — otomatik dogrulama yapiliyor...' -ForegroundColor Cyan
Show-AmfetaminMainForm
$out = Join-Path $env:TEMP 'amfetamin-ui-test.json'
if (Test-Path $out) {
    $r = Get-Content $out -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($r.passed) {
        Write-Host 'UI test PASSED' -ForegroundColor Green
        Write-Host ($r | ConvertTo-Json -Compress)
        exit 0
    }
    Write-Host 'UI test FAILED' -ForegroundColor Red
    Write-Host ($r | ConvertTo-Json -Compress)
    exit 1
}
Write-Host 'UI test sonuc dosyasi bulunamadi' -ForegroundColor Red
exit 1
