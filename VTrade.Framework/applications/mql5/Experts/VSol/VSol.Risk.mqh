//+------------------------------------------------------------------+
//|                                                VSol.Risk.mqh      |
//|                        Risk Management Implementation              |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include "VSol.Market.mqh"
#include "VSol.Utils.mqh"

//--- Risk Analysis Constants
#define RISK_MAX_ACCOUNT_PERCENT    2.0    // Maximum risk per trade (% of account)
#define RISK_MAX_DAILY_PERCENT      5.0    // Maximum daily risk (% of account)
#define RISK_MAX_DRAWDOWN_PERCENT   15.0   // Maximum allowed drawdown
#define RISK_MIN_RR_RATIO          1.5    // Minimum risk:reward ratio
#define RISK_MAX_CORRELATION        0.75   // Maximum correlation between positions
#define RISK_MAX_OPEN_POSITIONS    3      // Maximum concurrent positions
#define RISK_MIN_MARGIN_LEVEL      200.0  // Minimum required margin level (%)
#define RISK_MAX_SPREAD_PERCENT    10.0   // Maximum spread as % of average spread

//--- Risk Check Types
enum ENUM_RISK_CHECK
{
    RISK_CHECK_NONE = 0,          // No specific check
    RISK_CHECK_ACCOUNT,           // Account-based checks
    RISK_CHECK_POSITION,          // Position-specific checks
    RISK_CHECK_MARKET,            // Market condition checks
    RISK_CHECK_CORRELATION,       // Correlation checks
    RISK_CHECK_TIME              // Time-based checks
};

//--- Risk State Structure
struct SRiskState
{
    bool              isRiskValid;         // Whether current risk is acceptable
    double            currentAccountRisk;   // Current risk as % of account
    double            dailyRiskUsed;       // Daily risk used (%)
    double            currentDrawdown;      // Current drawdown (%)
    int               openPositions;        // Number of open positions
    double            marginLevel;          // Current margin level
    double            correlationLevel;     // Current correlation level
    double            spreadRatio;         // Current spread ratio
    string            lastRiskMessage;      // Last risk check message
    
    void Reset()
    {
        isRiskValid = false;
        currentAccountRisk = 0.0;
        dailyRiskUsed = 0.0;
        currentDrawdown = 0.0;
        openPositions = 0;
        marginLevel = 0.0;
        correlationLevel = 0.0;
        spreadRatio = 0.0;
        lastRiskMessage = "";
    }
};

//--- Risk Performance Metrics
struct SRiskPerformance
{
    int      totalChecks;         // Total risk checks performed
    int      passedChecks;        // Risk checks that passed
    int      failedChecks;        // Risk checks that failed
    double   avgAccountRisk;      // Average account risk per trade
    double   maxDailyRisk;        // Maximum daily risk reached
    double   maxDrawdown;         // Maximum drawdown reached
    double   avgCorrelation;      // Average position correlation
    double   worstMarginLevel;    // Worst margin level reached
    
    void Reset()
    {
        totalChecks = 0;
        passedChecks = 0;
        failedChecks = 0;
        avgAccountRisk = 0.0;
        maxDailyRisk = 0.0;
        maxDrawdown = 0.0;
        avgCorrelation = 0.0;
        worstMarginLevel = 0.0;
    }
};

class CVSolRisk : public CVSolMarketBase
{
private:
    double m_riskPercent;
    double m_maxDrawdown;
    double m_maxDailyLoss;
    
    static double m_initialBalance;
    static double m_maxRiskPerDay;
    static int m_maxOpenTrades;
    static bool m_compoundProfits;
    static double m_maxLossPerMonth;
    
    static double m_dailyLoss;
    static double m_monthlyLoss;
    static int m_openPositions;
    static datetime m_lastDayChecked;
    static datetime m_lastMonthChecked;
    
public:
    static void ConfigureMoneyManagement(double initialBalance, double maxRiskPerDay, int maxOpenTrades, bool compoundProfits, double maxLossPerMonth)
    {
        m_initialBalance = initialBalance;
        m_maxRiskPerDay = maxRiskPerDay;
        m_maxOpenTrades = maxOpenTrades;
        m_compoundProfits = compoundProfits;
        m_maxLossPerMonth = maxLossPerMonth;
    }
    
