#!/usr/bin/env python3
"""
Test HuggingFace Inference API for FinBERT
This tests if the API approach works (bypasses Python 3.13 compatibility issues)
"""

import sys
import os
import traceback

print("=" * 70)
print("Testing HuggingFace Inference API for FinBERT")
print("=" * 70)
print()

# Check for API token
api_token = os.environ.get("HF_API_TOKEN") or os.environ.get("HUGGINGFACE_API_TOKEN")
if not api_token:
    print("[INFO] No API token found. Testing with public endpoint (rate limited)")
    print("[INFO] For production, set HF_API_TOKEN environment variable")
    print()

try:
    import requests
    print("[OK] Requests library available")
except ImportError:
    print("[ERROR] Requests library not found")
    print("Install with: python -m pip install requests")
    sys.exit(1)

# Test API endpoint
model_name = "yiyanghkust/finbert-tone"
# Updated endpoint (as of 2024)
api_url = f"https://api-inference.huggingface.co/models/{model_name}"

print(f"API Endpoint: {api_url}")
print(f"Model: {model_name}")
print()

if api_token:
    headers = {"Authorization": f"Bearer {api_token}"}
    print("[OK] Using authenticated API call")
else:
    headers = {}
    print("[INFO] Using unauthenticated API call (rate limited)")

print()

# Test with sample text
test_text = "The market shows strong bullish momentum with positive economic indicators."
print(f"Test text: {test_text}")
print()
print("Sending request to HuggingFace API...")
print("(This may take 10-30 seconds on first call - model loading on HF servers)")
print()

try:
    payload = {"inputs": test_text}
    response = requests.post(api_url, headers=headers, json=payload, timeout=60)
    
    print(f"HTTP Status: {response.status_code}")
    
    if response.status_code == 200:
        result = response.json()
        
        # Handle different response formats
        if isinstance(result, list) and len(result) > 0:
            if isinstance(result[0], list):
                result = result[0]  # Nested list
            
            print()
            print("[OK] Analysis result:")
            for item in result:
                label = item.get('label', 'unknown')
                score = item.get('score', 0.0)
                print(f"  {label:15s}: {score:.4f} ({score*100:.2f}%)")
            
            print()
            print("=" * 70)
            print("SUCCESS: HuggingFace API is working correctly!")
            print("=" * 70)
            print()
            print("The API approach will work for your system!")
            print()
            print("Next steps:")
            print("1. Get API token from: https://huggingface.co/settings/tokens")
            print("2. Set environment variable: HF_API_TOKEN=your_token_here")
            print("3. Update enhanced_finbert_analyzer.py to use API")
            print()
            sys.exit(0)
        else:
            print(f"[ERROR] Unexpected response format: {result}")
            sys.exit(1)
            
    elif response.status_code == 503:
        print("[INFO] Model is loading on HuggingFace servers")
        print("[INFO] Wait 30 seconds and try again")
        print(f"Response: {response.json()}")
        print()
        print("This is normal - HuggingFace loads models on-demand")
        print("After first load, subsequent requests are fast")
        sys.exit(0)
        
    else:
        error_data = response.json() if response.content else {}
        print(f"[ERROR] API request failed")
        print(f"Status: {response.status_code}")
        print(f"Response: {error_data}")
        sys.exit(1)

except requests.exceptions.Timeout:
    print("[ERROR] Request timed out")
    print("This might mean the model is loading (can take 30+ seconds)")
    print("Try again in a moment")
    sys.exit(1)
    
except Exception as e:
    print()
    print("=" * 70)
    print("ERROR: API test failed")
    print("=" * 70)
    print(f"Error: {e}")
    print()
    print("Full traceback:")
    traceback.print_exc()
    print()
    sys.exit(1)

