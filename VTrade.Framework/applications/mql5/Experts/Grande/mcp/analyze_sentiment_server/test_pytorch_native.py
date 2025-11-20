#!/usr/bin/env python3
"""
Test PyTorch-native financial sentiment models (no TensorFlow needed)
"""

import sys
import traceback

print("=" * 60)
print("Testing PyTorch-Native Financial Sentiment Models")
print("=" * 60)
print()

# Try multiple PyTorch-native models
models_to_try = [
    ("cardiffnlp/twitter-roberta-base-sentiment-latest", "Twitter RoBERTa Sentiment"),
    ("nlptown/bert-base-multilingual-uncased-sentiment", "Multi-lingual Sentiment"),
    ("distilbert-base-uncased-finetuned-sst-2-english", "DistilBERT Sentiment"),
]

working_model = None

for model_name, description in models_to_try:
    print(f"Trying: {description}")
    print(f"Model: {model_name}")
    print()
    
    try:
        from transformers import pipeline
        
        print("Loading pipeline...")
        sentiment_pipeline = pipeline(
            "sentiment-analysis",
            model=model_name,
            return_all_scores=True
        )
        
        print(f"[OK] {description} loaded successfully!")
        
        # Test it
        test_text = "The market shows strong bullish momentum with positive economic indicators."
        result = sentiment_pipeline(test_text)
        
        print(f"[OK] Test result:")
        for item in result[0]:
            label = item['label']
            score = item['score']
            print(f"  {label}: {score:.4f} ({score*100:.2f}%)")
        
        working_model = (model_name, description)
        print()
        break
        
    except Exception as e:
        print(f"[FAILED] {description}: {str(e)[:100]}")
        print()
        continue

if working_model:
    model_name, description = working_model
    print("=" * 60)
    print("SUCCESS: Found working PyTorch-native model!")
    print("=" * 60)
    print(f"Model: {model_name}")
    print(f"Description: {description}")
    print()
    print("This model can be used for financial sentiment analysis.")
    print("While not specifically trained on financial text, it provides")
    print("real AI-based sentiment analysis that's better than keyword matching.")
    print()
    print("Next steps:")
    print("1. Update enhanced_finbert_analyzer.py to use this model")
    print("2. Restart the FinBERT watcher service")
    print("3. Restart your MT5 terminal and EA")
    print()
else:
    print("=" * 60)
    print("No working PyTorch-native models found")
    print("=" * 60)
    print()
    print("All tested models failed. This may indicate:")
    print("1. Network connectivity issues")
    print("2. HuggingFace cache corruption")
    print("3. Python environment issues")
    print()
    print("Your system will continue using fallback keyword analysis.")
    print("=" * 60)
    sys.exit(1)

