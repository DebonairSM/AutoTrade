#!/usr/bin/env python3
"""
FinBERT File Watcher Service for Grande Trading System

This service continuously monitors the MT5 Common Files directory for new
market_context_*.json files and automatically triggers FinBERT analysis.

Purpose:
- Watch for new market context files from Grande EA
- Automatically run enhanced_finbert_analyzer.py when new files arrive
- Process files in order (oldest first)
- Maintain a processed files log to avoid duplicates
- Run as a background service

Usage:
    python finbert_watcher_service.py

To run as Windows service, use:
    python finbert_watcher_service.py --install    (install service)
    python finbert_watcher_service.py --start      (start service)
    python finbert_watcher_service.py --stop       (stop service)
    python finbert_watcher_service.py --remove     (uninstall service)

Configuration:
- Set MT5_COMMON_FILES_DIR environment variable to override default path
- Service runs with a 10-second polling interval
- Processes one file at a time to avoid overload
"""

import os
import sys
import time
import glob
import json
import logging
import argparse
from pathlib import Path
from datetime import datetime
from typing import Set, Optional

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import the enhanced analyzer
try:
    from enhanced_finbert_analyzer import analyze_enhanced_market_data, common_files_dir
    ANALYZER_AVAILABLE = True
except ImportError as e:
    print(f"WARNING: Could not import enhanced_finbert_analyzer: {e}")
    ANALYZER_AVAILABLE = False


# ----------------------------- Configuration ---------------------------------

# Polling interval in seconds
POLL_INTERVAL = 10

# Directory to watch
def get_watch_directory() -> str:
    """Get the directory to watch for new files"""
    return common_files_dir() if ANALYZER_AVAILABLE else os.path.join(
        os.path.expanduser("~"), "AppData", "Roaming", "MetaQuotes", "Terminal", "Common", "Files"
    )

# Pattern for market context files
WATCH_PATTERN = "market_context_*.json"

# Log file location
LOG_FILE = os.path.join(os.path.dirname(__file__), "finbert_watcher.log")

# Processed files tracking
PROCESSED_FILES_LOG = os.path.join(get_watch_directory(), "finbert_processed_files.txt")


# ----------------------------- Logging Setup ---------------------------------

def setup_logging():
    """Configure logging for the service"""
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(message)s',
        handlers=[
            logging.FileHandler(LOG_FILE),
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger("FinBERTWatcher")


logger = setup_logging()


# ----------------------------- Processed Files Tracking -----------------------

def load_processed_files() -> Set[str]:
    """Load the set of already processed files"""
    if not os.path.exists(PROCESSED_FILES_LOG):
        return set()
    
    try:
        with open(PROCESSED_FILES_LOG, 'r') as f:
            return set(line.strip() for line in f if line.strip())
    except Exception as e:
        logger.error(f"Error loading processed files log: {e}")
        return set()


def mark_file_processed(filepath: str):
    """Mark a file as processed"""
    try:
        with open(PROCESSED_FILES_LOG, 'a') as f:
            f.write(f"{filepath}\n")
    except Exception as e:
        logger.error(f"Error marking file as processed: {e}")


# ----------------------------- File Processing --------------------------------

def process_market_context_file(filepath: str) -> bool:
    """
    Process a single market context file with enhanced FinBERT analyzer
    
    Args:
        filepath: Path to the market context JSON file
        
    Returns:
        True if processing was successful, False otherwise
    """
    logger.info(f"Processing file: {filepath}")
    
    try:
        # Read market context data (try UTF-8 first, then UTF-16)
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                market_context_data = json.load(f)
        except UnicodeDecodeError:
            # MQL5 sometimes writes UTF-16 files
            with open(filepath, 'r', encoding='utf-16') as f:
                market_context_data = json.load(f)
        
        logger.info(f"Loaded market context for {market_context_data.get('symbol', 'UNKNOWN')} "
                   f"at {market_context_data.get('timestamp', 'UNKNOWN')}")
        
        # Run enhanced FinBERT analysis
        if not ANALYZER_AVAILABLE:
            logger.error("Enhanced FinBERT analyzer is not available")
            return False
        
        result = analyze_enhanced_market_data(market_context_data)
        result["analysis_timestamp"] = datetime.now().isoformat()
        
        # Check if using real FinBERT or fallback
        if "FALLBACK" in result.get('reasoning', ''):
            result["finbert_status"] = "FALLBACK_MODE"
            logger.warning("Using FALLBACK analysis (FinBERT not available)")
        else:
            result["finbert_status"] = "REAL_AI"
            logger.info("Using REAL FinBERT AI analysis")
        
        # Write result to output file
        output_path = os.path.join(get_watch_directory(), "enhanced_finbert_analysis.json")
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2)
        
        logger.info(f"Analysis completed: {result['signal']} "
                   f"(confidence: {result['confidence']:.3f}, "
                   f"processing time: {result['processing_time_ms']:.1f}ms)")
        logger.info(f"Output saved to: {output_path}")
        
        return True
        
    except Exception as e:
        logger.error(f"Error processing file {filepath}: {e}", exc_info=True)
        return False


