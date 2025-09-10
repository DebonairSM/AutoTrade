//+------------------------------------------------------------------+
//| GrandeRiskManager.mqh                                            |
//| Copyright 2024, Grande Tech                                      |
//| Advanced Risk Management & Position Sizing System               |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Official MQL5 Expert Advisor risk management patterns

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Advanced risk management and position sizing system for Grande Trading"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Risk Management Configuration                                    |
//+------------------------------------------------------------------+
struct RiskConfig
{
    // === Position Sizing ===
    double risk_percent_trend;      // Risk % for trend trades
    double risk_percent_range;      // Risk % for range trades  
    double risk_percent_breakout;   // Risk % for breakout trades
    double max_risk_per_trade;      // Maximum risk % per trade
    
    // === Stop Loss & Take Profit ===
    double sl_atr_multiplier;       // Stop loss ATR multiplier
    double tp_reward_ratio;         // Take profit reward ratio (R:R)
    double breakeven_atr;           // Move to breakeven after X ATR
    double partial_close_atr;       // Partial close after X ATR
    
    // === Drawdown Protection ===
    double max_drawdown_percent;    // Maximum account drawdown %
    double equity_peak_reset;       // Reset peak after X% recovery
    
    // === Position Management ===
    int max_positions;              // Maximum concurrent positions
    bool enable_trailing_stop;      // Enable trailing stops
    double trailing_atr_multiplier; // Trailing stop ATR multiplier
    
    // === Advanced Features ===
    bool enable_partial_closes;     // Enable partial profit taking
    double partial_close_percent;   // % of position to close
    bool enable_breakeven;          // Enable breakeven stops
    double breakeven_buffer;        // Buffer above breakeven

    // === Management Coordination ===
    ENUM_TIMEFRAMES management_timeframe; // Only manage on this timeframe (if enabled)
    bool manage_only_on_timeframe;        // Gate management to selected timeframe

    // === Modify Dampening ===
    double min_modify_pips;               // Minimum pips change to modify SL/TP
    double min_modify_atr_fraction;       // Or fraction of ATR to consider material change
    int    min_modify_cooldown_sec;       // Per-ticket cooldown between SL/TP modifies
};

//+------------------------------------------------------------------+
//| Position Information Structure                                   |
//+------------------------------------------------------------------+
struct PositionInfo
{
    ulong ticket;                   // Position ticket
    string symbol;                  // Symbol
    ENUM_POSITION_TYPE type;        // Position type
    double volume;                  // Position volume
    double price_open;              // Open price
    double price_current;           // Current price
    double stop_loss;               // Current stop loss
    double take_profit;             // Current take profit
    double profit;                  // Current profit
    datetime time_open;             // Open time
    bool breakeven_set;             // Breakeven stop set
    bool partial_closed;            // Partial close executed
    double atr_at_open;             // ATR at position open
    bool tp_lock;                   // Whether TP is locked from comment
    double tp_lock_price;           // Locked TP price parsed from comment
    datetime last_sltp_set_time;    // Last time SL/TP was successfully modified
};

//+------------------------------------------------------------------+
//| Grande Risk Manager Class                                       |
//+------------------------------------------------------------------+
class CGrandeRiskManager
{
private:
    // === Configuration ===
    RiskConfig m_config;
    bool m_isInitialized;
    string m_symbol;
    
    // === Account Tracking ===
    double m_equityPeak;
    datetime m_lastEquityPeakTime;
    bool m_tradingEnabled;
    
    // === Position Tracking ===
    PositionInfo m_positions[];
    int m_positionCount;
    
    // === ATR Calculation ===
    int m_atrHandle;
    double m_atrBuffer[];
    
    // === Handle Recreation Control ===
    datetime m_lastRecreationTime;
    int m_recreationAttempts;
    int m_rapidFailures;
    bool m_circuitBreakerActive;
    double m_lastValidATR;
    datetime m_lastValidATRTime;
    
    // === Trade Object ===
    CTrade m_trade;
    
    // === Helper Methods ===
    bool InitializeATR();
    bool EnsureATRHandle(int maxRetries, int delayMs);
    void UpdateEquityPeak();
    double CalculateATR();
    double CalculateATRFallback();
    double GetPipValue();
    void UpdatePositionInfo();
    bool IsPositionValid(const PositionInfo &pos);
    void LogRiskEvent(const string &event, const string &details);
    void LogRiskEvent(const string &event);
    
public:
    // === Constructor/Destructor ===
    CGrandeRiskManager();
    ~CGrandeRiskManager();
    
    // === Initialization ===
    bool Initialize(const string &symbol, const RiskConfig &config, bool debugMode = false);
    void Deinitialize();
    
    // === Position Sizing ===
    double CalculateLotSize(double stopDistancePips, MARKET_REGIME regime);
    double CalculateLotSizeByRisk(double riskAmount, double stopDistancePips);
    
    // === Stop Loss & Take Profit ===
    double CalculateStopLoss(bool isBuy, double entryPrice, double atrValue);
    double CalculateTakeProfit(bool isBuy, double entryPrice, double stopLoss);
    double CalculateStopDistance(double atrValue);
    
    // === Risk Management ===
    bool CheckDrawdown();
    bool CheckMaxPositions();
    double GetCurrentDrawdown();
    bool IsTradingEnabled() const { return m_tradingEnabled; }
    
    // === Position Management ===
    void OnTick();
    bool UpdateBreakevenStops();
    bool UpdateTrailingStops();
    bool ExecutePartialCloses();
    void CloseAllPositions();
    
    // === Smart Position Management ===
    void ManageAllPositions();
    bool SetIntelligentSLTP(ulong ticket, bool isBuy, double entryPrice);
    double CalculateSmartStopLoss(bool isBuy, double entryPrice, double atrValue);
    double CalculateSmartTakeProfit(bool isBuy, double entryPrice, double stopLoss, double atrValue);
    bool IsPositionManaged(ulong ticket);
    
    // === Position Information ===
    int GetPositionCount() const { return m_positionCount; }
    PositionInfo GetPosition(int index);
    double GetTotalProfit();
    double GetLargestPosition();
    
    // === Configuration ===
    void UpdateConfig(const RiskConfig &config);
    RiskConfig GetConfig() const { return m_config; }
    
