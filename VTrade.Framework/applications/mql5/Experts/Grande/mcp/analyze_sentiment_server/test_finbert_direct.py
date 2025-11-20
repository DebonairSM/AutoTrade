#!/usr/bin/env python3
"""
Direct test of FinBERT loading without file dependencies
"""

import sys
import traceback

print("Testing FinBERT loading directly...")
print("=" * 60)

try:
    print("1. Testing basic imports...")
    import torch
    print(f"[OK] PyTorch: {torch.__version__}")
    
    import transformers
    print(f"[OK] Transformers: {transformers.__version__}")
    
    import google.protobuf
    print(f"[OK] Protobuf: Available")
    print()

    print("2. Testing FinBERT model loading...")
    from transformers import (
        AutoTokenizer,
        AutoModelForSequenceClassification,
        TextClassificationPipeline,
    )
    print("[OK] Transformers imports successful")

    print("3. Loading FinBERT model...")
    model_name = "yiyanghkust/finbert-tone"
    print(f"Model: {model_name}")
    
    print("Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    print("[OK] Tokenizer loaded")
    
    print("Loading model...")
    model = AutoModelForSequenceClassification.from_pretrained(model_name)
    print("[OK] Model loaded")
    
    print("Creating pipeline...")
    device = 0 if torch.cuda.is_available() else -1
    pipeline = TextClassificationPipeline(
        model=model,
        tokenizer=tokenizer,
        return_all_scores=True,
        device=device,
    )
    print(f"[OK] Pipeline created (device: {device})")
    
    print("4. Testing sentiment analysis...")
    test_text = "The market shows strong bullish momentum with positive indicators."
    result = pipeline(test_text)
    print(f"[OK] Analysis result: {result}")
    
    print()
    print("SUCCESS: FinBERT is working correctly!")
    print("=" * 60)

except Exception as e:
    print(f"[ERROR]: {e}")
    print()
    print("Full traceback:")
    traceback.print_exc()
    print("=" * 60)
    sys.exit(1)
