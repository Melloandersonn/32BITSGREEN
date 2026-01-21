#Requires -Version 5.1

# Remove a barra azul interna do PowerShell
$global:ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Clear-Host

Write-Host ""
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host "Downloader + Extract (Clean UI) - Progress em %" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host ""

# =========================
# CONFIG (EDITE AQUI)
# =========================
$PrimaryUrl  = "https://example.com/arquivo.zip"
$FallbackUrl = "https://example.com/arquivo_fallback.zip"
$DestinationPath = "C:\Destino"
$ZipName = "package.zip"
$Description = "Pacote ZIP"

# =========================
# TEMP (garantir pasta TEMP)
# =========================
if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
    if ($env:LOCALAPPDATA -and (Test-Path $env:LOCALAPPDATA)) {
        $env:TEMP = Join-Path $env:LOCALAPPDATA "Temp"
    }
    if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
        if ($PSScriptRoot) { $env:TEMP = Join-Path $PSScriptRoot "temp" }
        else { $env:TEMP = Join-Path (Get-Location).Path "temp" }
    }
}
if (-not (Test-Path $env:TEMP)) {
    New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
}

# =========================
# FUNÇÕES
# =========================
function Stop-OnError {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERRO: $Message" -ForegroundColor Red
    exit 1
}

function Show-LineProgress {
    param(
        [Parameter(Mandatory)] [string]$Label,
        [Parameter(Mandatory)] [int]$Percent
    )
    $barSize = 30
    $p = [Math]::Max(0, [Math]::Min(100, $Percent))
    $filled = [int](($p / 100) * $barSize)
    $bar = ("#" * $filled).PadRight($barSize, ".")
    Write-Host ("`r{0}: [{1}] {2}%   " -f $Label, $bar, $p) -NoNewline -ForegroundColor Cyan
}

function Download-FileWithPercent {
    param(
        [Parameter(Mandatory)] [string]$Url,
        [Parameter(Mandatory)] [string]$OutFile,
        [string]$Label = "Baixando"
    )

    $done = $false
    $wc = New-Object System.Net.WebClient

    $wc.DownloadProgressChanged += { Show-LineProgress -Label $Label -Percent $_.ProgressPercentage }
    $wc.DownloadFileCompleted += { $script:done = $true }

    try {
        $outDir = Split-Path $OutFile -Parent
        if ($outDir -and -not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        $wc.DownloadFileAsync([Uri]$Url, $OutFile)
        while (-not $done) { Start-Sleep -Milliseconds 80 }

        Show-LineProgress -Label $Label -Percent 100
        Write-Host ""
    }
    finally {
        $wc.Dispose()
    }
}

function Expand-ArchiveWithPercent {
    param(
        [Parameter(Mandatory)] [string]$ZipPath,
        [Parameter(Mandatory)] [string]$DestinationPath,
        [string]$Label = "Extraindo"
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

    try {
        $files = $zip.Entries | Where-Object { -not ($_.FullName.EndsWith('/') -or $_.FullName.EndsWith('\')) }
        $total = [Math]::Max(1, $files.Count)
        $i = 0

        foreach ($e in $zip.Entries) {
            if ($e.FullName.EndsWith('/') -or $e.FullName.EndsWith('\')) { continue }

            $target = Join-Path $DestinationPath ($e.FullName -replace '/', '\')
            $dir = Split-Path $target -Parent
            if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)

            $i++
            $p = [int](($i / $total) * 100)
            Show-LineProgress -Label $Label -Percent $p
        }

        Show-LineProgress -Label $Label -Percent 100
        Write-Host ""
    }
    finally {
        $zip.Dispose()
    }
}

function Download-AndExtractWithFallback {
    param(
        [string]$PrimaryUrl,
        [string]$FallbackUrl,
        [string]$TempZipPath,
        [string]$DestinationPath,
        [string]$Description
    )

    Write-Host "Baixando: $Description" -ForegroundColor Gray

    try {
        try {
            Download-FileWithPercent -Url $PrimaryUrl -OutFile $TempZipPath -Label "Baixando"
        } catch {
            Write-Host "Falha no link principal. Tentando fallback..." -ForegroundColor Yellow
            Download-FileWithPercent -Url $FallbackUrl -OutFile $TempZipPath -Label "Baixando"
        }

        Expand-ArchiveWithPercent -ZipPath $TempZipPath -DestinationPath $DestinationPath -Label "Extraindo"
        Remove-Item $TempZipPath -Force -ErrorAction SilentlyContinue
    }
    catch {
        Stop-OnError $_.Exception.Message
    }
}

# =========================
# EXECUÇÃO
# =========================
$tempZip = Join-Path $env:TEMP $ZipName

Download-AndExtractWithFallback `
    -PrimaryUrl $PrimaryUrl `
    -FallbackUrl $FallbackUrl `
    -TempZipPath $tempZip `
    -DestinationPath $DestinationPath `
    -Description $Description

Write-Host ""
Write-Host "✔ Concluído com sucesso!" -ForegroundColor Green
