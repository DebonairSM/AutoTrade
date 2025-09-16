#!/usr/bin/env python3
"""
Grande Integrated Calendar System
Reads Common\\Files\\economic_events.json, asks MCP tool to analyze, writes integrated_calendar_analysis.json
"""
import os, sys, json, asyncio, subprocess
from datetime import datetime

def common_files_dir() -> str:
    env = os.environ.get('MT5_COMMON_FILES_DIR', '')
    if env:
        return env
    # Default Windows Common Files
    return os.path.join(os.path.expanduser('~'), 'AppData', 'Roaming', 'MetaQuotes', 'Terminal', 'Common', 'Files')

def read_events() -> dict:
    base = common_files_dir()
    path = os.path.join(base, 'economic_events.json')
    if not os.path.exists(path):
        # fallback to cwd
        path = os.path.abspath('economic_events.json')
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {"events": []}

def save_result(result: dict) -> str:
    base = common_files_dir()
    try:
        os.makedirs(base, exist_ok=True)
    except Exception:
        pass
    outp = os.path.join(base, 'integrated_calendar_analysis.json')
    try:
        with open(outp, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2)
        return outp
    except Exception:
        # fallback
        outp = os.path.abspath('integrated_calendar_analysis.json')
        with open(outp, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2)
        return outp

def fallback(events: dict) -> dict:
    # Minimal heuristic if MCP not available
    items = events.get("events", [])
    return {
        "signal": "NEUTRAL" if not items else "BUY",
        "score": 0.0,
        "confidence": 0.3 if not items else 0.5,
        "reasoning": f"Fallback analysis for {len(items)} events",
        "event_count": len(items),
        "timestamp": datetime.now().isoformat()
    }

def call_mcp(events: dict) -> dict:
    # Use MCP Python client to call the local MCP server via stdio
    # We run the client here; the server must be reachable (stdio or http)
    client_code = f'''
import json, asyncio
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

events = {json.dumps(events)}

async def run():
    async with stdio_client(StdioServerParameters(command="python", args=["main.py"])) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("analyze_calendar_events", {{"events": events.get("events", [])}})
            print(json.dumps(result))

asyncio.run(run())
'''
    try:
        # Execute in the same directory as main.py (this file is in the same folder)
        here = os.path.dirname(os.path.abspath(__file__))
        result = subprocess.run(
            ["python", "-c", client_code],
            cwd=here,
            capture_output=True, text=True, timeout=60
        )
        if result.returncode != 0:
            return {}
        out = result.stdout.strip()
        return json.loads(out) if out else {}
    except Exception:
        return {}

def main():
    print("🚀 GRANDE INTEGRATED CALENDAR SYSTEM")
    events = read_events()
    if not events.get("events"):
        print("⚠️  No events found to analyze.")
    res = call_mcp(events)
    if not res or "signal" not in res:
        print("⚠️  MCP not available; using fallback.")
        res = fallback(events)
    res["timestamp"] = datetime.now().isoformat()
    outp = save_result(res)
    print(f"💾 Calendar analysis saved to: {outp}")

if __name__ == "__main__":
    main()
