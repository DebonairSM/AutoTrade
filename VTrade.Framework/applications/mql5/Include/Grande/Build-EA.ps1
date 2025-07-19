param(
    [string]$HeaderName = "VMarketRegimeDetector",
    [string]$ProjectName = "Grande",
    [switch]$ValidateOnly,
    [switch]$Verbose
)

function Write-ScriptHeader {
    param([string]$version, [string]$date)
    
    Write-Host ""
    Write-Host "=== Header Publisher Script v$version ($date) ===" -ForegroundColor Cyan
    Write-Host "Purpose: Publish MQL5 header files to MetaTrader 5 Include directories" -ForegroundColor DarkCyan
    Write-Host "Target: $HeaderName.mqh for $ProjectName project" -ForegroundColor DarkCyan
}

function Test-HeaderSyntax {
    param(
        [string]$HeaderPath,
        [string]$TempDir
    )
    
    Write-Host "Validating header file syntax..." -ForegroundColor Yellow
    
    # Create a temporary test EA that includes the header
    $testEAContent = @"
//+------------------------------------------------------------------+
//| Temporary Test EA for Header Validation                         |
//+------------------------------------------------------------------+
#property copyright "Test"
#property version   "1.00"

#include <$ProjectName/$HeaderName.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("Header validation test");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Test basic functionality
}
"@

    $testEAPath = Join-Path $TempDir "TestHeader_$HeaderName.mq5"
    
    try {
        # Write test EA file
        $testEAContent | Out-File -FilePath $testEAPath -Encoding UTF8
        
        # Attempt compilation
        $logFile = [System.IO.Path]::GetTempFileName()
        $process = Start-Process "C:\Program Files\FOREX.com US\MetaEditor64.exe" `
            -ArgumentList "/compile:`"$testEAPath`"", "/log:`"$logFile`"" `
            -NoNewWindow -PassThru -Wait
        
        # Check compilation result
        if (Test-Path $logFile) {
            $logContent = Get-Content $logFile -Raw
            
            if ($Verbose -and $logContent) {
                Write-Host ""
                Write-Host "Compilation Output:" -ForegroundColor DarkYellow
                Write-Host $logContent
            }
            
            # Check for compilation errors
            if ($logContent -match "(?m)^.*?\s*error\s*:") {
                Write-Host "Header validation failed - Found syntax errors" -ForegroundColor Red
                if (!$Verbose) {
                    Write-Host $logContent -ForegroundColor Red
                }
                return $false
            }
            
            if ($logContent -match "Result:\s*0\s*errors.*") {
                Write-Host "Header syntax validation passed!" -ForegroundColor Green
                return $true
            }
        }
        
        Write-Host "Header validation inconclusive - unable to determine result" -ForegroundColor Yellow
        return $false
    }
    finally {
        # Clean up temporary files
        if (Test-Path $testEAPath) { Remove-Item $testEAPath -Force }
        if (Test-Path $logFile) { Remove-Item $logFile -Force }
        
        # Clean up compiled test file if it exists
        $testEXPath = $testEAPath -replace "\.mq5$", ".ex5"
        if (Test-Path $testEXPath) { Remove-Item $testEXPath -Force }
    }
}

function Copy-HeaderToTargets {
    param(
        [string]$SourcePath,
        [string[]]$TargetDirs,
        [string]$ProjectSubDir
    )
    
    Write-Host "Publishing header file to MetaTrader 5 directories..." -ForegroundColor Yellow
    
    $copySuccess = $true
    $successCount = 0
    
    foreach ($targetDir in $TargetDirs) {
        $projectDir = Join-Path $targetDir $ProjectSubDir
        $targetPath = Join-Path $projectDir "$HeaderName.mqh"
        
        try {
            # Create project directory if it doesn't exist
            if (-not (Test-Path $projectDir)) {
                New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
                Write-Host "Created directory: $projectDir" -ForegroundColor DarkYellow
            }
            
            # Copy header file
            Copy-Item $SourcePath -Destination $targetPath -Force
            
            # Verify copy
            if (Test-Path $targetPath) {
                $sourceSize = (Get-Item $SourcePath).Length
                $targetSize = (Get-Item $targetPath).Length
                
                if ($sourceSize -eq $targetSize) {
                    Write-Host "[OK] Published to: $targetPath" -ForegroundColor DarkGreen
                    $successCount++
                } else {
                    Write-Host "[ERROR] File size mismatch at: $targetPath" -ForegroundColor Red
                    $copySuccess = $false
                }
            } else {
                Write-Host "[ERROR] Failed to verify copy at: $targetPath" -ForegroundColor Red
                $copySuccess = $false
            }
        }
        catch {
            Write-Host "[ERROR] Error copying to: $targetPath" -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            $copySuccess = $false
        }
    }
    
    return @{
        Success = $copySuccess
        Count = $successCount
        Total = $TargetDirs.Count
    }
}

function Publish-Header {
    param(
        [string]$HeaderName,
        [string]$ProjectName
    )
    
    # Script version tracking
    $scriptVersion = "2.0.1"
    $scriptDate = "2024-12-19"
    Write-ScriptHeader -version $scriptVersion -date $scriptDate
    
    # Define paths
    $sourceDir = "C:\Users\romme\source\repos\AutoTrade\VTrade.Framework\applications\mql5\Include\$ProjectName"
    $mt5IncludeDir = "C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Include"
    
    # Target directories for header deployment
    $targetDirs = @($mt5IncludeDir)
    
    Write-Host ""
    Write-Host "Source directory: $sourceDir" -ForegroundColor Gray
    Write-Host "Target directories: $($targetDirs.Count) MT5 Include folder(s)" -ForegroundColor Gray
    
    # Change to source directory
    if (-not (Test-Path $sourceDir)) {
        Write-Host ""
        Write-Host "Error: Source directory not found: $sourceDir" -ForegroundColor Red
        return
    }
    
    Set-Location $sourceDir
    
    # Verify source header file exists
    $sourceHeaderPath = "$HeaderName.mqh"
    if (-not (Test-Path $sourceHeaderPath)) {
        Write-Host ""
        Write-Host "Error: Header file $sourceHeaderPath not found!" -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "Found header file: $sourceHeaderPath" -ForegroundColor Green
    
    # Get file info
    $fileInfo = Get-Item $sourceHeaderPath
    Write-Host "File size: $($fileInfo.Length) bytes" -ForegroundColor Gray
    Write-Host "Last modified: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
    
    # Validate syntax if not in validate-only mode
    if ($ValidateOnly -or $Verbose) {
        $tempDir = $env:TEMP
        $syntaxValid = Test-HeaderSyntax -HeaderPath $sourceHeaderPath -TempDir $tempDir
        
        if ($ValidateOnly) {
            if ($syntaxValid) {
                Write-Host ""
                Write-Host "Validation completed successfully!" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "Validation failed!" -ForegroundColor Red
            }
            return
        }
        
        if (-not $syntaxValid) {
            Write-Host ""
            Write-Host "Warning: Syntax validation failed, but continuing with publish..." -ForegroundColor Yellow
        }
    }
    
    # Copy header to target directories
    $result = Copy-HeaderToTargets -SourcePath $sourceHeaderPath -TargetDirs $targetDirs -ProjectSubDir $ProjectName
    
    # Report results
    if ($result.Success -and $result.Count -eq $result.Total) {
        Write-Host ""
        Write-Host "SUCCESS: Header published successfully!" -ForegroundColor Green
        Write-Host "   $($result.Count)/$($result.Total) directories updated" -ForegroundColor DarkGreen
        Write-Host ""
        Write-Host "Usage in your EAs:" -ForegroundColor Cyan
        Write-Host "   #include <$ProjectName/$HeaderName.mqh>" -ForegroundColor White
    }
    elseif ($result.Count -gt 0) {
        Write-Host ""
        Write-Host "WARNING: Header partially published" -ForegroundColor Yellow
        Write-Host "   $($result.Count)/$($result.Total) directories updated" -ForegroundColor DarkYellow
    }
    else {
        Write-Host ""
        Write-Host "ERROR: Header publish failed!" -ForegroundColor Red
        Write-Host "   No directories were successfully updated" -ForegroundColor DarkRed
    }
}

# Main execution
try {
    if ($ValidateOnly) {
        Write-Host "Running in validation-only mode..." -ForegroundColor Yellow
    }
    
    Publish-Header -HeaderName $HeaderName -ProjectName $ProjectName
}
catch {
    Write-Host ""
    Write-Host "ERROR: Script execution failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($Verbose) {
        Write-Host ""
        Write-Host "Script execution completed." -ForegroundColor Gray
    }
}