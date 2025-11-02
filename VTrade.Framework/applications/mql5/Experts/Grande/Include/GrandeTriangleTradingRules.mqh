//+------------------------------------------------------------------+
//| GrandeTriangleTradingRules.mqh                                   |
//| Copyright 2024, Grande Tech                                      |
//| Trading Rules and Signal Generation for Triangle Patterns       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"

#include "GrandeTrianglePatternDetector.mqh"

//+------------------------------------------------------------------+
//| Configuration Structures                                          |
//+------------------------------------------------------------------+
struct TriangleTradingConfig
{
    double    minConfidence;         // Minimum pattern confidence
    double    minBreakoutProb;       // Minimum breakout probability
    bool      requireVolume;         // Require volume confirmation
    bool      requireVolumeConfirm;  // Alias for requireVolume
    double    riskPercent;           // Risk percentage per trade
    double    maxRiskPercent;        // Alias for riskPercent
    bool      allowEarlyEntry;       // Allow entry before breakout
    double    slATRMultiplier;       // Stop loss ATR multiplier
    double    tpRewardRatio;         // Take profit reward ratio
};

enum SIGNAL_TYPE
{
    SIGNAL_NONE,
    SIGNAL_BUY,
    SIGNAL_SELL
};

struct STriangleSignal
{
    bool               isValid;              // Signal validity
    SIGNAL_TYPE        type;                 // Buy or Sell
    ENUM_ORDER_TYPE    orderType;            // Order type (ORDER_TYPE_BUY or ORDER_TYPE_SELL)
    double             entryPrice;           // Entry price
    double             stopLoss;             // Stop loss price
    double             takeProfit;           // Take profit price
    double             signalStrength;       // Signal strength (0-1)
    string             signalReason;         // Reason for signal
    bool               breakoutConfirmed;    // Breakout confirmed flag
    TRIANGLE_TYPE      patternType;          // Triangle pattern type
    BREAKOUT_DIRECTION breakoutDirection;    // Expected breakout direction
};

//+------------------------------------------------------------------+
//| Triangle Trading Rules Class                                     |
//+------------------------------------------------------------------+
class CGrandeTriangleTradingRules
{
private:
    string                  m_symbol;
    ENUM_TIMEFRAMES         m_timeframe;
    TriangleTradingConfig   m_config;
    STriangleSignal         m_lastSignal;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CGrandeTriangleTradingRules()
    {
        m_symbol = _Symbol;
        m_timeframe = _Period;
        ResetSignal();
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                        |
    //+------------------------------------------------------------------+
    ~CGrandeTriangleTradingRules()
    {
    }
    
    //+------------------------------------------------------------------+
    //| Initialize trading rules                                          |
    //+------------------------------------------------------------------+
    bool Initialize(const string symbol, const TriangleTradingConfig &config)
    {
        m_symbol = symbol;
        m_config = config;
        
        // Set defaults if not configured
        if(m_config.minConfidence <= 0)
            m_config.minConfidence = 0.6;
        if(m_config.minBreakoutProb <= 0)
            m_config.minBreakoutProb = 0.6;
        if(m_config.riskPercent <= 0)
            m_config.riskPercent = 2.0;
        if(m_config.slATRMultiplier <= 0)
            m_config.slATRMultiplier = 1.8;
        if(m_config.tpRewardRatio <= 0)
            m_config.tpRewardRatio = 3.0;
            
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Reset signal to empty state                                      |
    //+------------------------------------------------------------------+
    void ResetSignal()
    {
        m_lastSignal.isValid = false;
        m_lastSignal.type = SIGNAL_NONE;
        m_lastSignal.orderType = ORDER_TYPE_BUY;
        m_lastSignal.entryPrice = 0.0;
        m_lastSignal.stopLoss = 0.0;
        m_lastSignal.takeProfit = 0.0;
        m_lastSignal.signalStrength = 0.0;
        m_lastSignal.signalReason = "";
        m_lastSignal.breakoutConfirmed = false;
        m_lastSignal.patternType = TRIANGLE_NONE;
        m_lastSignal.breakoutDirection = BREAKOUT_NONE;
    }
    
    //+------------------------------------------------------------------+
    //| Generate trading signal                                           |
    //+------------------------------------------------------------------+
    STriangleSignal GenerateSignal()
    {
        // Stub implementation - returns invalid signal
        // TODO: Implement actual signal generation logic
        ResetSignal();
        return m_lastSignal;
    }
    
    //+------------------------------------------------------------------+
    //| Validate trade setup                                             |
    //+------------------------------------------------------------------+
    bool ValidateTradeSetup()
    {
        // Stub implementation - basic validation
        if(!m_lastSignal.isValid)
            return false;
            
        if(m_lastSignal.type == SIGNAL_NONE)
            return false;
            
        if(m_lastSignal.entryPrice <= 0)
            return false;
            
        if(m_lastSignal.stopLoss <= 0)
            return false;
            
        if(m_lastSignal.takeProfit <= 0)
            return false;
            
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate risk amount                                            |
    //+------------------------------------------------------------------+
    double CalculateRiskAmount(double accountBalance)
    {
        if(accountBalance <= 0)
            return 0.0;
            
        return accountBalance * (m_config.riskPercent / 100.0);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate position size                                          |
    //+------------------------------------------------------------------+
    double CalculatePositionSize(double accountBalance, double riskAmount)
    {
        if(!m_lastSignal.isValid || riskAmount <= 0)
            return 0.0;
            
        double stopDistance = MathAbs(m_lastSignal.entryPrice - m_lastSignal.stopLoss);
        if(stopDistance <= 0)
            return 0.0;
            
        // Basic position sizing: Risk / Stop Distance
        double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
        double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
        
        if(tickValue == 0 || tickSize == 0)
            return minLot;
            
        double lotSize = (riskAmount * tickSize) / (stopDistance * tickValue);
        
        // Normalize lot size
        lotSize = MathFloor(lotSize / lotStep) * lotStep;
        lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
        
        return lotSize;
    }
    
    //+------------------------------------------------------------------+
    //| Get signal type as string                                        |
    //+------------------------------------------------------------------+
    string GetSignalTypeString() const
    {
        switch(m_lastSignal.type)
        {
            case SIGNAL_BUY:  return "BUY";
            case SIGNAL_SELL: return "SELL";
            default:          return "NONE";
        }
    }
    
    //+------------------------------------------------------------------+
    //| Get last signal                                                   |
    //+------------------------------------------------------------------+
    STriangleSignal GetLastSignal() const
    {
        return m_lastSignal;
    }
};

