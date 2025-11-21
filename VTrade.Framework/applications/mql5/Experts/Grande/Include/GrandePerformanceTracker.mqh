//+------------------------------------------------------------------+
//| GrandePerformanceTracker.mqh                                     |
//| Copyright 2024, Grande Tech                                      |
//| Performance Tracking and Reporting Module                        |
//+------------------------------------------------------------------+
// PURPOSE:
//   Track trade outcomes and generate performance reports for the
//   Grande Trading System. Provides comprehensive performance analysis.
//
// RESPONSIBILITIES:
//   - Track trade outcomes (TP hits, SL hits, trailing stops)
//   - Calculate win rates by signal type, symbol, regime
//   - Track performance over time periods
//   - Generate performance reports
//   - Identify performance patterns
//
// DEPENDENCIES:
//   - GrandeDatabaseManager.mqh - For storing performance data
//   - GrandeProfitCalculator.mqh - For profit calculations
//
// STATE MANAGED:
//   - Performance metrics cache
//   - Last report generation time
//   - Performance statistics
//
// PUBLIC INTERFACE:
//   bool Initialize(symbol, dbManager, profitCalculator)
//   void RecordTradeOutcome(ticket, outcome, closePrice) - Log trade result
//   double CalculateWinRate(signalType, symbol, regime) - Win rate by category
//   PerformanceByCategory GetPerformanceBySignalType() - Signal type analysis
//   PerformanceByCategory GetPerformanceBySymbol() - Symbol performance
//   PerformanceByCategory GetPerformanceByRegime() - Regime-based performance
//   string GeneratePerformanceReport() - Comprehensive report
//
// DATA STRUCTURES:
//   TradeOutcome - Structure for trade outcome data
//   PerformanceByCategory - Structure for categorized performance
//
// IMPLEMENTATION NOTES:
//   - Integrates with database for persistent storage
//   - Uses profit calculator for consistent calculations
//   - Caches performance metrics for quick access
//   - Generates reports in markdown format
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestPerformanceTracker.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Performance tracking and reporting module"

#include "GrandeDatabaseManager.mqh"
#include "GrandeProfitCalculator.mqh"

//+------------------------------------------------------------------+
//| Trade Outcome Structure                                           |
//+------------------------------------------------------------------+
struct TradeOutcome
{
    ulong ticket;                  // Position ticket
    string symbol;                 // Trading symbol
    string signalType;             // Signal type (TREND, BREAKOUT, RANGE)
    string direction;              // BUY or SELL
    double entryPrice;             // Entry price
    double closePrice;             // Close price
    double stopLoss;               // Stop loss price
    double takeProfit;             // Take profit price
    double profitPips;             // Profit in pips
    double profitCurrency;         // Profit in currency
    string outcome;                // TP_HIT, SL_HIT, TRAILING_STOP, MANUAL_CLOSE
    datetime entryTime;            // Entry time
    datetime closeTime;            // Close time
    int durationMinutes;           // Trade duration in minutes
    string regime;                 // Market regime at entry
    double regimeConfidence;       // Regime confidence at entry
    
