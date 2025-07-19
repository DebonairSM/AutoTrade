/**
 * @brief Advanced optimization analyzer for V-2-EA backtesting results
 * @details Analyzes multiple parameter combinations and provides optimization recommendations
 * Pattern from: Backtrader optimization patterns and MetaTrader analysis
 * Reference: Professional backtesting optimization framework
 */
#property strict

#include <Files/File.mqh>
#include <Arrays/ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Optimization result structure                                      |
//+------------------------------------------------------------------+
struct SOptimizationResult
{
   // Parameters
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   int    lookbackPeriod;
   double minStrength;
   double touchZone;
   int    minTouches;
   double riskPercentage;
   double atrMultiplierSL;
   double atrMultiplierTP;
   bool   useVolumeFilter;
   bool   useRetest;
   int    breakoutLookback;
   double minStrengthThreshold;
   
   // Performance metrics
   double totalReturn;
   double maxDrawdownPercent;
   double sharpeRatio;
   double profitFactor;
   double winRate;
   double calmarRatio;
   double sortinoRatio;
   int    totalTrades;
   double averageWin;
   double averageLoss;
   double volatility;
   
   // Strategy effectiveness
   double breakoutSuccessRate;
   double retestSuccessRate;
   double volumeFilterEffectiveness;
   double atrFilterEffectiveness;
   
   // Ranking metrics
   double overallScore;
   double riskAdjustedScore;
   double consistencyScore;
   int    rank;
};

//+------------------------------------------------------------------+
//| Optimization analysis class                                        |
//+------------------------------------------------------------------+
class CV2EAOptimizationAnalyzer
{
private:
   SOptimizationResult m_results[];
   string m_analysisPath;
   string m_csvExportPath;
   int m_resultCount;
   
   // Analysis thresholds
   double m_minAcceptableReturn;
   double m_maxAcceptableDrawdown;
   double m_minAcceptableSharpe;
   double m_minAcceptableProfitFactor;
   int    m_minAcceptableTrades;
   
   // Weight factors for scoring
   double m_returnWeight;
   double m_drawdownWeight;
   double m_sharpeWeight;
   double m_consistencyWeight;
   double m_tradeCountWeight;

public:
   CV2EAOptimizationAnalyzer();
   ~CV2EAOptimizationAnalyzer();
   
   // Configuration
   void SetAnalysisThresholds(double minReturn, double maxDrawdown, double minSharpe, 
                             double minProfitFactor, int minTrades);
   void SetScoringWeights(double returnWeight, double drawdownWeight, double sharpeWeight,
                         double consistencyWeight, double tradeCountWeight);
   
   // Data loading and analysis
   bool LoadOptimizationResults(const string folderPath);
   bool AddOptimizationResult(const SOptimizationResult &result);
   void AnalyzeResults();
   
   // Ranking and filtering
   void RankResults();
   void FilterResults();
   SOptimizationResult[] GetTopResults(int count);
   SOptimizationResult[] GetResultsByMetric(const string metric, bool descending = true);
   
   // Analysis reports
   void GenerateAnalysisReport();
   void GenerateParameterCorrelationAnalysis();
   void GenerateRobustnessAnalysis();
   void GenerateRecommendationReport();
   void ExportToCSV();
   
   // Parameter analysis
   void AnalyzeParameterRanges();
   void AnalyzeParameterSensitivity();
   void FindOptimalParameterCombinations();
   
   // Getters
   int GetResultCount() const { return m_resultCount; }
   SOptimizationResult GetBestResult() const;
   SOptimizationResult GetMostConsistentResult() const;
   SOptimizationResult GetMostRobustResult() const;

private:
   // Calculation methods
   double CalculateOverallScore(const SOptimizationResult &result);
   double CalculateRiskAdjustedScore(const SOptimizationResult &result);
   double CalculateConsistencyScore(const SOptimizationResult &result);
   
   // Analysis utilities
   void SortResultsByScore();
   double CalculateParameterCorrelation(const string param1, const string param2);
   bool IsResultAcceptable(const SOptimizationResult &result);
   string FormatParameterSet(const SOptimizationResult &result);
   
