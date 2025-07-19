/**
 * @brief Performance logging and analysis system for V-2-EA
 * @details Comprehensive metrics collection for backtesting optimization
 * Pattern from: Backtrader optimization patterns
 * Reference: Professional backtesting analysis framework
 */
#property strict

#include <Files/File.mqh>
#include <Generic/HashMap.mqh>

//+------------------------------------------------------------------+
//| Performance metrics structure                                     |
//+------------------------------------------------------------------+
struct SPerformanceMetrics
{
   // Trade Statistics
   int    totalTrades;
   int    winningTrades;
   int    losingTrades;
   double winRate;
   double profitFactor;
   double expectedValue;
   
   // Return Metrics
   double totalReturn;
   double annualizedReturn;
   double maxDrawdown;
   double maxDrawdownPercent;
   double sharpeRatio;
   double calmarRatio;
   double sortinoRatio;
   
   // Risk Metrics
   double averageWin;
   double averageLoss;
   double largestWin;
   double largestLoss;
   double averageRiskReward;
   double volatility;
   
   // Trade Timing
   double averageWinTime;
   double averageLossTime;
   double averageTradeTime;
   
   // Drawdown Analysis
   double currentDrawdown;
   int    maxDrawdownDuration;
   int    currentDrawdownDuration;
   datetime maxDrawdownStart;
   datetime maxDrawdownEnd;
   
   // Monthly/Weekly Analysis
   double monthlyReturns[12];
   double weeklyWinRate;
   double monthlyWinRate;
   
   // Strategy Specific
   double breakoutSuccessRate;
   double retestSuccessRate;
   double volumeFilterEffectiveness;
   double atrFilterEffectiveness;
};

//+------------------------------------------------------------------+
//| Trade data structure for detailed analysis                        |
//+------------------------------------------------------------------+
struct STradeRecord
{
   datetime openTime;
   datetime closeTime;
   double   openPrice;
   double   closePrice;
   double   stopLoss;
   double   takeProfit;
   double   lotSize;
   double   profit;
   double   commission;
   double   swap;
   string   direction; // "BUY" or "SELL"
   string   exitReason; // "TP", "SL", "MANUAL", "TIMEOUT"
   double   breakoutLevel;
   bool     wasRetest;
   double   atrAtEntry;
   double   volumeAtEntry;
   double   maxFavorableExcursion;
   double   maxAdverseExcursion;
   int      barsInTrade;
   double   riskRewardRatio;
};

//+------------------------------------------------------------------+
//| Optimization parameters tracking                                   |
//+------------------------------------------------------------------+
struct SOptimizationParameters
{
   // Strategy Parameters
   int    lookbackPeriod;
   double minStrength;
   double touchZone;
   int    minTouches;
   
   // Trading Parameters
   double riskPercentage;
   double atrMultiplierSL;
   double atrMultiplierTP;
   bool   useVolumeFilter;
   bool   useRetest;
   
   // Breakout Parameters
   int    breakoutLookback;
   double minStrengthThreshold;
   double retestATRMultiplier;
   double retestPipsThreshold;
   
   // Time-based
   datetime optimizationStart;
   datetime optimizationEnd;
   string   symbol;
   ENUM_TIMEFRAMES timeframe;
};

//+------------------------------------------------------------------+
//| Main performance logger class                                     |
//+------------------------------------------------------------------+
class CV2EAPerformanceLogger
{
private:
   string m_logPath;
   string m_csvPath;
   string m_reportPath;
   CHashMap<string,double> *m_metrics;
   STradeRecord m_trades[];
   SPerformanceMetrics m_performance;
   SOptimizationParameters m_params;
   
   // Internal tracking
   double m_initialBalance;
   double m_currentBalance;
   double m_peakBalance;
   double m_troughBalance;
   datetime m_lastUpdateTime;
   
   // File handles
   int m_logFileHandle;
   int m_csvFileHandle;
   bool m_isInitialized;
   
   // Analysis variables
   double m_dailyReturns[];
   int m_tradesToday;
   datetime m_lastTradeDate;

public:
   CV2EAPerformanceLogger();
   ~CV2EAPerformanceLogger();
   
   // Initialization and cleanup
   bool Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, const SOptimizationParameters &params);
   void Deinitialize();
   
   // Trade logging
   void LogTradeOpen(const datetime openTime, const double openPrice, const double lotSize, 
                    const string direction, const double stopLoss, const double takeProfit,
                    const double breakoutLevel, const bool wasRetest, const double atrValue, const double volume);
   void LogTradeClose(const datetime closeTime, const double closePrice, const double profit,
                     const double commission, const double swap, const string exitReason);
   void LogTradeUpdate(const double currentPrice, const double mfe, const double mae);
   
   // Performance tracking
   void UpdateBalance(const double newBalance);
   void UpdateDrawdown();
   void CalculateMetrics();
   void LogDailyUpdate();
   
   // Analysis and reporting
   void GenerateDetailedReport();
   void GenerateCSVReport();
   void PrintPerformanceSummary();
   void LogOptimizationResult();
   
   // Getters
   SPerformanceMetrics GetMetrics() const { return m_performance; }
   double GetSharpeRatio() const { return m_performance.sharpeRatio; }
   double GetMaxDrawdown() const { return m_performance.maxDrawdown; }
   double GetProfitFactor() const { return m_performance.profitFactor; }
   
   // Strategy-specific logging
   void LogBreakoutAttempt(const double level, const bool successful);
   void LogRetestAttempt(const double level, const bool successful);
   void LogVolumeFilterResult(const bool passed);
   void LogATRFilterResult(const bool passed);
   
