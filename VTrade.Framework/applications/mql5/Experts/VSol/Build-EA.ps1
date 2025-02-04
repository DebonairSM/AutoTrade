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
    
    $eaDir = "C:\repos\debonairsm\AutoTrade\VTrade.Framework\applications\mql5\Experts\VSol"
    $mt5Dir = "C:\Users\Usuario\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VSol"
    $mt5Dir2 = "C:\Users\Usuario\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E\MQL5\Experts\VSol"
    $mt5Dir3 = "C:\Users\Usuario\AppData\Roaming\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Experts\VSol"
    
    Write-Host "`nChanging to EA directory..." -ForegroundColor Yellow
    Set-Location $eaDir
    
    Write-Host "Compiling $EaName.mq5..." -ForegroundColor Yellow
    $output = & "C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"$EaName.mq5" /log
    if ($output) {
        Write-Host "`nCompilation Output:" -ForegroundColor Yellow
        Write-Host $output -ForegroundColor Red
    }
    
    $buildComplete = Wait-ForBuildComplete -FilePath "$EaName.ex5"
    
    if ($buildComplete -and (Test-Path "$EaName.ex5")) {
        Write-Host "`nCopying to MT5 directories..." -ForegroundColor Yellow
        Copy-Item "$EaName.ex5" -Destination $mt5Dir -Force
        Copy-Item "$EaName.ex5" -Destination $mt5Dir2 -Force
        Copy-Item "$EaName.ex5" -Destination $mt5Dir3 -Force
        Write-Host "Build completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`nBuild failed - Check compilation errors above" -ForegroundColor Red
    }
}