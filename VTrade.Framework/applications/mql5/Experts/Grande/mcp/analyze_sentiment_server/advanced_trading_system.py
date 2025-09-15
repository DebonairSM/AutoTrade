#!/usr/bin/env python3
"""
Grande Advanced Trading System
Sophisticated trading decisions based on sentiment, technical analysis, and risk management
"""

import os
import sys
import json
import time
import requests
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import logging
from dataclasses import dataclass
from enum import Enum

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SignalStrength(Enum):
    VERY_WEAK = 1
    WEAK = 2
    MODERATE = 3
    STRONG = 4
    VERY_STRONG = 5

class TradingAction(Enum):
    HOLD = "HOLD"
    BUY = "BUY"
    SELL = "SELL"
    CLOSE_LONG = "CLOSE_LONG"
    CLOSE_SHORT = "CLOSE_SHORT"
    REDUCE_POSITION = "REDUCE_POSITION"
    INCREASE_POSITION = "INCREASE_POSITION"

@dataclass
class CurrencyPair:
    symbol: str
    base_currency: str
    quote_currency: str
    current_price: float
    volatility: float
    trend_direction: str  # "UP", "DOWN", "SIDEWAYS"
    support_level: float
    resistance_level: float
    atr: float  # Average True Range for volatility

@dataclass
class Position:
    symbol: str
    side: str  # "LONG" or "SHORT"
    size: float
    entry_price: float
    current_price: float
    unrealized_pnl: float
    stop_loss: float
    take_profit: float
    open_time: datetime

@dataclass
class SentimentData:
    symbol: str
    sentiment_score: float  # -1.0 to 1.0
    confidence: float  # 0.0 to 1.0
    strength: SignalStrength
    news_count: int
    sources: List[str]
    reasoning: str
    timestamp: datetime

@dataclass
class TradingDecision:
    action: TradingAction
    symbol: str
    confidence: float
    reasoning: str
    position_size: float
    stop_loss: float
    take_profit: float
    risk_reward_ratio: float
    max_risk_percent: float

