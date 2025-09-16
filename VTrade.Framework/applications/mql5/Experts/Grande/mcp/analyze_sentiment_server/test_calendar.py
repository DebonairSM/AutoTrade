#!/usr/bin/env python3
"""
Test script for Grande Calendar Analysis
Tests the analyze_calendar_events MCP tool with sample data
"""

import json
import asyncio
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

async def test_calendar_analysis():
    """Test the calendar analysis MCP tool"""
    print("🧪 Testing Grande Calendar Analysis...")
    
    # Sample economic events data
    sample_events = {
        "events": [
            {
                "time_utc": "2025-01-16T12:30:00Z",
                "currency": "USD",
                "name": "Nonfarm Payrolls",
                "actual": "210000",
                "forecast": "195000",
                "previous": "180000",
                "impact": "High"
            },
            {
                "time_utc": "2025-01-16T14:00:00Z",
                "currency": "EUR",
                "name": "ECB Interest Rate Decision",
                "actual": "4.25",
                "forecast": "4.25",
                "previous": "4.00",
                "impact": "High"
            },
            {
                "time_utc": "2025-01-16T09:30:00Z",
                "currency": "GBP",
                "name": "CPI Inflation",
                "actual": "2.1",
                "forecast": "2.0",
                "previous": "1.8",
                "impact": "Critical"
            }
        ]
    }
    
    try:
        async with stdio_client(
            StdioServerParameters(command="python", args=["main.py"])
        ) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                
                print("✅ Connected to MCP server")
                
                # Test the analyze_calendar_events tool
                result = await session.call_tool("analyze_calendar_events", {"events": sample_events["events"]})
                
                print("\n📊 CALENDAR ANALYSIS RESULTS:")
                print("=" * 50)
                print(f"Signal: {result.get('signal', 'N/A')}")
                print(f"Score: {result.get('score', 0):.3f}")
                print(f"Confidence: {result.get('confidence', 0):.3f}")
                print(f"Event Count: {result.get('event_count', 0)}")
                print(f"Reasoning: {result.get('reasoning', 'N/A')}")
                
                if 'per_event' in result:
                    print("\n📋 PER-EVENT ANALYSIS:")
                    for i, event in enumerate(result['per_event'], 1):
                        print(f"{i}. {event.get('name', 'N/A')}")
                        print(f"   Impact: {event.get('impact', 'N/A')}")
                        print(f"   Surprise: {event.get('surprise', 0):.3f}")
                        print(f"   Direction Score: {event.get('direction_score', 0):.3f}")
                        print(f"   Weight: {event.get('weight', 0):.3f}")
                        print()
                
                print("=" * 50)
                print("✅ Calendar analysis test completed successfully!")
                
                return True
                
    except Exception as e:
        print(f"❌ Error testing calendar analysis: {e}")
        return False

async def main():
    """Main test function"""
    print("🚀 GRANDE CALENDAR ANALYSIS TEST")
    print("=" * 50)
    
    success = await test_calendar_analysis()
    
    if success:
        print("\n🎉 All tests passed!")
        print("\nNext steps:")
        print("1. Run the MQL5 demo: GrandeFreeNewsDemo.mq5")
        print("2. Check the logs for calendar AI signals")
        print("3. Verify economic_events.json is created in Common Files")
        print("4. Check integrated_calendar_analysis.json for AI results")
    else:
        print("\n❌ Tests failed!")
        print("Please check:")
        print("1. MCP server is running: python main.py")
        print("2. Dependencies are installed: pip install -r requirements.txt")
        print("3. Environment variables are set correctly")

if __name__ == "__main__":
    asyncio.run(main())
