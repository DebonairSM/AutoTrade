#!/usr/bin/env python3
"""
Test script for Grande Sentiment MCP Server
"""

import asyncio
import json
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

async def test_sentiment_server():
    """Test the sentiment analysis server"""
    print("Testing Grande Sentiment MCP Server...")
    
    try:
        # Test with Docker container
        async with stdio_client(
            StdioServerParameters(
                command="docker", 
                args=["exec", "-i", "grande-sentiment-mcp", "python", "main.py"]
            )
        ) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                
                # List available tools
                tools = await session.list_tools()
                print(f"Available tools: {[t.name for t in tools.tools]}")
                
                # Test sentiment analysis
                test_text = "This is a great product! I love it!"
                print(f"\nTesting with text: '{test_text}'")
                
                result = await session.call_tool("analyze_sentiment", {"text": test_text})
                print(f"Result: {json.dumps(result, indent=2)}")
                
    except Exception as e:
        print(f"Error testing server: {e}")
        print("Make sure the Docker container is running: docker compose ps")

if __name__ == "__main__":
    asyncio.run(test_sentiment_server())
