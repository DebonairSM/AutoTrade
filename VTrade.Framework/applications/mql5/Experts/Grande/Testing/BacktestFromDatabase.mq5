//+------------------------------------------------------------------+
//| BacktestFromDatabase.mq5                                        |
//| Copyright 2025, Grande Tech                                     |
//| Purpose: Custom backtesting using database historical data       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Grande Tech"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "..\..\Experts\Grande\Include\GrandeDatabaseManager.mqh"

//--- Input parameters
input group "=== Backtest Configuration ==="
input string InpSymbol = "";                 // Symbol (empty = current chart symbol)
input int    InpTimeframe = PERIOD_H1;       // Timeframe to backtest
input int    InpBacktestYears = 5;           // Years of historical data
input bool   InpShowProgress = true;         // Show progress updates

input group "=== Trading Parameters ==="
input double InpRiskPercent = 1.0;           // Risk per trade (%)
input double InpStopLossPips = 50;           // Stop loss in pips
input double InpTakeProfitPips = 100;        // Take profit in pips
input double InpStartingBalance = 10000;     // Starting balance

input group "=== Strategy Parameters ==="
input int    InpRSIPeriod = 14;              // RSI period for simple strategy
input int    InpRSIOversold = 30;            // RSI oversold level (buy signal)
input int    InpRSIOverbought = 70;          // RSI overbought level (sell signal)
input bool   InpSimulateLimitOrders = false; // Simulate limit orders vs market orders

//--- Global variables
CGrandeDatabaseManager* g_dbManager = NULL;

//--- Backtest tracking
struct BacktestStats
{
    int       totalTrades;
    int       winningTrades;
    int       losingTrades;
    double    totalProfit;
    double    totalLoss;
    double    maxDrawdown;
    double    peakBalance;
    double    currentBalance;
    double    grossProfit;
    double    grossLoss;
};

struct SimulatedTrade
{
    datetime  openTime;
    datetime  closeTime;
    double    entryPrice;
    double    exitPrice;
    double    stopLoss;
    double    takeProfit;
    double    lotSize;
    bool      isBuy;
    double    pnl;
    string    exitReason;
};

