//+------------------------------------------------------------------+
//| QuantumTraderAI_TrendFollowing.mq5                               |
//| VSol Software                                                    |
//+------------------------------------------------------------------+
// Define constants for version and copyright
const string EA_VERSION = "1.14";
const string EA_COPYRIGHT = "VSol Software";
#property copyright "VSol Software"
#property version   "1.14"
#property strict

#include <Trade/Trade.mqh>
#include <Bandeira/Utility.mqh>


// Define threshold values
input double ADX_THRESHOLD = 20.0;
input double RSI_UPPER_THRESHOLD = 70.0;
input double RSI_LOWER_THRESHOLD = 30.0;
input double DI_DIFFERENCE_THRESHOLD = 2.0; // Minimum difference between DI+ and DI-

// Add these constants near the top of the file
const int LOG_INTERVAL_CALCULATIONS = 300;  // 5 minutes between calculation logs
const int LOG_INTERVAL_ANALYSIS = 900;      // 15 minutes between analysis logs
const int LOG_INTERVAL_SIGNALS = 600;       // 10 minutes between signal logs

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+

// Strategy Activation
input group "Strategy Settings"
input bool UseTrendStrategy = true;         // Enable or disable the Trend Following strategy
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1; // Default timeframe
input bool AllowShortTrades = true;         // Allow short (sell) trades

// Risk Management
input group "Risk Management"
input double RiskPercent = 2.0;             // Percentage of account equity risked per trade
input double MaxDrawdownPercent = 15.0;     // Maximum drawdown percentage allowed
input double ATRMultiplier = 1.5;           // ATR multiplier for dynamic SL/TP
input double fixedStopLossPips = 20.0;      // Fixed Stop Loss in pips

// Trend Indicators
input group "Trend Indicators"
input int ADXPeriod = 14;                   // ADX indicator period
input double TrendADXThreshold = 25.0;      // ADX threshold for trend
input double RSIUpperThreshold = 70.0;      // RSI overbought level
input double RSILowerThreshold = 30.0;      // RSI oversold level

// Trading Hours
input group "Trading Time Settings"
input string TradingStartTime = "00:00";    // Trading session start time
input string TradingEndTime = "23:59";      // Trading session end time

// Position Management
input group "Position Management"
input bool UseTrailingStop = false;         // Enable trailing stops
input double TrailingStopPips = 20.0;       // Trailing stop distance in pips
input bool UseBreakeven = false;             // Enable breakeven
input double BreakevenActivationPips = 30.0;// Breakeven activation distance
input double BreakevenOffsetPips = 5.0;     // Breakeven offset distance

// Order Flow Analysis
input group "Order Flow Settings"
input bool UseDOMAnalysis = false;          // Enable DOM analysis
input double LiquidityThreshold = 50.0;     // Liquidity pool threshold
input double ImbalanceThreshold = 1.5;      // Order flow imbalance ratio

// Pattern Recognition
input group "Pattern Recognition"
input int EMA_PERIODS_SHORT = 20;           // Short EMA period
input int EMA_PERIODS_MEDIUM = 50;          // Medium EMA period
input int EMA_PERIODS_LONG = 200;           // Long EMA period
input int PATTERN_LOOKBACK = 5;             // Pattern lookback periods
input double GOLDEN_CROSS_THRESHOLD = 0.001; // Golden cross threshold

// RSI/MACD Settings
input group "RSI/MACD Settings"
input int RSI_Period = 14;           // RSI Period
input int MACD_Fast = 12;            // MACD Fast EMA Period
input int MACD_Slow = 26;            // MACD Slow EMA Period
input int MACD_Signal = 9;           // MACD Signal Period
input double RSI_Neutral = 50.0;     // RSI Neutral Level

// Order Management
input group "Order Management"
input double TakeProfitPips = 50.0;         // Take Profit in pips
input double StopLossPips = 30.0;           // Stop Loss in pips

// Order Entry Settings
input group "Order Entry Settings"
input bool StrictOrderChecks = true;         // Use strict order entry conditions
input double SignalTolerancePercent = 20.0;  // Signal tolerance (lower = more trades)

// Modify symbol settings inputs
input group "Symbol Settings"
input bool UseMultipleSymbols = true;        // Trade multiple symbols
input int MaxSymbolsToTrade = 100;           // Maximum number of symbols to trade

//+------------------------------------------------------------------+
//| Global Variables and Objects                                     |
//+------------------------------------------------------------------+
CTrade trade;
double starting_balance;
// Add a minimum price change threshold (in points)
double MinPriceChangeThreshold = 10;

// Store the last modification price
double LastModificationPrice = 0;

// Declare a static variable to track the last log time
static datetime lastLogTime = 0;

// Declare the lastCalculationTime variable
datetime lastCalculationTime = 0;

// Add these variables to track last log times
struct LogTimes {
    datetime calculationLogTime;
    datetime analysisLogTime;
    datetime signalLogTime;
};
static LogTimes symbolLogTimes[];  // Array to store log times for each symbol

//+------------------------------------------------------------------+
//| Core EA Functions                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    // Log version and copyright information
    Print("=== Expert Advisor Initialized ===");
    Print("Version: ", EA_VERSION);
    Print("Copyright: ", EA_COPYRIGHT);
    Print("===================================");

    // Initialize with current chart symbol if not using multiple symbols
    if(!UseMultipleSymbols)
    {
        string symbol = ChartSymbol(0);  // Get symbol from current chart
        ArrayResize(tradingSymbols, 1);
        AddTradingSymbol(symbol, 0);
        SetSymbolCount(1);
        ValidateInputs(symbol);
    }
    else
    {
        // Get all symbols from Market Watch
        int totalSymbols = SymbolsTotal(true);  // true = only symbols in Market Watch
        int count = 0;
        
        // Ensure we don't exceed array bounds
        int maxSymbols = MathMin(totalSymbols, MaxSymbolsToTrade);
        ArrayResize(tradingSymbols, maxSymbols);
        
        for(int i = 0; i < totalSymbols && count < maxSymbols; i++)
        {
            string symbol = SymbolName(i, true);  // Get symbol name from Market Watch
            
            // Verify the symbol is valid and can be traded
            if(SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL)
            {
                if(!SymbolSelect(symbol, true))
                {
                    Print("Failed to add symbol to Market Watch: ", symbol);
                    continue;
                }
                
                AddTradingSymbol(symbol, count);
                count++;
                Print("Added symbol for trading: ", symbol);
            }
        }
        
        SetSymbolCount(count);
        
        if(count == 0)
        {
            Print("Error: No valid symbols found for trading");
            return INIT_FAILED;
        }
        
        Print("Total symbols added for trading: ", count);
    }

    // Ensure arrays are properly sized for all symbols
    ArrayResize(symbolLogTimes, symbolCount);
    InitializeLogTimes();
    InitializeLotSizeCalcTimes();

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Process each symbol in the trading symbols array
    for(int i = 0; i < symbolCount; i++)
    {
        string symbol = tradingSymbols[i];
        
        // Skip invalid symbols
        if(symbol == "" || !SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE))
            continue;
            
        ProcessSymbol(symbol);
        
        // Add delay between symbol processing to avoid overloading
        Sleep(100);  // 100ms delay
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Deinitializing EA...");
    // Additional cleanup code can be added here
}

