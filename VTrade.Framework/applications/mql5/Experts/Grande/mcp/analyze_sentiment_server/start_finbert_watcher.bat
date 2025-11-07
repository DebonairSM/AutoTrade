@echo off
REM Start FinBERT File Watcher Service
REM Double-click this file to start the service

powershell.exe -ExecutionPolicy Bypass -File "%~dp0start_finbert_watcher.ps1"

