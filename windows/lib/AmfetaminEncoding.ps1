# UTF-8 script loader (PS 5.1 safe — files without BOM)
function Get-AmfetaminUtf8ScriptBlock {
    param([Parameter(Mandatory)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Script path is empty'
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Script not found: $Path"
    }
    $scriptRoot = (Split-Path $Path -Parent).Replace("'", "''")
    $body = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    $code = "`$PSScriptRoot = '$scriptRoot'`r`n" + $body
    return [scriptblock]::Create($code)
}

function Import-AmfetaminUtf8Script {
    param([Parameter(Mandatory)][string]$Path)
    . (Get-AmfetaminUtf8ScriptBlock $Path)
}

function Write-AmfetaminUtf8Bom {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return }
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($Path, $content, (New-Object System.Text.UTF8Encoding $true))
}