    static void Reset()
    {
        m_dailyLoss = 0;
        m_monthlyLoss = 0;
        m_openPositions = 0;
        m_lastDayChecked = 0;
        m_lastMonthChecked = 0;
    }
    
    static bool CanOpenNewPosition()
    {
        // Check max open positions
        if(m_openPositions >= m_maxOpenTrades)
            return false;
            
        // Reset daily/monthly trackers if needed
        datetime now = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(now, dt);
        
        MqlDateTime lastDay;
        TimeToStruct(m_lastDayChecked, lastDay);
        
        MqlDateTime lastMonth;
        TimeToStruct(m_lastMonthChecked, lastMonth);
        
        // Check if day changed
        if(dt.day != lastDay.day || dt.mon != lastDay.mon || dt.year != lastDay.year)
        {
            m_dailyLoss = 0;
            m_lastDayChecked = now;
        }
        
        // Check if month changed
        if(dt.mon != lastMonth.mon || dt.year != lastMonth.year)
        {
            m_monthlyLoss = 0;
            m_lastMonthChecked = now;
        }
        
        // Check daily loss limit
        if(m_dailyLoss >= m_initialBalance * m_maxRiskPerDay / 100)
            return false;
            
        // Check monthly loss limit
        if(m_monthlyLoss >= m_initialBalance * m_maxLossPerMonth / 100)
            return false;
            
        return true;
    }
    
    static void UpdatePositionCount(bool isOpen)
    {
        if(isOpen)
            m_openPositions++;
        else if(m_openPositions > 0)
            m_openPositions--;
    }
    
    static void UpdateLoss(double loss)
    {
        if(loss <= 0) return;
        
        m_dailyLoss += loss;
        m_monthlyLoss += loss;
    }
    
    static double GetAvailableRisk()
    {
        double dailyRemaining = m_initialBalance * m_maxRiskPerDay / 100 - m_dailyLoss;
        double monthlyRemaining = m_initialBalance * m_maxLossPerMonth / 100 - m_monthlyLoss;
        return MathMin(dailyRemaining, monthlyRemaining);
    }
    
    bool Init(double riskPercent, double maxDrawdown, double maxDailyLoss)
    {
        m_riskPercent = riskPercent;
        m_maxDrawdown = maxDrawdown;
        m_maxDailyLoss = maxDailyLoss;
        return true;
    }
    
    double CalculateLotSize(double stopLossPips)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = balance * m_riskPercent / 100.0;
        double tickValue = 0.0, lotStep = 0.0;
        
        if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tickValue) ||
           !SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, lotStep))
            return 0.0;
        
        if(tickValue <= 0 || lotStep <= 0 || stopLossPips <= 0)
            return 0.0;
        
        double lotSize = NormalizeDouble(riskAmount / (stopLossPips * tickValue), 2);
        lotSize = MathFloor(lotSize / lotStep) * lotStep;
        
        return lotSize;
    }
    
    bool ValidateRisk(double lotSize, double stopLossPips)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double tickValue = 0.0;
        
        if(!SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tickValue))
            return false;  // Can't validate without tick value
        
        // Calculate potential loss
        double potentialLoss = lotSize * stopLossPips * tickValue;
        
        // Check against risk percent
        if(potentialLoss > balance * m_riskPercent / 100.0)
            return false;
            
        // Check drawdown
        double currentDrawdown = (balance - equity) / balance * 100.0;
        if(currentDrawdown > m_maxDrawdown)
            return false;
            
        // Check daily loss
        // TODO: Implement daily loss tracking
        
        return true;
    }
};

// Initialize static members
double CVSolRisk::m_initialBalance = 10000;
double CVSolRisk::m_maxRiskPerDay = 5.0;
int CVSolRisk::m_maxOpenTrades = 3;
bool CVSolRisk::m_compoundProfits = true;
double CVSolRisk::m_maxLossPerMonth = 10.0;

double CVSolRisk::m_dailyLoss = 0;
double CVSolRisk::m_monthlyLoss = 0;
int CVSolRisk::m_openPositions = 0;
datetime CVSolRisk::m_lastDayChecked = 0;
datetime CVSolRisk::m_lastMonthChecked = 0;

