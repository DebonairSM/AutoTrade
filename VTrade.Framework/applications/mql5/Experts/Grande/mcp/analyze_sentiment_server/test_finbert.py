#!/usr/bin/env python3
"""
Test script to verify FinBERT is working properly
"""

import sys
print('Testing FinBERT availability...')
print('=' * 50)

try:
    import torch
    print(f'✅ PyTorch: {torch.__version__}')
except Exception as e:
    print(f'❌ PyTorch error: {e}')
    sys.exit(1)

try:
    import transformers
    print(f'✅ Transformers: {transformers.__version__}')
except Exception as e:
    print(f'❌ Transformers error: {e}')
    sys.exit(1)

try:
    from transformers import AutoTokenizer, AutoModelForSequenceClassification, TextClassificationPipeline
    print('✅ Import successful')
    
    # Test loading FinBERT
    print('🤖 Loading FinBERT model...')
    model_name = 'yiyanghkust/finbert-tone'
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(model_name)
    
    # Test actual sentiment analysis
    pipe = TextClassificationPipeline(
        model=model, 
        tokenizer=tokenizer, 
        return_all_scores=True
    )
    
    test_text = 'The Federal Reserve announced a dovish stance with interest rate cuts, boosting market confidence.'
    print(f'📝 Testing with text: {test_text[:50]}...')
    
    result = pipe(test_text)
    print('✅ FinBERT analysis result:')
    for item in result[0]:
        label = item['label']
        score = item['score']
        print(f'   {label}: {score:.3f}')
    
    # Test negative sentiment
    test_text2 = 'Market crashed due to hawkish Fed comments and rising unemployment concerns.'
    print(f'\n📝 Testing negative sentiment: {test_text2[:50]}...')
    
    result2 = pipe(test_text2)
    print('✅ FinBERT analysis result:')
    for item in result2[0]:
        label = item['label']
        score = item['score']
        print(f'   {label}: {score:.3f}')
    
    print('')
    print('🎉 FinBERT is working perfectly!')
    print('🎯 Real AI sentiment analysis is functional!')
    
except Exception as e:
    print(f'❌ FinBERT test failed: {e}')
    print(f'Error details: {type(e).__name__}: {str(e)}')
    sys.exit(1)
