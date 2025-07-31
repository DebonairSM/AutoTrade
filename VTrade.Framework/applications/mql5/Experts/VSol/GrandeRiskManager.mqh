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
    
    // === Trade Object ===
    CTrade m_trade;
    
    // === Helper Methods ===
    bool InitializeATR();
    void UpdateEquityPeak();
    double CalculateATR();
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
bool CGrandeRiskManager::InitializeATR()
{
    m_atrHandle = iATR(m_symbol, PERIOD_CURRENT, 14);
    if(m_atrHandle == INVALID_HANDLE)
    {
        Print("[GrandeRisk] ERROR: Failed to create ATR handle");
        return false;
    }
    
    ArraySetAsSeries(m_atrBuffer, true);
    return true;
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
    
    // Update position information
    UpdatePositionInfo();
    
    // Check drawdown
    CheckDrawdown();
    
    // Update position management features
    if(m_tradingEnabled)
    {
        if(m_config.enable_breakeven)
            UpdateBreakevenStops();
            
        if(m_config.enable_trailing_stop)
            UpdateTrailingStops();
            
        if(m_config.enable_partial_closes)
            ExecutePartialCloses();
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
    
    for(int i = 0; i < m_positionCount; i++)
    {
        PositionInfo pos = m_positions[i];
        
        if(pos.breakeven_set) continue;
        
        double profitDistance = MathAbs(pos.price_current - pos.price_open);
        double breakevenDistance = atrValue * m_config.breakeven_atr;
        
        if(profitDistance >= breakevenDistance)
        {
            double newStopLoss = pos.price_open + (pos.type == POSITION_TYPE_BUY ? 
                              m_config.breakeven_buffer * _Point : 
                              -m_config.breakeven_buffer * _Point);
            
            if(m_trade.PositionModify(pos.ticket, newStopLoss, pos.take_profit))
            {
                pos.stop_loss = newStopLoss;
                pos.breakeven_set = true;
                updated = true;
                
                LogRiskEvent("BREAKEVEN_SET", StringFormat("Ticket %d moved to breakeven", pos.ticket));
                
                // Update the position in the array
                m_positions[i] = pos;
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
    
    for(int i = 0; i < m_positionCount; i++)
    {
        PositionInfo pos = m_positions[i];
        
        if(!pos.breakeven_set) continue; // Only trail after breakeven
        
        double trailingDistance = atrValue * m_config.trailing_atr_multiplier;
        double newStopLoss = 0.0;
        bool shouldUpdate = false;
        
        if(pos.type == POSITION_TYPE_BUY)
        {
            newStopLoss = pos.price_current - trailingDistance;
            shouldUpdate = (newStopLoss > pos.stop_loss);
        }
        else
        {
            newStopLoss = pos.price_current + trailingDistance;
            shouldUpdate = (newStopLoss < pos.stop_loss);
        }
        
        if(shouldUpdate)
        {
            if(m_trade.PositionModify(pos.ticket, newStopLoss, pos.take_profit))
            {
                pos.stop_loss = newStopLoss;
                updated = true;
                
                LogRiskEvent("TRAILING_UPDATE", StringFormat("Ticket %d trailing stop updated", pos.ticket));
                
                // Update the position in the array
                m_positions[i] = pos;
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
    if(m_atrHandle == INVALID_HANDLE) return 0.0;
    
    if(CopyBuffer(m_atrHandle, 0, 0, 1, m_atrBuffer) <= 0)
        return 0.0;
    
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