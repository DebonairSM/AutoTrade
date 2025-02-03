function Build-EA {
    param(
        [string]$EaName = "V-2-EA-Main"
    )
    
    $eaDir = "C:\repos\debonairsm\AutoTrade\VTrade.Framework\applications\mql5\Experts\VSol"
    $mt5Dir = "C:\Users\Usuario\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\VSol"
    
    Write-Host "`nChanging to EA directory..." -ForegroundColor Yellow
    Set-Location $eaDir
    
    Write-Host "Compiling $EaName.mq5..." -ForegroundColor Yellow
    $output = & "C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"$EaName.mq5" /log
    if ($output) {
        Write-Host "`nCompilation Output:" -ForegroundColor Yellow
        Write-Host $output -ForegroundColor Red
    }
    
    if (Test-Path "$EaName.ex5") {
        Write-Host "`nCopying to MT5 directory..." -ForegroundColor Yellow
        Copy-Item "$EaName.ex5" -Destination $mt5Dir -Force
        Write-Host "Build completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "`nBuild failed - Check compilation errors above" -ForegroundColor Red
    }
}