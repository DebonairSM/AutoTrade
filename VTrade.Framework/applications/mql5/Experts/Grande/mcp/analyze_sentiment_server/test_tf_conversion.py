#!/usr/bin/env python3
"""
Test FinBERT loading with TensorFlow conversion
"""

import sys
import traceback

print("=" * 60)
print("Testing FinBERT with TensorFlow Conversion")
print("=" * 60)
print()

try:
    print("Step 1: Testing imports...")
    import torch
    print(f"[OK] PyTorch: {torch.__version__}")
    
    import transformers
    print(f"[OK] Transformers: {transformers.__version__}")
    print()

    print("Step 2: Loading FinBERT with TensorFlow conversion...")
    print("This may take 3-5 minutes (downloading + converting model)...")
    print()
    
    from transformers import AutoTokenizer, AutoModelForSequenceClassification, TextClassificationPipeline
    
    model_name = "yiyanghkust/finbert-tone"
    print(f"Model: {model_name}")
    
    print("Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    print("[OK] Tokenizer loaded")
    
    print("Loading model from TensorFlow weights (converting to PyTorch)...")
    model = AutoModelForSequenceClassification.from_pretrained(model_name, from_tf=True)
    print("[OK] Model loaded and converted successfully!")
    
    print("Creating pipeline...")
    device = 0 if torch.cuda.is_available() else -1
    pipeline = TextClassificationPipeline(
        model=model,
        tokenizer=tokenizer,
        return_all_scores=True,
        device=device,
    )
    print(f"[OK] Pipeline created (device: {device})")
    print()

    print("Step 3: Testing sentiment analysis...")
    test_text = "The market shows strong bullish momentum with positive indicators."
    result = pipeline(test_text)
    print(f"[OK] Analysis result:")
    for item in result[0]:
        label = item['label']
        score = item['score']
        print(f"  {label}: {score:.4f} ({score*100:.2f}%)")
    
    print()
    print("=" * 60)
    print("SUCCESS: FinBERT is working correctly!")
    print("=" * 60)
    print()
    print("The model was successfully loaded from TensorFlow weights.")
    print("Your Grande Trading System can now use real FinBERT AI analysis.")
    print()
    print("Next steps:")
    print("1. The code has been updated to use this conversion method")
    print("2. Restart your FinBERT watcher service")
    print("3. Restart your MT5 terminal and EA")
    print()

except Exception as e:
    print()
    print("=" * 60)
    print("ERROR: FinBERT loading failed")
    print("=" * 60)
    print(f"Error: {e}")
    print()
    print("Full traceback:")
    traceback.print_exc()
    print()
    print("=" * 60)
    print("This might require TensorFlow for conversion.")
    print("Your system will continue using fallback keyword analysis.")
    print("=" * 60)
    sys.exit(1)
