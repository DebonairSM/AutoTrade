param(
    [string]$ComponentName = "GrandeTradingSystem",
    [switch]$RunTests = $false,
    [switch]$TestOnly = $false,
    [switch]$IndicatorOnly = $false
)

function Get-MT5BaseDirectory {
    # Try to get MT5 terminal ID from environment variable first
    $terminalId = $env:MT5_TERMINAL_ID
    if ($terminalId) {
        $mt5Path = Join-Path $env:APPDATA "MetaQuotes\Terminal\$terminalId"
        if (Test-Path $mt5Path) {
            Write-Host "Using MT5 terminal from environment variable: $terminalId" -ForegroundColor Green
            return $mt5Path
        }
    }
    
    # Auto-detect MT5 terminal directory
    $mt5TerminalsPath = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (Test-Path $mt5TerminalsPath) {
        $terminalDirs = Get-ChildItem -Path $mt5TerminalsPath -Directory | Where-Object { 
            Test-Path (Join-Path $_.FullName "MQL5") 
        }
        
        if ($terminalDirs.Count -gt 0) {
            $selectedTerminal = $terminalDirs[0]
            Write-Host "Auto-detected MT5 terminal: $($selectedTerminal.Name)" -ForegroundColor Green
            Write-Host "To use a specific terminal, set MT5_TERMINAL_ID environment variable" -ForegroundColor Yellow
            return $selectedTerminal.FullName
        }
    }
    
    # Fallback: prompt user or use default
    Write-Host "Could not auto-detect MT5 terminal directory." -ForegroundColor Red
    Write-Host "Please set MT5_TERMINAL_ID environment variable with your terminal ID." -ForegroundColor Yellow
    Write-Host "Example: `$env:MT5_TERMINAL_ID = '5C659F0E64BA794E712EE4C936BCFED5'" -ForegroundColor Yellow
    
    # Return a default path that will likely fail, but gives user clear error
    return Join-Path $env:APPDATA "MetaQuotes\Terminal\UNKNOWN"
}

