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

    // Validate input parameters
    ValidateInputs();

    // Initialize starting balance
    starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);

    // Print current configurations to the journal/log
    Print("Configuration: ");
    Print("  UseTrendStrategy=", UseTrendStrategy);
    Print("  RiskPercent=", RiskPercent);
    Print("  MaxDrawdownPercent=", MaxDrawdownPercent);
    Print("  ATRMultiplier=", ATRMultiplier);
    Print("  ADXPeriod=", ADXPeriod);
    Print("  TrendADXThreshold=", TrendADXThreshold);
    Print("  TradingStartTime=", TradingStartTime);
    Print("  TradingEndTime=", TradingEndTime);
    Print("  UseTrailingStop=", UseTrailingStop);
    Print("  TrailingStopPips=", TrailingStopPips);
    Print("  UseBreakeven=", UseBreakeven);
    Print("  BreakevenActivationPips=", BreakevenActivationPips);
    Print("  BreakevenOffsetPips=", BreakevenOffsetPips);
    Print("  UseDOMAnalysis=", UseDOMAnalysis);
    Print("  LiquidityThreshold=", LiquidityThreshold);
    Print("  ImbalanceThreshold=", ImbalanceThreshold);
    Print("  Timeframe=", EnumToString(Timeframe));

    // Set the initial value of lastCalculationTime to ensure signals are calculated on the first tick
    lastCalculationTime = 0;

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Execute trading logic on each tick
    ExecuteTradingLogic();

    // Check calendar events every hour
    static datetime lastCheck = 0;
    datetime currentTime = TimeCurrent();
    if(currentTime - lastCheck >= PeriodSeconds(PERIOD_H1))
    {
        lastCheck = currentTime;
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
void ExecuteTradingLogic()
{
    // Check if within trading hours first
    if (!IsWithinTradingHours(TradingStartTime, TradingEndTime))
        return;

    // Check drawdown before proceeding
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if (CheckDrawdown(MaxDrawdownPercent, accountBalance, accountEquity))
        return;

    // Static variables to track last calculation time and signals
    static datetime lastCalculationTime = 0;
    static int lastTrendSignal = 0;
    static int lastOrderFlowSignal = 0;
    static int lastRsiMacdSignal = 0;
    static double lastStopLoss = 0;
    static double lastTakeProfit = 0;

    datetime currentTime = TimeCurrent();
    
    // Only recalculate signals every X seconds (e.g., 30 seconds)
    bool shouldRecalculateSignals = (currentTime - lastCalculationTime >= 30);
    
    // Always manage existing positions
    if (UseTrailingStop || UseBreakeven)
    {
        ManagePositions();
    }

    if (UseTrendStrategy && shouldRecalculateSignals)
    {
        // Calculate indicators
        double rsi = CalculateRSI(RSI_Period, Timeframe);
        double ema_short = CalculateEMA(EMA_PERIODS_SHORT, Timeframe);
        double ema_medium = CalculateEMA(EMA_PERIODS_MEDIUM, Timeframe);
        double ema_long = CalculateEMA(EMA_PERIODS_LONG, Timeframe);
        double atr = CalculateATR(14, Timeframe);
        double adx, plusDI, minusDI;
        CalculateADX(ADXPeriod, Timeframe, adx, plusDI, minusDI);
        double macdMain, macdSignal, macdHistogram;
        CalculateMACD(macdMain, macdSignal, macdHistogram);

        // Package the data for logging
        MarketAnalysisData analysisData;
        analysisData.currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
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
        analysisData.bullishPattern = IsBullishCandlePattern();
        analysisData.bearishPattern = IsBearishCandlePattern();

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

        // Log market analysis
        
        LogMarketAnalysis(analysisData, params, Timeframe, UseDOMAnalysis);

        // Calculate signals
        int orderFlowSignal = MonitorOrderFlow();
        int trendSignal = TrendFollowingCore();
        int rsiMacdSignal = CheckRSIMACDSignal();
        
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
        CalculateDynamicSLTP(stopLoss, takeProfit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

        // Calculate lot size using the now-defined stopLoss
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * 10;
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double lotSize = CalculateDynamicLotSize(stopLoss / _Point, accountBalance, localRiskPercent, minVolume, maxVolume);

        // For BUY signals
        if (trendSignal == 1 && rsiMacdSignal == 1 && orderFlowSignal == 1)
        {
            // Buy logic
            if (!HasActiveTradeOrPendingOrder(POSITION_TYPE_BUY))
            {
                double stopLoss, takeProfit;
                CalculateDynamicSLTP(stopLoss, takeProfit, ATRMultiplier, Timeframe, fixedStopLossPips);

                double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
                double lotSize = CalculateDynamicLotSize(stopLoss / _Point, accountBalance, RiskPercent, minVolume, maxVolume);

                double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double tpPrice = askPrice + takeProfit;
                double slPrice = askPrice - stopLoss;
                
                // Get the best limit order price
                double limitPrice = GetBestLimitOrderPrice(ORDER_TYPE_BUY_LIMIT, tpPrice, slPrice, LiquidityThreshold, TakeProfitPips, StopLossPips);
                
                if (limitPrice > 0.0)
                {
                    Print("Placing Buy Limit Order - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
                    PlaceBuyLimitOrder(limitPrice, tpPrice, slPrice);
                }
                else
                {
                    Print("Falling back to market order - TP: ", tpPrice, " SL: ", slPrice);
                    PlaceBuyOrder();
                }
            }
        }
        // For SELL signals
        else if (AllowShortTrades && trendSignal == -1 && rsiMacdSignal == -1 && orderFlowSignal == -1)
        {
            if (!HasActiveTradeOrPendingOrder(POSITION_TYPE_SELL))
            {
                double stopLoss, takeProfit;
                CalculateDynamicSLTP(stopLoss, takeProfit, ATRMultiplier, Timeframe, fixedStopLossPips);

                double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
                double lotSize = CalculateDynamicLotSize(stopLoss / _Point, accountBalance, RiskPercent, minVolume, maxVolume);

                double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double tpPrice = bidPrice - takeProfit;
                double slPrice = bidPrice + stopLoss;
                
                double limitPrice = GetBestLimitOrderPrice(ORDER_TYPE_SELL_LIMIT, tpPrice, slPrice, LiquidityThreshold, TakeProfitPips, StopLossPips);
                
                if (limitPrice > 0.0)
                {
                    Print("Placing Sell Limit Order - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
                    PlaceSellLimitOrder(limitPrice, tpPrice, slPrice);
                }
                else
                {
                    Print("Falling back to market order - TP: ", tpPrice, " SL: ", slPrice);
                    PlaceSellOrder();
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

        // If no trade signal is generated, log the reason
        if (orderFlowSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600) // Check if an hour has passed
            {
                LogTradeRejection("No order flow signal detected.", SymbolInfoDouble(_Symbol, SYMBOL_BID), adx, rsi, ema_short, ema_medium, ema_long,
                                    ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis);
                lastLogTime = TimeCurrent(); // Update last log time
            }
        }
        if (trendSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600)
            {
                LogTradeRejection("No trend signal detected.", SymbolInfoDouble(_Symbol, SYMBOL_BID), adx, rsi, ema_short, ema_medium, ema_long,
                                    ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis);
                lastLogTime = TimeCurrent();
            }
        }
        if (rsiMacdSignal == 0)
        {
            if (TimeCurrent() - lastLogTime >= 3600)
            {
                LogTradeRejection("No RSI/MACD signal detected.", SymbolInfoDouble(_Symbol, SYMBOL_BID), adx, rsi, ema_short, ema_medium, ema_long,
                                    ADX_THRESHOLD, RSI_UPPER_THRESHOLD, RSI_LOWER_THRESHOLD, UseDOMAnalysis);
                lastLogTime = TimeCurrent();
            }
        }
        
    }
}

// New helper functions to process signals
void ProcessBuySignal(double lotSize, double stopLoss, double takeProfit)
{
    if (!IsBearishCandlePattern())
    {
        if (!ManagePositions(POSITION_TYPE_BUY) && !HasPendingOrder(ORDER_TYPE_BUY_LIMIT))
        {
            double tpPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + takeProfit;
            double slPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - stopLoss;
            
            double limitPrice = GetBestLimitOrderPrice(ORDER_TYPE_BUY_LIMIT, tpPrice, slPrice, LiquidityThreshold, TakeProfitPips, StopLossPips);
            
            if (limitPrice > 0.0)
            {
                Print("Buy Limit Order Placed - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
                PlaceBuyLimitOrder(limitPrice, tpPrice, slPrice);
            }
            else
            {
                Print("Buy Market Order Placed - TP: ", tpPrice, " SL: ", slPrice, " Lot Size: ", lotSize);
                PlaceBuyOrder();
            }
        }
    }
    else
    {
        Print("Buy Signal Rejected - Strong bearish pattern detected");
    }
}

void ProcessSellSignal(double lotSize, double stopLoss, double takeProfit)
{
    if (!IsBullishCandlePattern())
    {
        if (!ManagePositions(POSITION_TYPE_SELL) && !HasPendingOrder(ORDER_TYPE_SELL_LIMIT))
        {
            double tpPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) - takeProfit;
            double slPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) + stopLoss;
            
            double limitPrice = GetBestLimitOrderPrice(ORDER_TYPE_SELL_LIMIT, tpPrice, slPrice, LiquidityThreshold, TakeProfitPips, StopLossPips);
            
            if (limitPrice > 0.0)
            {
                Print("Sell Limit Order Placed - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
                PlaceSellLimitOrder(limitPrice, tpPrice, slPrice);
            }
            else
            {
                Print("Sell Market Order Placed - TP: ", tpPrice, " SL: ", slPrice);
                PlaceSellOrder();
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
int TrendFollowingCore()
{
    double sma = CalculateSMA(100, Timeframe);
    double ema = CalculateEMA(20, Timeframe);
    double rsi = CalculateRSI(14, Timeframe);
    double atr = CalculateATR(14, Timeframe);
    
    double adx, plusDI, minusDI;
    CalculateADX(ADXPeriod, Timeframe, adx, plusDI, minusDI);
    
    static datetime lastBuySignalTime = 0;
    static datetime lastSellSignalTime = 0;
    
    // Define a minimum time interval between log messages (in seconds)
    int minLogInterval = 300; // 5 minutes
    
    // Calculate DI difference
    double diDifference = MathAbs(plusDI - minusDI);
    
    // Log DI difference for debugging
    Print("DI Difference: ", diDifference, " (Threshold: ", DI_DIFFERENCE_THRESHOLD, ")");
    
    if (ema > sma && rsi < RSIUpperThreshold && adx > TrendADXThreshold && 
        plusDI > minusDI && diDifference > DI_DIFFERENCE_THRESHOLD)
    {
        if (HasActiveTradeOrPendingOrder(POSITION_TYPE_BUY))
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
        if (HasActiveTradeOrPendingOrder(POSITION_TYPE_SELL))
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
bool ManagePositions(int checkType = -1)  // -1 means check all positions
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
            if(symbol != _Symbol) continue;
            
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
                    ApplyTrailingStop(ticket, posType, open_price, stop_loss);

                // Apply breakeven if enabled
                if(UseBreakeven)
                    ApplyBreakeven(ticket, posType, open_price, stop_loss);
            }
        }
    }
    
    return hasPosition;
}

//+------------------------------------------------------------------+
//| Detect Order Flow Imbalances                                     |
//+------------------------------------------------------------------+
int DetectOrderFlowImbalances(double buyVolume, double sellVolume, double imbalanceThreshold)
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
int MonitorOrderFlow()
{
    if (!UseDOMAnalysis)
        return 1; // Return neutral signal if DOM analysis is disabled

    MqlBookInfo book_info[];
    int book_count = MarketBookGet(_Symbol, book_info);
    
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
void CalculateMACD(double &macdMain, double &macdSignal, double &macdHistogram, int shift = 0)
{
    int handle = iMACD(_Symbol, Timeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
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
int CheckRSIMACDSignal()
{
    double rsi = CalculateRSI(RSI_Period, Timeframe, 0);
    double macdMain, macdSignal, macdHistogram;
    CalculateMACD(macdMain, macdSignal, macdHistogram);
    
    // Get dynamic thresholds
    double dynamic_upper, dynamic_lower;
    GetDynamicRSIThresholds(dynamic_upper, dynamic_lower);
    
    // Check for divergence
    bool bullish_div, bearish_div;
    CheckRSIDivergence(bullish_div, bearish_div);
    
    // Enhanced Buy Signal Conditions
    bool buySignal = 
        ((rsi < dynamic_lower) || bullish_div) &&    // RSI oversold OR bullish divergence
        macdMain > macdSignal &&                     // MACD above signal
        macdHistogram > 0 &&                         // Positive momentum
        rsi > CalculateRSI(RSI_Period, 1);          // RSI increasing
        
    // Enhanced Sell Signal Conditions    
    bool sellSignal = 
        ((rsi > dynamic_upper) || bearish_div) &&    // RSI overbought OR bearish divergence
        macdMain < macdSignal &&                     // MACD below signal
        macdHistogram < 0 &&                         // Negative momentum
        rsi < CalculateRSI(RSI_Period, 1);          // RSI decreasing
    
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
bool IsBullishCandlePattern()
{
    CandleData current = GetCandleData(1, Timeframe);
    CandleData previous = GetCandleData(2, Timeframe);
    
    // Get average candle size for reference
    double avgCandleSize = 0;
    for(int i = 1; i <= 10; i++)
    {
        CandleData temp = GetCandleData(i, Timeframe);
        avgCandleSize += temp.body;
    }
    avgCandleSize /= 10;
    
    // Only return true for very strong bullish patterns
    
    // 1. Strong Bullish Engulfing (more stringent criteria)
    bool isStrongBullishEngulfing = 
        current.isBullish &&
        !previous.isBullish &&
        current.open < previous.close &&
        current.close > previous.open &&
        current.body > previous.body * 1.5 && // Increased size requirement
        current.body > avgCandleSize * 1.2;   // Must be larger than average
    
    // 2. Perfect Morning Star
    CandleData twoDaysAgo = GetCandleData(3, Timeframe);
    bool isPerfectMorningStar =
        !twoDaysAgo.isBullish &&
        current.isBullish &&
        previous.body < avgCandleSize * 0.3 && // Smaller doji body
        twoDaysAgo.body > avgCandleSize * 1.2 &&
        current.body > avgCandleSize * 1.2 &&
        current.close > twoDaysAgo.open; // More stringent price requirement
    
    // 3. Clear Hammer
    bool isClearHammer = 
        current.isBullish &&
        current.lowerWick > current.body * 3 && // Increased wick requirement
        current.upperWick < current.body * 0.1 && // Minimal upper wick
        current.body > avgCandleSize * 0.8 &&
        current.low < previous.low; // Must make new low
    
    // Log pattern detection with confidence levels
    if(isStrongBullishEngulfing) Print("Strong Bullish Engulfing Pattern - High Confidence Reversal Signal");
    if(isPerfectMorningStar) Print("Perfect Morning Star Pattern - High Confidence Reversal Signal");
    if(isClearHammer) Print("Clear Hammer Pattern - High Confidence Reversal Signal");
    
    return (isStrongBullishEngulfing || isPerfectMorningStar || isClearHammer);
}

//+------------------------------------------------------------------+
//| Check for Bearish Candle Pattern                                |
//+------------------------------------------------------------------+
bool IsBearishCandlePattern()
{
    CandleData current = GetCandleData(1, Timeframe);
    CandleData previous = GetCandleData(2, Timeframe);
    
    // Get average candle size for reference
    double avgCandleSize = 0;
    for(int i = 1; i <= 10; i++)
    {
        CandleData temp = GetCandleData(i, Timeframe);
        avgCandleSize += temp.body;
    }
    avgCandleSize /= 10;
    
    // Only return true for very strong bearish patterns
    
    // 1. Strong Bearish Engulfing (more stringent criteria)
    bool isStrongBearishEngulfing = 
        !current.isBullish &&
        previous.isBullish &&
        current.open > previous.close &&
        current.close < previous.open &&
        current.body > previous.body * 1.5 && // Increased size requirement
        current.body > avgCandleSize * 1.2;   // Must be larger than average
    
    // 2. Perfect Evening Star
    CandleData twoDaysAgo = GetCandleData(3, Timeframe);
    bool isPerfectEveningStar =
        twoDaysAgo.isBullish &&
        !current.isBullish &&
        previous.body < avgCandleSize * 0.3 && // Smaller doji body
        twoDaysAgo.body > avgCandleSize * 1.2 &&
        current.body > avgCandleSize * 1.2 &&
        current.close < twoDaysAgo.open; // More stringent price requirement
    
    // 3. Clear Shooting Star
    bool isClearShootingStar = 
        !current.isBullish &&
        current.upperWick > current.body * 3 && // Increased wick requirement
        current.lowerWick < current.body * 0.1 && // Minimal lower wick
        current.body > avgCandleSize * 0.8 &&
        current.high > previous.high; // Must make new high
    
    // Log pattern detection with confidence levels
    if(isStrongBearishEngulfing) Print("Strong Bearish Engulfing Pattern - High Confidence Reversal Signal");
    if(isPerfectEveningStar) Print("Perfect Evening Star Pattern - High Confidence Reversal Signal");
    if(isClearShootingStar) Print("Clear Shooting Star Pattern - High Confidence Reversal Signal");
    
    return (isStrongBearishEngulfing || isPerfectEveningStar || isClearShootingStar);
}

//+------------------------------------------------------------------+
//| Comprehensive Pattern Recognition                                 |
//+------------------------------------------------------------------+
int IdentifyTrendPattern()
{
    // 1. Multiple EMA Crossover Analysis
    double current_ema_short = CalculateEMA(EMA_PERIODS_SHORT, Timeframe, 0);
    double current_ema_medium = CalculateEMA(EMA_PERIODS_MEDIUM, Timeframe, 0);
    double current_ema_long = CalculateEMA(EMA_PERIODS_LONG, Timeframe, 0);
    
    // Store historical EMA values
    double past_ema_short[5], past_ema_medium[5], past_ema_long[5];
    for(int i = 0; i < PATTERN_LOOKBACK; i++)
    {
        past_ema_short[i] = CalculateEMA(EMA_PERIODS_SHORT, Timeframe, i+1);
        past_ema_medium[i] = CalculateEMA(EMA_PERIODS_MEDIUM, Timeframe, i+1);
        past_ema_long[i] = CalculateEMA(EMA_PERIODS_LONG, Timeframe, i+1);
    }

    // 2. Trend Strength Analysis
    int bullish_signals = 0;
    int bearish_signals = 0;

    // Check EMA alignment (strongest when short > medium > long for bullish)
    if(current_ema_short > current_ema_medium && current_ema_medium > current_ema_long)
        bullish_signals += 2;
    else if(current_ema_short < current_ema_medium && current_ema_medium < current_ema_long)
        bearish_signals += 2;

    // 3. Golden/Death Cross Detection
    bool golden_cross = false;
    bool death_cross = false;

    // Check for recent golden cross (short EMA crossing above long EMA)
    if(current_ema_short > current_ema_long && past_ema_short[0] < past_ema_long[0])
    {
        if(MathAbs(current_ema_short - current_ema_long) > GOLDEN_CROSS_THRESHOLD * _Point)
            golden_cross = true;
    }
    // Check for recent death cross (short EMA crossing below long EMA)
    else if(current_ema_short < current_ema_long && past_ema_short[0] > past_ema_long[0])
    {
        if(MathAbs(current_ema_short - current_ema_long) > GOLDEN_CROSS_THRESHOLD * _Point)
            death_cross = true;
    }

    // 4. Trend Continuation Pattern
    bool bullish_continuation = true;
    bool bearish_continuation = true;

    // Check if EMAs maintained their order for several periods
    for(int i = 0; i < PATTERN_LOOKBACK - 1; i++)
    {
        if(!(past_ema_short[i] > past_ema_medium[i] && past_ema_medium[i] > past_ema_long[i]))
            bullish_continuation = false;
            
        if(!(past_ema_short[i] < past_ema_medium[i] && past_ema_medium[i] < past_ema_long[i]))
            bearish_continuation = false;
    }

    // 5. Volume Confirmation
    double current_volume = iVolume(_Symbol, Timeframe, 0);
    double avg_volume = 0;
    for(int i = 1; i <= PATTERN_LOOKBACK; i++)
    {
        avg_volume += iVolume(_Symbol, Timeframe, i);
    }
    avg_volume /= PATTERN_LOOKBACK;

    bool volume_confirmation = (current_volume > avg_volume * 1.2); // 20% above average

    // 6. Combine All Signals
    if(golden_cross && bullish_continuation && volume_confirmation)
        bullish_signals += 3;
    if(death_cross && bearish_continuation && volume_confirmation)
        bearish_signals += 3;

    // Add momentum confirmation
    double rsi = CalculateRSI(14, 0);
    if(rsi > 50 && rsi < 70) bullish_signals++;
    if(rsi < 50 && rsi > 30) bearish_signals++;

    // 7. Final Decision Making
    Print("Pattern Analysis - Bullish Signals: ", bullish_signals, " Bearish Signals: ", bearish_signals);

    if(bullish_signals >= 4 && bullish_signals > bearish_signals * 2)
        return 1;  // Strong bullish pattern
    else if(bearish_signals >= 4 && bearish_signals > bullish_signals * 2)
        return -1; // Strong bearish pattern
    
    return 0;     // No clear pattern
}

//+------------------------------------------------------------------+
//| Check for RSI Divergence                                         |
//+------------------------------------------------------------------+
bool CheckRSIDivergence(bool &bullish, bool &bearish, int lookback = 10)
{
    double rsi_values[];
    double price_values[];
    ArrayResize(rsi_values, lookback);
    ArrayResize(price_values, lookback);
    
    // Get RSI and price values
    for(int i = 0; i < lookback; i++)
    {
        rsi_values[i] = CalculateRSI(RSI_Period, Timeframe, i);
        price_values[i] = iLow(_Symbol, Timeframe, i);
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
void GetDynamicRSIThresholds(double &upper_threshold, double &lower_threshold)
{
    double atr = CalculateATR(14, Timeframe);
    double avg_atr = 0;
    
    // Calculate average ATR for last 20 periods
    for(int i = 0; i < 20; i++)
    {
        avg_atr += CalculateATR(14, Timeframe, i);
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
double GetRSITrendStrength(int periods = 5)
{
    double strength = 0;
    double prev_rsi = CalculateRSI(RSI_Period, Timeframe, periods);
    
    // Calculate the strength of the RSI trend
    for(int i = periods-1; i >= 0; i--)
    {
        double current_rsi = CalculateRSI(RSI_Period, Timeframe, i);
        strength += (current_rsi - prev_rsi);
        prev_rsi = current_rsi;
    }
    
    return strength / periods;  // Positive = strengthening, Negative = weakening
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket, int type, double open_price, double stop_loss)
{
    double trailing_stop = TrailingStopPips * _Point;
    double new_stop_loss;

    if (type == POSITION_TYPE_BUY)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        new_stop_loss = price - trailing_stop;

        if (new_stop_loss > stop_loss)
        {
            if (MathAbs(price - LastModificationPrice) >= MinPriceChangeThreshold * _Point)
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
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        new_stop_loss = price + trailing_stop;

        if (new_stop_loss < stop_loss || stop_loss == 0.0)
        {
            if (MathAbs(price - LastModificationPrice) >= MinPriceChangeThreshold * _Point)
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
void ApplyBreakeven(ulong ticket, int type, double open_price, double stop_loss)
{
    double activation_profit = BreakevenActivationPips * _Point;
    double offset = BreakevenOffsetPips * _Point;

    if (type == POSITION_TYPE_BUY)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (price - open_price >= activation_profit)
        {
            double new_stop_loss = open_price + offset;
            if (stop_loss < new_stop_loss)
            {
                if (MathAbs(price - LastModificationPrice) >= MinPriceChangeThreshold * _Point)
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
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if (open_price - price >= activation_profit)
        {
            double new_stop_loss = open_price - offset;
            if (stop_loss > new_stop_loss || stop_loss == 0.0)
            {
                if (MathAbs(price - LastModificationPrice) >= MinPriceChangeThreshold * _Point)
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
void PlaceBuyOrder()
{
    double stop_loss, take_profit;
    CalculateDynamicSLTP(stop_loss, take_profit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(stop_loss / _Point, accountBalance, RiskPercent, minVolume, maxVolume);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double limit_price = price - 10 * _Point; // Place limit order 10 points below current price
    double sl = limit_price - stop_loss;
    double tp = limit_price + take_profit;

    // Normalize SL and TP
    int price_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);
    limit_price = NormalizeDouble(limit_price, price_digits);

    if (trade.BuyLimit(lot_size, limit_price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Buy Limit Order with Dynamic SL/TP"))
    {
        LogTradeDetails(lot_size, stop_loss, take_profit);
    }
    else
    {
        int error = GetLastError();
        Print("Buy Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}

void PlaceSellOrder()
{
    double atr_multiplier = ATRMultiplier; // Use the input parameter
    double stop_loss, take_profit;
    CalculateDynamicSLTP(stop_loss, take_profit, atr_multiplier, PERIOD_H1, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(stop_loss / _Point, accountBalance, RiskPercent, minVolume, maxVolume);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double limit_price = price + 10 * _Point; // Place limit order 10 points above current price
    double sl = limit_price + stop_loss;
    double tp = limit_price - take_profit;

    // Normalize SL and TP
    int price_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);
    limit_price = NormalizeDouble(limit_price, price_digits);

    if (trade.SellLimit(lot_size, limit_price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Sell Limit Order with Dynamic SL/TP"))
    {
        LogTradeDetails(lot_size, stop_loss, take_profit);
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
void PlaceAdditionalBuyOrder()
{
    // Check if we already have maximum allowed positions
    if(CountOrders(POSITION_TYPE_BUY) >= 3)
    {
        Print("Maximum number of buy orders reached (3)");
        return;
    }

    double stop_loss, take_profit;
    CalculateDynamicSLTP(stop_loss, take_profit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(stop_loss / _Point, accountBalance, RiskPercent, minVolume, maxVolume);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double limit_price = price - 10 * _Point;
    double sl = limit_price - stop_loss;
    double tp = limit_price + take_profit;

    int price_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);
    limit_price = NormalizeDouble(limit_price, price_digits);

    if(trade.BuyLimit(lot_size, limit_price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, 
       "Additional Buy Limit Order #" + IntegerToString(CountOrders(POSITION_TYPE_BUY) + 1)))
    {
        LogTradeDetails(lot_size, stop_loss, take_profit);
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
void PlaceAdditionalSellOrder()
{
    // Check if we already have maximum allowed positions
    if(CountOrders(POSITION_TYPE_SELL) >= 3)
    {
        Print("Maximum number of sell orders reached (3)");
        return;
    }

    double stop_loss, take_profit;
    CalculateDynamicSLTP(stop_loss, take_profit, ATRMultiplier, PERIOD_H1, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(stop_loss / _Point, accountBalance, RiskPercent, minVolume, maxVolume);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double limit_price = price + 10 * _Point;
    double sl = limit_price + stop_loss;
    double tp = limit_price - take_profit;

    int price_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);
    limit_price = NormalizeDouble(limit_price, price_digits);

    if(trade.SellLimit(lot_size, limit_price, _Symbol, sl, tp, ORDER_TIME_GTC, 0,
       "Additional Sell Limit Order #" + IntegerToString(CountOrders(POSITION_TYPE_SELL) + 1)))
    {
        LogTradeDetails(lot_size, stop_loss, take_profit);
    }
    else
    {
        int error = GetLastError();
        Print("Additional Sell Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}

// Define the PlaceBuyLimitOrder function
void PlaceBuyLimitOrder(double limitPrice, double tpPrice, double slPrice)
{
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lot_size = CalculateDynamicLotSize(slPrice / _Point, accountBalance, RiskPercent, minVolume, maxVolume);
    
    if (trade.BuyLimit(lot_size, limitPrice, _Symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, "Buy Limit Order"))
    {
        LogTradeDetails(lot_size, slPrice, tpPrice);
    }
    else
    {
        int error = GetLastError();
        Print("Buy Limit Order Failed with Error: ", error);
        ResetLastError();
    }
}

// Define the PlaceSellLimitOrder function
void PlaceSellLimitOrder(double limitPrice, double tpPrice, double slPrice)
{
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lot_size = CalculateDynamicLotSize(slPrice / _Point, accountBalance, RiskPercent, minVolume, maxVolume);
    
    if (trade.SellLimit(lot_size, limitPrice, _Symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, "Sell Limit Order"))
    {
        LogTradeDetails(lot_size, slPrice, tpPrice);
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
void ValidateInputs()
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