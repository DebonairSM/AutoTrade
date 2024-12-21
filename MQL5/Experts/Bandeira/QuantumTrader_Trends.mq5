//+------------------------------------------------------------------+
//| QuantumTraderAI_TrendFollowing.mq5                               |
//| VSol Software                                                    |
//+------------------------------------------------------------------+

#property copyright "VSol Software"
#property version   "1.14"
#property strict

#include <Trade/Trade.mqh>
#include <Bandeira/Utility.mqh>
#include <Bandeira/RSI_MACD_Scalping.mqh>

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

// Scalping Strategy Parameters
input group "Scalping Strategy Parameters"
input ENUM_TIMEFRAMES ScalpingTimeframe = PERIOD_M5;  // Scalping Timeframe
input bool UseScalpingStrategy = true;        // Enable RSI-MACD Scalping
input double ScalpingRiskPercent = 2.0;       // Scalping Risk Percentage
input double ScalpingStopLoss = 15.0;         // Scalping Stop Loss (pips)
input double ScalpingTakeProfit = 30.0;       // Scalping Take Profit (pips)

//+------------------------------------------------------------------+
//| Global Variables and Objects                                     |
//+------------------------------------------------------------------+
CTrade trade;

double starting_balance;
// Add a minimum price change threshold (in points)
double LastModificationPrice = 0;

// Declare a static variable to track the last log time
static datetime lastLogTime = 0;

// Declare the lastCalculationTime variable
datetime lastCalculationTime = 0;

