//+------------------------------------------------------------------+
//|                                        GrandeMultiTimeframeAnalyzer.mqh |
//|                                    Copyright 2025, Grande Trading System |
//|                                             https://www.grande.com |
//+------------------------------------------------------------------+
// STATUS: PARTIALLY IMPLEMENTED - CURRENTLY DISABLED IN PRODUCTION
//
// PURPOSE:
//   Analyze market conditions across multiple timeframes to provide consensus signals.
//   Helps avoid false signals by requiring alignment across timeframes.
//
// RESPONSIBILITIES:
//   - Analyze regime on H4, H1, and M15 timeframes
//   - Calculate consensus score weighted by timeframe importance
//   - Provide detailed multi-timeframe analysis reports
//   - Detect timeframe conflicts
//
// DEPENDENCIES:
//   - GrandeMarketRegimeDetector.mqh (for RegimeSnapshot)
//
// STATE MANAGED:
//   - Consensus data for each analyzed timeframe
//   - Weighted consensus scores
//   - Timeframe conflict detection
//
// IMPLEMENTATION STATUS:
//   ℹ️ This implementation is PARTIALLY COMPLETE but currently DISABLED in the main EA.
//   The class has basic functionality but needs:
//   - Better error handling
//   - Performance optimization
//   - Integration testing with main EA
//   - Validation of consensus algorithms
//
// ENABLED: To enable, uncomment initialization in GrandeTradingSystem.mq5 OnInit()
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: Basic testing needed before production use
//+------------------------------------------------------------------+

#property copyright "Copyright 2025, Grande Trading System"
#property link      "https://www.grande.com"
#property version   "1.00"

#include "GrandeMarketRegimeDetector.mqh"
#include "GrandeKeyLevelDetector.mqh"  // Phase 3: For limit price validation

//+------------------------------------------------------------------+
//| Multi-Timeframe Consensus Structure                              |
//+------------------------------------------------------------------+
struct STimeframeConsensus {
    ENUM_TIMEFRAMES timeframe;
    string regime;
    double confidence;
    double adx;
    double rsi;
    int weight;              // Importance weight (H4=3, H1=2, M15=1)
    bool supports_long;
    bool supports_short;
    bool supports_breakout;
    bool supports_range;
    string primary_signal;   // "LONG", "SHORT", "BREAKOUT", "RANGE", "NEUTRAL"
    string reasoning;        // Why this timeframe supports/opposes the signal
};

//+------------------------------------------------------------------+
//| Multi-Timeframe Analyzer Class                                  |
//+------------------------------------------------------------------+
class CMultiTimeframeAnalyzer {
private:
    STimeframeConsensus m_consensus[];
    int m_consensus_count;
    string m_symbol;
    
    // Helper functions
    void AnalyzeTimeframe(ENUM_TIMEFRAMES tf, const RegimeSnapshot &rs);
    int GetTimeframeWeight(ENUM_TIMEFRAMES tf);
    string GetTimeframeSignal(ENUM_TIMEFRAMES tf, const RegimeSnapshot &rs);
    
public:
    CMultiTimeframeAnalyzer();
    ~CMultiTimeframeAnalyzer();
    
    bool Initialize(string symbol);
    string GetConsensusDecision(const RegimeSnapshot &rs);
    string GetDetailedAnalysis(const RegimeSnapshot &rs);
    bool IsConsensusStrong();
    double GetConsensusStrength();
    void Reset();
    
