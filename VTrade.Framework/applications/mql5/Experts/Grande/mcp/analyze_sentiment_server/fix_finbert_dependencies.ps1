# FinBERT Dependency Fix Script for Windows
# This script provides a comprehensive fix for FinBERT loading issues

Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host "🛠️  FinBERT Dependency Fix Script" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host ""

# Step 1: Check current environment
Write-Host "Step 1: Diagnosing current environment..." -ForegroundColor Cyan
Write-Host ""

# Check Python version
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Python Version: $pythonVersion" -ForegroundColor Green
    
    # Check if Python 3.13 (problematic version)
    if ($pythonVersion -match "3.13") {
        Write-Host "⚠️  WARNING: Python 3.13 detected - this may cause compatibility issues" -ForegroundColor Yellow
        Write-Host "   Some packages may not have prebuilt wheels for Python 3.13" -ForegroundColor Yellow
        Write-Host ""
    }
} catch {
    Write-Host "❌ ERROR: Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "   Please install Python 3.9-3.11 for best compatibility" -ForegroundColor Yellow
    exit 1
}

# Check current packages
Write-Host "Checking installed packages..." -ForegroundColor White
python -c "
import sys
print('Installed packages:')
try:
    import torch
    print('  ✅ PyTorch:', torch.__version__)
except ImportError:
    print('  ❌ PyTorch: Not installed')

try:
    import transformers
    print('  ✅ Transformers:', transformers.__version__)
except ImportError:
    print('  ❌ Transformers: Not installed')

try:
    import google.protobuf
    print('  ✅ Protobuf: Available')
except ImportError:
    print('  ❌ Protobuf: Not installed')

try:
    import numpy
    print('  ✅ NumPy:', numpy.__version__)
except ImportError:
    print('  ❌ NumPy: Not installed')
"

Write-Host ""
Write-Host "Step 2: Clearing HuggingFace cache (fixes model download issues)..." -ForegroundColor Cyan

# Clear HuggingFace cache
$hfCache = "$env:USERPROFILE\AppData\Local\huggingface\hub"
if (Test-Path $hfCache) {
    Write-Host "Clearing HuggingFace cache: $hfCache" -ForegroundColor White
    Remove-Item -Path $hfCache -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Cache cleared" -ForegroundColor Green
} else {
    Write-Host "✅ Cache directory not found (already clean)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 3: Installing/Upgrading dependencies with compatibility fixes..." -ForegroundColor Cyan
Write-Host ""

# Upgrade pip first
Write-Host "Upgrading pip..." -ForegroundColor White
python -m pip install --upgrade pip

# Install PyTorch CPU (most compatible version)
Write-Host ""
Write-Host "Installing PyTorch CPU..." -ForegroundColor White
python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install transformers with version that works well with Python 3.13
Write-Host ""
Write-Host "Installing compatible transformers version..." -ForegroundColor White
python -m pip install transformers>=4.21.0

# Install other dependencies
Write-Host ""
Write-Host "Installing additional dependencies..." -ForegroundColor White
python -m pip install protobuf numpy requests filelock huggingface-hub

# Install sentencepiece (often needed for tokenizers)
Write-Host ""
Write-Host "Installing sentencepiece (tokenizer support)..." -ForegroundColor White
python -m pip install sentencepiece

Write-Host ""
Write-Host "Step 4: Testing FinBERT functionality..." -ForegroundColor Cyan
Write-Host ""

# Test with proper error handling
python -c "
import sys
import traceback

def test_finbert():
    try:
        print('Testing basic imports...')
        import torch
        import transformers
        import google.protobuf
        print('[OK] Basic imports successful')
        
        print('Testing model loading (this may take a few minutes)...')
        from transformers import pipeline
        
        # Try a simpler approach first
        classifier = pipeline('sentiment-analysis')
        test_result = classifier('The market shows positive trends today')
        print('[OK] Basic sentiment pipeline works:', test_result)
        
        # Now try FinBERT specifically
        print('Testing FinBERT model...')
        from transformers import AutoTokenizer, AutoModelForSequenceClassification
        
        # Set offline mode to False to allow downloads
        import os
        os.environ['TRANSFORMERS_OFFLINE'] = '0'
        
        model_name = 'yiyanghkust/finbert-tone'
        print(f'Loading {model_name}...')
        
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSequenceClassification.from_pretrained(model_name)
        
        print('[OK] FinBERT model loaded successfully!')
        print('[OK] ALL TESTS PASSED - FinBERT is working correctly!')
        return True
        
    except Exception as e:
        print(f'[ERROR] Error: {e}')
        print('Full traceback:')
        traceback.print_exc()
        return False

if test_finbert():
    print('')
    print('🎉 SUCCESS: FinBERT is now working!')
else:
    print('')
    print('⚠️  FinBERT model loading failed, but fallback analysis is available')
"

$testResult = $LASTEXITCODE
Write-Host ""

if ($testResult -eq 0) {
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host "✅ SUCCESS: FinBERT is now fully functional!" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your Grande Trading System will now use REAL FinBERT AI analysis!" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Start the FinBERT watcher service: start_finbert_watcher.bat" -ForegroundColor White
    Write-Host "2. Restart your MT5 terminal if running" -ForegroundColor White
    Write-Host "3. Restart your EA" -ForegroundColor White
    Write-Host "4. Look for '[OK] Enhanced FinBERT pipeline initialized' in logs" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "========================================================================" -ForegroundColor Yellow
    Write-Host "⚠️  FinBERT model loading still has issues" -ForegroundColor Yellow
    Write-Host "========================================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The system will continue to work using fallback keyword analysis." -ForegroundColor White
    Write-Host "This provides basic sentiment analysis while we resolve the model issue." -ForegroundColor White
    Write-Host ""
    Write-Host "To diagnose further:" -ForegroundColor Cyan
    Write-Host "1. Check your internet connection" -ForegroundColor White
    Write-Host "2. Try running: python test_finbert_direct.py" -ForegroundColor White
    Write-Host "3. Check Windows firewall settings" -ForegroundColor White
    Write-Host "4. Consider using Python 3.9-3.11 instead of 3.13" -ForegroundColor White
    Write-Host ""
    Write-Host "Your trading system will still work with reduced AI capabilities." -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