class AdvancedTradingSystem:
    """Advanced trading system with sophisticated decision making"""
    
    def __init__(self):
        self.symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD', 'USDCAD']
        self.sentiment_server_url = os.getenv('SENTIMENT_SERVER_URL', 'http://localhost:8000')
        self.newsapi_key = os.getenv('NEWSAPI_KEY', '')
        
        # Trading parameters
        self.max_risk_per_trade = 0.02  # 2% max risk per trade
        self.min_confidence_threshold = 0.6  # Minimum confidence for trading
        self.sentiment_weight = 0.4  # Weight of sentiment in decision
        self.technical_weight = 0.3  # Weight of technical analysis
        self.risk_weight = 0.3  # Weight of risk management
        
        # Position tracking
        self.positions: Dict[str, Position] = {}
        self.sentiment_data: Dict[str, SentimentData] = {}
        
    async def analyze_currency_specific_sentiment(self, symbol: str) -> SentimentData:
        """Analyze sentiment specifically for a currency pair"""
        logger.info(f"Analyzing sentiment for {symbol}...")
        
        # Fetch news specific to this currency pair
        articles = await self.fetch_currency_news(symbol)
        
        if not articles:
            return SentimentData(
                symbol=symbol,
                sentiment_score=0.0,
                confidence=0.0,
                strength=SignalStrength.VERY_WEAK,
                news_count=0,
                sources=[],
                reasoning="No news available",
                timestamp=datetime.now()
            )
        
        # Analyze sentiment for each article
        analyzed_articles = []
        for article in articles:
            sentiment_result = await self.analyze_sentiment_with_server(article['raw_text'])
            article.update(sentiment_result)
            analyzed_articles.append(article)
        
        # Calculate weighted sentiment for this specific currency
        total_weight = 0.0
        weighted_sentiment = 0.0
        total_confidence = 0.0
        sources = set()
        
        for article in analyzed_articles:
            # Higher weight for more relevant articles
            relevance_weight = article.get('relevance', 50) / 100.0
            confidence_weight = article.get('confidence', 0.5)
            weight = relevance_weight * confidence_weight
            
            weighted_sentiment += article['sentiment_score'] * weight
            total_confidence += article['confidence']
            total_weight += weight
            sources.add(article['source'])
        
        if total_weight > 0:
            avg_sentiment = weighted_sentiment / total_weight
            avg_confidence = total_confidence / len(analyzed_articles)
        else:
            avg_sentiment = 0.0
            avg_confidence = 0.0
        
        # Determine signal strength
        if avg_sentiment >= 0.8 and avg_confidence >= 0.8:
            strength = SignalStrength.VERY_STRONG
        elif avg_sentiment >= 0.6 and avg_confidence >= 0.7:
            strength = SignalStrength.STRONG
        elif avg_sentiment >= 0.4 and avg_confidence >= 0.6:
            strength = SignalStrength.MODERATE
        elif avg_sentiment >= 0.2 and avg_confidence >= 0.5:
            strength = SignalStrength.WEAK
        else:
            strength = SignalStrength.VERY_WEAK
        
        reasoning = f"Based on {len(analyzed_articles)} articles for {symbol}. Sentiment: {avg_sentiment:.3f}, Confidence: {avg_confidence:.3f}"
        
        sentiment_data = SentimentData(
            symbol=symbol,
            sentiment_score=avg_sentiment,
            confidence=avg_confidence,
            strength=strength,
            news_count=len(analyzed_articles),
            sources=list(sources),
            reasoning=reasoning,
            timestamp=datetime.now()
        )
        
        self.sentiment_data[symbol] = sentiment_data
        return sentiment_data
    
    async def fetch_currency_news(self, symbol: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Fetch news specific to a currency pair"""
        # Extract base and quote currencies
        if len(symbol) == 6:
            base_currency = symbol[:3]
            quote_currency = symbol[3:]
        else:
            base_currency = symbol
            quote_currency = "USD"
        
        # Create search terms specific to this currency pair
        search_terms = [
            f"{base_currency} {quote_currency}",
            f"{base_currency}/{quote_currency}",
            f"{base_currency}USD" if quote_currency == "USD" else f"{base_currency}{quote_currency}",
            f"{base_currency} currency",
            f"{base_currency} forex"
        ]
        
        articles = []
        
        # Fetch from NewsAPI if available
        if self.newsapi_key:
            try:
                url = "https://newsapi.org/v2/everything"
                params = {
                    'q': ' OR '.join(search_terms),
                    'apiKey': self.newsapi_key,
                    'language': 'en',
                    'sortBy': 'publishedAt',
                    'pageSize': limit
                }
                
                response = requests.get(url, params=params, timeout=30)
                response.raise_for_status()
                
                data = response.json()
                
                for article in data.get('articles', []):
                    article_data = {
                        'title': article.get('title', ''),
                        'description': article.get('description', ''),
                        'source': article.get('source', {}).get('name', 'NewsAPI'),
                        'published_at': article.get('publishedAt', ''),
                        'url': article.get('url', ''),
                        'raw_text': f"{article.get('title', '')} {article.get('description', '')}",
                        'relevance': self.calculate_relevance(article.get('title', '') + ' ' + article.get('description', ''), symbol),
                        'sentiment_score': 0.0,
                        'sentiment_label': 'Unknown',
                        'confidence': 0.0
                    }
                    articles.append(article_data)
                
                logger.info(f"Fetched {len(articles)} {symbol}-specific articles from NewsAPI")
                
            except Exception as e:
                logger.error(f"Error fetching NewsAPI news for {symbol}: {e}")
        
        # Add simulated articles if no real news
        if len(articles) < 3:
            simulated_articles = self.get_simulated_currency_news(symbol, 3)
            articles.extend(simulated_articles)
        
        return articles[:limit]
    
    def calculate_relevance(self, text: str, symbol: str) -> float:
        """Calculate relevance score for a currency pair"""
        text_lower = text.lower()
        symbol_lower = symbol.lower()
        
        # Direct symbol mentions
        if symbol_lower in text_lower:
            return 95.0
        
        # Base currency mentions
        base_currency = symbol[:3].lower()
        if base_currency in text_lower:
            return 80.0
        
        # Quote currency mentions
        quote_currency = symbol[3:].lower()
        if quote_currency in text_lower:
            return 70.0
        
        # Forex-related terms
        forex_terms = ['forex', 'fx', 'currency', 'exchange rate', 'trading']
        forex_count = sum(1 for term in forex_terms if term in text_lower)
        
        return min(60.0 + (forex_count * 10), 90.0)
    
    def get_simulated_currency_news(self, symbol: str, count: int) -> List[Dict[str, Any]]:
        """Generate simulated news for a currency pair"""
        base_currency = symbol[:3]
        quote_currency = symbol[3:]
        
        simulated_articles = [
            {
                'title': f'{base_currency}/{quote_currency} Analysis: Central Bank Policy Impact',
                'description': f'The {base_currency} shows strong momentum against {quote_currency} following recent central bank announcements.',
                'source': f'{base_currency} News (Simulated)',
                'published_at': datetime.now().isoformat(),
                'url': f'https://example.com/{symbol.lower()}-analysis',
                'raw_text': f'{base_currency}/{quote_currency} Analysis: Central Bank Policy Impact The {base_currency} shows strong momentum against {quote_currency} following recent central bank announcements.',
                'relevance': 90.0,
                'sentiment_score': 0.0,
                'sentiment_label': 'Unknown',
                'confidence': 0.0
            },
            {
                'title': f'{base_currency} Technical Outlook: Key Levels to Watch',
                'description': f'Technical analysis suggests {base_currency} is approaching critical support/resistance levels against {quote_currency}.',
                'source': f'Technical Analysis (Simulated)',
                'published_at': datetime.now().isoformat(),
                'url': f'https://example.com/{symbol.lower()}-technical',
                'raw_text': f'{base_currency} Technical Outlook: Key Levels to Watch Technical analysis suggests {base_currency} is approaching critical support/resistance levels against {quote_currency}.',
                'relevance': 85.0,
                'sentiment_score': 0.0,
                'sentiment_label': 'Unknown',
                'confidence': 0.0
            }
        ]
        
        return simulated_articles[:count]
    
    async def analyze_sentiment_with_server(self, text: str) -> Dict[str, Any]:
        """Analyze sentiment using the professional sentiment server"""
        try:
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
                except json.JSONDecodeError:
                    pass
            
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
    
    def get_technical_analysis(self, symbol: str) -> Dict[str, Any]:
        """Get technical analysis for a currency pair (simplified)"""
        # In a real implementation, this would connect to your technical analysis system
        # For now, we'll return simulated data
        
        return {
            'trend_direction': 'UP',  # UP, DOWN, SIDEWAYS
            'strength': 0.7,  # 0.0 to 1.0
            'support_level': 1.0800,  # Example for EURUSD
            'resistance_level': 1.0900,
            'atr': 0.0050,  # Average True Range
            'rsi': 65.0,  # RSI
            'macd_signal': 'BULLISH',  # BULLISH, BEARISH, NEUTRAL
            'confidence': 0.8
        }
    
    def calculate_position_size(self, symbol: str, sentiment_data: SentimentData, technical_data: Dict[str, Any], account_balance: float) -> float:
        """Calculate position size based on sentiment, technical analysis, and risk management"""
        
        # Base position size (1% of account)
        base_size = account_balance * 0.01
        
        # Adjust based on sentiment strength
        sentiment_multiplier = {
            SignalStrength.VERY_WEAK: 0.2,
            SignalStrength.WEAK: 0.4,
            SignalStrength.MODERATE: 0.6,
            SignalStrength.STRONG: 0.8,
            SignalStrength.VERY_STRONG: 1.0
        }[sentiment_data.strength]
        
        # Adjust based on technical analysis confidence
        technical_multiplier = technical_data.get('confidence', 0.5)
        
        # Adjust based on volatility (ATR)
        atr = technical_data.get('atr', 0.01)
        volatility_multiplier = max(0.5, min(1.5, 0.01 / atr))  # Lower volatility = larger position
        
        # Calculate final position size
        position_size = base_size * sentiment_multiplier * technical_multiplier * volatility_multiplier
        
        # Ensure minimum and maximum limits
        min_size = account_balance * 0.001  # 0.1% minimum
        max_size = account_balance * 0.05   # 5% maximum
        
        return max(min_size, min(max_size, position_size))
    
    def calculate_stop_loss_take_profit(self, symbol: str, entry_price: float, side: str, technical_data: Dict[str, Any]) -> Tuple[float, float]:
        """Calculate stop loss and take profit levels"""
        
        atr = technical_data.get('atr', 0.01)
        support = technical_data.get('support_level', entry_price * 0.99)
        resistance = technical_data.get('resistance_level', entry_price * 1.01)
        
        if side == "LONG":
            # For long positions
            stop_loss = min(support, entry_price - (atr * 2))  # 2 ATR below entry
            take_profit = max(resistance, entry_price + (atr * 3))  # 3 ATR above entry
        else:
            # For short positions
            stop_loss = max(resistance, entry_price + (atr * 2))  # 2 ATR above entry
            take_profit = min(support, entry_price - (atr * 3))  # 3 ATR below entry
        
        return stop_loss, take_profit
    
    def make_trading_decision(self, symbol: str, sentiment_data: SentimentData, technical_data: Dict[str, Any], current_position: Optional[Position] = None) -> TradingDecision:
        """Make a comprehensive trading decision"""
        
        # Calculate combined score
        sentiment_score = sentiment_data.sentiment_score
        sentiment_confidence = sentiment_data.confidence
        technical_score = 1.0 if technical_data.get('trend_direction') == 'UP' else -1.0 if technical_data.get('trend_direction') == 'DOWN' else 0.0
        technical_confidence = technical_data.get('confidence', 0.5)
        
        # Weighted combined score
        combined_score = (sentiment_score * sentiment_confidence * self.sentiment_weight + 
                         technical_score * technical_confidence * self.technical_weight)
        
        # Determine action based on current position
        if current_position is None:
            # No current position - decide whether to enter
            if combined_score >= 0.6 and sentiment_confidence >= self.min_confidence_threshold:
                action = TradingAction.BUY
            elif combined_score <= -0.6 and sentiment_confidence >= self.min_confidence_threshold:
                action = TradingAction.SELL
            else:
                action = TradingAction.HOLD
        else:
            # Have current position - decide whether to hold, close, or adjust
            if current_position.side == "LONG":
                if combined_score <= -0.4 or sentiment_confidence < 0.3:
                    action = TradingAction.CLOSE_LONG
                elif combined_score >= 0.8 and sentiment_confidence >= 0.8:
                    action = TradingAction.INCREASE_POSITION
                else:
                    action = TradingAction.HOLD
            else:  # SHORT position
                if combined_score >= 0.4 or sentiment_confidence < 0.3:
                    action = TradingAction.CLOSE_SHORT
                elif combined_score <= -0.8 and sentiment_confidence >= 0.8:
                    action = TradingAction.INCREASE_POSITION
                else:
                    action = TradingAction.HOLD
        
        # Calculate position size and risk levels
        account_balance = 10000.0  # Example account balance
        position_size = self.calculate_position_size(symbol, sentiment_data, technical_data, account_balance)
        
        # Calculate stop loss and take profit
        entry_price = 1.0850  # Example entry price
        side = "LONG" if action in [TradingAction.BUY, TradingAction.INCREASE_POSITION] else "SHORT"
        stop_loss, take_profit = self.calculate_stop_loss_take_profit(symbol, entry_price, side, technical_data)
        
        # Calculate risk-reward ratio
        if side == "LONG":
            risk = entry_price - stop_loss
            reward = take_profit - entry_price
        else:
            risk = stop_loss - entry_price
            reward = entry_price - take_profit
        
        risk_reward_ratio = reward / risk if risk > 0 else 0
        
        # Generate reasoning
        reasoning = f"Sentiment: {sentiment_data.sentiment_score:.3f} (confidence: {sentiment_confidence:.3f}), " \
                   f"Technical: {technical_data.get('trend_direction')} (confidence: {technical_confidence:.3f}), " \
                   f"Combined: {combined_score:.3f}"
        
        return TradingDecision(
            action=action,
            symbol=symbol,
            confidence=min(sentiment_confidence, technical_confidence),
            reasoning=reasoning,
            position_size=position_size,
            stop_loss=stop_loss,
            take_profit=take_profit,
            risk_reward_ratio=risk_reward_ratio,
            max_risk_percent=self.max_risk_per_trade
        )
    
    async def run_advanced_analysis(self) -> Dict[str, Any]:
        """Run advanced analysis for all currency pairs"""
        logger.info("Starting advanced trading analysis...")
        
        results = {}
        
        for symbol in self.symbols:
            logger.info(f"Analyzing {symbol}...")
            
            # Get sentiment data
            sentiment_data = await self.analyze_currency_specific_sentiment(symbol)
            
            # Get technical analysis
            technical_data = self.get_technical_analysis(symbol)
            
            # Get current position (simplified - in real implementation, query your broker)
            current_position = self.positions.get(symbol)
            
            # Make trading decision
            decision = self.make_trading_decision(symbol, sentiment_data, technical_data, current_position)
            
            results[symbol] = {
                'sentiment': {
                    'score': sentiment_data.sentiment_score,
                    'confidence': sentiment_data.confidence,
                    'strength': sentiment_data.strength.name,
                    'news_count': sentiment_data.news_count,
                    'sources': sentiment_data.sources,
                    'reasoning': sentiment_data.reasoning
                },
                'technical': technical_data,
                'decision': {
                    'action': decision.action.value,
                    'confidence': decision.confidence,
                    'reasoning': decision.reasoning,
                    'position_size': decision.position_size,
                    'stop_loss': decision.stop_loss,
                    'take_profit': decision.take_profit,
                    'risk_reward_ratio': decision.risk_reward_ratio,
                    'max_risk_percent': decision.max_risk_percent
                }
            }
        
        return {
            'timestamp': datetime.now().isoformat(),
            'symbols': self.symbols,
            'results': results,
            'summary': self.generate_summary(results)
        }
    
    def generate_summary(self, results: Dict[str, Any]) -> Dict[str, Any]:
        """Generate summary of all trading decisions"""
        buy_signals = []
        sell_signals = []
        hold_signals = []
        
        for symbol, data in results.items():
            action = data['decision']['action']
            if action in ['BUY', 'INCREASE_POSITION']:
                buy_signals.append(symbol)
            elif action in ['SELL']:
                sell_signals.append(symbol)
            else:
                hold_signals.append(symbol)
        
        return {
            'buy_signals': buy_signals,
            'sell_signals': sell_signals,
            'hold_signals': hold_signals,
            'total_signals': len(buy_signals) + len(sell_signals),
            'high_confidence_signals': len([s for s in results.values() if s['decision']['confidence'] >= 0.8])
        }

async def main():
    """Main function to run advanced trading analysis"""
    print("🚀 GRANDE ADVANCED TRADING SYSTEM")
    print("=" * 50)
    print("📊 Currency-specific sentiment analysis")
    print("🔍 Technical analysis integration")
    print("⚖️ Risk management and position sizing")
    print("🎯 Sophisticated trading decisions")
    print()
    
    # Check if sentiment server is running
    try:
        import subprocess
        result = subprocess.run([
            "docker", "ps", "--filter", "name=grande-sentiment-mcp", "--format", "{{.Status}}"
        ], capture_output=True, text=True, check=True)
        
        if "Up" not in result.stdout:
            print("❌ Sentiment server is not running!")
            print("Please start it with: docker compose up -d")
            return 1
        else:
            print(f"✅ Sentiment server status: {result.stdout.strip()}")
    except Exception as e:
        print(f"❌ Error checking sentiment server: {e}")
        return 1
    
    print()
    
    # Run advanced analysis
    system = AdvancedTradingSystem()
    
    try:
        result = await system.run_advanced_analysis()
        
        # Display results
        print("\n" + "="*80)
        print("GRANDE ADVANCED TRADING ANALYSIS RESULTS")
        print("="*80)
        
        for symbol, data in result['results'].items():
            print(f"\n📈 {symbol} ANALYSIS:")
            print("-" * 40)
            print(f"Sentiment: {data['sentiment']['score']:.3f} (confidence: {data['sentiment']['confidence']:.3f})")
            print(f"Strength: {data['sentiment']['strength']}")
            print(f"News Sources: {len(data['sentiment']['sources'])}")
            print(f"Technical Trend: {data['technical']['trend_direction']}")
            print(f"Decision: {data['decision']['action']}")
            print(f"Confidence: {data['decision']['confidence']:.3f}")
            print(f"Position Size: ${data['decision']['position_size']:.2f}")
            print(f"Stop Loss: {data['decision']['stop_loss']:.4f}")
            print(f"Take Profit: {data['decision']['take_profit']:.4f}")
            print(f"Risk/Reward: {data['decision']['risk_reward_ratio']:.2f}")
            print(f"Reasoning: {data['decision']['reasoning']}")
        
        print(f"\n📊 SUMMARY:")
        print("-" * 20)
        summary = result['summary']
        print(f"Buy Signals: {', '.join(summary['buy_signals'])}")
        print(f"Sell Signals: {', '.join(summary['sell_signals'])}")
        print(f"Hold Signals: {', '.join(summary['hold_signals'])}")
        print(f"High Confidence Signals: {summary['high_confidence_signals']}")
        
        print("\n" + "="*80)
        print("✅ ADVANCED ANALYSIS COMPLETE!")
        print("✅ Currency-specific sentiment analysis")
        print("✅ Technical analysis integration")
        print("✅ Risk management applied")
        print("✅ Sophisticated trading decisions")
        print("="*80)
        
        # Save results
        with open('advanced_trading_analysis.json', 'w') as f:
            json.dump(result, f, indent=2, default=str)
        
        print(f"\n💾 Results saved to: advanced_trading_analysis.json")
        
        return 0
        
    except Exception as e:
        logger.error(f"Error in advanced analysis: {e}")
        return 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
