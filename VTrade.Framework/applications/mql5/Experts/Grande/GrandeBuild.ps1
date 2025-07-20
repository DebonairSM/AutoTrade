param(
    [string]$ComponentName = "GrandeTradingSystem"
)

function Build-GrandeComponent {
    param(
        [string]$ComponentName = "GrandeTradingSystem"
    )
    
    Write-Host "=== Grande Build Script ===" -ForegroundColor Cyan
    Write-Host "Component: $ComponentName" -ForegroundColor White
    
    $sourceDir = "C:\Users\romme\source\repos\AutoTrade\VTrade.Framework\applications\mql5\Experts\Grande"
    $buildDir = Join-Path $sourceDir "Build"
    $mt5Dir = "C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Experts\Grande"
    
    Write-Host "Changing to Grande directory..." -ForegroundColor Yellow
    Set-Location $sourceDir
    
    # Create build directory
    if (-not (Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        Write-Host "Created build directory: $buildDir" -ForegroundColor Green
    }
    
    # Create MT5 directory
    if (-not (Test-Path $mt5Dir)) {
        New-Item -ItemType Directory -Path $mt5Dir -Force | Out-Null
        Write-Host "Created MT5 directory: $mt5Dir" -ForegroundColor Green
    }
    
    # Define components
    $components = @{
        "GrandeTradingSystem" = @{
            MainFile = "GrandeTradingSystem.mq5"
            Dependencies = @("GrandeMarketRegimeDetector.mqh", "GrandeKeyLevelDetector.mqh")
        }
        "GrandeMarketRegimeDetector" = @{
            MainFile = "GrandeMarketRegimeDetector.mqh"
            Dependencies = @()
        }
        "GrandeKeyLevelDetector" = @{
            MainFile = "GrandeKeyLevelDetector.mqh"
            Dependencies = @()
        }
    }
    
    if ($ComponentName -eq "All") {
        Write-Host "Building all components..." -ForegroundColor Yellow
        
        $componentOrder = @("GrandeMarketRegimeDetector", "GrandeKeyLevelDetector", "GrandeTradingSystem")
        
        foreach ($comp in $componentOrder) {
            Build-SingleComponent -Name $comp -Components $components -BuildDir $buildDir -Mt5Dir $mt5Dir
        }
        
        Write-Host "All components built and deployed successfully!" -ForegroundColor Green
    } else {
        Build-SingleComponent -Name $ComponentName -Components $components -BuildDir $buildDir -Mt5Dir $mt5Dir
    }
}

function Build-SingleComponent {
    param(
        [string]$Name,
        [hashtable]$Components,
        [string]$BuildDir,
        [string]$Mt5Dir
    )
    
    Write-Host "Building component: $Name" -ForegroundColor Yellow
    
    $component = $Components[$Name]
    if (-not $component) {
        Write-Host "Error: Unknown component $Name" -ForegroundColor Red
        return
    }
    
    $mainFile = $component.MainFile
    if (-not (Test-Path $mainFile)) {
        Write-Host "Error: Main file $mainFile not found!" -ForegroundColor Red
        return
    }
    
    $componentBuildDir = Join-Path $BuildDir $Name
    if (-not (Test-Path $componentBuildDir)) {
        New-Item -ItemType Directory -Path $componentBuildDir -Force | Out-Null
    }
    
    # Copy main file
    $destMainFile = Join-Path $componentBuildDir $mainFile
    Copy-Item -Path $mainFile -Destination $destMainFile -Force
    Write-Host "Copied: $mainFile" -ForegroundColor Green
    
    # Copy dependencies
    foreach ($dependency in $component.Dependencies) {
        if (Test-Path $dependency) {
            $destDepFile = Join-Path $componentBuildDir $dependency
            Copy-Item -Path $dependency -Destination $destDepFile -Force
            Write-Host "Copied dependency: $dependency" -ForegroundColor Green
        } else {
            Write-Host "Warning: Dependency $dependency not found" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Component $Name built successfully!" -ForegroundColor Green
    
    # Compile .mq5 to .ex5 if it's an Expert Advisor
    if ($mainFile -like "*.mq5") {
        Write-Host "Compiling $mainFile..." -ForegroundColor Yellow
        
        # Create a temporary log file
        $logFile = [System.IO.Path]::GetTempFileName()
        
        try {
            # Run MetaEditor with log file
            $process = Start-Process "C:\Program Files\FOREX.com US\MetaEditor64.exe" `
                -ArgumentList "/compile:`"$mainFile`"", "/log:`"$logFile`"" `
                -NoNewWindow -PassThru -Wait
            
            # Read and display the log content
            if (Test-Path $logFile) {
                $logContent = Get-Content $logFile -Raw
                if ($logContent) {
                    Write-Host "Compilation Output:" -ForegroundColor Yellow
                    Write-Host $logContent
                    
                    # Check for compilation errors
                    if ($logContent -match "(?m)^.*?\s*error\s*:") {
                        Write-Host "Compilation failed - Found errors in output" -ForegroundColor Red
                        return
                    }
                    
                    # Check if compilation was successful
                    if ($logContent -match "Result:\s*0\s*errors.*") {
                        Write-Host "Compilation successful!" -ForegroundColor Green
                        
                        # Deploy .ex5 file to MT5
                        $ex5File = $mainFile -replace "\.mq5$", ".ex5"
                        if (Test-Path $ex5File) {
                            $mt5Ex5File = Join-Path $mt5Dir $ex5File
                            Copy-Item -Path $ex5File -Destination $mt5Ex5File -Force
                            Write-Host "Deployed: $ex5File to MT5" -ForegroundColor Green
                        } else {
                            Write-Host "Warning: Compiled .ex5 file not found" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "Compilation failed - Unable to determine status" -ForegroundColor Red
                    }
                }
            }
        }
        finally {
            # Clean up the temporary log file
            if (Test-Path $logFile) {
                Remove-Item $logFile -Force
            }
        }
    }
    
    # Deploy source files to MT5
    Write-Host "Deploying source files to MT5..." -ForegroundColor Yellow
    
    # Copy main file to MT5
    $mt5MainFile = Join-Path $Mt5Dir $mainFile
    Copy-Item -Path $mainFile -Destination $mt5MainFile -Force
    Write-Host "Deployed: $mainFile to MT5" -ForegroundColor Green
    
    # Copy dependencies to MT5
    foreach ($dependency in $component.Dependencies) {
        if (Test-Path $dependency) {
            $mt5DepFile = Join-Path $Mt5Dir $dependency
            Copy-Item -Path $dependency -Destination $mt5DepFile -Force
            Write-Host "Deployed dependency: $dependency to MT5" -ForegroundColor Green
        }
    }
    
    Write-Host "Component $Name deployed to MT5 successfully!" -ForegroundColor Green
}

# Call the function with the provided parameter
Build-GrandeComponent -ComponentName $ComponentName 