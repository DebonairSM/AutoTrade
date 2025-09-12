#!/usr/bin/env python3
"""
Grande Sentiment MCP Server Monitor
Monitors the sentiment server and restarts it if it becomes unhealthy.
"""

import os
import sys
import time
import signal
import subprocess
import logging
import requests
from datetime import datetime
from typing import Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('monitor.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class SentimentServerMonitor:
    def __init__(self, 
                 server_url: str = "http://localhost:8000/health",
                 check_interval: int = 30,
                 max_retries: int = 3,
                 restart_delay: int = 10):
        self.server_url = server_url
        self.check_interval = check_interval
        self.max_retries = max_retries
        self.restart_delay = restart_delay
        self.process: Optional[subprocess.Popen] = None
        self.running = True
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        if self.process:
            self.process.terminate()
        sys.exit(0)
    
    def start_server(self) -> bool:
        """Start the sentiment server"""
        try:
            logger.info("Starting Grande Sentiment MCP Server...")
            
            # Set environment variables
            env = os.environ.copy()
            env.update({
                'MCP_TRANSPORT': 'streamable-http',
                'SENTIMENT_PROVIDER': 'openai_compat',
                'OPENAI_BASE_URL': 'http://localhost:11434/v1',
                'OPENAI_API_KEY': 'EMPTY',
                'OPENAI_MODEL': 'gpt-4o-mini'
            })
            
            # Start the server
            self.process = subprocess.Popen(
                [sys.executable, 'main.py'],
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Wait a moment for startup
            time.sleep(5)
            
            if self.process.poll() is None:
                logger.info(f"Server started with PID {self.process.pid}")
                return True
            else:
                stdout, stderr = self.process.communicate()
                logger.error(f"Server failed to start. stdout: {stdout}, stderr: {stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            return False
    
    def check_health(self) -> bool:
        """Check if the server is healthy"""
        try:
            response = requests.get(self.server_url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 'healthy':
                    return True
            return False
        except Exception as e:
            logger.warning(f"Health check failed: {e}")
            return False
    
    def restart_server(self) -> bool:
        """Restart the server"""
        logger.info("Restarting server...")
        
        # Stop current process
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                logger.warning("Server didn't stop gracefully, forcing kill...")
                self.process.kill()
                self.process.wait()
        
        # Wait before restart
        time.sleep(self.restart_delay)
        
        # Start new process
        return self.start_server()
    
    def monitor(self):
        """Main monitoring loop"""
        logger.info("Starting Grande Sentiment MCP Server Monitor")
        logger.info(f"Health check URL: {self.server_url}")
        logger.info(f"Check interval: {self.check_interval} seconds")
        
        consecutive_failures = 0
        
        while self.running:
            try:
                if self.process is None or self.process.poll() is not None:
                    # Server is not running, start it
                    logger.warning("Server is not running, attempting to start...")
                    if self.start_server():
                        consecutive_failures = 0
                    else:
                        consecutive_failures += 1
                        logger.error(f"Failed to start server (attempt {consecutive_failures})")
                else:
                    # Server is running, check health
                    if self.check_health():
                        consecutive_failures = 0
                        logger.debug("Server is healthy")
                    else:
                        consecutive_failures += 1
                        logger.warning(f"Server health check failed (attempt {consecutive_failures})")
                        
                        if consecutive_failures >= self.max_retries:
                            logger.error(f"Server failed {consecutive_failures} consecutive health checks, restarting...")
                            if self.restart_server():
                                consecutive_failures = 0
                            else:
                                logger.error("Failed to restart server")
                
                # Wait before next check
                time.sleep(self.check_interval)
                
            except KeyboardInterrupt:
                logger.info("Monitor interrupted by user")
                break
            except Exception as e:
                logger.error(f"Monitor error: {e}")
                time.sleep(self.check_interval)
        
        # Cleanup
        if self.process:
            logger.info("Stopping server...")
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        
        logger.info("Monitor stopped")

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Monitor Grande Sentiment MCP Server')
    parser.add_argument('--url', default='http://localhost:8000/health',
                       help='Health check URL (default: http://localhost:8000/health)')
    parser.add_argument('--interval', type=int, default=30,
                       help='Health check interval in seconds (default: 30)')
    parser.add_argument('--max-retries', type=int, default=3,
                       help='Max consecutive failures before restart (default: 3)')
    parser.add_argument('--restart-delay', type=int, default=10,
                       help='Delay before restart in seconds (default: 10)')
    
    args = parser.parse_args()
    
    monitor = SentimentServerMonitor(
        server_url=args.url,
        check_interval=args.interval,
        max_retries=args.max_retries,
        restart_delay=args.restart_delay
    )
    
    monitor.monitor()

if __name__ == "__main__":
    main()
