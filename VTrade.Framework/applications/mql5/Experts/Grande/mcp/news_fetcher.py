#!/usr/bin/env python3
"""
Grande News Fetcher
Fetches real news from various sources and sends to sentiment analysis server
"""

import os
import sys
import json
import time
import requests
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class NewsFetcher:
    """Fetches news from various sources"""
    
    def __init__(self):
        self.marketaux_key = os.getenv('MARKETAUX_API_KEY', '')
        self.alpha_vantage_key = os.getenv('ALPHA_VANTAGE_API_KEY', '')
        self.newsapi_key = os.getenv('NEWSAPI_KEY', '')
        self.sentiment_server_url = os.getenv('SENTIMENT_SERVER_URL', 'http://localhost:8000/mcp')
        
    def fetch_marketaux_news(self, symbols: List[str], limit: int = 10) -> List[Dict[str, Any]]:
        """Fetch news from MarketAux API"""
        if not self.marketaux_key:
            logger.warning("MarketAux API key not provided")
            return []
        
        try:
            url = "https://api.marketaux.com/v1/news/all"
            params = {
                'api_token': self.marketaux_key,
                'symbols': ','.join(symbols),
                'limit': limit,
                'language': 'en',
                'filter_entities': 'true'
            }
            
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            articles = []
            
            for article in data.get('data', []):
                article_data = {
                    'title': article.get('title', ''),
                    'description': article.get('description', ''),
                    'source': article.get('source', ''),
                    'published_at': article.get('published_at', ''),
                    'url': article.get('url', ''),
                    'entities': article.get('entities', []),
                    'sentiment_score': 0.0,
                    'sentiment_label': 'Unknown',
                    'confidence': 0.0
                }
                
                # Extract sentiment from entities if available
                if article_data['entities']:
                    entity = article_data['entities'][0]
                    article_data['sentiment_score'] = entity.get('sentiment_score', 0.0)
                    article_data['confidence'] = entity.get('match_score', 0.0) / 100.0
                    
                    if article_data['sentiment_score'] > 0.1:
                        article_data['sentiment_label'] = 'Positive'
                    elif article_data['sentiment_score'] < -0.1:
                        article_data['sentiment_label'] = 'Negative'
                    else:
                        article_data['sentiment_label'] = 'Neutral'
                
                articles.append(article_data)
            
            logger.info(f"Fetched {len(articles)} articles from MarketAux")
            return articles
            
        except Exception as e:
            logger.error(f"Error fetching MarketAux news: {e}")
            return []
    
    def fetch_alpha_vantage_news(self, symbols: List[str], limit: int = 10) -> List[Dict[str, Any]]:
        """Fetch news from Alpha Vantage API"""
        if not self.alpha_vantage_key:
            logger.warning("Alpha Vantage API key not provided")
            return []
        
        try:
            url = "https://www.alphavantage.co/query"
            params = {
                'function': 'NEWS_SENTIMENT',
                'tickers': ','.join(symbols),
                'apikey': self.alpha_vantage_key,
                'limit': limit,
                'sort': 'LATEST'
            }
            
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            articles = []
            
            for item in data.get('feed', []):
                article_data = {
                    'title': item.get('title', ''),
                    'description': item.get('summary', ''),
                    'source': item.get('source', ''),
                    'published_at': item.get('time_published', ''),
                    'url': item.get('url', ''),
                    'entities': [],
                    'sentiment_score': float(item.get('overall_sentiment_score', 0.0)),
                    'sentiment_label': item.get('overall_sentiment_label', 'Unknown'),
                    'confidence': 0.7  # Alpha Vantage doesn't provide confidence, use default
                }
                
                # Convert sentiment label to score if needed
                if article_data['sentiment_score'] == 0.0:
                    label = article_data['sentiment_label'].lower()
                    if 'bullish' in label or 'positive' in label:
                        article_data['sentiment_score'] = 0.5
                    elif 'bearish' in label or 'negative' in label:
                        article_data['sentiment_score'] = -0.5
                    else:
                        article_data['sentiment_score'] = 0.0
                
                articles.append(article_data)
            
            logger.info(f"Fetched {len(articles)} articles from Alpha Vantage")
            return articles
            
        except Exception as e:
            logger.error(f"Error fetching Alpha Vantage news: {e}")
            return []
    
    def fetch_newsapi_news(self, symbols: List[str], limit: int = 10) -> List[Dict[str, Any]]:
        """Fetch news from NewsAPI"""
        if not self.newsapi_key:
            logger.warning("NewsAPI key not provided")
            return []
        
        try:
            url = "https://newsapi.org/v2/everything"
            params = {
                'q': f"{' OR '.join(symbols)} forex currency",
                'apiKey': self.newsapi_key,
                'pageSize': limit,
                'language': 'en',
                'sortBy': 'publishedAt'
            }
            
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            articles = []
            
            for article in data.get('articles', []):
                article_data = {
                    'title': article.get('title', ''),
                    'description': article.get('description', ''),
                    'source': article.get('source', {}).get('name', ''),
                    'published_at': article.get('publishedAt', ''),
                    'url': article.get('url', ''),
                    'entities': [],
                    'sentiment_score': 0.0,
                    'sentiment_label': 'Unknown',
                    'confidence': 0.0
                }
                articles.append(article_data)
            
            logger.info(f"Fetched {len(articles)} articles from NewsAPI")
            return articles
            
        except Exception as e:
            logger.error(f"Error fetching NewsAPI news: {e}")
            return []

