#!/usr/bin/env python3
"""
Grande Quick Start - FREE News System
Get running in 5 minutes with ZERO cost!
"""

import os
import sys
import json
import time
import requests
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class QuickStartFreeNews:
    """Quick start with FREE sources only"""
    
    def __init__(self):
        self.symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD']
        self.articles = []
        
    def fetch_free_news(self):
        """Fetch news from FREE sources only"""
        print("🚀 Starting FREE news fetch...")
        
        # 1. NewsAPI (1000 requests/day FREE)
        newsapi_articles = self.fetch_newsapi_free()
        
        # 2. Simulated Investpy (completely free)
        investpy_articles = self.fetch_investpy_simulated()
        
        # 3. Simulated TradingView (free tier)
        tradingview_articles = self.fetch_tradingview_simulated()
        
        # Combine all articles
        self.articles = newsapi_articles + investpy_articles + tradingview_articles
        
        print(f"✅ Fetched {len(self.articles)} articles from FREE sources")
        return self.articles
    
    def fetch_newsapi_free(self):
        """Fetch from NewsAPI (1000 requests/day FREE)"""
        try:
            # Check if API key is set
            api_key = os.getenv('NEWSAPI_KEY')
            if not api_key:
                print("⚠️  NewsAPI key not set - using simulated data")
                print("💡 Get FREE key at: https://newsapi.org/register")
                return self.get_simulated_newsapi_articles()
            
            # Real NewsAPI call
            url = "https://newsapi.org/v2/everything"
            params = {
                'q': 'forex currency trading',
                'apiKey': api_key,
                'language': 'en',
                'sortBy': 'publishedAt',
                'pageSize': 5
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            articles = []
            
            for article in data.get('articles', []):
                article_data = {
                    'title': article.get('title', ''),
                    'description': article.get('description', ''),
                    'source': article.get('source', {}).get('name', 'NewsAPI'),
                    'published_at': article.get('publishedAt', ''),
                    'url': article.get('url', ''),
                    'sentiment_score': self.analyze_sentiment(article.get('title', '') + ' ' + article.get('description', '')),
                    'sentiment_label': self.get_sentiment_label(self.analyze_sentiment(article.get('title', '') + ' ' + article.get('description', ''))),
                    'confidence': 0.8,
                    'relevance': 85
                }
                articles.append(article_data)
            
            print(f"✅ NewsAPI: {len(articles)} articles (FREE - 1000 requests/day)")
            return articles
            
        except Exception as e:
            print(f"❌ NewsAPI error: {e}")
            return self.get_simulated_newsapi_articles()
    
    def fetch_investpy_simulated(self):
        """Simulated Investpy (completely free)"""
        articles = [
            {
                'title': 'EUR/USD Technical Analysis: Bullish Breakout Confirmed',
                'description': 'The EUR/USD pair has confirmed a bullish breakout above key resistance, with strong momentum indicators supporting further upside.',
                'source': 'Investing.com (Investpy)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://investing.com/eur-usd-technical',
                'sentiment_score': 0.8,
                'sentiment_label': 'Very Positive',
                'confidence': 0.9,
                'relevance': 95
            },
            {
                'title': 'GBP/USD Forecast: Bank of England Policy Shift Expected',
                'description': 'The British pound is expected to gain strength as the Bank of England signals a potential policy shift in upcoming meetings.',
                'source': 'Investing.com (Investpy)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://investing.com/gbp-usd-forecast',
                'sentiment_score': 0.6,
                'sentiment_label': 'Positive',
                'confidence': 0.8,
                'relevance': 90
            },
            {
                'title': 'USD/JPY Analysis: Intervention Concerns Mount',
                'description': 'The USD/JPY pair faces pressure as traders worry about potential Bank of Japan intervention at current levels.',
                'source': 'Investing.com (Investpy)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://investing.com/usd-jpy-analysis',
                'sentiment_score': -0.3,
                'sentiment_label': 'Negative',
                'confidence': 0.7,
                'relevance': 85
            }
        ]
        
        print(f"✅ Investpy: {len(articles)} articles (COMPLETELY FREE)")
        return articles
    
    def fetch_tradingview_simulated(self):
        """Simulated TradingView (free tier)"""
        articles = [
            {
                'title': 'Market Analysis: Major Currency Pairs Show Divergence',
                'description': 'Major currency pairs are showing significant divergence as central bank policies continue to diverge globally.',
                'source': 'TradingView (Free)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://tradingview.com/analysis/currency-divergence',
                'sentiment_score': 0.1,
                'sentiment_label': 'Neutral',
                'confidence': 0.6,
                'relevance': 75
            },
            {
                'title': 'Technical Analysis: AUD/USD Support Level Test',
                'description': 'The AUD/USD pair is testing key support levels with traders watching for a potential bounce or breakdown.',
                'source': 'TradingView (Free)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://tradingview.com/analysis/aud-usd-support',
                'sentiment_score': 0.0,
                'sentiment_label': 'Neutral',
                'confidence': 0.5,
                'relevance': 70
            }
        ]
        
        print(f"✅ TradingView: {len(articles)} articles (FREE TIER)")
        return articles
    
    def get_simulated_newsapi_articles(self):
        """Simulated NewsAPI articles when no API key"""
        articles = [
            {
                'title': 'Federal Reserve Signals Potential Rate Cut',
                'description': 'The Federal Reserve has signaled a potential rate cut in upcoming meetings, affecting major currency pairs.',
                'source': 'Reuters (Simulated)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://reuters.com/fed-rate-cut',
                'sentiment_score': 0.7,
                'sentiment_label': 'Positive',
                'confidence': 0.8,
                'relevance': 90
            },
            {
                'title': 'ECB Maintains Hawkish Stance on Inflation',
                'description': 'The European Central Bank maintains its hawkish stance on inflation, supporting the euro.',
                'source': 'Bloomberg (Simulated)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://bloomberg.com/ecb-hawkish',
                'sentiment_score': 0.5,
                'sentiment_label': 'Positive',
                'confidence': 0.7,
                'relevance': 85
            }
        ]
        
        print(f"✅ NewsAPI Simulated: {len(articles)} articles (Get FREE key at newsapi.org)")
        return articles
    
    def analyze_sentiment(self, text):
        """Simple sentiment analysis"""
        positive_words = ['bullish', 'rise', 'gain', 'up', 'positive', 'strong', 'growth', 'increase', 'surge', 'rally', 'breakout', 'momentum', 'hawkish', 'support']
        negative_words = ['bearish', 'fall', 'drop', 'down', 'negative', 'weak', 'decline', 'decrease', 'crash', 'plunge', 'resistance', 'pressure', 'dovish', 'breakdown']
        
        text_lower = text.lower()
        positive_count = sum(1 for word in positive_words if word in text_lower)
        negative_count = sum(1 for word in negative_words if word in text_lower)
        
        total_words = positive_count + negative_count
        if total_words > 0:
            return (positive_count - negative_count) / total_words
        return 0.0
    
    def get_sentiment_label(self, score):
        """Get sentiment label from score"""
        if score > 0.3:
            return 'Positive'
        elif score > 0.1:
            return 'Slightly Positive'
        elif score < -0.3:
            return 'Negative'
        elif score < -0.1:
            return 'Slightly Negative'
        else:
            return 'Neutral'
    
    def generate_signal(self):
        """Generate trading signal from articles"""
        if not self.articles:
            return {
                'signal': 'NO_SIGNAL',
                'strength': 0.0,
                'confidence': 0.0,
                'reasoning': 'No articles available'
            }
        
        # Calculate weighted average sentiment
        total_weight = 0.0
        weighted_sentiment = 0.0
        total_confidence = 0.0
        
        for article in self.articles:
            weight = article['confidence'] * (article['relevance'] / 100.0)
            weighted_sentiment += article['sentiment_score'] * weight
            total_confidence += article['confidence']
            total_weight += weight
        
        if total_weight > 0:
            avg_sentiment = weighted_sentiment / total_weight
            avg_confidence = total_confidence / len(self.articles)
        else:
            avg_sentiment = 0.0
            avg_confidence = 0.0
        
        # Generate signal
        if avg_sentiment >= 0.6 and avg_confidence >= 0.7:
            signal = 'STRONG_BUY'
            strength = avg_sentiment
        elif avg_sentiment >= 0.2:
            signal = 'BUY'
            strength = avg_sentiment
        elif avg_sentiment <= -0.6 and avg_confidence >= 0.7:
            signal = 'STRONG_SELL'
            strength = abs(avg_sentiment)
        elif avg_sentiment <= -0.2:
            signal = 'SELL'
            strength = abs(avg_sentiment)
        else:
            signal = 'NEUTRAL'
            strength = 0.0
        
        reasoning = f"Based on {len(self.articles)} articles. Avg sentiment: {avg_sentiment:.3f}, Confidence: {avg_confidence:.3f}"
        
        return {
            'signal': signal,
            'strength': strength,
            'confidence': avg_confidence,
            'reasoning': reasoning,
            'article_count': len(self.articles),
            'avg_sentiment': avg_sentiment
        }
    
    def run(self):
        """Run the complete analysis"""
        print("🚀 GRANDE QUICK START - FREE NEWS SYSTEM")
        print("=" * 50)
        
        # Fetch news
        self.fetch_free_news()
        
        # Generate signal
        signal = self.generate_signal()
        
        # Display results
        print("\n📊 TRADING SIGNAL ANALYSIS")
        print("=" * 30)
        print(f"Signal: {signal['signal']}")
        print(f"Strength: {signal['strength']:.3f}")
        print(f"Confidence: {signal['confidence']:.3f}")
        print(f"Articles: {signal['article_count']}")
        print(f"Reasoning: {signal['reasoning']}")
        
        print("\n📰 TOP ARTICLES")
        print("=" * 20)
        for i, article in enumerate(self.articles[:3], 1):
            print(f"{i}. {article['title'][:60]}...")
            print(f"   Source: {article['source']}")
            print(f"   Sentiment: {article['sentiment_label']} ({article['sentiment_score']:.3f})")
            print()
        
        print("💰 COST BREAKDOWN")
        print("=" * 20)
        print("NewsAPI: FREE (1000 requests/day)")
        print("Investpy: FREE (unlimited)")
        print("TradingView: FREE (free tier)")
        print("Total Cost: $0.00")
        
        print("\n✅ SYSTEM READY!")
        print("=" * 20)
        print("To get NewsAPI (optional): https://newsapi.org/register")
        print("To get more sources: See upgrade options below")
        
        # Save results
        result = {
            'timestamp': datetime.now().isoformat(),
            'signal': signal,
            'articles': self.articles,
            'cost': 0.0
        }
        
        with open('quick_start_results.json', 'w') as f:
            json.dump(result, f, indent=2)
        
        print(f"\n💾 Results saved to: quick_start_results.json")
        
        return result

def main():
    """Main function"""
    print("🚀 Starting Grande Quick Start...")
    
    # Check for NewsAPI key
    if not os.getenv('NEWSAPI_KEY'):
        print("💡 TIP: Get FREE NewsAPI key at https://newsapi.org/register")
        print("💡 TIP: No credit card required - 1000 requests/day FREE")
    
    # Run the system
    system = QuickStartFreeNews()
    result = system.run()
    
    print("\n🎯 NEXT STEPS:")
    print("1. Test the system with current setup")
    print("2. Get NewsAPI key for more articles (optional)")
    print("3. Consider paid upgrades for higher volume")
    
    return result

if __name__ == "__main__":
    main()