def scan_for_new_files() -> Optional[str]:
    """
    Scan for new market context files that haven't been processed yet
    
    Returns:
        Path to the oldest unprocessed file, or None if no new files
    """
    watch_dir = get_watch_directory()
    pattern = os.path.join(watch_dir, WATCH_PATTERN)
    
    # Get all matching files
    files = glob.glob(pattern)
    
    if not files:
        return None
    
    # Load processed files
    processed = load_processed_files()
    
    # Filter to unprocessed files
    unprocessed = [f for f in files if f not in processed]
    
    if not unprocessed:
        return None
    
    # Sort by modification time (oldest first)
    unprocessed.sort(key=os.path.getmtime)
    
    return unprocessed[0]


# ----------------------------- Main Service Loop ------------------------------

def run_watcher_service():
    """Main service loop that watches for new files and processes them"""
    logger.info("=" * 80)
    logger.info("FinBERT File Watcher Service Starting")
    logger.info("=" * 80)
    logger.info(f"Watch directory: {get_watch_directory()}")
    logger.info(f"Watch pattern: {WATCH_PATTERN}")
    logger.info(f"Poll interval: {POLL_INTERVAL} seconds")
    logger.info(f"Log file: {LOG_FILE}")
    logger.info(f"Processed files log: {PROCESSED_FILES_LOG}")
    logger.info(f"Analyzer available: {ANALYZER_AVAILABLE}")
    
    if not ANALYZER_AVAILABLE:
        logger.error("Cannot start service: Enhanced FinBERT analyzer not available")
        logger.error("Please ensure enhanced_finbert_analyzer.py is in the same directory")
        return 1
    
    logger.info("Service started successfully - monitoring for new files...")
    logger.info("=" * 80)
    
    consecutive_errors = 0
    max_consecutive_errors = 5
    
    try:
        while True:
            try:
                # Check for new files
                new_file = scan_for_new_files()
                
                if new_file:
                    logger.info(f"New file detected: {os.path.basename(new_file)}")
                    
                    # Process the file
                    success = process_market_context_file(new_file)
                    
                    if success:
                        # Mark as processed
                        mark_file_processed(new_file)
                        consecutive_errors = 0
                        logger.info(f"File processed successfully: {os.path.basename(new_file)}")
                    else:
                        consecutive_errors += 1
                        logger.error(f"Failed to process file: {os.path.basename(new_file)}")
                        
                        if consecutive_errors >= max_consecutive_errors:
                            logger.error(f"Too many consecutive errors ({consecutive_errors}). "
                                       "Stopping service.")
                            return 1
                
                # Sleep until next poll
                time.sleep(POLL_INTERVAL)
                
            except KeyboardInterrupt:
                logger.info("Service interrupted by user")
                raise
            except Exception as e:
                consecutive_errors += 1
                logger.error(f"Error in service loop: {e}", exc_info=True)
                
                if consecutive_errors >= max_consecutive_errors:
                    logger.error(f"Too many consecutive errors ({consecutive_errors}). "
                               "Stopping service.")
                    return 1
                
                # Wait before retrying
                time.sleep(POLL_INTERVAL)
                
    except KeyboardInterrupt:
        logger.info("Service stopped by user (Ctrl+C)")
        return 0
    except Exception as e:
        logger.error(f"Fatal error in service: {e}", exc_info=True)
        return 1


# ----------------------------- CLI Interface ----------------------------------

def main(argv=None):
    """Main entry point for the service"""
    parser = argparse.ArgumentParser(
        description="FinBERT File Watcher Service for Grande Trading System"
    )
    parser.add_argument(
        '--daemon', 
        action='store_true', 
        help='Run as daemon (background service)'
    )
    parser.add_argument(
        '--test',
        action='store_true',
        help='Test mode: process existing files once and exit'
    )
    
    args = parser.parse_args(argv)
    
    if args.test:
        logger.info("Running in TEST mode - processing existing files once")
        watch_dir = get_watch_directory()
        pattern = os.path.join(watch_dir, WATCH_PATTERN)
        files = glob.glob(pattern)
        
        if not files:
            logger.info("No market context files found for testing")
            return 0
        
        # Process the most recent file
        files.sort(key=os.path.getmtime, reverse=True)
        test_file = files[0]
        
        logger.info(f"Testing with most recent file: {os.path.basename(test_file)}")
        success = process_market_context_file(test_file)
        
        if success:
            logger.info("TEST PASSED: File processed successfully")
            return 0
        else:
            logger.error("TEST FAILED: File processing failed")
            return 1
    
    if args.daemon:
        logger.info("Daemon mode not yet implemented - running in foreground")
    
    # Run the service
    return run_watcher_service()


if __name__ == "__main__":
    sys.exit(main())

