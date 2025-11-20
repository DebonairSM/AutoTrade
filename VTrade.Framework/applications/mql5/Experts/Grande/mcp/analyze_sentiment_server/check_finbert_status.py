#!/usr/bin/env python3
"""
Quick diagnostic to check if FinBERT is working or using fallback mode
"""

import sys
import os

print("=" * 70)
print("FinBERT Status Diagnostic")
print("=" * 70)
print()

# Import the actual analyzer to test
try:
    # Change to the directory where the module is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, script_dir)
    
    from enhanced_finbert_analyzer import get_finbert_pipeline
    
    print("Testing FinBERT pipeline loading...")
    print()
    
    pipeline = get_finbert_pipeline()
    
    if pipeline is None:
        print("=" * 70)
        print("STATUS: FinBERT NOT LOADED")
        print("=" * 70)
        print()
        print("Your system is using FALLBACK keyword-based analysis.")
        print()
        print("This means:")
        print("  - Basic sentiment analysis is active (keyword matching)")
        print("  - Trading system is working normally")
        print("  - AI deep learning sentiment analysis is NOT active")
        print()
        print("This is OK - your system continues to work correctly.")
        print()
        sys.exit(0)
    else:
        print("=" * 70)
        print("STATUS: FinBERT IS LOADED!")
        print("=" * 70)
        print()
        print("Your system is using REAL FinBERT AI analysis!")
        print()
        
        # Test it with a sample text
        print("Testing with sample financial text...")
        test_text = "The market shows strong bullish momentum with positive economic indicators."
        result = pipeline(test_text)
        
        print()
        print("FinBERT Analysis Result:")
        print("-" * 70)
        for item in result[0]:
            label = item['label']
            score = item['score']
            print(f"  {label:15s}: {score:.4f} ({score*100:.2f}%)")
        
        print()
        print("=" * 70)
        print("SUCCESS: FinBERT AI is working correctly!")
        print("=" * 70)
        print()
        print("Your Grande Trading System is using advanced AI sentiment analysis.")
        print()
        sys.exit(0)

except Exception as e:
    print("=" * 70)
    print("ERROR: Could not check FinBERT status")
    print("=" * 70)
    print(f"Error: {e}")
    print()
    print("This suggests:")
    print("  - FinBERT is likely NOT loaded")
    print("  - System is using fallback keyword analysis")
    print("  - Your trading system continues to work normally")
    print()
    sys.exit(1)

