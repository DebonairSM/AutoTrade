#!/usr/bin/env python3
"""
Alternative FinBERT test using pipeline approach which may handle model config better
"""

import sys
import traceback

print("=" * 60)
print("Testing FinBERT with Alternative Methods")
print("=" * 60)
print()

# Method 1: Try using pipeline directly (handles model config automatically)
print("Method 1: Testing with pipeline (automatic model handling)...")
try:
    from transformers import pipeline
    
    # Try loading FinBERT directly via pipeline
    print("Loading FinBERT via pipeline...")
    print("This may take 2-5 minutes on first run...")
    print()
    
    finbert_pipeline = pipeline(
        "text-classification",
        model="yiyanghkust/finbert-tone",
        return_all_scores=True
    )
    
    print("[OK] FinBERT pipeline loaded successfully!")
    print()
    
    # Test it
    test_text = "The market shows strong bullish momentum with positive indicators."
    result = finbert_pipeline(test_text)
    
    print("[OK] Test analysis:")
    for item in result[0]:
        label = item['label']
        score = item['score']
        print(f"  {label}: {score:.4f} ({score*100:.2f}%)")
    
    print()
    print("=" * 60)
    print("SUCCESS: FinBERT is working correctly!")
    print("=" * 60)
    print()
    print("Your Grande Trading System can now use real FinBERT AI analysis.")
    print()
    sys.exit(0)
    
except Exception as e1:
    print(f"[FAILED] Pipeline method failed: {e1}")
    print()
    
    # Method 2: Try with a different FinBERT model
    print("Method 2: Trying alternative financial sentiment model...")
    try:
        from transformers import pipeline
        
        # Try an alternative financial model
        print("Loading alternative model: ProsusAI/finbert...")
        alt_pipeline = pipeline(
            "sentiment-analysis",
            model="ProsusAI/finbert",
            return_all_scores=True
        )
        
        print("[OK] Alternative FinBERT model loaded!")
        test_text = "The market shows strong bullish momentum."
        result = alt_pipeline(test_text)
        
        print("[OK] Test result:", result)
        print()
        print("=" * 60)
        print("SUCCESS: Alternative FinBERT model works!")
        print("=" * 60)
        print("Note: Using ProsusAI/finbert instead of yiyanghkust/finbert-tone")
        print("This model provides similar financial sentiment analysis.")
        print()
        sys.exit(0)
        
    except Exception as e2:
        print(f"[FAILED] Alternative model also failed: {e2}")
        print()
        
        # Method 3: Use a basic financial sentiment model
        print("Method 3: Trying basic financial sentiment model...")
        try:
            from transformers import pipeline
            
            print("Loading basic sentiment model (general purpose)...")
            basic_pipeline = pipeline("sentiment-analysis")
            
            test_text = "The market shows strong bullish momentum with positive indicators."
            result = basic_pipeline(test_text)
            
            print("[OK] Basic sentiment model works:", result)
            print()
            print("=" * 60)
            print("WARNING: Using general sentiment model, not FinBERT")
            print("=" * 60)
            print("FinBERT specifically trained for financial text is not available.")
            print("Your system will use general sentiment analysis instead.")
            print("This is better than keyword matching but not as specialized.")
            print()
            sys.exit(0)
            
        except Exception as e3:
            print(f"[FAILED] All methods failed")
            print()
            print("=" * 60)
            print("ERROR: Could not load any FinBERT model")
            print("=" * 60)
            print(f"Pipeline error: {e1}")
            print(f"Alternative error: {e2}")
            print(f"Basic error: {e3}")
            print()
            print("Full traceback (pipeline):")
            traceback.print_exc()
            print()
            print("Your system will continue using fallback keyword analysis.")
            print("=" * 60)
            sys.exit(1)