//+------------------------------------------------------------------+
//| Execute Trading Logic                                            |
//+------------------------------------------------------------------+
void ExecuteTradingLogic(string symbol)
{
    // Check if within trading hours first
    if (!IsWithinTradingHours(TradingStartTime, TradingEndTime))
        return;

    // Check drawdown before proceeding
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if (CheckDrawdown(symbol, MaxDrawdownPercent, accountBalance, accountEquity))
        return;

    // Static variables to track last calculation time and signals
    static int lastTrendSignal = 0;
    static int lastOrderFlowSignal = 0;
    static int lastRsiMacdSignal = 0;
    static double lastStopLoss = 0;
    static double lastTakeProfit = 0;

    datetime currentTime = TimeCurrent();
    
    // Use the global lastCalculationTime
    bool shouldRecalculateSignals = (currentTime - lastCalculationTime >= 30);
    
    // Always manage existing positions
    if (UseTrailingStop || UseBreakeven)
    {
        ManagePositions(symbol);
    }

    if (UseTrendStrategy && shouldRecalculateSignals)
    {
        int symbolIdx = GetSymbolIndex(symbol);
        if(symbolIdx == -1)
        {
            Print("Error: Symbol not found in trading symbols array: ", symbol);
            return;
        }

        // Calculate indicators
        double rsi = CalculateRSI(symbol, RSI_Period, Timeframe);
        double ema_short = CalculateEMA(symbol, EMA_PERIODS_SHORT, Timeframe);
        double ema_medium = CalculateEMA(symbol, EMA_PERIODS_MEDIUM, Timeframe);
        double ema_long = CalculateEMA(symbol, EMA_PERIODS_LONG, Timeframe);
        double atr = CalculateATR(symbol, 14, Timeframe);
        double adx, plusDI, minusDI;
        CalculateADX(symbol, ADXPeriod, Timeframe, adx, plusDI, minusDI);
        double macdMain, macdSignal, macdHistogram;
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram);

        // Package the data for logging
        MarketAnalysisData analysisData;
        analysisData.currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        analysisData.ema_short = ema_short;
        analysisData.ema_medium = ema_medium;
        analysisData.ema_long = ema_long;
        analysisData.adx = adx;
        analysisData.plusDI = plusDI;
        analysisData.minusDI = minusDI;
        analysisData.rsi = rsi;
        analysisData.macdMain = macdMain;
        analysisData.macdSignal = macdSignal;
        analysisData.macdHistogram = macdHistogram;
        analysisData.atr = atr;
        analysisData.bullishPattern = IsBullishCandlePattern(symbol);
        analysisData.bearishPattern = IsBearishCandlePattern(symbol);

        // Package the parameters
        MarketAnalysisParameters params;
        params.ema_period_short = EMA_PERIODS_SHORT;
        params.ema_period_medium = EMA_PERIODS_MEDIUM;
        params.ema_period_long = EMA_PERIODS_LONG;
        params.adx_period = ADXPeriod;
        params.rsi_period = RSI_Period;
        params.trend_adx_threshold = TrendADXThreshold;
        params.rsi_upper_threshold = RSIUpperThreshold;
        params.rsi_lower_threshold = RSILowerThreshold;

        // Only log market analysis if enough time has passed for this symbol
        if (currentTime - symbolLogTimes[symbolIdx].analysisLogTime >= LOG_INTERVAL_ANALYSIS)
        {
            LogMarketAnalysis(symbol, analysisData, params, Timeframe, UseDOMAnalysis);
            symbolLogTimes[symbolIdx].analysisLogTime = currentTime;
        }

        // Calculate signals
        int orderFlowSignal = MonitorOrderFlow(symbol);
        int trendSignal = TrendFollowingCore(symbol);
        int patternSignal = IdentifyTrendPattern(symbol);
        int rsiMacdSignal = CheckRSIMACDSignal(symbol);
        
        // Use a local variable for RiskPercent modification
        double localRiskPercent = RiskPercent;

        // Double the risk if RSI/MACD signal is triggered
        if (rsiMacdSignal != 0)
        {
            localRiskPercent *= 2;
            Print("Doubling Risk: New RiskPercent = ", localRiskPercent);
        }

        // Calculate stop loss and take profit only when needed
        double stopLoss, takeProfit;
        CalculateDynamicSLTP(symbol, stopLoss, takeProfit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

        // Calculate lot size using the now-defined stopLoss
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        double lotSize = CalculateDynamicLotSize(
            symbol,
            stopLoss / SymbolInfoDouble(symbol, SYMBOL_POINT),    // stop loss in pips
            accountEquity,        // current account equity
            RiskPercent,         // risk percent
            minVolume,           // minimum volume
            maxVolume            // maximum volume
        );

        // For BUY signals
        if (StrictOrderChecks)
        {
            // Original strict conditions
            if (trendSignal == 1 && patternSignal == 1 && rsiMacdSignal == 1 && orderFlowSignal == 1)
            {
                ProcessBuySignal(symbol, lotSize, stopLoss, takeProfit);
            }
        }
        else
        {
            // More lenient conditions - only need majority of signals
            int totalBuySignals = (trendSignal == 1 ? 1 : 0) + 
                                   (patternSignal == 1 ? 1 : 0) + 
                                   (rsiMacdSignal == 1 ? 1 : 0) + 
                                   (orderFlowSignal == 1 ? 1 : 0);
            
            double requiredSignals = 4 * (1 - SignalTolerancePercent/100.0);  // Adjust threshold based on tolerance
            if (totalBuySignals >= requiredSignals)
            {
                ProcessBuySignal(symbol, lotSize, stopLoss, takeProfit);
            }
        }

        // For SELL signals
        if (AllowShortTrades)
        {
            if (StrictOrderChecks)
            {
                // Original strict conditions
                if (trendSignal == -1 && patternSignal == -1 && rsiMacdSignal == -1 && orderFlowSignal == -1)
                {
                    ProcessSellSignal(symbol, lotSize, stopLoss, takeProfit);
                }
            }
            else
            {
                // More lenient conditions - only need majority of signals
                int totalSellSignals = (trendSignal == -1 ? 1 : 0) + 
                                      (patternSignal == -1 ? 1 : 0) + 
                                      (rsiMacdSignal == -1 ? 1 : 0) + 
                                      (orderFlowSignal == -1 ? 1 : 0);
                
                double requiredSignals = 4 * (1 - SignalTolerancePercent/100.0);  // Adjust threshold based on tolerance
                if (totalSellSignals >= requiredSignals)
                {
                    ProcessSellSignal(symbol, lotSize, stopLoss, takeProfit);
                }
            }
        }

        // Update last values
        lastOrderFlowSignal = orderFlowSignal;
        lastTrendSignal = trendSignal;
        lastRsiMacdSignal = rsiMacdSignal;
        lastStopLoss = stopLoss;
        lastTakeProfit = takeProfit;
        lastCalculationTime = currentTime;

        // Only log signals if enough time has passed for this symbol
        if (currentTime - symbolLogTimes[symbolIdx].signalLogTime >= LOG_INTERVAL_SIGNALS)
        {
            Print("Updated Signals and Parameters for ", symbol, ":");
            Print("  Last Order Flow Signal: ", lastOrderFlowSignal);
            Print("  Last Trend Signal: ", lastTrendSignal);
            Print("  Last RSI/MACD Signal: ", lastRsiMacdSignal);
            Print("  Last Pattern Signal: ", patternSignal); 
            Print("  Last Stop Loss: ", lastStopLoss);
            Print("  Last Take Profit: ", lastTakeProfit);
            Print("  Last Calculation Time: ", TimeToString(lastCalculationTime, TIME_DATE | TIME_MINUTES));
            symbolLogTimes[symbolIdx].signalLogTime = currentTime;
        }

        // If no trade signal is generated, log the reason
        if (orderFlowSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600) // Check if an hour has passed
            {
                LogTradeRejection("No order flow signal detected", symbol, SymbolInfoDouble(symbol, SYMBOL_BID), 
                                 adx, rsi, ema_short, ema_medium, ema_long,
                                 ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD);
                lastLogTime = TimeCurrent(); // Update last log time
            }
        }
        if (trendSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600)
            {
                LogTradeRejection("No trend signal detected", symbol, SymbolInfoDouble(symbol, SYMBOL_BID), 
                                 adx, rsi, ema_short, ema_medium, ema_long,
                                 ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD);
                lastLogTime = TimeCurrent();
            }
        }
        if (rsiMacdSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600)
            {
                LogTradeRejection("No RSI/MACD signal detected", symbol, SymbolInfoDouble(symbol, SYMBOL_BID), 
                                 adx, rsi, ema_short, ema_medium, ema_long,
                                 ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD);
                lastLogTime = TimeCurrent();
            }
        }
        if (patternSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600)
            {
                LogTradeRejection("No pattern signal detected", symbol, SymbolInfoDouble(symbol, SYMBOL_BID), 
                                 adx, rsi, ema_short, ema_medium, ema_long,
                                 ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD);
                lastLogTime = TimeCurrent();
            }
        }
        
        // Only log calculations if enough time has passed for this symbol
        if (currentTime - symbolLogTimes[symbolIdx].calculationLogTime >= LOG_INTERVAL_CALCULATIONS)
        {
            Print("=== CalculateDynamicLotSize Debug for ", symbol, " ===");
            Print("Symbol: ", symbol);
            Print("Account Balance: ", accountBalance);
            Print("Risk Percent: ", RiskPercent, "%");
            Print("Intended Monetary Risk: ", localRiskPercent * accountBalance / 100);
            Print("Stop Loss Pips: ", stopLoss / _Point);
            Print("Tick Value: ", tickValue);
            Print("Tick Size: ", SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE));
            Print("Lot Step: ", SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP));
            Print("Pip Value: ", tickValue);
            Print("Calculated Lot Size: ", lotSize);
            Print("Actual Monetary Risk: ", lotSize * stopLoss * tickValue);
            Print("==============================");
            symbolLogTimes[symbolIdx].calculationLogTime = currentTime;
        }
    }
}

