//+------------------------------------------------------------------+
//|                                          V-2-EA-FilterManager.mqh |
//|                                   Trade Filter Implementation     |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//--- Filter Analysis Constants
#define FILTER_MIN_ADR_POINTS      50     // Minimum Average Daily Range in points
#define FILTER_MAX_SPREAD_RATIO    2.0    // Maximum spread as ratio of average
#define FILTER_MIN_VOLUME_RATIO    1.2    // Minimum volume ratio vs average
#define FILTER_NEWS_IMPACT_MINS    30     // Minutes to avoid trading around news
#define FILTER_SWING_MIN_POINTS    20     // Minimum swing size in points
#define FILTER_MAX_GAP_POINTS      10     // Maximum allowable gap in points
#define FILTER_VOLATILITY_FACTOR   1.5    // Maximum volatility increase factor
#define FILTER_MIN_TREND_STRENGTH  0.6    // Minimum trend strength (0-1)

//--- Trading Session Types
enum ENUM_TRADING_SESSION
{
    SESSION_NONE = 0,         // No specific session
    SESSION_ASIAN,            // Asian session
    SESSION_LONDON,           // London session
    SESSION_NEWYORK,         // New York session
    SESSION_OVERLAP          // Session overlap periods
};

//--- Market Condition Types
enum ENUM_MARKET_CONDITION
{
    MARKET_CONDITION_NONE = 0,    // Undefined condition
    MARKET_CONDITION_TRENDING,    // Trending market
    MARKET_CONDITION_RANGING,     // Ranging market
    MARKET_CONDITION_VOLATILE,    // Highly volatile
    MARKET_CONDITION_QUIET       // Low volatility
};

//--- Filter Types
enum ENUM_FILTER_TYPE
{
    FILTER_TYPE_NONE = 0,        // No specific filter
    FILTER_TYPE_TIME,            // Time-based filters
    FILTER_TYPE_VOLATILITY,      // Volatility filters
    FILTER_TYPE_TREND,           // Trend filters
    FILTER_TYPE_VOLUME,          // Volume filters
    FILTER_TYPE_NEWS,            // News filters
    FILTER_TYPE_PATTERN         // Pattern filters
};

//--- Filter State Structure
struct SFilterState
{
    bool              isValid;            // Whether current conditions pass filters
    ENUM_TRADING_SESSION currentSession;   // Current trading session
    ENUM_MARKET_CONDITION marketCondition; // Current market condition
    double            volatilityRatio;    // Current volatility ratio
    double            trendStrength;      // Current trend strength
    double            volumeRatio;        // Current volume ratio
    bool              hasNewsEvent;       // Whether news event is active
    string            lastFilterMessage;   // Last filter message
    
    void Reset()
    {
        isValid = false;
        currentSession = SESSION_NONE;
        marketCondition = MARKET_CONDITION_NONE;
        volatilityRatio = 0.0;
        trendStrength = 0.0;
        volumeRatio = 0.0;
        hasNewsEvent = false;
        lastFilterMessage = "";
    }
};

//--- Filter Performance Metrics
struct SFilterPerformance
{
    int      totalChecks;         // Total filter checks performed
    int      passedChecks;        // Filter checks that passed
    int      failedChecks;        // Filter checks that failed
    int      newsSkipped;         // Trades skipped due to news
    int      volatilitySkipped;   // Trades skipped due to volatility
    int      sessionSkipped;      // Trades skipped due to session
    double   avgPassRate;         // Average filter pass rate
    double   bestSession;         // Best performing session
    
    void Reset()
    {
        totalChecks = 0;
        passedChecks = 0;
        failedChecks = 0;
        newsSkipped = 0;
        volatilitySkipped = 0;
        sessionSkipped = 0;
        avgPassRate = 0.0;
        bestSession = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Main Filter Manager Class                                          |
//+------------------------------------------------------------------+
class CV2EABreakoutFilterManager : public CV2EAMarketDataBase
{
private:
    //--- State Management
    SFilterState         m_currentFilter;   // Current filter state
    SFilterPerformance   m_performance;     // Performance tracking
    
    //--- Configuration
    double              m_minADR;          // Minimum ADR requirement
    double              m_maxSpread;        // Maximum allowed spread
    double              m_minVolume;        // Minimum volume requirement
    int                 m_newsWindow;       // News filter window
    int                 m_minSwing;         // Minimum swing size
    int                 m_maxGap;           // Maximum price gap
    double              m_volFactor;        // Volatility factor
    double              m_trendStrength;    // Required trend strength
    
    //--- Session Management
    datetime            m_asianOpen;        // Asian session open
    datetime            m_asianClose;       // Asian session close
    datetime            m_londonOpen;       // London session open
    datetime            m_londonClose;      // London session close
    datetime            m_nyOpen;           // New York session open
    datetime            m_nyClose;          // New York session close
    
    //--- Private Methods
    bool                ValidateTimeFilter();
    bool                CheckVolatilityFilter();
    bool                ValidateTrendFilter();
    bool                CheckVolumeFilter();
    bool                ValidateNewsFilter();
    bool                CheckPatternFilter();
    void                UpdateFilterMetrics(const ENUM_FILTER_TYPE filterType, const bool passed);
    void                LogFilterStatus();
    ENUM_MARKET_CONDITION DetermineMarketCondition();
    
protected:
    //--- Protected utility methods
    virtual bool        IsSessionActive();
    virtual bool        IsVolatilityAcceptable();
    virtual bool        IsTrendValid();
    virtual bool        AreNewsConditionsSafe();

public:
    //--- Constructor and Destructor
    CV2EABreakoutFilterManager(void);
    ~CV2EABreakoutFilterManager(void);
    
    //--- Initialization and Configuration
    virtual bool        Initialize(void);
    virtual void        ConfigureFilterParameters(
                           const double minAdr,
                           const double maxSprd,
                           const double minVol,
                           const int newsWin
                       );
    
    //--- Main Filter Methods
    virtual bool        ValidateTradeSetup();
    virtual bool        UpdateFilterState();
    virtual bool        CheckAllFilters();
    virtual string      GetFilterWarnings();
    
    //--- Session Management Methods
    virtual void        ConfigureSessions(
                           const string asianRange,
                           const string londonRange,
                           const string nyRange
                       );
    virtual bool        IsInActiveSession();
    virtual ENUM_TRADING_SESSION GetCurrentSession();
    
    //--- Market Condition Methods
    virtual bool        ValidateMarketCondition();
    virtual bool        CheckVolatilityLevels();
    virtual bool        ValidateTrendCondition();
    
    //--- News Filter Methods
    virtual bool        CheckNewsEvents();
    virtual bool        IsHighImpactNews();
    virtual int         GetNextNewsMinutes();
    
    //--- Pattern Filter Methods
    virtual bool        ValidateBreakoutPattern();
    virtual bool        CheckSwingPoints();
    virtual bool        ValidateGapSize();
    
    //--- Utility and Information Methods
    virtual void        GetFilterState(SFilterState &state) const;
    virtual void        GetFilterPerformance(SFilterPerformance &perf) const;
    virtual string      GetFilterReport(void) const;
    virtual double      GetCurrentVolatility(void) const;
    virtual double      GetTrendStrength(void) const;
    
    //--- Event Handlers
    virtual void        OnFilterFailed(const ENUM_FILTER_TYPE filterType);
    virtual void        OnNewsDetected();
    virtual void        OnVolatilityExceeded();
    virtual void        OnSessionChanged();
    virtual void        OnMarketConditionChanged();
}; 