    // Phase 3: Limit price validation across timeframes
    bool ValidateLimitPriceMultiTimeframe(double limitPrice, bool isBuy, 
                                          CGrandeKeyLevelDetector* keyLevelH1,
                                          CGrandeKeyLevelDetector* keyLevelH4,
                                          CGrandeKeyLevelDetector* keyLevelD1);
    bool ValidateLimitPriceOnTimeframe(double limitPrice, bool isBuy, 
                                       ENUM_TIMEFRAMES timeframe,
                                       CGrandeKeyLevelDetector* keyLevelDetector);
    double GetMultiTimeframeConfluenceScore(double limitPrice, bool isBuy,
                                            CGrandeKeyLevelDetector* keyLevelH1,
                                            CGrandeKeyLevelDetector* keyLevelH4,
                                            CGrandeKeyLevelDetector* keyLevelD1);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMultiTimeframeAnalyzer::CMultiTimeframeAnalyzer() {
    m_consensus_count = 0;
    m_symbol = "";
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMultiTimeframeAnalyzer::~CMultiTimeframeAnalyzer() {
    ArrayFree(m_consensus);
}

//+------------------------------------------------------------------+
//| Initialize the analyzer                                          |
//+------------------------------------------------------------------+
bool CMultiTimeframeAnalyzer::Initialize(string symbol) {
    m_symbol = symbol;
    ArrayResize(m_consensus, 3);  // H4, H1, M15
    m_consensus_count = 0;
    return true;
}

//+------------------------------------------------------------------+
//| Get consensus decision from all timeframes                       |
//+------------------------------------------------------------------+
string CMultiTimeframeAnalyzer::GetConsensusDecision(const RegimeSnapshot &rs) {
    Reset();
    
    // Analyze each timeframe
    AnalyzeTimeframe(PERIOD_H4, rs);
    AnalyzeTimeframe(PERIOD_H1, rs);
    AnalyzeTimeframe(PERIOD_M15, rs);
    
    // Calculate consensus
    int bull_score = 0;
    int bear_score = 0;
    int breakout_score = 0;
    int range_score = 0;
    int total_weight = 0;
    
    for(int i = 0; i < m_consensus_count; i++) {
        if(m_consensus[i].supports_long) 
            bull_score += m_consensus[i].weight;
        if(m_consensus[i].supports_short)
            bear_score += m_consensus[i].weight;
        if(m_consensus[i].supports_breakout)
            breakout_score += m_consensus[i].weight;
        if(m_consensus[i].supports_range)
            range_score += m_consensus[i].weight;
        total_weight += m_consensus[i].weight;
    }
    
    // Determine consensus
    if(bull_score > bear_score * 1.5 && bull_score > breakout_score && bull_score > range_score) 
        return "STRONG_LONG";
    if(bear_score > bull_score * 1.5 && bear_score > breakout_score && bear_score > range_score) 
        return "STRONG_SHORT";
    if(breakout_score > bull_score && breakout_score > bear_score && breakout_score > range_score) 
        return "STRONG_BREAKOUT";
    if(range_score > bull_score && range_score > bear_score && range_score > breakout_score) 
        return "STRONG_RANGE";
    if(bull_score > bear_score) 
        return "WEAK_LONG";
    if(bear_score > bull_score) 
        return "WEAK_SHORT";
    if(breakout_score > range_score) 
        return "WEAK_BREAKOUT";
    if(range_score > breakout_score) 
        return "WEAK_RANGE";
    
    return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Analyze specific timeframe                                       |
//+------------------------------------------------------------------+
void CMultiTimeframeAnalyzer::AnalyzeTimeframe(ENUM_TIMEFRAMES tf, const RegimeSnapshot &rs) {
    if(m_consensus_count >= 3) return;
    
    STimeframeConsensus consensus;
    consensus.timeframe = tf;
    consensus.weight = GetTimeframeWeight(tf);
    
    // Get regime-specific data
    if(tf == PERIOD_H4) {
        consensus.regime = g_regimeDetector.RegimeToString(rs.regime);
        consensus.confidence = rs.confidence;
        consensus.adx = rs.adx_h4;
        consensus.rsi = 50.0; // Default RSI value - will be calculated separately
    }
    else if(tf == PERIOD_H1) {
        consensus.regime = g_regimeDetector.RegimeToString(rs.regime);
        consensus.confidence = rs.confidence;
        consensus.adx = rs.adx_h1;
        consensus.rsi = 50.0; // Default RSI value - will be calculated separately
    }
    else if(tf == PERIOD_M15) {
        consensus.regime = g_regimeDetector.RegimeToString(rs.regime);
        consensus.confidence = rs.confidence;
        consensus.adx = rs.adx_h1;  // Use H1 ADX for M15
        consensus.rsi = 50.0; // Default RSI value - will be calculated separately
    }
    
    // Determine signal support
    consensus.primary_signal = GetTimeframeSignal(tf, rs);
    
    // Set support flags
    consensus.supports_long = (consensus.primary_signal == "LONG");
    consensus.supports_short = (consensus.primary_signal == "SHORT");
    consensus.supports_breakout = (consensus.primary_signal == "BREAKOUT");
    consensus.supports_range = (consensus.primary_signal == "RANGE");
    
    // Generate reasoning
    consensus.reasoning = StringFormat("%s: %s (ADX:%.1f, RSI:%.1f, Conf:%.2f)", 
                                     EnumToString(tf), consensus.primary_signal, 
                                     consensus.adx, consensus.rsi, consensus.confidence);
    
    m_consensus[m_consensus_count] = consensus;
    m_consensus_count++;
}

//+------------------------------------------------------------------+
//| Get timeframe weight (H4=3, H1=2, M15=1)                        |
//+------------------------------------------------------------------+
int CMultiTimeframeAnalyzer::GetTimeframeWeight(ENUM_TIMEFRAMES tf) {
    switch(tf) {
        case PERIOD_H4: return 3;
        case PERIOD_H1: return 2;
        case PERIOD_M15: return 1;
        default: return 1;
    }
}

//+------------------------------------------------------------------+
//| Get signal for specific timeframe                                |
//+------------------------------------------------------------------+
string CMultiTimeframeAnalyzer::GetTimeframeSignal(ENUM_TIMEFRAMES tf, const RegimeSnapshot &rs) {
    // Use regime and technical indicators to determine signal
    if(rs.regime == REGIME_TREND_BULL) {
        if(rs.adx_h4 > 25) return "LONG";
        return "WEAK_LONG";
    }
    else if(rs.regime == REGIME_TREND_BEAR) {
        if(rs.adx_h4 > 25) return "SHORT";
        return "WEAK_SHORT";
    }
    else if(rs.regime == REGIME_BREAKOUT_SETUP) {
        if(rs.adx_h1 > 20) return "BREAKOUT";
        return "WEAK_BREAKOUT";
    }
    else if(rs.regime == REGIME_RANGING) {
        if(rs.adx_h1 < 20) return "RANGE";
        return "WEAK_RANGE";
    }
    
    return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Get detailed analysis report                                     |
//+------------------------------------------------------------------+
string CMultiTimeframeAnalyzer::GetDetailedAnalysis(const RegimeSnapshot &rs) {
    string analysis = "\n=== MULTI-TIMEFRAME CONSENSUS ANALYSIS ===\n";
    
    for(int i = 0; i < m_consensus_count; i++) {
        analysis += StringFormat("%s (Weight: %d): %s\n", 
                                EnumToString(m_consensus[i].timeframe),
                                m_consensus[i].weight,
                                m_consensus[i].reasoning);
    }
    
    analysis += StringFormat("\nConsensus Decision: %s\n", GetConsensusDecision(rs));
    analysis += StringFormat("Consensus Strength: %.1f%%\n", GetConsensusStrength());
    analysis += "==========================================\n";
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Check if consensus is strong                                     |
//+------------------------------------------------------------------+
bool CMultiTimeframeAnalyzer::IsConsensusStrong() {
    return GetConsensusStrength() > 60.0;
}

//+------------------------------------------------------------------+
//| Get consensus strength percentage                                |
//+------------------------------------------------------------------+
double CMultiTimeframeAnalyzer::GetConsensusStrength() {
    if(m_consensus_count == 0) return 0.0;
    
    int max_score = 0;
    int total_weight = 0;
    
    // Count scores for each signal type
    int bull_score = 0, bear_score = 0, breakout_score = 0, range_score = 0;
    
    for(int i = 0; i < m_consensus_count; i++) {
        if(m_consensus[i].supports_long) bull_score += m_consensus[i].weight;
        if(m_consensus[i].supports_short) bear_score += m_consensus[i].weight;
        if(m_consensus[i].supports_breakout) breakout_score += m_consensus[i].weight;
        if(m_consensus[i].supports_range) range_score += m_consensus[i].weight;
        total_weight += m_consensus[i].weight;
    }
    
    max_score = MathMax(MathMax(bull_score, bear_score), MathMax(breakout_score, range_score));
    
    if(total_weight == 0) return 0.0;
    return (double)max_score / total_weight * 100.0;
}

//+------------------------------------------------------------------+
//| Reset consensus data                                             |
//+------------------------------------------------------------------+
void CMultiTimeframeAnalyzer::Reset() {
    m_consensus_count = 0;
    ArrayFree(m_consensus);
    ArrayResize(m_consensus, 3);
}

//+------------------------------------------------------------------+
//| Phase 3: Validate limit price across multiple timeframes        |
//+------------------------------------------------------------------+
bool CMultiTimeframeAnalyzer::ValidateLimitPriceMultiTimeframe(double limitPrice, bool isBuy,
                                                               CGrandeKeyLevelDetector* keyLevelH1,
                                                               CGrandeKeyLevelDetector* keyLevelH4,
                                                               CGrandeKeyLevelDetector* keyLevelD1)
{
    // Check H1, H4, D1 for conflicts
    bool h1Valid = ValidateLimitPriceOnTimeframe(limitPrice, isBuy, PERIOD_H1, keyLevelH1);
    bool h4Valid = ValidateLimitPriceOnTimeframe(limitPrice, isBuy, PERIOD_H4, keyLevelH4);
    bool d1Valid = ValidateLimitPriceOnTimeframe(limitPrice, isBuy, PERIOD_D1, keyLevelD1);
    
    // Require at least H1 and H4 alignment (D1 is preferred but not required)
    return h1Valid && h4Valid;
}

//+------------------------------------------------------------------+
//| Phase 3: Validate limit price on specific timeframe             |
//+------------------------------------------------------------------+
bool CMultiTimeframeAnalyzer::ValidateLimitPriceOnTimeframe(double limitPrice, bool isBuy,
                                                            ENUM_TIMEFRAMES timeframe,
                                                            CGrandeKeyLevelDetector* keyLevelDetector)
{
    if(keyLevelDetector == NULL)
    {
        // Fallback: basic direction check
        double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(isBuy)
            return limitPrice <= currentPrice; // Buy limits below current
        else
            return limitPrice >= currentPrice; // Sell limits above current
    }
    
    // Check if limit price aligns with key levels on this timeframe
    // For buys: price should be at or near support
    // For sells: price should be at or near resistance
    double proximityPips = 5.0; // 5 pip tolerance
    double pipSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(m_symbol, SYMBOL_DIGITS) >= 5)
        pipSize *= 10.0;
    double proximity = proximityPips * pipSize;
    
    int levelCount = keyLevelDetector.GetKeyLevelCount();
    for(int i = 0; i < levelCount; i++)
    {
        SKeyLevel level;
        if(keyLevelDetector.GetKeyLevel(i, level))
        {
            if(MathAbs(limitPrice - level.price) <= proximity)
            {
                // Check alignment
                if(isBuy && !level.isResistance) // Buy at support
                    return true;
                if(!isBuy && level.isResistance) // Sell at resistance
                    return true;
            }
        }
    }
    
    // If no key level found nearby, use basic direction check
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    if(isBuy)
        return limitPrice <= currentPrice;
    else
        return limitPrice >= currentPrice;
}

//+------------------------------------------------------------------+
//| Phase 3: Get multi-timeframe confluence score for price level   |
//+------------------------------------------------------------------+
double CMultiTimeframeAnalyzer::GetMultiTimeframeConfluenceScore(double limitPrice, bool isBuy,
                                                                 CGrandeKeyLevelDetector* keyLevelH1,
                                                                 CGrandeKeyLevelDetector* keyLevelH4,
                                                                 CGrandeKeyLevelDetector* keyLevelD1)
{
    double score = 0.0;
    double proximityPips = 5.0;
    double pipSize = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(m_symbol, SYMBOL_DIGITS) >= 5)
        pipSize *= 10.0;
    double proximity = proximityPips * pipSize;
    
    // Check if price appears as key level on multiple timeframes
    // Weight: D1 = 0.5, H4 = 0.3, H1 = 0.2
    bool foundH1 = false, foundH4 = false, foundD1 = false;
    
    if(keyLevelH1 != NULL)
    {
        int count = keyLevelH1.GetKeyLevelCount();
        for(int i = 0; i < count; i++)
        {
            SKeyLevel level;
            if(keyLevelH1.GetKeyLevel(i, level))
            {
                if(MathAbs(limitPrice - level.price) <= proximity)
                {
                    if((isBuy && !level.isResistance) || (!isBuy && level.isResistance))
                    {
                        foundH1 = true;
                        break;
                    }
                }
            }
        }
    }
    
    if(keyLevelH4 != NULL)
    {
        int count = keyLevelH4.GetKeyLevelCount();
        for(int i = 0; i < count; i++)
        {
            SKeyLevel level;
            if(keyLevelH4.GetKeyLevel(i, level))
            {
                if(MathAbs(limitPrice - level.price) <= proximity)
                {
                    if((isBuy && !level.isResistance) || (!isBuy && level.isResistance))
                    {
                        foundH4 = true;
                        break;
                    }
                }
            }
        }
    }
    
    if(keyLevelD1 != NULL)
    {
        int count = keyLevelD1.GetKeyLevelCount();
        for(int i = 0; i < count; i++)
        {
            SKeyLevel level;
            if(keyLevelD1.GetKeyLevel(i, level))
            {
                if(MathAbs(limitPrice - level.price) <= proximity)
                {
                    if((isBuy && !level.isResistance) || (!isBuy && level.isResistance))
                    {
                        foundD1 = true;
                        break;
                    }
                }
            }
        }
    }
    
    // Calculate weighted score
    if(foundD1) score += 0.5;
    if(foundH4) score += 0.3;
    if(foundH1) score += 0.2;
    
    return score;
}