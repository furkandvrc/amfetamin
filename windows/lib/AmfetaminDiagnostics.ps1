# amfetamin — entegre teshis
function Get-AmfetaminDiagnosticReport {
    param([switch]$Quiet)
    $lines = [System.Collections.ArrayList]::new()
    function L([string]$m) {
        $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
        [void]$lines.Add($line)
        if (-not $Quiet) { Write-Host $line }
    }

    L (T 'diag_report_header')
    L (T 'diag_pc_user' $env:COMPUTERNAME, $env:USERNAME)
    try { $cfg = Get-Config; L (T 'diag_version_line' $cfg.version, $cfg.fakeTtl, $cfg.autoTuneDone) } catch { L (T 'diag_config_unreadable') }
    L (T 'diag_windows' ([Environment]::OSVersion.VersionString))

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    L (T 'diag_admin' $isAdmin)

    $st = Get-AmfetaminStatus
    L (T 'diag_status_line' $st.NpcapInstalled, $st.EngineDownloaded, $st.EngineRunning, $st.AutoStartInstalled)

    L (T 'diag_section_zerotier')
    $zt = Get-Process -Name 'ZeroTier*' -ErrorAction SilentlyContinue
    if ($zt) { L (T 'diag_zerotier_warning' (($zt.Id -join ','))) }
    else { L (T 'diag_zerotier_none') }

    L (T 'diag_section_dns')
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
        $srv = ($_.ServerAddresses -join ', ')
        if ($srv) { L (T 'diag_dns_iface' $_.InterfaceAlias, $srv) }
    }

    L (T 'diag_section_tcp443')
    foreach ($target in @('discord.com', 'gateway.discord.gg', 'www.google.com')) {
        try {
            $t = Test-NetConnection $target -Port 443 -WarningAction SilentlyContinue
            L (T 'diag_tcp_result' $target, $t.TcpTestSucceeded)
        } catch { L (T 'diag_tcp_error' $target) }
    }

    L (T 'diag_section_http')
    foreach ($url in @('https://discord.com', 'https://www.google.com')) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
            $sw.Stop()
            L (T 'diag_http_ok' $url, $r.StatusCode, $sw.ElapsedMilliseconds)
        } catch {
            $sw.Stop()
            L (T 'diag_http_fail' $url, $sw.ElapsedMilliseconds)
        }
    }

    L (T 'diag_section_recent_logs')
    foreach ($name in @('app.log', 'errors.log', 'amfetamin-run.log')) {
        $tail = Get-AmfetaminLogTail -LogName $name -Lines 5
        if ($tail.Count -gt 0) {
            L (T 'diag_log_section' $name)
            $tail | ForEach-Object { L (T 'diag_log_line' $_) }
        }
    }

    L (T 'diag_report_footer')
    return ($lines -join [Environment]::NewLine)
}

function Save-AmfetaminDiagnosticReport {
    param([string]$Path)
    $report = Get-AmfetaminDiagnosticReport -Quiet
    $dest = if ($Path) { $Path } else {
        Join-Path (Get-ProjectRoot) "amfetamin-diagnose-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    }
    [System.IO.File]::WriteAllText($dest, $report + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-AmfetaminLog -Message "Teshis raporu kaydedildi: $dest" -Level INFO
    return $dest
}

function Test-AmfetaminConnectivity {
    param([string[]]$Urls)
    if (-not $Urls) {
        $Urls = @('https://discord.com', 'https://www.google.com/generate_204')
    }
    $results = @()
    foreach ($url in $Urls) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $ok = $false
        $code = 0
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -Method Head -ErrorAction Stop
            $ok = $true; $code = $r.StatusCode
        } catch {
            try {
                $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
                $ok = $true; $code = $r.StatusCode
            } catch {}
        }
        $sw.Stop()
        $results += [PSCustomObject]@{
            Url = $url
            Ok = $ok
            StatusCode = $code
            Ms = [int]$sw.ElapsedMilliseconds
        }
    }
    return $results
}

function Test-ZeroTierRunning {
    return $null -ne (Get-Process -Name 'ZeroTier*' -ErrorAction SilentlyContinue)
}

function Get-AmfetaminUpdateInfo {
    try {
        $cfg = Get-Config
        $current = [string]$cfg.version
        $api = Invoke-RestMethod -Uri 'https://api.github.com/repos/furkandvrc/amfetamin/releases/latest' -UseBasicParsing -TimeoutSec 10
        $latest = ($api.tag_name -replace '^v','')
        $url = ($api.assets | Where-Object { $_.name -eq 'amfetamin.zip' } | Select-Object -First 1).browser_download_url
        return [PSCustomObject]@{
            Current = $current
            Latest = $latest
            UpdateAvailable = ([version]$latest -gt [version]$current)
            DownloadUrl = $url
        }
    } catch {
        Write-AmfetaminError -Message 'Guncelleme kontrolu basarisiz' -Exception $_.Exception
        return $null
    }
}
