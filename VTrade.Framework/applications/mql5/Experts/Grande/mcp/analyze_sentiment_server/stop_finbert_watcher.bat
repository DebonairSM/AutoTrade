@echo off
REM Stop FinBERT File Watcher Service
REM Double-click this file to stop the service

powershell.exe -ExecutionPolicy Bypass -File "%~dp0stop_finbert_watcher.ps1"