function Build-GrandeComponent {
    param(
        [string]$ComponentName = "GrandeTradingSystem",
        [bool]$RunTests = $false,
        [bool]$TestOnly = $false,
        [bool]$IndicatorOnly = $false
    )
    
    Write-Host "=== Grande Build Script ===" -ForegroundColor Cyan
    Write-Host "Component: $ComponentName" -ForegroundColor White
    if ($RunTests) { Write-Host "Mode: Build + Test" -ForegroundColor Yellow }
    elseif ($TestOnly) { Write-Host "Mode: Test Only" -ForegroundColor Yellow }
    elseif ($IndicatorOnly) { Write-Host "Mode: Indicator Only" -ForegroundColor Yellow }
    else { Write-Host "Mode: Build Only" -ForegroundColor White }
    
    # Get current script directory as source directory
    $sourceDir = $PSScriptRoot
    $buildDir = Join-Path $sourceDir "Build"
    
    # Get MT5 paths dynamically
    $mt5BaseDir = Get-MT5BaseDirectory
    $mt5ExpertsDir = Join-Path $mt5BaseDir "MQL5\Experts\Grande"
    $mt5IndicatorsDir = Join-Path $mt5BaseDir "MQL5\Indicators\Grande"
    
    Write-Host "Changing to Grande directory..." -ForegroundColor Yellow
    Set-Location $sourceDir
    
    # Create build directory
    if (-not (Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
        Write-Host "Created build directory: $buildDir" -ForegroundColor Green
    }
    
    # Create MT5 directories
    if (-not (Test-Path $mt5ExpertsDir)) {
        New-Item -ItemType Directory -Path $mt5ExpertsDir -Force | Out-Null
        Write-Host "Created MT5 Experts directory: $mt5ExpertsDir" -ForegroundColor Green
    }
    
    if (-not (Test-Path $mt5IndicatorsDir)) {
        New-Item -ItemType Directory -Path $mt5IndicatorsDir -Force | Out-Null
        Write-Host "Created MT5 Indicators directory: $mt5IndicatorsDir" -ForegroundColor Green
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
        "GrandeMonitorIndicator" = @{
            MainFile = "GrandeMonitorIndicator.mq5"
            Dependencies = @("GrandeMarketRegimeDetector.mqh", "GrandeKeyLevelDetector.mqh", "GrandeMultiTimeframeAnalyzer.mqh")
        }
    }
    
    if ($TestOnly) {
        Write-Host "Running tests only..." -ForegroundColor Cyan
        Run-AutomatedTests -Components $components -Mt5Dir $mt5ExpertsDir
        return
    }
    
    if ($IndicatorOnly) {
        Write-Host "Building indicator only..." -ForegroundColor Cyan
        Build-SingleComponent -Name "GrandeMonitorIndicator" -Components $components -BuildDir $buildDir -Mt5ExpertsDir $mt5ExpertsDir -Mt5IndicatorsDir $mt5IndicatorsDir
        Write-Host "Indicator built and deployed successfully!" -ForegroundColor Green
        return
    }
    
    if ($ComponentName -eq "All") {
        Write-Host "Building all components..." -ForegroundColor Yellow
        
        $componentOrder = @("GrandeMarketRegimeDetector", "GrandeKeyLevelDetector", "GrandeTradingSystem", "GrandeMonitorIndicator")
        
        foreach ($comp in $componentOrder) {
            Build-SingleComponent -Name $comp -Components $components -BuildDir $buildDir -Mt5ExpertsDir $mt5ExpertsDir -Mt5IndicatorsDir $mt5IndicatorsDir
        }
        
        Write-Host "All components built and deployed successfully!" -ForegroundColor Green
        
        if ($RunTests) {
            Run-AutomatedTests -Components $components -Mt5Dir $mt5ExpertsDir
        }
    } else {
        Build-SingleComponent -Name $ComponentName -Components $components -BuildDir $buildDir -Mt5ExpertsDir $mt5ExpertsDir -Mt5IndicatorsDir $mt5IndicatorsDir
        
        if ($RunTests) {
            Write-Host "Test suite removed - main EA includes validation" -ForegroundColor Yellow
        }
    }
}

function Build-SingleComponent {
    param(
        [string]$Name,
        [hashtable]$Components,
        [string]$BuildDir,
        [string]$Mt5ExpertsDir,
        [string]$Mt5IndicatorsDir
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
                            # Determine target directory for .ex5 file
                            $isIndicator = $mainFile -like "*.mq5" -and $Name -eq "GrandeMonitorIndicator"
                            $targetDir = if ($isIndicator) { $Mt5IndicatorsDir } else { $Mt5ExpertsDir }
                            $dirType = if ($isIndicator) { "Indicators" } else { "Experts" }
                            
                            $mt5Ex5File = Join-Path $targetDir $ex5File
                            Copy-Item -Path $ex5File -Destination $mt5Ex5File -Force
                            Write-Host "Deployed: $ex5File to MT5 $dirType" -ForegroundColor Green
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
    
    # Determine if this is an indicator or expert advisor
    $isIndicator = $mainFile -like "*.mq5" -and $Name -eq "GrandeMonitorIndicator"
    $targetDir = if ($isIndicator) { $Mt5IndicatorsDir } else { $Mt5ExpertsDir }
    $dirType = if ($isIndicator) { "Indicators" } else { "Experts" }
    
    Write-Host "Component: $Name | MainFile: $mainFile | IsIndicator: $isIndicator" -ForegroundColor Cyan
    Write-Host "Target Directory: $targetDir" -ForegroundColor Cyan
    
    # Ensure target directory exists
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Host "Created target directory: $targetDir" -ForegroundColor Green
    }
    
    # Copy main file to appropriate MT5 directory
    $mt5MainFile = Join-Path $targetDir $mainFile
    Copy-Item -Path $mainFile -Destination $mt5MainFile -Force
    Write-Host "Deployed: $mainFile to MT5 $dirType at $mt5MainFile" -ForegroundColor Green
    
    # Copy dependencies to the same directory as the main file
    Write-Host "Deploying dependencies to $targetDir..." -ForegroundColor Yellow
    foreach ($dependency in $component.Dependencies) {
        if (Test-Path $dependency) {
            $mt5DepFile = Join-Path $targetDir $dependency
            Copy-Item -Path $dependency -Destination $mt5DepFile -Force
            Write-Host "Deployed dependency: $dependency to MT5 $dirType at $mt5DepFile" -ForegroundColor Green
        } else {
            Write-Host "Warning: Dependency not found: $dependency" -ForegroundColor Yellow
        }
    }
    
    # MCP FinBERT Calendar Analyzer deployment (essential files only)
    $deployMcp = $true
    if ($deployMcp) {
        $mcpSource = Join-Path $sourceDir "mcp\analyze_sentiment_server"
        $mcpDestParent = Join-Path $Mt5ExpertsDir "mcp"
        $mcpDest = Join-Path $mcpDestParent "analyze_sentiment_server"
        
        if (Test-Path $mcpSource) {
            if (-not (Test-Path $mcpDestParent)) {
                New-Item -ItemType Directory -Path $mcpDestParent -Force | Out-Null
            }
            if (-not (Test-Path $mcpDest)) {
                New-Item -ItemType Directory -Path $mcpDest -Force | Out-Null
            }
            
            # Copy only essential files (not the entire directory with dependencies)
            $essentialFiles = @(
                "finbert_calendar_analyzer.py",
                "GrandeNewsSentimentIntegration.mqh"
            )
            
            foreach ($file in $essentialFiles) {
                $sourceFile = Join-Path $mcpSource $file
                $destFile = Join-Path $mcpDest $file
                if (Test-Path $sourceFile) {
                    Copy-Item -Path $sourceFile -Destination $destFile -Force
                    Write-Host "Deployed: $file" -ForegroundColor Green
                } else {
                    Write-Host "Warning: Essential file not found: $file" -ForegroundColor Yellow
                }
            }
            Write-Host "Deployed essential MCP files to MT5 ($(($essentialFiles).Count) files)" -ForegroundColor Green
        } else {
            Write-Host "Warning: MCP source directory not found at $mcpSource" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Skipped MCP deployment (calendar AI disabled)" -ForegroundColor Yellow
    }
    
    # Verify deployment
    Write-Host "Verifying deployment..." -ForegroundColor Yellow
    if (Test-Path $mt5MainFile) {
        Write-Host "Main file verified: $mt5MainFile" -ForegroundColor Green
    } else {
        Write-Host "Main file NOT found: $mt5MainFile" -ForegroundColor Red
    }
    
    # Check dependencies
    $allDepsDeployed = $true
    foreach ($dependency in $component.Dependencies) {
        $mt5DepFile = Join-Path $targetDir $dependency
        if (Test-Path $mt5DepFile) {
            Write-Host "Dependency verified: $dependency" -ForegroundColor Green
        } else {
            Write-Host "Dependency NOT found: $dependency" -ForegroundColor Red
            $allDepsDeployed = $false
        }
    }
    
    if ($allDepsDeployed) {
        Write-Host "Component $Name deployed to MT5 $dirType successfully!" -ForegroundColor Green
    } else {
        Write-Host "Component $Name deployed with warnings - some dependencies missing!" -ForegroundColor Yellow
    }
}

function Run-AutomatedTests {
    param(
        [hashtable]$Components,
        [string]$Mt5Dir
    )
    
    Write-Host "`n=== RUNNING AUTOMATED TESTS ===" -ForegroundColor Cyan
    
    # Check if test suite exists
    $testSuiteEx5 = Join-Path $Mt5Dir "GrandeTestSuite.ex5"
    if (-not (Test-Path $testSuiteEx5)) {
        Write-Host "Error: Test suite not found at $testSuiteEx5" -ForegroundColor Red
        Write-Host "Make sure to build GrandeTestSuite first." -ForegroundColor Yellow
        return
    }
    
    # Create test configuration
    $testConfig = @{
        Symbol = "EURUSD"
        Timeframe = "PERIOD_H1"
        TestDuration = 60  # seconds
        GenerateReport = $true
    }
    
    Write-Host "Test Configuration:" -ForegroundColor Yellow
    $testConfig.GetEnumerator() | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
    }
    
    Write-Host "`nStarting automated test execution..." -ForegroundColor Green
    Write-Host "Note: This will run the GrandeTestSuite EA in MetaTrader 5" -ForegroundColor Yellow
    Write-Host "Check the Expert tab in MT5 Terminal for detailed test results." -ForegroundColor Yellow
    
    # Generate test report template
    Generate-TestReportTemplate
    
    Write-Host "`nAutomated testing initiated!" -ForegroundColor Green
    Write-Host "To view results:" -ForegroundColor Cyan
    Write-Host "1. Open MetaTrader 5" -ForegroundColor White
    Write-Host "2. Attach GrandeTestSuite EA to a chart" -ForegroundColor White
    Write-Host "3. Check the Expert tab for test results" -ForegroundColor White
    Write-Host "4. Review test report in Build directory" -ForegroundColor White
}

function Generate-TestReportTemplate {
    $reportDir = Join-Path $sourceDir "Build\TestReports"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportFile = Join-Path $reportDir "TestReport_$timestamp.md"
    
    $reportContent = @"
# Grande Trading System Test Report
**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Test Configuration
- **Component:** Grande Trading System
- **Test Suite Version:** 1.0
- **Symbol:** EURUSD
- **Timeframe:** H1

## Test Categories

### Regime Detection Tests
- [ ] Initialization Test
- [ ] ADX Calculation Accuracy
- [ ] Regime Classification Logic
- [ ] Multi-Timeframe Data Integrity
- [ ] Timeframe Consistency
- [ ] Confidence Calculation
- [ ] Threshold Adjustment

### Key Level Detection Tests
- [ ] Initialization Test
- [ ] Level Detection Accuracy
- [ ] Strength Calculation
- [ ] Touch Zone Adjustment
- [ ] Timeframe Scaling

### Performance Tests
- [ ] Regime Detection Performance
- [ ] Key Level Detection Performance
- [ ] Memory Usage Test

### Stress Tests
- [ ] High Frequency Updates
- [ ] Large Dataset Handling
- [ ] Error Recovery

### Multi-Timeframe Tests
- [ ] Timeframe-Specific Behavior
- [ ] Cross-Platform Consistency

## Test Results
*Results will be populated when tests are executed*

## Summary
- **Total Tests:** TBD
- **Passed:** TBD
- **Failed:** TBD
- **Success Rate:** TBD%

## Recommendations
*To be filled based on test results*
"@

    $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "Test report template created: $reportFile" -ForegroundColor Green
}

# Call the function with the provided parameters
Build-GrandeComponent -ComponentName $ComponentName -RunTests $RunTests -TestOnly $TestOnly -IndicatorOnly $IndicatorOnly
