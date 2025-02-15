//+------------------------------------------------------------------+
//|                                          V-2-EA-Statistics.mqh |
//|                                   Statistics Implementation     |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//--- Statistics Analysis Constants
#define STATS_MIN_TRADES           30     // Minimum trades for reliable statistics
#define STATS_HISTORY_DAYS         90     // Days of trade history to analyze
#define STATS_MAX_DRAWDOWN_PCT    25.0   // Maximum drawdown percentage warning
#define STATS_MIN_WIN_RATE        45.0   // Minimum acceptable win rate
#define STATS_MIN_PROFIT_FACTOR   1.5    // Minimum acceptable profit factor
#define STATS_MAX_CONSEC_LOSSES   5      // Maximum consecutive losses warning
#define STATS_CONFIDENCE_LEVEL    95.0   // Statistical confidence level
#define STATS_UPDATE_INTERVAL     60     // Statistics update interval (seconds)

//--- Trade Result Types
enum ENUM_TRADE_RESULT
{
    TRADE_RESULT_NONE = 0,     // No result
    TRADE_RESULT_WIN,          // Winning trade
    TRADE_RESULT_LOSS,         // Losing trade
    TRADE_RESULT_BREAKEVEN    // Breakeven trade
};

//--- Performance Period Types
enum ENUM_PERFORMANCE_PERIOD
{
    PERIOD_NONE = 0,          // No specific period
    PERIOD_TODAY,             // Today's performance
    PERIOD_WEEK,             // This week
    PERIOD_MONTH,            // This month
    PERIOD_QUARTER,          // This quarter
    PERIOD_YEAR             // This year
};

//--- Trade Statistics Structure
struct STradeStats
{
    //--- Basic Metrics
    int               totalTrades;        // Total number of trades
    int               winningTrades;      // Number of winning trades
    int               losingTrades;       // Number of losing trades
    int               breakEvenTrades;    // Number of breakeven trades
    double            winRate;            // Win rate percentage
    double            profitFactor;       // Profit factor
    
    //--- Profit Metrics
    double            grossProfit;        // Total gross profit
    double            grossLoss;          // Total gross loss
    double            netProfit;          // Net profit/loss
    double            largestWin;         // Largest winning trade
    double            largestLoss;        // Largest losing trade
    double            averageWin;         // Average winning trade
    double            averageLoss;        // Average losing trade
    
    //--- Risk Metrics
    double            maxDrawdown;        // Maximum drawdown
    double            maxDrawdownPct;     // Maximum drawdown percentage
    int               maxConsecLosses;    // Maximum consecutive losses
    double            sharpeRatio;        // Sharpe ratio
    double            sortinoRatio;       // Sortino ratio
    
    //--- Time Metrics
    int               avgHoldingTime;     // Average trade duration (minutes)
    int               maxHoldingTime;     // Maximum trade duration
    int               minHoldingTime;     // Minimum trade duration
    
    void Reset()
    {
        totalTrades = 0;
        winningTrades = 0;
        losingTrades = 0;
        breakEvenTrades = 0;
        winRate = 0.0;
        profitFactor = 0.0;
        grossProfit = 0.0;
        grossLoss = 0.0;
        netProfit = 0.0;
        largestWin = 0.0;
        largestLoss = 0.0;
        averageWin = 0.0;
        averageLoss = 0.0;
        maxDrawdown = 0.0;
        maxDrawdownPct = 0.0;
        maxConsecLosses = 0;
        sharpeRatio = 0.0;
        sortinoRatio = 0.0;
        avgHoldingTime = 0;
        maxHoldingTime = 0;
        minHoldingTime = 0;
    }
};

//--- Strategy Performance Structure
struct SStrategyPerformance
{
    //--- Period Performance
    STradeStats       todayStats;         // Today's statistics
    STradeStats       weekStats;          // This week's statistics
    STradeStats       monthStats;         // This month's statistics
    STradeStats       quarterStats;       // This quarter's statistics
    STradeStats       yearStats;          // This year's statistics
    STradeStats       allTimeStats;       // All-time statistics
    
    //--- Pattern Performance
    double            breakoutWinRate;    // Win rate for breakout patterns
    double            retestWinRate;      // Win rate for retest patterns
    double            trendWinRate;       // Win rate in trending markets
    double            rangeWinRate;       // Win rate in ranging markets
    
