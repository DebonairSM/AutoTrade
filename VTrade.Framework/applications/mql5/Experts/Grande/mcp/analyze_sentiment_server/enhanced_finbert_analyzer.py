#!/usr/bin/env python3
"""
Enhanced FinBERT Multi-Modal Trading Intelligence Analyzer

This analyzer integrates comprehensive market data including:
- Technical indicators (EMA, RSI, Stochastic, ATR, ADX)
- Market regime detection (Trend, Breakout, Ranging, High Volatility)
- Key levels (Support/Resistance with strength scoring)
- Economic calendar events with FinBERT sentiment analysis
- Multi-timeframe analysis (H1, H4, D1)

The system provides intelligent trading decisions based on confluence
of multiple factors with weighted scoring and risk assessment.
"""

from __future__ import annotations

import os
import json
import time
import logging
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple
import numpy as np

# Set up logger for diagnostic output
logger = logging.getLogger("EnhancedFinBERT")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(name)s: %(message)s'))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


# ----------------------------- Paths & IO ------------------------------------

def common_files_dir() -> str:
    env = os.environ.get("MT5_COMMON_FILES_DIR", "").strip()
    if env:
        return env
    # Default Windows Common Files
    return os.path.join(
        os.path.expanduser("~"), "AppData", "Roaming", "MetaQuotes", "Terminal", "Common", "Files"
    )

def default_market_context_path() -> str:
    return os.path.join(common_files_dir(), "market_context_*.json")

def default_output_path() -> str:
    return os.path.join(common_files_dir(), "enhanced_finbert_analysis.json")


# --------------------------- Enhanced FinBERT Pipeline --------------------------------

_PIPELINE = None

def get_finbert_pipeline():
    global _PIPELINE
    if _PIPELINE is not None:
        return _PIPELINE
    try:
        import torch
        from transformers import (
            AutoTokenizer,
            AutoModelForSequenceClassification,
            TextClassificationPipeline,
        )
        print("✅ Enhanced FinBERT dependencies loaded successfully")
    except Exception as e:
        print("=" * 80)
        print("!!! FINBERT NOT AVAILABLE !!!")
        print(f"[ERROR] Transformers library not found: {e}")
        print("[WARNING] FALLING BACK TO KEYWORD-BASED ANALYSIS (NOT REAL AI)")
        print("[INFO] To install FinBERT, run: python -m pip install torch transformers")
        print("=" * 80)
        return None

    try:
        model_name = os.environ.get("FINBERT_MODEL", "yiyanghkust/finbert-tone")
        print(f"🤖 Loading Enhanced FinBERT model: {model_name}")
        
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        model = AutoModelForSequenceClassification.from_pretrained(model_name)
        device = 0 if getattr(torch, "cuda", None) and torch.cuda.is_available() else -1
        
        _PIPELINE = TextClassificationPipeline(
            model=model,
            tokenizer=tokenizer,
            return_all_scores=True,
            device=device,
        )
        print(f"[OK] Enhanced FinBERT pipeline initialized successfully on device: {device}")
        return _PIPELINE
    except Exception as e:
        print("=" * 80)
        print("!!! FINBERT FAILED TO LOAD !!!")
        print(f"[ERROR] {e}")
        print("[WARNING] FALLING BACK TO KEYWORD-BASED ANALYSIS (NOT REAL AI)")
        print("[INFO] To install FinBERT, run: python -m pip install torch transformers")
        print("=" * 80)
        return None


# ------------------------------ Enhanced Data Structures --------------------------------

@dataclass
class TechnicalAnalysis:
    """Comprehensive technical analysis data"""
    trend_direction: str
    trend_strength: float
    rsi_current: float
    rsi_h4: float
    rsi_d1: float
    rsi_status: str
    stoch_k: float
    stoch_d: float
    stoch_signal: str
    atr_current: float
    atr_average: float
    volatility_level: str
    ema_20: float
    ema_50: float
    ema_200: float
    
    # Enhanced: Price-EMA Relationships
    price_to_ema20_pips: float
    price_to_ema50_pips: float
    price_to_ema200_pips: float
    ema_alignment: str
    
    # Enhanced: Spread & Execution Quality
    spread_current: float
    spread_average: float
    spread_status: str
    
    # Enhanced: Momentum Indicators
    rsi_slope: str
    price_momentum_3bar: float
    atr_slope: str
    
    # Enhanced: Candlestick Context
    candle_pattern: str
    candle_body_ratio: float
    rejection_signal: str
    
    # Enhanced: Session & Timing
    trading_session: str
    hour_of_day: int

@dataclass
class MarketRegime:
    """Market regime analysis data"""
    current_regime: str
    confidence: float
    adx_h1: float
    adx_h4: float
    adx_d1: float
    plus_di: float
    minus_di: float

@dataclass
class KeyLevels:
    """Key support and resistance levels"""
    support_levels: List[Dict[str, Any]]
    resistance_levels: List[Dict[str, Any]]
    nearest_support: Dict[str, Any]
    nearest_resistance: Dict[str, Any]

@dataclass
class EconomicCalendar:
    """Economic calendar and FinBERT sentiment data"""
    events_today: int
    high_impact_events: int
    finbert_signal: str
    finbert_confidence: float
    next_event: Dict[str, Any]

