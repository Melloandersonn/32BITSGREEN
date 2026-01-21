#Requires -Version 5.1

# =========================
# CONSOLE / ENCODING (fix de "conclu??do" e "???")
# =========================
try {
    # UTF-8 sem BOM na saida do console
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [Console]::OutputEncoding = $utf8NoBom
    $OutputEncoding = $utf8NoBom
} catch { }

# =========================
# CLEAN MODE (remove barras azuis internas)
# =========================
$global:ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Clear-Host

# =========================
# UI (barra + %)
# =========================
$script:Steps = @(
    "Etapa 1/5 - Preparando",
    "Etapa 2/5 - Executando",
    "Etapa 3/5 - Processando",
    "Etapa 4/5 - Aplicando",
    "Etapa 5/5 - Finalizando"
)
$script:StepIndex = 0
$script:TotalSteps = $script:Steps.Count

function Set-Step {
    param([string]$Message)

    $script:StepIndex++
    if ($script:StepIndex -gt $script:TotalSteps) { $script:StepIndex = $script:TotalSteps }

    $percent = [int](($script:StepIndex / $script:TotalSteps) * 100)

    # Apenas a SUA barra (nada de azul automatico)
    Write-Progress -Id 1 -Activity "GREEN STORE - Progresso" -Status "$Message ($percent%)" -PercentComplete $percent
}

function Stop-OnError {
    param([string]$Message)

    Write-Progress -Id 1 -Activity "GREEN STORE - Progresso" -Completed
    Write-Host ""
    Write-Host "[ERRO] $Message" -ForegroundColor Red
    exit 1
}

function Done {
    Write-Progress -Id 1 -Activity "GREEN STORE - Progresso" -Completed
    Write-Host ""
    # Sem acento e sem emoji (pra nao quebrar em PS 5.1)
    Write-Host "[OK] Processo concluido com sucesso!" -ForegroundColor Green
}

# Executa um bloco garantindo que nenhum comando desenhe "barra azul"
function Invoke-Clean {
    param([Parameter(Mandatory)] [scriptblock]$Block)

    $old = $global:ProgressPreference
    try {
        $global:ProgressPreference = 'SilentlyContinue'
        & $Block
    } finally {
        $global:ProgressPreference = $old
    }
}

# =========================
# EXECUCAO (coloque suas acoes aqui)
# =========================
try {
    Set-Step $script:Steps[0]
    Invoke-Clean {
        # >>> COLOQUE AQUI a logica da etapa 1
        Start-Sleep -Milliseconds 400
    }

    Set-Step $script:Steps[1]
    Invoke-Clean {
        # >>> COLOQUE AQUI a logica da etapa 2
        Start-Sleep -Milliseconds 400
    }

    Set-Step $script:Steps[2]
    Invoke-Clean {
        # >>> COLOQUE AQUI a logica da etapa 3
        Start-Sleep -Milliseconds 400
    }

    Set-Step $script:Steps[3]
    Invoke-Clean {
        # >>> COLOQUE AQUI a logica da etapa 4
        Start-Sleep -Milliseconds 400
    }

    Set-Step $script:Steps[4]
    Invoke-Clean {
        # >>> COLOQUE AQUI a logica da etapa 5
        Start-Sleep -Milliseconds 400
    }

    Done
}
catch {
    Stop-OnError $_.Exception.Message
}
