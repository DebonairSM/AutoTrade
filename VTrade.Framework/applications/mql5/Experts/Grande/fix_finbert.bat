@echo off
REM FinBERT Dependency Fix Script (Batch Wrapper)
REM This script calls the PowerShell fix script

echo ========================================================================
echo    FinBERT Dependency Fix Script
echo ========================================================================
echo.

cd /d "%~dp0"

if exist "mcp\analyze_sentiment_server\fix_finbert_dependencies.ps1" (
    echo Running FinBERT dependency fix script...
    echo.
    powershell -ExecutionPolicy Bypass -File "mcp\analyze_sentiment_server\fix_finbert_dependencies.ps1"
) else (
    echo ERROR: Fix script not found.
    echo.
    echo Please ensure you're running this from the Grande project root directory.
    echo.
    pause
    exit /b 1
)

pause

