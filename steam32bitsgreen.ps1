#Requires -Version 5.1
$global:ProgressPreference = 'SilentlyContinue'  # remove a barra azul do Invoke-WebRequest/Expand-Archive
$ErrorActionPreference = 'Stop'
# Downgrader Steam 32-bit
# Obtém o caminho do Steam pelo registro e executa com parâmetros específicos

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host

Write-Host ""
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host "Steam Downgrader 32-bit - por https://discord.gg/greenstore" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host ""

# Garantir que o diretório TEMP exista
if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
    if ($env:LOCALAPPDATA -and (Test-Path $env:LOCALAPPDATA)) {
        $env:TEMP = Join-Path $env:LOCALAPPDATA "Temp"
    }
    if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
        if ($PSScriptRoot) {
            $env:TEMP = Join-Path $PSScriptRoot "temp"
        } else {
            $env:TEMP = Join-Path (Get-Location).Path "temp"
        }
    }
}
if (-not (Test-Path $env:TEMP)) {
    New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
}

# =========================
# FUNÇÕES
# =========================

function Stop-OnError {
    param(
        [string]$ErrorMessage,
        [string]$ErrorDetails = "",
        [string]$StepName = ""
    )

    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Red
    Write-Host "ERROR OCCURRED" -ForegroundColor Red
    if ($StepName) {
        Write-Host "Step: $StepName" -ForegroundColor Yellow
    }
    Write-Host "===============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error Message: $ErrorMessage" -ForegroundColor Red
    if ($ErrorDetails) {
        Write-Host ""
        Write-Host "Details: $ErrorDetails" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "The script cannot continue due to this error." -ForegroundColor Yellow
    Write-Host "Please resolve the issue and try again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Red
    Write-Host "Exiting..." -ForegroundColor Red
    Write-Host "===============================================================" -ForegroundColor Red
    exit 1
}

function Stop-SteamProcesses {
    Write-Host "Encerrando processos do Steam..." -ForegroundColor Gray
    Get-Process steam -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force
        } catch {
            Stop-OnError "Falha ao encerrar processos do Steam." $_.Exception.Message "Stop-SteamProcesses"
        }
    }
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

    $wc.DownloadProgressChanged += {
        Show-LineProgress -Label $Label -Percent $_.ProgressPercentage
    }
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

    $wc.DownloadProgressChanged += {
        Show-LineProgress -Label $Label -Percent $_.ProgressPercentage
    }
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


function Get-SteamPath {
    $steamPath = $null

    Write-Host "Procurando instalação do Steam..." -ForegroundColor Gray

    $regPaths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\Software\Valve\Steam",
        "HKLM:\Software\WOW6432Node\Valve\Steam"
    )

    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $prop = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue

            if ($prop.SteamPath) {
                $steamPath = $prop.SteamPath
            } elseif ($prop.InstallPath) {
                $steamPath = $prop.InstallPath
            }

            if ($steamPath -and (Test-Path $steamPath)) {
                return $steamPath
            }
        }
    }

    return $null
}

# =========================
# EXECUÇÃO
# =========================

Write-Host "Etapa 0: Localizando instalação do Steam..." -ForegroundColor Yellow
$steamPath = Get-SteamPath

if (-not $steamPath) {
    Write-Host "Steam installation not found in registry." -ForegroundColor Red
    Write-Host "Please ensure Steam is installed on your system." -ForegroundColor Yellow
    exit
}

$steamExePath = Join-Path $steamPath "Steam.exe"

if (-not (Test-Path $steamExePath)) {
    Write-Host "Steam.exe not found at: $steamExePath" -ForegroundColor Red
    exit
}

Write-Host "Steam encontrado com sucesso!" -ForegroundColor Green
Write-Host "Local: $steamPath" -ForegroundColor White
Write-Host ""

Write-Host "Etapa 1: Encerrando processos do Steam..." -ForegroundColor Yellow
Stop-SteamProcesses
Write-Host ""

Write-Host "Etapa 2: Baixando e extraindo Steam 32-bit..." -ForegroundColor Yellow
$steamZipUrl = "https://github.com/madoiscool/lt_api_links/releases/download/unsteam/latest32bitsteam.zip"
$steamZipFallbackUrl = "http://files.luatools.work/OneOffFiles/latest32bitsteam.zip"
$tempSteamZip = Join-Path $env:TEMP "latest32bitsteam.zip"

Download-AndExtractWithFallback `
    -PrimaryUrl $steamZipUrl `
    -FallbackUrl $steamZipFallbackUrl `
    -TempZipPath $tempSteamZip `
    -DestinationPath $steamPath `
    -Description "Steam x32 Latest Build"

Write-Host "Etapa 3: Criando steam.cfg..." -ForegroundColor Yellow
$steamCfgPath = Join-Path $steamPath "steam.cfg"
$cfgContent = "BootStrapperInhibitAll=enable`nBootStrapperForceSelfUpdate=disable"
Set-Content -Path $steamCfgPath -Value $cfgContent -Force

Write-Host "steam.cfg criado com sucesso!" -ForegroundColor Green
Write-Host ""

Write-Host "Etapa 4: Iniciando Steam..." -ForegroundColor Yellow
Start-Process -FilePath $steamExePath -ArgumentList "-clearbeta" -WindowStyle Normal

Write-Host ""
Write-Host "Steam iniciado com sucesso." -ForegroundColor Green