// Declare and initialize these variables at the top of your file or within the relevant function
double liquidityThreshold = 50.0; // Example value, adjust as needed
double takeProfitPips = 50.0;     // Example value, adjust as needed
double stopLossPips = 30.0;       // Example value, adjust as needed
double riskPercent = 2.0;         // Example value, adjust as needed

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
    Print("===================================");

    // Initialize with current chart symbol if not using multiple symbols
    if(!UseMultipleSymbols)
    {
        string symbol = ChartSymbol(0);  // Get symbol from current chart
        ArrayResize(tradingSymbols, 1);
        AddTradingSymbol(symbol, 0);
        SetSymbolCount(1);
        ValidateInputs(RiskPercent, MaxDrawdownPercent, ATRMultiplier, ADXPeriod, TrendADXThreshold, TrailingStopPips, BreakevenActivationPips, BreakevenOffsetPips, LiquidityThreshold, ImbalanceThreshold, EMA_PERIODS_SHORT, EMA_PERIODS_MEDIUM, EMA_PERIODS_LONG, PATTERN_LOOKBACK, GOLDEN_CROSS_THRESHOLD);
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
                
                // Log whether symbol is stock or not
                if(IsStockSymbol(symbol))
                {
                    Print("Added stock symbol (US Market Hours): ", symbol);
                }
                else
                {
                    Print("Added non-stock symbol (24/5): ", symbol);
                }
                
                AddTradingSymbol(symbol, count);
                count++;
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
    InitializeLogTimes(symbolLogTimes, symbolCount);
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
        
        // Add start delimiter with emoji
        Print("🚀🚀🚀 Start Processing Symbol: ", symbol, " 🚀🚀🚀");
        
        ProcessSymbol(symbol, UseScalpingStrategy, MaxDrawdownPercent, ScalpingRiskPercent, ScalpingStopLoss, Timeframe, TradingStartTime, TradingEndTime);
        
        // Add end delimiter with emoji
        Print("🏁🏁🏁 End Processing Symbol: ", symbol, " 🏁🏁🏁");
        
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
    
    // Always manage existing positions
    if (UseTrailingStop || UseBreakeven)
    {
        ManagePositions(symbol);
    }

    // Check for scalping opportunities first
    if (UseScalpingStrategy)
    {
        // Add start delimiter for scalping logic
        Print("💰 Scalping Logic Start for Symbol: ", symbol, " 💰");

        // Calculate RSI using scalping-specific period
        double rsi = CalculateRSI(symbol, SCALP_RSI_PERIOD, ScalpingTimeframe);
        
        // Calculate MACD using scalping-specific parameters
        double macdMain, macdSignal, macdHistogram;
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram, 0, ScalpingTimeframe);

        // Check for existing positions to avoid overlapping trades
        if (!HasActiveTradeOrPendingOrder(symbol, POSITION_TYPE_BUY) && 
            !HasActiveTradeOrPendingOrder(symbol, POSITION_TYPE_SELL))
        {
            // Calculate lot size for scalping using enhanced risk management
            double lotSize = CalculateLotSize(ScalpingRiskPercent, ScalpingStopLoss, symbol);  // Added symbol

            // Enhanced buy condition check with all confirmations
            if (CheckBuyCondition(rsi, macdMain, macdSignal, symbol))  // Added symbol
            {
                ExecuteBuyTrade(lotSize, symbol, ScalpingRiskPercent);  // Added symbol
                LogGenericMessage("Scalping Buy Signal Executed on " + EnumToString(ScalpingTimeframe), symbol);  // Added symbol
                return;  // Exit to avoid conflicting signals
            }
            
            // Enhanced sell condition check with all confirmations
            if (CheckSellCondition(rsi, macdMain, macdSignal, symbol))  // Added symbol
            {
                ExecuteSellTrade(lotSize, symbol, ScalpingRiskPercent);  // Added symbol
                LogGenericMessage("Scalping Sell Signal Executed on " + EnumToString(ScalpingTimeframe), symbol);  // Added symbol
                return;  // Exit to avoid conflicting signals
            }
        }

        // Enhanced exit condition check
        if (CheckExitCondition(rsi, symbol))  // Add the symbol parameter
        {
            CloseAllPositions(symbol, trade);
            LogGenericMessage("Scalping Exit Signal - Closing Positions on " + EnumToString(ScalpingTimeframe), symbol);
            return;
        }

        // Add end delimiter for scalping logic
        Print("💰 Scalping Logic End for Symbol: ", symbol, " 💰");
    }

    // Continue with existing trend strategy
    if (UseTrendStrategy)
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
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram, 0, Timeframe);

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
        int orderFlowSignal = MonitorOrderFlow(symbol, UseDOMAnalysis, LiquidityThreshold, ImbalanceThreshold);
        int trendSignal = TrendFollowingCore(symbol);
        int patternSignal = IdentifyTrendPattern(symbol);
        int rsiMacdSignal = CheckRSIMACDSignal(symbol, Timeframe, RSI_Period, RSIUpperThreshold, RSILowerThreshold);
        
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
        CalculateDynamicSLTP(symbol, stopLoss, takeProfit, ATRMultiplier, Timeframe, fixedStopLossPips);

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
                ProcessBuySignal(symbol, lotSize, stopLoss, takeProfit, liquidityThreshold, takeProfitPips, stopLossPips, riskPercent, trade);
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
                ProcessBuySignal(symbol, lotSize, stopLoss, takeProfit, liquidityThreshold, takeProfitPips, stopLossPips, riskPercent, trade);
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
                    ProcessSellSignal(symbol, lotSize, stopLoss, takeProfit, liquidityThreshold, takeProfitPips, stopLossPips, riskPercent, trade);
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
                    ProcessSellSignal(symbol, lotSize, stopLoss, takeProfit, liquidityThreshold, takeProfitPips, stopLossPips, riskPercent, trade);
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
                                 ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis);
                lastLogTime = TimeCurrent(); // Update last log time
            }
        }
        if (trendSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600)
            {
                LogTradeRejection("No trend signal detected", symbol, SymbolInfoDouble(symbol, SYMBOL_BID), 
                                 adx, rsi, ema_short, ema_medium, ema_long,
                                 ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis);
                lastLogTime = TimeCurrent();
            }
        }
        if (rsiMacdSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600)
            {
                LogTradeRejection("No RSI/MACD signal detected", symbol, SymbolInfoDouble(symbol, SYMBOL_BID), 
                                 adx, rsi, ema_short, ema_medium, ema_long,
                                 ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis);
                lastLogTime = TimeCurrent();
            }
        }
        if (patternSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600)
            {
                LogTradeRejection("No pattern signal detected", symbol, SymbolInfoDouble(symbol, SYMBOL_BID), 
                                 adx, rsi, ema_short, ema_medium, ema_long,
                                 ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis);
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
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram, 0, Timeframe);
        
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
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram, 0, Timeframe);
        
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
    string analysis = "=== Trend Pattern Analysis (Timeframe: " + EnumToString(Timeframe) + ") ===\n";
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
//| Process trading logic for a single symbol                        |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol, bool useScalpingStrategy, double maxDrawdownPercent, double scalpingRiskPercent, double scalpingStopLoss, ENUM_TIMEFRAMES timeframe, double tradingStartTime, double tradingEndTime)
{
    // Check if symbol is a stock and if we're within market hours
    if(IsStockSymbol(symbol) && !IsWithinUSMarketHours())
    {
        LogGenericMessage("Skipping " + symbol + " - Outside US market hours", symbol);
        return;
    }

    // Check if within trading hours (for non-stock symbols)
    if(!IsStockSymbol(symbol) && !IsWithinTradingHours(tradingStartTime, tradingEndTime))
        return;

    // Check drawdown
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(CheckDrawdown(symbol, maxDrawdownPercent, accountBalance, accountEquity))
        return;

    // Add volatility check for scalping
    if (useScalpingStrategy)
    {
        double atr = CalculateATR(symbol, 14, timeframe);
        double avgAtr = 0;
        for(int i = 1; i <= 20; i++)
        {
            avgAtr += CalculateATR(symbol, 14, timeframe, i);
        }
        avgAtr /= 20;

        // Only allow scalping in normal volatility conditions
        if (atr > avgAtr * 1.5)
        {
            Print("Scalping disabled due to high volatility: ATR=", atr, " AvgATR=", avgAtr);
            return;
        }
    }

    // Execute trading logic for this symbol
    ExecuteTradingLogic(symbol);
}
