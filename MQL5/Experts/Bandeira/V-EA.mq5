//+------------------------------------------------------------------+
//| V-EA.mq5                                                         |
//| VSol Software                                                    |
//+------------------------------------------------------------------+

#property copyright "VSol Software"
#property version   "1.14"
#property strict

#include <Trade/Trade.mqh>
#include <Bandeira/VTrends.mqh>
#include <Bandeira/VScalping.mqh>
#include <Bandeira/VLogging.mqh>

// Define threshold values
input double ADX_THRESHOLD = 20.0;
input double RSI_UPPER_THRESHOLD = 70.0;
input double RSI_LOWER_THRESHOLD = 30.0;
input double DI_DIFFERENCE_THRESHOLD = 2.0; // Minimum difference between DI+ and DI-

// Add these constants near the top of the file
const int LOG_INTERVAL_CALCULATIONS = 1;  
const int LOG_INTERVAL_ANALYSIS = 1;      
const int LOG_INTERVAL_SIGNALS = 1;       

// Declare global variables for trading times
int tradingStartHour;
int tradingStartMinute;
int tradingEndHour;
int tradingEndMinute;

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+

// Strategy Activation
input group "Strategy Settings"
input bool UseTrendStrategy = true;         // Enable or disable the Trend Following strategy
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15; // Default timeframe
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
input double TrendADXThreshold = 37.5;      // ADX threshold for trend
input double RSIUpperThreshold = 75.0;      // RSI overbought level
input double RSILowerThreshold = 25.0;      // RSI oversold level

// Trading Hours
input group "Trading Time Settings"
input int TradingStartHour = 0;    // Trading session start hour (0-23)
input int TradingStartMinute = 0;  // Trading session start minute (0-59) 
input int TradingEndHour = 24;     // Trading session end hour (0-23)
input int TradingEndMinute = 0;    // Trading session end minute (0-59)

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
input double GOLDEN_CROSS_THRESHOLD = 0.0015; // Golden cross threshold

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
input bool StrictOrderChecks = false;         // Use strict order entry conditions

// Modify symbol settings inputs
input group "Symbol Settings"
input bool UseMultipleSymbols = true;        // Trade multiple symbols
input int MaxSymbolsToTrade = 300;           // Maximum number of symbols to trade

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