//+------------------------------------------------------------------+
//| Main Risk Manager Class                                            |
//+------------------------------------------------------------------+
class CVSolRiskManager : public CVSolMarketBase
{
private:
    //--- State Management
    SRiskState          m_currentRisk;     // Current risk state
    SRiskPerformance    m_performance;     // Performance tracking
    
    //--- Configuration
    double              m_maxAccountRisk;   // Maximum account risk (%)
    double              m_maxDailyRisk;     // Maximum daily risk (%)
    double              m_maxDrawdown;      // Maximum allowed drawdown
    double              m_minRRRatio;       // Minimum risk:reward ratio
    double              m_maxCorrelation;   // Maximum position correlation
    int                 m_maxPositions;     // Maximum open positions
    double              m_minMarginLevel;   // Minimum margin level
    double              m_maxSpreadRatio;   // Maximum spread ratio
    
    //--- Private Methods
    bool ValidateAccountRisk(const double riskAmount)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskPercent = (riskAmount / balance) * 100.0;
        return (riskPercent <= m_maxAccountRisk);
    }
    
    bool ValidateDailyRisk(const double riskAmount)
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double currentDailyRisk = m_currentRisk.dailyRiskUsed;
        double newDailyRisk = currentDailyRisk + (riskAmount / balance) * 100.0;
        return (newDailyRisk <= m_maxDailyRisk);
    }
    
    bool CheckDrawdownLimit()
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double drawdown = (balance - equity) / balance * 100.0;
        return (drawdown <= m_maxDrawdown);
    }
    
    bool ValidatePositionCorrelation()
    {
        double correlation = CalculatePositionCorrelation();
        return (correlation <= m_maxCorrelation);
    }
    
    bool CheckMarginRequirements()
    {
        double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
        return (marginLevel >= m_minMarginLevel);
    }
    
    void UpdateRiskMetrics(const ENUM_RISK_CHECK checkType, const bool passed)
    {
        m_performance.totalChecks++;
        if(passed)
            m_performance.passedChecks++;
        else
            m_performance.failedChecks++;
    }
    
    void LogRiskStatus()
    {
        Print("Risk Status Update:");
        Print("Account Risk: ", m_currentRisk.currentAccountRisk, "%");
        Print("Daily Risk Used: ", m_currentRisk.dailyRiskUsed, "%");
        Print("Current Drawdown: ", m_currentRisk.currentDrawdown, "%");
        Print("Open Positions: ", m_currentRisk.openPositions);
        Print("Margin Level: ", m_currentRisk.marginLevel, "%");
    }
    
    double CalculatePositionCorrelation()
    {
        // Simple correlation calculation based on open positions
        int totalPositions = PositionsTotal();
        if(totalPositions <= 1)
            return 0.0;
            
        double correlation = 0.0;
        // TODO: Implement proper correlation calculation
        return correlation;
    }
    
protected:
    //--- Protected utility methods
    virtual bool IsRiskAcceptable()
    {
        return CheckDrawdownLimit() && 
               CheckMarginRequirements() && 
               ValidatePositionCorrelation();
    }
    
    virtual bool IsMarginSufficient()
    {
        return CheckMarginRequirements();
    }
    
    virtual bool AreSpreadsSafe()
    {
        double ask = 0.0, bid = 0.0;
        long spread = 0;
        
        if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask) ||
           !SymbolInfoDouble(_Symbol, SYMBOL_BID, bid) ||
           !SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread))
            return false;
            
        double currentSpread = ask - bid;
        double avgSpread = spread * _Point;
        return (currentSpread <= avgSpread * m_maxSpreadRatio);
    }
    
    virtual double GetCurrentRiskExposure()
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double exposure = 0.0;
        
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
                double positionValue = PositionGetDouble(POSITION_VOLUME) * 
                                     PositionGetDouble(POSITION_PRICE_OPEN);
                exposure += positionValue;
            }
        }
        
        return (exposure / balance) * 100.0;
    }

