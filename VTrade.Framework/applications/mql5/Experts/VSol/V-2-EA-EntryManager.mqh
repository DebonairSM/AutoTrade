//+------------------------------------------------------------------+
//|                                           V-2-EA-EntryManager.mqh |
//|                                    Entry Management Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//--- Entry Analysis Constants
#define ENTRY_MIN_VOLUME_RATIO       1.5    // Minimum volume ratio for entry validation
#define ENTRY_MIN_MOMENTUM          0.3    // Minimum momentum for entry
#define ENTRY_MAX_SPREAD_POINTS     10     // Maximum spread allowed for entry
#define ENTRY_TIMEOUT_BARS          5      // Maximum bars to wait for entry
#define ENTRY_MIN_ADR_PERCENT       0.2    // Minimum ADR percentage for entry
#define ENTRY_MAX_RISK_PERCENT      2.0    // Maximum risk per trade

//--- Entry Types
enum ENUM_ENTRY_TYPE
{
    ENTRY_TYPE_NONE = 0,       // No entry
    ENTRY_TYPE_MARKET,         // Market entry
    ENTRY_TYPE_STOP,          // Stop entry
    ENTRY_TYPE_LIMIT          // Limit entry
};

//--- Entry Timeframes
enum ENUM_ENTRY_TIMEFRAME
{
    ENTRY_TF_NONE = 0,        // No timeframe
    ENTRY_TF_M1   = 1,        // 1 minute
    ENTRY_TF_M5   = 5,        // 5 minutes
    ENTRY_TF_M15  = 15,       // 15 minutes
    ENTRY_TF_H1   = 60,       // 1 hour
    ENTRY_TF_H4   = 240,      // 4 hours
    ENTRY_TF_D1   = 1440      // Daily
};

//--- Entry State Structure
struct SEntryState
{
    bool              isActive;           // Whether entry analysis is active
    datetime          startTime;          // When entry analysis began
    double            entryPrice;         // Calculated entry price
    double            stopLoss;           // Initial stop loss
    double            takeProfit;         // Initial take profit
    ENUM_ENTRY_TYPE   entryType;          // Type of entry
    double            positionSize;       // Position size in lots
    double            riskAmount;         // Risk amount in account currency
    double            rewardAmount;       // Potential reward in account currency
    double            riskRewardRatio;    // Risk:Reward ratio
    
    void Reset()
    {
        isActive = false;
        startTime = 0;
        entryPrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        entryType = ENTRY_TYPE_NONE;
        positionSize = 0.0;
        riskAmount = 0.0;
        rewardAmount = 0.0;
        riskRewardRatio = 0.0;
    }
};

//--- Entry Performance Metrics
struct SEntryPerformance
{
    int      totalSignals;       // Total entry signals generated
    int      validEntries;       // Successfully validated entries
    int      rejectedEntries;    // Entries rejected by filters
    int      timeoutEntries;     // Entries that timed out
    double   entryAccuracy;      // Rate of successful entries
    double   avgEntryTime;       // Average bars until entry
    double   avgSpreadCost;      // Average spread cost at entry
    
    void Reset()
    {
        totalSignals = 0;
        validEntries = 0;
        rejectedEntries = 0;
        timeoutEntries = 0;
        entryAccuracy = 0.0;
        avgEntryTime = 0.0;
        avgSpreadCost = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Main Entry Manager Class                                           |
//+------------------------------------------------------------------+
class CV2EABreakoutEntryManager : public CV2EAMarketDataBase
{
private:
    //--- State Management
    SEntryState         m_currentEntry;    // Current entry state
    SEntryPerformance   m_performance;     // Performance tracking
    
    //--- Configuration
    int                 m_maxEntryBars;    // Maximum bars to wait for entry
    double              m_minVolume;       // Minimum volume for entry
    double              m_minMomentum;     // Minimum momentum for entry
    double              m_maxSpread;       // Maximum allowed spread
    double              m_maxRiskPercent;  // Maximum risk per trade
    
    //--- Timeframe Management
    ENUM_ENTRY_TIMEFRAME m_primaryTimeframe;   // Primary analysis timeframe
    ENUM_ENTRY_TIMEFRAME m_secondaryTimeframe; // Secondary confirmation timeframe
    
    //--- Private Methods
    bool                ValidateEntrySetup(const double price, const double volume);
    bool                CheckEntryMomentum(const double currentPrice);
    void                UpdateEntryMetrics(const bool isSuccessful);
    void                LogEntryProgress();
    double              CalculatePositionSize(const double entryPrice, const double stopLoss);
    double              GetMaxPositionSize();
    bool                ValidateRiskParameters();
    
protected:
    //--- Protected utility methods
    virtual bool        IsEntryVolumeSufficient();
    virtual bool        HasEntryTimedOut();
    virtual bool        IsSpreadAcceptable();
    virtual double      CalculateRiskRewardRatio();

public:
    //--- Constructor and Destructor
    CV2EABreakoutEntryManager(void);
    ~CV2EABreakoutEntryManager(void);
    
    //--- Initialization and Configuration
    virtual bool        Initialize(void);
    virtual void        ConfigureEntryParameters(
                           const int maxBars,
                           const double minVol,
                           const double minMom,
                           const double maxSprd
                       );
    
    //--- Main Entry Management Methods
    virtual bool        BeginEntryAnalysis(const double price);
    virtual bool        UpdateEntryState(const double currentPrice, const double currentVolume);
    virtual bool        IsEntryValid(void);
    virtual bool        HasEntryCompleted(void);
    virtual bool        ExecuteEntry(void);
    
    //--- Position Sizing and Risk Management
    virtual bool        SetPositionSize(const double lots);
    virtual bool        SetRiskPercentage(const double riskPercent);
    virtual bool        SetStopLoss(const double price);
    virtual bool        SetTakeProfit(const double price);
    
    //--- Timeframe Management
    virtual void        SetTimeframes(
                           const ENUM_ENTRY_TIMEFRAME primary,
                           const ENUM_ENTRY_TIMEFRAME secondary
                       );
    virtual bool        ValidateTimeframeAlignment();
    
    //--- Utility and Information Methods
    virtual void        GetEntryState(SEntryState &state) const;
    virtual void        GetEntryPerformance(SEntryPerformance &perf) const;
    virtual string      GetEntryReport(void) const;
    virtual double      GetCurrentRisk(void) const;
    virtual double      GetCurrentReward(void) const;
    
    //--- Event Handlers
    virtual void        OnEntryValidated(void);
    virtual void        OnEntryRejected(void);
    virtual void        OnEntryTimeout(void);
    virtual void        OnEntryExecuted(void);
}; 