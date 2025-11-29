//+------------------------------------------------------------------+
//| OptimizeParameters.mq5                                          |
//| Copyright 2025, Grande Tech                                     |
//| Purpose: Optimize trading parameters using database backtest data |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Grande Tech"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "..\..\Experts\Grande\Include\GrandeDatabaseManager.mqh"

//--- Input parameters
input group "=== Optimization Configuration ==="
input string InpSymbol = "";                 // Symbol (empty = current chart symbol)
input int    InpTimeframe = PERIOD_H1;       // Timeframe to optimize
input int    InpBacktestYears = 3;           // Years of historical data for optimization
input double InpStartingBalance = 10000;     // Starting balance
input bool   InpShowProgress = true;         // Show progress updates

input group "=== Parameters to Optimize ==="
input bool   InpOptimizeRisk = true;         // Optimize risk percentages
input bool   InpOptimizeSLTP = true;         // Optimize Stop Loss / Take Profit
input bool   InpOptimizeADX = false;         // Optimize ADX thresholds
input bool   InpOptimizeKeyLevels = false;   // Optimize key level settings

input group "=== Optimization Ranges ==="
// Risk management ranges
input double InpRiskTrendMin = 1.0;           // Risk Trend Min (%)
input double InpRiskTrendMax = 3.0;           // Risk Trend Max (%)
input double InpRiskTrendStep = 0.5;          // Risk Trend Step
input double InpRiskRangeMin = 0.5;          // Risk Range Min (%)
input double InpRiskRangeMax = 1.5;          // Risk Range Max (%)
input double InpRiskRangeStep = 0.3;          // Risk Range Step
input double InpRiskBreakoutMin = 2.0;       // Risk Breakout Min (%)
input double InpRiskBreakoutMax = 5.0;        // Risk Breakout Max (%)
input double InpRiskBreakoutStep = 0.5;      // Risk Breakout Step

// SL/TP ranges
input double InpSLATRMin = 1.2;              // SL ATR Multiplier Min
input double InpSLATRMax = 2.5;              // SL ATR Multiplier Max
input double InpSLATRStep = 0.3;             // SL ATR Multiplier Step
input double InpTPRatioMin = 2.0;            // TP Reward Ratio Min
input double InpTPRatioMax = 4.0;            // TP Reward Ratio Max
input double InpTPRatioStep = 0.5;            // TP Reward Ratio Step

// ADX ranges
input double InpADXTrendMin = 20.0;          // ADX Trend Threshold Min
input double InpADXTrendMax = 30.0;          // ADX Trend Threshold Max
input double InpADXTrendStep = 2.5;          // ADX Trend Threshold Step
input double InpADXBreakoutMin = 15.0;       // ADX Breakout Min
input double InpADXBreakoutMax = 22.0;       // ADX Breakout Max
input double InpADXBreakoutStep = 2.0;       // ADX Breakout Step

// Key level ranges
input double InpMinStrengthMin = 0.30;        // Min Strength Min
input double InpMinStrengthMax = 0.50;       // Min Strength Max
input double InpMinStrengthStep = 0.05;      // Min Strength Step

input group "=== Optimization Criteria ==="
input int    InpOptimizationMode = 0;        // Optimization Mode: 0=Net Profit, 1=Profit Factor, 2=Sharpe Ratio, 3=Custom Score
input double InpMinTrades = 20;               // Minimum trades required for valid result
input double InpMinWinRate = 45.0;           // Minimum win rate (%) to consider

//--- Global variables
CGrandeDatabaseManager* g_dbManager = NULL;

//--- Optimization structures
struct OptimizationResult
{
    // Parameters tested
    double    riskPctTrend;
    double    riskPctRange;
    double    riskPctBreakout;
    double    slATRMultiplier;
    double    tpRewardRatio;
    double    adxTrendThreshold;
    double    adxBreakoutMin;
    double    minStrength;
    
