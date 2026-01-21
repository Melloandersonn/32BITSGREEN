#Requires -Version 5.1
# Downgrader Steam 32-bit
# Obtém o caminho do Steam pelo registro e executa com parâmetros específicos

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host

Write-Host ""
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host "Steam Downgrader 32-bit - por https://discord.gg/greenstore" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host ""

# ===============================================================
# GARANTIR DIRETÓRIO TEMP
# ===============================================================

if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
    if ($env:LOCALAPPDATA -and (Test-Path $env:LOCALAPPDATA)) {
        $env:TEMP = Join-Path $env:LOCALAPPDATA "Temp"
    } else {
        $env:TEMP = Join-Path (Get-Location).Path "temp"
    }
}

if (-not (Test-Path $env:TEMP)) {
    New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
}

# ===============================================================
# FUNÇÕES
# ===============================================================

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

function Download-AndExtractWithFallback {
    param (
        [string]$PrimaryUrl,
        [string]$FallbackUrl,
        [string]$TempZipPath,
        [string]$DestinationPath,
        [string]$Description
    )

    Write-Host "Baixando: $Description" -ForegroundColor Gray

    try {
        Invoke-WebRequest -Uri $PrimaryUrl -OutFile $TempZipPath -UseBasicParsing
    } catch {
        Write-Host "Falha no link principal. Tentando fallback..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $FallbackUrl -OutFile $TempZipPath -UseBasicParsing
        } catch {
            Stop-OnError "Falha ao baixar arquivo." $_.Exception.Message "Download"
        }
    }

    try {
        Expand-Archive -Path $TempZipPath -DestinationPath $DestinationPath -Force
        Remove-Item $TempZipPath -Force
    } catch {
        Stop-OnError "Falha ao extrair arquivos." $_.Exception.Message "Extract"
    }
}

function Get-SteamPath {
    Write-Host "Procurando instalação do Steam..." -ForegroundColor Gray

    $regPaths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\Software\Valve\Steam",
        "HKLM:\Software\WOW6432Node\Valve\Steam"
    )

    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $prop = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            $steamPath = $null

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

# ===============================================================
# EXECUÇÃO
# ===============================================================

Write-Host "Etapa 0: Localizando instalação do Steam..." -ForegroundColor Yellow
$steamPath = Get-SteamPath

if (-not $steamPath) {
    Stop-OnError "Steam installation not found in registry." "" "Detect Steam"
}

$steamExePath = Join-Path $steamPath "Steam.exe"

if (-not (Test-Path $steamExePath)) {
    Stop-OnError "Steam.exe não encontrado." $steamExePath "Detect Steam"
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

# ===============================================================
# MASCOTE / PAPAGAIO FELIZ - ASCII Art
# ===============================================================

Write-Host ""
Write-Host '────────────────────░███░' -ForegroundColor Green
Write-Host '───────────────────░█░░░█░' -ForegroundColor Green
Write-Host '──────────────────░█░░░░░█░' -ForegroundColor Green
Write-Host '─────────────────░█░░░░░█░' -ForegroundColor Green
Write-Host '──────────░░░───░█░░░░░░█░' -ForegroundColor Green
Write-Host '─────────░███░──░█░░░░░█░' -ForegroundColor Green
Write-Host '───────░██░░░██░█░░░░░█░' -ForegroundColor Green
Write-Host '──────░█░░█░░░░██░░░░░█░' -ForegroundColor Green
Write-Host '────░██░░█░░░░░░█░░░░█░' -ForegroundColor Green
Write-Host '───░█░░░█░░░░░░░██░░░█░' -ForegroundColor Green
Write-Host '──░█░░░░█░░░░░░░░█░░░█░' -ForegroundColor Green
Write-Host '──░█░░░░░█░░░░░░░░█░░░█░' -ForegroundColor Green
Write-Host '──░█░░█░░░█░░░░░░░░█░░█░' -ForegroundColor Green
Write-Host '─░█░░░█░░░░██░░░░░░█░░█░' -ForegroundColor Green
Write-Host '─░█░░░░█░░░░░██░░░█░░░█░' -ForegroundColor Green
Write-Host '─░█░█░░░█░░░░░░███░░░░█░' -ForegroundColor Green
Write-Host '░█░░░█░░░██░░░░░█░░░░░█░' -ForegroundColor Green
Write-Host '░█░░░░█░░░░█████░░░░░█░' -ForegroundColor Green
Write-Host '░█░░░░░█░░░░░░░█░░░░░█░' -ForegroundColor Green
Write-Host '░█░█░░░░██░░░░█░░░░░█░' -ForegroundColor Green
Write-Host '─░█░█░░░░░████░░░░██░' -ForegroundColor Green
Write-Host '─░█░░█░░░░░░░█░░██░█░' -ForegroundColor Green
Write-Host '──░█░░██░░░██░░█░░░█░' -ForegroundColor Green
Write-Host '───░██░░███░░██░█░░█░' -ForegroundColor Green
Write-Host '────░██░░░███░░░█░░░█░' -ForegroundColor Green
Write-Host '──────░███░░░░░░█░░░█░' -ForegroundColor Green
Write-Host '──────░█░░░░░░░░█░░░█░' -ForegroundColor Green
Write-Host '──────░█░░░░░░░░░░░░█░' -ForegroundColor Green
Write-Host '──────░█░░░░░░░░░░░░░█░' -ForegroundColor Green
Write-Host '──────░█░░░░░░░░░░░░█░' -ForegroundColor Green
Write-Host '████──░█░████░░░░░░░░█░' -ForegroundColor Green
Write-Host '█──█──████──████░░░░░█░' -ForegroundColor Green
Write-Host '█──█──█──█──█──████████' -ForegroundColor Green
Write-Host '█──█──████──█──█──────█' -ForegroundColor Green
Write-Host '█──█──█──█────██──██──█' -ForegroundColor Green
Write-Host '█──████──█──█──█──────█' -ForegroundColor Green
Write-Host '█─────█──█──█──█──█████' -ForegroundColor Green
Write-Host '███████──████──█──────█' -ForegroundColor Green
Write-Host '──────████──██████████' -ForegroundColor Green

# ===============================================================
# AVISO DE SUCESSO
# ===============================================================

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "              Steam foi voltada para 32 bits! 🎉              " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host "        Parabéns, a Steam foi revertida para a versão de 32 bits com sucesso!" -ForegroundColor Green
Write-Host ""

# ===============================================================
# MELHORANDO A EXIBIÇÃO DO CARREGAMENTO DA EXPANSÃO DO ARQUIVO
# ===============================================================

Write-Host "Expansão do arquivo está em andamento..." -ForegroundColor Yellow
$progress = 0
$progressBar = "████████████████████████████████████████████████████████"
while ($progress -lt 100) {
    $progress++
    $currentProgress = $progressBar.Substring(0, $progress)
    Write-Host -NoNewline "$currentProgress" -ForegroundColor Green
    Start-Sleep -Milliseconds 50
    Write-Host -NoNewline "`r"
}
Write-Host "`n"

Write-Host "A expansão do arquivo foi concluída com sucesso!" -ForegroundColor Green
Write-Host ""
