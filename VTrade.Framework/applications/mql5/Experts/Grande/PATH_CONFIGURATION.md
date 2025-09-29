# Path Configuration Guide

This guide explains how the Grande trading system handles MetaTrader 5 paths dynamically.

## Overview

The Grande build system has been updated to automatically detect MetaTrader 5 installation paths instead of using hardcoded paths. This makes the system portable across different users and MT5 installations.

## How It Works

### 1. Automatic Detection
The build script automatically detects your MT5 terminal directory by:
1. Looking for the first directory in `%APPDATA%\MetaQuotes\Terminal\` that contains an `MQL5` folder
2. Using that directory as the base for all MT5 operations

### 2. Environment Variable Override
You can specify a specific terminal ID using the `MT5_TERMINAL_ID` environment variable:
```powershell
$env:MT5_TERMINAL_ID = "5C659F0E64BA794E712EE4C936BCFED5"
```

### 3. Path Structure
The system constructs paths as follows:
- **Base MT5 Directory**: `%APPDATA%\MetaQuotes\Terminal\{TERMINAL_ID}\`
- **Experts Directory**: `{BASE_DIR}\MQL5\Experts\Grande\`
- **Indicators Directory**: `{BASE_DIR}\MQL5\Indicators\Grande\`
- **Files Directory**: `{BASE_DIR}\MQL5\Files\`
- **Logs Directory**: `{BASE_DIR}\MQL5\Logs\`

## Setup Instructions

### Option 1: Use Automatic Detection (Recommended)
Simply run the build script without any setup:
```powershell
.\GrandeBuild.ps1
```
The script will auto-detect your MT5 terminal and display which one it found.

### Option 2: Set Environment Variable
If you have multiple MT5 terminals or want to use a specific one:

1. **Find your terminal ID**:
   ```powershell
   .\Set-MT5Environment.ps1
   ```

2. **Set the environment variable**:
   ```powershell
   $env:MT5_TERMINAL_ID = "YOUR_TERMINAL_ID_HERE"
   ```

3. **Make it permanent** (optional):
   ```powershell
   [Environment]::SetEnvironmentVariable("MT5_TERMINAL_ID", "YOUR_TERMINAL_ID", "User")
   ```

## Environment Setup Script

Use the provided `Set-MT5Environment.ps1` script to:
- List all available MT5 terminals
- Set the `MT5_TERMINAL_ID` environment variable
- Configure it permanently for your user account

### Usage:
```powershell
# Interactive setup
.\Set-MT5Environment.ps1

# Direct setup
.\Set-MT5Environment.ps1 -TerminalId "5C659F0E64BA794E712EE4C936BCFED5"
```

## Troubleshooting

### "Could not auto-detect MT5 terminal directory"
This error occurs when:
1. MetaTrader 5 is not installed
2. The terminal hasn't been run yet (no MQL5 directory created)
3. No terminals are found in the expected location

**Solutions**:
1. Run MetaTrader 5 at least once to create the MQL5 directory
2. Check that MT5 is installed in the standard location
3. Manually set the `MT5_TERMINAL_ID` environment variable

### "Terminal ID not found"
This occurs when the specified `MT5_TERMINAL_ID` doesn't exist.

**Solutions**:
1. Run `.\Set-MT5Environment.ps1` to see available terminals
2. Use the correct terminal ID
3. Let the system auto-detect by clearing the environment variable

### Multiple MT5 Terminals
If you have multiple MT5 terminals (e.g., different brokers), the system will use the first one found. To use a specific terminal:
1. Set the `MT5_TERMINAL_ID` environment variable
2. Or rename/reorder the terminal directories (not recommended)

## Migration from Hardcoded Paths

If you were previously using hardcoded paths, the system will now:
1. Automatically detect your MT5 installation
2. Use the same deployment locations
3. Continue working without any configuration changes

## Benefits

- **Portable**: Works on any Windows system with MT5 installed
- **User-independent**: No need to modify paths for different users
- **Flexible**: Supports multiple MT5 terminals
- **Maintainable**: No hardcoded paths to update
- **Robust**: Automatic fallback and error handling

## Files Updated

The following files have been updated to use dynamic paths:
- `GrandeBuild.ps1` - Main build script
- `GrandeBuild.ps1.backup` - Backup build script
- `BUILD_USAGE.md` - Usage documentation
- `docs/DEBUG_LOGS_PROMPT.md` - Debug documentation
- `docs/GRANDE_EA_STATUS.md` - Status documentation
- `docs/PROFIT_LOSS_ANALYSIS_PROMPT.md` - Analysis documentation

Python files already used proper environment variables and required no changes.
