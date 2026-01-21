#Requires -Version 5.1
# Steam 32-bit Downgrader with Christmas Theme
# Obtém o caminho do Steam pelo registro e executa com parâmetros especificados

# Limpar tela
Clear-Host

# Cabeçalho com tema de Natal
Write-Host ""
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host "Steam 32-bit Downgrader - por discord.gg/greenstore" -ForegroundColor Cyan
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
    Write-Host "OCORREU UM ERRO" -ForegroundColor Red
    if ($StepName) {
        Write-Host "Passo: $StepName" -ForegroundColor Yellow
    }
    Write-Host "===============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Mensagem de erro: $ErrorMessage" -ForegroundColor Red
    if ($ErrorDetails) {
        Write-Host ""
        Write-Host "Detalhes: $ErrorDetails" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "O script não pode continuar devido a este erro." -ForegroundColor Yellow
    Write-Host "Por favor, resolva o problema e tente novamente." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Red
    Write-Host "Saindo..." -ForegroundColor Red
    Write-Host "===============================================================" -ForegroundColor Red
    exit 1
}

# Função para obter o caminho do Steam do registro
function Get-SteamPath {
    $steamPath = $null
    
    Write-Host "Procurando pela instalação do Steam..." -ForegroundColor Gray
    
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
            Write-Host "  [ERRO] Conexão falhou: $_" -ForegroundColor Red
            Write-Host "  [ERRO] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Tempo de conexão ou falha ao conectar ao servidor"
        }
        
        # Verificar código de resposta
        $statusCode = [int]$response.StatusCode
        if ($statusCode -ne 200) {
            $response.Close()
            Write-Host "  [ERRO] Código de resposta inválido: $statusCode (esperado 200)" -ForegroundColor Red
            Write-Host "  [ERRO] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Servidor retornou o código de status $statusCode em vez de 200"
        }
        
        # Verificar comprimento do conteúdo
        $totalLength = $response.ContentLength
        if ($totalLength -eq 0) {
            $response.Close()
            Write-Host "  [ERRO] Comprimento do conteúdo inválido: $totalLength (esperado > 0 ou -1 para desconhecido)" -ForegroundColor Red
            Write-Host "  [ERRO] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Servidor retornou comprimento de conteúdo zero"
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
            Write-Host "  [ERRO] Falha na conexão de download: $_" -ForegroundColor Red
            Write-Host "  [ERRO] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Falha de conexão durante o download"
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
                        Write-Host "  [ERRO] Download travado (0 kbps por $stuckTimeoutSeconds segundos)" -ForegroundColor Red
                        Write-Host "  [ERRO] Baixado: $downloadedBytes bytes, Esperado: $totalLength bytes" -ForegroundColor Red
                        throw "Download travado - sem dados recebidos por $stuckTimeoutSeconds segundos"
                    }
                }
                
                # Atualizar progresso a cada 100ms
                if (($now - $lastUpdate).TotalMilliseconds -ge 100) {
                    if ($totalLength -gt 0) {
                        $percentComplete = [math]::Round(($downloadedBytes / $totalLength) * 100, 2)
                        Write-Host "`r  Progresso: $percentComplete% ($downloadedBytes bytes de $totalLength bytes)" -NoNewline -ForegroundColor Cyan
                    } else {
                        Write-Host "`r  Progresso: Baixando $downloadedBytes bytes..." -NoNewline -ForegroundColor Cyan
                    }
                    $lastUpdate = $now
                }
            }
            
            Write-Host "`r  Progresso: 100% Completo!" -ForegroundColor Green
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
        Write-Host "  [ERRO] Falha no download: $_" -ForegroundColor Red
        Write-Host "  [ERRO] Detalhes do erro: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        throw $_
    }
}

