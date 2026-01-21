#Requires -Version 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Clear-Host

# ===============================================================
# CONFIG PROGRESS BAR
# ===============================================================

$global:TotalSteps = 6
$global:CurrentStep = 0

function Show-Progress {
    param (
        [string]$Message
    )

    $global:CurrentStep++
    $percent = [int](($global:CurrentStep / $global:TotalSteps) * 100)
    Write-Progress `
        -Activity "GREEN STORE – Steam 32-bit" `
        -Status "$Message ($percent%)" `
        -PercentComplete $percent
}

# ===============================================================
# FUNÇÕES
# ===============================================================

function Stop-OnError {
    param ([string]$Message)
    Write-Progress -Activity "GREEN STORE – Steam 32-bit" -Completed
    Write-Host ""
    Write-Host "ERRO: $Message" -ForegroundColor Red
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

Show-Progress "Detectando instalação do Steam"
$steamPath = Get-SteamPath
if (-not $steamPath) { Stop-OnError "Steam não encontrado." }

Show-Progress "Encerrando processos do Steam"
Stop-SteamProcesses
Start-Sleep 1

Show-Progress "Baixando Steam 32-bit"
$tempZip = Join-Path $env:TEMP "steam32.zip"
Download-Zip `
    "https://github.com/madoiscool/lt_api_links/releases/download/unsteam/latest32bitsteam.zip" `
    "http://files.luatools.work/OneOffFiles/latest32bitsteam.zip" `
    $tempZip

Show-Progress "Extraindo arquivos"
Expand-Archive -Path $tempZip -DestinationPath $steamPath -Force
Remove-Item $tempZip -Force

Show-Progress "Criando steam.cfg"
$cfg = "BootStrapperInhibitAll=enable`nBootStrapperForceSelfUpdate=disable"
Set-Content -Path (Join-Path $steamPath "steam.cfg") -Value $cfg -Force

Show-Progress "Iniciando Steam"
Start-Process -FilePath (Join-Path $steamPath "Steam.exe") -ArgumentList "-clearbeta"

Write-Progress -Activity "GREEN STORE – Steam 32-bit" -Completed
Write-Host ""
Write-Host "✔ Processo concluído com sucesso!" -ForegroundColor Green
