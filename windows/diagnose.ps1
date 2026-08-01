# amfetamin teshis - by furkandvrc
# Calistir: diagnose.bat  VEYA  powershell -ExecutionPolicy Bypass -File .\diagnose.ps1
# Cikti: bu klasorde amfetamin-diagnose.txt

$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'lib\AmfetaminI18n.ps1')
Initialize-AmfetaminI18n

function Write-DiagLine {
    param([string]$Message, [System.Collections.ArrayList]$Buffer)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    [void]$Buffer.Add($line)
    Write-Host $line
}

function Get-DiagReportPath {
    if ($PSScriptRoot) {
        return Join-Path $PSScriptRoot 'amfetamin-diagnose.txt'
    }
    return Join-Path (Get-Location).Path 'amfetamin-diagnose.txt'
}

$lines = New-Object System.Collections.ArrayList

try {
    Write-DiagLine (T 'diag_report_header') $lines
    Write-DiagLine (T 'diag_pc_user' $env:COMPUTERNAME, $env:USERNAME) $lines
    Write-DiagLine (T 'diag_folder' (Get-Location)) $lines
    Write-DiagLine (T 'diag_windows' ([Environment]::OSVersion.VersionString)) $lines

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-DiagLine (T 'diag_admin' $isAdmin) $lines

    $installRoot = Join-Path $env:LOCALAPPDATA 'Amfetamin'
    $engine = Join-Path $installRoot 'bin\amfetamin.exe'
    Write-DiagLine (T 'diag_install_root' $installRoot, (Test-Path $installRoot)) $lines
    Write-DiagLine (T 'diag_engine_exe' $engine, (Test-Path $engine)) $lines

    $configPath = Join-Path $installRoot 'config.json'
    if (Test-Path $configPath) {
        Write-DiagLine (T 'diag_section_config') $lines
        Get-Content $configPath -ErrorAction SilentlyContinue | ForEach-Object {
            Write-DiagLine (T 'diag_config_line' $_) $lines
        }
    }

    Write-DiagLine (T 'diag_section_npcap') $lines
    Write-DiagLine (T 'diag_npcap_program_files' (Test-Path 'C:\Program Files\Npcap')) $lines
    Write-DiagLine (T 'diag_npcap_wpcap' (Test-Path 'C:\Windows\System32\Npcap\wpcap.dll')) $lines

    Write-DiagLine (T 'diag_section_process') $lines
    $procs = Get-Process -Name amfetamin -ErrorAction SilentlyContinue
    if ($procs) {
        foreach ($proc in $procs) {
            Write-DiagLine (T 'diag_process_line' $proc.Name, $proc.Id) $lines
        }
    } else {
        Write-DiagLine (T 'diag_process_missing') $lines
    }

    Write-DiagLine (T 'diag_section_scheduled_task') $lines
    $task = Get-ScheduledTask -TaskName 'Amfetamin-AutoStart' -ErrorAction SilentlyContinue
    if ($task) { Write-DiagLine (T 'diag_task_state' $task.State) $lines }
    else { Write-DiagLine (T 'diag_task_missing') $lines }

    Write-DiagLine (T 'diag_section_dns_settings') $lines
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
        $srv = ($_.ServerAddresses -join ', ')
        if ($srv) { Write-DiagLine (T 'diag_dns_iface' $_.InterfaceAlias, $srv) $lines }
    }

    Write-DiagLine (T 'diag_section_dns_resolve') $lines
    foreach ($domain in @('discord.com', 'www.pornhub.com')) {
        Write-DiagLine (T 'diag_dns_domain' $domain) $lines
        foreach ($server in @('127.0.0.1', '8.8.8.8')) {
            Write-DiagLine (T 'diag_nslookup' $server) $lines
            cmd /c "nslookup $domain $server 2>&1" | ForEach-Object {
                Write-DiagLine (T 'diag_nslookup_line' $_) $lines
            }
        }
    }

    Write-DiagLine (T 'diag_section_tcp') $lines
    foreach ($target in @(
            'discord.com', 'gateway.discord.gg', 'cdn.discordapp.com',
            'www.pornhub.com', 'ei.phncdn.com', 'www.google.com'
        )) {
        try {
            $t = Test-NetConnection $target -Port 443 -WarningAction SilentlyContinue
            Write-DiagLine (T 'diag_tcp_result' $target, $t.TcpTestSucceeded) $lines
        } catch {
            Write-DiagLine (T 'diag_tcp_error_detail' $target, $_.Exception.Message) $lines
        }
    }

    Write-DiagLine (T 'diag_section_http_test') $lines
    foreach ($url in @(
            'https://discord.com', 'https://discord.com/app',
            'https://www.pornhub.com', 'https://www.google.com'
        )) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
            $sw.Stop()
            Write-DiagLine (T 'diag_http_result' $url, $r.StatusCode, $sw.ElapsedMilliseconds) $lines
        } catch {
            $sw.Stop()
            Write-DiagLine (T 'diag_http_fail_detail' $url, $sw.ElapsedMilliseconds, $_.Exception.Message) $lines
        }
    }

    Write-DiagLine (T 'diag_section_log_files') $lines
    $logDir = Join-Path $installRoot 'logs'
    foreach ($logName in @('launcher.log', 'amfetamin-run.log', 'service.log')) {
        $path = Join-Path $logDir $logName
        if (Test-Path $path) {
            Write-DiagLine (T 'diag_log_tail_header' $logName) $lines
            Get-Content $path -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object {
                Write-DiagLine (T 'diag_log_line' $_) $lines
            }
        } else {
            Write-DiagLine (T 'diag_log_missing' $logName) $lines
        }
    }

    Write-DiagLine (T 'diag_report_footer') $lines
} catch {
    Write-DiagLine (T 'diag_critical_error' $_.Exception.Message) $lines
}

$reportPath = Get-DiagReportPath
$backupPath = Join-Path $env:TEMP 'amfetamin-diagnose.txt'
$text = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
$savedPath = $null

foreach ($targetPath in @($reportPath, $backupPath)) {
    try {
        [System.IO.File]::WriteAllText($targetPath, $text, [System.Text.UTF8Encoding]::new($false))
        $savedPath = $targetPath
        Write-DiagLine (T 'diag_saved' $targetPath) $lines
        break
    } catch {
        Write-Host (T 'diag_save_error' $targetPath, $_.Exception.Message) -ForegroundColor Yellow
    }
}

Write-Host ''
if ($savedPath) {
    Write-Host (T 'diag_report_saved' $savedPath) -ForegroundColor Green
    try { Start-Process notepad.exe $savedPath } catch {}
} else {
    Write-Host (T 'diag_save_failed') -ForegroundColor Red
    Write-Host $text
}

exit 0
