#!/usr/bin/env python3
"""
Test ModernFinBERT as alternative to original FinBERT
ModernFinBERT: tabularisai/ModernFinBERT
- Better accuracy (48% improvement)
- Actively maintained
- PyTorch-native (no TensorFlow conversion)
- More likely to work with Python 3.13
"""

import sys
import traceback

print("=" * 70)
print("Testing ModernFinBERT Alternative")
print("=" * 70)
print()
print("Model: tabularisai/ModernFinBERT")
print("Why: Better accuracy, actively maintained, PyTorch-native")
print()

try:
    print("Step 1: Testing imports...")
    import torch
    print(f"[OK] PyTorch: {torch.__version__}")
    
    import transformers
    print(f"[OK] Transformers: {transformers.__version__}")
    print()

    print("Step 2: Loading ModernFinBERT...")
    print("This may take 2-5 minutes on first run (downloading model)...")
    print()
    
    from transformers import AutoTokenizer, AutoModelForSequenceClassification, TextClassificationPipeline
    
    model_name = "tabularisai/ModernFinBERT"
    print(f"Model: {model_name}")
    
    print("Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    print("[OK] Tokenizer loaded successfully!")
    
    print("Loading model...")
    model = AutoModelForSequenceClassification.from_pretrained(model_name)
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
    test_text = "The market shows strong bullish momentum with positive economic indicators and rising GDP."
    result = pipeline(test_text)
    
    print("[OK] Analysis result:")
    for item in result[0]:
        label = item['label']
        score = item['score']
        print(f"  {label:15s}: {score:.4f} ({score*100:.2f}%)")
    
    print()
    print("=" * 70)
    print("SUCCESS: ModernFinBERT is working correctly!")
    print("=" * 70)
    print()
    print("ModernFinBERT is ready to use!")
    print()
    print("To use in your system:")
    print("1. Update enhanced_finbert_analyzer.py:")
    print('   Change: model_name = os.environ.get("FINBERT_MODEL", "yiyanghkust/finbert-tone")')
    print('   To:     model_name = os.environ.get("FINBERT_MODEL", "tabularisai/ModernFinBERT")')
    print()
    print("2. Restart your FinBERT watcher service")
    print("3. Restart your MT5 terminal and EA")
    print()
    print("ModernFinBERT offers:")
    print("  - 48% better accuracy than original FinBERT")
    print("  - Better Python 3.13 compatibility")
    print("  - PyTorch-native (faster loading)")
    print("  - Actively maintained")
    print()
    sys.exit(0)

except Exception as e:
    print()
    print("=" * 70)
    print("ERROR: ModernFinBERT loading failed")
    print("=" * 70)
    print(f"Error: {e}")
    print()
    print("Full traceback:")
    traceback.print_exc()
    print()
    print("=" * 70)
    print("ModernFinBERT didn't work, but we can try other alternatives:")
    print("  - ProsusAI/finbert")
    print("  - DistilRoBERTa financial sentiment models")
    print()
    print("Or continue with fallback mode (already working)")
    print("=" * 70)
    sys.exit(1)

