function Wait-ForBuildComplete {
    param(
        [string]$FilePath,
        [int]$TimeoutSeconds = 30
    )
    
    $startTime = Get-Date
    $lastWriteTime = $null
    
    Write-Host "Waiting for build to complete..." -ForegroundColor Yellow
    
    while ($true) {
        if ((Get-Date).Subtract($startTime).TotalSeconds -gt $TimeoutSeconds) {
            Write-Host "Build timeout after $TimeoutSeconds seconds" -ForegroundColor Red
            return $false
        }
        
        if (Test-Path $FilePath) {
            $currentWriteTime = (Get-Item $FilePath).LastWriteTime
            
            if ($lastWriteTime -ne $null -and $currentWriteTime -eq $lastWriteTime) {
                # File hasn't changed in the last second, assume build is complete
                Start-Sleep -Seconds 1  # Give one extra second for good measure
                return $true
            }
            
            $lastWriteTime = $currentWriteTime
        }
        
        Start-Sleep -Milliseconds 500
    }
}

function Build-EA {
    param(
        [string]$EaName = "V-2-EA-Main"
    )
    
    # Script version tracking
    $scriptVersion = "1.0.3"
    $scriptDate = "2024-03-19"
    Write-Host "`n=== Build-EA Script v$scriptVersion ($scriptDate) ===" -ForegroundColor Cyan
    Write-Host "Changes: Fixed regex pattern for compilation success detection" -ForegroundColor DarkCyan
    
    $eaDir = "C:\repos\debonairsm\AutoTrade\VTrade.Framework\applications\mql5\Experts\VSol"
    $mt5Dir = "C:\Users\Usuario\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VSol"
    $mt5Dir2 = "C:\Users\Usuario\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E\MQL5\Experts\VSol"
    $mt5Dir3 = "C:\Users\Usuario\AppData\Roaming\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Experts\VSol"
    
    Write-Host "`nChanging to EA directory..." -ForegroundColor Yellow
    Set-Location $eaDir
    
    # Verify source file exists
    if (-not (Test-Path "$EaName.mq5")) {
        Write-Host "`nError: Source file $EaName.mq5 not found!" -ForegroundColor Red
        return
    }
    
    Write-Host "Compiling $EaName.mq5..." -ForegroundColor Yellow
    
    # Create a temporary log file
    $logFile = [System.IO.Path]::GetTempFileName()
    
    try {
        # Run MetaEditor with log file
        $process = Start-Process "C:\Program Files\MetaTrader 5\metaeditor64.exe" `
            -ArgumentList "/compile:`"$EaName.mq5`"", "/log:`"$logFile`"" `
            -NoNewWindow -PassThru -Wait
        
        # Read and display the log content
        if (Test-Path $logFile) {
            $logContent = Get-Content $logFile -Raw
            if ($logContent) {
                Write-Host "`nCompilation Output:" -ForegroundColor Yellow
                Write-Host $logContent
                
                # Check for actual compilation errors first
                if ($logContent -match "(?m)^.*?\s*error\s*:") {
                    Write-Host "`nCompilation failed - Found errors in output" -ForegroundColor Red
                    return
                }
                
                # Check if compilation was successful by looking for the Result line
                if ($logContent -match "Result:\s*0\s*errors.*") {
                    Write-Host "`nCompilation successful!" -ForegroundColor Green
                    Write-Host "Copying to MT5 directories..." -ForegroundColor Yellow
                    
                    # Create directories if they don't exist
                    @($mt5Dir, $mt5Dir2, $mt5Dir3) | ForEach-Object {
                        if (-not (Test-Path $_)) {
                            New-Item -ItemType Directory -Path $_ -Force | Out-Null
                            Write-Host "Created directory: $_" -ForegroundColor DarkYellow
                        }
                    }
                    
                    # Copy files and verify each copy
                    $copySuccess = $true
                    @($mt5Dir, $mt5Dir2, $mt5Dir3) | ForEach-Object {
                        $targetPath = Join-Path $_ "$EaName.ex5"
                        try {
                            Copy-Item "$EaName.ex5" -Destination $targetPath -Force
                            if (Test-Path $targetPath) {
                                Write-Host "Copied to: $targetPath" -ForegroundColor DarkGreen
                            } else {
                                Write-Host "Failed to verify copy at: $targetPath" -ForegroundColor Red
                                $copySuccess = $false
                            }
                        } catch {
                            Write-Host "Error copying to: $targetPath" -ForegroundColor Red
                            Write-Host $_.Exception.Message -ForegroundColor Red
                            $copySuccess = $false
                        }
                    }
                    
                    if ($copySuccess) {
                        Write-Host "`nBuild completed successfully!" -ForegroundColor Green
                    } else {
                        Write-Host "`nBuild completed but some files failed to copy" -ForegroundColor Yellow
                    }
                    return
                }
            }
        }
        
        Write-Host "`nBuild failed - Unable to determine compilation status" -ForegroundColor Red
    }
    finally {
        # Clean up the temporary log file
        if (Test-Path $logFile) {
            Remove-Item $logFile -Force
        }
    }
}