    //--- Session Performance
    double            asianWinRate;       // Win rate during Asian session
    double            londonWinRate;      // Win rate during London session
    double            nyWinRate;          // Win rate during NY session
    double            overlapWinRate;     // Win rate during session overlaps
    
    void Reset()
    {
        todayStats.Reset();
        weekStats.Reset();
        monthStats.Reset();
        quarterStats.Reset();
        yearStats.Reset();
        allTimeStats.Reset();
        breakoutWinRate = 0.0;
        retestWinRate = 0.0;
        trendWinRate = 0.0;
        rangeWinRate = 0.0;
        asianWinRate = 0.0;
        londonWinRate = 0.0;
        nyWinRate = 0.0;
        overlapWinRate = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Main Statistics Manager Class                                      |
//+------------------------------------------------------------------+
class CV2EABreakoutStatistics : public CV2EAMarketDataBase
{
private:
    //--- State Management
    SStrategyPerformance m_performance;    // Performance tracking
    datetime            m_lastUpdate;      // Last statistics update
    bool               m_isInitialized;    // Initialization state
    
    //--- Configuration
    int                m_minTrades;        // Minimum trades for stats
    int                m_historyDays;      // History analysis period
    double             m_maxDrawdown;      // Maximum allowed drawdown
    double             m_minWinRate;       // Minimum required win rate
    double             m_minProfitFactor;  // Minimum profit factor
    int                m_maxConsecLosses;  // Max consecutive losses
    double             m_confidenceLevel;  // Statistical confidence
    
    //--- Private Methods
    void               UpdatePerformanceMetrics();
    void               CalculateTradeStatistics(const ENUM_PERFORMANCE_PERIOD period);
    void               UpdatePatternPerformance();
    void               UpdateSessionPerformance();
    void               CalculateRiskMetrics();
    double             CalculateSharpeRatio();
    double             CalculateSortinoRatio();
    void               LogPerformanceStatus();
    
protected:
    //--- Protected utility methods
    virtual bool       IsStatisticallySignificant();
    virtual bool       IsPerformanceAcceptable();
    virtual bool       AreRiskMetricsHealthy();
    virtual double     GetStatisticalConfidence();

public:
    //--- Constructor and Destructor
    CV2EABreakoutStatistics(void);
    ~CV2EABreakoutStatistics(void);
    
    //--- Initialization and Configuration
    virtual bool       Initialize(void);
    virtual void       ConfigureStatistics(
                           const int minTrades,
                           const int historyDays,
                           const double maxDD,
                           const double minWR
                       );
    
    //--- Main Statistics Methods
    virtual bool       UpdateStatistics();
    virtual bool       ValidatePerformance();
    virtual bool       CheckHealthMetrics();
    virtual string     GetPerformanceWarnings();
    
    //--- Trade Analysis Methods
    virtual void       OnTradeComplete(
                           const double profit,
                           const int duration,
                           const string pattern
                       );
    virtual void       UpdateDrawdown(const double drawdown);
    virtual void       RecordTradeResult(const ENUM_TRADE_RESULT result);
    
    //--- Performance Analysis Methods
    virtual double     GetWinRate(const ENUM_PERFORMANCE_PERIOD period);
    virtual double     GetProfitFactor(const ENUM_PERFORMANCE_PERIOD period);
    virtual double     GetAverageProfit(const ENUM_PERFORMANCE_PERIOD period);
    virtual int        GetConsecutiveLosses();
    
    //--- Pattern Analysis Methods
    virtual double     GetPatternWinRate(const string pattern);
    virtual double     GetMarketConditionWinRate(const string condition);
    virtual double     GetSessionWinRate(const string session);
    
    //--- Risk Analysis Methods
    virtual double     GetCurrentDrawdown();
    virtual double     GetMaxDrawdown();
    virtual double     GetSharpeRatio();
    virtual double     GetSortinoRatio();
    
    //--- Utility and Information Methods
    virtual void       GetTradeStats(STradeStats &stats, const ENUM_PERFORMANCE_PERIOD period) const;
    virtual void       GetStrategyPerformance(SStrategyPerformance &perf) const;
    virtual string     GetStatisticsReport(void) const;
    virtual bool       ExportStatistics(const string filename);
    virtual bool       ImportStatistics(const string filename);
    
    //--- Event Handlers
    virtual void       OnDrawdownWarning();
    virtual void       OnConsecutiveLossesWarning();
    virtual void       OnProfitFactorWarning();
    virtual void       OnWinRateWarning();
    virtual void       OnStatisticsUpdated();
}; 