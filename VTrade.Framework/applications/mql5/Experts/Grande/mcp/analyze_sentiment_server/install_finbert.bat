@echo off
REM FinBERT Installation Script for Windows (Batch version)
REM Double-click this file to install FinBERT dependencies

echo ========================================================================
echo    FinBERT Installation Script for Grande Trading System
echo ========================================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo.
    echo Please install Python from: https://www.python.org/downloads/
    echo Make sure to check 'Add Python to PATH' during installation
    echo.
    pause
    exit /b 1
)

echo Found Python installation
python --version
echo.

echo ========================================================================
echo    Installing FinBERT Dependencies
echo ========================================================================
echo.
echo This will install:
echo   - PyTorch (Deep Learning Framework^)
echo   - Transformers (HuggingFace Library^)
echo   - NumPy (Numerical Computing^)
echo   - Protobuf (Required by Transformers^)
echo.
echo This may take several minutes...
echo.
pause

REM Upgrade pip
echo.
echo Upgrading pip...
python -m pip install --upgrade pip

REM Install PyTorch (CPU version)
echo.
echo Installing PyTorch (CPU version^)...
python -m pip install torch --index-url https://download.pytorch.org/whl/cpu

REM Install Transformers
echo.
echo Installing Transformers library...
python -m pip install transformers

REM Install NumPy
echo.
echo Installing NumPy...
python -m pip install numpy

REM Install Protobuf (required by Transformers)
echo.
echo Installing Protobuf (required by Transformers^)...
python -m pip install protobuf

REM Test installation
echo.
echo ========================================================================
echo    Testing Installation
echo ========================================================================
echo.

python -c "import torch; import transformers; print('SUCCESS: All packages installed'); print('PyTorch version:', torch.__version__); print('Transformers version:', transformers.__version__)"

if %errorlevel% equ 0 (
    echo.
    echo ========================================================================
    echo    INSTALLATION COMPLETE!
    echo ========================================================================
    echo.
    echo Your Grande Trading System will now use REAL FinBERT AI analysis!
    echo.
    echo Look for these indicators in your EA logs:
    echo   [OK] = Real FinBERT AI active
    echo   [WARNING] = Fallback keyword analysis
    echo   [ERROR] = Error or problem
    echo.
    echo Next steps:
    echo   1. Restart your MT5 terminal if it's running
    echo   2. Restart your EA
    echo   3. Check logs for confirmation messages
    echo.
) else (
    echo.
    echo ========================================================================
    echo    ERROR: Installation failed
    echo ========================================================================
    echo.
    echo Please check the error messages above and try again.
    echo.
)

pause


