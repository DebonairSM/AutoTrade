//+------------------------------------------------------------------+
//|                                            V-2-EA-ExitManager.mqh |
//|                                     Exit Management Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//--- Exit Analysis Constants
#define EXIT_TRAILING_START_POINTS   20    // Points of profit before trailing starts
#define EXIT_TRAILING_STEP_POINTS    5     // Points for each trailing step
#define EXIT_PARTIAL_PROFIT_RATIO    0.5   // Ratio at which to take partial profits
#define EXIT_MAX_HOLDING_BARS        100   // Maximum bars to hold position
#define EXIT_BREAKEVEN_POINTS        15    // Points in profit to move to breakeven
#define EXIT_TIME_STOP_MINUTES       240   // Maximum minutes to hold position

//--- Exit Types
enum ENUM_EXIT_TYPE
{
    EXIT_TYPE_NONE = 0,        // No exit
    EXIT_TYPE_STOP_LOSS,       // Stop loss hit
    EXIT_TYPE_TAKE_PROFIT,     // Take profit hit
    EXIT_TYPE_TRAILING_STOP,   // Trailing stop hit
    EXIT_TYPE_BREAKEVEN,       // Breakeven stop hit
    EXIT_TYPE_TIME_STOP,       // Time-based exit
    EXIT_TYPE_MANUAL           // Manual exit
};

//--- Exit Mode
enum ENUM_EXIT_MODE
{
    EXIT_MODE_NONE = 0,        // No specific mode
    EXIT_MODE_FULL,           // Full position exit
    EXIT_MODE_PARTIAL,        // Partial position exit
    EXIT_MODE_SCALED         // Scaled exit
};

//--- Exit State Structure
struct SExitState
{
    bool              isActive;           // Whether exit management is active
    datetime          entryTime;          // When position was entered
    double            entryPrice;         // Position entry price
    double            currentStop;        // Current stop loss level
    double            initialStop;        // Initial stop loss level
    double            takeProfit;         // Take profit level
    double            breakeven;          // Breakeven level
    double            trailingStop;       // Current trailing stop level
    ENUM_EXIT_TYPE    lastExitType;       // Last exit type triggered
    ENUM_EXIT_MODE    exitMode;           // Current exit mode
    double            maxFloatingProfit;  // Maximum floating profit reached
    double            maxFloatingLoss;    // Maximum floating loss reached
    
    void Reset()
    {
        isActive = false;
        entryTime = 0;
        entryPrice = 0.0;
        currentStop = 0.0;
        initialStop = 0.0;
        takeProfit = 0.0;
        breakeven = 0.0;
        trailingStop = 0.0;
        lastExitType = EXIT_TYPE_NONE;
        exitMode = EXIT_MODE_NONE;
        maxFloatingProfit = 0.0;
        maxFloatingLoss = 0.0;
    }
};

//--- Exit Performance Metrics
struct SExitPerformance
{
    int      totalExits;         // Total exits executed
    int      stopLossExits;      // Exits by stop loss
    int      takeProfitExits;    // Exits by take profit
    int      trailingExits;      // Exits by trailing stop
    int      breakevenExits;     // Exits at breakeven
    int      timeStopExits;      // Time-based exits
    int      manualExits;        // Manual exits
    double   avgHoldingTime;     // Average position holding time
    double   avgProfitFactor;    // Average profit factor
    double   maxDrawdown;        // Maximum drawdown experienced
    
    void Reset()
    {
        totalExits = 0;
        stopLossExits = 0;
        takeProfitExits = 0;
        trailingExits = 0;
        breakevenExits = 0;
        timeStopExits = 0;
        manualExits = 0;
        avgHoldingTime = 0.0;
        avgProfitFactor = 0.0;
        maxDrawdown = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Main Exit Manager Class                                            |
//+------------------------------------------------------------------+
class CV2EABreakoutExitManager : public CV2EAMarketDataBase
{
private:
    //--- State Management
    SExitState          m_currentExit;     // Current exit state
    SExitPerformance    m_performance;     // Performance tracking
    
    //--- Configuration
    int                 m_trailingStart;   // Points before trailing
    int                 m_trailingStep;    // Trailing step size
    double              m_partialRatio;    // Partial exit ratio
    int                 m_maxBars;         // Maximum holding period
    int                 m_breakevenPoints; // Points for breakeven
    int                 m_timeStopMinutes; // Time-based exit
    
    //--- Private Methods
    bool                UpdateTrailingStop(const double currentPrice);
    bool                CheckBreakevenCondition(const double currentPrice);
    bool                ValidateExitParameters();
    void                UpdateExitMetrics(const ENUM_EXIT_TYPE exitType);
    void                LogExitProgress();
    double              CalculatePartialLots(const double totalLots);
    bool                IsTimeExitDue();
    
protected:
    //--- Protected utility methods
    virtual bool        IsTrailingActive();
    virtual bool        ShouldMoveBreakeven();
    virtual bool        HasTimeExpired();
    virtual double      GetOptimalExitPrice();

public:
    //--- Constructor and Destructor
    CV2EABreakoutExitManager(void);
    ~CV2EABreakoutExitManager(void);
    
    //--- Initialization and Configuration
    virtual bool        Initialize(void);
    virtual void        ConfigureExitParameters(
                           const int trailStart,
                           const int trailStep,
                           const double partialRatio,
                           const int maxBars
                       );
    
    //--- Main Exit Management Methods
    virtual bool        BeginExitManagement(
                           const double entryPrice,
                           const double stopLoss,
                           const double takeProfit
                       );
    virtual bool        UpdateExitState(const double currentPrice);
    virtual bool        CheckExitConditions(void);
    virtual bool        ExecuteExit(const ENUM_EXIT_MODE mode);
    
    //--- Stop Management Methods
    virtual bool        UpdateStopLoss(const double price);
    virtual bool        UpdateTakeProfit(const double price);
    virtual bool        EnableTrailingStop(const bool enable);
    virtual bool        EnableBreakeven(const bool enable);
    virtual bool        EnableTimeStop(const bool enable);
    
    //--- Partial Exit Methods
    virtual bool        SetPartialExitLevel(const double price);
    virtual bool        SetScaledExitLevels(const double &levels[]);
    virtual bool        ExecutePartialExit(const double lots);
    
    //--- Utility and Information Methods
    virtual void        GetExitState(SExitState &state) const;
    virtual void        GetExitPerformance(SExitPerformance &perf) const;
    virtual string      GetExitReport(void) const;
    virtual double      GetCurrentProfit(void) const;
    virtual int         GetHoldingTime(void) const;
    
    //--- Event Handlers
    virtual void        OnStopLossHit(void);
    virtual void        OnTakeProfitHit(void);
    virtual void        OnTrailingStopHit(void);
    virtual void        OnBreakevenHit(void);
    virtual void        OnTimeStopTriggered(void);
    virtual void        OnManualExit(void);
}; 