@dataclass
class MarketContext:
    """Complete market context for analysis"""
    timestamp: str
    symbol: str
    timeframe: str
    market_data: Dict[str, Any]
    technical_indicators: TechnicalAnalysis
    market_regime: MarketRegime
    key_levels: KeyLevels
    economic_calendar: EconomicCalendar

@dataclass
class EnhancedFinBERTDecision:
    """Enhanced FinBERT trading decision with comprehensive analysis"""
    signal: str  # STRONG_BUY, BUY, NEUTRAL, SELL, STRONG_SELL
    confidence: float  # 0.0-1.0
    weighted_score: float  # -1.0 to 1.0
    reasoning: str
    risk_level: str  # LOW, MEDIUM, HIGH
    price_targets: Dict[str, float]
    stop_loss: float
    position_size_multiplier: float
    
    # Enhanced metrics
    technical_score: float
    regime_score: float
    levels_score: float
    economic_score: float
    confluence_score: float
    processing_time_ms: float


# ------------------------------ Enhanced Analysis Engine --------------------------------

class EnhancedFinBERTAnalyzer:
    """Multi-modal FinBERT analysis engine with decision synthesis"""
    
    def __init__(self):
        self.finbert_pipeline = get_finbert_pipeline()
        # Refactored weights: FinBERT now analyzes ONLY calendar events (its trained purpose)
        # Removed risk_assessment from weights (computed separately)
        # Combined economic_sentiment and finbert_sentiment into economic_finbert
        self.weights = {
            'technical_trend': 0.30,      # Increased from 0.25
            'market_regime': 0.25,         # Increased from 0.20
            'key_levels': 0.20,            # Unchanged
            'economic_finbert': 0.25       # NEW: Combined calendar + FinBERT sentiment
        }
    
    def analyze_comprehensive_market_data(self, market_context: MarketContext) -> EnhancedFinBERTDecision:
        """Analyze comprehensive market data and generate trading decision"""
        start_time = time.time()
        
        # Validate input data quality
        self._validate_market_context(market_context)
        
        # 1. Technical Analysis Summary
        technical_summary = self._create_technical_summary(market_context)
        
        # 2. Market Regime Analysis
        regime_analysis = self._analyze_market_regime(market_context)
        
        # 3. Key Levels Analysis
        levels_analysis = self._analyze_key_levels(market_context)
        
        # 4. Economic Calendar Integration
        calendar_analysis = self._analyze_economic_context(market_context)
        
        # 5. Calendar-Only FinBERT Analysis
        # FinBERT analyzes ONLY economic calendar events (its trained purpose)
        # Technical analysis uses pure rule-based scoring
        calendar_prompt = self._create_calendar_prompt(calendar_analysis, market_context)
        
        # 6. FinBERT Processing (calendar events only)
        finbert_result = self._process_finbert_analysis(calendar_prompt)
        
        # 7. Risk Assessment
        risk_analysis = self._assess_risk(market_context, finbert_result)
        
        # 8. Final Decision Synthesis
        final_decision = self._synthesize_decision(
            finbert_result, risk_analysis, market_context, technical_summary, 
            regime_analysis, levels_analysis, calendar_analysis
        )
        
        processing_time = (time.time() - start_time) * 1000
        final_decision.processing_time_ms = processing_time
        
        return final_decision
    
    def _validate_market_context(self, context: MarketContext) -> None:
        """
        Validate market context data quality and log warnings for missing data.
        System continues with graceful degradation even if data is missing.
        """
        warnings = []
        
        # Check key levels
        support_count = len(context.key_levels.support_levels)
        resistance_count = len(context.key_levels.resistance_levels)
        
        if support_count == 0 and resistance_count == 0:
            warnings.append("[WARNING] No key levels detected (empty support and resistance arrays)")
            logger.warning("Key levels data is empty - key_levels component will have minimal influence")
        elif support_count == 0:
            warnings.append(f"[WARNING] No support levels detected ({resistance_count} resistance levels found)")
        elif resistance_count == 0:
            warnings.append(f"[WARNING] No resistance levels detected ({support_count} support levels found)")
        else:
            logger.info(f"[OK] Key levels: {support_count} support, {resistance_count} resistance")
        
        # Check nearest levels
        if context.key_levels.nearest_support['price'] == 0.0:
            warnings.append("[WARNING] No nearest support level identified")
        if context.key_levels.nearest_resistance['price'] == 0.0:
            warnings.append("[WARNING] No nearest resistance level identified")
        
        # Check economic calendar with weekend awareness
        if context.economic_calendar.events_today == 0:
            from datetime import datetime
            day_of_week = datetime.now().strftime('%A')
            is_weekend = day_of_week in ['Saturday', 'Sunday']
            
            if is_weekend:
                logger.info(f"[OK] Economic calendar empty (expected on {day_of_week}). Using market structure analysis.")
            else:
                warnings.append("[WARNING] No economic events on trading day - check MT5 calendar settings (Tools > Options > Server > 'Enable news')")
                logger.warning("Economic calendar has 0 events on weekday - FinBERT analysis will be less informative")
        else:
            high_impact = context.economic_calendar.high_impact_events
            logger.info(f"[OK] Economic calendar: {context.economic_calendar.events_today} events "
                       f"({high_impact} high-impact)")
        
        # Check next event (only warn on weekdays)
        if not context.economic_calendar.next_event['name']:
            from datetime import datetime
            day_of_week = datetime.now().strftime('%A')
            if day_of_week not in ['Saturday', 'Sunday']:
                warnings.append("[WARNING] No upcoming economic events identified")
        
        # Log all warnings
        if warnings:
            logger.warning("=" * 80)
            logger.warning("DATA QUALITY WARNINGS:")
            for warning in warnings:
                logger.warning(f"  {warning}")
            logger.warning("Analysis will continue with graceful degradation")
            logger.warning("=" * 80)
        else:
            logger.info("[OK] All input data validation passed")
    
    def _create_technical_summary(self, context: MarketContext) -> Dict[str, Any]:
        """Create technical analysis summary"""
        tech = context.technical_indicators
        
        # Calculate technical confluence score
        confluence_factors = []
        
        # Trend alignment
        if tech.trend_direction == "BULLISH":
            confluence_factors.append(0.8)
        elif tech.trend_direction == "BEARISH":
            confluence_factors.append(-0.8)
        else:
            confluence_factors.append(0.0)
        
        # RSI alignment
        if tech.rsi_status == "NEUTRAL_TO_BULLISH" or tech.rsi_status == "OVERSOLD":
            confluence_factors.append(0.6)
        elif tech.rsi_status == "NEUTRAL_TO_BEARISH" or tech.rsi_status == "OVERBOUGHT":
            confluence_factors.append(-0.6)
        else:
            confluence_factors.append(0.0)
        
        # Stochastic alignment
        if tech.stoch_signal == "OVERSOLD_WARNING":
            confluence_factors.append(0.4)
        elif tech.stoch_signal == "OVERBOUGHT_WARNING":
            confluence_factors.append(-0.4)
        else:
            confluence_factors.append(0.0)
        
        technical_score = np.mean(confluence_factors)
        
        return {
            'trend_direction': tech.trend_direction,
            'trend_strength': tech.trend_strength,
            'rsi_status': tech.rsi_status,
            'stoch_signal': tech.stoch_signal,
            'volatility_level': tech.volatility_level,
            'technical_score': technical_score,
            'confluence_factors': confluence_factors
        }
    
    def _analyze_market_regime(self, context: MarketContext) -> Dict[str, Any]:
        """Analyze market regime and its implications"""
        regime = context.market_regime
        
        # Map regime to trading implications
        regime_implications = {
            "BULL TREND": {"score": 0.8, "description": "Strong bullish momentum"},
            "BEAR TREND": {"score": -0.8, "description": "Strong bearish momentum"},
            "BREAKOUT SETUP": {"score": 0.3, "description": "Potential breakout formation"},
            "RANGING": {"score": 0.0, "description": "Sideways market conditions"},
            "HIGH VOLATILITY": {"score": 0.1, "description": "High volatility environment"}
        }
        
        regime_info = regime_implications.get(regime.current_regime, {"score": 0.0, "description": "Unknown regime"})
        
        return {
            'regime': regime.current_regime,
            'confidence': regime.confidence,
            'score': regime_info['score'],
            'description': regime_info['description'],
            'adx_strength': (regime.adx_h1 + regime.adx_h4 + regime.adx_d1) / 3
        }
    
    def _analyze_key_levels(self, context: MarketContext) -> Dict[str, Any]:
        """Analyze key support and resistance levels"""
        levels = context.key_levels
        current_price = context.market_data['price']['current']
        
        # Analyze proximity to key levels
        support_proximity = 0.0
        resistance_proximity = 0.0
        
        if levels.nearest_support['price'] > 0:
            distance = abs(current_price - levels.nearest_support['price'])
            support_proximity = max(0, 1.0 - (distance / (current_price * 0.01)))  # Within 1%
        
        if levels.nearest_resistance['price'] > 0:
            distance = abs(current_price - levels.nearest_resistance['price'])
            resistance_proximity = max(0, 1.0 - (distance / (current_price * 0.01)))  # Within 1%
        
        # Calculate levels score
        levels_score = 0.0
        if support_proximity > 0.8:
            levels_score = 0.6  # Near strong support
        elif resistance_proximity > 0.8:
            levels_score = -0.6  # Near strong resistance
        
        return {
            'support_proximity': support_proximity,
            'resistance_proximity': resistance_proximity,
            'levels_score': levels_score,
            'nearest_support': levels.nearest_support,
            'nearest_resistance': levels.nearest_resistance
        }
    
    def _analyze_economic_context(self, context: MarketContext) -> Dict[str, Any]:
        """Analyze economic calendar context"""
        calendar = context.economic_calendar
        
        # Map FinBERT signals to scores
        signal_scores = {
            "STRONG_BUY": 0.8,
            "BUY": 0.4,
            "NEUTRAL": 0.0,
            "SELL": -0.4,
            "STRONG_SELL": -0.8
        }
        
        economic_score = signal_scores.get(calendar.finbert_signal, 0.0)
        
        return {
            'signal': calendar.finbert_signal,
            'confidence': calendar.finbert_confidence,
            'score': economic_score,
            'events_today': calendar.events_today,
            'high_impact_events': calendar.high_impact_events,
            'next_event': calendar.next_event
        }
    
    def _create_calendar_prompt(self, calendar_analysis: Dict, context: MarketContext) -> str:
        """
        Create financial news-style text from calendar events for FinBERT analysis.
        
        FinBERT was trained on short financial news headlines and articles (typically < 512 tokens).
        This method formats calendar events into natural financial news text that FinBERT can analyze.
        Keep under 100 words for optimal FinBERT performance.
        """
        calendar = context.economic_calendar
        symbol = context.symbol
        
        # Extract base currency from symbol (e.g., USD from USDJPY)
        base_currency = symbol[:3] if len(symbol) >= 6 else "USD"
        
        # If no events, return neutral market statement (common on weekends)
        if calendar.events_today == 0:
            from datetime import datetime
            day_of_week = datetime.now().strftime('%A')
            
            # On weekends, note that markets are closed
            if day_of_week in ['Saturday', 'Sunday']:
                return f"{base_currency} markets remain steady with no economic releases scheduled on {day_of_week}. Weekend trading conditions."
            else:
                return f"{base_currency} markets remain steady with no major economic releases scheduled. Trading conditions normal."
        
        # Build news-style text from calendar events
        news_parts = []
        
        # Add event count context
        if calendar.high_impact_events > 0:
            news_parts.append(f"{calendar.high_impact_events} high-impact economic event(s) scheduled for {base_currency}.")
        else:
            news_parts.append(f"{calendar.events_today} economic event(s) scheduled for {base_currency}.")
        
        # Add next event details if available
        next_event = calendar.next_event
        if next_event['name'] and next_event['currency']:
            impact_descriptor = "major" if next_event['impact'] in ["HIGH", "CRITICAL"] else "scheduled"
            news_parts.append(f"Next {impact_descriptor} release: {next_event['currency']} {next_event['name']}.")
        
        # Add market context from technical indicators
        tech = context.technical_indicators
        
        # Add trend context
        if tech.trend_direction == "BULLISH":
            news_parts.append(f"{symbol} showing bullish momentum with positive technical outlook.")
        elif tech.trend_direction == "BEARISH":
            news_parts.append(f"{symbol} showing bearish pressure with negative technical outlook.")
        else:
            news_parts.append(f"{symbol} trading in neutral range with mixed signals.")
        
        # Add volatility context
        if tech.volatility_level == "ABOVE_AVERAGE":
            news_parts.append("Market volatility elevated.")
        elif tech.volatility_level == "BELOW_AVERAGE":
            news_parts.append("Market volatility subdued.")
        
        # Combine into cohesive financial news text (under 100 words)
        news_text = " ".join(news_parts)
        
        # Truncate if too long (keep under 512 characters for FinBERT)
        if len(news_text) > 500:
            news_text = news_text[:497] + "..."
        
        return news_text
    
    def _process_finbert_analysis(self, prompt: str) -> Dict[str, Any]:
        """Process prompt through FinBERT pipeline with detailed diagnostic logging"""
        logger.info("=" * 80)
        logger.info("FinBERT Analysis Starting")
        logger.info(f"Input text length: {len(prompt)} characters")
        logger.info(f"Input text: {prompt[:200]}{'...' if len(prompt) > 200 else ''}")
        
        if self.finbert_pipeline is None:
            logger.warning("[WARNING] Using FALLBACK analysis (FinBERT not loaded)")
            print("[WARNING] Using FALLBACK analysis (FinBERT not loaded)")
            return self._fallback_sentiment_analysis(prompt)
        
        try:
            preds = self.finbert_pipeline(prompt)
            scores = preds[0] if isinstance(preds, list) else preds
            probs: Dict[str, float] = {}
            
            for item in scores:
                label = str(item.get("label", "")).lower()
                probs[label] = float(item.get("score", 0.0))
            
            # Log raw FinBERT probabilities
            logger.info("Raw FinBERT Probability Distribution:")
            for label, prob in sorted(probs.items(), key=lambda x: -x[1]):
                logger.info(f"  {label:>10}: {prob:.4f} ({prob*100:.2f}%)")
            
            p_pos = float(probs.get("positive", probs.get("bullish", 0.0)))
            p_neg = float(probs.get("negative", probs.get("bearish", 0.0)))
            p_neu = float(probs.get("neutral", 0.0))
            
            # Calculate sentiment score
            score = p_pos - p_neg
            logger.info(f"Sentiment Score: {score:.4f} (positive: {p_pos:.4f} - negative: {p_neg:.4f})")
            
            # Enhanced confidence calculation (entropy-based only)
            confidence = self._calculate_enhanced_confidence(p_pos, p_neg, p_neu)
            logger.info(f"Calculated Confidence: {confidence:.4f} ({confidence*100:.2f}%)")
            
            # Log entropy details
            probs_list = [p_pos, p_neg, p_neu]
            entropy = -sum(p * np.log(p + 1e-10) for p in probs_list if p > 0)
            max_entropy = np.log(3)
            normalized_entropy = 1 - (entropy / max_entropy)
            logger.info(f"Entropy: {entropy:.4f}, Normalized: {normalized_entropy:.4f}, Max Prob: {max(probs_list):.4f}")
            logger.info("[OK] Using REAL FinBERT AI analysis")
            logger.info("=" * 80)
            
            return {
                'sentiment_score': float(score),
                'confidence': float(confidence),
                'probabilities': probs,
                'reasoning': f"[OK] Real FinBERT AI analysis: {score:.3f} sentiment with {confidence:.3f} confidence"
            }
        except Exception as e:
            logger.error(f"[ERROR] FinBERT analysis error: {e}", exc_info=True)
            logger.warning("[WARNING] Falling back to keyword analysis")
            print(f"[ERROR] FinBERT analysis error: {e}")
            print("[WARNING] Falling back to keyword analysis")
            return self._fallback_sentiment_analysis(prompt)
    
    def _calculate_enhanced_confidence(self, p_pos: float, p_neg: float, p_neu: float) -> float:
        """
        Calculate confidence using entropy-based uncertainty metrics.
        
        FinBERT works best with SHORT text (headlines/articles), so we removed the 
        text_length_factor that incorrectly penalized shorter inputs.
        
        Confidence is based purely on probability distribution entropy:
        - High confidence when one class dominates (low entropy)
        - Low confidence when probabilities are similar (high entropy)
        """
        probs = [p_pos, p_neg, p_neu]
        max_prob = max(probs)
        
        # Calculate entropy (uncertainty measure)
        entropy = -sum(p * np.log(p + 1e-10) for p in probs if p > 0)
        max_entropy = np.log(3)  # For 3 classes
        normalized_entropy = 1 - (entropy / max_entropy)
        
        # Confidence is weighted combination of max probability and normalized entropy
        # Max prob (70%): How strongly the model predicts the top class
        # Normalized entropy (30%): How certain vs uncertain the distribution is
        confidence = max_prob * 0.7 + normalized_entropy * 0.3
        
        # Ensure confidence stays in reasonable bounds
        final_confidence = min(1.0, max(0.1, confidence))
        
        return final_confidence
    
    def _fallback_sentiment_analysis(self, text: str) -> Dict[str, Any]:
        """Fallback sentiment analysis using keyword matching"""
        positive_words = ["bullish", "strong", "growth", "positive", "buy", "support", "resistance"]
        negative_words = ["bearish", "weak", "decline", "negative", "sell", "breakdown", "rejection"]
        
        text_lower = text.lower()
        pos_count = sum(1 for word in positive_words if word in text_lower)
        neg_count = sum(1 for word in negative_words if word in text_lower)
        
        total = pos_count + neg_count
        if total == 0:
            return {
                'sentiment_score': 0.0,
                'confidence': 0.3,
                'probabilities': {'positive': 0.33, 'negative': 0.33, 'neutral': 0.34},
                'reasoning': '[WARNING] FALLBACK KEYWORD ANALYSIS (NOT REAL AI) - neutral sentiment with low confidence'
            }
        
        score = (pos_count - neg_count) / total
        confidence = min(0.8, total * 0.1 + 0.3)
        
        return {
            'sentiment_score': float(score),
            'confidence': float(confidence),
            'probabilities': {'positive': 0.5 + score/2, 'negative': 0.5 - score/2, 'neutral': 0.2},
            'reasoning': f'[WARNING] FALLBACK KEYWORD ANALYSIS (NOT REAL AI) - {score:.3f} sentiment with {confidence:.3f} confidence'
        }
    
    def _assess_risk(self, context: MarketContext, finbert_result: Dict[str, Any]) -> Dict[str, Any]:
        """Assess trading risk based on market conditions"""
        risk_factors = []
        
        # Volatility risk
        if context.technical_indicators.volatility_level == "ABOVE_AVERAGE":
            risk_factors.append(0.3)
        elif context.technical_indicators.volatility_level == "BELOW_AVERAGE":
            risk_factors.append(-0.1)
        else:
            risk_factors.append(0.0)
        
        # Economic event risk
        if context.economic_calendar.high_impact_events > 0:
            risk_factors.append(0.2)
        
        # Market regime risk
        if context.market_regime.current_regime == "HIGH VOLATILITY":
            risk_factors.append(0.4)
        elif context.market_regime.current_regime == "RANGING":
            risk_factors.append(0.1)
        
        # FinBERT confidence risk
        if finbert_result['confidence'] < 0.5:
            risk_factors.append(0.2)
        
        total_risk = sum(risk_factors)
        
        if total_risk > 0.5:
            risk_level = "HIGH"
        elif total_risk > 0.2:
            risk_level = "MEDIUM"
        else:
            risk_level = "LOW"
        
        return {
            'risk_level': risk_level,
            'risk_score': total_risk,
            'risk_factors': risk_factors
        }
    
    def _synthesize_decision(self, finbert_result: Dict[str, Any], risk_analysis: Dict[str, Any],
                           context: MarketContext, technical_summary: Dict[str, Any],
                           regime_analysis: Dict[str, Any], levels_analysis: Dict[str, Any],
                           calendar_analysis: Dict[str, Any]) -> EnhancedFinBERTDecision:
        """Synthesize final trading decision from all analysis components"""
        
        # Calculate weighted scores
        technical_score = technical_summary['technical_score']
        regime_score = regime_analysis['score']
        levels_score = levels_analysis['levels_score']
        
        # Combine calendar economic score with FinBERT sentiment
        # Both come from the same source (economic calendar events)
        economic_score = calendar_analysis['score']
        finbert_score = finbert_result['sentiment_score']
        finbert_confidence = finbert_result['confidence']
        
        # Weight the FinBERT score by its confidence (low confidence = less influence)
        weighted_finbert = finbert_score * finbert_confidence
        
        # Combine economic and FinBERT into single economic_finbert score
        # If FinBERT has high confidence, it dominates; if low confidence, rule-based economic score takes over
        economic_finbert_score = (weighted_finbert * 0.7 + economic_score * 0.3)
        
        # Apply component weights (no more risk_assessment in weights)
        weighted_score = (
            technical_score * self.weights['technical_trend'] +
            regime_score * self.weights['market_regime'] +
            levels_score * self.weights['key_levels'] +
            economic_finbert_score * self.weights['economic_finbert']
        )
        
        # Apply risk adjustment (multiplicative, not additive)
        risk_score = risk_analysis['risk_score']
        if risk_score > 0.5:
            weighted_score *= 0.7  # High risk: reduce signal strength by 30%
        elif risk_score > 0.3:
            weighted_score *= 0.85  # Medium risk: reduce signal strength by 15%
        
        # Calculate confluence score
        confluence_score = (technical_score + regime_score + levels_score + economic_score) / 4
        
        # Generate final recommendation
        if weighted_score >= 0.6:
            signal = "STRONG_BUY"
        elif weighted_score >= 0.2:
            signal = "BUY"
        elif weighted_score <= -0.6:
            signal = "STRONG_SELL"
        elif weighted_score <= -0.2:
            signal = "SELL"
        else:
            signal = "NEUTRAL"
        
        # Calculate final trading decision confidence
        # This represents signal conviction, NOT FinBERT sentiment quality
        signal_conviction = abs(weighted_score)
        
        # Combine with component confidences
        technical_confidence = abs(technical_summary['trend_strength']) if 'trend_strength' in technical_summary else 0.5
        regime_confidence = context.market_regime.confidence
        finbert_sentiment_confidence = finbert_result['confidence']
        
        # Weighted average of all confidence sources
        combined_confidence = (
            technical_confidence * 0.3 +
            regime_confidence * 0.3 +
            finbert_sentiment_confidence * 0.4
        )
        
        # If signal is weak, use signal conviction instead of component average
        # This prevents high component confidence from masking weak trading signals
        if signal_conviction < 0.4:
            final_confidence = signal_conviction
            logger.info(f"Weak trading signal detected (conviction: {signal_conviction:.3f} < 0.4)")
            logger.info(f"FinBERT sentiment confidence: {finbert_sentiment_confidence:.3f} (sentiment quality is good)")
            logger.info(f"Position size will be reduced due to conflicting/weak component signals")
        else:
            final_confidence = combined_confidence
            logger.info(f"Strong trading signal (conviction: {signal_conviction:.3f})")
            logger.info(f"Combined confidence: {combined_confidence:.3f}")
        
        confidence = min(1.0, final_confidence)
        
        # Generate reasoning
        reasoning = self._generate_reasoning(
            signal, weighted_score, technical_summary, regime_analysis, 
            levels_analysis, calendar_analysis, risk_analysis
        )
        
        # Calculate price targets and stop loss
        current_price = context.market_data['price']['current']
        atr = context.technical_indicators.atr_current
        
        price_targets = self._calculate_price_targets(current_price, atr, signal)
        stop_loss = self._calculate_stop_loss(current_price, atr, signal)
        
        # Calculate position size multiplier
        position_size_multiplier = self._calculate_position_size_multiplier(
            confidence, risk_analysis['risk_level'], confluence_score
        )
        
        return EnhancedFinBERTDecision(
            signal=signal,
            confidence=confidence,
            weighted_score=weighted_score,
            reasoning=reasoning,
            risk_level=risk_analysis['risk_level'],
            price_targets=price_targets,
            stop_loss=stop_loss,
            position_size_multiplier=position_size_multiplier,
            technical_score=technical_score,
            regime_score=regime_score,
            levels_score=levels_score,
            economic_score=economic_score,
            confluence_score=confluence_score,
            processing_time_ms=0.0  # Will be set by caller
        )
    
    def _generate_reasoning(self, signal: str, weighted_score: float, 
                          technical_summary: Dict, regime_analysis: Dict,
                          levels_analysis: Dict, calendar_analysis: Dict,
                          risk_analysis: Dict) -> str:
        """Generate comprehensive reasoning for the trading decision"""
        
        reasoning_parts = []
        
        # Technical analysis reasoning
        if abs(technical_summary['technical_score']) > 0.3:
            reasoning_parts.append(f"Technical analysis shows {technical_summary['trend_direction']} trend with {technical_summary['trend_strength']:.2f} strength")
        
        # Market regime reasoning
        if regime_analysis['confidence'] > 0.6:
            reasoning_parts.append(f"Market regime: {regime_analysis['regime']} with {regime_analysis['confidence']:.2f} confidence")
        
        # Key levels reasoning
        if levels_analysis['levels_score'] != 0:
            if levels_analysis['levels_score'] > 0:
                reasoning_parts.append("Price near strong support levels")
            else:
                reasoning_parts.append("Price near strong resistance levels")
        
        # Economic calendar reasoning
        if calendar_analysis['confidence'] > 0.5:
            reasoning_parts.append(f"Economic sentiment: {calendar_analysis['signal']} with {calendar_analysis['confidence']:.2f} confidence")
        
        # Risk assessment
        reasoning_parts.append(f"Risk level: {risk_analysis['risk_level']}")
        
        # Final score
        reasoning_parts.append(f"Combined weighted score: {weighted_score:.3f}")
        
        return " | ".join(reasoning_parts)
    
    def _calculate_price_targets(self, current_price: float, atr: float, signal: str) -> Dict[str, float]:
        """Calculate price targets based on signal and ATR"""
        if signal in ["STRONG_BUY", "BUY"]:
            target1 = current_price + (atr * 1.5)
            target2 = current_price + (atr * 2.5)
            target3 = current_price + (atr * 4.0)
        elif signal in ["STRONG_SELL", "SELL"]:
            target1 = current_price - (atr * 1.5)
            target2 = current_price - (atr * 2.5)
            target3 = current_price - (atr * 4.0)
        else:
            target1 = target2 = target3 = current_price
        
        return {
            'target_1': target1,
            'target_2': target2,
            'target_3': target3
        }
    
    def _calculate_stop_loss(self, current_price: float, atr: float, signal: str) -> float:
        """Calculate stop loss based on signal and ATR"""
        if signal in ["STRONG_BUY", "BUY"]:
            stop_loss = current_price - (atr * 1.2)
        elif signal in ["STRONG_SELL", "SELL"]:
            stop_loss = current_price + (atr * 1.2)
        else:
            stop_loss = current_price
        
        return stop_loss
    
    def _calculate_position_size_multiplier(self, confidence: float, risk_level: str, confluence_score: float) -> float:
        """
        Calculate position size multiplier based on signal conviction and risk.
        
        Note: 'confidence' parameter represents TRADING SIGNAL CONVICTION, not FinBERT sentiment quality.
        Low conviction = weak/conflicting signals across technical, regime, levels, and economic components.
        
        Implements weak signal penalty:
        - conviction < 0.4: multiply by 0.3 (severe reduction for weak signals)
        - conviction < 0.6: multiply by conviction (gradual reduction)
        - conviction >= 0.6: no penalty (strong unified signal)
        """
        base_multiplier = confidence
        
        # Apply weak signal penalty (not sentiment confidence penalty)
        if confidence < 0.4:
            signal_penalty = 0.3  # Severe reduction for very weak/conflicting signals
            logger.info(f"Weak trading signal penalty applied: {confidence:.3f} < 0.4, using penalty {signal_penalty}")
        elif confidence < 0.6:
            signal_penalty = confidence  # Gradual reduction for moderate signals
            logger.info(f"Moderate signal strength: {confidence:.3f} < 0.6, using proportional sizing")
        else:
            signal_penalty = 1.0  # No penalty for strong unified signals
            logger.info(f"Strong signal detected: {confidence:.3f} >= 0.6, full position sizing")
        
        base_multiplier *= signal_penalty
        
        # Adjust for risk level
        risk_adjustments = {
            "LOW": 1.2,
            "MEDIUM": 1.0,
            "HIGH": 0.7
        }
        
        risk_multiplier = risk_adjustments.get(risk_level, 1.0)
        
        # Adjust for confluence
        confluence_multiplier = 0.8 + (confluence_score * 0.4)  # 0.8 to 1.2 range
        
        final_multiplier = base_multiplier * risk_multiplier * confluence_multiplier
        
        logger.info(f"Position sizing: base={base_multiplier:.3f}, risk={risk_multiplier:.3f}, "
                   f"confluence={confluence_multiplier:.3f}, final={final_multiplier:.3f}")
        
        return max(0.1, min(2.0, final_multiplier))  # Clamp between 0.1 and 2.0