//+------------------------------------------------------------------+
//| Calculate simple RSI                                              |
//+------------------------------------------------------------------+
double CalculateRSI(const MqlRates &rates[], int index, int period)
{
    if(index < period + 1)
        return 50.0; // Default neutral
    
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
        return 0.01; // Minimum lot
    
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    
    double valuePerPip = (tickValue / tickSize) * pipValue;
    if(valuePerPip == 0)
        return minLot;
    
    double lotSize = riskAmount / (stopLossPips * valuePerPip);
    
    // Round to lot step
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    // Apply limits
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Run backtest simulation                                           |
//+------------------------------------------------------------------+
bool RunBacktest(const string symbol, const MqlRates &rates[], BacktestStats &stats, SimulatedTrade &trades[])
{
    int ratesCount = ArraySize(rates);
    if(ratesCount < InpRSIPeriod + 10)
    {
        Print("[BACKTEST] ERROR: Insufficient data for backtesting");
        return false;
    }
    
    // Initialize stats
    stats.totalTrades = 0;
    stats.winningTrades = 0;
    stats.losingTrades = 0;
    stats.totalProfit = 0;
    stats.totalLoss = 0;
    stats.maxDrawdown = 0;
    stats.peakBalance = InpStartingBalance;
    stats.currentBalance = InpStartingBalance;
    stats.grossProfit = 0;
    stats.grossLoss = 0;
    
    ArrayResize(trades, 0);
    
    double pipValue = GetPipValue(symbol);
    if(pipValue == 0)
    {
        Print("[BACKTEST] ERROR: Could not determine pip value for ", symbol);
        return false;
    }
    
    // Trading state
    bool inPosition = false;
    SimulatedTrade currentTrade;
    int progressInterval = ratesCount / 10;
    
    Print("[BACKTEST] Starting simulation with ", ratesCount, " bars");
    
    // Main simulation loop
    for(int i = InpRSIPeriod + 1; i < ratesCount; i++)
    {
        // Progress update
        if(InpShowProgress && progressInterval > 0 && i % progressInterval == 0)
        {
            double progress = (double)i / ratesCount * 100;
            Print("[BACKTEST] Progress: ", DoubleToString(progress, 1), "%");
        }
        
        double currentPrice = rates[i].close;
        double rsi = CalculateRSI(rates, i, InpRSIPeriod);
        
        // Check for exit if in position
        if(inPosition)
        {
            bool shouldExit = false;
            string exitReason = "";
            double exitPrice = currentPrice;
            
            if(currentTrade.isBuy)
            {
                // Check stop loss
                if(rates[i].low <= currentTrade.stopLoss)
                {
                    shouldExit = true;
                    exitReason = "SL_HIT";
                    exitPrice = currentTrade.stopLoss;
                }
                // Check take profit
                else if(rates[i].high >= currentTrade.takeProfit)
                {
                    shouldExit = true;
                    exitReason = "TP_HIT";
                    exitPrice = currentTrade.takeProfit;
                }
            }
            else
            {
                // Sell position
                if(rates[i].high >= currentTrade.stopLoss)
                {
                    shouldExit = true;
                    exitReason = "SL_HIT";
                    exitPrice = currentTrade.stopLoss;
                }
                else if(rates[i].low <= currentTrade.takeProfit)
                {
                    shouldExit = true;
                    exitReason = "TP_HIT";
                    exitPrice = currentTrade.takeProfit;
                }
            }
            
            if(shouldExit)
            {
                currentTrade.closeTime = rates[i].time;
                currentTrade.exitPrice = exitPrice;
                currentTrade.exitReason = exitReason;
                
                // Calculate PnL
                double priceDiff = currentTrade.isBuy 
                    ? (exitPrice - currentTrade.entryPrice)
                    : (currentTrade.entryPrice - exitPrice);
                double pipsMoved = priceDiff / pipValue;
                double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
                double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
                
                if(tickSize > 0)
                {
                    currentTrade.pnl = (tickValue / tickSize) * priceDiff * currentTrade.lotSize;
                }
                else
                {
                    currentTrade.pnl = pipsMoved * currentTrade.lotSize * 10; // Simplified
                }
                
                // Update stats
                stats.totalTrades++;
                stats.currentBalance += currentTrade.pnl;
                
                if(currentTrade.pnl > 0)
                {
                    stats.winningTrades++;
                    stats.grossProfit += currentTrade.pnl;
                }
                else
                {
                    stats.losingTrades++;
                    stats.grossLoss += MathAbs(currentTrade.pnl);
                }
                
                // Update peak and drawdown
                if(stats.currentBalance > stats.peakBalance)
                    stats.peakBalance = stats.currentBalance;
                
                double drawdown = stats.peakBalance - stats.currentBalance;
                if(drawdown > stats.maxDrawdown)
                    stats.maxDrawdown = drawdown;
                
                // Save trade
                int tradeIdx = ArraySize(trades);
                ArrayResize(trades, tradeIdx + 1);
                trades[tradeIdx] = currentTrade;
                
                inPosition = false;
            }
        }
        
        // Check for entry signals (only if not in position)
        if(!inPosition)
        {
            bool buySignal = (rsi < InpRSIOversold);
            bool sellSignal = (rsi > InpRSIOverbought);
            
            if(buySignal || sellSignal)
            {
                currentTrade.openTime = rates[i].time;
                currentTrade.isBuy = buySignal;
                
                // Simulate limit order with slight improvement (if enabled)
                if(InpSimulateLimitOrders)
                {
                    // Assume limit order gets filled at slightly better price
                    double improvement = pipValue * 2; // 2 pips improvement
                    currentTrade.entryPrice = buySignal 
                        ? currentPrice - improvement 
                        : currentPrice + improvement;
                }
                else
                {
                    currentTrade.entryPrice = currentPrice;
                }
                
                // Set SL/TP
                if(buySignal)
                {
                    currentTrade.stopLoss = currentTrade.entryPrice - (InpStopLossPips * pipValue);
                    currentTrade.takeProfit = currentTrade.entryPrice + (InpTakeProfitPips * pipValue);
                }
                else
                {
                    currentTrade.stopLoss = currentTrade.entryPrice + (InpStopLossPips * pipValue);
                    currentTrade.takeProfit = currentTrade.entryPrice - (InpTakeProfitPips * pipValue);
                }
                
                // Calculate lot size
                currentTrade.lotSize = CalculateLotSize(symbol, stats.currentBalance, InpRiskPercent, InpStopLossPips);
                currentTrade.pnl = 0;
                currentTrade.exitReason = "";
                
                inPosition = true;
            }
        }
    }
    
    // Close any open position at end
    if(inPosition)
    {
        currentTrade.closeTime = rates[ratesCount - 1].time;
        currentTrade.exitPrice = rates[ratesCount - 1].close;
        currentTrade.exitReason = "END_OF_DATA";
        
        double priceDiff = currentTrade.isBuy 
            ? (currentTrade.exitPrice - currentTrade.entryPrice)
            : (currentTrade.entryPrice - currentTrade.exitPrice);
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        
        if(tickSize > 0)
            currentTrade.pnl = (tickValue / tickSize) * priceDiff * currentTrade.lotSize;
        else
            currentTrade.pnl = (priceDiff / pipValue) * currentTrade.lotSize * 10;
        
        stats.totalTrades++;
        stats.currentBalance += currentTrade.pnl;
        
        if(currentTrade.pnl > 0)
        {
            stats.winningTrades++;
            stats.grossProfit += currentTrade.pnl;
        }
        else
        {
            stats.losingTrades++;
            stats.grossLoss += MathAbs(currentTrade.pnl);
        }
        
        int tradeIdx = ArraySize(trades);
        ArrayResize(trades, tradeIdx + 1);
        trades[tradeIdx] = currentTrade;
    }
    
    stats.totalProfit = stats.grossProfit;
    stats.totalLoss = stats.grossLoss;
    
    return true;
}

//+------------------------------------------------------------------+
//| Print backtest results                                           |
//+------------------------------------------------------------------+
void PrintResults(const string symbol, const BacktestStats &stats, const SimulatedTrade &trades[])
{
    Print("\n========================================");
    Print("BACKTEST RESULTS");
    Print("========================================\n");
    
    Print("Symbol: ", symbol);
    Print("Order Type: ", InpSimulateLimitOrders ? "LIMIT ORDERS (simulated)" : "MARKET ORDERS");
    Print("");
    
    Print("=== TRADE STATISTICS ===");
    Print("Total Trades: ", stats.totalTrades);
    Print("Winning Trades: ", stats.winningTrades);
    Print("Losing Trades: ", stats.losingTrades);
    
    double winRate = stats.totalTrades > 0 ? (double)stats.winningTrades / stats.totalTrades * 100 : 0;
    Print("Win Rate: ", DoubleToString(winRate, 2), "%");
    Print("");
    
    Print("=== PROFIT/LOSS ===");
    Print("Starting Balance: $", DoubleToString(InpStartingBalance, 2));
    Print("Ending Balance: $", DoubleToString(stats.currentBalance, 2));
    Print("Net Profit: $", DoubleToString(stats.currentBalance - InpStartingBalance, 2));
    Print("Gross Profit: $", DoubleToString(stats.grossProfit, 2));
    Print("Gross Loss: $", DoubleToString(stats.grossLoss, 2));
    Print("");
    
    Print("=== RISK METRICS ===");
    Print("Max Drawdown: $", DoubleToString(stats.maxDrawdown, 2));
    double ddPercent = InpStartingBalance > 0 ? stats.maxDrawdown / InpStartingBalance * 100 : 0;
    Print("Max Drawdown %: ", DoubleToString(ddPercent, 2), "%");
    
    double profitFactor = stats.grossLoss > 0 ? stats.grossProfit / stats.grossLoss : 0;
    Print("Profit Factor: ", DoubleToString(profitFactor, 2));
    
    double avgWin = stats.winningTrades > 0 ? stats.grossProfit / stats.winningTrades : 0;
    double avgLoss = stats.losingTrades > 0 ? stats.grossLoss / stats.losingTrades : 0;
    Print("Average Win: $", DoubleToString(avgWin, 2));
    Print("Average Loss: $", DoubleToString(avgLoss, 2));
    
    double riskReward = avgLoss > 0 ? avgWin / avgLoss : 0;
    Print("Risk:Reward Ratio: ", DoubleToString(riskReward, 2), ":1");
    
    // Expectancy
    double expectancy = (winRate / 100 * avgWin) - ((100 - winRate) / 100 * avgLoss);
    Print("Expectancy: $", DoubleToString(expectancy, 2));
    Print("");
    
    // Show last 10 trades
    int tradeCount = ArraySize(trades);
    if(tradeCount > 0)
    {
        Print("=== LAST 10 TRADES ===");
        int start = MathMax(0, tradeCount - 10);
        for(int i = start; i < tradeCount; i++)
        {
            string direction = trades[i].isBuy ? "BUY" : "SELL";
            string result = trades[i].pnl >= 0 ? "WIN" : "LOSS";
            Print(StringFormat("#%d %s %s @ %.5f -> %.5f | %s | PnL: $%.2f", 
                  i + 1, direction, TimeToString(trades[i].openTime, TIME_DATE),
                  trades[i].entryPrice, trades[i].exitPrice,
                  trades[i].exitReason, trades[i].pnl));
        }
    }
    
    Print("\n========================================");
    Print("BACKTEST COMPLETE");
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("\n====================================");
    Print("CUSTOM DATABASE BACKTEST");
    Print("====================================\n");
    
    string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
    
    Print("[BACKTEST] Symbol: ", symbol);
    Print("[BACKTEST] Timeframe: ", EnumToString((ENUM_TIMEFRAMES)InpTimeframe));
    Print("[BACKTEST] Years: ", InpBacktestYears);
    Print("[BACKTEST] Order Type: ", InpSimulateLimitOrders ? "LIMIT" : "MARKET");
    Print("");
    
    // Database path
    string dbPath = "Data/GrandeTradingData.db";
    
    // Check if database exists
    if(!FileIsExist(dbPath))
    {
        Print("[BACKTEST] ERROR: Database not found at ", dbPath);
        Print("[BACKTEST] Please run BackfillHistoricalData.mq5 first to populate the database.");
        return;
    }
    
    // Create database manager
    g_dbManager = new CGrandeDatabaseManager();
    if(g_dbManager == NULL)
    {
        Print("[BACKTEST] ERROR: Failed to create database manager");
        return;
    }
    
    // Initialize database
    if(!g_dbManager.Initialize(dbPath, InpShowProgress))
    {
        Print("[BACKTEST] ERROR: Failed to initialize database");
        delete g_dbManager;
        return;
    }
    
    Print("[BACKTEST] Database initialized: ", dbPath);
    
    // Calculate date range
    datetime endDate = TimeCurrent();
    datetime startDate = endDate - (InpBacktestYears * 365 * 24 * 3600);
    
    Print("[BACKTEST] Date range: ", TimeToString(startDate, TIME_DATE), " to ", TimeToString(endDate, TIME_DATE));
    Print("");
    
    // Load historical data from database
    Print("[BACKTEST] Loading historical data from database...");
    
    MqlRates rates[];
    uint loadStart = GetTickCount();
    
    if(!g_dbManager.GetMarketDataRange(symbol, startDate, endDate, InpTimeframe, rates))
    {
        Print("[BACKTEST] ERROR: Failed to load market data from database");
        Print("[BACKTEST] Make sure you have backfilled data for ", symbol, " on timeframe ", InpTimeframe);
        delete g_dbManager;
        return;
    }
    
    uint loadDuration = GetTickCount() - loadStart;
    Print("[BACKTEST] Loaded ", ArraySize(rates), " bars in ", loadDuration, " ms");
    
    // Run backtest
    Print("\n[BACKTEST] Running simulation...");
    
    BacktestStats stats;
    SimulatedTrade trades[];
    
    uint backtestStart = GetTickCount();
    bool success = RunBacktest(symbol, rates, stats, trades);
    uint backtestDuration = GetTickCount() - backtestStart;
    
    if(!success)
    {
        Print("[BACKTEST] ERROR: Backtest simulation failed");
        delete g_dbManager;
        return;
    }
    
    Print("[BACKTEST] Simulation completed in ", backtestDuration, " ms");
    
    // Print results
    PrintResults(symbol, stats, trades);
    
    // Cleanup
    delete g_dbManager;
}

//+------------------------------------------------------------------+
