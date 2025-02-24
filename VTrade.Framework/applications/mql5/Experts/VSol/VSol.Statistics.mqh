//+------------------------------------------------------------------+
//|                                            VSol.Statistics.mqh    |
//|                        Performance Statistics Implementation      |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include "VSol.Market.mqh"
#include "VSol.Utils.mqh"

class CVSolStatistics : public CVSolMarketBase
{
private:
    // Performance requirements
    static double m_minWinRate;
    static double m_minProfitFactor;
    static int m_minTrades;
    static double m_maxDrawdown;
    
    // Trade tracking
    static int m_totalTrades;
    static int m_winningTrades;
    static double m_totalProfit;
    static double m_totalLoss;
    static double m_currentDrawdown;
    
    // Test period tracking
    static datetime m_optimizationStart;
    static datetime m_optimizationEnd;
    static datetime m_outOfSampleStart;
    static datetime m_outOfSampleEnd;
    static bool m_isInSample;  // true if in optimization period, false if in out-of-sample
    
public:
    static void ConfigureTestPeriods(datetime optimizationStart, datetime optimizationEnd,
                                   datetime outOfSampleStart, datetime outOfSampleEnd)
    {
        m_optimizationStart = optimizationStart;
        m_optimizationEnd = optimizationEnd;
        m_outOfSampleStart = outOfSampleStart;
        m_outOfSampleEnd = outOfSampleEnd;
        
        // Reset statistics for new test
        Reset();
    }
    
    static void ConfigurePerformanceRequirements(double minWinRate, double minProfitFactor, int minTrades, double maxDrawdown)
    {
        m_minWinRate = minWinRate;
        m_minProfitFactor = minProfitFactor;
        m_minTrades = minTrades;
        m_maxDrawdown = maxDrawdown;
    }
    
    static void Reset()
    {
        m_totalTrades = 0;
        m_winningTrades = 0;
        m_totalProfit = 0;
        m_totalLoss = 0;
        m_currentDrawdown = 0;
    }
    
    static void UpdateStats(bool isWin, double profit)
    {
        // Check if we're in the valid testing period
        datetime currentTime = TimeCurrent();
        if(currentTime < m_optimizationStart || currentTime > m_outOfSampleEnd)
            return;
            
        // Update in-sample flag
        m_isInSample = (currentTime >= m_optimizationStart && currentTime <= m_optimizationEnd);
        
        m_totalTrades++;
        if(isWin)
        {
            m_winningTrades++;
            m_totalProfit += profit;
        }
        else
        {
            m_totalLoss += MathAbs(profit);
        }
        
        // Update drawdown
        double equity = m_totalProfit - m_totalLoss;
        double dd = equity < 0 ? MathAbs(equity) / m_totalProfit * 100 : 0;
        m_currentDrawdown = MathMax(m_currentDrawdown, dd);
    }
    
    static bool MeetsPerformanceRequirements()
    {
        if(m_totalTrades < m_minTrades)
            return true;  // Not enough trades to evaluate
            
        double winRate = m_totalTrades > 0 ? (double)m_winningTrades / m_totalTrades * 100 : 0;
        double profitFactor = m_totalLoss > 0 ? m_totalProfit / m_totalLoss : 0;
        
        return winRate >= m_minWinRate &&
               profitFactor >= m_minProfitFactor &&
               m_currentDrawdown <= m_maxDrawdown;
    }
    
    static string GetPerformanceReport()
    {
        string period = m_isInSample ? "Optimization" : "Out-of-Sample";
        string report = StringFormat("=== %s Period Performance ===\n", period);
        report += StringFormat("Total Trades: %d\n", m_totalTrades);
        report += StringFormat("Win Rate: %.2f%%\n", m_totalTrades > 0 ? (double)m_winningTrades / m_totalTrades * 100 : 0);
        report += StringFormat("Profit Factor: %.2f\n", m_totalLoss > 0 ? m_totalProfit / m_totalLoss : 0);
        report += StringFormat("Current Drawdown: %.2f%%\n", m_currentDrawdown);
        return report;
    }
};

// Initialize static members - Performance requirements
double CVSolStatistics::m_minWinRate = 55.0;
double CVSolStatistics::m_minProfitFactor = 1.5;
int CVSolStatistics::m_minTrades = 30;
double CVSolStatistics::m_maxDrawdown = 20.0;

// Initialize static members - Trade tracking
int CVSolStatistics::m_totalTrades = 0;
int CVSolStatistics::m_winningTrades = 0;
double CVSolStatistics::m_totalProfit = 0;
double CVSolStatistics::m_totalLoss = 0;
double CVSolStatistics::m_currentDrawdown = 0;

// Initialize static members - Test period tracking
datetime CVSolStatistics::m_optimizationStart = 0;
datetime CVSolStatistics::m_optimizationEnd = 0;
datetime CVSolStatistics::m_outOfSampleStart = 0;
datetime CVSolStatistics::m_outOfSampleEnd = 0;
bool CVSolStatistics::m_isInSample = true; 