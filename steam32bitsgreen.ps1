#Requires -Version 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Clear-Host

# ===============================================================
# SIDEBAR CONFIG
# ===============================================================

$global:Steps = @(
    "Detectando Steam",
    "Encerrando Steam",
    "Baixando Steam 32-bit",
    "Extraindo arquivos",
    "Criando steam.cfg",
    "Iniciando Steam"
)

$global:CurrentStep = 0
$global:TotalSteps = $Steps.Count

function Draw-Sidebar {
    param ([int]$ActiveStep)

    Clear-Host
    Write-Host "┌────────────────────────────┐" -ForegroundColor DarkGreen
    Write-Host "│   GREEN STORE - PROGRESS   │" -ForegroundColor Green
    Write-Host "├────────────────────────────┤" -ForegroundColor DarkGreen

    for ($i = 0; $i -lt $Steps.Count; $i++) {
        if ($i -lt $ActiveStep) {
            Write-Host ("│ [✔]  " + $Steps[$i]).PadRight(28) "│" -ForegroundColor Green
        }
        elseif ($i -eq $ActiveStep) {
            Write-Host ("│ [▶]  " + $Steps[$i]).PadRight(28) "│" -ForegroundColor Yellow
        }
        else {
            Write-Host ("│ [·]  " + $Steps[$i]).PadRight(28) "│" -ForegroundColor DarkGray
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
# FUNÇÕES
# ===============================================================

function Stop-OnError {
    param ([string]$Message)
    Write-Host ""
    Write-Host "ERRO: $Message" -ForegroundColor Red
    Write-Host "Script interrompido." -ForegroundColor Red
    exit 1
}

function Stop-SteamProcesses {
    Get-Process steam -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
}

function Get-SteamPath {
    $paths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\Software\Valve\Steam",
        "HKLM:\Software\WOW6432Node\Valve\Steam"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) {
            $prop = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
            if ($prop.SteamPath -and (Test-Path $prop.SteamPath)) {
                return $prop.SteamPath
            }
            if ($prop.InstallPath -and (Test-Path $prop.InstallPath)) {
                return $prop.InstallPath
            }
        }
    }
    return $null
}

function Download-Zip {
    param ($Url, $Fallback, $Out)

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing
    } catch {
        Invoke-WebRequest -Uri $Fallback -OutFile $Out -UseBasicParsing
    }
}

# ===============================================================
# EXECUÇÃO
# ===============================================================

# STEP 1 – DETECT STEAM
$steamPath = Get-SteamPath
if (-not $steamPath) { Stop-OnError "Steam não encontrado." }
Next-Step
Start-Sleep 1

# STEP 2 – STOP STEAM
Stop-SteamProcesses
Next-Step
Start-Sleep 1

# STEP 3 – DOWNLOAD
$tempZip = Join-Path $env:TEMP "steam32.zip"
Download-Zip `
    "https://github.com/madoiscool/lt_api_links/releases/download/unsteam/latest32bitsteam.zip" `
    "http://files.luatools.work/OneOffFiles/latest32bitsteam.zip" `
    $tempZip
Next-Step
Start-Sleep 1

# STEP 4 – EXTRACT
Expand-Archive -Path $tempZip -DestinationPath $steamPath -Force
Remove-Item $tempZip -Force
Next-Step
Start-Sleep 1

# STEP 5 – CFG
$cfg = "BootStrapperInhibitAll=enable`nBootStrapperForceSelfUpdate=disable"
Set-Content -Path (Join-Path $steamPath "steam.cfg") -Value $cfg -Force
Next-Step
Start-Sleep 1

# STEP 6 – START STEAM
Start-Process -FilePath (Join-Path $steamPath "Steam.exe") -ArgumentList "-clearbeta"
Next-Step

Write-Host ""
Write-Host "✔ Processo concluído com sucesso!" -ForegroundColor Green