    // Results
    int       totalTrades;
    int       winningTrades;
    double    winRate;
    double    netProfit;
    double    grossProfit;
    double    grossLoss;
    double    profitFactor;
    double    maxDrawdown;
    double    maxDrawdownPercent;
    double    avgWin;
    double    avgLoss;
    double    riskRewardRatio;
    double    expectancy;
    double    sharpeRatio;
    double    customScore;
    
    // Balance tracking
    double    finalBalance;
    double    peakBalance;
};

struct OptimizationStats
{
    int       totalCombinations;
    int       validResults;
    int       invalidResults;
    double    bestScore;
    int       bestIndex;
};

//--- Results storage
OptimizationResult g_results[];
OptimizationStats  g_stats;

//+------------------------------------------------------------------+
//| Calculate simple RSI                                              |
//+------------------------------------------------------------------+
double CalculateRSI(const MqlRates &rates[], int index, int period)
{
    if(index < period + 1)
        return 50.0;
    
    double gains = 0, losses = 0;
    
    for(int i = index - period; i < index; i++)
    {
        double change = rates[i + 1].close - rates[i].close;
        if(change > 0)
            gains += change;
        else
            losses += MathAbs(change);
    }
    
    if(losses == 0)
        return 100.0;
    
    double avgGain = gains / period;
    double avgLoss = losses / period;
    double rs = avgGain / avgLoss;
    
    return 100.0 - (100.0 / (1.0 + rs));
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                      |
//+------------------------------------------------------------------+
double CalculateATR(const MqlRates &rates[], int index, int period)
{
    if(index < period)
        return 0;
    
    double sum = 0;
    for(int i = index - period + 1; i <= index; i++)
    {
        double tr = MathMax(rates[i].high - rates[i].low,
                           MathMax(MathAbs(rates[i].high - rates[i-1].close),
                                  MathAbs(rates[i].low - rates[i-1].close)));
        sum += tr;
    }
    
    return sum / period;
}

//+------------------------------------------------------------------+
//| Get pip value for symbol                                          |
//+------------------------------------------------------------------+
double GetPipValue(const string symbol)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    if(digits == 3 || digits == 5)
        return point * 10;
    return point;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
double CalculateLotSize(const string symbol, double balance, double riskPercent, double stopLossPips)
{
    double riskAmount = balance * (riskPercent / 100.0);
    double pipValue = GetPipValue(symbol);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize == 0 || pipValue == 0)
        return 0.01;
    
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    
    double valuePerPip = (tickValue / tickSize) * pipValue;
    if(valuePerPip == 0)
        return minLot;
    
    double lotSize = riskAmount / (stopLossPips * valuePerPip);
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Run backtest with specific parameters                            |
//+------------------------------------------------------------------+
bool RunOptimizationBacktest(const string symbol, 
                             const MqlRates &rates[],
                             const double riskPctTrend,
                             const double riskPctRange,
                             const double riskPctBreakout,
                             const double slATRMultiplier,
                             const double tpRewardRatio,
                             OptimizationResult &result)
{
    int ratesCount = ArraySize(rates);
    if(ratesCount < 50)
        return false;
    
    // Initialize result
    result.riskPctTrend = riskPctTrend;
    result.riskPctRange = riskPctRange;
    result.riskPctBreakout = riskPctBreakout;
    result.slATRMultiplier = slATRMultiplier;
    result.tpRewardRatio = tpRewardRatio;
    
    result.totalTrades = 0;
    result.winningTrades = 0;
    result.netProfit = 0;
    result.grossProfit = 0;
    result.grossLoss = 0;
    result.maxDrawdown = 0;
    result.peakBalance = InpStartingBalance;
    result.finalBalance = InpStartingBalance;
    
    double pipValue = GetPipValue(symbol);
    if(pipValue == 0)
        return false;
    
    bool inPosition = false;
    struct Trade {
        datetime openTime;
        double entryPrice;
        double stopLoss;
        double takeProfit;
        double lotSize;
        bool isBuy;
        double riskPct;
    } currentTrade;
    
    // Main simulation loop
    for(int i = 50; i < ratesCount; i++)
    {
        double currentPrice = rates[i].close;
        double atr = CalculateATR(rates, i, 21);
        double rsi = CalculateRSI(rates, i, 14);
        
        // Determine market regime (simplified)
        string regime = "RANGE";
        if(atr > 0)
        {
            double avgATR = 0;
            int avgPeriod = 90;
            for(int j = MathMax(0, i - avgPeriod); j < i; j++)
                avgATR += CalculateATR(rates, j, 21);
            avgATR /= MathMin(avgPeriod, i);
            
            if(atr > avgATR * 2.0)
                regime = "BREAKOUT";
            else if(atr > avgATR * 1.2)
                regime = "TREND";
        }
        
        // Check for exit if in position
        if(inPosition)
        {
            bool shouldExit = false;
            double exitPrice = currentPrice;
            string exitReason = "";
            
            if(currentTrade.isBuy)
            {
                if(rates[i].low <= currentTrade.stopLoss)
                {
                    shouldExit = true;
                    exitReason = "SL";
                    exitPrice = currentTrade.stopLoss;
                }
                else if(rates[i].high >= currentTrade.takeProfit)
                {
                    shouldExit = true;
                    exitReason = "TP";
                    exitPrice = currentTrade.takeProfit;
                }
            }
            else
            {
                if(rates[i].high >= currentTrade.stopLoss)
                {
                    shouldExit = true;
                    exitReason = "SL";
                    exitPrice = currentTrade.stopLoss;
                }
                else if(rates[i].low <= currentTrade.takeProfit)
                {
                    shouldExit = true;
                    exitReason = "TP";
                    exitPrice = currentTrade.takeProfit;
                }
            }
            
            if(shouldExit)
            {
                // Calculate PnL
                double priceDiff = currentTrade.isBuy 
                    ? (exitPrice - currentTrade.entryPrice)
                    : (currentTrade.entryPrice - exitPrice);
                double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
                double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
                
                double pnl = 0;
                if(tickSize > 0)
                    pnl = (tickValue / tickSize) * priceDiff * currentTrade.lotSize;
                else
                    pnl = (priceDiff / pipValue) * currentTrade.lotSize * 10;
                
                result.totalTrades++;
                result.finalBalance += pnl;
                
                if(pnl > 0)
                {
                    result.winningTrades++;
                    result.grossProfit += pnl;
                }
                else
                {
                    result.grossLoss += MathAbs(pnl);
                }
                
                if(result.finalBalance > result.peakBalance)
                    result.peakBalance = result.finalBalance;
                
                double drawdown = result.peakBalance - result.finalBalance;
                if(drawdown > result.maxDrawdown)
                    result.maxDrawdown = drawdown;
                
                inPosition = false;
            }
        }
        
        // Check for entry signals
        if(!inPosition)
        {
            bool buySignal = (rsi < 30);
            bool sellSignal = (rsi > 70);
            
            if(buySignal || sellSignal)
            {
                currentTrade.openTime = rates[i].time;
                currentTrade.isBuy = buySignal;
                currentTrade.entryPrice = currentPrice;
                
                // Determine risk based on regime
                double riskPct = riskPctRange;
                if(regime == "TREND")
                    riskPct = riskPctTrend;
                else if(regime == "BREAKOUT")
                    riskPct = riskPctBreakout;
                
                currentTrade.riskPct = riskPct;
                
                // Calculate SL/TP based on ATR
                double slDistance = atr * slATRMultiplier;
                double tpDistance = slDistance * tpRewardRatio;
                
                if(buySignal)
                {
                    currentTrade.stopLoss = currentPrice - slDistance;
                    currentTrade.takeProfit = currentPrice + tpDistance;
                }
                else
                {
                    currentTrade.stopLoss = currentPrice + slDistance;
                    currentTrade.takeProfit = currentPrice - tpDistance;
                }
                
                // Calculate lot size
                double slPips = slDistance / pipValue;
                currentTrade.lotSize = CalculateLotSize(symbol, result.finalBalance, riskPct, slPips);
                
                inPosition = true;
            }
        }
    }
    
    // Calculate metrics
    result.netProfit = result.finalBalance - InpStartingBalance;
    result.winRate = result.totalTrades > 0 ? (double)result.winningTrades / result.totalTrades * 100 : 0;
    result.profitFactor = result.grossLoss > 0 ? result.grossProfit / result.grossLoss : 0;
    result.maxDrawdownPercent = InpStartingBalance > 0 ? result.maxDrawdown / InpStartingBalance * 100 : 0;
    result.avgWin = result.winningTrades > 0 ? result.grossProfit / result.winningTrades : 0;
    result.avgLoss = (result.totalTrades - result.winningTrades) > 0 ? result.grossLoss / (result.totalTrades - result.winningTrades) : 0;
    result.riskRewardRatio = result.avgLoss > 0 ? result.avgWin / result.avgLoss : 0;
    result.expectancy = (result.winRate / 100 * result.avgWin) - ((100 - result.winRate) / 100 * result.avgLoss);
    
    // Calculate Sharpe Ratio (simplified)
    result.sharpeRatio = result.maxDrawdownPercent > 0 ? result.netProfit / result.maxDrawdownPercent : 0;
    
    // Calculate custom score
    double score = 0;
    if(result.totalTrades >= InpMinTrades && result.winRate >= InpMinWinRate)
    {
        score = result.netProfit * 0.4 + 
                result.profitFactor * 1000 * 0.3 +
                result.winRate * 10 * 0.2 +
                (100 - result.maxDrawdownPercent) * 0.1;
    }
    result.customScore = score;
    
    return result.totalTrades >= InpMinTrades;
}

//+------------------------------------------------------------------+
//| Run optimization                                                  |
//+------------------------------------------------------------------+
void RunOptimization(const string symbol, const MqlRates &rates[])
{
    Print("\n[OPTIMIZE] Starting parameter optimization...");
    Print("[OPTIMIZE] Testing parameter combinations...");
    
    g_stats.totalCombinations = 0;
    g_stats.validResults = 0;
    g_stats.invalidResults = 0;
    g_stats.bestScore = -999999;
    g_stats.bestIndex = -1;
    
    ArrayResize(g_results, 0);
    
    // Calculate number of combinations
    int riskTrendSteps = (int)((InpRiskTrendMax - InpRiskTrendMin) / InpRiskTrendStep) + 1;
    int riskRangeSteps = (int)((InpRiskRangeMax - InpRiskRangeMin) / InpRiskRangeStep) + 1;
    int riskBreakoutSteps = (int)((InpRiskBreakoutMax - InpRiskBreakoutMin) / InpRiskBreakoutStep) + 1;
    int slATRSteps = (int)((InpSLATRMax - InpSLATRMin) / InpSLATRStep) + 1;
    int tpRatioSteps = (int)((InpTPRatioMax - InpTPRatioMin) / InpTPRatioStep) + 1;
    
    int totalCombos = 1;
    if(InpOptimizeRisk)
        totalCombos *= riskTrendSteps * riskRangeSteps * riskBreakoutSteps;
    if(InpOptimizeSLTP)
        totalCombos *= slATRSteps * tpRatioSteps;
    
    Print("[OPTIMIZE] Total combinations to test: ", totalCombos);
    
    int currentCombo = 0;
    int progressInterval = MathMax(1, totalCombos / 20);
    
    // Grid search
    for(double riskTrend = InpRiskTrendMin; riskTrend <= InpRiskTrendMax; riskTrend += InpRiskTrendStep)
    {
        for(double riskRange = InpRiskRangeMin; riskRange <= InpRiskRangeMax; riskRange += InpRiskRangeStep)
        {
            for(double riskBreakout = InpRiskBreakoutMin; riskBreakout <= InpRiskBreakoutMax; riskBreakout += InpRiskBreakoutStep)
            {
                for(double slATR = InpSLATRMin; slATR <= InpSLATRMax; slATR += InpSLATRStep)
                {
                    for(double tpRatio = InpTPRatioMin; tpRatio <= InpTPRatioMax; tpRatio += InpTPRatioStep)
                    {
                        currentCombo++;
                        
                        if(InpShowProgress && currentCombo % progressInterval == 0)
                        {
                            double progress = (double)currentCombo / totalCombos * 100;
                            Print("[OPTIMIZE] Progress: ", DoubleToString(progress, 1), "% (", currentCombo, "/", totalCombos, ")");
                        }
                        
                        OptimizationResult result;
                        result.adxTrendThreshold = 25.0; // Default
                        result.adxBreakoutMin = 18.0;     // Default
                        result.minStrength = 0.40;        // Default
                        
                        if(RunOptimizationBacktest(symbol, rates, riskTrend, riskRange, riskBreakout, slATR, tpRatio, result))
                        {
                            int idx = ArraySize(g_results);
                            ArrayResize(g_results, idx + 1);
                            g_results[idx] = result;
                            g_stats.validResults++;
                            
                            // Track best result
                            double score = 0;
                            switch(InpOptimizationMode)
                            {
                                case 0: score = result.netProfit; break;
                                case 1: score = result.profitFactor; break;
                                case 2: score = result.sharpeRatio; break;
                                case 3: score = result.customScore; break;
                            }
                            
                            if(score > g_stats.bestScore)
                            {
                                g_stats.bestScore = score;
                                g_stats.bestIndex = idx;
                            }
                        }
                        else
                        {
                            g_stats.invalidResults++;
                        }
                        
                        g_stats.totalCombinations++;
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Print optimization results                                       |
//+------------------------------------------------------------------+
void PrintResults(const string symbol)
{
    Print("\n========================================");
    Print("OPTIMIZATION RESULTS");
    Print("========================================\n");
    
    Print("Symbol: ", symbol);
    Print("Total Combinations Tested: ", g_stats.totalCombinations);
    Print("Valid Results: ", g_stats.validResults);
    Print("Invalid Results: ", g_stats.invalidResults);
    Print("");
    
    if(g_stats.bestIndex < 0)
    {
        Print("No valid results found. Try adjusting minimum requirements.");
        return;
    }
    
    OptimizationResult best = g_results[g_stats.bestIndex];
    
    Print("=== BEST PARAMETERS ===");
    Print("Risk Trend: ", DoubleToString(best.riskPctTrend, 2), "%");
    Print("Risk Range: ", DoubleToString(best.riskPctRange, 2), "%");
    Print("Risk Breakout: ", DoubleToString(best.riskPctBreakout, 2), "%");
    Print("SL ATR Multiplier: ", DoubleToString(best.slATRMultiplier, 2));
    Print("TP Reward Ratio: ", DoubleToString(best.tpRewardRatio, 2));
    Print("");
    
    Print("=== PERFORMANCE ===");
    Print("Total Trades: ", best.totalTrades);
    Print("Win Rate: ", DoubleToString(best.winRate, 2), "%");
    Print("Net Profit: $", DoubleToString(best.netProfit, 2));
    Print("Profit Factor: ", DoubleToString(best.profitFactor, 2));
    Print("Max Drawdown: ", DoubleToString(best.maxDrawdownPercent, 2), "%");
    Print("Expectancy: $", DoubleToString(best.expectancy, 2));
    Print("Risk:Reward: ", DoubleToString(best.riskRewardRatio, 2), ":1");
    Print("");
    
    // Show top 10 results
    Print("=== TOP 10 RESULTS ===");
    
    // Sort by optimization mode
    int sorted[];
    ArrayResize(sorted, ArraySize(g_results));
    for(int i = 0; i < ArraySize(g_results); i++)
        sorted[i] = i;
    
    // Simple bubble sort
    for(int i = 0; i < ArraySize(g_results) - 1; i++)
    {
        for(int j = 0; j < ArraySize(g_results) - i - 1; j++)
        {
            double score1 = 0, score2 = 0;
            switch(InpOptimizationMode)
            {
                case 0: score1 = g_results[sorted[j]].netProfit; score2 = g_results[sorted[j+1]].netProfit; break;
                case 1: score1 = g_results[sorted[j]].profitFactor; score2 = g_results[sorted[j+1]].profitFactor; break;
                case 2: score1 = g_results[sorted[j]].sharpeRatio; score2 = g_results[sorted[j+1]].sharpeRatio; break;
                case 3: score1 = g_results[sorted[j]].customScore; score2 = g_results[sorted[j+1]].customScore; break;
            }
            
            if(score1 < score2)
            {
                int temp = sorted[j];
                sorted[j] = sorted[j+1];
                sorted[j+1] = temp;
            }
        }
    }
    
    int topCount = MathMin(10, ArraySize(g_results));
    for(int i = 0; i < topCount; i++)
    {
        OptimizationResult r = g_results[sorted[i]];
        double score = 0;
        switch(InpOptimizationMode)
        {
            case 0: score = r.netProfit; break;
            case 1: score = r.profitFactor; break;
            case 2: score = r.sharpeRatio; break;
            case 3: score = r.customScore; break;
        }
        
        Print(StringFormat("#%d: Risk[%.1f/%.1f/%.1f] SL:%.2f TP:%.2f | Trades:%d WR:%.1f%% PF:%.2f Profit:$%.2f",
              i+1, r.riskPctTrend, r.riskPctRange, r.riskPctBreakout,
              r.slATRMultiplier, r.tpRewardRatio,
              r.totalTrades, r.winRate, r.profitFactor, r.netProfit));
    }
    
    Print("\n========================================");
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("\n====================================");
    Print("PARAMETER OPTIMIZATION");
    Print("====================================\n");
    
    string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
    
    Print("[OPTIMIZE] Symbol: ", symbol);
    Print("[OPTIMIZE] Timeframe: ", EnumToString((ENUM_TIMEFRAMES)InpTimeframe));
    Print("[OPTIMIZE] Years: ", InpBacktestYears);
    Print("[OPTIMIZE] Optimization Mode: ", InpOptimizationMode == 0 ? "Net Profit" : 
          InpOptimizationMode == 1 ? "Profit Factor" : 
          InpOptimizationMode == 2 ? "Sharpe Ratio" : "Custom Score");
    Print("");
    
    string dbPath = "Data/GrandeTradingData.db";
    
    if(!FileIsExist(dbPath))
    {
        Print("[OPTIMIZE] ERROR: Database not found at ", dbPath);
        Print("[OPTIMIZE] Please run BackfillHistoricalData.mq5 first.");
        return;
    }
    
    g_dbManager = new CGrandeDatabaseManager();
    if(g_dbManager == NULL)
    {
        Print("[OPTIMIZE] ERROR: Failed to create database manager");
        return;
    }
    
    if(!g_dbManager.Initialize(dbPath, InpShowProgress))
    {
        Print("[OPTIMIZE] ERROR: Failed to initialize database");
        delete g_dbManager;
        return;
    }
    
    Print("[OPTIMIZE] Database initialized: ", dbPath);
    
    datetime endDate = TimeCurrent();
    datetime startDate = endDate - (InpBacktestYears * 365 * 24 * 3600);
    
    Print("[OPTIMIZE] Date range: ", TimeToString(startDate, TIME_DATE), " to ", TimeToString(endDate, TIME_DATE));
    Print("");
    
    Print("[OPTIMIZE] Loading historical data...");
    
    MqlRates rates[];
    uint loadStart = GetTickCount();
    
    if(!g_dbManager.GetMarketDataRange(symbol, startDate, endDate, InpTimeframe, rates))
    {
        Print("[OPTIMIZE] ERROR: Failed to load market data");
        delete g_dbManager;
        return;
    }
    
    uint loadDuration = GetTickCount() - loadStart;
    Print("[OPTIMIZE] Loaded ", ArraySize(rates), " bars in ", loadDuration, " ms");
    Print("");
    
    uint optStart = GetTickCount();
    RunOptimization(symbol, rates);
    uint optDuration = GetTickCount() - optStart;
    
    Print("[OPTIMIZE] Optimization completed in ", optDuration / 1000, " seconds");
    
    PrintResults(symbol);
    
    delete g_dbManager;
}

//+------------------------------------------------------------------+
