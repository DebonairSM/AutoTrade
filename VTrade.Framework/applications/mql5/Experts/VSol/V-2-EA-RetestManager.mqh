//+------------------------------------------------------------------+
//|                                           V-2-EA-RetestManager.mqh |
//|                                    Retest Detection Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//--- Retest Analysis Constants
#define RETEST_MIN_TOUCHES           2     // Minimum touches required for valid retest
#define RETEST_MAX_DURATION_BARS     20    // Maximum bars to wait for retest completion
#define RETEST_VOLUME_THRESHOLD      1.5   // Minimum volume ratio for retest validation
#define RETEST_MOMENTUM_THRESHOLD    0.3   // Minimum momentum change for retest confirmation
#define RETEST_BOUNCE_MIN_PIPS      5     // Minimum bounce distance in pips
#define RETEST_MAX_DEVIATION_PIPS   3     // Maximum deviation from level during retest

//--- Retest State Structure
struct SRetestState
{
    bool     isActive;           // Whether retest phase is currently active
    datetime startTime;          // When retest phase began
    double   entryPrice;         // Original breakout price
    double   extremePrice;       // Most extreme price during retest
    int      touchCount;         // Number of touches during retest
    double   cumulativeVolume;   // Total volume during retest phase
    double   averageMomentum;    // Average momentum during retest
    
    void Reset()
    {
        isActive = false;
        startTime = 0;
        entryPrice = 0.0;
        extremePrice = 0.0;
        touchCount = 0;
        cumulativeVolume = 0.0;
        averageMomentum = 0.0;
    }
};

//--- Retest Performance Metrics
struct SRetestPerformance
{
    int      totalRetests;       // Total retest attempts
    int      validRetests;       // Successfully validated retests
    int      failedRetests;      // Failed retest attempts
    int      timeoutRetests;     // Retests that timed out
    double   successRate;        // Success rate of retest validation
    double   avgRetestDuration;  // Average bars until retest completion
    double   avgTouchCount;      // Average touches during retest
    
    void Reset()
    {
        totalRetests = 0;
        validRetests = 0;
        failedRetests = 0;
        timeoutRetests = 0;
        successRate = 0.0;
        avgRetestDuration = 0.0;
        avgTouchCount = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Main Retest Manager Class                                          |
//+------------------------------------------------------------------+
class CV2EARetestManager : public CV2EAMarketDataBase
{
private:
    //--- State Management
    SRetestState        m_currentRetest;    // Current retest state
    SRetestPerformance  m_performance;      // Performance tracking
    
    //--- Configuration
    int                 m_maxRetestBars;    // Maximum bars to wait for retest
    double              m_volumeThreshold;  // Required volume for validation
    double              m_momentumThresh;   // Required momentum for confirmation
    
    //--- Private Methods
    bool                ValidateRetestSetup(const double &price, const double &volume);
    bool                CheckRetestMomentum(const double &currentPrice);
    void                UpdateRetestMetrics(const bool isSuccessful);
    void                LogRetestProgress();

protected:
    //--- Protected utility methods
    virtual bool        IsRetestVolumeSufficient();
    virtual bool        HasRetestTimedOut();
    virtual double      CalculateRetestStrength();

public:
    //--- Constructor and Destructor
    CV2EARetestManager(void);
    ~CV2EARetestManager(void);
    
    //--- Initialization and Configuration
    virtual bool        Initialize(void);
    virtual void        ConfigureRetestParameters(const int maxBars, const double volThresh);
    
    //--- Main Retest Management Methods
    virtual bool        BeginRetestPhase(const double breakoutPrice);
    virtual bool        UpdateRetestState(const double currentPrice, const double currentVolume);
    virtual bool        IsRetestValid(void);
    virtual bool        HasRetestCompleted(void);
    
    //--- Utility and Information Methods
    virtual void        GetRetestState(SRetestState &state) const;
    virtual void        GetRetestPerformance(SRetestPerformance &perf) const;
    virtual string      GetRetestReport(void) const;
    
    //--- Event Handlers
    virtual void        OnRetestValidated(void);
    virtual void        OnRetestFailed(void);
    virtual void        OnRetestTimeout(void);
}; 