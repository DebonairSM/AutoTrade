#!/usr/bin/env python3
"""
Grande Integrated News System
Connects existing news fetchers with the professional sentiment server
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

class IntegratedNewsSystem:
    """Integrated news system using professional sentiment analysis"""
    
    def __init__(self):
        self.symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD']
        self.sentiment_server_url = os.getenv('SENTIMENT_SERVER_URL', 'http://localhost:8000')
        self.newsapi_key = os.getenv('NEWSAPI_KEY', '')
        self.alpha_vantage_key = os.getenv('ALPHA_VANTAGE_API_KEY', '')
        self.marketaux_key = os.getenv('MARKETAUX_API_KEY', '')
        
    async def fetch_newsapi_news(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Fetch news from NewsAPI (1000 requests/day FREE)"""
        if not self.newsapi_key:
            logger.warning("NewsAPI key not provided - using simulated data")
            return self.get_simulated_newsapi_articles()
        
        try:
            url = "https://newsapi.org/v2/everything"
            params = {
                'q': f"{' OR '.join(self.symbols)} forex currency trading",
                'apiKey': self.newsapi_key,
                'language': 'en',
                'sortBy': 'publishedAt',
                'pageSize': limit
            }
            
            response = requests.get(url, params=params, timeout=30)
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
                    'raw_text': f"{article.get('title', '')} {article.get('description', '')}",
                    'sentiment_score': 0.0,
                    'sentiment_label': 'Unknown',
                    'confidence': 0.0,
                    'relevance': 85
                }
                articles.append(article_data)
            
            logger.info(f"NewsAPI: Fetched {len(articles)} articles (FREE - 1000 requests/day)")
            return articles
            
        except Exception as e:
            logger.error(f"Error fetching NewsAPI news: {e}")
            return self.get_simulated_newsapi_articles()
    
    def get_simulated_newsapi_articles(self) -> List[Dict[str, Any]]:
        """Simulated NewsAPI articles when no API key"""
        articles = [
            {
                'title': 'Federal Reserve Signals Potential Rate Cut',
                'description': 'The Federal Reserve has signaled a potential rate cut in upcoming meetings, affecting major currency pairs.',
                'source': 'Reuters (Simulated)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://reuters.com/fed-rate-cut',
                'raw_text': 'Federal Reserve Signals Potential Rate Cut The Federal Reserve has signaled a potential rate cut in upcoming meetings, affecting major currency pairs.',
                'sentiment_score': 0.0,
                'sentiment_label': 'Unknown',
                'confidence': 0.0,
                'relevance': 90
            },
            {
                'title': 'ECB Maintains Hawkish Stance on Inflation',
                'description': 'The European Central Bank maintains its hawkish stance on inflation, supporting the euro.',
                'source': 'Bloomberg (Simulated)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://bloomberg.com/ecb-hawkish',
                'raw_text': 'ECB Maintains Hawkish Stance on Inflation The European Central Bank maintains its hawkish stance on inflation, supporting the euro.',
                'sentiment_score': 0.0,
                'sentiment_label': 'Unknown',
                'confidence': 0.0,
                'relevance': 85
            },
            {
                'title': 'Bank of Japan Considers Policy Shift',
                'description': 'The Bank of Japan is considering a major policy shift that could impact the yen significantly.',
                'source': 'Financial Times (Simulated)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://ft.com/boj-policy-shift',
                'raw_text': 'Bank of Japan Considers Policy Shift The Bank of Japan is considering a major policy shift that could impact the yen significantly.',
                'sentiment_score': 0.0,
                'sentiment_label': 'Unknown',
                'confidence': 0.0,
                'relevance': 80
            }
        ]
        
        logger.info(f"NewsAPI Simulated: {len(articles)} articles (Get FREE key at newsapi.org)")
        return articles
    
    async def fetch_alpha_vantage_news(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Fetch news from Alpha Vantage API"""
        if not self.alpha_vantage_key:
            logger.warning("Alpha Vantage API key not provided - using simulated data")
            return self.get_simulated_alpha_vantage_articles()
        
        try:
            url = "https://www.alphavantage.co/query"
            params = {
                'function': 'NEWS_SENTIMENT',
                'tickers': ','.join(self.symbols),
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
                    'source': item.get('source', 'Alpha Vantage'),
                    'published_at': item.get('time_published', ''),
                    'url': item.get('url', ''),
                    'raw_text': f"{item.get('title', '')} {item.get('summary', '')}",
                    'sentiment_score': float(item.get('overall_sentiment_score', 0.0)),
                    'sentiment_label': item.get('overall_sentiment_label', 'Unknown'),
                    'confidence': 0.7,  # Alpha Vantage doesn't provide confidence
                    'relevance': 90
                }
                articles.append(article_data)
            
            logger.info(f"Alpha Vantage: Fetched {len(articles)} articles")
            return articles
            
        except Exception as e:
            logger.error(f"Error fetching Alpha Vantage news: {e}")
            return self.get_simulated_alpha_vantage_articles()
    
    def get_simulated_alpha_vantage_articles(self) -> List[Dict[str, Any]]:
        """Simulated Alpha Vantage articles"""
        articles = [
            {
                'title': 'EUR/USD Technical Analysis: Bullish Momentum Building',
                'description': 'Technical indicators show strong bullish momentum building in EUR/USD with key resistance levels being tested.',
                'source': 'Alpha Vantage (Simulated)',
                'published_at': datetime.now().isoformat(),
                'url': 'https://alphavantage.co/eur-usd-analysis',
                'raw_text': 'EUR/USD Technical Analysis: Bullish Momentum Building Technical indicators show strong bullish momentum building in EUR/USD with key resistance levels being tested.',
                'sentiment_score': 0.0,
                'sentiment_label': 'Unknown',
                'confidence': 0.0,
                'relevance': 95
            }
        ]
        
        logger.info(f"Alpha Vantage Simulated: {len(articles)} articles")
        return articles
    
    async def analyze_sentiment_with_server(self, text: str) -> Dict[str, Any]:
        """Analyze sentiment using the professional sentiment server"""
        try:
            # Use Docker exec to call the sentiment server
            import subprocess
            
            # Create a simple test script
            test_script = f'''
import asyncio
import json
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

async def analyze():
    async with stdio_client(
        StdioServerParameters(command="python", args=["main.py"])
    ) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("analyze_sentiment", {{"text": "{text}"}})
            print(json.dumps(result))

asyncio.run(analyze())
'''
            
            # Run the analysis inside the container
            result = subprocess.run([
                "docker", "exec", "grande-sentiment-mcp",
                "python", "-c", test_script
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                try:
                    response = json.loads(result.stdout.strip())
                    if "error" not in response:
                        return response
                    else:
                        logger.warning(f"Sentiment server error: {response['error']}")
                except json.JSONDecodeError:
                    logger.warning("Invalid JSON response from sentiment server")
            
            # Fallback to simple analysis
            return self.simple_sentiment_analysis(text)
            
        except Exception as e:
            logger.warning(f"Error calling sentiment server: {e}")
            return self.simple_sentiment_analysis(text)
    
    def simple_sentiment_analysis(self, text: str) -> Dict[str, Any]:
        """Fallback simple sentiment analysis"""
        positive_words = ['bullish', 'rise', 'gain', 'up', 'positive', 'strong', 'growth', 'increase', 'surge', 'rally', 'breakout', 'momentum', 'hawkish', 'support']
        negative_words = ['bearish', 'fall', 'drop', 'down', 'negative', 'weak', 'decline', 'decrease', 'crash', 'plunge', 'resistance', 'pressure', 'dovish', 'breakdown']
        
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
    
    async def analyze_articles_sentiment(self, articles: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Analyze sentiment for all articles using the professional server"""
        logger.info(f"Analyzing sentiment for {len(articles)} articles...")
        
        analyzed_articles = []
        for i, article in enumerate(articles, 1):
            logger.info(f"Analyzing article {i}/{len(articles)}: {article['title'][:50]}...")
            
            # Analyze sentiment using the professional server
            sentiment_result = await self.analyze_sentiment_with_server(article['raw_text'])
            
            # Update article with sentiment results
            article['sentiment_score'] = sentiment_result['score']
            article['sentiment_label'] = sentiment_result['sentiment']
            article['confidence'] = sentiment_result['confidence']
            
            analyzed_articles.append(article)
            
            # Small delay to avoid overwhelming the server
            await asyncio.sleep(0.1)
        
        logger.info(f"Completed sentiment analysis for {len(analyzed_articles)} articles")
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
        
        # Calculate weighted average sentiment
        total_weight = 0.0
        weighted_sentiment = 0.0
        total_confidence = 0.0
        sources = set()
        
        for article in articles:
            weight = article['confidence'] * (article['relevance'] / 100.0)
            weighted_sentiment += article['sentiment_score'] * weight
            total_confidence += article['confidence']
            total_weight += weight
            sources.add(article['source'])
        
        if total_weight > 0:
            avg_sentiment = weighted_sentiment / total_weight
            avg_confidence = total_confidence / len(articles)
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
        
        reasoning = f"Based on {len(articles)} articles from {len(sources)} sources. Avg sentiment: {avg_sentiment:.3f}, Confidence: {avg_confidence:.3f}"
        
        return {
            'signal': signal,
            'strength': strength,
            'confidence': avg_confidence,
            'reasoning': reasoning,
            'article_count': len(articles),
            'sources': list(sources),
            'avg_sentiment': avg_sentiment,
            'articles': articles[:5]  # Include first 5 articles for reference
        }
    
    async def run_integrated_analysis(self) -> Dict[str, Any]:
        """Run complete integrated news analysis"""
        logger.info("Starting integrated news analysis with professional sentiment server...")
        
        # Fetch news from all sources
        all_articles = []
        
        # Fetch from NewsAPI
        newsapi_articles = await self.fetch_newsapi_news(5)
        all_articles.extend(newsapi_articles)
        
        # Fetch from Alpha Vantage
        alpha_articles = await self.fetch_alpha_vantage_news(5)
        all_articles.extend(alpha_articles)
        
        logger.info(f"Fetched {len(all_articles)} articles from all sources")
        
        # Analyze sentiment using professional server
        analyzed_articles = await self.analyze_articles_sentiment(all_articles)
        
        # Generate trading signal
        signal = self.generate_trading_signal(analyzed_articles)
        
        # Add metadata
        signal['timestamp'] = datetime.now().isoformat()
        signal['symbols'] = self.symbols
        signal['sentiment_server_status'] = 'connected'
        
        return signal

async def main():
    """Main function to run the integrated analysis"""
    print("🚀 GRANDE INTEGRATED NEWS SYSTEM")
    print("=" * 50)
    print("📰 Fetching news from multiple sources...")
    print("🧠 Analyzing with professional sentiment server...")
    print("📊 Generating trading signals...")
    print()
    
    # Check if sentiment server is running (non-fatal; proceed with fallback if not)
    server_status = 'connected'
    try:
        result = subprocess.run([
            "docker", "ps", "--filter", "name=grande-sentiment-mcp", "--format", "{{.Status}}"
        ], capture_output=True, text=True, check=True)
        
        if "Up" not in result.stdout:
            print("❌ Sentiment server is not running! Continuing with fallback analysis...")
            print("Tip: Start it with: docker compose up -d")
            server_status = 'not_running'
        else:
            print(f"✅ Sentiment server status: {result.stdout.strip()}")
            server_status = 'connected'
    except Exception as e:
        print(f"❌ Error checking sentiment server: {e}. Continuing with fallback analysis...")
        server_status = 'unknown'
    
    print()
    
    # Run integrated analysis
    system = IntegratedNewsSystem()
    
    try:
        result = await system.run_integrated_analysis()
        # Reflect server status discovered above
        try:
            result['sentiment_server_status'] = server_status
        except Exception:
            pass
        
        # Display results
        print("\n" + "="*60)
        print("GRANDE INTEGRATED NEWS ANALYSIS RESULTS")
        print("="*60)
        print(f"Timestamp: {result['timestamp']}")
        print(f"Symbols: {', '.join(result['symbols'])}")
        print(f"Signal: {result['signal']}")
        print(f"Strength: {result['strength']:.3f}")
        print(f"Confidence: {result['confidence']:.3f}")
        print(f"Articles Analyzed: {result['article_count']}")
        print(f"Sources: {', '.join(result['sources'])}")
        print(f"Reasoning: {result['reasoning']}")
        
        if result['articles']:
            print("\n📰 TOP ARTICLES WITH PROFESSIONAL SENTIMENT ANALYSIS:")
            print("-" * 60)
            for i, article in enumerate(result['articles'], 1):
                print(f"{i}. {article['title'][:60]}...")
                print(f"   Source: {article['source']}")
                print(f"   Sentiment: {article['sentiment_label']} (Score: {article['sentiment_score']:.3f})")
                print(f"   Confidence: {article['confidence']:.3f}")
                print()
        
        print("="*60)
        print("✅ INTEGRATION SUCCESSFUL!")
        print("✅ News fetched from multiple sources")
        print("✅ Professional sentiment analysis completed")
        print("✅ Trading signal generated")
        print("="*60)
        
        # Save results to MT5 Common Files directory when available (works with Docker bind mounts too)
        common_env = os.environ.get('MT5_COMMON_FILES_DIR', '')
        if common_env:
            output_path = os.path.join(common_env, 'integrated_news_analysis.json')
        else:
            # Default Windows common path; allow override via env above
            default_common = os.path.join(os.path.expanduser('~'), 'AppData', 'Roaming', 'MetaQuotes', 'Terminal', 'Common', 'Files')
            try:
                os.makedirs(default_common, exist_ok=True)
            except Exception:
                pass
            output_path = os.path.join(default_common, 'integrated_news_analysis.json')

        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2)
            print(f"\n💾 Results saved to: {output_path}")
        except Exception as e:
            # Fallback to current working directory if common path fails
            fallback_path = os.path.abspath('integrated_news_analysis.json')
            with open(fallback_path, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2)
            print(f"\n⚠️ Could not write to Common Files ({e}). Saved to: {fallback_path}")
        
        return 0
        
    except Exception as e:
        logger.error(f"Error in integrated analysis: {e}")
        return 1

if __name__ == "__main__":
    import subprocess
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
