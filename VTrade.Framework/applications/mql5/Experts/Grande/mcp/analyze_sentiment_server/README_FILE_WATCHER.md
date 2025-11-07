# FinBERT File Watcher Service

## Purpose

The FinBERT File Watcher Service automatically monitors for new market context files from Grande EA and runs FinBERT analysis on them. This service is **required** for the FinBERT integration to work properly.

## Problem It Solves

Previously, the FinBERT Python scripts only ran when manually executed. This meant:
- Grande EA would write market context files
- But nothing would process them automatically
- Analysis output would become stale
- Trading decisions were based on old data (or no data)

The File Watcher Service solves this by:
- Continuously monitoring for new market context files
- Automatically processing them with FinBERT
- Keeping analysis output fresh and up-to-date
- Running in the background without manual intervention

## How It Works

```
Grande EA (MQL5)
    ↓
    Writes: market_context_SYMBOL_DATE.json
    ↓
File Watcher Service (Python)
    ↓
    Detects new file
    ↓
    Runs: enhanced_finbert_analyzer.py
    ↓
    Writes: enhanced_finbert_analysis.json
    ↓
Grande EA (MQL5)
    ↓
    Reads analysis results
    ↓
    Makes trading decisions
```

## Quick Start

### 1. Install FinBERT (First Time Only)

```bash
# Option 1: Double-click
Double-click: install_finbert.bat

# Option 2: Run PowerShell script
Right-click install_finbert.ps1 → "Run with PowerShell"
```

### 2. Start the File Watcher Service

```bash
# Option 1: Double-click (easiest)
Double-click: start_finbert_watcher.bat

# Option 2: Run PowerShell script
Right-click start_finbert_watcher.ps1 → "Run with PowerShell"

# Option 3: Command line
python finbert_watcher_service.py
```

The service will:
- Open in a new window
- Display status messages
- Keep running until you close it
- Process files as they arrive

### 3. Verify It's Working

Check the log file:
```
mcp/analyze_sentiment_server/finbert_watcher.log
```

Look for:
```
Service started successfully - monitoring for new files...
New file detected: market_context_EURUSD_2025.11.06.json
Processing file: ...
Analysis completed: BUY (confidence: 0.856)
File processed successfully
```

### 4. Stop the Service

```bash
# Option 1: Close the service window
Just close the PowerShell window running the service

# Option 2: Ctrl+C in the service window
Press Ctrl+C to stop gracefully

# Option 3: Run stop script
Double-click: stop_finbert_watcher.bat
```

## Configuration

The service is configured through environment variables and command-line options.

### Environment Variables

```bash
# Override the MT5 Common Files directory
set MT5_COMMON_FILES_DIR=C:\Path\To\Common\Files

# Override the FinBERT model
set FINBERT_MODEL=yiyanghkust/finbert-tone
```

### Command-Line Options

```bash
# Run in test mode (process one file and exit)
python finbert_watcher_service.py --test

# Run in daemon mode (background)
python finbert_watcher_service.py --daemon
```

## How Often Does It Run?

The service checks for new files every **10 seconds**.

When a new file is detected:
1. File is processed immediately (30-60 seconds)
2. Output is written to `enhanced_finbert_analysis.json`
3. Service resumes monitoring for the next file

## Files

### Service Files
- `finbert_watcher_service.py` - Main service script
- `start_finbert_watcher.ps1` - PowerShell start script
- `start_finbert_watcher.bat` - Batch start script
- `stop_finbert_watcher.ps1` - PowerShell stop script
- `stop_finbert_watcher.bat` - Batch stop script

### Log Files
- `finbert_watcher.log` - Service activity log
- `finbert_processed_files.txt` - List of processed files (auto-managed)

### Analyzer Files
- `enhanced_finbert_analyzer.py` - FinBERT analysis engine
- `finbert_calendar_analyzer.py` - Calendar-specific analyzer (fallback)

## Monitoring

### Check If Service Is Running

Windows Task Manager:
1. Open Task Manager (Ctrl+Shift+Esc)
2. Go to "Details" tab
3. Look for `python.exe` with command line containing `finbert_watcher_service.py`

PowerShell:
```powershell
Get-Process -Name python | Where-Object { $_.CommandLine -like "*finbert_watcher_service.py*" }
```

### Check Service Status

Watch the log file in real-time:
```bash
# PowerShell
Get-Content finbert_watcher.log -Wait -Tail 20

# Command Prompt
powershell -Command "Get-Content finbert_watcher.log -Wait -Tail 20"
```

### Check Common Files Directory

