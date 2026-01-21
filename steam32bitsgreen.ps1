#Requires -Version 5.1

# --- Clean: remove progress azul interno (Invoke-WebRequest / Expand-Archive etc.)
$global:ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host

# ===============================================================
# CONFIG SIDEBAR (ASCII only - no ???)
# ===============================================================
$global:Steps = @(
    "Detectando caminho",
    "Encerrando processos",
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
    Write-Host "+----------------------------------+" -ForegroundColor Green
    Write-Host "|        GREEN STORE - PROGRESS     |" -ForegroundColor Green
    Write-Host "+----------------------------------+" -ForegroundColor Green

    for ($i = 0; $i -lt $Steps.Count; $i++) {
        if ($i -lt $ActiveStep) {
            Write-Host ("| [OK] " + $Steps[$i]).PadRight(35) + "|" -ForegroundColor Green
        }
        elseif ($i -eq $ActiveStep) {
            Write-Host ("| [>>] " + $Steps[$i]).PadRight(35) + "|" -ForegroundColor Yellow
        }
        else {
            Write-Host ("| [..] " + $Steps[$i]).PadRight(35) + "|" -ForegroundColor DarkGray
        }
    }

    Write-Host "+----------------------------------+" -ForegroundColor Green
    $percent = [int](($ActiveStep / $TotalSteps) * 100)
    Write-Host ("| Progresso: {0}%".PadRight(35) -f $percent) + "|" -ForegroundColor Cyan
    Write-Host "+----------------------------------+" -ForegroundColor Green
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

# EXEMPLO: encerra processos (edite os nomes se precisar)
function Stop-TargetProcesses {
    $names = @("steam")  # <- troque/adicione nomes aqui se quiser
    foreach ($n in $names) {
        Get-Process $n -ErrorAction SilentlyContinue | ForEach-Object {
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
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

# STEP 1 - DETECT PATH (sem dar "Caminho nao encontrado")
$targetPath = Read-Host "Digite o caminho da pasta de destino (ex: C:\MinhaPasta)"

if (-not $targetPath) { Stop-OnError "Caminho vazio." }

if (-not (Test-Path $targetPath)) {
    $ans = Read-Host "A pasta nao existe. Quer criar? (S/N)"
    if ($ans -match '^(s|S)$') {
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    } else {
        Stop-OnError "Caminho nao encontrado."
    }
}

Next-Step

# STEP 2 - STOP
Stop-TargetProcesses
Start-Sleep -Milliseconds 400
Next-Step

# STEP 3 - DOWNLOAD (exemplo - coloque suas URLs se for usar)
$tempZip = Join-Path $env:TEMP "payload.zip"

# Descomente e coloque suas URLs se precisar:
# Download-FileClean `
#   "URL_PRINCIPAL_AQUI" `
#   "URL_FALLBACK_AQUI" `
#   $tempZip

Start-Sleep -Milliseconds 400
Next-Step

# STEP 4 - EXTRACT (exemplo)
# Descomente se voce tiver baixado um zip:
# Expand-ArchiveClean -ZipPath $tempZip -DestinationPath $targetPath
# Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

Start-Sleep -Milliseconds 400
Next-Step

# STEP 5 - CONFIG (exemplo)
# Coloque sua configuracao aqui, se tiver

Start-Sleep -Milliseconds 400
Next-Step

# STEP 6 - FINAL
Next-Step
Write-Host ""
Write-Host "[OK] Processo concluido com sucesso!" -ForegroundColor Green