public:
    //--- Main Risk Management Methods
    virtual bool ValidateNewPosition(const double riskAmount,
                                   const double rewardAmount,
                                   const string symbol)
    {
        // Check risk-reward ratio
        if(rewardAmount > 0 && (riskAmount / rewardAmount) > m_minRRRatio)
            return false;
            
        // Check position limits
        if(PositionsTotal() >= m_maxPositions)
            return false;
            
        // Validate risk amounts
        if(!ValidateAccountRisk(riskAmount) || !ValidateDailyRisk(riskAmount))
            return false;
            
        // Check correlation if symbol is different
        if(symbol != _Symbol && !ValidatePositionCorrelation())
            return false;
            
        return IsRiskAcceptable();
    }
    
    virtual bool UpdateRiskState()
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        m_currentRisk.currentDrawdown = (balance - equity) / balance * 100.0;
        m_currentRisk.marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
        m_currentRisk.openPositions = PositionsTotal();
        m_currentRisk.currentAccountRisk = GetCurrentRiskExposure();
        m_currentRisk.correlationLevel = CalculatePositionCorrelation();
        
        m_currentRisk.isRiskValid = IsRiskAcceptable();
        
        LogRiskStatus();
        return m_currentRisk.isRiskValid;
    }
    
    virtual bool CheckRiskLimits()
    {
        if(!UpdateRiskState())
            return false;
            
        if(m_currentRisk.currentDrawdown > m_maxDrawdown)
        {
            OnDrawdownLimitHit();
            return false;
        }
        
        if(m_currentRisk.marginLevel < m_minMarginLevel)
        {
            OnMarginCallWarning();
            return false;
        }
        
        if(m_currentRisk.dailyRiskUsed > m_maxDailyRisk)
        {
            OnDailyRiskLimitHit();
            return false;
        }
        
        return true;
    }
    
    virtual string GetRiskWarnings()
    {
        string warnings = "";
        
        if(m_currentRisk.currentDrawdown > m_maxDrawdown * 0.8)
            warnings += "High Drawdown Warning\n";
            
        if(m_currentRisk.marginLevel < m_minMarginLevel * 1.2)
            warnings += "Low Margin Level Warning\n";
            
        if(m_currentRisk.dailyRiskUsed > m_maxDailyRisk * 0.8)
            warnings += "Approaching Daily Risk Limit\n";
            
        if(m_currentRisk.openPositions >= m_maxPositions * 0.8)
            warnings += "Approaching Position Limit\n";
            
        return warnings;
    }
    
    //--- Position Risk Methods
    virtual bool ValidatePositionSize(const double lots)
    {
        double maxLots = GetMaxPositionSize();
        return (lots <= maxLots);
    }
    
    virtual bool ValidateStopLoss(const double price)
    {
        double currentPrice = 0.0;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, currentPrice))
            return false;
            
        double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
        return (MathAbs(currentPrice - price) >= minDistance);
    }
    
    virtual bool CheckPositionLimits()
    {
        return (PositionsTotal() < m_maxPositions);
    }
    
    virtual double GetMaxPositionSize()
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double margin = 0.0;
        
        // Get margin requirement using proper enumeration
        if(!SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL, margin))
        {
            // If margin info not available, use conservative estimate
            double tickValue = 0.0;
            if(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE, tickValue))
            {
                margin = tickValue * 100;  // Assume 1:100 leverage
            }
            else
            {
                // Ultimate fallback - use very conservative estimate
                margin = 1000.0;  // Assume high margin requirement
            }
        }
        
        double maxRiskAmount = balance * m_maxAccountRisk / 100.0;
        
        // Get minimum lot size with proper error checking
        double minLot = 0.0, maxLot = 0.0, lotStep = 0.0;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN, minLot)) minLot = 0.01;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX, maxLot)) maxLot = 100.0;
        if(!SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP, lotStep)) lotStep = 0.01;
        
        // Calculate maximum position size
        double lotSize = NormalizeDouble(maxRiskAmount / margin, 2);
        
        // Ensure lot size is within allowed range and properly stepped
        lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
        lotSize = MathFloor(lotSize / lotStep) * lotStep;
        
        return lotSize;
    }
    
    //--- Correlation Management
    virtual bool CheckSymbolCorrelation(const string symbol)
    {
        // TODO: Implement proper correlation check
        return true;
    }
    
    virtual bool UpdateCorrelationMatrix()
    {
        // TODO: Implement correlation matrix update
        return true;
    }
    
    virtual double GetSymbolCorrelation(const string symbol)
    {
        // TODO: Implement correlation calculation
        return 0.0;
    }
    
    //--- Market Risk Methods
    virtual bool ValidateMarketConditions()
    {
        return AreSpreadsSafe();
    }
    
    virtual bool CheckVolatilityLevels()
    {
        // First check if ATR indicator is available
        double atr[];
        ArraySetAsSeries(atr, true);
        int handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        
        if(handle == INVALID_HANDLE)
            return false;  // Failed to create ATR indicator
            
        if(CopyBuffer(handle, 0, 0, 1, atr) <= 0)
        {
            IndicatorRelease(handle);
            return false;  // Failed to copy ATR data
        }
        
        // Get current market prices
        double avgATR = atr[0];
        double ask = 0.0, bid = 0.0;
        
        if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask) ||
           !SymbolInfoDouble(_Symbol, SYMBOL_BID, bid))
        {
            IndicatorRelease(handle);
            return false;  // Failed to get price data
        }
        
        // Calculate current volatility
        double currentATR = MathAbs(ask - bid) / _Point;
        bool result = (currentATR <= avgATR * 2.0);
        
        IndicatorRelease(handle);
        return result;
    }
    
    virtual bool ValidateSpreadLevels()
    {
        return AreSpreadsSafe();
    }
    
    //--- Account Risk Methods
    virtual bool CheckAccountHealth()
    {
        return IsMarginSufficient() && CheckDrawdownLimit();
    }
    
    virtual bool ValidateMarginLevels()
    {
        return IsMarginSufficient();
    }
    
    virtual double GetAvailableRisk()
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double usedRisk = m_currentRisk.currentAccountRisk;
        double availableRisk = m_maxAccountRisk - usedRisk;
        return MathMax(0.0, availableRisk * balance / 100.0);
    }
    
    //--- Utility and Information Methods
    virtual void GetRiskState(SRiskState &state) const
    {
        state = m_currentRisk;
    }
    
    virtual void GetRiskPerformance(SRiskPerformance &perf) const
    {
        perf = m_performance;
    }
    
    virtual string GetRiskReport(void) const
    {
        string report = "=== Risk Management Report ===\n";
        report += StringFormat("Account Risk: %.2f%%\n", m_currentRisk.currentAccountRisk);
        report += StringFormat("Daily Risk Used: %.2f%%\n", m_currentRisk.dailyRiskUsed);
        report += StringFormat("Current Drawdown: %.2f%%\n", m_currentRisk.currentDrawdown);
        report += StringFormat("Margin Level: %.2f%%\n", m_currentRisk.marginLevel);
        report += StringFormat("Open Positions: %d\n", m_currentRisk.openPositions);
        report += StringFormat("Risk Checks - Total: %d, Passed: %d, Failed: %d\n",
                             m_performance.totalChecks,
                             m_performance.passedChecks,
                             m_performance.failedChecks);
        return report;
    }
    
    virtual double GetCurrentDrawdown(void) const
    {
        return m_currentRisk.currentDrawdown;
    }
    
    virtual double GetDailyRiskUsed(void) const
    {
        return m_currentRisk.dailyRiskUsed;
    }
    
    //--- Event Handlers
    virtual void OnRiskLimitExceeded(void)
    {
        Print("⚠️ Risk limit exceeded!");
        // TODO: Implement risk limit exceeded handling
    }
    
    virtual void OnMarginCallWarning(void)
    {
        Print("⚠️ Margin call warning!");
        // TODO: Implement margin call warning handling
    }
    
    virtual void OnDrawdownLimitHit(void)
    {
        Print("⚠️ Drawdown limit hit!");
        // TODO: Implement drawdown limit handling
    }
    
    virtual void OnCorrelationLimitHit(void)
    {
        Print("⚠️ Correlation limit hit!");
        // TODO: Implement correlation limit handling
    }
    
    virtual void OnDailyRiskLimitHit(void)
    {
        Print("⚠️ Daily risk limit hit!");
        // TODO: Implement daily risk limit handling
    }
}; 