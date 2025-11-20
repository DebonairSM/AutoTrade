#!/usr/bin/env python3
"""Show the exact FinBERT error"""
from transformers import AutoTokenizer
import traceback

try:
    print("Attempting to load FinBERT tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained('yiyanghkust/finbert-tone')
    print("Success!")
except Exception as e:
    print(f"\n{'='*60}")
    print(f"ERROR TYPE: {type(e).__name__}")
    print(f"ERROR MESSAGE: {str(e)}")
    print(f"{'='*60}\n")
    print("Full traceback:")
    traceback.print_exc()