Music music
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

    // Log StrictOrderChecks status with a strict emoji
    Print("Strict Order Checks Mode: ", StrictOrderChecks ? "🔒 Enabled" : "🔓 Disabled");

    // Initialize with current chart symbol if not using multiple symbols
    if(!UseMultipleSymbols)
    {
        string symbol = ChartSymbol(0);  // Get symbol from current chart
        ArrayResize(tradingSymbols, 1);
        AddTradingSymbol(symbol, 0);
        SetSymbolCount(1);
        ValidateInputs(RiskPercent, MaxDrawdownPercent, ATRMultiplier, ADXPeriod, TrendADXThreshold, TrailingStopPips, BreakevenActivationPips, BreakevenOffsetPips, LiquidityThreshold, ImbalanceThreshold, EMA_PERIODS_SHORT, EMA_PERIODS_MEDIUM, EMA_PERIODS_LONG, PATTERN_LOOKBACK, GOLDEN_CROSS_THRESHOLD);
        
        // Cleanup pending orders for the current symbol
        //CleanupPendingOrders(symbol);
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

        
        ProcessSymbol(symbol, UseScalpingStrategy, MaxDrawdownPercent, ScalpingRiskPercent, ScalpingStopLoss, ScalpingTimeframe, Timeframe, TradingStartHour, TradingStartMinute, TradingEndHour, TradingEndMinute);

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
//| Process trading logic for a single symbol                        |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol, bool useScalpingStrategy, double maxDrawdownPercent, double scalpingRiskPercent, double scalpingStopLoss, ENUM_TIMEFRAMES timeframe, 
                    ENUM_TIMEFRAMES scalpingTimeframe, int tradingStartHour, int tradingStartMinute, int tradingEndHour, int tradingEndMinute)
{
    // Add prominent warning if symbol has active trades
    if(HasActiveTradeOrPendingOrder(symbol, POSITION_TYPE_BUY) || 
       HasActiveTradeOrPendingOrder(symbol, POSITION_TYPE_SELL))
    {
        Print("⚠️ ⚠️ ⚠️ ATTENTION ⚠️ ⚠️ ⚠️");
        Print("🔴 ACTIVE TRADE(S) DETECTED FOR SYMBOL: ", symbol, " 🔴");
        Print("=====================================");
    }

    // Check if symbol is a stock and if we're within market hours
    if(IsStockSymbol(symbol) && !IsWithinUSMarketHours())
    {
        LogGenericMessage("Skipping " + symbol + " - Outside US market hours", symbol);
        return;
    }
        
    // Add start delimiter with emoji
    Print("🌟🌟🌟 Start Processing Symbol: ", symbol, " 🌟🌟🌟");

    // Check if within trading hours (for non-stock symbols)
    if(!IsStockSymbol(symbol) && !IsWithinTradingHours(tradingStartHour, tradingStartMinute, tradingEndHour, tradingEndMinute))
    {
        Print("Skipping ", symbol, " - Outside trading hours: ", tradingStartHour, ":", tradingStartMinute, " to ", tradingEndHour, ":", tradingEndMinute);
        return;
    }

    // Check drawdown
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(CheckDrawdown(symbol, maxDrawdownPercent, accountBalance, accountEquity))
        return;

    // Add volatility check for scalping
    if (useScalpingStrategy)
    {
        double atr = CalculateATR(symbol, 14, scalpingTimeframe);
        double avgAtr = 0;
        for(int i = 1; i <= 20; i++)
        {
            avgAtr += CalculateATR(symbol, 14, scalpingTimeframe, i);
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
    // Add end delimiter with emoji
    Print("🏁🏁🏁 End Processing Symbol: ", symbol, " 🏁🏁🏁");
    
}

//+------------------------------------------------------------------+
//| Execute Trading Logic                                            |
//+------------------------------------------------------------------+
void ExecuteTradingLogic(string symbol)
{
    // Check if within trading hours first
    if (!IsWithinTradingHours(TradingStartHour, TradingStartMinute, TradingEndHour, TradingEndMinute))
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
        const int SCALP_RSI_PERIOD = 5;           // Even shorter RSI period
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

    if (UseTrendStrategy)
    {
        // Set weights for trend strategy
        int trendWeight = 2;
        int patternWeight = 2;
        int rsiMacdWeight = 1;
        int orderFlowWeight = 1;

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
        CalculateDynamicSLTPInPips(symbol, stopLoss, takeProfit, ATRMultiplier, Timeframe, fixedStopLossPips);

        // Ensure SL and TP are calculated based on pip values
        double pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double stopLossPrice = SymbolInfoDouble(symbol, SYMBOL_BID) - (stopLoss * pipValue); // Adjust SL based on pip value
        double takeProfitPrice = SymbolInfoDouble(symbol, SYMBOL_BID) + (takeProfit * pipValue); // Adjust TP based on pip value

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

        // Declare totalScore and scoreThreshold at the beginning of the function or globally if needed
        int totalScore = 0; // Initialize totalScore
        double scoreThreshold = 0.0; // Initialize scoreThreshold

        // Calculate total score and score threshold
        totalScore = trendSignal * trendWeight + 
                     patternSignal * patternWeight + 
                     rsiMacdSignal * rsiMacdWeight + 
                     orderFlowSignal * orderFlowWeight;

        // Add score for consecutive signals
        int consecutiveScore = 0;
        if (CheckConsecutiveSignals(symbol, 2, true)) // Adjust parameters as needed
        {
            consecutiveScore = 1; // Assign a score for consecutive buy signals
        }
        else if (CheckConsecutiveSignals(symbol, 2, false)) // Adjust parameters as needed
        {
            consecutiveScore = -1; // Assign a score for consecutive sell signals
        }
        totalScore += consecutiveScore; // Add the consecutive score to the total score

        // Calculate scoreThreshold based on the maximum score
        int maxScore = (trendWeight + patternWeight + rsiMacdWeight + orderFlowWeight) * 1;
        scoreThreshold = maxScore - 1;

        // For BUY signals
        if (StrictOrderChecks)
        {
            // Original strict conditions
            if (trendSignal == 1 && patternSignal == 1 && rsiMacdSignal == 1 && orderFlowSignal == 1)
            {
                // Check for consecutive signals as an additional filter
                if (CheckConsecutiveSignals(symbol, 2, true)) // Adjust parameters as needed
                {
                    ProcessBuySignal(symbol, lotSize, stopLossPrice, takeProfitPrice, liquidityThreshold, takeProfitPips, stopLossPips, riskPercent, trade);
                }
            }
        }
        else
        {
            // Decision making based on total score
            if (totalScore >= scoreThreshold)
            {
                // Fun and clear log for buy setup
                Print("🚀🚀🚀 Buy Setup for ", symbol, " 🚀🚀🚀");
                Print("📈 Current Bid: ", SymbolInfoDouble(symbol, SYMBOL_BID));
                Print("🔒 Stop Loss: ", stopLossPrice, " | 🎯 Take Profit: ", takeProfitPrice);
                Print("Lot Size: ", lotSize, " | Min Stop Level: ", SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT));
                
                // Use PlaceBuyLimitOrder instead of trade.Buy
                PlaceBuyLimitOrder(symbol, SymbolInfoDouble(symbol, SYMBOL_BID) - 10 * SymbolInfoDouble(symbol, SYMBOL_POINT), RiskPercent);
            }
            else if (totalScore <= -scoreThreshold && AllowShortTrades)
            {
                // Fun and clear log for sell setup
                Print("🔻🔻🔻 Sell Setup for ", symbol, " 🔻🔻🔻");
                Print("📉 Current Ask: ", SymbolInfoDouble(symbol, SYMBOL_ASK));
                Print("🔒 Stop Loss: ", stopLossPrice, " | 🎯 Take Profit: ", takeProfitPrice);
                Print("Lot Size: ", lotSize, " | Min Stop Level: ", SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT));
                
                // Use PlaceSellLimitOrder instead of trade.Sell
                PlaceSellLimitOrder(symbol, SymbolInfoDouble(symbol, SYMBOL_ASK) + 10 * SymbolInfoDouble(symbol, SYMBOL_POINT), RiskPercent);
            }
        }

        // Update last values
        lastOrderFlowSignal = orderFlowSignal;
        lastTrendSignal = trendSignal;
        lastRsiMacdSignal = rsiMacdSignal;
        lastStopLoss = stopLoss;
        lastTakeProfit = takeProfit;
        lastCalculationTime = currentTime;

        // Log signal updates
        LogSignalUpdates(symbol, 
                         trendSignal, trendWeight,
                         patternSignal, patternWeight,
                         rsiMacdSignal, rsiMacdWeight,
                         orderFlowSignal, orderFlowWeight,
                         totalScore, scoreThreshold,
                         lastStopLoss, lastTakeProfit,
                         lastCalculationTime);

        // Log lot size calculation
        LogLotSizeCalculation(symbol, 
                              accountBalance, 
                              RiskPercent,
                              stopLoss,
                              tickValue,
                              lotSize);

        // Check and log trade rejections
        if (totalScore > -scoreThreshold && totalScore < scoreThreshold)
        {
            LogTradeRejection("Insufficient total score for trade", symbol, SymbolInfoDouble(symbol, SYMBOL_BID),
                              adx, rsi, ema_short, ema_medium, ema_long,
                              ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis, Timeframe);
        }

        if (trendSignal == 0 || rsiMacdSignal == 0 || patternSignal == 0)
        {
            string reason = trendSignal == 0 ? "No trend signal detected" :
                           rsiMacdSignal == 0 ? "No RSI/MACD signal detected" :
                           "No pattern signal detected";
                   
            LogTradeRejection(reason, symbol, SymbolInfoDouble(symbol, SYMBOL_BID),
                              adx, rsi, ema_short, ema_medium, ema_long,
                              ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis, Timeframe);
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
    
    // Calculate DI difference
    double diDifference = MathAbs(plusDI - minusDI);
    
    if (ema > sma && rsi < RSIUpperThreshold && adx > TrendADXThreshold && 
        plusDI > minusDI && diDifference > DI_DIFFERENCE_THRESHOLD)
    {
        Print("Trend Following: Buy Signal");
        Print("DI+ (", plusDI, ") > DI- (", minusDI, "), Difference: ", diDifference);
        return 1;
    }
    else if (ema < sma && rsi > RSILowerThreshold && adx > TrendADXThreshold && 
             minusDI > plusDI && diDifference > DI_DIFFERENCE_THRESHOLD)
    {
        Print("Trend Following: Sell Signal");
        Print("DI- (", minusDI, ") > DI+ (", plusDI, "), Difference: ", diDifference);
        return -1;
    }
    
    // Log rejection reason if DI difference is too small
    if (diDifference <= DI_DIFFERENCE_THRESHOLD)
    {
        Print("Trade rejected: DI difference (", diDifference, 
              ") below threshold (", DI_DIFFERENCE_THRESHOLD, ")");
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
        cross_strength = MathAbs(current_ema_short - current_ema_long) / SymbolInfoDouble(symbol, SYMBOL_POINT);
        if(cross_strength > GOLDEN_CROSS_THRESHOLD) {
            golden_cross = true;
            score.bullish += 3.0 * (cross_strength / GOLDEN_CROSS_THRESHOLD);
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Golden Cross - Strength: " + DoubleToString(cross_strength);
        }
    }
    // Check for death cross with momentum confirmation
    else if(current_ema_short < current_ema_long && past_ema_short[0] > past_ema_long[0]) {
        cross_strength = MathAbs(current_ema_short - current_ema_long) / SymbolInfoDouble(symbol, SYMBOL_POINT);
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
    string analysis = "🔍 Trend Pattern Analysis for " + symbol + " (Timeframe: " + EnumToString(Timeframe) + ") ===\n";
    analysis += "Bullish Score: " + DoubleToString(score.bullish, 2) + "\n";
    analysis += "Bearish Score: " + DoubleToString(score.bearish, 2) + "\n";
    analysis += "Reasons:\n";
    for(int i = 0; i < ArraySize(score.reasons); i++) {
        analysis += "- " + score.reasons[i] + "\n";
    }
    Print(analysis);
    Print("=== End of Trend Pattern Analysis ===");  // Simple end delimiter

    // 7. Final Decision Making with Minimum Threshold
    const double MIN_SCORE_THRESHOLD = 3.0; // Minimum score required for signal (lowered from 5.0)
    const double SCORE_DIFFERENCE_THRESHOLD = 2.0; // Minimum difference between bull/bear scores
    
    if(score.bullish >= MIN_SCORE_THRESHOLD && 
       score.bullish - score.bearish >= SCORE_DIFFERENCE_THRESHOLD)
        return 1;  // Strong bullish pattern
    else if(score.bearish >= MIN_SCORE_THRESHOLD && 
            score.bearish - score.bullish >= SCORE_DIFFERENCE_THRESHOLD)
        return -1; // Strong bearish pattern
    
    return 0;     // No clear pattern or insufficient strength
}