void ProcessBuySignal(string symbol, double lotSize, double stopLoss, double takeProfit)
{
    // Require 3 bars of confirmation for more reliability
    if(!CheckConsecutiveSignals(symbol, 3, true))
    {
        Print("Buy signal rejected - Failed 3-bar persistence check");
        return;
    }

    if (!IsBearishCandlePattern(symbol))
    {
        if (!ManagePositions(symbol, POSITION_TYPE_BUY) && !HasPendingOrder(symbol, ORDER_TYPE_BUY_LIMIT))
        {
            double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double tpPrice = ask + takeProfit;
            double slPrice = ask - stopLoss;
            
            double limitPrice = GetBestLimitOrderPrice(symbol, ORDER_TYPE_BUY_LIMIT, tpPrice, slPrice, 
                                                       LiquidityThreshold, TakeProfitPips, StopLossPips);
            
            if (limitPrice > 0.0)
            {
                Print("Buy Limit Order Placed - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
                PlaceBuyLimitOrder(symbol, limitPrice, tpPrice, slPrice);
            }
            else
            {
                Print("Buy Market Order Placed - TP: ", tpPrice, " SL: ", slPrice, " Lot Size: ", lotSize);
                PlaceBuyOrder(symbol);
            }
        }
    }
    else
    {
        Print("Buy Signal Rejected - Strong bearish pattern detected");
    }
}

void ProcessSellSignal(string symbol, double lotSize, double stopLoss, double takeProfit)
{
    // Require 3 bars of confirmation for more reliability
    if(!CheckConsecutiveSignals(symbol, 3, false))
    {
        Print("Sell signal rejected - Failed 3-bar persistence check");
        return;
    }

    if (!IsBullishCandlePattern(symbol))
    {
        if (!ManagePositions(symbol, POSITION_TYPE_SELL) && !HasPendingOrder(symbol, ORDER_TYPE_SELL_LIMIT))
        {
            double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
            double tpPrice = bid - takeProfit;
            double slPrice = bid + stopLoss;
            
            double limitPrice = GetBestLimitOrderPrice(symbol, ORDER_TYPE_SELL_LIMIT, tpPrice, slPrice, 
                                                       LiquidityThreshold, TakeProfitPips, StopLossPips);
            
            if (limitPrice > 0.0)
            {
                Print("Sell Limit Order Placed - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
                PlaceSellLimitOrder(symbol, limitPrice, tpPrice, slPrice);
            }
            else
            {
                Print("Sell Market Order Placed - TP: ", tpPrice, " SL: ", slPrice);
                PlaceSellOrder(symbol);
            }
        }
    }
    else
    {
        Print("Sell Signal Rejected - Strong bullish pattern detected");
    }
}

//+------------------------------------------------------------------+
//| Trend Following Core Strategy                                    |
//+------------------------------------------------------------------+
int TrendFollowingCore(string symbol)
{
    double sma = CalculateSMA(symbol, 100, Timeframe);
    double ema = CalculateEMA(symbol, 20, Timeframe);
    double rsi = CalculateRSI(symbol, 14, Timeframe);
    double atr = CalculateATR(symbol, 14, Timeframe);
    
    double adx, plusDI, minusDI;
    CalculateADX(symbol, ADXPeriod, Timeframe, adx, plusDI, minusDI);
    
    static datetime lastBuySignalTime = 0;
    static datetime lastSellSignalTime = 0;
    
    // Define a minimum time interval between log messages (in seconds)
    int minLogInterval = 300; // 5 minutes
    
    // Calculate DI difference
    double diDifference = MathAbs(plusDI - minusDI);

    
    if (ema > sma && rsi < RSIUpperThreshold && adx > TrendADXThreshold && 
        plusDI > minusDI && diDifference > DI_DIFFERENCE_THRESHOLD)
    {
        if (HasActiveTradeOrPendingOrder(symbol, POSITION_TYPE_BUY))
        {
            datetime currentTime = TimeCurrent();
            if (currentTime - lastBuySignalTime >= minLogInterval)
            {
                Print("Trend Following: Buy Signal - Active Position");
                Print("DI+ (", plusDI, ") > DI- (", minusDI, "), Difference: ", diDifference);
                lastBuySignalTime = currentTime;
            }
        }
        return 1;
    }
    else if (ema < sma && rsi > RSILowerThreshold && adx > TrendADXThreshold && 
             minusDI > plusDI && diDifference > DI_DIFFERENCE_THRESHOLD)
    {
        if (HasActiveTradeOrPendingOrder(symbol, POSITION_TYPE_SELL))
        {
            datetime currentTime = TimeCurrent();
            if (currentTime - lastSellSignalTime >= minLogInterval)
            {
                Print("Trend Following: Sell Signal - Active Position");
                Print("DI- (", minusDI, ") > DI+ (", plusDI, "), Difference: ", diDifference);
                lastSellSignalTime = currentTime;
            }
        }
        return -1;
    }
    
    // Log rejection reason if DI difference is too small
    if (diDifference <= DI_DIFFERENCE_THRESHOLD)
    {
        static datetime lastDILogTime = 0;
        datetime currentTime = TimeCurrent();
        if (currentTime - lastDILogTime >= minLogInterval)
        {
            Print("Trade rejected: DI difference (", diDifference, 
                  ") below threshold (", DI_DIFFERENCE_THRESHOLD, ")");
            lastDILogTime = currentTime;
        }
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Check and Manage Positions                                       |
//+------------------------------------------------------------------+
bool ManagePositions(string symbol, int checkType = -1)  // -1 means check all positions
{
    bool hasPosition = false;
    int total = PositionsTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            // Check if position is for our symbol
            string symbol = PositionGetString(POSITION_SYMBOL);
            if(symbol != symbol) continue;
            
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            
            // If checking for specific type and doesn't match, skip
            if(checkType != -1 && posType != checkType) continue;
            
            hasPosition = true;
            
            // Only manage if trailing stop or breakeven is enabled
            if(UseTrailingStop || UseBreakeven)
            {
                double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
                double stop_loss = PositionGetDouble(POSITION_SL);
                double profit = PositionGetDouble(POSITION_PROFIT);

                // Apply trailing stop if enabled
                if(UseTrailingStop)
                    ApplyTrailingStop(symbol, ticket, posType, open_price, stop_loss);

                // Apply breakeven if enabled
                if(UseBreakeven)
                    ApplyBreakeven(symbol, ticket, posType, open_price, stop_loss);
            }
        }
    }
    
    return hasPosition;
}

//+------------------------------------------------------------------+
//| Detect Order Flow Imbalances                                     |
//+------------------------------------------------------------------+
int DetectOrderFlowImbalances(string symbol, double buyVolume, double sellVolume, double imbalanceThreshold)
{
    // Calculate imbalance ratio for logging
    double imbalanceRatio = 0;
    if (sellVolume > 0) imbalanceRatio = buyVolume / sellVolume;
    
    if (buyVolume > sellVolume * imbalanceThreshold)
    {
        Print("Order Flow Imbalance Detected: More Buy Orders (Ratio: ", imbalanceRatio, ")");
        return 1;  // Buy signal
    }
    else if (sellVolume > buyVolume * imbalanceThreshold)
    {
        Print("Order Flow Imbalance Detected: More Sell Orders (Ratio: ", imbalanceRatio, ")");
        return -1; // Sell signal
    }
    
    return 0;  // No significant imbalance
}

//+------------------------------------------------------------------+
//| Monitor Order Flow                                               |
//+------------------------------------------------------------------+
int MonitorOrderFlow(string symbol)
{
    if (!UseDOMAnalysis)
        return 1; // Return neutral signal if DOM analysis is disabled

    MqlBookInfo book_info[];
    int book_count = MarketBookGet(symbol, book_info);
    
    if (book_count <= 0)
    {
        static datetime lastWarningTime = 0;
        datetime currentTime = TimeCurrent();
        if (currentTime - lastWarningTime >= 300) // Log warning every 5 minutes
        {
            Print("Warning: No DOM data available. Returning neutral signal.");
            lastWarningTime = currentTime;
        }
        return 1; // Return neutral instead of 0 to not block trades
    }

    double buyVolume = 0.0;
    double sellVolume = 0.0;
    double totalVolume = 0.0;
    double maxBuyPrice = 0.0;
    double minSellPrice = DBL_MAX;
    double largestBuyOrder = 0.0;
    double largestSellOrder = 0.0;
    int buyLevels = 0;
    int sellLevels = 0;
    
    // Calculate average order size for normalization
    double totalOrderSize = 0.0;
    int orderCount = 0;

    // First pass - calculate averages
    for (int i = 0; i < book_count; i++)
    {
        totalOrderSize += book_info[i].volume;
        orderCount++;
    }
    double avgOrderSize = (orderCount > 0) ? totalOrderSize / orderCount : 0;

    // Second pass - analyze order flow with normalized volumes
    for (int i = 0; i < book_count; i++)
    {
        double normalizedVolume = (avgOrderSize > 0) ? book_info[i].volume / avgOrderSize : book_info[i].volume;
        
        if (book_info[i].type == BOOK_TYPE_BUY)
        {
            buyVolume += normalizedVolume;
            buyLevels++;
            maxBuyPrice = MathMax(maxBuyPrice, book_info[i].price);
            largestBuyOrder = MathMax(largestBuyOrder, normalizedVolume);
        }
        else if (book_info[i].type == BOOK_TYPE_SELL)
        {
            sellVolume += normalizedVolume;
            sellLevels++;
            minSellPrice = MathMin(minSellPrice, book_info[i].price);
            largestSellOrder = MathMax(largestSellOrder, normalizedVolume);
        }
    }

    totalVolume = buyVolume + sellVolume;
    double buyPercentage = (totalVolume > 0) ? (buyVolume / totalVolume) * 100 : 0;
    double sellPercentage = (totalVolume > 0) ? (sellVolume / totalVolume) * 100 : 0;
    double imbalanceRatio = (sellVolume > 0) ? buyVolume / sellVolume : 1.0;

    // Reduced imbalance threshold for more frequent signals
    double adjustedImbalanceThreshold = ImbalanceThreshold * 0.8; // 20% more lenient

    // More lenient liquidity check
    bool sufficientLiquidity = (totalVolume >= LiquidityThreshold * 0.7); // 30% more lenient

    // Log order flow analysis
    static datetime lastDetailedLog = 0;
    datetime currentTime = TimeCurrent();
    
    if (currentTime - lastDetailedLog >= 300) // Log details every 5 minutes
    {
        string flowDirection = "NEUTRAL";
        if (imbalanceRatio > adjustedImbalanceThreshold) flowDirection = "BUY";
        else if (imbalanceRatio < 1/adjustedImbalanceThreshold) flowDirection = "SELL";

        Print("=== Order Flow Analysis ===");
        Print("Buy Volume: ", buyVolume, " (", buyPercentage, "%)");
        Print("Sell Volume: ", sellVolume, " (", sellPercentage, "%)");
        Print("Imbalance Ratio: ", imbalanceRatio);
        Print("Adjusted Threshold: ", adjustedImbalanceThreshold);
        Print("Flow Direction: ", flowDirection);
        Print("Liquidity Status: ", (sufficientLiquidity ? "Sufficient" : "Insufficient"));
        Print("========================");
        
        lastDetailedLog = currentTime;
    }

    // Return signals with more lenient conditions
    if (sufficientLiquidity)
    {
        if (imbalanceRatio > adjustedImbalanceThreshold)
            return 1;  // Buy signal
        else if (imbalanceRatio < 1/adjustedImbalanceThreshold)
            return -1; // Sell signal
        else
            return 1;  // Return neutral signal instead of 0 when no clear imbalance
    }
    
    // Even with insufficient liquidity, return neutral instead of blocking
    return 1;
}

//+------------------------------------------------------------------+
//| Calculate MACD Values                                            |
//+------------------------------------------------------------------+
void CalculateMACD(string symbol, double &macdMain, double &macdSignal, double &macdHistogram, int shift = 0)
{
    int handle = iMACD(symbol, Timeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    if(handle == INVALID_HANDLE)
    {
        Print("Error creating MACD indicator handle");
        return;
    }

    double macdBuffer[];
    double signalBuffer[];
    ArraySetAsSeries(macdBuffer, true);
    ArraySetAsSeries(signalBuffer, true);

    CopyBuffer(handle, 0, shift, 2, macdBuffer);    // MACD line
    CopyBuffer(handle, 1, shift, 2, signalBuffer);  // Signal line

    macdMain = macdBuffer[0];
    macdSignal = signalBuffer[0];
    macdHistogram = macdMain - macdSignal;

    IndicatorRelease(handle);
}

//+------------------------------------------------------------------+
//| Check RSI and MACD Combination Signal                            |
//+------------------------------------------------------------------+
int CheckRSIMACDSignal(string symbol)
{
    double rsi = CalculateRSI(symbol, RSI_Period, Timeframe, 0);
    double macdMain, macdSignal, macdHistogram;
    CalculateMACD(symbol, macdMain, macdSignal, macdHistogram);
    
    // Get dynamic thresholds
    double dynamic_upper, dynamic_lower;
    GetDynamicRSIThresholds(symbol, dynamic_upper, dynamic_lower);
    
    // Check for divergence
    bool bullish_div, bearish_div;
    CheckRSIDivergence(symbol, bullish_div, bearish_div);
    
    // Enhanced Buy Signal Conditions
    bool buySignal = 
        ((rsi < dynamic_lower) || bullish_div) &&    // RSI oversold OR bullish divergence
        macdMain > macdSignal &&                     // MACD above signal
        macdHistogram > 0 &&                         // Positive momentum
        rsi > CalculateRSI(symbol, RSI_Period, Timeframe, 1);          // RSI increasing
        
    // Enhanced Sell Signal Conditions    
    bool sellSignal = 
        ((rsi > dynamic_upper) || bearish_div) &&    // RSI overbought OR bearish divergence
        macdMain < macdSignal &&                     // MACD below signal
        macdHistogram < 0 &&                         // Negative momentum
        rsi < CalculateRSI(symbol, RSI_Period, Timeframe, 1);          // RSI decreasing
    
    // Return signals with logging
    if(buySignal)
    {
        Print("RSI Buy Signal - Value: ", rsi, 
              " Dynamic Lower: ", dynamic_lower,
              " Divergence: ", bullish_div);
        return 1;
    }
    if(sellSignal)
    {
        Print("RSI Sell Signal - Value: ", rsi,
              " Dynamic Upper: ", dynamic_upper,
              " Divergence: ", bearish_div);
        return -1;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Candle Pattern Analysis Functions                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check for Bullish Candle Pattern                                |
//+------------------------------------------------------------------+
bool IsBullishCandlePattern(string symbol)
{
    CandleData current = GetCandleData(symbol, 1, Timeframe);
    CandleData previous = GetCandleData(symbol, 2, Timeframe);
    
    // Get average candle size for reference
    double avgCandleSize = 0;
    double avgVolume = 0;
    for(int i = 1; i <= 10; i++)
    {
        CandleData temp = GetCandleData(symbol, i, Timeframe);
        avgCandleSize += temp.body;
        avgVolume += iVolume(symbol, Timeframe, i);
    }
    avgCandleSize /= 10;
    avgVolume /= 10;
    
    // Only return true for very strong bullish patterns
    
    // 1. Strong Bullish Engulfing (more stringent criteria)
    bool isStrongBullishEngulfing = 
        current.isBullish &&
        !previous.isBullish &&
        current.open < previous.close &&
        current.close > previous.open &&
        current.body > previous.body * 1.5 && // Increased size requirement
        current.body > avgCandleSize * 1.2 &&   // Must be larger than average
        iVolume(symbol, Timeframe, 1) > avgVolume * 1.5; // Volume confirmation
    
    // 2. Perfect Morning Star
    CandleData twoDaysAgo = GetCandleData(symbol, 3, Timeframe);
    bool isPerfectMorningStar =
        !twoDaysAgo.isBullish &&
        current.isBullish &&
        previous.body < avgCandleSize * 0.3 && // Smaller doji body
        twoDaysAgo.body > avgCandleSize * 1.2 &&
        current.body > avgCandleSize * 1.2 &&
        current.close > twoDaysAgo.open && // More stringent price requirement
        iVolume(symbol, Timeframe, 1) > avgVolume * 1.5; // Volume confirmation
    
    // 3. Clear Hammer
    bool isClearHammer = 
        current.isBullish &&
        current.lowerWick > current.body * 3 && // Increased wick requirement
        current.upperWick < current.body * 0.1 && // Minimal upper wick
        current.body > avgCandleSize * 0.8 &&
        current.low < previous.low && // Must make new low
        iVolume(symbol, Timeframe, 1) > avgVolume * 1.5; // Volume confirmation
    
    // Log pattern detection with confidence levels
    if(isStrongBullishEngulfing) Print("Strong Bullish Engulfing Pattern - High Confidence Reversal Signal");
    if(isPerfectMorningStar) Print("Perfect Morning Star Pattern - High Confidence Reversal Signal");
    if(isClearHammer) Print("Clear Hammer Pattern - High Confidence Reversal Signal");
    
    return (isStrongBullishEngulfing || isPerfectMorningStar || isClearHammer);
}

//+------------------------------------------------------------------+
//| Check for Bearish Candle Pattern                                |
//+------------------------------------------------------------------+
bool IsBearishCandlePattern(string symbol)
{
    CandleData current = GetCandleData(symbol, 1, Timeframe);
    CandleData previous = GetCandleData(symbol, 2, Timeframe);
    
    // Get average candle size for reference
    double avgCandleSize = 0;
    double avgVolume = 0;
    for(int i = 1; i <= 10; i++)
    {
        CandleData temp = GetCandleData(symbol, i, Timeframe);
        avgCandleSize += temp.body;
        avgVolume += iVolume(symbol, Timeframe, i);
    }
    avgCandleSize /= 10;
    avgVolume /= 10;
    
    // Only return true for very strong bearish patterns
    
    // 1. Strong Bearish Engulfing (more stringent criteria)
    bool isStrongBearishEngulfing = 
        !current.isBullish &&
        previous.isBullish &&
        current.open > previous.close &&
        current.close < previous.open &&
        current.body > previous.body * 1.5 && // Increased size requirement
        current.body > avgCandleSize * 1.2 &&   // Must be larger than average
        iVolume(symbol, Timeframe, 1) > avgVolume * 1.5; // Volume confirmation
    
    // 2. Perfect Evening Star
    CandleData twoDaysAgo = GetCandleData(symbol, 3, Timeframe);
    bool isPerfectEveningStar =
        twoDaysAgo.isBullish &&
        !current.isBullish &&
        previous.body < avgCandleSize * 0.3 && // Smaller doji body
        twoDaysAgo.body > avgCandleSize * 1.2 &&
        current.body > avgCandleSize * 1.2 &&
        current.close < twoDaysAgo.open && // More stringent price requirement
        iVolume(symbol, Timeframe, 1) > avgVolume * 1.5; // Volume confirmation
    
    // 3. Clear Shooting Star
    bool isClearShootingStar = 
        !current.isBullish &&
        current.upperWick > current.body * 3 && // Increased wick requirement
        current.lowerWick < current.body * 0.1 && // Minimal lower wick
        current.body > avgCandleSize * 0.8 &&
        current.high > previous.high && // Must make new high
        iVolume(symbol, Timeframe, 1) > avgVolume * 1.5; // Volume confirmation
    
    // Log pattern detection with confidence levels
    if(isStrongBearishEngulfing) Print("Strong Bearish Engulfing Pattern - High Confidence Reversal Signal");
    if(isPerfectEveningStar) Print("Perfect Evening Star Pattern - High Confidence Reversal Signal");
    if(isClearShootingStar) Print("Clear Shooting Star Pattern - High Confidence Reversal Signal");
    
    return (isStrongBearishEngulfing || isPerfectEveningStar || isClearShootingStar);
}

//+------------------------------------------------------------------+
//| Comprehensive Pattern Recognition                                 |
//+------------------------------------------------------------------+
int IdentifyTrendPattern(string symbol)
{
    // Initialize scoring system
    struct TrendScore {
        double bullish;
        double bearish;
        string reasons[];
    } score;
    score.bullish = 0;
    score.bearish = 0;
    
    // 1. Multiple EMA Analysis with validation
    double current_ema_short = CalculateEMA(symbol, EMA_PERIODS_SHORT, Timeframe, 0);
    double current_ema_medium = CalculateEMA(symbol, EMA_PERIODS_MEDIUM, Timeframe, 0);
    double current_ema_long = CalculateEMA(symbol, EMA_PERIODS_LONG, Timeframe, 0);
    
    // Validate EMA values
    if(current_ema_short == 0 || current_ema_medium == 0 || current_ema_long == 0) {
        Print("Warning: Invalid EMA values detected");
        return 0;
    }
    
    // Store historical EMA values with validation
    double past_ema_short[], past_ema_medium[], past_ema_long[];
    ArrayResize(past_ema_short, PATTERN_LOOKBACK);
    ArrayResize(past_ema_medium, PATTERN_LOOKBACK);
    ArrayResize(past_ema_long, PATTERN_LOOKBACK);
    
    for(int i = 0; i < PATTERN_LOOKBACK; i++) {
        past_ema_short[i] = CalculateEMA(symbol, EMA_PERIODS_SHORT, Timeframe, i+1);
        past_ema_medium[i] = CalculateEMA(symbol, EMA_PERIODS_MEDIUM, Timeframe, i+1);
        past_ema_long[i] = CalculateEMA(symbol, EMA_PERIODS_LONG, Timeframe, i+1);
        
        if(past_ema_short[i] == 0 || past_ema_medium[i] == 0 || past_ema_long[i] == 0) {
            Print("Warning: Historical EMA data incomplete");
            return 0;
        }
    }

    // 2. Enhanced Trend Strength Analysis
    
    // Check EMA alignment with weighted scoring
    if(current_ema_short > current_ema_medium && current_ema_medium > current_ema_long) {
        // Get MACD values for momentum confirmation
        double macdMain, macdSignal, macdHistogram;
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram);
        
        // Enhanced bullish scoring with momentum confirmation
        if(macdHistogram > 0) {  // Positive momentum
            score.bullish += 3.0;  // Increased from 2.5 to 3.0 for strong confirmation
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Bullish EMA alignment with positive momentum";
        } else {
            score.bullish += 1.5;  // Reduced score without momentum confirmation
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Bullish EMA alignment (weak momentum)";
        }
    }
    else if(current_ema_short < current_ema_medium && current_ema_medium < current_ema_long) {
        // Get MACD values for momentum confirmation
        double macdMain, macdSignal, macdHistogram;
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram);
        
        // Enhanced bearish scoring with momentum confirmation
        if(macdHistogram < 0) {  // Negative momentum
            score.bearish += 3.0;  // Increased from 2.5 to 3.0 for strong confirmation
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Bearish EMA alignment with negative momentum";
        } else {
            score.bearish += 1.5;  // Reduced score without momentum confirmation
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Bearish EMA alignment (weak momentum)";
        }
    }

    // 3. Enhanced Golden/Death Cross Detection with Confirmation
    bool golden_cross = false;
    bool death_cross = false;
    double cross_strength = 0;

    // Check for golden cross with momentum confirmation
    if(current_ema_short > current_ema_long && past_ema_short[0] < past_ema_long[0]) {
        cross_strength = MathAbs(current_ema_short - current_ema_long) / _Point;
        if(cross_strength > GOLDEN_CROSS_THRESHOLD) {
            golden_cross = true;
            score.bullish += 3.0 * (cross_strength / GOLDEN_CROSS_THRESHOLD);
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Golden Cross - Strength: " + DoubleToString(cross_strength);
        }
    }
    // Check for death cross with momentum confirmation
    else if(current_ema_short < current_ema_long && past_ema_short[0] > past_ema_long[0]) {
        cross_strength = MathAbs(current_ema_short - current_ema_long) / _Point;
        if(cross_strength > GOLDEN_CROSS_THRESHOLD) {
            death_cross = true;
            score.bearish += 3.0 * (cross_strength / GOLDEN_CROSS_THRESHOLD);
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Death Cross - Strength: " + DoubleToString(cross_strength);
        }
    }

    // 4. Enhanced Trend Continuation Pattern
    int consecutive_bullish = 0;
    int consecutive_bearish = 0;
    
    for(int i = 0; i < PATTERN_LOOKBACK - 1; i++) {
        if(past_ema_short[i] > past_ema_medium[i] && past_ema_medium[i] > past_ema_long[i])
            consecutive_bullish++;
        else if(past_ema_short[i] < past_ema_medium[i] && past_ema_medium[i] < past_ema_long[i])
            consecutive_bearish++;
    }
    
    // Add trend consistency score
    if(consecutive_bullish >= PATTERN_LOOKBACK * 0.8) {
        score.bullish += 2.0;
        ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
        score.reasons[ArraySize(score.reasons)-1] = "Strong Bullish Trend Consistency";
    }
    if(consecutive_bearish >= PATTERN_LOOKBACK * 0.8) {
        score.bearish += 2.0;
        ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
        score.reasons[ArraySize(score.reasons)-1] = "Strong Bearish Trend Consistency";
    }

    // 5. Volume Analysis with Trend Confirmation
    double current_volume = iVolume(symbol, Timeframe, 0);
    double avg_volume = 0;
    for(int i = 1; i <= PATTERN_LOOKBACK; i++) {
        avg_volume += iVolume(symbol, Timeframe, i);
    }
    avg_volume /= PATTERN_LOOKBACK;

    // Volume trend confirmation
    if(current_volume > avg_volume * 1.5) {
        if(score.bullish > score.bearish)
            score.bullish += 1.5;
        else if(score.bearish > score.bullish)
            score.bearish += 1.5;
            
        ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
        score.reasons[ArraySize(score.reasons)-1] = "Strong Volume Confirmation: " + DoubleToString(current_volume/avg_volume);
    }

    // 6. Log detailed analysis
    string analysis = "=== Trend Pattern Analysis ===\n";
    analysis += "Bullish Score: " + DoubleToString(score.bullish, 2) + "\n";
    analysis += "Bearish Score: " + DoubleToString(score.bearish, 2) + "\n";
    analysis += "Reasons:\n";
    for(int i = 0; i < ArraySize(score.reasons); i++) {
        analysis += "- " + score.reasons[i] + "\n";
    }
    Print(analysis);

    // 7. Final Decision Making with Minimum Threshold
    const double MIN_SCORE_THRESHOLD = 5.0; // Minimum score required for signal
    const double SCORE_DIFFERENCE_THRESHOLD = 2.0; // Minimum difference between bull/bear scores
    
    if(score.bullish >= MIN_SCORE_THRESHOLD && 
       score.bullish - score.bearish >= SCORE_DIFFERENCE_THRESHOLD)
        return 1;  // Strong bullish pattern
    else if(score.bearish >= MIN_SCORE_THRESHOLD && 
            score.bearish - score.bullish >= SCORE_DIFFERENCE_THRESHOLD)
        return -1; // Strong bearish pattern
    
    return 0;     // No clear pattern or insufficient strength
}

//+------------------------------------------------------------------+
//| Check for RSI Divergence                                         |
//+------------------------------------------------------------------+
bool CheckRSIDivergence(string symbol, bool &bullish, bool &bearish, int lookback = 10)
{
    double rsi_values[];
    double price_values[];
    ArrayResize(rsi_values, lookback);
    ArrayResize(price_values, lookback);
    
    // Get RSI and price values
    for(int i = 0; i < lookback; i++)
    {
        rsi_values[i] = CalculateRSI(symbol, RSI_Period, Timeframe, i);
        price_values[i] = iLow(symbol, Timeframe, i);
    }
    
    // Find local extremes
    double rsi_low = rsi_values[ArrayMinimum(rsi_values)];
    double rsi_high = rsi_values[ArrayMaximum(rsi_values)];
    double price_low = price_values[ArrayMinimum(price_values)];
    double price_high = price_values[ArrayMaximum(price_values)];
    
    // Check for bullish divergence (price lower, RSI higher)
    bullish = (price_values[0] < price_low && rsi_values[0] > rsi_low);
    
    // Check for bearish divergence (price higher, RSI lower)
    bearish = (price_values[0] > price_high && rsi_values[0] < rsi_high);
    
    return (bullish || bearish);
}
//+------------------------------------------------------------------+
//| Calculate Dynamic RSI Thresholds                                 |
//+------------------------------------------------------------------+
void GetDynamicRSIThresholds(string symbol, double &upper_threshold, double &lower_threshold)
{
    double atr = CalculateATR(symbol, 14, Timeframe);
    double avg_atr = 0;
    
    // Calculate average ATR for last 20 periods
    for(int i = 0; i < 20; i++)
    {
        avg_atr += CalculateATR(symbol, 14, Timeframe, i);
    }
    avg_atr /= 20;
    
    // Adjust thresholds based on relative volatility
    double volatility_factor = atr / avg_atr;
    
    // More volatile market = wider thresholds
    upper_threshold = RSIUpperThreshold + (volatility_factor - 1) * 10;
    lower_threshold = RSILowerThreshold - (volatility_factor - 1) * 10;
    
    // Keep thresholds within reasonable bounds
    upper_threshold = MathMin(MathMax(upper_threshold, 65), 85);
    lower_threshold = MathMax(MathMin(lower_threshold, 35), 15);
}
//+------------------------------------------------------------------+
//| Analyze RSI Trend Strength                                       |
//+------------------------------------------------------------------+
double GetRSITrendStrength(string symbol, int periods = 5)
{
    double strength = 0;
    double prev_rsi = CalculateRSI(symbol, RSI_Period, Timeframe, periods);
    
    // Calculate the strength of the RSI trend
    for(int i = periods-1; i >= 0; i--)
    {
        double current_rsi = CalculateRSI(symbol, RSI_Period, Timeframe, i);
        strength += (current_rsi - prev_rsi);
        prev_rsi = current_rsi;
    }
    
    return strength / periods;  // Positive = strengthening, Negative = weakening
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(string symbol, ulong ticket, int type, double open_price, double stop_loss)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if (point <= 0)
    {
        Print("Error: Invalid point value for symbol ", symbol);
        return;
    }

    double trailing_stop = TrailingStopPips * point;
    double breakeven_level = BreakevenActivationPips * point;
    double breakeven_offset = BreakevenOffsetPips * point;

    if (type == POSITION_TYPE_BUY)
    {
        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        double new_stop_loss = price - trailing_stop;

        if (new_stop_loss > stop_loss)
        {
            if (MathAbs(price - LastModificationPrice) >= MinPriceChangeThreshold * point)
            {
                if (trade.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP)))
                {
                    LastModificationPrice = price; // Update the last modification price
                    Print("Trailing Stop Updated for Buy Position ", ticket);
                }
            }
        }
    }
    else if (type == POSITION_TYPE_SELL)
    {
        double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double new_stop_loss = price + trailing_stop;

        if (new_stop_loss < stop_loss || stop_loss == 0.0)
        {
            if (MathAbs(price - LastModificationPrice) >= MinPriceChangeThreshold * point)
            {
                if (trade.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP)))
                {
                    LastModificationPrice = price; // Update the last modification price
                    Print("Trailing Stop Updated for Sell Position ", ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply Breakeven                                                  |
//+------------------------------------------------------------------+
void ApplyBreakeven(string symbol, ulong ticket, int type, double open_price, double stop_loss)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if (point <= 0)
    {
        Print("Error: Invalid point value for symbol ", symbol);
        return;
    }

    double breakeven_level = BreakevenActivationPips * point;
    double breakeven_offset = BreakevenOffsetPips * point;

    if (type == POSITION_TYPE_BUY)
    {
        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        if (price - open_price >= breakeven_level)
        {
            double new_stop_loss = open_price + breakeven_offset;
            if (stop_loss < new_stop_loss)
            {
                if (MathAbs(price - LastModificationPrice) >= MinPriceChangeThreshold * point)
                {
                    if (trade.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP)))
                    {
                        LastModificationPrice = price; // Update the last modification price
                        Print("Breakeven Activated for Buy Position ", ticket);
                    }
                }
            }
        }
    }
    else if (type == POSITION_TYPE_SELL)
    {
        double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
        if (open_price - price >= breakeven_level)
        {
            double new_stop_loss = open_price - breakeven_offset;
            if (stop_loss > new_stop_loss || stop_loss == 0.0)
            {
                if (MathAbs(price - LastModificationPrice) >= MinPriceChangeThreshold * point)
                {
                    if (trade.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP)))
                    {
                        LastModificationPrice = price; // Update the last modification price
                        Print("Breakeven Activated for Sell Position ", ticket);
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
//| Order Placement Functions                                        |
//+------------------------------------------------------------------+
void PlaceBuyOrder(string symbol)
{
    double stop_loss, take_profit;
    CalculateDynamicSLTP(symbol, stop_loss, take_profit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(
        symbol,                          // symbol
        stop_loss / _Point,             // stop_loss_pips
        accountBalance,                  // accountBalance
        RiskPercent,                    // riskPercent
        minVolume,                      // minVolume
        maxVolume                       // maxVolume
    );
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double limit_price = price - 10 * _Point; // Place limit order 10 points below current price
    double sl = limit_price - stop_loss;
    double tp = limit_price + take_profit;

    // Normalize SL and TP
    int price_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);
    limit_price = NormalizeDouble(limit_price, price_digits);

    if (trade.BuyLimit(lot_size, limit_price, symbol, sl, tp, ORDER_TIME_GTC, 0, "Buy Limit Order with Dynamic SL/TP"))
    {
        LogTradeDetails(symbol, lot_size, stop_loss, take_profit);
    }
    else
    {
        int error = GetLastError();
        Print("Buy Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}

void PlaceSellOrder(string symbol)
{
    double stop_loss, take_profit;
    CalculateDynamicSLTP(symbol, stop_loss, take_profit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(
        symbol,                          // symbol
        stop_loss / _Point,             // stop_loss_pips
        accountBalance,                  // accountBalance
        RiskPercent,                    // riskPercent
        minVolume,                      // minVolume
        maxVolume                       // maxVolume
    );
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double limit_price = price + 10 * _Point; // Place limit order 10 points above current price
    double sl = limit_price + stop_loss;
    double tp = limit_price - take_profit;

    // Normalize SL and TP
    int price_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);
    limit_price = NormalizeDouble(limit_price, price_digits);

    if (trade.SellLimit(lot_size, limit_price, symbol, sl, tp, ORDER_TIME_GTC, 0, "Sell Limit Order with Dynamic SL/TP"))
    {
        LogTradeDetails(symbol, lot_size, stop_loss, take_profit);
    }
    else
    {
        int error = GetLastError();
        Print("Sell Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}

//+------------------------------------------------------------------+
//| Place Additional Buy Order                                       |
//+------------------------------------------------------------------+
void PlaceAdditionalBuyOrder(string symbol)
{
    // Check if we already have maximum allowed positions
    if(CountOrders(symbol, POSITION_TYPE_BUY) >= 3)
    {
        Print("Maximum number of buy orders reached (3)");
        return;
    }

    double stop_loss, take_profit;
    CalculateDynamicSLTP(symbol, stop_loss, take_profit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(
        symbol,                          // symbol
        stop_loss / _Point,             // stop_loss_pips
        accountBalance,                  // accountBalance
        RiskPercent,                    // riskPercent
        minVolume,                      // minVolume
        maxVolume                       // maxVolume
    );
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double limit_price = price - 10 * _Point;
    double sl = limit_price - stop_loss;
    double tp = limit_price + take_profit;

    int price_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);
    limit_price = NormalizeDouble(limit_price, price_digits);

    if(trade.BuyLimit(lot_size, limit_price, symbol, sl, tp, ORDER_TIME_GTC, 0, 
       "Additional Buy Limit Order #" + IntegerToString(CountOrders(symbol, POSITION_TYPE_BUY) + 1)))
    {
        LogTradeDetails(symbol, lot_size, stop_loss, take_profit);
    }
    else
    {
        int error = GetLastError();
        Print("Additional Buy Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}

//+------------------------------------------------------------------+
//| Place Additional Sell Order                                      |
//+------------------------------------------------------------------+
void PlaceAdditionalSellOrder(string symbol)
{
    // Check if we already have maximum allowed positions
    if(CountOrders(symbol, POSITION_TYPE_SELL) >= 3)
    {
        Print("Maximum number of sell orders reached (3)");
        return;
    }

    double stop_loss, take_profit;
    CalculateDynamicSLTP(symbol, stop_loss, take_profit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(
        symbol,                          // symbol
        stop_loss / _Point,             // stop_loss_pips
        accountBalance,                  // accountBalance
        RiskPercent,                    // riskPercent
        minVolume,                      // minVolume
        maxVolume                       // maxVolume
    );
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double limit_price = price + 10 * _Point;
    double sl = limit_price + stop_loss;
    double tp = limit_price - take_profit;

    int price_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);
    limit_price = NormalizeDouble(limit_price, price_digits);

    if(trade.SellLimit(lot_size, limit_price, symbol, sl, tp, ORDER_TIME_GTC, 0,
       "Additional Sell Limit Order #" + IntegerToString(CountOrders(symbol, POSITION_TYPE_SELL) + 1)))
    {
        LogTradeDetails(symbol, lot_size, stop_loss, take_profit);
    }
    else
    {
        int error = GetLastError();
        Print("Additional Sell Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}

// Define the PlaceBuyLimitOrder function
void PlaceBuyLimitOrder(string symbol, double limitPrice, double tpPrice, double slPrice)
{
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lot_size = CalculateDynamicLotSize(
        symbol,                          // symbol
        slPrice / _Point,               // stop_loss_pips
        accountBalance,                  // accountBalance
        RiskPercent,                    // riskPercent
        minVolume,                      // minVolume
        maxVolume                       // maxVolume
    );
    
    if (trade.BuyLimit(lot_size, limitPrice, symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, "Buy Limit Order"))
    {
        LogTradeDetails(symbol, lot_size, slPrice, tpPrice);
    }
    else
    {
        int error = GetLastError();
        Print("Buy Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}

// Define the PlaceSellLimitOrder function
void PlaceSellLimitOrder(string symbol, double limitPrice, double tpPrice, double slPrice)
{
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lot_size = CalculateDynamicLotSize(
        symbol,                          // symbol
        slPrice / _Point,               // stop_loss_pips
        accountBalance,                  // accountBalance
        RiskPercent,                    // riskPercent
        minVolume,                      // minVolume
        maxVolume                       // maxVolume
    );
    
    if (trade.SellLimit(lot_size, limitPrice, symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, "Sell Limit Order"))
    {
        LogTradeDetails(symbol, lot_size, slPrice, tpPrice);
    }
    else
    {
        int error = GetLastError();
        Print("Sell Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}
//+------------------------------------------------------------------+
//| Validate Input Parameters                                        |
//+------------------------------------------------------------------+
void ValidateInputs(string symbol)
{
    // Validate RiskPercent
    if (RiskPercent <= 0.0 || RiskPercent > 10.0)
    {
        Alert("RiskPercent must be between 0.1 and 10.0");
        ExpertRemove();
        return;
    }

    // Validate MaxDrawdownPercent
    if (MaxDrawdownPercent <= 0.0 || MaxDrawdownPercent > 100.0)
    {
        Alert("MaxDrawdownPercent must be between 0.1 and 100.0");
        ExpertRemove();
        return;
    }

    // Validate ATRMultiplier
    if (ATRMultiplier <= 0.0 || ATRMultiplier > 5.0)
    {
        Alert("ATRMultiplier must be between 0.1 and 5.0");
        ExpertRemove();
        return;
    }

    // Validate ADXPeriod
    if (ADXPeriod <= 0)
    {
        Alert("ADXPeriod must be greater than 0");
        ExpertRemove();
        return;
    }

    // Validate TrendADXThreshold
    if (TrendADXThreshold <= 0.0 || TrendADXThreshold > 100.0)
    {
        Alert("TrendADXThreshold must be between 0.1 and 100.0");
        ExpertRemove();
        return;
    }

    // Validate TrailingStopPips
    if (TrailingStopPips <= 0.0)
    {
        Alert("TrailingStopPips must be greater than 0");
        ExpertRemove();
        return;
    }

    // Validate BreakevenActivationPips and BreakevenOffsetPips
    if (BreakevenActivationPips <= 0.0 || BreakevenOffsetPips < 0.0)
    {
        Alert("BreakevenActivationPips must be greater than 0 and BreakevenOffsetPips cannot be negative");
        ExpertRemove();
        return;
    }

    // Validate LiquidityThreshold
    if (LiquidityThreshold <= 0.0)
    {
        Alert("LiquidityThreshold must be greater than 0");
        ExpertRemove();
        return;
    }

    // Validate ImbalanceThreshold
    if (ImbalanceThreshold <= 1.0)
    {
        Alert("ImbalanceThreshold must be greater than 1.0");
        ExpertRemove();
        return;
    }

    // Validate Pattern Recognition parameters
    if (EMA_PERIODS_SHORT >= EMA_PERIODS_MEDIUM || EMA_PERIODS_MEDIUM >= EMA_PERIODS_LONG)
    {
        Alert("EMA periods must be in ascending order: SHORT < MEDIUM < LONG");
        ExpertRemove();
        return;
    }

    if (PATTERN_LOOKBACK <= 0 || PATTERN_LOOKBACK > 100)
    {
        Alert("PATTERN_LOOKBACK must be between 1 and 100");
        ExpertRemove();
        return;
    }

    if (GOLDEN_CROSS_THRESHOLD <= 0)
    {
        Alert("GOLDEN_CROSS_THRESHOLD must be greater than 0");
        ExpertRemove();
        return;
    }
}

//+------------------------------------------------------------------+
//| Process trading logic for a single symbol                        |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol)
{
    // Check if within trading hours
    if(!IsWithinTradingHours(TradingStartTime, TradingEndTime))
        return;

    // Check drawdown
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(CheckDrawdown(symbol, MaxDrawdownPercent, accountBalance, accountEquity))
        return;

    // Execute trading logic for this symbol
    ExecuteTradingLogic(symbol);
}

//+------------------------------------------------------------------+
//| Initialize log times for all symbols                             |
//+------------------------------------------------------------------+
void InitializeLogTimes()
{
    datetime currentTime = TimeCurrent();
    for(int i = 0; i < symbolCount; i++)
    {
        symbolLogTimes[i].calculationLogTime = currentTime;
        symbolLogTimes[i].analysisLogTime = currentTime;
        symbolLogTimes[i].signalLogTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Check for Signal Persistence                                     |
//+------------------------------------------------------------------+
bool CheckConsecutiveSignals(string symbol, int requiredBars, bool isBuySignal)
{
    // Minimum required bars for confirmation
    if(requiredBars < 2) requiredBars = 2;  // Force minimum of 2 bars
    
    // Arrays to store historical values
    double ema_short_values[];
    double ema_medium_values[];
    double ema_long_values[];
    double macd_histogram_values[];
    double rsi_values[];
    
    // Initialize arrays
    ArrayResize(ema_short_values, requiredBars);
    ArrayResize(ema_medium_values, requiredBars);
    ArrayResize(ema_long_values, requiredBars);
    ArrayResize(macd_histogram_values, requiredBars);
    ArrayResize(rsi_values, requiredBars);
    
    // Get historical values for all indicators
    for(int i = 0; i < requiredBars; i++)
    {
        // Calculate EMAs
        ema_short_values[i] = CalculateEMA(symbol, EMA_PERIODS_SHORT, Timeframe, i);
        ema_medium_values[i] = CalculateEMA(symbol, EMA_PERIODS_MEDIUM, Timeframe, i);
        ema_long_values[i] = CalculateEMA(symbol, EMA_PERIODS_LONG, Timeframe, i);
        
        // Calculate MACD
        double macdMain, macdSignal, macdHistogram;
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram, i);
        macd_histogram_values[i] = macdHistogram;
        
        // Calculate RSI
        rsi_values[i] = CalculateRSI(symbol, RSI_Period, Timeframe, i);
    }
    
    // Check for signal persistence
    int confirmedBars = 0;
    
    for(int i = 0; i < requiredBars; i++)
    {
        bool signalConfirmed = false;
        
        if(isBuySignal)
        {
            // Buy signal conditions
            bool emaAligned = (ema_short_values[i] > ema_medium_values[i] && 
                             ema_medium_values[i] > ema_long_values[i]);
            bool macdPositive = (macd_histogram_values[i] > 0);
            bool rsiSupport = (rsi_values[i] > RSI_Neutral);  // Above neutral level
            
            signalConfirmed = (emaAligned && macdPositive && rsiSupport);
        }
        else
        {
            // Sell signal conditions
            bool emaAligned = (ema_short_values[i] < ema_medium_values[i] && 
                             ema_medium_values[i] < ema_long_values[i]);
            bool macdNegative = (macd_histogram_values[i] < 0);
            bool rsiSupport = (rsi_values[i] < RSI_Neutral);  // Below neutral level
            
            signalConfirmed = (emaAligned && macdNegative && rsiSupport);
        }
        
        if(signalConfirmed)
        {
            confirmedBars++;
        }
        else
        {
            // Reset counter if signal breaks
            confirmedBars = 0;
            
            // Log the reason for signal break
            string signalType = isBuySignal ? "Buy" : "Sell";
            Print(signalType, " signal persistence broken at bar ", i);
            Print("EMA Alignment: ", 
                  ema_short_values[i], " / ",
                  ema_medium_values[i], " / ",
                  ema_long_values[i]);
            Print("MACD Histogram: ", macd_histogram_values[i]);
            Print("RSI: ", rsi_values[i]);
            
            return false;
        }
    }
    
    // Log successful confirmation
    if(confirmedBars >= requiredBars)
    {
        string signalType = isBuySignal ? "Buy" : "Sell";
        Print(signalType, " signal confirmed over ", confirmedBars, " bars");
        Print("Final Values:");
        Print("EMA Short: ", ema_short_values[0]);
        Print("EMA Medium: ", ema_medium_values[0]);
        Print("EMA Long: ", ema_long_values[0]);
        Print("MACD Histogram: ", macd_histogram_values[0]);
        Print("RSI: ", rsi_values[0]);
    }
    
    return (confirmedBars >= requiredBars);
}