    // === Utility Methods ===
    void ResetEquityPeak();
    void EnableTrading(bool enable) { m_tradingEnabled = enable; }
    void LogStatus();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandeRiskManager::CGrandeRiskManager()
{
    m_isInitialized = false;
    m_symbol = "";
    m_equityPeak = 0.0;
    m_lastEquityPeakTime = 0;
    m_tradingEnabled = true;
    m_positionCount = 0;
    m_atrHandle = INVALID_HANDLE;
    
    // Initialize circuit breaker variables
    m_lastRecreationTime = 0;
    m_recreationAttempts = 0;
    m_rapidFailures = 0;
    m_circuitBreakerActive = false;
    m_lastValidATR = 0.0;
    m_lastValidATRTime = 0;
    
    // Initialize trade object
    m_trade.SetExpertMagicNumber(123456);
    m_trade.SetDeviationInPoints(30);
    m_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    // Set default configuration
    m_config.risk_percent_trend = 2.0;
    m_config.risk_percent_range = 1.0;
    m_config.risk_percent_breakout = 3.0;
    m_config.max_risk_per_trade = 5.0;
    m_config.sl_atr_multiplier = 1.2;
    m_config.tp_reward_ratio = 3.0;
    m_config.breakeven_atr = 1.0;
    m_config.partial_close_atr = 2.0;
    m_config.max_drawdown_percent = 25.0;
    m_config.equity_peak_reset = 5.0;
    m_config.max_positions = 3;
    m_config.enable_trailing_stop = true;
    m_config.trailing_atr_multiplier = 0.8;
    m_config.enable_partial_closes = true;
    m_config.partial_close_percent = 50.0;
    m_config.enable_breakeven = true;
    m_config.breakeven_buffer = 0.5;
    // Management coordination defaults
    m_config.management_timeframe = PERIOD_H1;
    m_config.manage_only_on_timeframe = false;
    // Modify dampening defaults
    m_config.min_modify_pips = 5.0;
    m_config.min_modify_atr_fraction = 0.05;
    m_config.min_modify_cooldown_sec = 120;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CGrandeRiskManager::~CGrandeRiskManager()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize Risk Manager                                           |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::Initialize(const string &symbol, const RiskConfig &config, bool debugMode)
{
    if(m_isInitialized)
    {
        Print("[GrandeRisk] Already initialized");
        return true;
    }
    
    m_symbol = symbol;
    m_config = config;
    
    // Validate configuration
    if(m_config.risk_percent_trend <= 0 || m_config.risk_percent_trend > 10.0)
    {
        Print("[GrandeRisk] ERROR: Invalid risk_percent_trend: ", m_config.risk_percent_trend);
        return false;
    }
    
    if(m_config.max_drawdown_percent <= 0 || m_config.max_drawdown_percent > 50.0)
    {
        Print("[GrandeRisk] ERROR: Invalid max_drawdown_percent: ", m_config.max_drawdown_percent);
        return false;
    }
    
    // Initialize ATR
    if(!InitializeATR())
    {
        Print("[GrandeRisk] ERROR: Failed to initialize ATR");
        return false;
    }
    
    // Initialize equity peak
    m_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
    m_lastEquityPeakTime = TimeCurrent();
    
    // Initialize position tracking
    ArrayResize(m_positions, 0);
    m_positionCount = 0;
    
    m_isInitialized = true;
    m_tradingEnabled = true;
    
    if(debugMode)
    {
        Print("[GrandeRisk] Initialized successfully for ", m_symbol);
        Print("[GrandeRisk] Risk Config: Trend=", m_config.risk_percent_trend, 
              "%, Range=", m_config.risk_percent_range, 
              "%, Breakout=", m_config.risk_percent_breakout, "%");
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Risk Manager                                         |
//+------------------------------------------------------------------+
void CGrandeRiskManager::Deinitialize()
{
    if(!m_isInitialized) return;
    
    // Release ATR handle
    if(m_atrHandle != INVALID_HANDLE)
    {
        IndicatorRelease(m_atrHandle);
        m_atrHandle = INVALID_HANDLE;
    }
    
    // Clear position tracking
    ArrayResize(m_positions, 0);
    m_positionCount = 0;
    
    m_isInitialized = false;
    Print("[GrandeRisk] Deinitialized");
}

//+------------------------------------------------------------------+
//| Initialize ATR Indicator                                          |
//+------------------------------------------------------------------+
//| Ensure ATR Handle is Ready (MetaQuotes Pattern)                 |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::EnsureATRHandle(int maxRetries, int delayMs)
{
    // Pattern from: MetaQuotes Official Documentation
    // Reference: Proper indicator handle creation and validation
    
    // If no handle yet, or BarsCalculated shows it's invalid, create a new one
    if(m_atrHandle == INVALID_HANDLE || BarsCalculated(m_atrHandle) <= 0)
    {
        // Release any existing handle
        if(m_atrHandle != INVALID_HANDLE)
        {
            IndicatorRelease(m_atrHandle);
            m_atrHandle = INVALID_HANDLE;
        }
        
        // Validate symbol
        if(!SymbolSelect(m_symbol, true))
        {
            LogRiskEvent("ERROR", StringFormat("Symbol not available: %s", m_symbol));
            return false;
        }
        
        // Create new ATR handle
        ResetLastError();
        m_atrHandle = iATR(m_symbol, PERIOD_CURRENT, 14);
        int error = GetLastError();
        
        if(m_atrHandle == INVALID_HANDLE)
        {
            LogRiskEvent("ERROR", StringFormat("Failed to create ATR handle. Error: %d, Symbol: %s", error, m_symbol));
            return false;
        }
        
        // Wait until the indicator has calculated bars
        for(int i = 0; i < maxRetries; i++)
        {
            int bars = BarsCalculated(m_atrHandle);
            if(bars > 0)
            {
                ArraySetAsSeries(m_atrBuffer, true);
                if(InpLogDebugInfo)
                    Print("[GrandeRisk] ATR handle ready. Calculated bars: ", bars, ", Symbol: ", m_symbol);
                return true;
            }
            
            if(InpLogDebugInfo && i == 0)
                Print("[GrandeRisk] Waiting for ATR to calculate. Attempt ", (i+1), "/", maxRetries, ", Bars: ", bars);
            
            Sleep(delayMs);
        }
        
        // Still not ready; release and mark invalid
        LogRiskEvent("ERROR", StringFormat("ATR handle invalid after %d retries. Symbol: %s", maxRetries, m_symbol));
        IndicatorRelease(m_atrHandle);
        m_atrHandle = INVALID_HANDLE;
        return false;
    }
    
    return true; // Handle already exists and is valid
}

//+------------------------------------------------------------------+
//| Initialize ATR (Simplified)                                      |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::InitializeATR()
{
    // Simply ensure the ATR handle is ready
    return EnsureATRHandle(10, 200); // More retries and longer delay during initialization
}

//+------------------------------------------------------------------+
//| Calculate Position Size Based on Risk                            |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateLotSize(double stopDistancePips, MARKET_REGIME regime)
{
    if(!m_isInitialized) return 0.0;
    
    // Determine risk percentage based on regime
    double riskPercent = m_config.risk_percent_trend; // Default
    
    switch(regime)
    {
        case REGIME_TREND_BULL:
        case REGIME_TREND_BEAR:
            riskPercent = m_config.risk_percent_trend;
            break;
        case REGIME_RANGING:
            riskPercent = m_config.risk_percent_range;
            break;
        case REGIME_BREAKOUT_SETUP:
            riskPercent = m_config.risk_percent_breakout;
            break;
        default:
            riskPercent = m_config.risk_percent_trend;
            break;
    }
    
    // Cap risk percentage
    riskPercent = MathMin(riskPercent, m_config.max_risk_per_trade);
    
    // Calculate risk amount
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = equity * riskPercent / 100.0;
    
    return CalculateLotSizeByRisk(riskAmount, stopDistancePips);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size by Risk Amount                                |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateLotSizeByRisk(double riskAmount, double stopDistancePips)
{
    if(stopDistancePips <= 0) return 0.0;
    
    // Get pip value
    double pipValue = GetPipValue();
    if(pipValue <= 0) return 0.0;
    
    // Calculate lot size
    double lotSize = riskAmount / (stopDistancePips * pipValue);
    
    // Get broker volume requirements
    double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    // Validate broker requirements
    if(minLot <= 0 || maxLot <= 0 || lotStep <= 0)
    {
        LogRiskEvent("ERROR", StringFormat("Invalid broker volume settings. Min: %.5f, Max: %.5f, Step: %.5f", 
                      minLot, maxLot, lotStep));
        return 0.0;
    }
    
    // Normalize lot size
    lotSize = MathMax(lotSize, minLot);
    lotSize = MathMin(lotSize, maxLot);
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
    
    // Final validation
    if(lotSize < minLot || lotSize > maxLot)
    {
        LogRiskEvent("ERROR", StringFormat("Lot size %.5f outside valid range [%.5f, %.5f]", 
                      lotSize, minLot, maxLot));
        return 0.0;
    }
    
    if(InpLogDebugInfo)
        LogRiskEvent("INFO", StringFormat("Calculated lot size: %.5f (Risk: %.2f, Stop: %.1f pips)", 
                      lotSize, riskAmount, stopDistancePips));
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss Price                                         |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateStopLoss(bool isBuy, double entryPrice, double atrValue)
{
    double stopDistance = CalculateStopDistance(atrValue);
    
    if(isBuy)
        return entryPrice - stopDistance;
    else
        return entryPrice + stopDistance;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit Price                                       |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateTakeProfit(bool isBuy, double entryPrice, double stopLoss)
{
    double stopDistance = MathAbs(entryPrice - stopLoss);
    double takeProfitDistance = stopDistance * m_config.tp_reward_ratio;
    
    if(isBuy)
        return entryPrice + takeProfitDistance;
    else
        return entryPrice - takeProfitDistance;
}

//+------------------------------------------------------------------+
//| Calculate Stop Distance                                           |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateStopDistance(double atrValue)
{
    return atrValue * m_config.sl_atr_multiplier;
}

//+------------------------------------------------------------------+
//| Check Maximum Drawdown                                            |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::CheckDrawdown()
{
    if(!m_isInitialized) return false;
    
    UpdateEquityPeak();
    
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double drawdown = 100.0 * (m_equityPeak - currentEquity) / m_equityPeak;
    
    if(drawdown > m_config.max_drawdown_percent)
    {
        if(m_tradingEnabled)
        {
            m_tradingEnabled = false;
            LogRiskEvent("DRAWDOWN_LIMIT", StringFormat("Drawdown %.2f%% exceeds limit %.2f%%", 
                       drawdown, m_config.max_drawdown_percent));
        }
        return false;
    }
    
    // Reset peak if recovered
    if(currentEquity > m_equityPeak * (1.0 + m_config.equity_peak_reset / 100.0))
    {
        ResetEquityPeak();
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Maximum Positions                                           |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::CheckMaxPositions()
{
    if(!m_isInitialized) return false;
    
    UpdatePositionInfo();
    
    if(m_positionCount >= m_config.max_positions)
    {
        LogRiskEvent("MAX_POSITIONS", StringFormat("Position count %d exceeds limit %d", 
                   m_positionCount, m_config.max_positions));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get Current Drawdown                                              |
//+------------------------------------------------------------------+
double CGrandeRiskManager::GetCurrentDrawdown()
{
    if(!m_isInitialized) return 0.0;
    
    UpdateEquityPeak();
    
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    return 100.0 * (m_equityPeak - currentEquity) / m_equityPeak;
}

//+------------------------------------------------------------------+
//| Update Equity Peak                                                |
//+------------------------------------------------------------------+
void CGrandeRiskManager::UpdateEquityPeak()
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    if(currentEquity > m_equityPeak)
    {
        m_equityPeak = currentEquity;
        m_lastEquityPeakTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Reset Equity Peak                                                 |
//+------------------------------------------------------------------+
void CGrandeRiskManager::ResetEquityPeak()
{
    m_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
    m_lastEquityPeakTime = TimeCurrent();
    LogRiskEvent("EQUITY_PEAK_RESET", StringFormat("New peak: %.2f", m_equityPeak));
}

//+------------------------------------------------------------------+
//| OnTick Processing                                                 |
//+------------------------------------------------------------------+
void CGrandeRiskManager::OnTick()
{
    if(!m_isInitialized) return;
    
    // Optional management timeframe gate to reduce churn across multi-timeframe charts
    if(m_config.manage_only_on_timeframe)
    {
        if(Period() != m_config.management_timeframe)
            return;
    }

    ResetLastError();
    
    // Update position information
    UpdatePositionInfo();
    
    int error = GetLastError();
    if(error != 0)
    {
        Print("[GrandeRisk] ERROR: UpdatePositionInfo failed. Error: ", error);
        return;
    }
    
    // Check drawdown
    CheckDrawdown();
    
    error = GetLastError();
    if(error != 0)
    {
        Print("[GrandeRisk] ERROR: CheckDrawdown failed. Error: ", error);
        return;
    }
    
            // Update position management features
        if(m_tradingEnabled)
        {
            // Check if ATR is available before attempting position management
            double atrValue = CalculateATR();
            if(atrValue <= 0)
            {
                if(InpLogDebugInfo)
                    Print("[GrandeRisk] WARNING: ATR unavailable, skipping position management features");
                return; // Skip position management but don't fail completely
            }
            
            // Only proceed with position management if we have a valid ATR value
            if(atrValue > 0)
            {
                // Smart Position Management - Set SL/TP for all open positions
                // Rate limiting: only attempt position management every 10 seconds
                static datetime lastPositionManagement = 0;
                if(TimeCurrent() - lastPositionManagement >= 60)
                {
                    // Rely on internal logging within ManageAllPositions; avoid GetLastError-based warnings
                    ManageAllPositions();
                    
                    lastPositionManagement = TimeCurrent();
                }
                
            if(m_config.enable_breakeven)
            {
                // Rate limiting: only attempt breakeven updates every 5 seconds
                static datetime lastBreakevenAttempt = 0;
                if(TimeCurrent() - lastBreakevenAttempt >= 15)
                {
                    // Rely on internal logging within UpdateBreakevenStops.
                    // Do not use GetLastError() for trade modify outcomes here to avoid spurious warnings.
                    UpdateBreakevenStops();
                    
                    lastBreakevenAttempt = TimeCurrent();
                }
            }
                
            if(m_config.enable_trailing_stop)
            {
                // Rate limiting: only attempt trailing stop updates every 3 seconds
                static datetime lastTrailingAttempt = 0;
                if(TimeCurrent() - lastTrailingAttempt >= 10)
                {
                    ResetLastError();
                    UpdateTrailingStops();
                    error = GetLastError();
                    if(error != 0)
                        Print("[GrandeRisk] WARNING: UpdateTrailingStops failed. Error: ", error);
                    
                    lastTrailingAttempt = TimeCurrent();
                }
            }
                
            if(m_config.enable_partial_closes)
            {
                // Only attempt partial closes if we have positions that could benefit
                bool shouldAttemptPartial = false;
                for(int i = 0; i < m_positionCount; i++)
                {
                    if(!m_positions[i].partial_closed)
                    {
                        double potentialCloseVolume = m_positions[i].volume * m_config.partial_close_percent / 100.0;
                        double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
                        if(potentialCloseVolume >= minLot)
                        {
                            shouldAttemptPartial = true;
                            break;
                        }
                    }
                }
                
                if(shouldAttemptPartial)
                {
                    ResetLastError();
                    ExecutePartialCloses();
                    error = GetLastError();
                    if(error != 0 && error != 4756) // Don't log ERR_TRADE_INVALID_STOPS as warning
                        Print("[GrandeRisk] WARNING: ExecutePartialCloses failed. Error: ", error);
                }
            }
        }
        else
        {
            if(InpLogDebugInfo)
                Print("[GrandeRisk] INFO: ATR value is 0, skipping position management");
        }
    }
}

//+------------------------------------------------------------------+
//| Update Position Information                                       |
//+------------------------------------------------------------------+
void CGrandeRiskManager::UpdatePositionInfo()
{
    int totalPositions = PositionsTotal();
    ArrayResize(m_positions, totalPositions);
    m_positionCount = 0;
    
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol)
            {
                PositionInfo pos;
                pos.ticket = ticket;
                pos.symbol = PositionGetString(POSITION_SYMBOL);
                pos.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                pos.volume = PositionGetDouble(POSITION_VOLUME);
                pos.price_open = PositionGetDouble(POSITION_PRICE_OPEN);
                pos.price_current = PositionGetDouble(POSITION_PRICE_CURRENT);
                pos.stop_loss = PositionGetDouble(POSITION_SL);
                pos.take_profit = PositionGetDouble(POSITION_TP);
                pos.profit = PositionGetDouble(POSITION_PROFIT);
                pos.time_open = (datetime)PositionGetInteger(POSITION_TIME);
                pos.tp_lock = false;
                pos.tp_lock_price = 0.0;
                
                // Parse TP lock from position comment if present (format: |TP_LOCK@<price>|...)
                string posComment = PositionGetString(POSITION_COMMENT);
                int idx = StringFind(posComment, "TP_LOCK@");
                if(idx >= 0)
                {
                    int start = idx + (int)StringLen("TP_LOCK@");
                    int end = StringFind(posComment, "|", start);
                    string priceStr = (end >= 0) ? StringSubstr(posComment, start, end - start)
                                                 : StringSubstr(posComment, start);
                    double locked = StringToDouble(priceStr);
                    if(locked > 0)
                    {
                        pos.tp_lock = true;
                        pos.tp_lock_price = locked;
                    }
                }
                
                // Check if this is a new position
                bool isNewPosition = true;
                for(int j = 0; j < m_positionCount; j++)
                {
                    if(m_positions[j].ticket == ticket)
                    {
                        isNewPosition = false;
                        pos.breakeven_set = m_positions[j].breakeven_set;
                        pos.partial_closed = m_positions[j].partial_closed;
                        pos.atr_at_open = m_positions[j].atr_at_open;
                        pos.last_sltp_set_time = m_positions[j].last_sltp_set_time;
                        break;
                    }
                }
                
                if(isNewPosition)
                {
                    pos.breakeven_set = false;
                    pos.partial_closed = false;
                    pos.atr_at_open = CalculateATR();
                    pos.last_sltp_set_time = 0;
                }
                
                // CRITICAL FIX: Check if position is already at breakeven by comparing stop loss
                // This prevents the oscillation between breakeven and trailing updates
                if(!pos.breakeven_set && pos.stop_loss > 0)
                {
                    double breakevenThreshold = pos.price_open + (pos.type == POSITION_TYPE_BUY ? 
                                              m_config.breakeven_buffer * _Point : 
                                              -m_config.breakeven_buffer * _Point);
                    
                    // If stop loss is at or beyond breakeven level, mark as breakeven_set
                    if(pos.type == POSITION_TYPE_BUY)
                    {
                        if(pos.stop_loss >= breakevenThreshold)
                            pos.breakeven_set = true;
                    }
                    else
                    {
                        if(pos.stop_loss <= breakevenThreshold)
                            pos.breakeven_set = true;
                    }
                }
                
                m_positions[m_positionCount] = pos;
                m_positionCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update Breakeven Stops                                            |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::UpdateBreakevenStops()
{
    if(!m_config.enable_breakeven) return false;
    
    // Backoff window after market-closed errors to avoid repeated attempts
    static datetime marketClosedBackoffUntil = 0;
    if(TimeCurrent() < marketClosedBackoffUntil)
        return false;

    double atrValue = CalculateATR();
    bool updated = false;
    
    // Get broker stop level requirements
    long stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minStopDistance = stopLevel * _Point;
    
    // Rate limiting: prevent excessive operations on the same position
    static datetime lastBreakevenLog = 0;
    static ulong lastBreakevenTicket = 0;
    
    for(int i = 0; i < m_positionCount; i++)
    {
        PositionInfo pos = m_positions[i];
        
        // Skip if already at breakeven or if stop loss is already at breakeven level
        if(pos.breakeven_set) continue;
        
        // Additional check: if stop loss is already at breakeven level, mark as set
        if(pos.stop_loss > 0)
        {
            double breakevenThreshold = pos.price_open + (pos.type == POSITION_TYPE_BUY ? 
                                      m_config.breakeven_buffer * _Point : 
                                      -m_config.breakeven_buffer * _Point);
            
            bool alreadyAtBreakeven = false;
            if(pos.type == POSITION_TYPE_BUY)
                alreadyAtBreakeven = (pos.stop_loss >= breakevenThreshold);
            else
                alreadyAtBreakeven = (pos.stop_loss <= breakevenThreshold);
                
            if(alreadyAtBreakeven)
            {
                pos.breakeven_set = true;
                m_positions[i] = pos;
                
                // Rate limit logging to prevent spam
                if(TimeCurrent() - lastBreakevenLog >= 10 || lastBreakevenTicket != pos.ticket)
                {
                    LogRiskEvent("INFO", StringFormat("Ticket %d already at breakeven level %.5f", pos.ticket, pos.stop_loss));
                    lastBreakevenLog = TimeCurrent();
                    lastBreakevenTicket = pos.ticket;
                }
                continue;
            }
        }
        
        double profitDistance = MathAbs(pos.price_current - pos.price_open);
        double breakevenDistance = atrValue * m_config.breakeven_atr;
        
        if(profitDistance >= breakevenDistance)
        {
            double newStopLoss = pos.price_open + (pos.type == POSITION_TYPE_BUY ? 
                              m_config.breakeven_buffer * _Point : 
                              -m_config.breakeven_buffer * _Point);
            
            // Rationale logging: context for breakeven decision
            if(InpLogDetailedInfo)
            {
                LogRiskEvent("INFO", StringFormat(
                    "BREAKEVEN DECISION ticket=%d type=%s profitDist=%.*f breakevenDist=%.*f atr=%.*f beBuffer(pips)=%.1f",
                    pos.ticket,
                    (pos.type==POSITION_TYPE_BUY?"BUY":"SELL"),
                    _Digits, profitDistance,
                    _Digits, breakevenDistance,
                    _Digits, atrValue,
                    m_config.breakeven_buffer/_Point));
            }

            // Validate stop level before attempting modification
            double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            double currentPrice = (pos.type == POSITION_TYPE_BUY) ? currentBid : currentAsk;
            
            // Check if stop level meets minimum distance requirement
            double stopDistance = MathAbs(currentPrice - newStopLoss);
            if(stopDistance < minStopDistance)
            {
                // Rate limit warning logs
                if(TimeCurrent() - lastBreakevenLog >= 30 || lastBreakevenTicket != pos.ticket)
                {
                    LogRiskEvent("WARNING", StringFormat(
                        "BREAKEVEN SKIP stop too close ticket=%d required=%.*f actual=%.*f price=%.*f newSL=%.*f",
                        pos.ticket,
                        _Digits, minStopDistance,
                        _Digits, stopDistance,
                        _Digits, currentPrice,
                        _Digits, newStopLoss));
                    lastBreakevenLog = TimeCurrent();
                    lastBreakevenTicket = pos.ticket;
                }
                continue; // Skip this position, try again later
            }
            
            // Additional validation: ensure stop is in the right direction
            bool validStop = false;
            if(pos.type == POSITION_TYPE_BUY)
            {
                validStop = (newStopLoss < currentBid && newStopLoss > 0);
            }
            else
            {
                validStop = (newStopLoss > currentAsk && newStopLoss > 0);
            }
            
            if(!validStop)
            {
                // Rate limit warning logs
                if(TimeCurrent() - lastBreakevenLog >= 30 || lastBreakevenTicket != pos.ticket)
                {
                    LogRiskEvent("WARNING", StringFormat(
                        "BREAKEVEN SKIP invalid direction ticket=%d stop=%.*f price=%.*f type=%s",
                        pos.ticket,
                        _Digits, newStopLoss,
                        _Digits, currentPrice,
                        (pos.type==POSITION_TYPE_BUY?"BUY":"SELL")));
                    lastBreakevenLog = TimeCurrent();
                    lastBreakevenTicket = pos.ticket;
                }
                continue; // Skip this position, try again later
            }
            
            // No-op guard: skip modify if stop wouldn't change materially
            if(pos.stop_loss > 0 && MathAbs(pos.stop_loss - newStopLoss) < 5*_Point)
            {
                pos.breakeven_set = true;
                m_positions[i] = pos;
                continue;
            }
            
            // Attempt to modify position with validated stop level
            if(m_trade.PositionModify(pos.ticket, newStopLoss, pos.take_profit))
            {
                pos.stop_loss = newStopLoss;
                pos.breakeven_set = true;
                updated = true;
                
                LogRiskEvent("BREAKEVEN_SET", StringFormat(
                    "ticket=%d sl=%.*f tp=%.*f rr=%.2f reason=profit>=beDist",
                    pos.ticket,
                    _Digits, newStopLoss,
                    _Digits, pos.take_profit,
                    (pos.take_profit>0 && newStopLoss>0 ?
                        MathAbs(pos.take_profit-pos.price_open)/MathAbs(pos.price_open-newStopLoss):0.0)));
                
                // Update the position in the array
                m_positions[i] = pos;
            }
            else
            {
                int error = m_trade.ResultRetcode();
                // Treat benign retcodes as non-errors
                if(error == 10025) { /* no change */ }
                else if(error == 4756) // invalid stops from server side, likely distance/freeze level
                {
                    // Do not mark breakeven_set permanently; we will retry later when distance allows
                    if(InpLogDebugInfo)
                        LogRiskEvent("WARNING", StringFormat(
                            "BREAKEVEN FAIL invalid stops ticket=%d ret=%d bid=%.*f ask=%.*f newSL=%.*f",
                            pos.ticket, error,
                            _Digits, currentBid,
                            _Digits, currentAsk,
                            _Digits, newStopLoss));
                }
                else if(error == 10018) // TRADE_RETCODE_MARKET_CLOSED
                {
                    // Back off for 15 minutes to avoid log spam while market is closed
                    marketClosedBackoffUntil = TimeCurrent() + 900;
                }
                else
                {
                    LogRiskEvent("ERROR", StringFormat(
                        "BREAKEVEN FAIL modify ticket=%d err=%d newSL=%.*f tp=%.*f",
                        pos.ticket, error,
                        _Digits, newStopLoss,
                        _Digits, pos.take_profit));
                }
            }
        }
    }
    
    return updated;
}

//+------------------------------------------------------------------+
//| Update Trailing Stops                                             |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::UpdateTrailingStops()
{
    if(!m_config.enable_trailing_stop) return false;
    
    // Backoff window after market-closed errors to avoid repeated attempts
    static datetime marketClosedBackoffUntil = 0;
    if(TimeCurrent() < marketClosedBackoffUntil)
        return false;

    double atrValue = CalculateATR();
    bool updated = false;
    
    // Get broker stop level requirements
    long stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minStopDistance = stopLevel * _Point;
    
    // Rate limiting: prevent excessive operations on the same position
    static datetime lastTrailingLog = 0;
    static ulong lastTrailingTicket = 0;
    
    for(int i = 0; i < m_positionCount; i++)
    {
        PositionInfo pos = m_positions[i];
        
        if(!pos.breakeven_set) continue; // Only trail after breakeven
        
        // Skip if no stop loss is set
        if(pos.stop_loss <= 0) continue;
        
        double trailingDistance = atrValue * m_config.trailing_atr_multiplier;
        double newStopLoss = 0.0;
        bool shouldUpdate = false;
        
        if(pos.type == POSITION_TYPE_BUY)
        {
            newStopLoss = pos.price_current - trailingDistance;
            // Only update if new stop is significantly better
            double minImprovement = MathMax(10*_Point, 0.25 * atrValue);
            shouldUpdate = (newStopLoss > pos.stop_loss + minImprovement);
        }
        else
        {
            newStopLoss = pos.price_current + trailingDistance;
            // Only update if new stop is significantly better
            double minImprovement = MathMax(10*_Point, 0.25 * atrValue);
            shouldUpdate = (newStopLoss < pos.stop_loss - minImprovement);
        }
        
        if(shouldUpdate)
        {
            // Rationale logging: context for trailing decision
            if(InpLogDetailedInfo)
            {
                LogRiskEvent("INFO", StringFormat(
                    "TRAIL DECISION ticket=%d type=%s price=%.*f prevSL=%.*f newSL=%.*f trailDist(ATR*%.2f)=%.*f minImprove=%.*f",
                    pos.ticket,
                    (pos.type==POSITION_TYPE_BUY?"BUY":"SELL"),
                    _Digits, pos.price_current,
                    _Digits, pos.stop_loss,
                    _Digits, newStopLoss,
                    m_config.trailing_atr_multiplier,
                    _Digits, trailingDistance,
                    _Digits, MathMax(10*_Point, 0.25 * atrValue)));
            }

            // Validate stop level before attempting modification
            double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            double currentAsk = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            double currentPrice = (pos.type == POSITION_TYPE_BUY) ? currentBid : currentAsk;
            
            // Check if stop level meets minimum distance requirement
            double stopDistance = MathAbs(currentPrice - newStopLoss);
            if(stopDistance < minStopDistance)
            {
                // Rate limit warning logs
                if(TimeCurrent() - lastTrailingLog >= 30 || lastTrailingTicket != pos.ticket)
                {
                    LogRiskEvent("WARNING", StringFormat("Trailing stop too close for ticket %d. Required: %.5f, Actual: %.5f", 
                                  pos.ticket, minStopDistance, stopDistance));
                    lastTrailingLog = TimeCurrent();
                    lastTrailingTicket = pos.ticket;
                }
                continue; // Skip this position, try again later
            }
            
            // Additional validation: ensure stop is in the right direction
            bool validStop = false;
            if(pos.type == POSITION_TYPE_BUY)
            {
                validStop = (newStopLoss < currentBid && newStopLoss > 0);
            }
            else
            {
                validStop = (newStopLoss > currentAsk && newStopLoss > 0);
            }
            
            if(!validStop)
            {
                // Rate limit warning logs
                if(TimeCurrent() - lastTrailingLog >= 30 || lastTrailingTicket != pos.ticket)
                {
                    LogRiskEvent("WARNING", StringFormat("Invalid trailing stop direction for ticket %d. Stop: %.5f, Price: %.5f", 
                                  pos.ticket, newStopLoss, currentPrice));
                    lastTrailingLog = TimeCurrent();
                    lastTrailingTicket = pos.ticket;
                }
                continue; // Skip this position, try again later
            }
            
            // Attempt to modify position with validated stop level
            if(m_trade.PositionModify(pos.ticket, newStopLoss, pos.take_profit))
            {
                pos.stop_loss = newStopLoss;
                updated = true;
                
                LogRiskEvent("TRAILING_UPDATE", StringFormat(
                    "ticket=%d sl=%.*f tp=%.*f rr=%.2f",
                    pos.ticket,
                    _Digits, newStopLoss,
                    _Digits, pos.take_profit,
                    (pos.take_profit>0 && newStopLoss>0 ?
                        MathAbs(pos.take_profit-pos.price_open)/MathAbs(pos.price_open-newStopLoss):0.0)));
                
                // Update the position in the array
                m_positions[i] = pos;
            }
            else
            {
                int error = m_trade.ResultRetcode();
                if(error == 10025) { /* no change */ }
                else if(error == 4756)
                {
                    if(InpLogDebugInfo)
                        LogRiskEvent("WARNING", StringFormat(
                            "TRAIL FAIL invalid stops ticket=%d bid=%.*f ask=%.*f newSL=%.*f",
                            pos.ticket,
                            _Digits, currentBid,
                            _Digits, currentAsk,
                            _Digits, newStopLoss));
                }
                else if(error == 10018) // TRADE_RETCODE_MARKET_CLOSED
                {
                    // Back off for 15 minutes to avoid repeated attempts
                    marketClosedBackoffUntil = TimeCurrent() + 900;
                }
                else
                {
                    LogRiskEvent("ERROR", StringFormat(
                        "TRAIL FAIL modify ticket=%d err=%d newSL=%.*f tp=%.*f",
                        pos.ticket, error,
                        _Digits, newStopLoss,
                        _Digits, pos.take_profit));
                }
            }
        }
    }
    
    return updated;
}

//+------------------------------------------------------------------+
//| Execute Partial Closes                                            |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::ExecutePartialCloses()
{
    if(!m_config.enable_partial_closes) return false;
    
    double atrValue = CalculateATR();
    if(atrValue <= 0) return false; // Skip if ATR not available
    
    bool executed = false;
    
    // Get broker volume requirements
    double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    // Check if any positions are large enough for partial closes
    bool hasPartialCloseablePositions = false;
    for(int i = 0; i < m_positionCount; i++)
    {
        if(!m_positions[i].partial_closed)
        {
            double potentialCloseVolume = m_positions[i].volume * m_config.partial_close_percent / 100.0;
            if(potentialCloseVolume >= minLot)
            {
                hasPartialCloseablePositions = true;
                break;
            }
        }
    }
    
    // If no positions can be partially closed, exit early
    if(!hasPartialCloseablePositions)
    {
        return false;
    }
    
    // Rate limiting: prevent excessive operations on the same position
    static datetime lastPartialLog = 0;
    static ulong lastPartialTicket = 0;
    
    for(int i = 0; i < m_positionCount; i++)
    {
        PositionInfo pos = m_positions[i];
        
        if(pos.partial_closed) continue;
        
        double profitDistance = MathAbs(pos.price_current - pos.price_open);
        double partialDistance = atrValue * m_config.partial_close_atr;
        
        if(profitDistance >= partialDistance)
        {
            double closeVolume = pos.volume * m_config.partial_close_percent / 100.0;
            
            // Rationale logging: context for partial close decision
            if(InpLogDetailedInfo)
            {
                LogRiskEvent("INFO", StringFormat(
                    "PARTIAL DECISION ticket=%d type=%s profitDist=%.*f threshold(ATR*%.2f)=%.*f vol=%.2f%% closeVol=%.2f",
                    pos.ticket,
                    (pos.type==POSITION_TYPE_BUY?"BUY":"SELL"),
                    _Digits, profitDistance,
                    m_config.partial_close_atr,
                    _Digits, partialDistance,
                    m_config.partial_close_percent,
                    closeVolume));
            }

            // Validate volume before attempting partial close
            if(closeVolume < minLot)
            {
                // Only log warning once per position and reduce frequency
                static datetime lastPartialLog = 0;
                static ulong lastPartialTicket = 0;
                
                if(TimeCurrent() - lastPartialLog >= 300 || lastPartialTicket != pos.ticket) // 5 minutes instead of 30 seconds
                {
                    if(InpLogDebugInfo) // Only log if debug is enabled
                    {
                        LogRiskEvent("INFO", StringFormat("Partial close volume too small for ticket %d. Required: %.5f, Actual: %.5f - This is normal for small positions", 
                                      pos.ticket, minLot, closeVolume));
                    }
                    lastPartialLog = TimeCurrent();
                    lastPartialTicket = pos.ticket;
                }
                
                // Mark as partial_closed to prevent repeated attempts on this position
                pos.partial_closed = true;
                m_positions[i] = pos;
                continue;
            }
            
            // Normalize volume to lot step
            closeVolume = NormalizeDouble(closeVolume / lotStep, 0) * lotStep;
            
            // Additional validation: ensure we're not closing the entire position
            if(closeVolume >= pos.volume)
            {
                LogRiskEvent("WARNING", StringFormat("Partial close volume %.5f >= total volume %.5f for ticket %d, skipping", 
                              closeVolume, pos.volume, pos.ticket));
                continue;
            }
            
            // Attempt partial close with validated volume
            ResetLastError();
            if(m_trade.PositionClosePartial(pos.ticket, closeVolume))
            {
                pos.partial_closed = true;
                executed = true;
                
                LogRiskEvent("PARTIAL_CLOSE", StringFormat(
                    "ticket=%d closed=%.2f lots remain=%.2f rr=%.2f",
                    pos.ticket,
                    closeVolume,
                    MathMax(0.0, pos.volume - closeVolume),
                    (pos.take_profit>0 && pos.stop_loss>0 ?
                        MathAbs(pos.take_profit-pos.price_open)/MathAbs(pos.price_open-pos.stop_loss):0.0)));
                
                // Update the position in the array
                m_positions[i] = pos;
            }
            else
            {
                int error = m_trade.ResultRetcode();
                LogRiskEvent("ERROR", StringFormat(
                    "PARTIAL FAIL ticket=%d err=%d volume=%.2f",
                    pos.ticket, error, closeVolume));
                
                // If it's an invalid stops error, mark as partial_closed to prevent infinite retries
                if(error == 4756) // ERR_TRADE_INVALID_STOPS
                {
                    pos.partial_closed = true; // Prevent further attempts
                    m_positions[i] = pos;
                    LogRiskEvent("WARNING", StringFormat("Marked ticket %d as partial_closed to prevent retries", pos.ticket));
                }
            }
        }
    }
    
    return executed;
}

//+------------------------------------------------------------------+
//| Smart Position Management - Set SL/TP for All Open Positions     |
//+------------------------------------------------------------------+
void CGrandeRiskManager::ManageAllPositions()
{
    if(!m_isInitialized) return;
    
    double atrValue = CalculateATR();
    if(atrValue <= 0) return; // Skip if ATR not available
    
    int totalPositions = PositionsTotal();
    int managedCount = 0;
    
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            string symbol = PositionGetString(POSITION_SYMBOL);
            if(symbol == m_symbol)
            {
                ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentSL = PositionGetDouble(POSITION_SL);
                double currentTP = PositionGetDouble(POSITION_TP);
                ulong magic = PositionGetInteger(POSITION_MAGIC);
                
                // Check if position needs SL/TP management
                bool needsManagement = false;
                
                // Case 1: No SL/TP set (common for manually opened positions)
                if(currentSL == 0 && currentTP == 0)
                {
                    needsManagement = true;
                    if(InpLogDebugInfo)
                        LogRiskEvent("INFO", StringFormat("Position %d has no SL/TP - setting intelligent levels", ticket));
                }
                // Case 2: SL/TP set but too close (within 1 ATR) - adjust for better risk management
                else if(currentSL != 0 || currentTP != 0)
                {
                    double minDistance = atrValue * 1.0; // Minimum 1 ATR distance
                    double slDistance = (currentSL != 0) ? MathAbs(entryPrice - currentSL) : 0;
                    double tpDistance = (currentTP != 0) ? MathAbs(currentTP - entryPrice) : 0;
                    
                    if(slDistance < minDistance || tpDistance < minDistance)
                    {
                        needsManagement = true;
                        if(InpLogDebugInfo)
                            LogRiskEvent("INFO", StringFormat("Position %d SL/TP too close - adjusting for better risk management", ticket));
                    }
                }
                
                if(needsManagement)
                {
                    bool isBuy = (type == POSITION_TYPE_BUY);
                    if(SetIntelligentSLTP(ticket, isBuy, entryPrice))
                    {
                        managedCount++;
                        if(InpLogDebugInfo)
                            LogRiskEvent("SUCCESS", StringFormat("Position %d SL/TP set successfully", ticket));
                    }
                    else
                    {
                        LogRiskEvent("WARNING", StringFormat("Failed to set SL/TP for position %d", ticket));
                    }
                }
            }
        }
    }
    
    if(managedCount > 0 && InpLogDebugInfo)
    {
        LogRiskEvent("INFO", StringFormat("Managed %d positions with intelligent SL/TP", managedCount));
    }
}

//+------------------------------------------------------------------+
//| Set Intelligent Stop Loss and Take Profit for a Position         |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::SetIntelligentSLTP(ulong ticket, bool isBuy, double entryPrice)
{
    if(!m_isInitialized) return false;
    
    double atrValue = CalculateATR();
    if(atrValue <= 0) return false;
    
    // Read current TP and check for TP lock from comment
    bool preserveTP = false;
    double currentTP = 0.0;
    double currentSL = 0.0;
    if(PositionSelectByTicket(ticket))
    {
        currentTP = PositionGetDouble(POSITION_TP);
        currentSL = PositionGetDouble(POSITION_SL);
        string posComment = PositionGetString(POSITION_COMMENT);
        int idx = StringFind(posComment, "TP_LOCK@");
        if(idx >= 0)
        {
            int start = idx + (int)StringLen("TP_LOCK@");
            int end = StringFind(posComment, "|", start);
            string priceStr = (end >= 0) ? StringSubstr(posComment, start, end - start)
                                         : StringSubstr(posComment, start);
            double locked = StringToDouble(priceStr);
            if(locked > 0)
            {
                preserveTP = true;
                // If current TP is not set use the locked value from comment
                if(currentTP <= 0) currentTP = locked;
            }
        }
    }
    
    // Calculate smart SL/TP levels
    double stopLoss = CalculateSmartStopLoss(isBuy, entryPrice, atrValue);
    double takeProfit = CalculateSmartTakeProfit(isBuy, entryPrice, stopLoss, atrValue);
    
    if(stopLoss <= 0 || takeProfit <= 0) return false;
    
    // Validate against broker requirements
    double minStopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if(minStopLevel <= 0) minStopLevel = 50 * _Point; // Fallback minimum
    
    double currentPrice = (isBuy) ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    
    // Validate SL distance
    double slDistance = MathAbs(currentPrice - stopLoss);
    if(slDistance < minStopLevel)
    {
        if(InpLogDebugInfo)
            LogRiskEvent("WARNING", StringFormat("Calculated SL too close (%.5f < %.5f) - adjusting", slDistance, minStopLevel));
        
        // Adjust SL to meet minimum distance
        if(isBuy)
            stopLoss = currentPrice - minStopLevel;
        else
            stopLoss = currentPrice + minStopLevel;
    }
    
    // Validate TP distance
    double tpDistance = MathAbs(takeProfit - currentPrice);
    if(tpDistance < minStopLevel)
    {
        if(InpLogDebugInfo)
            LogRiskEvent("WARNING", StringFormat("Calculated TP too close (%.5f < %.5f) - adjusting", tpDistance, minStopLevel));
        
        // Adjust TP to meet minimum distance
        if(isBuy)
            takeProfit = currentPrice + minStopLevel;
        else
            takeProfit = currentPrice - minStopLevel;
    }
    
    // Respect TP lock: do not overwrite TP if lock present
    if(preserveTP && currentTP > 0)
    {
        takeProfit = currentTP;
    }
    
    // Normalize prices to symbol digits
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    stopLoss = NormalizeDouble(stopLoss, digits);
    takeProfit = NormalizeDouble(takeProfit, digits);
    
    // Material-change dampening: use pips or fraction of ATR and cooldown
    double pipDeltaSL = MathAbs(currentSL - stopLoss) / _Point;
    double pipDeltaTP = MathAbs(currentTP - takeProfit) / _Point;
    double minPips = MathMax(1.0, m_config.min_modify_pips);
    double minAtr = MathMax(0.0, m_config.min_modify_atr_fraction) * atrValue;
    bool belowPipThreshold = (currentSL > 0 && pipDeltaSL < minPips) && (currentTP > 0 && pipDeltaTP < minPips);
    bool belowAtrThreshold = (currentSL > 0 && MathAbs(currentSL - stopLoss) < minAtr) && (currentTP > 0 && MathAbs(currentTP - takeProfit) < minAtr);
    bool withinCooldown = false;
    // Determine last set time from tracked positions
    for(int i=0;i<m_positionCount;i++){
        if(m_positions[i].ticket==ticket){
            withinCooldown = (TimeCurrent() - m_positions[i].last_sltp_set_time) < m_config.min_modify_cooldown_sec;
            break;
        }
    }
    if((belowPipThreshold || belowAtrThreshold) || withinCooldown)
    {
        if(InpLogDebugInfo)
            LogRiskEvent("INFO", StringFormat(
                "SLTP SKIP ticket=%d pipDeltaSL=%.1f pipDeltaTP=%.1f minPips=%.1f atr=%.5f minAtr=%.5f cooldown=%ds",
                ticket, pipDeltaSL, pipDeltaTP, minPips, atrValue, minAtr, m_config.min_modify_cooldown_sec));
        return true; // treat as success to avoid retries
    }

    // Modify position with new SL/TP
    ResetLastError();
    if(m_trade.PositionModify(ticket, stopLoss, takeProfit))
    {
        // Always-on concise rationale summary for SL/TP modify
        // Suppress duplicate log lines if effectively unchanged
        static double lastLoggedSL = 0.0;
        static double lastLoggedTP = 0.0;
        bool materiallyChangedForLog = (MathAbs(lastLoggedSL - stopLoss) >= 1*_Point) || (MathAbs(lastLoggedTP - takeProfit) >= 1*_Point);
        if(materiallyChangedForLog)
        {
            Print(StringFormat("[SLTP] SET ticket=%I64u side=%s entry=%.*f SL=%.*f TP=%.*f rr=%.2f",
                           ticket,
                           (isBuy?"BUY":"SELL"),
                           _Digits, entryPrice,
                           _Digits, stopLoss,
                           _Digits, takeProfit,
                           (MathAbs(takeProfit-entryPrice)/MathMax(1e-10, MathAbs(entryPrice-stopLoss)))));
            lastLoggedSL = stopLoss;
            lastLoggedTP = takeProfit;
        }
        if(InpLogDebugInfo)
            LogRiskEvent("SUCCESS", StringFormat("Position %d modified - SL: %.5f, TP: %.5f", 
                          ticket, stopLoss, takeProfit));
        // Update last set time
        for(int i=0;i<m_positionCount;i++){
            if(m_positions[i].ticket==ticket){
                m_positions[i].last_sltp_set_time = TimeCurrent();
                break;
            }
        }
        return true;
    }
    else
    {
        int error = m_trade.ResultRetcode();
        if(error == 10025)
        {
            // No changes; benign outcome
            if(InpLogDebugInfo)
                LogRiskEvent("INFO", StringFormat("Ticket %d modify returned NO_CHANGES", ticket));
            return true;
        }
        LogRiskEvent("ERROR", StringFormat("Failed to modify position %d. Error: %d", ticket, error));
        return false;
    }
}

//+------------------------------------------------------------------+
//| Calculate Smart Stop Loss Based on Market Conditions             |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateSmartStopLoss(bool isBuy, double entryPrice, double atrValue)
{
    if(atrValue <= 0) return 0;
    
    // Base ATR multiplier for stop loss
    double baseAtrMultiplier = m_config.sl_atr_multiplier;
    
    // Adjust based on market regime if available
    // This could be enhanced with trend strength, volatility regime, etc.
    double adjustedMultiplier = baseAtrMultiplier;
    
    // Calculate stop loss distance
    double stopDistance = atrValue * adjustedMultiplier;
    
    // Calculate stop loss price
    double stopLoss;
    if(isBuy)
    {
        stopLoss = entryPrice - stopDistance;
    }
    else
    {
        stopLoss = entryPrice + stopDistance;
    }
    
    return stopLoss;
}

//+------------------------------------------------------------------+
//| Calculate Smart Take Profit Based on Risk-Reward and ATR         |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateSmartTakeProfit(bool isBuy, double entryPrice, double stopLoss, double atrValue)
{
    if(atrValue <= 0) return 0;
    
    // Calculate stop loss distance
    double slDistance = MathAbs(entryPrice - stopLoss);
    if(slDistance <= 0) return 0;
    
    // Use configurable reward-to-risk ratio
    double rewardRiskRatio = m_config.tp_reward_ratio;
    
    // Calculate take profit distance
    double tpDistance = slDistance * rewardRiskRatio;
    
    // Calculate take profit price
    double takeProfit;
    if(isBuy)
    {
        takeProfit = entryPrice + tpDistance;
    }
    else
    {
        takeProfit = entryPrice - tpDistance;
    }
    
    return takeProfit;
}

//+------------------------------------------------------------------+
//| Check if Position Already Has SL/TP Set                          |
//+------------------------------------------------------------------+
bool CGrandeRiskManager::IsPositionManaged(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    double sl = PositionGetDouble(POSITION_SL);
    double tp = PositionGetDouble(POSITION_TP);
    
    // Position is managed if both SL and TP are set
    return (sl > 0 && tp > 0);
}

//+------------------------------------------------------------------+
//| Close All Positions                                               |
//+------------------------------------------------------------------+
void CGrandeRiskManager::CloseAllPositions()
{
    if(!m_isInitialized) return;
    
    int closedCount = 0;
    
    for(int i = m_positionCount - 1; i >= 0; i--)
    {
        if(m_trade.PositionClose(m_positions[i].ticket))
        {
            closedCount++;
            LogRiskEvent("POSITION_CLOSED", StringFormat("Ticket %d closed", m_positions[i].ticket));
        }
    }
    
    if(closedCount > 0)
    {
        LogRiskEvent("ALL_POSITIONS_CLOSED", StringFormat("Closed %d positions", closedCount));
        UpdatePositionInfo();
    }
}

//+------------------------------------------------------------------+
//| Get Position Information                                          |
//+------------------------------------------------------------------+
PositionInfo CGrandeRiskManager::GetPosition(int index)
{
    PositionInfo pos;
    pos.ticket = 0;
    
    if(!m_isInitialized || index < 0 || index >= m_positionCount)
        return pos;
    
    return m_positions[index];
}

//+------------------------------------------------------------------+
//| Get Total Profit                                                  |
//+------------------------------------------------------------------+
double CGrandeRiskManager::GetTotalProfit()
{
    if(!m_isInitialized) return 0.0;
    
    double totalProfit = 0.0;
    
    for(int i = 0; i < m_positionCount; i++)
    {
        totalProfit += m_positions[i].profit;
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Get Largest Position                                              |
//+------------------------------------------------------------------+
double CGrandeRiskManager::GetLargestPosition()
{
    if(!m_isInitialized || m_positionCount == 0) return 0.0;
    
    double largestVolume = 0.0;
    
    for(int i = 0; i < m_positionCount; i++)
    {
        if(m_positions[i].volume > largestVolume)
            largestVolume = m_positions[i].volume;
    }
    
    return largestVolume;
}

//+------------------------------------------------------------------+
//| Update Configuration                                              |
//+------------------------------------------------------------------+
void CGrandeRiskManager::UpdateConfig(const RiskConfig &config)
{
    m_config = config;
    LogRiskEvent("CONFIG_UPDATED", "Risk configuration updated");
}

//+------------------------------------------------------------------+
//| Calculate ATR Value                                               |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateATR()
{
    static int totalFailures = 0;
    static bool useFallbackMode = false;
    
    // If we're in fallback mode, just use the fallback calculation
    if(useFallbackMode)
    {
        double fallbackATR = CalculateATRFallback();
        if(fallbackATR > 0)
        {
            return fallbackATR;
        }
        else
        {
            Print("[GrandeRisk] ERROR: Fallback ATR failed, returning 0");
            return 0.0;
        }
    }
    
    // Pattern from: MetaQuotes Official Documentation
    // Reference: Ensure handle is ready before using CopyBuffer
    
    // First ensure the ATR handle is valid and ready
    if(!EnsureATRHandle(5, 100))
    {
        totalFailures++;
        Print("[GrandeRisk] ERROR: ATR handle not available. Total failures: ", totalFailures);
        
        if(totalFailures >= 5)
        {
            Print("[GrandeRisk] WARNING: Switching to fallback mode due to persistent ATR failures");
            useFallbackMode = true;
            return CalculateATRFallback();
        }
        
        return 0.0;
    }
    
    // Now the handle is guaranteed to be ready, safe to call CopyBuffer
    ResetLastError();
    int copied = CopyBuffer(m_atrHandle, 0, 0, 1, m_atrBuffer);
    int error = GetLastError();
    
    if(copied <= 0 || error != 0)
    {
        totalFailures++;
        Print("[GrandeRisk] ERROR: Failed to copy ATR buffer. Error: ", error, ", Copied: ", copied);
        
        // Handle still failed even after EnsureATRHandle - this shouldn't happen often
        if(totalFailures >= 5)
        {
            Print("[GrandeRisk] WARNING: Switching to fallback mode due to persistent copy failures");
            useFallbackMode = true;
            return CalculateATRFallback();
        }
        
        return 0.0;
    }
    
    // Success - reset failure counter and return ATR value
    if(totalFailures > 0) totalFailures--; // Gradually reduce failure count on success
    
    return m_atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Get Pip Value                                                     |
//+------------------------------------------------------------------+
double CGrandeRiskManager::GetPipValue()
{
    double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize <= 0) return 0.0;
    
    return tickValue / tickSize * _Point;
}

//+------------------------------------------------------------------+
//| Calculate ATR Fallback (Manual Calculation)                      |
//+------------------------------------------------------------------+
double CGrandeRiskManager::CalculateATRFallback()
{
    // Manual ATR calculation using high/low/close data
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    // Get last 15 bars (14 for ATR + 1 for current)
    int copied = CopyHigh(m_symbol, PERIOD_CURRENT, 0, 15, high);
    if(copied <= 0)
    {
        Print("[GrandeRisk] ERROR: Failed to copy high data for fallback ATR");
        return 0.0;
    }
    
    copied = CopyLow(m_symbol, PERIOD_CURRENT, 0, 15, low);
    if(copied <= 0)
    {
        Print("[GrandeRisk] ERROR: Failed to copy low data for fallback ATR");
        return 0.0;
    }
    
    copied = CopyClose(m_symbol, PERIOD_CURRENT, 0, 15, close);
    if(copied <= 0)
    {
        Print("[GrandeRisk] ERROR: Failed to copy close data for fallback ATR");
        return 0.0;
    }
    
    // Calculate True Range for each bar
    double tr[];
    ArrayResize(tr, 14);
    
    for(int i = 0; i < 14; i++)
    {
        double high_low = high[i] - low[i];
        double high_close = MathAbs(high[i] - close[i+1]);
        double low_close = MathAbs(low[i] - close[i+1]);
        
        tr[i] = MathMax(high_low, MathMax(high_close, low_close));
    }
    
    // Calculate ATR as simple average of True Range
    double atr = 0.0;
    for(int i = 0; i < 14; i++)
    {
        atr += tr[i];
    }
    atr /= 14.0;
    
    if(InpLogDebugInfo)
        Print("[GrandeRisk] Fallback ATR calculated: ", DoubleToString(atr, 5));
    
    return atr;
}

//+------------------------------------------------------------------+
//| Log Risk Event                                                    |
//+------------------------------------------------------------------+
void CGrandeRiskManager::LogRiskEvent(const string &event, const string &details)
{
    // Classify event severity
    bool isCritical = (StringFind(event, "CRITICAL") == 0);
    bool isError    = (StringFind(event, "ERROR") == 0);
    bool isWarning  = (event == "WARNING");
    bool isMaxPos   = (event == "MAX_POSITIONS");
    bool isInfoLike = (event == "INFO" || event == "SUCCESS" || event == "BREAKEVEN_SET" ||
                       event == "TRAILING_UPDATE" || event == "POSITION_CLOSED" ||
                       event == "ALL_POSITIONS_CLOSED" || event == "CONFIG_UPDATED" ||
                       event == "EQUITY_PEAK_RESET" || event == "PARTIAL_CLOSE");

    static datetime lastInfoLog = 0;
    static datetime lastWarnLog = 0;
    static datetime lastMaxPosLog = 0;

    // Always log critical and errors immediately
    if(isCritical || isError)
    {
        string msg = StringFormat("[GrandeRisk] %s", event);
        if(details != "") msg += ": " + details;
        Print(msg);
        return;
    }

    // Throttle MAX_POSITIONS messages to at most once per 60s
    if(isMaxPos)
    {
        if(TimeCurrent() - lastMaxPosLog < 60) return;
        lastMaxPosLog = TimeCurrent();
        string msg = StringFormat("[GrandeRisk] %s", event);
        if(details != "") msg += ": " + details;
        Print(msg);
        return;
    }

    // Warnings: only when debug enabled and rate-limited (30s)
    if(isWarning)
    {
        if(!InpLogDebugInfo) return;
        if(TimeCurrent() - lastWarnLog < 30) return;
        lastWarnLog = TimeCurrent();
        string msg = StringFormat("[GrandeRisk] %s", event);
        if(details != "") msg += ": " + details;
        Print(msg);
        return;
    }

    // Info-like events (including breakeven/trailing updates): debug-only and lightly rate-limited
    if(!InpLogDebugInfo) return;
    if(TimeCurrent() - lastInfoLog < 10) return;
    lastInfoLog = TimeCurrent();
    string msg = StringFormat("[GrandeRisk] %s", event);
    if(details != "") msg += ": " + details;
    Print(msg);
}

//+------------------------------------------------------------------+
void CGrandeRiskManager::LogRiskEvent(const string &event)
{
    LogRiskEvent(event, "");
}

//+------------------------------------------------------------------+
//| Log Status                                                        |
//+------------------------------------------------------------------+
void CGrandeRiskManager::LogStatus()
{
    if(!m_isInitialized) return;
    
    Print("=== GRANDE RISK MANAGER STATUS ===");
    Print("Symbol: ", m_symbol);
    Print("Trading Enabled: ", m_tradingEnabled ? "YES" : "NO");
    Print("Position Count: ", m_positionCount);
    Print("Current Drawdown: ", DoubleToString(GetCurrentDrawdown(), 2), "%");
    Print("Equity Peak: ", DoubleToString(m_equityPeak, 2));
    Print("Total Profit: ", DoubleToString(GetTotalProfit(), 2));
    Print("Largest Position: ", DoubleToString(GetLargestPosition(), 2));
    Print("ATR Value: ", DoubleToString(CalculateATR(), 5));
    Print("==================================");
} 