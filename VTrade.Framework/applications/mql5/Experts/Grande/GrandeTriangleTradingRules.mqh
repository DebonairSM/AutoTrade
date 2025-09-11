//+------------------------------------------------------------------+
//| GrandeTriangleTradingRules.mqh                                  |
//| Copyright 2024, Grande Tech                                      |
//| Triangle Pattern Trading Rules and Risk Management              |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor trading logic and risk management

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Triangle pattern trading rules with advanced risk management"

#include "GrandeTrianglePatternDetector.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Triangle Trading Signal Structure                               |
//+------------------------------------------------------------------+
struct STriangleSignal
{
    bool                isValid;            // Is signal valid
    ENUM_ORDER_TYPE     orderType;          // BUY or SELL
    double              entryPrice;         // Suggested entry price
    double              stopLoss;           // Stop loss price
    double              takeProfit;         // Take profit price
    double              signalStrength;     // Signal strength (0.0-1.0)
    string              signalReason;       // Reason for signal
    datetime            signalTime;         // Signal generation time
    bool                breakoutConfirmed;  // Is breakout confirmed
    double              volumeConfirmation; // Volume confirmation ratio
};

//+------------------------------------------------------------------+
//| Triangle Trading Configuration                                   |
//+------------------------------------------------------------------+
struct TriangleTradingConfig
{
    // Signal Requirements
    double              minConfidence;          // Minimum pattern confidence (0.6)
    double              minBreakoutProb;        // Minimum breakout probability (0.6)
    bool                requireVolumeConfirm;   // Require volume confirmation
    
    // Entry Rules
    double              breakoutBuffer;         // Buffer above/below levels (5 pips)
    double              confirmationBars;       // Bars to wait for confirmation (2)
    bool                allowEarlyEntry;        // Allow entry before breakout
    
    // Risk Management
    double              riskRewardRatio;        // Minimum risk:reward ratio (2.0)
    double              maxRiskPercent;         // Maximum risk per trade (2%)
    double              positionSizeMultiplier; // Position size multiplier (1.0)
    
    // Breakout Confirmation
    double              minBreakoutPips;        // Minimum breakout in pips (10)
    double              volumeSpikeMultiplier;  // Volume spike multiplier (1.5)
    int                 volumeLookbackBars;     // Volume lookback period (20)
    
    // Constructor with defaults
    TriangleTradingConfig()
    {
        minConfidence = 0.6;
        minBreakoutProb = 0.6;
        requireVolumeConfirm = true;
        breakoutBuffer = 5.0 * _Point * 10; // 5 pips
        confirmationBars = 2;
        allowEarlyEntry = false;
        riskRewardRatio = 2.0;
        maxRiskPercent = 2.0;
        positionSizeMultiplier = 1.0;
        minBreakoutPips = 10.0 * _Point * 10; // 10 pips
        volumeSpikeMultiplier = 1.5;
        volumeLookbackBars = 20;
    }
};

//+------------------------------------------------------------------+
//| Grande Triangle Trading Rules Class                            |
//+------------------------------------------------------------------+
class CGrandeTriangleTradingRules
{
private:
    // Configuration
    TriangleTradingConfig m_config;
    string              m_symbol;
    bool                m_initialized;
    
    // Triangle detector
    CGrandeTrianglePatternDetector m_triangleDetector;
    
    // Current state
    STrianglePattern    m_lastPattern;
    STriangleSignal     m_currentSignal;
    datetime            m_lastSignalTime;
    bool                m_signalActive;
    
    // Helper methods
    bool                ValidateSignalRequirements();
    STriangleSignal     GenerateBreakoutSignal();
    STriangleSignal     GenerateEarlyEntrySignal();
    bool                IsBreakoutConfirmed();
    double              CalculateVolumeConfirmation();
    double              CalculatePositionSize(double riskAmount);
    bool                ValidateRiskReward();
    void                UpdateSignalStrength();
    
public:
    // Constructor/Destructor
    CGrandeTriangleTradingRules();
    ~CGrandeTriangleTradingRules();
    
