#Requires -Version 5.1
# Steam 32-bit Downgrader with Christmas Theme
# Gets Steam path from registry and runs with specified parameters

# Limpar tela
Clear-Host

# Cabeçalho com tema de Natal
Write-Host ""
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host "Steam 32-bit Downgrader - by discord.gg/luatools (join for fun)" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host ""

# Garantir que o diretório temp exista (correção para sistemas onde $env:TEMP aponta para um diretório inexistente)
if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
    # Fallback para o AppData\Local\Temp do usuário
    if ($env:LOCALAPPDATA -and (Test-Path $env:LOCALAPPDATA)) {
        $env:TEMP = Join-Path $env:LOCALAPPDATA "Temp"
    }
    # Se ainda não for válido, tentar a última opção
    if (-not $env:TEMP -or -not (Test-Path $env:TEMP)) {
        # Última opção: criar um diretório temp no local do script ou no diretório atual
        if ($PSScriptRoot) {
            $env:TEMP = Join-Path $PSScriptRoot "temp"
        } else {
            $env:TEMP = Join-Path (Get-Location).Path "temp"
        }
    }
}
# Garantir que o diretório temp exista
if (-not (Test-Path $env:TEMP)) {
    New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
}

# Função para pausar o script e explicar o erro
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

# Função para obter o caminho do Steam do registro
function Get-SteamPath {
    $steamPath = $null
    
    Write-Host "Searching for Steam installation..." -ForegroundColor Gray
    
    # Tentar HKCU primeiro (registro do usuário)
    $regPath = "HKCU:\Software\Valve\Steam"
    if (Test-Path $regPath) {
        $steamPath = (Get-ItemProperty -Path $regPath -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
        if ($steamPath -and (Test-Path $steamPath)) {
            return $steamPath
        }
    }
    
    # Tentar HKLM (registro do sistema)
    $regPath = "HKLM:\Software\Valve\Steam"
    if (Test-Path $regPath) {
        $steamPath = (Get-ItemProperty -Path $regPath -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
        if ($steamPath -and (Test-Path $steamPath)) {
            return $steamPath
        }
    }
    
    # Tentar o registro de 32 bits em sistemas de 64 bits
    $regPath = "HKLM:\Software\WOW6432Node\Valve\Steam"
    if (Test-Path $regPath) {
        $steamPath = (Get-ItemProperty -Path $regPath -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
        if ($steamPath -and (Test-Path $steamPath)) {
            return $steamPath
        }
    }
    
    return $null
}

# Função para baixar arquivo com barra de progresso
function Download-FileWithProgress {
    param(
        [string]$Url,
        [string]$OutFile
    )
    
    try {
        # Adicionar quebra de cache para evitar cache do PowerShell
        $uri = New-Object System.Uri($Url)
        $uriBuilder = New-Object System.UriBuilder($uri)
        $timestamp = (Get-Date -Format 'yyyyMMddHHmmss')
        if ($uriBuilder.Query) {
            $uriBuilder.Query = $uriBuilder.Query.TrimStart('?') + "&t=" + $timestamp
        } else {
            $uriBuilder.Query = "t=" + $timestamp
        }
        $cacheBustUrl = $uriBuilder.ToString()
        
        # Primeira solicitação para obter o comprimento do conteúdo e verificar a resposta
        $request = [System.Net.HttpWebRequest]::Create($cacheBustUrl)
        $request.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
        $request.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
        $request.Headers.Add("Pragma", "no-cache")
        $request.Timeout = 30000 # Timeout de 30 segundos
        $request.ReadWriteTimeout = 30000
        
        try {
            $response = $request.GetResponse()
        } catch {
            Write-Host "  [ERROR] Connection failed: $_" -ForegroundColor Red
            Write-Host "  [ERROR] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Connection timeout or failed to connect to server"
        }
        
        # Verificar código de resposta
        $statusCode = [int]$response.StatusCode
        if ($statusCode -ne 200) {
            $response.Close()
            Write-Host "  [ERROR] Invalid response code: $statusCode (expected 200)" -ForegroundColor Red
            Write-Host "  [ERROR] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Server returned status code $statusCode instead of 200"
        }
        
        # Verificar comprimento do conteúdo
        $totalLength = $response.ContentLength
        if ($totalLength -eq 0) {
            $response.Close()
            Write-Host "  [ERROR] Invalid content length: $totalLength (expected > 0 or -1 for unknown)" -ForegroundColor Red
            Write-Host "  [ERROR] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Server returned zero content length"
        }
        $response.Close()
        
        # Solicitação para baixar o arquivo (sem timeout)
        $request = [System.Net.HttpWebRequest]::Create($cacheBustUrl)
        $request.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
        $request.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
        $request.Headers.Add("Pragma", "no-cache")
        $request.Timeout = -1 # Sem timeout
        $request.ReadWriteTimeout = -1 # Sem timeout
        
        $response = $null
        try {
            $response = $request.GetResponse()
        } catch {
            Write-Host "  [ERROR] Download connection failed: $_" -ForegroundColor Red
            Write-Host "  [ERROR] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Download connection failed"
        }
        
        try {
            # Garantir que o diretório de saída exista
            $outDir = Split-Path $OutFile -Parent
            if ($outDir -and -not (Test-Path $outDir)) {
                New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            }
            
            $responseStream = $null
            $targetStream = $null
            $responseStream = $response.GetResponseStream()
            $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $OutFile, Create
            
            $buffer = New-Object byte[] (10 * 1024)  # Buffer de 10KB
            $count = $responseStream.Read($buffer, 0, $buffer.Length)
            $downloadedBytes = $count
            $lastUpdate = Get-Date
            $lastBytesDownloaded = $downloadedBytes
            $lastBytesUpdateTime = Get-Date
            $stuckTimeoutSeconds = 60 # Timeout de 1 minuto para downloads travados
            
            while ($count -gt 0) {
                $targetStream.Write($buffer, 0, $count)
                $count = $responseStream.Read($buffer, 0, $buffer.Length)
                $downloadedBytes += $count
                
                # Verificar se o download está travado
                $now = Get-Date
                if ($downloadedBytes -gt $lastBytesDownloaded) {
                    # Bytes aumentaram, reiniciar o timer
                    $lastBytesDownloaded = $downloadedBytes
                    $lastBytesUpdateTime = $now
                } else {
                    # Nenhum byte foi baixado, verificar se está travado
                    $timeSinceLastBytes = ($now - $lastBytesUpdateTime).TotalSeconds
                    if ($timeSinceLastBytes -ge $stuckTimeoutSeconds) {
                        Write-Host ""
                        Write-Host "  [ERROR] Download is stuck (0 kbps for $stuckTimeoutSeconds seconds)" -ForegroundColor Red
                        Write-Host "  [ERROR] Downloaded: $downloadedBytes bytes, Expected: $totalLength bytes" -ForegroundColor Red
                        throw "Download is stuck - no data received for $stuckTimeoutSeconds seconds"
                    }
                }
                
                # Atualizar progresso a cada 100ms
                if (($now - $lastUpdate).TotalMilliseconds -ge 100) {
                    if ($totalLength -gt 0) {
                        $percentComplete = [math]::Round(($downloadedBytes / $totalLength) * 100, 2)
                        Write-Host "`r  Progress: $percentComplete% ($downloadedBytes bytes of $totalLength bytes)" -NoNewline -ForegroundColor Cyan
                    } else {
                        Write-Host "`r  Progress: Downloading $downloadedBytes bytes..." -NoNewline -ForegroundColor Cyan
                    }
                    $lastUpdate = $now
                }
            }
            
            Write-Host "`r  Progress: 100% Complete!" -ForegroundColor Green
            Write-Host ""
            return $true
        } finally {
            # Fechar streams
            if ($targetStream) {
                $targetStream.Close()
            }
            if ($responseStream) {
                $responseStream.Close()
            }
            if ($response) {
                $response.Close()
            }
        }
    } catch {
        Write-Host ""
        Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
        Write-Host "  [ERROR] Error details: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        throw $_
    }
}
