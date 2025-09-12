#!/usr/bin/env python3
"""
HTTP-based test for Grande Sentiment MCP Server
Tests the sentiment analysis functionality via HTTP
"""

import requests
import json
import time

def test_http_connection():
    """Test HTTP connection to the server"""
    print("🌐 Testing HTTP connection to MCP server...")
    
    try:
        # Test basic connectivity
        response = requests.get("http://localhost:8000", timeout=5)
        print(f"✅ HTTP connection successful (status: {response.status_code})")
        return True
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to http://localhost:8000")
        return False
    except Exception as e:
        print(f"⚠️  HTTP connection issue: {e}")
        return False

def test_mcp_tools():
    """Test MCP tools via HTTP"""
    print("\n🔧 Testing MCP tools...")
    
    # Test cases
    test_cases = [
        {
            "text": "This is absolutely fantastic! I love this product!",
            "expected": "positive",
            "description": "Positive sentiment test"
        },
        {
            "text": "This is terrible. I hate it completely.",
            "expected": "negative",
            "description": "Negative sentiment test"
        },
        {
            "text": "The weather is okay today. Nothing special.",
            "expected": "neutral",
            "description": "Neutral sentiment test"
        }
    ]
    
    try:
        # Since this is an MCP server, we need to use the MCP protocol
        # Let's try a simple HTTP POST to see what happens
        for i, test_case in enumerate(test_cases, 1):
            print(f"\nTest {i}: {test_case['description']}")
            print(f"Text: '{test_case['text']}'")
            
            # Try to send a simple request
            try:
                # MCP servers typically expect JSON-RPC format
                payload = {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "tools/call",
                    "params": {
                        "name": "analyze_sentiment",
                        "arguments": {
                            "text": test_case['text']
                        }
                    }
                }
                
                response = requests.post(
                    "http://localhost:8000",
                    json=payload,
                    headers={"Content-Type": "application/json"},
                    timeout=10
                )
                
                print(f"Response status: {response.status_code}")
                print(f"Response headers: {dict(response.headers)}")
                
                if response.status_code == 200:
                    try:
                        result = response.json()
                        print(f"✅ Response: {json.dumps(result, indent=2)}")
                    except:
                        print(f"Response text: {response.text[:200]}...")
                else:
                    print(f"❌ HTTP error: {response.status_code}")
                    print(f"Response: {response.text[:200]}...")
                    
            except Exception as e:
                print(f"❌ Request failed: {e}")
            
            print("-" * 40)
            
    except Exception as e:
        print(f"❌ MCP tools test failed: {e}")

def test_docker_container():
    """Test Docker container status"""
    print("🐳 Testing Docker container...")
    
    import subprocess
    
    try:
        # Check container status
        result = subprocess.run(
            ["docker", "ps", "--filter", "name=grande-sentiment-mcp", "--format", "{{.Status}}"],
            capture_output=True, text=True, check=True
        )
        
        if "Up" in result.stdout:
            print(f"✅ Container status: {result.stdout.strip()}")
            
            # Check container logs
            logs_result = subprocess.run(
                ["docker", "logs", "grande-sentiment-mcp", "--tail", "5"],
                capture_output=True, text=True, check=True
            )
            
            print("Recent logs:")
            print(logs_result.stdout)
            return True
        else:
            print(f"❌ Container not running: {result.stdout}")
            return False
            
    except Exception as e:
        print(f"❌ Docker check failed: {e}")
        return False

def main():
    """Main test function"""
    print("🧪 Grande Sentiment MCP Server - HTTP Test")
    print("=" * 50)
    
    # Test 1: Docker container
    if not test_docker_container():
        print("\n❌ Docker container issues. Please check:")
        print("1. docker compose ps")
        print("2. docker compose logs sentiment-server")
        return
    
    print("\n" + "=" * 50)
    
    # Test 2: HTTP connection
    if not test_http_connection():
        print("\n❌ HTTP connection failed. Please check:")
        print("1. Container is running on port 8000")
        print("2. Port 8000 is accessible")
        return
    
    print("\n" + "=" * 50)
    
    # Test 3: MCP tools
    test_mcp_tools()
    
    print("\n" + "=" * 50)
    print("📋 Test Summary:")
    print("✅ Docker container is running")
    print("✅ HTTP port 8000 is accessible")
    print("⚠️  MCP protocol testing needs proper client")
    
    print("\nNext steps:")
    print("1. The server is running and accessible")
    print("2. Use proper MCP client to test sentiment analysis")
    print("3. Check server logs for any issues")
    print("4. Integrate with your MQL5 system")

if __name__ == "__main__":
    main()