# ------------------------------ Main Analysis Function --------------------------------

def analyze_enhanced_market_data(market_context_data: Dict[str, Any]) -> Dict[str, Any]:
    """Main function to analyze enhanced market data"""
    try:
        # Parse market context
        context = MarketContext(
            timestamp=market_context_data['timestamp'],
            symbol=market_context_data['symbol'],
            timeframe=market_context_data['timeframe'],
            market_data=market_context_data['market_data'],
            technical_indicators=TechnicalAnalysis(**market_context_data['technical_indicators']),
            market_regime=MarketRegime(**market_context_data['market_regime']),
            key_levels=KeyLevels(**market_context_data['key_levels']),
            economic_calendar=EconomicCalendar(**market_context_data['economic_calendar'])
        )
        
        # Run enhanced analysis
        analyzer = EnhancedFinBERTAnalyzer()
        decision = analyzer.analyze_comprehensive_market_data(context)
        
        # Convert to dictionary for JSON serialization
        result = {
            'signal': decision.signal,
            'confidence': decision.confidence,
            'weighted_score': decision.weighted_score,
            'reasoning': decision.reasoning,
            'risk_level': decision.risk_level,
            'price_targets': decision.price_targets,
            'stop_loss': decision.stop_loss,
            'position_size_multiplier': decision.position_size_multiplier,
            'technical_score': decision.technical_score,
            'regime_score': decision.regime_score,
            'levels_score': decision.levels_score,
            'economic_score': decision.economic_score,
            'confluence_score': decision.confluence_score,
            'processing_time_ms': decision.processing_time_ms,
            'analyzer': 'Enhanced FinBERT',
            'timestamp': market_context_data['timestamp'],
            'symbol': market_context_data['symbol'],
            'timeframe': market_context_data['timeframe'],
            # Diagnostic information
            'component_weights': {
                'technical_trend': analyzer.weights['technical_trend'],
                'market_regime': analyzer.weights['market_regime'],
                'key_levels': analyzer.weights['key_levels'],
                'economic_finbert': analyzer.weights['economic_finbert']
            },
            'component_scores': {
                'technical_score': decision.technical_score,
                'regime_score': decision.regime_score,
                'levels_score': decision.levels_score,
                'economic_score': decision.economic_score,
                'finbert_sentiment_score': decision.weighted_score  # Overall weighted score
            },
            'component_contributions': {
                'technical_contribution': decision.technical_score * analyzer.weights['technical_trend'],
                'regime_contribution': decision.regime_score * analyzer.weights['market_regime'],
                'levels_contribution': decision.levels_score * analyzer.weights['key_levels'],
                'economic_finbert_contribution': decision.economic_score * analyzer.weights['economic_finbert']
            },
            'confidence_breakdown': {
                'base_confidence': decision.confidence,
                'technical_confidence': abs(decision.technical_score),
                'regime_confidence': context.market_regime.confidence,
                'confluence_confidence': decision.confluence_score,
                'finbert_confidence': decision.confidence
            },
            'input_data_summary': {
                'symbol': context.symbol,
                'timeframe': context.timeframe,
                'current_price': context.market_data['price']['current'],
                'trend_direction': context.technical_indicators.trend_direction,
                'trend_strength': context.technical_indicators.trend_strength,
                'current_regime': context.market_regime.current_regime,
                'regime_confidence': context.market_regime.confidence,
                'rsi_current': context.technical_indicators.rsi_current,
                'volatility_level': context.technical_indicators.volatility_level,
                'economic_events_today': context.economic_calendar.events_today,
                'high_impact_events': context.economic_calendar.high_impact_events
            }
        }
        
        return result
        
    except Exception as e:
        print(f"Error in enhanced market data analysis: {e}")
        return {
            'signal': 'NEUTRAL',
            'confidence': 0.0,
            'weighted_score': 0.0,
            'reasoning': f'Analysis error: {str(e)}',
            'risk_level': 'HIGH',
            'price_targets': {'target_1': 0.0, 'target_2': 0.0, 'target_3': 0.0},
            'stop_loss': 0.0,
            'position_size_multiplier': 0.1,
            'technical_score': 0.0,
            'regime_score': 0.0,
            'levels_score': 0.0,
            'economic_score': 0.0,
            'confluence_score': 0.0,
            'processing_time_ms': 0.0,
            'analyzer': 'Enhanced FinBERT (Error)',
            'timestamp': market_context_data.get('timestamp', ''),
            'symbol': market_context_data.get('symbol', ''),
            'timeframe': market_context_data.get('timeframe', '')
        }


