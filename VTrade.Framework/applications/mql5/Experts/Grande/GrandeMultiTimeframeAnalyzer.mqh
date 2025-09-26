//+------------------------------------------------------------------+
//|                                        GrandeMultiTimeframeAnalyzer.mqh |
//|                                    Copyright 2025, Grande Trading System |
//|                                             https://www.grande.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Grande Trading System"
#property link      "https://www.grande.com"
#property version   "1.00"

#include "GrandeMarketRegimeDetector.mqh"

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