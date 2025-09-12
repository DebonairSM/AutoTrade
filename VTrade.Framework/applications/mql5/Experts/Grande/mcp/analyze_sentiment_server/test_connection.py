#!/usr/bin/env python3
"""
Simple connection test for Grande Sentiment MCP Server
"""

import subprocess
import sys
import time

def test_docker_container():
    """Test if Docker container is running"""
    print("Testing Docker container status...")
    
    try:
        # Check if container is running
        result = subprocess.run(
            ["docker", "ps", "--filter", "name=grande-sentiment-mcp", "--format", "{{.Status}}"],
            capture_output=True, text=True, check=True
        )
        
        if result.stdout.strip():
            print(f"✅ Container status: {result.stdout.strip()}")
            return True
        else:
            print("❌ Container is not running")
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"❌ Error checking container: {e}")
        return False

def test_port_access():
    """Test if port 8000 is accessible"""
    print("\nTesting port 8000 accessibility...")
    
    try:
        import socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex(('localhost', 8000))
        sock.close()
        
        if result == 0:
            print("✅ Port 8000 is accessible")
            return True
        else:
            print("❌ Port 8000 is not accessible")
            return False
            
    except Exception as e:
        print(f"❌ Error testing port: {e}")
        return False

def test_container_logs():
    """Check container logs for any errors"""
    print("\nChecking container logs...")
    
    try:
        result = subprocess.run(
            ["docker", "logs", "grande-sentiment-mcp", "--tail", "10"],
            capture_output=True, text=True, check=True
        )
        
        print("Recent logs:")
        print(result.stdout)
        
        if "ERROR" in result.stdout or "Traceback" in result.stdout:
            print("❌ Errors found in logs")
            return False
        else:
            print("✅ No errors in recent logs")
            return True
            
    except subprocess.CalledProcessError as e:
        print(f"❌ Error checking logs: {e}")
        return False

def main():
    """Run all tests"""
    print("Grande Sentiment MCP Server - Connection Test")
    print("=" * 50)
    
    tests = [
        test_docker_container,
        test_port_access,
        test_container_logs
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print(f"Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Server is running correctly.")
        print("\nNext steps:")
        print("1. The server is running in Docker container 'grande-sentiment-mcp'")
        print("2. It's accessible on port 8000")
        print("3. You can use it with MCP clients")
        print("4. Check logs with: docker compose logs -f sentiment-server")
    else:
        print("❌ Some tests failed. Check the output above for details.")
        print("\nTroubleshooting:")
        print("1. Make sure Docker is running")
        print("2. Check if container is healthy: docker compose ps")
        print("3. View logs: docker compose logs sentiment-server")

if __name__ == "__main__":
    main()