   // File operations
   bool CreateAnalysisFile();
   void WriteAnalysisEntry(const string message);
   string GetParameterValue(const SOptimizationResult &result, const string paramName);
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CV2EAOptimizationAnalyzer::CV2EAOptimizationAnalyzer() : m_resultCount(0),
                                                       m_minAcceptableReturn(10.0),
                                                       m_maxAcceptableDrawdown(20.0),
                                                       m_minAcceptableSharpe(1.0),
                                                       m_minAcceptableProfitFactor(1.2),
                                                       m_minAcceptableTrades(50),
                                                       m_returnWeight(0.25),
                                                       m_drawdownWeight(0.25),
                                                       m_sharpeWeight(0.25),
                                                       m_consistencyWeight(0.15),
                                                       m_tradeCountWeight(0.10)
{
   ArrayResize(m_results, 0);
   
   // Create file paths
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE) + "_" + TimeToString(TimeCurrent(), TIME_MINUTES);
   StringReplace(timestamp, ":", "");
   StringReplace(timestamp, ".", "");
   StringReplace(timestamp, " ", "_");
   
   m_analysisPath = "V2EA_OptimizationAnalysis_" + timestamp + ".txt";
   m_csvExportPath = "V2EA_OptimizationResults_" + timestamp + ".csv";
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CV2EAOptimizationAnalyzer::~CV2EAOptimizationAnalyzer()
{
   // Cleanup handled automatically for arrays
}

//+------------------------------------------------------------------+
//| Set analysis thresholds                                            |
//+------------------------------------------------------------------+
void CV2EAOptimizationAnalyzer::SetAnalysisThresholds(double minReturn, double maxDrawdown, double minSharpe, 
                                                     double minProfitFactor, int minTrades)
{
   m_minAcceptableReturn = minReturn;
   m_maxAcceptableDrawdown = maxDrawdown;
   m_minAcceptableSharpe = minSharpe;
   m_minAcceptableProfitFactor = minProfitFactor;
   m_minAcceptableTrades = minTrades;
}

//+------------------------------------------------------------------+
//| Set scoring weights                                                |
//+------------------------------------------------------------------+
void CV2EAOptimizationAnalyzer::SetScoringWeights(double returnWeight, double drawdownWeight, double sharpeWeight,
                                                 double consistencyWeight, double tradeCountWeight)
{
   // Normalize weights to sum to 1.0
   double totalWeight = returnWeight + drawdownWeight + sharpeWeight + consistencyWeight + tradeCountWeight;
   
   if(totalWeight > 0)
   {
      m_returnWeight = returnWeight / totalWeight;
      m_drawdownWeight = drawdownWeight / totalWeight;
      m_sharpeWeight = sharpeWeight / totalWeight;
      m_consistencyWeight = consistencyWeight / totalWeight;
      m_tradeCountWeight = tradeCountWeight / totalWeight;
   }
}

//+------------------------------------------------------------------+
//| Add optimization result                                            |
//+------------------------------------------------------------------+
bool CV2EAOptimizationAnalyzer::AddOptimizationResult(const SOptimizationResult &result)
{
   int newSize = ArraySize(m_results) + 1;
   ArrayResize(m_results, newSize);
   m_results[newSize - 1] = result;
   m_resultCount = newSize;
   
   return true;
}

//+------------------------------------------------------------------+
//| Analyze all results                                                |
//+------------------------------------------------------------------+
void CV2EAOptimizationAnalyzer::AnalyzeResults()
{
   if(m_resultCount == 0) return;
   
   Print("🔍 Analyzing ", m_resultCount, " optimization results...");
   
   // Calculate scores for all results
   for(int i = 0; i < m_resultCount; i++)
   {
      m_results[i].overallScore = CalculateOverallScore(m_results[i]);
      m_results[i].riskAdjustedScore = CalculateRiskAdjustedScore(m_results[i]);
      m_results[i].consistencyScore = CalculateConsistencyScore(m_results[i]);
   }
   
   // Rank results
   RankResults();
   
   // Filter acceptable results
   FilterResults();
   
   Print("✅ Analysis complete. Generating reports...");
}

//+------------------------------------------------------------------+
//| Calculate overall score                                            |
//+------------------------------------------------------------------+
double CV2EAOptimizationAnalyzer::CalculateOverallScore(const SOptimizationResult &result)
{
   double score = 0;
   
   // Return component (normalized to 0-100 scale)
   double returnScore = MathMin(100, MathMax(0, result.totalReturn * 2)); // 50% return = 100 points
   score += returnScore * m_returnWeight;
   
   // Drawdown component (inverted - lower is better)
   double drawdownScore = MathMax(0, 100 - (result.maxDrawdownPercent * 5)); // 20% DD = 0 points
   score += drawdownScore * m_drawdownWeight;
   
   // Sharpe ratio component
   double sharpeScore = MathMin(100, MathMax(0, result.sharpeRatio * 50)); // Sharpe 2.0 = 100 points
   score += sharpeScore * m_sharpeWeight;
   
   // Profit factor component
   double pfScore = MathMin(100, MathMax(0, (result.profitFactor - 1.0) * 50)); // PF 3.0 = 100 points
   score += pfScore * m_consistencyWeight;
   
   // Trade count component (ensure sufficient trades)
   double tradeScore = MathMin(100, MathMax(0, (result.totalTrades / 200.0) * 100)); // 200 trades = 100 points
   score += tradeScore * m_tradeCountWeight;
   
   return score;
}

//+------------------------------------------------------------------+
//| Calculate risk-adjusted score                                      |
//+------------------------------------------------------------------+
double CV2EAOptimizationAnalyzer::CalculateRiskAdjustedScore(const SOptimizationResult &result)
{
   if(result.maxDrawdownPercent <= 0) return 0;
   
   // Risk-adjusted return: Return per unit of maximum drawdown
   double riskAdjustedReturn = result.totalReturn / result.maxDrawdownPercent;
   
   // Combine with Sharpe ratio
   double combinedScore = (riskAdjustedReturn * 0.6) + (result.sharpeRatio * 20 * 0.4);
   
   return MathMax(0, combinedScore);
}

//+------------------------------------------------------------------+
//| Calculate consistency score                                        |
//+------------------------------------------------------------------+
double CV2EAOptimizationAnalyzer::CalculateConsistencyScore(const SOptimizationResult &result)
{
   double score = 0;
   
   // Win rate component
   score += (result.winRate / 100.0) * 30; // Max 30 points
   
   // Profit factor component
   score += MathMin(30, (result.profitFactor - 1.0) * 15); // Max 30 points
   
   // Average win/loss ratio
   if(result.averageLoss > 0)
   {
      double winLossRatio = result.averageWin / result.averageLoss;
      score += MathMin(25, winLossRatio * 10); // Max 25 points
   }
   
   // Low volatility bonus
   score += MathMax(0, 15 - (result.volatility * 0.5)); // Max 15 points
   
   return MathMax(0, score);
}

//+------------------------------------------------------------------+
//| Rank all results                                                   |
//+------------------------------------------------------------------+
void CV2EAOptimizationAnalyzer::RankResults()
{
   if(m_resultCount <= 1) return;
   
   // Simple bubble sort by overall score (descending)
   for(int i = 0; i < m_resultCount - 1; i++)
   {
      for(int j = 0; j < m_resultCount - 1 - i; j++)
      {
         if(m_results[j].overallScore < m_results[j + 1].overallScore)
         {
            SOptimizationResult temp = m_results[j];
            m_results[j] = m_results[j + 1];
            m_results[j + 1] = temp;
         }
      }
   }
   
   // Assign ranks
   for(int i = 0; i < m_resultCount; i++)
   {
      m_results[i].rank = i + 1;
   }
}

//+------------------------------------------------------------------+
//| Get top results                                                    |
//+------------------------------------------------------------------+
SOptimizationResult[] CV2EAOptimizationAnalyzer::GetTopResults(int count)
{
   SOptimizationResult topResults[];
   int returnCount = MathMin(count, m_resultCount);
   
   ArrayResize(topResults, returnCount);
   for(int i = 0; i < returnCount; i++)
   {
      topResults[i] = m_results[i];
   }
   
   return topResults;
}

//+------------------------------------------------------------------+
//| Generate comprehensive analysis report                             |
//+------------------------------------------------------------------+
void CV2EAOptimizationAnalyzer::GenerateAnalysisReport()
{
   if(m_resultCount == 0) return;
   
   int fileHandle = FileOpen(m_analysisPath, FILE_WRITE|FILE_TXT);
   if(fileHandle == INVALID_HANDLE)
   {
      Print("❌ Failed to create analysis report file");
      return;
   }
   
   // Write header
   FileWriteString(fileHandle, "=== V-2-EA OPTIMIZATION ANALYSIS REPORT ===\n\n");
   FileWriteString(fileHandle, StringFormat("Analysis Date: %s\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)));
   FileWriteString(fileHandle, StringFormat("Total Results Analyzed: %d\n\n", m_resultCount));
   
   // Executive Summary
   FileWriteString(fileHandle, "EXECUTIVE SUMMARY\n");
   FileWriteString(fileHandle, "=================\n");
   
   if(m_resultCount > 0)
   {
      SOptimizationResult best = m_results[0];
      FileWriteString(fileHandle, StringFormat("Best Overall Score: %.2f\n", best.overallScore));
      FileWriteString(fileHandle, StringFormat("Best Total Return: %.2f%%\n", best.totalReturn));
      FileWriteString(fileHandle, StringFormat("Best Sharpe Ratio: %.2f\n", best.sharpeRatio));
      FileWriteString(fileHandle, StringFormat("Lowest Max Drawdown: %.2f%%\n", best.maxDrawdownPercent));
   }
   
   // Top 10 Results
   FileWriteString(fileHandle, "\nTOP 10 PARAMETER COMBINATIONS\n");
   FileWriteString(fileHandle, "==============================\n");
   
   int topCount = MathMin(10, m_resultCount);
   for(int i = 0; i < topCount; i++)
   {
      SOptimizationResult result = m_results[i];
      FileWriteString(fileHandle, StringFormat(
         "Rank %d: Score=%.1f | Return=%.1f%% | DD=%.1f%% | Sharpe=%.2f | PF=%.2f | Trades=%d\n",
         result.rank, result.overallScore, result.totalReturn, 
         result.maxDrawdownPercent, result.sharpeRatio, result.profitFactor, result.totalTrades
      ));
      FileWriteString(fileHandle, StringFormat("  Parameters: LP=%d, MS=%.2f, TZ=%.4f, Risk=%.1f%%, SL=%.1f, TP=%.1f\n\n",
         result.lookbackPeriod, result.minStrength, result.touchZone,
         result.riskPercentage, result.atrMultiplierSL, result.atrMultiplierTP
      ));
   }
   
   // Parameter Analysis
   FileWriteString(fileHandle, "PARAMETER ANALYSIS\n");
   FileWriteString(fileHandle, "==================\n");
   
   // Find best performing parameter ranges
   FileWriteString(fileHandle, "Optimal Parameter Ranges (based on top 25% results):\n\n");
   
   int top25Count = MathMax(1, m_resultCount / 4);
   
   // Analyze lookback period
   int minLP = 9999, maxLP = 0;
   for(int i = 0; i < top25Count; i++)
   {
      minLP = MathMin(minLP, m_results[i].lookbackPeriod);
      maxLP = MathMax(maxLP, m_results[i].lookbackPeriod);
   }
   FileWriteString(fileHandle, StringFormat("Lookback Period: %d - %d\n", minLP, maxLP));
   
   // Analyze min strength
   double minMS = 999.0, maxMS = 0.0;
   for(int i = 0; i < top25Count; i++)
   {
      minMS = MathMin(minMS, m_results[i].minStrength);
      maxMS = MathMax(maxMS, m_results[i].minStrength);
   }
   FileWriteString(fileHandle, StringFormat("Min Strength: %.2f - %.2f\n", minMS, maxMS));
   
   // Analyze risk percentage
   double minRisk = 999.0, maxRisk = 0.0;
   for(int i = 0; i < top25Count; i++)
   {
      minRisk = MathMin(minRisk, m_results[i].riskPercentage);
      maxRisk = MathMax(maxRisk, m_results[i].riskPercentage);
   }
   FileWriteString(fileHandle, StringFormat("Risk Percentage: %.1f%% - %.1f%%\n", minRisk, maxRisk));
   
   // Recommendations
   FileWriteString(fileHandle, "\nOPTIMIZATION RECOMMENDATIONS\n");
   FileWriteString(fileHandle, "=============================\n");
   
   if(m_resultCount > 0)
   {
      SOptimizationResult best = m_results[0];
      
      FileWriteString(fileHandle, "Recommended Parameter Set (Best Overall):\n");
      FileWriteString(fileHandle, StringFormat("  Lookback Period: %d\n", best.lookbackPeriod));
      FileWriteString(fileHandle, StringFormat("  Min Strength: %.2f\n", best.minStrength));
      FileWriteString(fileHandle, StringFormat("  Touch Zone: %.4f\n", best.touchZone));
      FileWriteString(fileHandle, StringFormat("  Risk Percentage: %.1f%%\n", best.riskPercentage));
      FileWriteString(fileHandle, StringFormat("  ATR SL Multiplier: %.1f\n", best.atrMultiplierSL));
      FileWriteString(fileHandle, StringFormat("  ATR TP Multiplier: %.1f\n", best.atrMultiplierTP));
      FileWriteString(fileHandle, StringFormat("  Use Volume Filter: %s\n", best.useVolumeFilter ? "true" : "false"));
      FileWriteString(fileHandle, StringFormat("  Use Retest: %s\n", best.useRetest ? "true" : "false"));
      
      FileWriteString(fileHandle, StringFormat("\nExpected Performance:\n"));
      FileWriteString(fileHandle, StringFormat("  Annual Return: %.2f%%\n", best.totalReturn));
      FileWriteString(fileHandle, StringFormat("  Maximum Drawdown: %.2f%%\n", best.maxDrawdownPercent));
      FileWriteString(fileHandle, StringFormat("  Sharpe Ratio: %.2f\n", best.sharpeRatio));
      FileWriteString(fileHandle, StringFormat("  Win Rate: %.1f%%\n", best.winRate));
   }
   
   FileClose(fileHandle);
   Print("✅ Analysis report generated: ", m_analysisPath);
}

//+------------------------------------------------------------------+
//| Export results to CSV for external analysis                       |
//+------------------------------------------------------------------+
void CV2EAOptimizationAnalyzer::ExportToCSV()
{
   if(m_resultCount == 0) return;
   
   int csvHandle = FileOpen(m_csvExportPath, FILE_WRITE|FILE_CSV);
   if(csvHandle == INVALID_HANDLE)
   {
      Print("❌ Failed to create CSV export file");
      return;
   }
   
   // Write header
   string header = "Rank,OverallScore,Symbol,Timeframe,LookbackPeriod,MinStrength,TouchZone,MinTouches," +
                   "RiskPercentage,ATRMultiplierSL,ATRMultiplierTP,UseVolumeFilter,UseRetest," +
                   "TotalReturn,MaxDrawdown,SharpeRatio,ProfitFactor,WinRate,TotalTrades," +
                   "AverageWin,AverageLoss,Volatility,BreakoutSuccessRate,RetestSuccessRate";
   
   FileWrite(csvHandle, header);
   
   // Write data
   for(int i = 0; i < m_resultCount; i++)
   {
      SOptimizationResult r = m_results[i];
      
      string dataRow = StringFormat("%d,%.2f,%s,%s,%d,%.2f,%.4f,%d,%.1f,%.1f,%.1f,%s,%s,%.2f,%.2f,%.2f,%.2f,%.1f,%d,%.2f,%.2f,%.2f,%.1f,%.1f",
         r.rank, r.overallScore, r.symbol, EnumToString(r.timeframe),
         r.lookbackPeriod, r.minStrength, r.touchZone, r.minTouches,
         r.riskPercentage, r.atrMultiplierSL, r.atrMultiplierTP,
         r.useVolumeFilter ? "true" : "false", r.useRetest ? "true" : "false",
         r.totalReturn, r.maxDrawdownPercent, r.sharpeRatio, r.profitFactor,
         r.winRate, r.totalTrades, r.averageWin, r.averageLoss, r.volatility,
         r.breakoutSuccessRate, r.retestSuccessRate
      );
      
      FileWrite(csvHandle, dataRow);
   }
   
   FileClose(csvHandle);
   Print("✅ Results exported to CSV: ", m_csvExportPath);
}

//+------------------------------------------------------------------+
//| Get best result                                                    |
//+------------------------------------------------------------------+
SOptimizationResult CV2EAOptimizationAnalyzer::GetBestResult() const
{
   SOptimizationResult empty;
   ZeroMemory(empty);
   
   if(m_resultCount == 0) return empty;
   
   return m_results[0]; // Results are sorted by score
}

//+------------------------------------------------------------------+
//| Filter results by acceptability criteria                          |
//+------------------------------------------------------------------+
void CV2EAOptimizationAnalyzer::FilterResults()
{
   int acceptableCount = 0;
   
   for(int i = 0; i < m_resultCount; i++)
   {
      if(IsResultAcceptable(m_results[i]))
      {
         acceptableCount++;
      }
   }
   
   Print(StringFormat("📊 Acceptable results: %d out of %d (%.1f%%)", 
         acceptableCount, m_resultCount, (double)acceptableCount / m_resultCount * 100.0));
}

//+------------------------------------------------------------------+
//| Check if result meets acceptability criteria                      |
//+------------------------------------------------------------------+
bool CV2EAOptimizationAnalyzer::IsResultAcceptable(const SOptimizationResult &result)
{
   return (result.totalReturn >= m_minAcceptableReturn &&
           result.maxDrawdownPercent <= m_maxAcceptableDrawdown &&
           result.sharpeRatio >= m_minAcceptableSharpe &&
           result.profitFactor >= m_minAcceptableProfitFactor &&
           result.totalTrades >= m_minAcceptableTrades);
} 