# ------------------------------ CLI Interface --------------------------------

def main(argv: Optional[List[str]] = None) -> int:
    import argparse
    from datetime import datetime
    import glob

    parser = argparse.ArgumentParser(description="Enhanced FinBERT multi-modal trading intelligence analyzer")
    parser.add_argument("--input", dest="input_path", default=None, help="Path to market context JSON file")
    parser.add_argument("--output", dest="output_path", default=None, help="Path to enhanced analysis output JSON file")
    args = parser.parse_args(argv)

    # Find market context file
    if args.input_path:
        input_path = args.input_path
    else:
        # Look for market context files in common files directory
        pattern = os.path.join(common_files_dir(), "market_context_*.json")
        files = glob.glob(pattern)
        if not files:
            print("No market context files found")
            return 1
        input_path = max(files, key=os.path.getctime)  # Get most recent file

    # Read market context data
    try:
        with open(input_path, "r", encoding="utf-8") as f:
            market_context_data = json.load(f)
    except Exception as e:
        print(f"Error reading market context file: {e}")
        return 1

    # Run enhanced analysis
    result = analyze_enhanced_market_data(market_context_data)
    result["analysis_timestamp"] = datetime.now().isoformat()
    
    # Check if using real FinBERT or fallback
    if "FALLBACK" in result['reasoning']:
        result["finbert_status"] = "FALLBACK_MODE"
        print("🚨 WARNING: Using FALLBACK analysis (FinBERT not available)")
    else:
        result["finbert_status"] = "REAL_AI"
        print("[OK] Using REAL FinBERT AI analysis")

    # Write result
    output_path = args.output_path or default_output_path()
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
    except Exception:
        pass
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    
    print(f"Enhanced FinBERT analysis completed: {result['signal']} (confidence: {result['confidence']:.3f})")
    print(f"Output saved to: {output_path}")
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
