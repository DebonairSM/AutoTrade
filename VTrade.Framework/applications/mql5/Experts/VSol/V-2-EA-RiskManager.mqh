//+------------------------------------------------------------------+
//|                                           V-2-EA-RiskManager.mqh |
//|                                    Risk Management Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

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

//+------------------------------------------------------------------+
//| Main Risk Manager Class                                            |
//+------------------------------------------------------------------+
class CV2EABreakoutRiskManager : public CV2EAMarketDataBase
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
    bool                ValidateAccountRisk(const double riskAmount);
    bool                ValidateDailyRisk(const double riskAmount);
    bool                CheckDrawdownLimit();
    bool                ValidatePositionCorrelation();
    bool                CheckMarginRequirements();
    void                UpdateRiskMetrics(const ENUM_RISK_CHECK checkType, const bool passed);
    void                LogRiskStatus();
    double              CalculatePositionCorrelation();
    
protected:
    //--- Protected utility methods
    virtual bool        IsRiskAcceptable();
    virtual bool        IsMarginSufficient();
    virtual bool        AreSpreadsSafe();
    virtual double      GetCurrentRiskExposure();

public:
    //--- Constructor and Destructor
    CV2EABreakoutRiskManager(void);
    ~CV2EABreakoutRiskManager(void);
    
    //--- Initialization and Configuration
    virtual bool        Initialize(void);
    virtual void        ConfigureRiskParameters(
                           const double maxAccRisk,
                           const double maxDayRisk,
                           const double maxDD,
                           const double minRR
                       );
    
    //--- Main Risk Management Methods
    virtual bool        ValidateNewPosition(
                           const double riskAmount,
                           const double rewardAmount,
                           const string symbol
                       );
    virtual bool        UpdateRiskState();
    virtual bool        CheckRiskLimits();
    virtual string      GetRiskWarnings();
    
    //--- Position Risk Methods
    virtual bool        ValidatePositionSize(const double lots);
    virtual bool        ValidateStopLoss(const double price);
    virtual bool        CheckPositionLimits();
    virtual double      GetMaxPositionSize();
    
    //--- Correlation Management
    virtual bool        CheckSymbolCorrelation(const string symbol);
    virtual bool        UpdateCorrelationMatrix();
    virtual double      GetSymbolCorrelation(const string symbol);
    
    //--- Market Risk Methods
    virtual bool        ValidateMarketConditions();
    virtual bool        CheckVolatilityLevels();
    virtual bool        ValidateSpreadLevels();
    
    //--- Account Risk Methods
    virtual bool        CheckAccountHealth();
    virtual bool        ValidateMarginLevels();
    virtual double      GetAvailableRisk();
    
    //--- Utility and Information Methods
    virtual void        GetRiskState(SRiskState &state) const;
    virtual void        GetRiskPerformance(SRiskPerformance &perf) const;
    virtual string      GetRiskReport(void) const;
    virtual double      GetCurrentDrawdown(void) const;
    virtual double      GetDailyRiskUsed(void) const;
    
    //--- Event Handlers
    virtual void        OnRiskLimitExceeded(void);
    virtual void        OnMarginCallWarning(void);
    virtual void        OnDrawdownLimitHit(void);
    virtual void        OnCorrelationLimitHit(void);
    virtual void        OnDailyRiskLimitHit(void);
}; 