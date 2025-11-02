# Set MT5 Environment Variable Script
# This script helps you set the MT5_TERMINAL_ID environment variable

param(
    [string]$TerminalId = ""
)

function Show-AvailableTerminals {
    Write-Host "Available MT5 Terminal IDs:" -ForegroundColor Cyan
    $mt5TerminalsPath = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    
    if (Test-Path $mt5TerminalsPath) {
        $terminalDirs = Get-ChildItem -Path $mt5TerminalsPath -Directory | Where-Object { 
            Test-Path (Join-Path $_.FullName "MQL5") 
        }
        
        if ($terminalDirs.Count -gt 0) {
            foreach ($terminal in $terminalDirs) {
                Write-Host "  - $($terminal.Name)" -ForegroundColor White
            }
        } else {
            Write-Host "  No MT5 terminals found with MQL5 directory" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  MT5 terminals directory not found at: $mt5TerminalsPath" -ForegroundColor Red
    }
}

function Set-TerminalId {
    param([string]$Id)
    
    if (-not $Id) {
        Write-Host "Please provide a terminal ID." -ForegroundColor Red
        Show-AvailableTerminals
        return
    }
    
    # Validate the terminal ID exists
    $mt5Path = Join-Path $env:APPDATA "MetaQuotes\Terminal\$Id"
    if (-not (Test-Path $mt5Path)) {
        Write-Host "Terminal ID '$Id' not found!" -ForegroundColor Red
        Show-AvailableTerminals
        return
    }
    
    # Set environment variable for current session
    $env:MT5_TERMINAL_ID = $Id
    Write-Host "MT5_TERMINAL_ID set to: $Id" -ForegroundColor Green
    
    # Offer to set it permanently
    $response = Read-Host "Set this permanently for your user account? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        [Environment]::SetEnvironmentVariable("MT5_TERMINAL_ID", $Id, "User")
        Write-Host "MT5_TERMINAL_ID set permanently for user account" -ForegroundColor Green
        Write-Host "Restart PowerShell for the change to take effect in new sessions" -ForegroundColor Yellow
    }
}

Write-Host "=== MT5 Environment Setup ===" -ForegroundColor Cyan

if ($TerminalId) {
    Set-TerminalId -Id $TerminalId
} else {
    Show-AvailableTerminals
    Write-Host ""
    $input = Read-Host "Enter terminal ID to use (or press Enter to skip)"
    if ($input) {
        Set-TerminalId -Id $input
    }
}

Write-Host ""
Write-Host "Current MT5_TERMINAL_ID: $($env:MT5_TERMINAL_ID)" -ForegroundColor Cyan
Write-Host "Usage: .\Set-MT5Environment.ps1 -TerminalId 'YOUR_TERMINAL_ID'" -ForegroundColor Yellow