class SentimentAnalyzer:
    """Sends news to sentiment analysis server"""
    
    def __init__(self, server_url: str):
        self.server_url = server_url
    
    async def analyze_article_sentiment(self, article: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze sentiment of a single article"""
        try:
            # Prepare text for analysis
            text = f"{article['title']} {article['description']}"
            
            # Call sentiment analysis server
            payload = {
                "text": text
            }
            
            # For now, we'll simulate the MCP call
            # In a real implementation, you'd use the MCP client
            sentiment_result = await self.simulate_sentiment_analysis(text)
            
            # Update article with sentiment results
            article['sentiment_score'] = sentiment_result['score']
            article['sentiment_label'] = sentiment_result['sentiment']
            article['confidence'] = sentiment_result['confidence']
            
            return article
            
        except Exception as e:
            logger.error(f"Error analyzing sentiment: {e}")
            return article
    
    async def simulate_sentiment_analysis(self, text: str) -> Dict[str, Any]:
        """Simulate sentiment analysis (replace with actual MCP call)"""
        # Simple keyword-based sentiment analysis
        positive_words = ['bullish', 'rise', 'gain', 'up', 'positive', 'strong', 'growth', 'increase', 'surge', 'rally', 'optimistic', 'good', 'better', 'improve']
        negative_words = ['bearish', 'fall', 'drop', 'down', 'negative', 'weak', 'decline', 'decrease', 'crash', 'plunge', 'pessimistic', 'bad', 'worse', 'worry']
        
        text_lower = text.lower()
        positive_count = sum(1 for word in positive_words if word in text_lower)
        negative_count = sum(1 for word in negative_words if word in text_lower)
        
        total_words = positive_count + negative_count
        if total_words > 0:
            score = (positive_count - negative_count) / total_words
            confidence = min(total_words / 10.0, 1.0)
        else:
            score = 0.0
            confidence = 0.1
        
        if score > 0.2:
            sentiment = 'Positive'
        elif score < -0.2:
            sentiment = 'Negative'
        else:
            sentiment = 'Neutral'
        
        return {
            'sentiment': sentiment,
            'score': score,
            'confidence': confidence
        }

class NewsSignalGenerator:
    """Main class that orchestrates news fetching and signal generation"""
    
    def __init__(self):
        self.news_fetcher = NewsFetcher()
        self.sentiment_analyzer = SentimentAnalyzer(self.news_fetcher.sentiment_server_url)
        self.symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD']
    
    async def fetch_and_analyze_news(self) -> List[Dict[str, Any]]:
        """Fetch news from all sources and analyze sentiment"""
        all_articles = []
        
        # Fetch from MarketAux
        marketaux_articles = self.news_fetcher.fetch_marketaux_news(self.symbols, 5)
        all_articles.extend(marketaux_articles)
        
        # Fetch from Alpha Vantage
        alpha_articles = self.news_fetcher.fetch_alpha_vantage_news(self.symbols, 5)
        all_articles.extend(alpha_articles)
        
        # Fetch from NewsAPI
        newsapi_articles = self.news_fetcher.fetch_newsapi_news(self.symbols, 5)
        all_articles.extend(newsapi_articles)
        
        # Analyze sentiment for articles that don't have it
        analyzed_articles = []
        for article in all_articles:
            if article['sentiment_score'] == 0.0 and article['confidence'] == 0.0:
                article = await self.sentiment_analyzer.analyze_article_sentiment(article)
            analyzed_articles.append(article)
        
        return analyzed_articles
    
    def generate_trading_signal(self, articles: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate trading signal based on analyzed articles"""
        if not articles:
            return {
                'signal': 'NO_SIGNAL',
                'strength': 0.0,
                'confidence': 0.0,
                'reasoning': 'No articles available',
                'article_count': 0
            }
        
        # Calculate average sentiment
        valid_articles = [a for a in articles if a['sentiment_score'] != 0.0 or a['confidence'] > 0.0]
        
        if not valid_articles:
            return {
                'signal': 'NO_SIGNAL',
                'strength': 0.0,
                'confidence': 0.0,
                'reasoning': 'No valid articles for analysis',
                'article_count': len(articles)
            }
        
        # Calculate weighted average sentiment
        total_weight = 0.0
        weighted_sentiment = 0.0
        total_confidence = 0.0
        
        for article in valid_articles:
            weight = article['confidence']
            weighted_sentiment += article['sentiment_score'] * weight
            total_confidence += article['confidence']
            total_weight += weight
        
        if total_weight > 0:
            avg_sentiment = weighted_sentiment / total_weight
            avg_confidence = total_confidence / len(valid_articles)
        else:
            avg_sentiment = 0.0
            avg_confidence = 0.0
        
        # Generate signal based on sentiment
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
        
        reasoning = f"Based on {len(valid_articles)} articles. Avg sentiment: {avg_sentiment:.3f}, Confidence: {avg_confidence:.3f}"
        
        return {
            'signal': signal,
            'strength': strength,
            'confidence': avg_confidence,
            'reasoning': reasoning,
            'article_count': len(valid_articles),
            'articles': valid_articles[:5]  # Include first 5 articles for reference
        }
    
    async def run_analysis(self) -> Dict[str, Any]:
        """Run complete news analysis and signal generation"""
        logger.info("Starting news analysis...")
        
        # Fetch and analyze news
        articles = await self.fetch_and_analyze_news()
        logger.info(f"Fetched and analyzed {len(articles)} articles")
        
        # Generate trading signal
        signal = self.generate_trading_signal(articles)
        
        # Add timestamp
        signal['timestamp'] = datetime.now().isoformat()
        signal['symbols'] = self.symbols
        
        return signal

async def main():
    """Main function to run the news analysis"""
    generator = NewsSignalGenerator()
    
    try:
        # Run analysis
        result = await generator.run_analysis()
        
        # Print results
        print("\n" + "="*60)
        print("GRANDE NEWS SIGNAL ANALYSIS RESULTS")
        print("="*60)
        print(f"Timestamp: {result['timestamp']}")
        print(f"Symbols: {', '.join(result['symbols'])}")
        print(f"Signal: {result['signal']}")
        print(f"Strength: {result['strength']:.3f}")
        print(f"Confidence: {result['confidence']:.3f}")
        print(f"Articles Analyzed: {result['article_count']}")
        print(f"Reasoning: {result['reasoning']}")
        
        if result['articles']:
            print("\nTop Articles:")
            for i, article in enumerate(result['articles'][:3], 1):
                print(f"{i}. {article['title'][:80]}...")
                print(f"   Source: {article['source']}")
                print(f"   Sentiment: {article['sentiment_label']} ({article['sentiment_score']:.3f})")
                print()
        
        print("="*60)
        
        # Save results to file
        with open('news_signal_result.json', 'w') as f:
            json.dump(result, f, indent=2)
        
        logger.info("Analysis complete. Results saved to news_signal_result.json")
        
    except Exception as e:
        logger.error(f"Error in main analysis: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    # Set up environment variables if not already set
    if not os.getenv('MARKETAUX_API_KEY'):
        print("WARNING: MARKETAUX_API_KEY not set. MarketAux news will not be available.")
    if not os.getenv('ALPHA_VANTAGE_API_KEY'):
        print("WARNING: ALPHA_VANTAGE_API_KEY not set. Alpha Vantage news will not be available.")
    if not os.getenv('NEWSAPI_KEY'):
        print("WARNING: NEWSAPI_KEY not set. NewsAPI news will not be available.")
    
    # Run the analysis
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
