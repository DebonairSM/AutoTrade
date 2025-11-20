# FinBERT Dependency Fix Script Wrapper
# This script calls the main fix script from the correct location

$scriptPath = Join-Path $PSScriptRoot "mcp\analyze_sentiment_server\fix_finbert_dependencies.ps1"

if (Test-Path $scriptPath) {
    Write-Host "Running FinBERT dependency fix script..." -ForegroundColor Cyan
    Write-Host ""
    & $scriptPath
} else {
    Write-Host "ERROR: Fix script not found at: $scriptPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure you're running this from the Grande project root directory." -ForegroundColor Yellow
    Write-Host "Or run the script directly from its location:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File `"mcp\analyze_sentiment_server\fix_finbert_dependencies.ps1`"" -ForegroundColor White
    exit 1
}

