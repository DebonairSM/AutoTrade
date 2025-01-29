//+------------------------------------------------------------------+
//|                                              V-2-EA-Breakouts.mqh |
//|                                    Breakout Strategy Implementation|
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.00"

// Include required files
#include <Trade\Trade.mqh>
#include "V-2-EA-Utils.mqh"
#include "V-2-EA-MarketData.mqh"

//+------------------------------------------------------------------+
//| Breakout Strategy Class                                            |
//+------------------------------------------------------------------+
class CV2EABreakouts
{
private:
    // Core handles and objects
    int           m_handleATR;         // ATR indicator handle
    CTrade        m_trade;             // Trading object
    
    // Strategy parameters from main EA
    int           m_atrPeriod;         // ATR period
    double        m_slMultiplier;      // Stop loss multiplier
    double        m_tpMultiplier;      // Take profit multiplier
    double        m_riskPercentage;    // Risk per trade
    bool          m_showDebugPrints;   // Debug mode
    int           m_magicNumber;       // Magic number for trade identification
    
    // Session control
    bool          m_restrictTradingHours;
    int           m_londonOpenHour;
    int           m_londonCloseHour;
    int           m_newYorkOpenHour;
    int           m_newYorkCloseHour;
    int           m_brokerToLocalOffsetHours;
    
    // State variables
    bool          m_initialized;
    bool          m_hasPositionOpen;
    datetime      m_lastBarTime;
    int           m_lastBarIndex;
    
    // Performance monitoring
    ulong         m_tickCount;
    ulong         m_calculationCount;
    double        m_maxTickTime;
    double        m_avgTickTime;
    double        m_totalTickTime;

public:
    //--- Constructor and destructor
    CV2EABreakouts(void);
   ~CV2EABreakouts(void);
   
    //--- Initialization and deinitialization
    bool          Init(int magicNumber, int atrPeriod, double slMultiplier, 
                      double tpMultiplier, double riskPercentage, bool showDebugPrints);
    void          Deinit(void);
    
    //--- Main strategy methods
    void          ProcessTick(void);
    bool          IsTradeAllowed(void);
    
    //--- Setters for session control
    void          SetSessionControl(bool restrictHours, int londonOpen, int londonClose,
                                  int nyOpen, int nyClose, int brokerOffset)
    {
        CV2EAUtils::SetSessionControl(restrictHours, londonOpen, londonClose,
                                    nyOpen, nyClose, brokerOffset);
    }
    
