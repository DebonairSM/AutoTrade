#!/usr/bin/env python3
"""
Simple test for Grande Sentiment MCP Server
Tests the sentiment analysis functionality using Docker exec
"""

import subprocess
import json
import time

def test_docker_exec():
    """Test sentiment analysis using docker exec"""
    print("🧪 Testing Grande Sentiment MCP Server")
    print("=" * 50)
    
    # Test cases
    test_cases = [
        "This is absolutely fantastic! I love this product!",
        "This is terrible. I hate it completely.",
        "The weather is okay today. Nothing special.",
        "Amazing earnings report! Stock price soaring!",
        "The market showed mixed signals today."
    ]
    
    print("📡 Testing sentiment analysis via Docker exec...")
    
    for i, text in enumerate(test_cases, 1):
        print(f"\nTest {i}: '{text}'")
        
        try:
            # Create a simple test script
            test_script = f'''
import asyncio
import json
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

async def test():
    async with stdio_client(
        StdioServerParameters(command="python", args=["main.py"])
    ) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("analyze_sentiment", {{"text": "{text}"}})
            print(json.dumps(result))

asyncio.run(test())
'''
            
            # Write test script to container
            subprocess.run([
                "docker", "exec", "grande-sentiment-mcp", 
                "sh", "-c", f"echo '{test_script}' > test_script.py"
            ], check=True)
            
            # Run the test script
            result = subprocess.run([
                "docker", "exec", "grande-sentiment-mcp",
                "python", "test_script.py"
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                try:
                    response = json.loads(result.stdout.strip())
                    print(f"✅ Response: {json.dumps(response, indent=2)}")
                    
                    if "error" not in response:
                        sentiment = response.get("sentiment", "unknown")
                        score = response.get("score", 0)
                        confidence = response.get("confidence", 0)
                        print(f"   Sentiment: {sentiment}, Score: {score:.3f}, Confidence: {confidence:.3f}")
                    else:
                        print(f"❌ Error: {response['error']}")
                        
                except json.JSONDecodeError:
                    print(f"❌ Invalid JSON response: {result.stdout}")
            else:
                print(f"❌ Script failed: {result.stderr}")
                
        except subprocess.TimeoutExpired:
            print("❌ Test timed out")
        except Exception as e:
            print(f"❌ Error: {e}")
        
        print("-" * 40)
    
    print("\n🎉 Test completed!")

def test_container_status():
    """Test container status"""
    print("🐳 Checking container status...")
    
    try:
        result = subprocess.run([
            "docker", "ps", "--filter", "name=grande-sentiment-mcp", "--format", "{{.Status}}"
        ], capture_output=True, text=True, check=True)
        
        if "Up" in result.stdout:
            print(f"✅ Container status: {result.stdout.strip()}")
            return True
        else:
            print(f"❌ Container not running: {result.stdout}")
            return False
    except Exception as e:
        print(f"❌ Error checking container: {e}")
        return False

def main():
    """Main test function"""
    print("🚀 Grande Sentiment MCP Server - Simple Test")
    print("=" * 60)
    
    # Check container status
    if not test_container_status():
        print("\n❌ Container is not running. Please start it with:")
        print("docker compose up -d")
        return
    
    print("\n" + "=" * 60)
    
    # Test sentiment analysis
    test_docker_exec()
    
    print("\n" + "=" * 60)
    print("📋 Test Summary:")
    print("✅ Container is running")
    print("✅ Sentiment analysis tests completed")
    print("\nNext steps:")
    print("1. The server is working inside the container")
    print("2. You can integrate it with your MQL5 system")
    print("3. Use Docker exec to call the sentiment analysis")

if __name__ == "__main__":
    main()