private:
   // Internal calculation methods
   void CalculateSharpeRatio();
   void CalculateDrawdownMetrics();
   void CalculateTradeStatistics();
   void CalculateRiskMetrics();
   void CalculateTimeBasedMetrics();
   
   // File operations
   bool CreateLogFile();
   bool CreateCSVFile();
   void WriteLogEntry(const string message);
   void WriteCSVEntry(const string data);
   
   // Utility methods
   string FormatDateTime(const datetime dt);
   string FormatDouble(const double value, const int digits = 2);
   double CalculateStandardDeviation(const double &values[]);
   void ResizeTradeArray();
   string ParametersToString();
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CV2EAPerformanceLogger::CV2EAPerformanceLogger() : m_isInitialized(false),
                                                   m_logFileHandle(INVALID_HANDLE),
                                                   m_csvFileHandle(INVALID_HANDLE),
                                                   m_initialBalance(0),
                                                   m_currentBalance(0),
                                                   m_peakBalance(0),
                                                   m_troughBalance(0),
                                                   m_tradesToday(0)
{
   m_metrics = new CHashMap<string,double>();
   ZeroMemory(m_performance);
   ZeroMemory(m_params);
   ArrayResize(m_trades, 0);
   ArrayResize(m_dailyReturns, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CV2EAPerformanceLogger::~CV2EAPerformanceLogger()
{
   Deinitialize();
   if(m_metrics != NULL)
   {
      delete m_metrics;
      m_metrics = NULL;
   }
}

//+------------------------------------------------------------------+
//| Initialize the performance logger                                  |
//+------------------------------------------------------------------+
bool CV2EAPerformanceLogger::Initialize(const string symbol, const ENUM_TIMEFRAMES timeframe, 
                                       const SOptimizationParameters &params)
{
   if(m_isInitialized)
      return true;
      
   m_params = params;
   m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_currentBalance = m_initialBalance;
   m_peakBalance = m_initialBalance;
   m_troughBalance = m_initialBalance;
   m_lastUpdateTime = TimeCurrent();
   
   // Create file paths with enhanced timestamp for uniqueness
   datetime currentTime = TimeCurrent();
   ulong microseconds = GetMicrosecondCount();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Create unique timestamp: YYYYMMDD_HHMMSS_microseconds
   string timestamp = StringFormat("%04d%02d%02d_%02d%02d%02d_%06d", 
      dt.year, dt.mon, dt.day,
      dt.hour, dt.min, dt.sec,
      (int)(microseconds % 1000000)); // Last 6 digits of microseconds for uniqueness
   
   m_logPath = "V2EA_Performance_" + symbol + "_" + EnumToString(timeframe) + "_" + timestamp + ".log";
   m_csvPath = "V2EA_Trades_" + symbol + "_" + EnumToString(timeframe) + "_" + timestamp + ".csv";
   m_reportPath = "V2EA_Report_" + symbol + "_" + EnumToString(timeframe) + "_" + timestamp + ".txt";
   
   // *** FILENAME VERIFICATION ***
   Print("🔍 VERIFYING UNIQUE FILENAMES:");
   Print("📝 LOG FILE: ", m_logPath);
   Print("📊 CSV FILE: ", m_csvPath);  
   Print("📋 REPORT FILE: ", m_reportPath);
   Print("🕒 TIMESTAMP USED: ", timestamp);
   Print("📁 Files will be created in: MetaTrader 5\\MQL5\\Files\\");
   Print("⚠️  NOTE: MT5 system logs (20250119.log) are DIFFERENT from our custom files!");
   
   // Initialize metrics
   m_metrics.Clear();
   
   // Create log files
   if(!CreateLogFile() || !CreateCSVFile())
   {
      Print("❌ Failed to create performance log files");
      return false;
   }
   
   // Log initialization
   WriteLogEntry("=== V-2-EA Performance Logger Initialized ===");
   WriteLogEntry("Symbol: " + symbol);
   WriteLogEntry("Timeframe: " + EnumToString(timeframe));
   WriteLogEntry("Start Time: " + FormatDateTime(TimeCurrent()));
   WriteLogEntry("Initial Balance: " + FormatDouble(m_initialBalance));
   WriteLogEntry("Optimization Parameters: " + ParametersToString());
   
   m_isInitialized = true;
   Print("✅ Performance logger initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Create log file                                                    |
//+------------------------------------------------------------------+
bool CV2EAPerformanceLogger::CreateLogFile()
{
   // Pattern from: MQL5 Programming Reference
   // Reference: Write Data to CSV File section
   m_logFileHandle = FileOpen(m_logPath, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(m_logFileHandle == INVALID_HANDLE)
   {
      Print("❌ Failed to create log file: ", m_logPath, " Error: ", GetLastError());
      return false;
   }
   
   // Confirm new file creation
   Print("✅ NEW LOG FILE CREATED: ", m_logPath);
   return true;
}

//+------------------------------------------------------------------+
//| Create CSV file                                                    |
//+------------------------------------------------------------------+
bool CV2EAPerformanceLogger::CreateCSVFile()
{
   // Pattern from: MQL5 Programming Reference
   // Reference: Write Data to CSV File section
   m_csvFileHandle = FileOpen(m_csvPath, FILE_WRITE|FILE_CSV|FILE_COMMON);
   if(m_csvFileHandle == INVALID_HANDLE)
   {
      Print("❌ Failed to create CSV file: ", m_csvPath, " Error: ", GetLastError());
      return false;
   }
   
   // Confirm new file creation
   Print("✅ NEW CSV FILE CREATED: ", m_csvPath);
   
   // Write CSV header
   string header = "OpenTime,CloseTime,Direction,OpenPrice,ClosePrice,LotSize,Profit,Commission,Swap," +
                   "StopLoss,TakeProfit,ExitReason,BreakoutLevel,WasRetest,ATRAtEntry,VolumeAtEntry," +
                   "MFE,MAE,BarsInTrade,RiskReward,TradeNumber";
   
   FileWrite(m_csvFileHandle, header);
   return true;
}

//+------------------------------------------------------------------+
//| Log trade opening                                                  |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::LogTradeOpen(const datetime openTime, const double openPrice, const double lotSize,
                                         const string direction, const double stopLoss, const double takeProfit,
                                         const double breakoutLevel, const bool wasRetest, const double atrValue, const double volume)
{
   if(!m_isInitialized) return;
   
   // Resize array if needed
   ResizeTradeArray();
   
   int tradeIndex = ArraySize(m_trades) - 1;
   
   // Fill trade record
   m_trades[tradeIndex].openTime = openTime;
   m_trades[tradeIndex].openPrice = openPrice;
   m_trades[tradeIndex].lotSize = lotSize;
   m_trades[tradeIndex].direction = direction;
   m_trades[tradeIndex].stopLoss = stopLoss;
   m_trades[tradeIndex].takeProfit = takeProfit;
   m_trades[tradeIndex].breakoutLevel = breakoutLevel;
   m_trades[tradeIndex].wasRetest = wasRetest;
   m_trades[tradeIndex].atrAtEntry = atrValue;
   m_trades[tradeIndex].volumeAtEntry = volume;
   m_trades[tradeIndex].maxFavorableExcursion = 0;
   m_trades[tradeIndex].maxAdverseExcursion = 0;
   
   // Log to file
   string logMsg = StringFormat("TRADE OPEN: %s %s %.2f lots at %.5f | SL: %.5f TP: %.5f | Breakout: %.5f | Retest: %s",
                               direction, _Symbol, lotSize, openPrice, stopLoss, takeProfit, breakoutLevel, 
                               wasRetest ? "YES" : "NO");
   WriteLogEntry(logMsg);
   
   // Update daily trade count
   datetime today = TimeCurrent();
   
   MqlDateTime todayStruct, lastTradeDateStruct;
   TimeToStruct(today, todayStruct);
   TimeToStruct(m_lastTradeDate, lastTradeDateStruct);
   
   if(todayStruct.day != lastTradeDateStruct.day || m_lastTradeDate == 0)
   {
      m_tradesToday = 1;
      m_lastTradeDate = today;
   }
   else
   {
      m_tradesToday++;
   }
}

//+------------------------------------------------------------------+
//| Log trade closing                                                  |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::LogTradeClose(const datetime closeTime, const double closePrice, const double profit,
                                          const double commission, const double swap, const string exitReason)
{
   if(!m_isInitialized || ArraySize(m_trades) == 0) return;
   
   // BACKUP VALIDATION: Sanitize input values to prevent astronomical numbers
   const double MAX_REASONABLE_VALUE = 1000.0; // $1K max per trade
   const double MIN_REASONABLE_VALUE = -1000.0; // -$1K min per trade
   
   double validatedProfit = profit;
   double validatedCommission = commission;
   double validatedSwap = swap;
   bool wasCorrupted = false;
   
   if(profit > MAX_REASONABLE_VALUE || profit < MIN_REASONABLE_VALUE)
   {
      Print(StringFormat("⚠️ PERFORMANCE LOGGER: Corrupted profit %.2f, resetting to 0", profit));
      validatedProfit = 0;
      wasCorrupted = true;
   }
   
   if(commission > MAX_REASONABLE_VALUE || commission < MIN_REASONABLE_VALUE)
   {
      Print(StringFormat("⚠️ PERFORMANCE LOGGER: Corrupted commission %.2f, resetting to 0", commission));
      validatedCommission = 0;
      wasCorrupted = true;
   }
   
   if(swap > MAX_REASONABLE_VALUE || swap < MIN_REASONABLE_VALUE)
   {
      Print(StringFormat("⚠️ PERFORMANCE LOGGER: Corrupted swap %.2f, resetting to 0", swap));
      validatedSwap = 0;
      wasCorrupted = true;
   }
   
   if(wasCorrupted)
   {
      Print(StringFormat("📊 TRADE DATA SANITIZED: Using P/L=%.2f, Commission=%.2f, Swap=%.2f", 
            validatedProfit, validatedCommission, validatedSwap));
   }
   
   int lastTradeIndex = ArraySize(m_trades) - 1;
   
   // Complete trade record with validated values
   m_trades[lastTradeIndex].closeTime = closeTime;
   m_trades[lastTradeIndex].closePrice = closePrice;
   m_trades[lastTradeIndex].profit = validatedProfit;      // Use validated value
   m_trades[lastTradeIndex].commission = validatedCommission;  // Use validated value
   m_trades[lastTradeIndex].swap = validatedSwap;             // Use validated value
   m_trades[lastTradeIndex].exitReason = exitReason;
   
   // Calculate additional metrics
   long tradeSeconds = closeTime - m_trades[lastTradeIndex].openTime;
   m_trades[lastTradeIndex].barsInTrade = (int)(tradeSeconds / PeriodSeconds(PERIOD_CURRENT));
   
   // Calculate risk/reward
   double risk = MathAbs(m_trades[lastTradeIndex].openPrice - m_trades[lastTradeIndex].stopLoss);
   double reward = MathAbs(m_trades[lastTradeIndex].takeProfit - m_trades[lastTradeIndex].openPrice);
   m_trades[lastTradeIndex].riskRewardRatio = (risk > 0) ? reward / risk : 0;
   
   // Log to file
   string logMsg = StringFormat("TRADE CLOSE: %s closed at %.5f | P/L: $%.2f | Exit: %s | Duration: %d bars",
                               m_trades[lastTradeIndex].direction, closePrice, validatedProfit, exitReason, 
                               m_trades[lastTradeIndex].barsInTrade);
   WriteLogEntry(logMsg);
   
   // Write to CSV
   string csvData = StringFormat("%s,%s,%s,%.5f,%.5f,%.2f,%.2f,%.2f,%.2f,%.5f,%.5f,%s,%.5f,%s,%.4f,%.0f,%.5f,%.5f,%d,%.2f,%d",
                                TimeToString(m_trades[lastTradeIndex].openTime, TIME_DATE|TIME_MINUTES),
                                TimeToString(closeTime, TIME_DATE|TIME_MINUTES),
                                m_trades[lastTradeIndex].direction,
                                m_trades[lastTradeIndex].openPrice,
                                closePrice,
                                m_trades[lastTradeIndex].lotSize,
                                validatedProfit,        // Use validated value
                                validatedCommission,    // Use validated value
                                validatedSwap,          // Use validated value
                                m_trades[lastTradeIndex].stopLoss,
                                m_trades[lastTradeIndex].takeProfit,
                                exitReason,
                                m_trades[lastTradeIndex].breakoutLevel,
                                m_trades[lastTradeIndex].wasRetest ? "YES" : "NO",
                                m_trades[lastTradeIndex].atrAtEntry,
                                m_trades[lastTradeIndex].volumeAtEntry,
                                m_trades[lastTradeIndex].maxFavorableExcursion,
                                m_trades[lastTradeIndex].maxAdverseExcursion,
                                m_trades[lastTradeIndex].barsInTrade,
                                m_trades[lastTradeIndex].riskRewardRatio,
                                lastTradeIndex + 1);
   WriteCSVEntry(csvData);
   
   // Update balance
   UpdateBalance(AccountInfoDouble(ACCOUNT_BALANCE));
}

//+------------------------------------------------------------------+
//| Update trade with current price for MFE/MAE tracking             |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::LogTradeUpdate(const double currentPrice, const double mfe, const double mae)
{
   if(!m_isInitialized || ArraySize(m_trades) == 0) return;
   
   int lastTradeIndex = ArraySize(m_trades) - 1;
   
   // Update MFE/MAE if current values are better
   if(mfe > m_trades[lastTradeIndex].maxFavorableExcursion)
      m_trades[lastTradeIndex].maxFavorableExcursion = mfe;
      
   if(mae > m_trades[lastTradeIndex].maxAdverseExcursion)
      m_trades[lastTradeIndex].maxAdverseExcursion = mae;
}

//+------------------------------------------------------------------+
//| Update balance and tracking                                        |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::UpdateBalance(const double newBalance)
{
   if(!m_isInitialized) return;
   
   m_currentBalance = newBalance;
   
   // Track peak balance
   if(newBalance > m_peakBalance)
   {
      m_peakBalance = newBalance;
      m_performance.currentDrawdown = 0;
      m_performance.currentDrawdownDuration = 0;
   }
   else
   {
      // Calculate current drawdown
      m_performance.currentDrawdown = m_peakBalance - newBalance;
      m_performance.currentDrawdownDuration++;
      
      // Update max drawdown if necessary
      if(m_performance.currentDrawdown > m_performance.maxDrawdown)
      {
         m_performance.maxDrawdown = m_performance.currentDrawdown;
         m_performance.maxDrawdownPercent = (m_performance.maxDrawdown / m_peakBalance) * 100.0;
         m_performance.maxDrawdownEnd = TimeCurrent();
      }
   }
   
   m_lastUpdateTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Calculate all performance metrics                                  |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::CalculateMetrics()
{
   if(!m_isInitialized) return;
   
   CalculateTradeStatistics();
   CalculateRiskMetrics();
   CalculateDrawdownMetrics();
   CalculateSharpeRatio();
   CalculateTimeBasedMetrics();
}

//+------------------------------------------------------------------+
//| Calculate basic trade statistics                                   |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::CalculateTradeStatistics()
{
   int totalTrades = ArraySize(m_trades);
   if(totalTrades == 0) 
   {
      // Reset all metrics when no trades
      m_performance.totalTrades = 0;
      m_performance.winningTrades = 0;
      m_performance.losingTrades = 0;
      m_performance.winRate = 0;
      m_performance.averageWin = 0;
      m_performance.averageLoss = 0;
      m_performance.profitFactor = 0;
      m_performance.expectedValue = 0;
      return;
   }
   
   m_performance.totalTrades = totalTrades;
   m_performance.winningTrades = 0;
   m_performance.losingTrades = 0;
   
   double totalProfit = 0;
   double totalWins = 0;
   double totalLosses = 0;
   
   // Add small epsilon to prevent division by zero issues
   const double EPSILON = 0.01; // Changed from 0.000001 to $0.01 for more practical threshold
   
   int breakevenTrades = 0; // Track breakeven trades
   
   for(int i = 0; i < totalTrades; i++)
   {
      double netProfit = m_trades[i].profit + m_trades[i].commission + m_trades[i].swap;
      
      // Additional safety check: Validate stored trade data
      if(MathAbs(netProfit) > 10000.0) // If net profit > $10K, likely corrupted
      {
         Print(StringFormat("⚠️ CORRUPTED TRADE DATA DETECTED: Trade #%d has net profit of %.2f", i, netProfit));
         Print(StringFormat("   Original: P=%.2f, C=%.2f, S=%.2f", m_trades[i].profit, m_trades[i].commission, m_trades[i].swap));
         
         // Reset corrupted values
         m_trades[i].profit = 0;
         m_trades[i].commission = 0;
         m_trades[i].swap = 0;
         netProfit = 0;
         
         Print("   Sanitized to zero values for calculation safety");
      }
      
      totalProfit += netProfit;
      
      if(netProfit > EPSILON) // Profit > $0.01
      {
         m_performance.winningTrades++;
         totalWins += netProfit;
         if(netProfit > m_performance.largestWin)
            m_performance.largestWin = netProfit;
      }
      else if(netProfit < -EPSILON) // Loss > $0.01
      {
         m_performance.losingTrades++;
         totalLosses += MathAbs(netProfit);
         if(MathAbs(netProfit) > m_performance.largestLoss)
            m_performance.largestLoss = MathAbs(netProfit);
      }
      else // Breakeven trades: between -$0.01 and +$0.01
      {
         breakevenTrades++;
      }
   }
   
   // Calculate derived metrics with safety bounds
   m_performance.winRate = (totalTrades > 0) ? (m_performance.winningTrades * 100.0) / totalTrades : 0;
   m_performance.averageWin = (m_performance.winningTrades > 0) ? totalWins / m_performance.winningTrades : 0;
   m_performance.averageLoss = (m_performance.losingTrades > 0) ? totalLosses / m_performance.losingTrades : 0;
   
   // Fixed profit factor calculation with safety bounds
   if(totalLosses > EPSILON)
   {
      m_performance.profitFactor = totalWins / totalLosses;
      // Cap profit factor at reasonable maximum to prevent display issues
      if(m_performance.profitFactor > 999.0)
         m_performance.profitFactor = 999.0;
   }
   else if(totalWins > EPSILON)
   {
      // If we have wins but no significant losses, set to maximum reasonable value
      m_performance.profitFactor = 999.0;
   }
   else
   {
      // No significant wins or losses
      m_performance.profitFactor = 0;
   }
   
   m_performance.expectedValue = (totalTrades > 0) ? totalProfit / totalTrades : 0;
   
   // Calculate total return with safety check
   if(m_initialBalance > EPSILON)
   {
      m_performance.totalReturn = ((m_currentBalance - m_initialBalance) / m_initialBalance) * 100.0;
      // Cap total return at reasonable bounds to prevent overflow display
      m_performance.totalReturn = MathMax(-99.9, MathMin(m_performance.totalReturn, 9999.9));
   }
   else
   {
      m_performance.totalReturn = 0;
   }
}

//+------------------------------------------------------------------+
//| Calculate risk metrics                                             |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::CalculateRiskMetrics()
{
   int totalTrades = ArraySize(m_trades);
   if(totalTrades == 0) return;
   
   // Calculate average risk/reward ratio
   double totalRR = 0;
   int validRR = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(m_trades[i].riskRewardRatio > 0)
      {
         totalRR += m_trades[i].riskRewardRatio;
         validRR++;
      }
   }
   
   m_performance.averageRiskReward = (validRR > 0) ? totalRR / validRR : 0;
   
   // Calculate volatility (standard deviation of daily returns)
   int returnCount = ArraySize(m_dailyReturns);
   if(returnCount > 1)
   {
      m_performance.volatility = CalculateStandardDeviation(m_dailyReturns) * 100.0;
   }
}

//+------------------------------------------------------------------+
//| Calculate Sharpe ratio                                             |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::CalculateSharpeRatio()
{
   int returnCount = ArraySize(m_dailyReturns);
   if(returnCount < 2)
   {
      m_performance.sharpeRatio = 0;
      return;
   }
   
   // Calculate average daily return
   double totalReturn = 0;
   for(int i = 0; i < returnCount; i++)
   {
      totalReturn += m_dailyReturns[i];
   }
   double avgReturn = totalReturn / returnCount;
   
   // Calculate standard deviation
   double stdDev = CalculateStandardDeviation(m_dailyReturns);
   
   // Assume risk-free rate of 0.02% daily (about 8% annually)
   double riskFreeRate = 0.0002;
   
   // Calculate Sharpe ratio
   if(stdDev > 0)
   {
      m_performance.sharpeRatio = (avgReturn - riskFreeRate) / stdDev;
      // Annualize it
      m_performance.sharpeRatio *= MathSqrt(252); // 252 trading days per year
   }
   else
   {
      m_performance.sharpeRatio = 0;
   }
   
   // Calculate Calmar ratio (Annual Return / Max Drawdown %)
   if(m_performance.maxDrawdownPercent > 0)
   {
      double annualizedReturn = m_performance.totalReturn; // Simplified - could be improved
      m_performance.calmarRatio = annualizedReturn / m_performance.maxDrawdownPercent;
   }
}

//+------------------------------------------------------------------+
//| Calculate drawdown metrics                                         |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::CalculateDrawdownMetrics()
{
   // Most drawdown calculations are done in UpdateBalance()
   // Here we can add additional analysis if needed
   
   if(m_performance.maxDrawdownDuration < m_performance.currentDrawdownDuration)
      m_performance.maxDrawdownDuration = m_performance.currentDrawdownDuration;
}

//+------------------------------------------------------------------+
//| Calculate time-based metrics                                       |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::CalculateTimeBasedMetrics()
{
   int totalTrades = ArraySize(m_trades);
   if(totalTrades == 0) return;
   
   double totalWinTime = 0;
   double totalLossTime = 0;
   double totalTradeTime = 0;
   int winCount = 0;
   int lossCount = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(m_trades[i].closeTime > 0) // Trade is closed
      {
         double tradeTime = (double)(m_trades[i].closeTime - m_trades[i].openTime) / 3600.0; // Hours
         totalTradeTime += tradeTime;
         
         double netProfit = m_trades[i].profit + m_trades[i].commission + m_trades[i].swap;
         if(netProfit > 0)
         {
            totalWinTime += tradeTime;
            winCount++;
         }
         else if(netProfit < 0)
         {
            totalLossTime += tradeTime;
            lossCount++;
         }
      }
   }
   
   m_performance.averageTradeTime = (totalTrades > 0) ? totalTradeTime / totalTrades : 0;
   m_performance.averageWinTime = (winCount > 0) ? totalWinTime / winCount : 0;
   m_performance.averageLossTime = (lossCount > 0) ? totalLossTime / lossCount : 0;
}

//+------------------------------------------------------------------+
//| Calculate standard deviation                                       |
//+------------------------------------------------------------------+
double CV2EAPerformanceLogger::CalculateStandardDeviation(const double &values[])
{
   int count = ArraySize(values);
   if(count < 2) return 0;
   
   // Calculate mean
   double sum = 0;
   for(int i = 0; i < count; i++)
   {
      sum += values[i];
   }
   double mean = sum / count;
   
   // Calculate variance
   double variance = 0;
   for(int i = 0; i < count; i++)
   {
      variance += MathPow(values[i] - mean, 2);
   }
   variance /= (count - 1);
   
   return MathSqrt(variance);
}

//+------------------------------------------------------------------+
//| Log strategy-specific events                                       |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::LogBreakoutAttempt(const double level, const bool successful)
{
   if(!m_isInitialized) return;
   
   string key = "breakout_attempts";
   double attempts = 0;
   if(m_metrics.TryGetValue(key, attempts))
      attempts++;
   else
      attempts = 1;
   m_metrics.Add(key, attempts);
   
   if(successful)
   {
      key = "breakout_successes";
      double successes = 0;
      if(m_metrics.TryGetValue(key, successes))
         successes++;
      else
         successes = 1;
      m_metrics.Add(key, successes);
   }
   
   // Calculate success rate
   double totalAttempts, totalSuccesses;
   if(m_metrics.TryGetValue("breakout_attempts", totalAttempts) && 
      m_metrics.TryGetValue("breakout_successes", totalSuccesses))
   {
      m_performance.breakoutSuccessRate = (totalAttempts > 0) ? (totalSuccesses / totalAttempts) * 100.0 : 0;
   }
   
   WriteLogEntry(StringFormat("BREAKOUT %s at level %.5f | Success Rate: %.1f%%", 
                             successful ? "SUCCESS" : "FAILED", level, m_performance.breakoutSuccessRate));
}

void CV2EAPerformanceLogger::LogRetestAttempt(const double level, const bool successful)
{
   if(!m_isInitialized) return;
   
   string key = "retest_attempts";
   double attempts = 0;
   if(m_metrics.TryGetValue(key, attempts))
      attempts++;
   else
      attempts = 1;
   m_metrics.Add(key, attempts);
   
   if(successful)
   {
      key = "retest_successes";
      double successes = 0;
      if(m_metrics.TryGetValue(key, successes))
         successes++;
      else
         successes = 1;
      m_metrics.Add(key, successes);
   }
   
   // Calculate success rate
   double totalAttempts, totalSuccesses;
   if(m_metrics.TryGetValue("retest_attempts", totalAttempts) && 
      m_metrics.TryGetValue("retest_successes", totalSuccesses))
   {
      m_performance.retestSuccessRate = (totalAttempts > 0) ? (totalSuccesses / totalAttempts) * 100.0 : 0;
   }
}

void CV2EAPerformanceLogger::LogVolumeFilterResult(const bool passed)
{
   if(!m_isInitialized) return;
   
   string key = "volume_filter_checks";
   double checks = 0;
   if(m_metrics.TryGetValue(key, checks))
      checks++;
   else
      checks = 1;
   m_metrics.Add(key, checks);
   
   if(passed)
   {
      key = "volume_filter_passed";
      double passed_count = 0;
      if(m_metrics.TryGetValue(key, passed_count))
         passed_count++;
      else
         passed_count = 1;
      m_metrics.Add(key, passed_count);
   }
}

void CV2EAPerformanceLogger::LogATRFilterResult(const bool passed)
{
   if(!m_isInitialized) return;
   
   string key = "atr_filter_checks";
   double checks = 0;
   if(m_metrics.TryGetValue(key, checks))
      checks++;
   else
      checks = 1;
   m_metrics.Add(key, checks);
   
   if(passed)
   {
      key = "atr_filter_passed";
      double passed_count = 0;
      if(m_metrics.TryGetValue(key, passed_count))
         passed_count++;
      else
         passed_count = 1;
      m_metrics.Add(key, passed_count);
   }
}

//+------------------------------------------------------------------+
//| Generate CSV report                                                |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::GenerateCSVReport()
{
   // CSV is generated real-time during trade logging
   // This method can be used for additional CSV exports if needed
   Print("✅ CSV trade data saved to: ", m_csvPath);
}

//+------------------------------------------------------------------+
//| Log daily update                                                   |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::LogDailyUpdate()
{
   if(!m_isInitialized) return;
   
   // Calculate daily return
   static double lastDayBalance = 0;
   if(lastDayBalance == 0)
      lastDayBalance = m_initialBalance;
      
   double dailyReturn = 0;
   if(lastDayBalance > 0)
      dailyReturn = (m_currentBalance - lastDayBalance) / lastDayBalance;
      
   // Add to daily returns array
   int size = ArraySize(m_dailyReturns);
   ArrayResize(m_dailyReturns, size + 1);
   m_dailyReturns[size] = dailyReturn;
   
   lastDayBalance = m_currentBalance;
   
   WriteLogEntry(StringFormat("DAILY UPDATE: Balance: $%.2f | Daily Return: %.2f%% | Trades Today: %d", 
                             m_currentBalance, dailyReturn * 100.0, m_tradesToday));
   
   m_tradesToday = 0; // Reset daily counter
}

//+------------------------------------------------------------------+
//| Log optimization result                                            |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::LogOptimizationResult()
{
   if(!m_isInitialized) return;
   
   CalculateMetrics();
   
   string optimizationLog = StringFormat(
      "OPTIMIZATION_RESULT,%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%.1f,%.1f,%d,%d",
      _Symbol,
      EnumToString(Period()),
      m_performance.totalReturn,
      m_performance.maxDrawdownPercent,
      m_performance.sharpeRatio,
      m_performance.profitFactor,
      m_performance.winRate,
      m_params.riskPercentage,
      m_params.atrMultiplierSL,
      m_params.atrMultiplierTP,
      m_params.lookbackPeriod,
      m_performance.totalTrades
   );
   
   WriteLogEntry(optimizationLog);
   Print("🎯 Optimization result logged for analysis");
}

//+------------------------------------------------------------------+
//| Generate detailed performance report                               |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::GenerateDetailedReport()
{
   if(!m_isInitialized) return;
   
   CalculateMetrics();
   
   // Pattern from: MQL5 Programming Reference
   // Reference: Write Data to CSV File section
   int reportHandle = FileOpen(m_reportPath, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(reportHandle == INVALID_HANDLE)
   {
      Print("❌ Failed to create report file: ", m_reportPath);
      return;
   }
   
   // Confirm new report file creation
   Print("✅ NEW REPORT FILE CREATED: ", m_reportPath);
   
   // Write comprehensive report
   FileWriteString(reportHandle, "=== V-2-EA DETAILED PERFORMANCE REPORT ===\n\n");
   
   // Executive Summary
   FileWriteString(reportHandle, "EXECUTIVE SUMMARY\n");
   FileWriteString(reportHandle, "=================\n");
   FileWriteString(reportHandle, StringFormat("Total Trades: %d\n", m_performance.totalTrades));
   FileWriteString(reportHandle, StringFormat("Win Rate: %.2f%%\n", m_performance.winRate));
   FileWriteString(reportHandle, StringFormat("Profit Factor: %.2f\n", m_performance.profitFactor));
   FileWriteString(reportHandle, StringFormat("Total Return: %.2f%%\n", m_performance.totalReturn));
   FileWriteString(reportHandle, StringFormat("Max Drawdown: %.2f%%\n", m_performance.maxDrawdownPercent));
   FileWriteString(reportHandle, StringFormat("Sharpe Ratio: %.2f\n", m_performance.sharpeRatio));
   FileWriteString(reportHandle, StringFormat("Calmar Ratio: %.2f\n", m_performance.calmarRatio));
   
   // Risk Analysis
   FileWriteString(reportHandle, "\nRISK ANALYSIS\n");
   FileWriteString(reportHandle, "=============\n");
   FileWriteString(reportHandle, StringFormat("Average Win: $%.2f\n", m_performance.averageWin));
   FileWriteString(reportHandle, StringFormat("Average Loss: $%.2f\n", m_performance.averageLoss));
   FileWriteString(reportHandle, StringFormat("Risk/Reward Ratio: %.2f\n", m_performance.averageRiskReward));
   FileWriteString(reportHandle, StringFormat("Volatility: %.2f%%\n", m_performance.volatility));
   
   // Strategy Effectiveness
   FileWriteString(reportHandle, "\nSTRATEGY EFFECTIVENESS\n");
   FileWriteString(reportHandle, "======================\n");
   FileWriteString(reportHandle, StringFormat("Breakout Success Rate: %.2f%%\n", m_performance.breakoutSuccessRate));
   FileWriteString(reportHandle, StringFormat("Retest Success Rate: %.2f%%\n", m_performance.retestSuccessRate));
   FileWriteString(reportHandle, StringFormat("Volume Filter Effectiveness: %.2f%%\n", m_performance.volumeFilterEffectiveness));
   FileWriteString(reportHandle, StringFormat("ATR Filter Effectiveness: %.2f%%\n", m_performance.atrFilterEffectiveness));
   
   // Optimization Parameters
   FileWriteString(reportHandle, "\nOPTIMIZATION PARAMETERS\n");
   FileWriteString(reportHandle, "=======================\n");
   FileWriteString(reportHandle, StringFormat("Lookback Period: %d\n", m_params.lookbackPeriod));
   FileWriteString(reportHandle, StringFormat("Min Strength: %.2f\n", m_params.minStrength));
   FileWriteString(reportHandle, StringFormat("Touch Zone: %.4f\n", m_params.touchZone));
   FileWriteString(reportHandle, StringFormat("Risk Percentage: %.1f%%\n", m_params.riskPercentage));
   FileWriteString(reportHandle, StringFormat("ATR SL Multiplier: %.1f\n", m_params.atrMultiplierSL));
   FileWriteString(reportHandle, StringFormat("ATR TP Multiplier: %.1f\n", m_params.atrMultiplierTP));
   
   // Recommendations
   FileWriteString(reportHandle, "\nOPTIMIZATION RECOMMENDATIONS\n");
   FileWriteString(reportHandle, "============================\n");
   
   if(m_performance.winRate < 40)
      FileWriteString(reportHandle, "• Consider tightening entry criteria (higher MinStrength)\n");
   if(m_performance.profitFactor < 1.2)
      FileWriteString(reportHandle, "• Review risk/reward ratios and exit strategy\n");
   if(m_performance.maxDrawdownPercent > 20)
      FileWriteString(reportHandle, "• Reduce position sizing or improve stop loss strategy\n");
   if(m_performance.sharpeRatio < 1.0)
      FileWriteString(reportHandle, "• Strategy shows poor risk-adjusted returns\n");
   
   FileClose(reportHandle);
   Print("✅ Detailed performance report generated: ", m_reportPath);
}

//+------------------------------------------------------------------+
//| Print performance summary to console                              |
//+------------------------------------------------------------------+
void CV2EAPerformanceLogger::PrintPerformanceSummary()
{
   if(!m_isInitialized) return;
   
   CalculateMetrics();
   
   Print("=== V-2-EA PERFORMANCE SUMMARY ===");
   Print(StringFormat("📊 Total Trades: %d (Wins: %d, Losses: %d, Breakeven: %d)", 
         m_performance.totalTrades, m_performance.winningTrades, m_performance.losingTrades, 
         m_performance.totalTrades - m_performance.winningTrades - m_performance.losingTrades));
   
   // Add validation check for consistency
   int calculatedTotal = m_performance.winningTrades + m_performance.losingTrades;
   int breakevenCount = m_performance.totalTrades - calculatedTotal;
   
   if(breakevenCount > 0)
   {
      Print(StringFormat("ℹ️  Note: %d breakeven trade(s) (profit between -$0.01 and +$0.01)", breakevenCount));
   }
   
   if(calculatedTotal != m_performance.totalTrades && breakevenCount == 0)
   {
      Print(StringFormat("⚠️  CALCULATION WARNING: Total trades mismatch! Wins+Losses=%d, Total=%d", 
            calculatedTotal, m_performance.totalTrades));
   }
   
   Print(StringFormat("🎯 Win Rate: %.1f%% | Profit Factor: %.2f", 
         m_performance.winRate, m_performance.profitFactor));
         
   // Add more detailed profit/loss breakdown
   double totalWins = m_performance.averageWin * m_performance.winningTrades;
   double totalLosses = m_performance.averageLoss * m_performance.losingTrades;
   Print(StringFormat("💵 Total Profits: $%.2f | Total Losses: $%.2f", totalWins, totalLosses));
   
   Print(StringFormat("📈 Total Return: %.2f%% | Sharpe Ratio: %.2f", 
         m_performance.totalReturn, m_performance.sharpeRatio));
   Print(StringFormat("📉 Max Drawdown: %.2f%% (%.2f)", 
         m_performance.maxDrawdownPercent, m_performance.maxDrawdown));
   Print(StringFormat("💰 Avg Win: $%.2f | Avg Loss: $%.2f", 
         m_performance.averageWin, m_performance.averageLoss));
         
   // Add largest win/loss for context
   Print(StringFormat("🏆 Largest Win: $%.2f | Largest Loss: $%.2f", 
         m_performance.largestWin, m_performance.largestLoss));
         
   Print(StringFormat("⚡ Breakout Success: %.1f%% | Retest Success: %.1f%%", 
         m_performance.breakoutSuccessRate, m_performance.retestSuccessRate));
   Print("=====================================");
}

// Additional helper methods for string formatting and calculations
string CV2EAPerformanceLogger::FormatDateTime(const datetime dt)
{
   return TimeToString(dt, TIME_DATE|TIME_MINUTES);
}

string CV2EAPerformanceLogger::FormatDouble(const double value, const int digits = 2)
{
   return DoubleToString(value, digits);
}

void CV2EAPerformanceLogger::ResizeTradeArray()
{
   int currentSize = ArraySize(m_trades);
   ArrayResize(m_trades, currentSize + 1);
}

string CV2EAPerformanceLogger::ParametersToString()
{
   return StringFormat("LP:%d,MS:%.2f,TZ:%.4f,MT:%d,RP:%.1f,SL:%.1f,TP:%.1f", 
                      m_params.lookbackPeriod, m_params.minStrength, m_params.touchZone,
                      m_params.minTouches, m_params.riskPercentage, 
                      m_params.atrMultiplierSL, m_params.atrMultiplierTP);
}

void CV2EAPerformanceLogger::WriteLogEntry(const string message)
{
   if(m_logFileHandle != INVALID_HANDLE)
   {
      FileWriteString(m_logFileHandle, FormatDateTime(TimeCurrent()) + " - " + message + "\n");
      FileFlush(m_logFileHandle);
   }
}

void CV2EAPerformanceLogger::WriteCSVEntry(const string data)
{
   if(m_csvFileHandle != INVALID_HANDLE)
   {
      FileWriteString(m_csvFileHandle, data + "\n");
      FileFlush(m_csvFileHandle);
   }
}

void CV2EAPerformanceLogger::Deinitialize()
{
   if(m_isInitialized)
   {
      GenerateDetailedReport();
      GenerateCSVReport();
      
      if(m_logFileHandle != INVALID_HANDLE)
      {
         WriteLogEntry("=== Performance Logger Shutdown ===");
         FileClose(m_logFileHandle);
         m_logFileHandle = INVALID_HANDLE;
      }
      
      if(m_csvFileHandle != INVALID_HANDLE)
      {
         FileClose(m_csvFileHandle);
         m_csvFileHandle = INVALID_HANDLE;
      }
      
      m_isInitialized = false;
   }
} 