    void TradeOutcome()
    {
        ticket = 0;
        symbol = "";
        signalType = "";
        direction = "";
        entryPrice = 0.0;
        closePrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        profitPips = 0.0;
        profitCurrency = 0.0;
        outcome = "";
        entryTime = 0;
        closeTime = 0;
        durationMinutes = 0;
        regime = "";
        regimeConfidence = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Performance By Category Structure                                 |
//+------------------------------------------------------------------+
struct PerformanceByCategory
{
    string category;               // Category name (signal type, symbol, regime)
    int totalTrades;               // Total trades
    int winningTrades;             // Winning trades
    int losingTrades;              // Losing trades
    double winRate;                // Win rate percentage
    double totalProfitPips;        // Total profit in pips
    double totalLossPips;          // Total loss in pips
    double averageWinPips;         // Average win in pips
    double averageLossPips;        // Average loss in pips
    double profitFactor;           // Profit factor
    double largestWinPips;         // Largest win in pips
    double largestLossPips;        // Largest loss in pips
    
    void PerformanceByCategory()
    {
        category = "";
        totalTrades = 0;
        winningTrades = 0;
        losingTrades = 0;
        winRate = 0.0;
        totalProfitPips = 0.0;
        totalLossPips = 0.0;
        averageWinPips = 0.0;
        averageLossPips = 0.0;
        profitFactor = 0.0;
        largestWinPips = 0.0;
        largestLossPips = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Grande Performance Tracker Class                                 |
//+------------------------------------------------------------------+
class CGrandePerformanceTracker
{
private:
    string m_symbol;
    bool m_isInitialized;
    CGrandeDatabaseManager* m_dbManager;
    CGrandeProfitCalculator* m_profitCalculator;
    
    // Performance cache
    PerformanceByCategory m_signalTypePerf[];
    PerformanceByCategory m_symbolPerf[];
    PerformanceByCategory m_regimePerf[];
    datetime m_lastCacheUpdate;
    int m_cacheValiditySeconds;
    
    // Helper methods
    void UpdatePerformanceCache();
    bool IsCacheValid();
    PerformanceByCategory CalculateCategoryPerformance(string category, string categoryType);
    
public:
    // Constructor/Destructor
    CGrandePerformanceTracker();
    ~CGrandePerformanceTracker();
    
    // Initialization
    bool Initialize(string symbol, CGrandeDatabaseManager* dbManager, CGrandeProfitCalculator* profitCalculator);
    
    // Trade Outcome Recording
    void RecordTradeOutcome(ulong ticket, string outcome, double closePrice);
    void RecordTradeOutcome(const TradeOutcome &outcome);
    
    // Performance Calculations
    double CalculateWinRate(string signalType = "", string symbol = "", string regime = "");
    PerformanceByCategory GetPerformanceBySignalType(string signalType = "");
    PerformanceByCategory GetPerformanceBySymbol(string symbol = "");
    PerformanceByCategory GetPerformanceByRegime(string regime = "");
    
    // Report Generation
    string GeneratePerformanceReport(int days = 30);
    string GeneratePerformanceSummary();
    
    // Utility Methods
    int GetTotalTrades(string signalType = "", string symbol = "", string regime = "");
    int GetWinningTrades(string signalType = "", string symbol = "", string regime = "");
    int GetLosingTrades(string signalType = "", string symbol = "", string regime = "");
    double GetTotalProfitPips(string signalType = "", string symbol = "", string regime = "");
    double GetTotalLossPips(string signalType = "", string symbol = "", string regime = "");
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandePerformanceTracker::CGrandePerformanceTracker()
{
    m_symbol = "";
    m_isInitialized = false;
    m_dbManager = NULL;
    m_profitCalculator = NULL;
    m_lastCacheUpdate = 0;
    m_cacheValiditySeconds = 300; // 5 minutes
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CGrandePerformanceTracker::~CGrandePerformanceTracker()
{
}

//+------------------------------------------------------------------+
//| Initialize Performance Tracker                                   |
//+------------------------------------------------------------------+
// PURPOSE:
//   Initialize the performance tracker with required dependencies.
//
// PARAMETERS:
//   symbol (string) - Trading symbol
//   dbManager (CGrandeDatabaseManager*) - Database manager instance
//   profitCalculator (CGrandeProfitCalculator*) - Profit calculator instance
//
// RETURNS:
//   (bool) - true if initialization successful, false otherwise
//
// SIDE EFFECTS:
//   - Sets internal references to dependencies
//
// ERROR CONDITIONS:
//   - Returns false if symbol is empty
//   - Returns false if dbManager is NULL
//   - Returns false if profitCalculator is NULL
//+------------------------------------------------------------------+
bool CGrandePerformanceTracker::Initialize(string symbol, CGrandeDatabaseManager* dbManager, CGrandeProfitCalculator* profitCalculator)
{
    if(symbol == "")
    {
        Print("[GrandePerformance] ERROR: Invalid symbol");
        return false;
    }
    
    if(dbManager == NULL)
    {
        Print("[GrandePerformance] ERROR: Database manager is NULL");
        return false;
    }
    
    if(profitCalculator == NULL)
    {
        Print("[GrandePerformance] ERROR: Profit calculator is NULL");
        return false;
    }
    
    m_symbol = symbol;
    m_dbManager = dbManager;
    m_profitCalculator = profitCalculator;
    m_isInitialized = true;
    
    return true;
}

//+------------------------------------------------------------------+
//| Record Trade Outcome                                              |
//+------------------------------------------------------------------+
// PURPOSE:
//   Record a trade outcome for performance tracking.
//
// PARAMETERS:
//   ticket (ulong) - Position ticket number
//   outcome (string) - Outcome type (TP_HIT, SL_HIT, TRAILING_STOP, MANUAL_CLOSE)
//   closePrice (double) - Price at which position was closed
//
// SIDE EFFECTS:
//   - Records outcome in database
//   - Invalidates performance cache
//
// ERROR CONDITIONS:
//   - Returns early if not initialized
//   - Returns early if position not found
//+------------------------------------------------------------------+
void CGrandePerformanceTracker::RecordTradeOutcome(ulong ticket, string outcome, double closePrice)
{
    if(!m_isInitialized)
        return;
    
    if(!PositionSelectByTicket(ticket))
        return;
    
    TradeOutcome tradeOutcome;
    tradeOutcome.ticket = ticket;
    tradeOutcome.symbol = PositionGetString(POSITION_SYMBOL);
    tradeOutcome.direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
    tradeOutcome.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    tradeOutcome.closePrice = closePrice;
    tradeOutcome.stopLoss = PositionGetDouble(POSITION_SL);
    tradeOutcome.takeProfit = PositionGetDouble(POSITION_TP);
    tradeOutcome.outcome = outcome;
    tradeOutcome.entryTime = (datetime)PositionGetInteger(POSITION_TIME);
    tradeOutcome.closeTime = TimeCurrent();
    
    // Calculate profit
    if(m_profitCalculator != NULL)
    {
        tradeOutcome.profitPips = m_profitCalculator.CalculatePositionProfitPips(ticket, closePrice);
        tradeOutcome.profitCurrency = m_profitCalculator.CalculatePositionProfitCurrency(ticket, closePrice);
    }
    
    // Calculate duration
    tradeOutcome.durationMinutes = (int)((tradeOutcome.closeTime - tradeOutcome.entryTime) / 60);
    
    RecordTradeOutcome(tradeOutcome);
}

//+------------------------------------------------------------------+
//| Record Trade Outcome (with structure)                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Record a trade outcome using a TradeOutcome structure.
//
// PARAMETERS:
//   outcome (TradeOutcome) - Complete trade outcome data
//
// SIDE EFFECTS:
//   - Records outcome in database
//   - Invalidates performance cache
//+------------------------------------------------------------------+
void CGrandePerformanceTracker::RecordTradeOutcome(const TradeOutcome &outcome)
{
    if(!m_isInitialized || m_dbManager == NULL)
        return;
    
    // Record in database
    // Note: This would require database schema for trade outcomes
    // For now, this is a placeholder for future implementation
    
    // Invalidate cache
    m_lastCacheUpdate = 0;
}

//+------------------------------------------------------------------+
//| Calculate Win Rate                                                |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate win rate for trades matching the specified filters.
//
// PARAMETERS:
//   signalType (string) - Filter by signal type (empty for all)
//   symbol (string) - Filter by symbol (empty for all)
//   regime (string) - Filter by regime (empty for all)
//
// RETURNS:
//   (double) - Win rate percentage (0-100)
//
// NOTES:
//   - Requires database access for historical data
//   - Returns 0.0 if no trades found
//+------------------------------------------------------------------+
double CGrandePerformanceTracker::CalculateWinRate(string signalType = "", string symbol = "", string regime = "")
{
    if(!m_isInitialized)
        return 0.0;
    
    int totalTrades = GetTotalTrades(signalType, symbol, regime);
    if(totalTrades == 0)
        return 0.0;
    
    int winningTrades = GetWinningTrades(signalType, symbol, regime);
    return (double)winningTrades / totalTrades * 100.0;
}

//+------------------------------------------------------------------+
//| Get Performance By Signal Type                                    |
//+------------------------------------------------------------------+
// PURPOSE:
//   Get performance metrics for a specific signal type.
//
// PARAMETERS:
//   signalType (string) - Signal type (empty for all signal types)
//
// RETURNS:
//   (PerformanceByCategory) - Performance metrics for the signal type
//+------------------------------------------------------------------+
PerformanceByCategory CGrandePerformanceTracker::GetPerformanceBySignalType(string signalType = "")
{
    if(!IsCacheValid())
        UpdatePerformanceCache();
    
    // Search cache for matching signal type
    for(int i = 0; i < ArraySize(m_signalTypePerf); i++)
    {
        if(signalType == "" || m_signalTypePerf[i].category == signalType)
            return m_signalTypePerf[i];
    }
    
    // Return empty if not found
    PerformanceByCategory empty;
    return empty;
}

//+------------------------------------------------------------------+
//| Get Performance By Symbol                                         |
//+------------------------------------------------------------------+
// PURPOSE:
//   Get performance metrics for a specific symbol.
//
// PARAMETERS:
//   symbol (string) - Symbol (empty for all symbols)
//
// RETURNS:
//   (PerformanceByCategory) - Performance metrics for the symbol
//+------------------------------------------------------------------+
PerformanceByCategory CGrandePerformanceTracker::GetPerformanceBySymbol(string symbol = "")
{
    if(!IsCacheValid())
        UpdatePerformanceCache();
    
    // Search cache for matching symbol
    for(int i = 0; i < ArraySize(m_symbolPerf); i++)
    {
        if(symbol == "" || m_symbolPerf[i].category == symbol)
            return m_symbolPerf[i];
    }
    
    // Return empty if not found
    PerformanceByCategory empty;
    return empty;
}

//+------------------------------------------------------------------+
//| Get Performance By Regime                                         |
//+------------------------------------------------------------------+
// PURPOSE:
//   Get performance metrics for a specific market regime.
//
// PARAMETERS:
//   regime (string) - Market regime (empty for all regimes)
//
// RETURNS:
//   (PerformanceByCategory) - Performance metrics for the regime
//+------------------------------------------------------------------+
PerformanceByCategory CGrandePerformanceTracker::GetPerformanceByRegime(string regime = "")
{
    if(!IsCacheValid())
        UpdatePerformanceCache();
    
    // Search cache for matching regime
    for(int i = 0; i < ArraySize(m_regimePerf); i++)
    {
        if(regime == "" || m_regimePerf[i].category == regime)
            return m_regimePerf[i];
    }
    
    // Return empty if not found
    PerformanceByCategory empty;
    return empty;
}

//+------------------------------------------------------------------+
//| Generate Performance Report                                       |
//+------------------------------------------------------------------+
// PURPOSE:
//   Generate a comprehensive performance report for the specified period.
//
// PARAMETERS:
//   days (int) - Number of days to analyze (default: 30)
//
// RETURNS:
//   (string) - Formatted performance report in markdown format
//
// NOTES:
//   - Report includes overall metrics, signal type performance, symbol performance
//   - Requires database access for historical data
//+------------------------------------------------------------------+
string CGrandePerformanceTracker::GeneratePerformanceReport(int days = 30)
{
    if(!m_isInitialized)
        return "Performance tracker not initialized";
    
    string report = "# Grande Trading System - Performance Report\n\n";
    report += "**Generated:** " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
    report += "**Analysis Period:** Last " + IntegerToString(days) + " days\n\n";
    
    report += "## Executive Summary\n\n";
    report += GeneratePerformanceSummary();
    report += "\n";
    
    // Add signal type performance
    report += "## Signal Type Performance\n\n";
    report += "| Signal Type | Trades | Wins | Losses | Win Rate | Total Pips |\n";
    report += "|-------------|--------|------|--------|----------|------------|\n";
    
    // This would query database for signal type performance
    // Placeholder for now
    
    report += "\n";
    
    // Add symbol performance
    report += "## Symbol Performance\n\n";
    report += "| Symbol | Trades | Wins | Losses | Win Rate | Total Pips |\n";
    report += "|--------|--------|------|--------|----------|------------|\n";
    
    // This would query database for symbol performance
    // Placeholder for now
    
    report += "\n";
    
    return report;
}

//+------------------------------------------------------------------+
//| Generate Performance Summary                                      |
//+------------------------------------------------------------------+
// PURPOSE:
//   Generate a summary of overall performance metrics.
//
// RETURNS:
//   (string) - Formatted summary string
//+------------------------------------------------------------------+
string CGrandePerformanceTracker::GeneratePerformanceSummary()
{
    int totalTrades = GetTotalTrades();
    int winningTrades = GetWinningTrades();
    int losingTrades = GetLosingTrades();
    double winRate = CalculateWinRate();
    double totalProfitPips = GetTotalProfitPips();
    double totalLossPips = GetTotalLossPips();
    double profitFactor = (totalLossPips > 0) ? (totalProfitPips / totalLossPips) : 0.0;
    
    string summary = "| Metric | Value |\n";
    summary += "|--------|-------|\n";
    summary += "| Total Trades | " + IntegerToString(totalTrades) + " |\n";
    summary += "| Winning Trades | " + IntegerToString(winningTrades) + " |\n";
    summary += "| Losing Trades | " + IntegerToString(losingTrades) + " |\n";
    summary += "| Win Rate | " + DoubleToString(winRate, 2) + "% |\n";
    summary += "| Total Profit | " + DoubleToString(totalProfitPips, 1) + " pips |\n";
    summary += "| Total Loss | " + DoubleToString(totalLossPips, 1) + " pips |\n";
    summary += "| Profit Factor | " + DoubleToString(profitFactor, 2) + " |\n";
    
    return summary;
}

//+------------------------------------------------------------------+
//| Check if Cache is Valid                                           |
//+------------------------------------------------------------------+
bool CGrandePerformanceTracker::IsCacheValid()
{
    if(m_lastCacheUpdate == 0)
        return false;
    
    return (TimeCurrent() - m_lastCacheUpdate) < m_cacheValiditySeconds;
}

//+------------------------------------------------------------------+
//| Update Performance Cache                                          |
//+------------------------------------------------------------------+
void CGrandePerformanceTracker::UpdatePerformanceCache()
{
    // This would query database and update cache
    // Placeholder for now
    m_lastCacheUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Calculate Category Performance                                    |
//+------------------------------------------------------------------+
PerformanceByCategory CGrandePerformanceTracker::CalculateCategoryPerformance(string category, string categoryType)
{
    PerformanceByCategory perf;
    perf.category = category;
    
    // This would query database for category performance
    // Placeholder for now
    
    return perf;
}

//+------------------------------------------------------------------+
//| Get Total Trades                                                  |
//+------------------------------------------------------------------+
int CGrandePerformanceTracker::GetTotalTrades(string signalType = "", string symbol = "", string regime = "")
{
    // This would query database
    // Placeholder - return 0 for now
    return 0;
}

//+------------------------------------------------------------------+
//| Get Winning Trades                                                |
//+------------------------------------------------------------------+
int CGrandePerformanceTracker::GetWinningTrades(string signalType = "", string symbol = "", string regime = "")
{
    // This would query database
    // Placeholder - return 0 for now
    return 0;
}

//+------------------------------------------------------------------+
//| Get Losing Trades                                                 |
//+------------------------------------------------------------------+
int CGrandePerformanceTracker::GetLosingTrades(string signalType = "", string symbol = "", string regime = "")
{
    // This would query database
    // Placeholder - return 0 for now
    return 0;
}

//+------------------------------------------------------------------+
//| Get Total Profit Pips                                             |
//+------------------------------------------------------------------+
double CGrandePerformanceTracker::GetTotalProfitPips(string signalType = "", string symbol = "", string regime = "")
{
    // This would query database
    // Placeholder - return 0.0 for now
    return 0.0;
}

//+------------------------------------------------------------------+
//| Get Total Loss Pips                                               |
//+------------------------------------------------------------------+
double CGrandePerformanceTracker::GetTotalLossPips(string signalType = "", string symbol = "", string regime = "")
{
    // This would query database
    // Placeholder - return 0.0 for now
    return 0.0;
}

//+------------------------------------------------------------------+

