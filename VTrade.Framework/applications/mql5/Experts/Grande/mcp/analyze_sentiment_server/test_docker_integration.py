#!/usr/bin/env python3
"""
Test script to verify Docker stdio integration with the sentiment server.
This script can be executed by the EA to test the Docker integration.
"""

import asyncio
import json
import sys
import os
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

async def test_sentiment_analysis():
    """Test sentiment analysis via Docker stdio"""
    try:
        print("Testing Docker stdio integration...")
        
        # Test text
        test_text = "This is a bullish market with strong positive sentiment and growth potential"
        
        async with stdio_client(
            StdioServerParameters(command="python", args=["main.py"])
        ) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                result = await session.call_tool("analyze_sentiment", {"text": test_text})
                
                print("✅ Sentiment analysis completed successfully")
                
                if hasattr(result, 'content') and result.content:
                    content = result.content[0].text
                    try:
                        # Try to parse as JSON
                        sentiment_data = json.loads(content)
                        print(f"📊 Sentiment: {sentiment_data.get('sentiment', 'Unknown')}")
                        print(f"📈 Score: {sentiment_data.get('score', 'Unknown')}")
                        print(f"🎯 Confidence: {sentiment_data.get('confidence', 'Unknown')}")
                        return True
                    except json.JSONDecodeError:
                        print(f"📝 Raw response: {content}")
                        return True
                else:
                    print("❌ No content in response")
                    return False
                    
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

async def test_calendar_analysis():
    """Test calendar analysis via Docker stdio"""
    try:
        print("\nTesting calendar analysis...")
        
        # Test events
        test_events = {
            "events": [
                {
                    "title": "GDP Release",
                    "impact": "HIGH",
                    "currency": "USD",
                    "time": "2025-09-16T14:00:00Z"
                }
            ]
        }
        
        async with stdio_client(
            StdioServerParameters(command="python", args=["main.py"])
        ) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                result = await session.call_tool("analyze_calendar_events", {"events": test_events["events"]})
                
                print("✅ Calendar analysis completed successfully")
                
                if hasattr(result, 'content') and result.content:
                    content = result.content[0].text
                    try:
                        # Try to parse as JSON
                        calendar_data = json.loads(content)
                        print(f"📊 Signal: {calendar_data.get('signal', 'Unknown')}")
                        print(f"📈 Score: {calendar_data.get('score', 'Unknown')}")
                        print(f"🎯 Confidence: {calendar_data.get('confidence', 'Unknown')}")
                        return True
                    except json.JSONDecodeError:
                        print(f"📝 Raw response: {content}")
                        return True
                else:
                    print("❌ No content in response")
                    return False
                    
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

async def main():
    """Main test function"""
    print("🚀 GRANDE DOCKER STDIO INTEGRATION TEST")
    print("=" * 50)
    
    # Test sentiment analysis
    sentiment_success = await test_sentiment_analysis()
    
    # Test calendar analysis
    calendar_success = await test_calendar_analysis()
    
    print("\n" + "=" * 50)
    print("📋 TEST RESULTS:")
    print(f"✅ Sentiment Analysis: {'PASS' if sentiment_success else 'FAIL'}")
    print(f"✅ Calendar Analysis: {'PASS' if calendar_success else 'FAIL'}")
    
    if sentiment_success and calendar_success:
        print("\n🎉 ALL TESTS PASSED! Docker stdio integration is working correctly.")
        return 0
    else:
        print("\n❌ Some tests failed. Check the logs above.")
        return 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)

