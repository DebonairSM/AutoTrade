#!/usr/bin/env python3
"""
Test ProsusAI/finbert as alternative to original FinBERT
"""

import sys
import traceback

print("=" * 70)
print("Testing ProsusAI/finbert Alternative")
print("=" * 70)
print()

try:
    print("Step 1: Testing imports...")
    import torch
    print(f"[OK] PyTorch: {torch.__version__}")
    
    import transformers
    print(f"[OK] Transformers: {transformers.__version__}")
    print()

    print("Step 2: Loading ProsusAI/finbert...")
    print("This may take 2-5 minutes on first run...")
    print()
    
    from transformers import AutoTokenizer, AutoModelForSequenceClassification, TextClassificationPipeline
    
    model_name = "ProsusAI/finbert"
    print(f"Model: {model_name}")
    
    print("Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    print("[OK] Tokenizer loaded successfully!")
    
    print("Loading model (may need TensorFlow conversion)...")
    try:
        model = AutoModelForSequenceClassification.from_pretrained(model_name)
    except OSError as e:
        if "TensorFlow weights" in str(e):
            print("[INFO] Converting from TensorFlow weights...")
            model = AutoModelForSequenceClassification.from_pretrained(model_name, from_tf=True)
        else:
            raise
    
    print("[OK] Model loaded successfully!")
    
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
    test_text = "The market shows strong bullish momentum with positive economic indicators."
    result = pipeline(test_text)
    
    print("[OK] Analysis result:")
    for item in result[0]:
        label = item['label']
        score = item['score']
        print(f"  {label:15s}: {score:.4f} ({score*100:.2f}%)")
    
    print()
    print("=" * 70)
    print("SUCCESS: ProsusAI/finbert is working correctly!")
    print("=" * 70)
    print()
    print("ProsusAI/finbert is ready to use!")
    print()
    sys.exit(0)

except Exception as e:
    print()
    print("=" * 70)
    print("ERROR: ProsusAI/finbert loading failed")
    print("=" * 70)
    print(f"Error: {e}")
    print()
    print("Full traceback:")
    traceback.print_exc()
    print()
    sys.exit(1)