    //--- Getters for strategy state
    bool          HasOpenPosition(void) const { return m_hasPositionOpen; }
    ulong         GetTickCount(void) const { return m_tickCount; }
    double        GetAvgProcessingTime(void) const { return m_avgTickTime; }

private:
    //--- Internal helper methods
    bool          ValidateParameters(void);
    bool          InitIndicators(void);
    void          UpdateState(void);
    bool          CheckNewBar(void);
    void          ExecuteBreakoutStrategy(void);
    bool          ApplyDailyPivotSLTP(bool isBullish, double &entryPrice, double &slPrice, double &tpPrice);
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CV2EABreakouts::CV2EABreakouts(void) : m_initialized(false),
                                       m_handleATR(INVALID_HANDLE),
                                       m_hasPositionOpen(false),
                                       m_lastBarTime(0),
                                       m_lastBarIndex(-1),
                                       m_tickCount(0),
                                       m_calculationCount(0),
                                       m_maxTickTime(0.0),
                                       m_avgTickTime(0.0),
                                       m_totalTickTime(0.0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                         |
//+------------------------------------------------------------------+
CV2EABreakouts::~CV2EABreakouts(void)
{
    Deinit();
}

//+------------------------------------------------------------------+
//| Initialize the strategy                                            |
//+------------------------------------------------------------------+
bool CV2EABreakouts::Init(int magicNumber, int atrPeriod, double slMultiplier, 
                         double tpMultiplier, double riskPercentage, bool showDebugPrints)
{
    // Store parameters
    m_magicNumber = magicNumber;
    m_atrPeriod = atrPeriod;
    m_slMultiplier = slMultiplier;
    m_tpMultiplier = tpMultiplier;
    m_riskPercentage = riskPercentage;
    m_showDebugPrints = showDebugPrints;
    
    // Initialize utils and market data
    CV2EAUtils::Init(showDebugPrints);
    CV2EAUtils::SetMagicNumber(magicNumber);
    CV2EAMarketData::Init(showDebugPrints);
    
    // Validate parameters
    if(!ValidateParameters())
        return false;
        
    // Initialize indicators
    if(!InitIndicators())
        return false;
        
    // Set trade object parameters
    m_trade.SetExpertMagicNumber(m_magicNumber);
    
    m_initialized = true;
    if(m_showDebugPrints)
        Print("✅ [V-2-EA-Breakouts] Strategy initialized successfully");
        
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize the strategy                                         |
//+------------------------------------------------------------------+
void CV2EABreakouts::Deinit(void)
{
    if(m_handleATR != INVALID_HANDLE)
    {
        IndicatorRelease(m_handleATR);
        m_handleATR = INVALID_HANDLE;
    }
    m_initialized = false;
}

//+------------------------------------------------------------------+
//| Validate strategy parameters                                       |
//+------------------------------------------------------------------+
bool CV2EABreakouts::ValidateParameters(void)
{
    if(m_atrPeriod <= 0)
    {
        if(m_showDebugPrints)
            Print("❌ [V-2-EA-Breakouts] Invalid ATR period");
        return false;
    }
    
    if(m_slMultiplier <= 0 || m_tpMultiplier <= 0)
    {
        if(m_showDebugPrints)
            Print("❌ [V-2-EA-Breakouts] Invalid SL/TP multipliers");
        return false;
    }
    
    if(m_riskPercentage <= 0 || m_riskPercentage > 5)
    {
        if(m_showDebugPrints)
            Print("❌ [V-2-EA-Breakouts] Invalid risk percentage");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize required indicators                                     |
//+------------------------------------------------------------------+
bool CV2EABreakouts::InitIndicators(void)
{
    // Initialize ATR
    m_handleATR = iATR(_Symbol, PERIOD_CURRENT, m_atrPeriod);
    if(m_handleATR == INVALID_HANDLE)
    {
        if(m_showDebugPrints)
            Print("❌ [V-2-EA-Breakouts] Failed to create ATR indicator");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Process new tick                                                  |
//+------------------------------------------------------------------+
void CV2EABreakouts::ProcessTick(void)
{
    if(!m_initialized)
        return;
        
    ulong startTime = GetTickCount64();
    m_tickCount++;
    
    UpdateState();
    
    if(CheckNewBar())
    {
        ExecuteBreakoutStrategy();
        m_calculationCount++;
    }
    
    // Performance monitoring
    ulong endTime = GetTickCount64();
    double tickTime = (endTime - startTime) / 1000.0;
    m_totalTickTime += tickTime;
    m_avgTickTime = m_totalTickTime / m_tickCount;
    
    if(tickTime > m_maxTickTime)
        m_maxTickTime = tickTime;
        
    if(m_showDebugPrints && m_tickCount % 1000 == 0)
    {
        Print("📊 [V-2-EA-Breakouts] Performance Metrics:");
        Print("   Ticks Processed: ", m_tickCount);
        Print("   Calculations: ", m_calculationCount);
        Print("   Average Time: ", DoubleToString(m_avgTickTime, 6), " sec");
        Print("   Max Time: ", DoubleToString(m_maxTickTime, 6), " sec");
    }
}

//+------------------------------------------------------------------+
//| Update strategy state                                             |
//+------------------------------------------------------------------+
void CV2EABreakouts::UpdateState(void)
{
    // Update bar tracking
    CheckNewBar();
    
    // Update position state
    m_hasPositionOpen = CV2EAUtils::HasOpenPosition(_Symbol, m_magicNumber);
}

//+------------------------------------------------------------------+
//| Check for new bar                                                 |
//+------------------------------------------------------------------+
bool CV2EABreakouts::CheckNewBar(void)
{
    return CV2EAUtils::CheckNewBar(_Symbol, PERIOD_CURRENT, m_lastBarTime, m_lastBarIndex);
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                       |
//+------------------------------------------------------------------+
bool CV2EABreakouts::IsTradeAllowed(void)
{
    return CV2EAUtils::IsTradeAllowed();
}

//+------------------------------------------------------------------+
//| Apply pivot-based SL/TP                                            |
//+------------------------------------------------------------------+
bool CV2EABreakouts::ApplyDailyPivotSLTP(bool isBullish, double &entryPrice, double &slPrice, double &tpPrice)
{
    double pivot=0, r1=0, r2=0, s1=0, s2=0;
    if(!CV2EAMarketData::GetDailyPivotPoints(_Symbol, pivot, r1, r2, s1, s2))
    {
        if(m_showDebugPrints)
            Print("❌ [ApplyDailyPivotSLTP] Using fallback because pivot retrieval failed.");
        return false;
    }

    // Strategy-specific logic for using pivot points
    double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    if(isBullish)
    {
        slPrice = MathMin(s1, entryPrice - (m_slMultiplier * 50 * pointSize));
        tpPrice = MathMax(r1, entryPrice + (m_tpMultiplier * 50 * pointSize));
    }
    else
    {
        slPrice = MathMax(r1, entryPrice + (m_slMultiplier * 50 * pointSize));
        tpPrice = MathMin(s1, entryPrice - (m_tpMultiplier * 50 * pointSize));
    }

    return true;
}

//+------------------------------------------------------------------+
//| Execute breakout strategy                                          |
//+------------------------------------------------------------------+
void CV2EABreakouts::ExecuteBreakoutStrategy(void)
{
    if(!m_initialized || !IsTradeAllowed() || m_hasPositionOpen)
        return;
        
    // Get ATR using market data class
    double atr = CV2EAMarketData::GetATR(_Symbol, PERIOD_CURRENT, m_atrPeriod);
    if(atr <= 0)
        return;
        
    double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
    double low = iLow(_Symbol, PERIOD_CURRENT, 1);
    double close = iClose(_Symbol, PERIOD_CURRENT, 1);
    
    double stopLoss = m_slMultiplier * atr;
    double takeProfit = m_tpMultiplier * atr;
    
    // Buy condition
    if(close > high)
    {
        double sl = NormalizeDouble(close - stopLoss, _Digits);
        double tp = NormalizeDouble(close + takeProfit, _Digits);
        
        // Try to apply pivot-based SL/TP adjustments
        double pivotSL = sl, pivotTP = tp;
        if(ApplyDailyPivotSLTP(true, close, pivotSL, pivotTP))
        {
            sl = pivotSL;  // Use pivot-adjusted stop loss
            tp = pivotTP;  // Use pivot-adjusted take profit
        }
        
        double lotSize = CV2EAUtils::CalculateLotSize(sl, close, m_riskPercentage, _Symbol);
        
        if(lotSize > 0)
        {
            CV2EAUtils::PlaceTrade(true, close, sl, tp, lotSize, _Symbol, "V2EA Breakout Buy");
        }
    }
    // Sell condition
    else if(close < low)
    {
        double sl = NormalizeDouble(close + stopLoss, _Digits);
        double tp = NormalizeDouble(close - takeProfit, _Digits);
        
        // Try to apply pivot-based SL/TP adjustments
        double pivotSL = sl, pivotTP = tp;
        if(ApplyDailyPivotSLTP(false, close, pivotSL, pivotTP))
        {
            sl = pivotSL;  // Use pivot-adjusted stop loss
            tp = pivotTP;  // Use pivot-adjusted take profit
        }
        
        double lotSize = CV2EAUtils::CalculateLotSize(sl, close, m_riskPercentage, _Symbol);
        
        if(lotSize > 0)
        {
            CV2EAUtils::PlaceTrade(false, close, sl, tp, lotSize, _Symbol, "V2EA Breakout Sell");
        }
    }
}

// Example of how to use utils in strategy code (add this as a comment for reference)
/*
void CV2EABreakouts::ExecuteBreakoutTrade(bool isBullish, double entryPrice)
{
    double slPrice = 0, tpPrice = 0;
    
    // Get SL/TP levels
    if(!ApplyDailyPivotSLTP(isBullish, entryPrice, slPrice, tpPrice))
        return;
        
    // Calculate position size
    double lots = CV2EAUtils::CalculateLotSize(slPrice, entryPrice, m_riskPercentage);
    if(lots <= 0)
        return;
        
    // Place the trade
    CV2EAUtils::PlaceTrade(isBullish, entryPrice, slPrice, tpPrice, lots);
}
*/ 