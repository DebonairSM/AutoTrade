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
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(lotSize, minLot);
    lotSize = MathMin(lotSize, maxLot);
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
    
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
            if(m_config.enable_breakeven)
            {
                // Rate limiting: only attempt breakeven updates every 5 seconds
                static datetime lastBreakevenAttempt = 0;
                if(TimeCurrent() - lastBreakevenAttempt >= 5)
                {
                    ResetLastError();
                    UpdateBreakevenStops();
                    error = GetLastError();
                    if(error != 0)
                        Print("[GrandeRisk] WARNING: UpdateBreakevenStops failed. Error: ", error);
                    
                    lastBreakevenAttempt = TimeCurrent();
                }
            }
                
            if(m_config.enable_trailing_stop)
            {
                // Rate limiting: only attempt trailing stop updates every 3 seconds
                static datetime lastTrailingAttempt = 0;
                if(TimeCurrent() - lastTrailingAttempt >= 3)
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
                ResetLastError();
                ExecutePartialCloses();
                error = GetLastError();
                if(error != 0)
                    Print("[GrandeRisk] WARNING: ExecutePartialCloses failed. Error: ", error);
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
                        break;
                    }
                }
                
                if(isNewPosition)
                {
                    pos.breakeven_set = false;
                    pos.partial_closed = false;
                    pos.atr_at_open = CalculateATR();
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
                    LogRiskEvent("WARNING", StringFormat("Stop level too close for ticket %d. Required: %.5f, Actual: %.5f", 
                                  pos.ticket, minStopDistance, stopDistance));
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
                    LogRiskEvent("WARNING", StringFormat("Invalid stop direction for ticket %d. Stop: %.5f, Price: %.5f", 
                                  pos.ticket, newStopLoss, currentPrice));
                    lastBreakevenLog = TimeCurrent();
                    lastBreakevenTicket = pos.ticket;
                }
                continue; // Skip this position, try again later
            }
            
            // Attempt to modify position with validated stop level
            if(m_trade.PositionModify(pos.ticket, newStopLoss, pos.take_profit))
            {
                pos.stop_loss = newStopLoss;
                pos.breakeven_set = true;
                updated = true;
                
                LogRiskEvent("BREAKEVEN_SET", StringFormat("Ticket %d moved to breakeven at %.5f", pos.ticket, newStopLoss));
                
                // Update the position in the array
                m_positions[i] = pos;
            }
            else
            {
                int error = m_trade.ResultRetcode();
                LogRiskEvent("ERROR", StringFormat("Failed to modify ticket %d. Error: %d", pos.ticket, error));
                
                // If it's an invalid stops error, mark as breakeven_set to prevent infinite retries
                if(error == 4756) // ERR_TRADE_INVALID_STOPS
                {
                    pos.breakeven_set = true; // Prevent further attempts
                    m_positions[i] = pos;
                    LogRiskEvent("WARNING", StringFormat("Marked ticket %d as breakeven_set to prevent retries", pos.ticket));
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
            // Only update if new stop is significantly better (at least 1 pip improvement)
            shouldUpdate = (newStopLoss > pos.stop_loss + _Point);
        }
        else
        {
            newStopLoss = pos.price_current + trailingDistance;
            // Only update if new stop is significantly better (at least 1 pip improvement)
            shouldUpdate = (newStopLoss < pos.stop_loss - _Point);
        }
        
        if(shouldUpdate)
        {
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
                
                LogRiskEvent("TRAILING_UPDATE", StringFormat("Ticket %d trailing stop updated to %.5f", pos.ticket, newStopLoss));
                
                // Update the position in the array
                m_positions[i] = pos;
            }
            else
            {
                int error = m_trade.ResultRetcode();
                LogRiskEvent("ERROR", StringFormat("Failed to modify trailing stop for ticket %d. Error: %d", pos.ticket, error));
                
                // If it's an invalid stops error, log but don't prevent future attempts
                if(error == 4756) // ERR_TRADE_INVALID_STOPS
                {
                    LogRiskEvent("WARNING", StringFormat("Invalid trailing stop for ticket %d, will retry later", pos.ticket));
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
    bool executed = false;
    
    for(int i = 0; i < m_positionCount; i++)
    {
        PositionInfo pos = m_positions[i];
        
        if(pos.partial_closed) continue;
        
        double profitDistance = MathAbs(pos.price_current - pos.price_open);
        double partialDistance = atrValue * m_config.partial_close_atr;
        
        if(profitDistance >= partialDistance)
        {
            double closeVolume = pos.volume * m_config.partial_close_percent / 100.0;
            
            if(m_trade.PositionClosePartial(pos.ticket, closeVolume))
            {
                pos.partial_closed = true;
                executed = true;
                
                LogRiskEvent("PARTIAL_CLOSE", StringFormat("Ticket %d partial close %.2f lots", 
                           pos.ticket, closeVolume));
                
                // Update the position in the array
                m_positions[i] = pos;
            }
        }
    }
    
    return executed;
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
    string logMessage = StringFormat("[GrandeRisk] %s", event);
    if(details != "")
        logMessage += ": " + details;
    
    Print(logMessage);
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