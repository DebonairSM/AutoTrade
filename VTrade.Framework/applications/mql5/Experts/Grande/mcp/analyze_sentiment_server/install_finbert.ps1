# FinBERT Installation Script for Windows
# This script installs all dependencies needed for real FinBERT AI analysis
# Run this in PowerShell as Administrator

Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host "🤖 FinBERT Installation Script for Grande Trading System" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host ""

# Check if Python is installed
Write-Host "Checking for Python installation..." -ForegroundColor Cyan
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "Make sure to check Add Python to PATH during installation" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host "Installing FinBERT Dependencies" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will install:" -ForegroundColor White
Write-Host "  - PyTorch (Deep Learning Framework)" -ForegroundColor White
Write-Host "  - Transformers (HuggingFace Library)" -ForegroundColor White
Write-Host "  - NumPy (Numerical Computing)" -ForegroundColor White
Write-Host ""
Write-Host "This may take several minutes depending on your connection..." -ForegroundColor Yellow
Write-Host ""

# Upgrade pip first
Write-Host "Upgrading pip..." -ForegroundColor Cyan
python -m pip install --upgrade pip

# Install PyTorch (CPU version for compatibility)
Write-Host ""
Write-Host "Installing PyTorch (CPU version)..." -ForegroundColor Cyan
python -m pip install torch --index-url https://download.pytorch.org/whl/cpu

# Install Transformers
Write-Host ""
Write-Host "Installing Transformers library..." -ForegroundColor Cyan
python -m pip install transformers

# Install NumPy
Write-Host ""
Write-Host "Installing NumPy..." -ForegroundColor Cyan
python -m pip install numpy

# Verify installation
Write-Host ""
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host "Verifying Installation" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host ""

# Create temporary Python verification script
$tempPyScript = Join-Path $env:TEMP "finbert_verify.py"
$pythonCode = @'
import sys

print("Checking installed packages...")
print("")

try:
    import torch
    print("OK: PyTorch installed -", torch.__version__)
except ImportError as e:
    print("ERROR: PyTorch NOT installed -", str(e))
    sys.exit(1)

try:
    import transformers
    print("OK: Transformers installed -", transformers.__version__)
except ImportError as e:
    print("ERROR: Transformers NOT installed -", str(e))
    sys.exit(1)

try:
    import numpy
    print("OK: NumPy installed -", numpy.__version__)
except ImportError as e:
    print("ERROR: NumPy NOT installed -", str(e))
    sys.exit(1)

print("")
print("========================================================================")
print("SUCCESS: All dependencies installed!")
print("========================================================================")
print("")
print("Testing FinBERT model download...")
print("First download may take a few minutes...")
print("")

try:
    from transformers import AutoTokenizer, AutoModelForSequenceClassification
    model_name = "yiyanghkust/finbert-tone"
    print("Downloading FinBERT model:", model_name)
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(model_name)
    print("SUCCESS: FinBERT model downloaded and ready!")
    print("")
    print("========================================================================")
    print("INSTALLATION COMPLETE!")
    print("========================================================================")
    print("")
    print("Your Grande Trading System will now use REAL FinBERT AI analysis!")
    print("Look for these indicators in your EA logs:")
    print("  [OK] = Real FinBERT AI active")
    print("  [WARNING] = Fallback keyword analysis")
    print("  [ERROR] = Error or warning")
    print("")
except Exception as e:
    print("ERROR downloading FinBERT model:", str(e))
    print("")
    print("This might be due to:")
    print("  - Network connection issues")
    print("  - Firewall blocking downloads")
    print("  - Insufficient disk space")
    print("")
    sys.exit(1)
'@

# Write Python code to temp file
$pythonCode | Out-File -FilePath $tempPyScript -Encoding UTF8

# Run verification script
python $tempPyScript

# Clean up temp file
Remove-Item $tempPyScript -ErrorAction SilentlyContinue

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host "SUCCESS! FinBERT is now installed and ready!" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Restart your MT5 terminal if it is running" -ForegroundColor White
    Write-Host "2. Restart your EA" -ForegroundColor White
    Write-Host "3. Look for [OK] marks in logs to confirm FinBERT is active" -ForegroundColor White
    Write-Host "4. If you see [ERROR] warnings, check the log messages" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Red
    Write-Host "Installation encountered errors" -ForegroundColor Red
    Write-Host "========================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error messages above and try again." -ForegroundColor Yellow
    Write-Host "If problems persist, contact support with the error details." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


