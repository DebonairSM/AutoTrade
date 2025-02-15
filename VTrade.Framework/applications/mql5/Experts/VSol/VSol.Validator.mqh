//+------------------------------------------------------------------+
//|                                    V-2-EA-BreakoutConfirmation.mqh |
//|                               Breakout Confirmation Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//--- Confirmation Analysis Constants
#define CONFIRM_MIN_CANDLES          3     // Minimum candles beyond level for confirmation
#define CONFIRM_VOLUME_THRESHOLD     2.0   // Minimum volume increase for confirmation
#define CONFIRM_MOMENTUM_MIN         0.4   // Minimum momentum indicator value
#define CONFIRM_MAX_WAIT_BARS       10     // Maximum bars to wait for confirmation
#define CONFIRM_MIN_PIPS_BEYOND     5     // Minimum pips beyond level
#define CONFIRM_PATTERN_WEIGHT      0.3   // Weight given to candlestick patterns

//--- Breakout Types
enum ENUM_BREAKOUT_TYPE
{
    BREAKOUT_TYPE_NONE = 0,    // No breakout
    BREAKOUT_TYPE_BULLISH,     // Bullish breakout (above resistance)
    BREAKOUT_TYPE_BEARISH      // Bearish breakout (below support)
};

//--- Confirmation State Structure
struct SConfirmationState
{
    bool              isActive;           // Whether confirmation phase is active
    datetime          startTime;          // When confirmation began
    double            breakoutLevel;      // The key level that was broken
    double            breakoutPrice;      // Price at initial breakout
    ENUM_BREAKOUT_TYPE breakoutType;      // Type of breakout
    int               confirmedCandles;   // Number of candles confirming breakout
    double            volumeRatio;        // Current volume ratio vs pre-breakout
    double            momentumValue;      // Current momentum indicator value
    
    void Reset()
    {
        isActive = false;
        startTime = 0;
        breakoutLevel = 0.0;
        breakoutPrice = 0.0;
        breakoutType = BREAKOUT_TYPE_NONE;
        confirmedCandles = 0;
        volumeRatio = 0.0;
        momentumValue = 0.0;
    }
};

//--- Confirmation Performance Metrics
struct SConfirmationPerformance
{
    int      totalBreakouts;     // Total breakout signals received
    int      confirmedBreakouts; // Successfully confirmed breakouts
    int      falseBreakouts;     // Failed confirmation attempts
    int      timeoutBreakouts;   // Breakouts that timed out waiting for confirmation
    double   confirmationRate;   // Rate of successful confirmations
    double   avgConfirmTime;     // Average bars until confirmation
    double   falseBreakoutRate;  // Rate of false breakouts caught
    
    void Reset()
    {
        totalBreakouts = 0;
        confirmedBreakouts = 0;
        falseBreakouts = 0;
        timeoutBreakouts = 0;
        confirmationRate = 0.0;
        avgConfirmTime = 0.0;
        falseBreakoutRate = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Main Breakout Confirmation Manager Class                           |
//+------------------------------------------------------------------+
class CV2EABreakoutConfirmation : public CV2EAMarketDataBase
{
private:
    //--- State Management
    SConfirmationState      m_currentConfirmation;  // Current confirmation state
    SConfirmationPerformance m_performance;         // Performance tracking
    
    //--- Configuration
    int                     m_minConfirmCandles;    // Required candles for confirmation
    double                  m_volumeThreshold;      // Required volume increase
    double                  m_momentumThreshold;    // Required momentum reading
    int                     m_maxWaitBars;         // Maximum bars to wait
    
    //--- Private Methods
    bool                    ValidateVolumeProfile();
    bool                    CheckMomentumConfirmation();
    bool                    AnalyzeCandlePatterns();
    void                    UpdateConfirmationMetrics(const bool isConfirmed);
    void                    LogConfirmationProgress();

protected:
    //--- Protected utility methods
    virtual bool            IsVolumeSufficient();
    virtual bool            HasConfirmationTimedOut();
    virtual double          CalculateConfirmationStrength();
    virtual bool            ValidatePriceAction();

public:
    //--- Constructor and Destructor
    CV2EABreakoutConfirmation(void);
    ~CV2EABreakoutConfirmation(void);
    
    //--- Initialization and Configuration
    virtual bool            Initialize(void);
    virtual void            ConfigureConfirmation(const int minCandles, const double volThresh);
    
    //--- Main Confirmation Methods
    virtual bool            BeginConfirmationPhase(const double level, const ENUM_BREAKOUT_TYPE type);
    virtual bool            UpdateConfirmationState();
    virtual bool            IsBreakoutConfirmed();
    virtual bool            HasConfirmationCompleted();
    
    //--- Utility and Information Methods
    virtual void            GetConfirmationState(SConfirmationState &state) const;
    virtual void            GetConfirmationPerformance(SConfirmationPerformance &perf) const;
    virtual string          GetConfirmationReport(void) const;
    
    //--- Event Handlers
    virtual void            OnBreakoutConfirmed(void);
    virtual void            OnBreakoutInvalid(void);
    virtual void            OnConfirmationTimeout(void);
}; 