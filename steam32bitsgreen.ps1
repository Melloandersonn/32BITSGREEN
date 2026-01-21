#Requires -Version 5.1

# ===== Encoding/Console (corrige "conclu??do" e "???") =====
try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [Console]::OutputEncoding = $utf8NoBom
    $OutputEncoding = $utf8NoBom
} catch { }

# ===== Clean UI (remove barras azuis do PowerShell) =====
$global:ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Clear-Host

# ===============================================================
# CONFIG SIDEBAR
# ===============================================================
$global:Steps = @(
    "Detectando Steam",
    "Encerrando Steam",
    "Baixando arquivo",
    "Extraindo arquivos",
    "Criando configuracao",
    "Finalizando"
)

$global:CurrentStep = 0
$global:TotalSteps = $Steps.Count

function Draw-Sidebar {
    param([int]$ActiveStep)

    Clear-Host
    Write-Host "┌────────────────────────────┐" -ForegroundColor DarkGreen
    Write-Host "│   GREEN STORE - PROGRESS   │" -ForegroundColor Green
    Write-Host "├────────────────────────────┤" -ForegroundColor DarkGreen

    for ($i = 0; $i -lt $Steps.Count; $i++) {
        if ($i -lt $ActiveStep) {
            Write-Host ("│ [OK]  " + $Steps[$i]).PadRight(28) "│" -ForegroundColor Green
        } elseif ($i -eq $ActiveStep) {
            Write-Host ("│ [>>]  " + $Steps[$i]).PadRight(28) "│" -ForegroundColor Yellow
        } else {
            Write-Host ("│ [..]  " + $Steps[$i]).PadRight(28) "│" -ForegroundColor DarkGray
        }
    }

    Write-Host "├────────────────────────────┤" -ForegroundColor DarkGreen
    $percent = [int](($ActiveStep / $TotalSteps) * 100)
    Write-Host ("│ Progresso: {0}%".PadRight(28) -f $percent) "│" -ForegroundColor Cyan
    Write-Host "└────────────────────────────┘" -ForegroundColor DarkGreen
    Write-Host ""
}

function Next-Step {
    $global:CurrentStep++
    Draw-Sidebar -ActiveStep $global:CurrentStep
}

Draw-Sidebar -ActiveStep 0

# ===============================================================
# FUNCOES
# ===============================================================
function Stop-OnError {
    param([string]$Message)

    Write-Host ""
    Write-Host "ERRO: $Message" -ForegroundColor Red
    Write-Host "O script foi interrompido." -ForegroundColor Red
    exit 1
}

function Stop-TargetProcesses {
    # Coloque aqui os processos que VOCÊ quer encerrar
    # Exemplo:
    # Get-Process "meuprocesso" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Get-TargetPath {
    # Coloque aqui como VOCÊ detecta o caminho no registro/FS
    # Retorne um caminho valido ou $null
    return $null
}

function Download-FileClean {
    param([string]$Url, [string]$Fallback, [string]$OutFile)

    $old = $global:ProgressPreference
    try {
        $global:ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
        } catch {
            Invoke-WebRequest -Uri $Fallback -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
        }
    } finally {
        $global:ProgressPreference = $old
    }
}

function Expand-ArchiveClean {
    param([string]$ZipPath, [string]$DestinationPath)

    $old = $global:ProgressPreference
    try {
        $global:ProgressPreference = 'SilentlyContinue'
        Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force
    } finally {
        $global:ProgressPreference = $old
    }
}

# ===============================================================
# EXECUCAO
# ===============================================================

# STEP 1 - DETECT
$targetPath = Get-TargetPath
if (-not $targetPath) { Stop-OnError "Caminho nao encontrado." }
Next-Step

# STEP 2 - STOP
Stop-TargetProcesses
Start-Sleep 1
Next-Step

# STEP 3 - DOWNLOAD (sem barra azul)
$tempZip = Join-Path $env:TEMP "payload.zip"

# >>> COLE AQUI suas URLs (principal e fallback) e mantenha o OutFile $tempZip
# Download-FileClean "URL_PRINCIPAL" "URL_FALLBACK" $tempZip

Next-Step

# STEP 4 - EXTRACT (sem barra azul)
# >>> COLE AQUI seu destino real (DestinationPath)
# Expand-ArchiveClean -ZipPath $tempZip -DestinationPath $targetPath

# Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Next-Step

# STEP 5 - CONFIG
# >>> COLE AQUI sua criacao de config (sem mexer na UI)
Next-Step

# STEP 6 - FINAL
# >>> COLE AQUI seu Start-Process (se houver)
Next-Step

Write-Host ""
Write-Host "[OK] Processo concluido com sucesso!" -ForegroundColor Green