    // Initialization
    bool                Initialize(string symbol, TriangleTradingConfig config = TriangleTradingConfig());
    void                Deinitialize();
    
    // Signal Generation
    STriangleSignal     GenerateSignal();
    STriangleSignal     GetCurrentSignal() const { return m_currentSignal; }
    bool                IsSignalActive() const { return m_signalActive; }
    
    // Pattern Analysis
    bool                UpdatePattern();
    STrianglePattern    GetCurrentPattern() const;
    double              GetPatternConfidence() const;
    double              GetBreakoutProbability() const;
    
    // Trading Information
    double              GetEntryPrice() const { return m_currentSignal.entryPrice; }
    double              GetStopLoss() const { return m_currentSignal.stopLoss; }
    double              GetTakeProfit() const { return m_currentSignal.takeProfit; }
    double              GetSignalStrength() const { return m_currentSignal.signalStrength; }
    string              GetSignalReason() const { return m_currentSignal.signalReason; }
    
    // Risk Management
    double              CalculateRiskAmount(double accountBalance);
    double              CalculatePositionSize(double accountBalance, double riskAmount);
    bool                ValidateTradeSetup();
    
    // Utility Methods
    void                ResetSignal();
    void                LogSignalInfo();
    string              GetSignalTypeString() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGrandeTriangleTradingRules::CGrandeTriangleTradingRules()
{
    m_initialized = false;
    m_symbol = "";
    m_lastSignalTime = 0;
    m_signalActive = false;
    ZeroMemory(m_currentSignal);
    m_currentSignal.isValid = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGrandeTriangleTradingRules::~CGrandeTriangleTradingRules()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize Triangle Trading Rules                               |
//+------------------------------------------------------------------+
bool CGrandeTriangleTradingRules::Initialize(string symbol, TriangleTradingConfig config)
{
    if(symbol == "" || SymbolSelect(symbol, true) == false)
    {
        Print("❌ GrandeTriangleTradingRules: Invalid symbol ", symbol);
        return false;
    }
    
    m_symbol = symbol;
    m_config = config;
    
    // Initialize triangle detector
    TriangleConfig triangleConfig;
    if(!m_triangleDetector.Initialize(m_symbol, triangleConfig))
    {
        Print("❌ Failed to initialize triangle detector");
        return false;
    }
    
    m_initialized = true;
    Print("✅ GrandeTriangleTradingRules initialized for ", m_symbol);
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                     |
//+------------------------------------------------------------------+
void CGrandeTriangleTradingRules::Deinitialize()
{
    m_initialized = false;
    m_triangleDetector.Deinitialize();
    ResetSignal();
}

//+------------------------------------------------------------------+
//| Generate Trading Signal Based on Triangle Pattern              |
//+------------------------------------------------------------------+
STriangleSignal CGrandeTriangleTradingRules::GenerateSignal()
{
    STriangleSignal signal;
    ZeroMemory(signal);
    signal.isValid = false;
    
    if(!m_initialized)
    {
        Print("❌ GrandeTriangleTradingRules not initialized");
        return signal;
    }
    
    // Update pattern detection
    if(!UpdatePattern())
    {
        // Print("🔍 No triangle pattern detected");
        return signal;
    }
    
    // Validate signal requirements
    if(!ValidateSignalRequirements())
    {
        // Print("🔍 Signal requirements not met");
        return signal;
    }
    
    // Check for breakout confirmation
    if(IsBreakoutConfirmed())
    {
        signal = GenerateBreakoutSignal();
    }
    else if(m_config.allowEarlyEntry)
    {
        signal = GenerateEarlyEntrySignal();
    }
    
    // Update signal strength
    if(signal.isValid)
    {
        UpdateSignalStrength();
        m_currentSignal = signal;
        m_signalActive = true;
        m_lastSignalTime = TimeCurrent();
        
        LogSignalInfo();
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Update Pattern Detection                                         |
//+------------------------------------------------------------------+
bool CGrandeTriangleTradingRules::UpdatePattern()
{
    if(!m_triangleDetector.DetectTrianglePattern(100))
    {
        return false;
    }
    
    m_lastPattern = m_triangleDetector.GetCurrentPattern();
    return m_lastPattern.isActive;
}

//+------------------------------------------------------------------+
//| Validate Signal Requirements                                     |
//+------------------------------------------------------------------+
bool CGrandeTriangleTradingRules::ValidateSignalRequirements()
{
    // Check pattern confidence
    if(m_lastPattern.confidence < m_config.minConfidence)
    {
        return false;
    }
    
    // Check breakout probability
    if(m_lastPattern.breakoutProbability < m_config.minBreakoutProb)
    {
        return false;
    }
    
    // Check volume confirmation if required
    if(m_config.requireVolumeConfirm && !m_lastPattern.volumeConfirmed)
    {
        return false;
    }
    
    // Check pattern type (some types are more reliable)
    if(m_lastPattern.type == TRIANGLE_NONE)
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check for Breakout Confirmation                                 |
//+------------------------------------------------------------------+
bool CGrandeTriangleTradingRules::IsBreakoutConfirmed()
{
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    
    // Check for resistance breakout (bullish)
    if(currentPrice > m_lastPattern.resistanceLevel + m_config.breakoutBuffer)
    {
        // Check volume confirmation
        double volumeConfirm = CalculateVolumeConfirmation();
        if(volumeConfirm > m_config.volumeSpikeMultiplier)
        {
            return true;
        }
    }
    
    // Check for support breakdown (bearish)
    if(currentPrice < m_lastPattern.supportLevel - m_config.breakoutBuffer)
    {
        // Check volume confirmation
        double volumeConfirm = CalculateVolumeConfirmation();
        if(volumeConfirm > m_config.volumeSpikeMultiplier)
        {
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Generate Breakout Signal                                        |
//+------------------------------------------------------------------+
STriangleSignal CGrandeTriangleTradingRules::GenerateBreakoutSignal()
{
    STriangleSignal signal;
    ZeroMemory(signal);
    signal.isValid = false;
    
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    
    // Determine signal direction based on triangle type and breakout
    if(currentPrice > m_lastPattern.resistanceLevel + m_config.breakoutBuffer)
    {
        // Bullish breakout
        signal.orderType = ORDER_TYPE_BUY;
        signal.entryPrice = currentAsk;
        signal.stopLoss = m_lastPattern.stopLossPrice;
        signal.takeProfit = m_lastPattern.targetPrice;
        signal.signalReason = "Bullish breakout from " + m_triangleDetector.GetPatternTypeString() + " triangle";
        signal.breakoutConfirmed = true;
    }
    else if(currentPrice < m_lastPattern.supportLevel - m_config.breakoutBuffer)
    {
        // Bearish breakout
        signal.orderType = ORDER_TYPE_SELL;
        signal.entryPrice = currentPrice;
        signal.stopLoss = m_lastPattern.stopLossPrice;
        signal.takeProfit = m_lastPattern.targetPrice;
        signal.signalReason = "Bearish breakout from " + m_triangleDetector.GetPatternTypeString() + " triangle";
        signal.breakoutConfirmed = true;
    }
    
    // Validate risk:reward ratio
    if(signal.isValid && !ValidateRiskReward())
    {
        signal.isValid = false;
        return signal;
    }
    
    signal.isValid = true;
    signal.signalTime = TimeCurrent();
    signal.volumeConfirmation = CalculateVolumeConfirmation();
    
    return signal;
}

//+------------------------------------------------------------------+
//| Generate Early Entry Signal (Before Breakout)                  |
//+------------------------------------------------------------------+
STriangleSignal CGrandeTriangleTradingRules::GenerateEarlyEntrySignal()
{
    STriangleSignal signal;
    ZeroMemory(signal);
    signal.isValid = false;
    
    // Early entry is only recommended for high-confidence ascending triangles
    if(m_lastPattern.type != TRIANGLE_ASCENDING || m_lastPattern.confidence < 0.8)
    {
        return signal;
    }
    
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    
    // Early entry near support level
    if(currentPrice <= m_lastPattern.supportLevel + (m_config.breakoutBuffer * 2))
    {
        signal.orderType = ORDER_TYPE_BUY;
        signal.entryPrice = currentAsk;
        signal.stopLoss = m_lastPattern.supportLevel - (m_config.breakoutBuffer * 3);
        signal.takeProfit = m_lastPattern.targetPrice;
        signal.signalReason = "Early entry on " + m_triangleDetector.GetPatternTypeString() + " triangle (pre-breakout)";
        signal.breakoutConfirmed = false;
        signal.isValid = true;
        signal.signalTime = TimeCurrent();
        signal.volumeConfirmation = CalculateVolumeConfirmation();
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Calculate Volume Confirmation                                   |
//+------------------------------------------------------------------+
double CGrandeTriangleTradingRules::CalculateVolumeConfirmation()
{
    long volumes[];
    if(CopyTickVolume(m_symbol, Period(), 0, m_config.volumeLookbackBars, volumes) != m_config.volumeLookbackBars)
    {
        return 1.0; // Default if volume data unavailable
    }
    
    // Calculate average volume for the period
    long totalVolume = 0;
    for(int i = 0; i < ArraySize(volumes); i++)
    {
        totalVolume += volumes[i];
    }
    double avgVolume = (double)totalVolume / ArraySize(volumes);
    
    // Get current volume
    long currentVolume = volumes[0]; // Most recent bar
    
    // Return volume ratio
    return avgVolume > 0 ? (double)currentVolume / avgVolume : 1.0;
}

//+------------------------------------------------------------------+
//| Validate Risk:Reward Ratio                                      |
//+------------------------------------------------------------------+
bool CGrandeTriangleTradingRules::ValidateRiskReward()
{
    if(!m_currentSignal.isValid) return false;
    
    double risk = MathAbs(m_currentSignal.stopLoss - m_currentSignal.entryPrice);
    double reward = MathAbs(m_currentSignal.takeProfit - m_currentSignal.entryPrice);
    
    if(risk <= 0) return false;
    
    double ratio = reward / risk;
    return ratio >= m_config.riskRewardRatio;
}

//+------------------------------------------------------------------+
//| Update Signal Strength                                          |
//+------------------------------------------------------------------+
void CGrandeTriangleTradingRules::UpdateSignalStrength()
{
    if(!m_currentSignal.isValid) return;
    
    double strength = 0.0;
    
    // Base strength from pattern confidence
    strength += m_lastPattern.confidence * 0.3;
    
    // Breakout probability contribution
    strength += m_lastPattern.breakoutProbability * 0.3;
    
    // Volume confirmation contribution
    double volumeStrength = MathMin(1.0, m_currentSignal.volumeConfirmation / 2.0);
    strength += volumeStrength * 0.2;
    
    // Risk:reward ratio contribution
    double risk = MathAbs(m_currentSignal.stopLoss - m_currentSignal.entryPrice);
    double reward = MathAbs(m_currentSignal.takeProfit - m_currentSignal.entryPrice);
    if(risk > 0)
    {
        double rrRatio = reward / risk;
        double rrStrength = MathMin(1.0, rrRatio / m_config.riskRewardRatio);
        strength += rrStrength * 0.2;
    }
    
    m_currentSignal.signalStrength = MathMin(1.0, strength);
}

//+------------------------------------------------------------------+
//| Calculate Risk Amount                                           |
//+------------------------------------------------------------------+
double CGrandeTriangleTradingRules::CalculateRiskAmount(double accountBalance)
{
    return accountBalance * (m_config.maxRiskPercent / 100.0);
}

//+------------------------------------------------------------------+
//| Calculate Position Size                                         |
//+------------------------------------------------------------------+
double CGrandeTriangleTradingRules::CalculatePositionSize(double accountBalance, double riskAmount)
{
    if(!m_currentSignal.isValid) return 0.0;
    
    double riskPips = MathAbs(m_currentSignal.stopLoss - m_currentSignal.entryPrice) / _Point;
    if(riskPips <= 0) return 0.0;
    
    double pipValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotSize = riskAmount / (riskPips * pipValue);
    
    // Apply position size multiplier
    lotSize *= m_config.positionSizeMultiplier;
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Validate Trade Setup                                            |
//+------------------------------------------------------------------+
bool CGrandeTriangleTradingRules::ValidateTradeSetup()
{
    if(!m_currentSignal.isValid) return false;
    
    // Check if signal is recent (within last 5 minutes)
    if(TimeCurrent() - m_currentSignal.signalTime > 300)
    {
        return false;
    }
    
    // Check if price hasn't moved too far from entry
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double priceDistance = MathAbs(currentPrice - m_currentSignal.entryPrice);
    double maxDistance = m_config.breakoutBuffer * 3;
    
    if(priceDistance > maxDistance)
    {
        return false;
    }
    
    // Check risk:reward ratio
    return ValidateRiskReward();
}

//+------------------------------------------------------------------+
//| Public Methods                                                   |
//+------------------------------------------------------------------+
STrianglePattern CGrandeTriangleTradingRules::GetCurrentPattern() const
{
    return m_lastPattern;
}

double CGrandeTriangleTradingRules::GetPatternConfidence() const
{
    return m_lastPattern.confidence;
}

double CGrandeTriangleTradingRules::GetBreakoutProbability() const
{
    return m_lastPattern.breakoutProbability;
}

void CGrandeTriangleTradingRules::ResetSignal()
{
    ZeroMemory(m_currentSignal);
    m_currentSignal.isValid = false;
    m_signalActive = false;
    m_lastSignalTime = 0;
}

string CGrandeTriangleTradingRules::GetSignalTypeString() const
{
    if(!m_currentSignal.isValid) return "NONE";
    
    switch(m_currentSignal.orderType)
    {
        case ORDER_TYPE_BUY:  return "BUY";
        case ORDER_TYPE_SELL: return "SELL";
        default:              return "UNKNOWN";
    }
}

void CGrandeTriangleTradingRules::LogSignalInfo()
{
    if(!m_currentSignal.isValid) return;
    
    Print("🎯 TRIANGLE TRADING SIGNAL GENERATED:");
    Print("   Type: ", GetSignalTypeString());
    Print("   Pattern: ", m_triangleDetector.GetPatternTypeString());
    Print("   Entry: ", DoubleToString(m_currentSignal.entryPrice, _Digits));
    Print("   Stop Loss: ", DoubleToString(m_currentSignal.stopLoss, _Digits));
    Print("   Take Profit: ", DoubleToString(m_currentSignal.takeProfit, _Digits));
    Print("   Signal Strength: ", DoubleToString(m_currentSignal.signalStrength * 100, 1), "%");
    Print("   Pattern Confidence: ", DoubleToString(m_lastPattern.confidence * 100, 1), "%");
    Print("   Breakout Probability: ", DoubleToString(m_lastPattern.breakoutProbability * 100, 1), "%");
    Print("   Volume Confirmation: ", DoubleToString(m_currentSignal.volumeConfirmation, 2));
    Print("   Breakout Confirmed: ", m_currentSignal.breakoutConfirmed ? "YES" : "NO");
    Print("   Reason: ", m_currentSignal.signalReason);
}