```powershell
# List market context files
dir $env:APPDATA\MetaQuotes\Terminal\Common\Files\market_context_*.json

# List output files
dir $env:APPDATA\MetaQuotes\Terminal\Common\Files\enhanced_finbert_analysis.json
```

## Troubleshooting

### Service Window Closes Immediately

**Cause:** Python packages not installed or import error

**Solution:**
1. Check the log file: `finbert_watcher.log`
2. Run test mode: `python finbert_watcher_service.py --test`
3. Verify packages: `python -m pip list` (look for torch, transformers, numpy)
4. Reinstall packages: Run `install_finbert.bat`

### No Analysis Output Appearing

**Cause:** Service not detecting new files

**Solution:**
1. Check Grande EA is creating market context files
2. Verify Common Files directory location
3. Check service log for "New file detected" messages
4. Verify file pattern matches: `market_context_*.json`

### Service Uses Too Much CPU

**Cause:** FinBERT analysis is CPU-intensive (this is normal)

**Solution:**
1. CPU usage is normal during analysis (30-60 seconds per file)
2. Service sleeps between checks (10 seconds of low CPU usage)
3. Consider reducing `InpFinBERTAnalysisInterval` in EA to create fewer files
4. Run service at lower priority (not recommended, may delay analysis)

### Service Processes Old Files

**Cause:** Service starting for first time with many existing files

**Solution:**
This is normal. The service will:
1. Process existing unprocessed files (oldest first)
2. Mark them as processed
3. Then monitor for new files only

To reset:
1. Delete `finbert_processed_files.txt`
2. Service will reprocess all files

### "FALLBACK MODE" in Output

**Cause:** FinBERT packages not installed correctly

**Solution:**
1. Check packages: `python -m pip list`
2. Reinstall: Run `install_finbert.bat`
3. Test import: `python -c "import torch, transformers"`
4. Check log for specific error messages

## Performance

### Resource Usage
- **CPU:** 5-50% during analysis (spikes to 100% briefly)
- **Memory:** 1-2 GB (FinBERT model in RAM)
- **Disk:** Minimal (only log files)
- **Network:** Only on first run (downloads FinBERT model ~440MB)

### Processing Time
- **Per file:** 30-60 seconds (depending on CPU)
- **Model loading:** 5-10 seconds (once at startup)
- **Between checks:** 10 seconds (low resource usage)

### Scalability
- **Files per hour:** Up to 60 (one per minute)
- **Concurrent processing:** One file at a time (prevents resource exhaustion)
- **Queue:** Unlimited (processes all files eventually)

## Integration with Grande EA

The Grande EA is configured to:
1. Write market context files at intervals (default: 5 minutes)
2. Look for `enhanced_finbert_analysis.json` output
3. Use the analysis for trading decisions

EA configuration:
```cpp
input int InpFinBERTAnalysisInterval = 300;  // 5 minutes = 300 seconds
```

Adjust this interval based on:
- How often you want FinBERT analysis
- CPU/resource constraints
- Trading timeframe (H4 = less frequent is fine)

## Security

The service:
- **Only reads** market context JSON files
- **Only writes** to the same directory (Common Files)
- **Does not** access network (except initial model download)
- **Does not** execute arbitrary code
- **Does not** modify EA or system files

## Logging

Log levels:
- **INFO:** Normal operation (file detected, processed, etc.)
- **WARNING:** Non-critical issues (test failures, etc.)
- **ERROR:** Critical errors (import failures, processing errors)

Log rotation:
- Not implemented (log file grows indefinitely)
- Manually delete `finbert_watcher.log` to reset

## Advanced Usage

### Run as Windows Service

Coming soon. Currently, the service must run in a visible window.

### Multiple Instances

Not recommended. Running multiple instances will:
- Process the same files multiple times
- Compete for resources
- Create race conditions in output files

### Custom Polling Interval

Edit `finbert_watcher_service.py`:
```python
POLL_INTERVAL = 10  # Change to desired seconds
```

### Custom Watch Directory

Set environment variable before starting:
```powershell
$env:MT5_COMMON_FILES_DIR = "C:\Custom\Path"
python finbert_watcher_service.py
```

## Support

If you encounter issues:

1. Check the log file first: `finbert_watcher.log`
2. Run in test mode: `python finbert_watcher_service.py --test`
3. Verify packages: `python -m pip list`
4. Check Grande EA logs in MT5
5. Review `INSTALL_FINBERT.txt` for setup instructions

## Version History

- **v1.0** (2025-11-06) - Initial release
  - Automatic file monitoring
  - FinBERT analysis integration
  - PowerShell management scripts
  - Comprehensive logging

