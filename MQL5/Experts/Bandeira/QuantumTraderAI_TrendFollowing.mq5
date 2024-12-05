//+------------------------------------------------------------------+
//| QuantumTraderAI_TrendFollowing.mq5                               |
//| VSol Software                                                    |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.08"
#property strict

#include <Trade/Trade.mqh>

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
input double Aggressiveness = 1.0;          // Trade aggressiveness factor
input double RecoveryFactor = 1.2;          // Recovery mode lot size multiplier
input double ATRMultiplier = 1.0;           // ATR multiplier for dynamic SL/TP
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
input bool UseBreakeven = true;             // Enable breakeven
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

//+------------------------------------------------------------------+
//| Global Variables and Objects                                     |
//+------------------------------------------------------------------+
CTrade trade;
double starting_balance;

// Add a minimum price change threshold (in points)
double MinPriceChangeThreshold = 10;

// Store the last modification price
double LastModificationPrice = 0;

//+------------------------------------------------------------------+
//| Helper function to get indicator value                           |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int bufferIndex, int shift = 0)
{
    double value[];
    if (handle == INVALID_HANDLE)
    {
        Print("Invalid indicator handle");
        return 0;
    }

    if (CopyBuffer(handle, bufferIndex, shift, 1, value) > 0)
    {
        return value[0];
    }
    else
    {
        int error = GetLastError();
        Print("Error copying data from indicator handle: ", error);
        ResetLastError();
        return 0;
    }
}

//+------------------------------------------------------------------+
//| Indicator Calculation Functions                                  |
//+------------------------------------------------------------------+
double CalculateSMA(int period, int shift = 0)
{
    int handle = iMA(_Symbol, Timeframe, period, 0, MODE_SMA, PRICE_CLOSE);
    if (handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("Failed to create SMA indicator handle: ", error);
        ResetLastError();
        return 0;
    }
    double value = GetIndicatorValue(handle, 0, shift);
    IndicatorRelease(handle);
    return value;
}

double CalculateEMA(int period, int shift = 0)
{
    int handle = iMA(_Symbol, Timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
    if (handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("Failed to create EMA indicator handle: ", error);
        ResetLastError();
        return 0;
    }
    double value = GetIndicatorValue(handle, 0, shift);
    IndicatorRelease(handle);
    return value;
}

double CalculateRSI(int period, int shift = 0)
{
    int handle = iRSI(_Symbol, Timeframe, period, PRICE_CLOSE);
    if (handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("Failed to create RSI indicator handle: ", error);
        ResetLastError();
        return 0;
    }
    double value = GetIndicatorValue(handle, 0, shift);
    IndicatorRelease(handle);
    return value;
}

double CalculateATR(int period, int shift = 0)
{
    int handle = iATR(_Symbol, Timeframe, period);
    if (handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("Failed to create ATR indicator handle: ", error);
        ResetLastError();
        return 0;
    }
    double value = GetIndicatorValue(handle, 0, shift);
    IndicatorRelease(handle);
    return value;
}

//+------------------------------------------------------------------+
//| Calculate ADX, +DI, and -DI                                      |
//+------------------------------------------------------------------+
void CalculateADX(int period, double &adx, double &plusDI, double &minusDI)
{
    int handle = iADX(_Symbol, Timeframe, period);
    if (handle == INVALID_HANDLE)
    {
        Print("Failed to create ADX handle");
        return;
    }

    double adxVal[];
    double plusDIVal[];
    double minusDIVal[];

    ArraySetAsSeries(adxVal, true);
    ArraySetAsSeries(plusDIVal, true);
    ArraySetAsSeries(minusDIVal, true);

    CopyBuffer(handle, 0, 0, 3, adxVal);
    CopyBuffer(handle, 1, 0, 3, plusDIVal);
    CopyBuffer(handle, 2, 0, 3, minusDIVal);

    adx = NormalizeDouble(adxVal[0], 2);
    plusDI = NormalizeDouble(plusDIVal[0], 2);
    minusDI = NormalizeDouble(minusDIVal[0], 2);

    IndicatorRelease(handle);
}

//+------------------------------------------------------------------+
//| Calculate Volume Step Digits                                     |
//+------------------------------------------------------------------+
int GetVolumeStepDigits(double volume_step)
{
    int digits = 0;
    while (MathFloor(volume_step * MathPow(10, digits)) != volume_step * MathPow(10, digits))
    {
        digits++;
        if (digits > 8) break; // Prevent infinite loop
    }
    return digits;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk Percentage and Stop Loss        |
//+------------------------------------------------------------------+
double CalculateLotSize(double risk_percent, double stop_loss_pips)
{
    // Retrieve account and symbol information
    double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * 10; // For 5-digit brokers
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Calculate the risk amount in account currency
    double risk_amount = account_equity * risk_percent / 100.0;

    // Calculate the lot size based on risk and stop-loss distance
    double lot_size = risk_amount / (stop_loss_pips * pip_value);

    // Ensure the lot size is within broker constraints
    lot_size = MathMax(min_lot, MathMin(lot_size, max_lot));

    // Adjust lot size to valid volume step
    lot_size = MathFloor(lot_size / lot_step) * lot_step;

    // Ensure the adjusted lot size is not less than minimum lot
    lot_size = MathMax(lot_size, min_lot);

    // Normalize lot size to avoid floating-point issues
    int volume_step_digits = GetVolumeStepDigits(lot_step);
    lot_size = NormalizeDouble(lot_size, volume_step_digits);

    Print("Calculated Lot Size: ", lot_size);
    return lot_size;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size                                       |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(double stop_loss_points)
{
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * (RiskPercent / 100.0);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if (tick_value == 0.0 || tick_size == 0.0 || lot_step == 0.0)
    {
        Print("Error: Invalid symbol properties for lot size calculation.");
        return 0.0;
    }

    double lot_size = (risk_amount / stop_loss_points) / (tick_value / tick_size);
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    lot_size = MathMax(lot_size, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
    lot_size = MathMin(lot_size, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));

    return lot_size;
}

//+------------------------------------------------------------------+
//| Check Drawdown and Halt Trading if Necessary                     |
//+------------------------------------------------------------------+
bool CheckDrawdown()
{
    // Retrieve account balance and equity
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Avoid division by zero
    if (account_balance == 0.0)
        account_balance = 0.0001;

    // Calculate drawdown percentage
    double drawdown_percent = ((account_balance - account_equity) / account_balance) * 100.0;

    // Log current drawdown for monitoring
    Print("Current Drawdown: ", drawdown_percent, "%");

    // Check if drawdown exceeds the maximum allowed
    if (drawdown_percent >= MaxDrawdownPercent)
    {
        Print("Maximum Drawdown Reached: Trading Halted");
        Alert("Alert: Maximum Drawdown Reached. Trading Halted.");
        return true; // Indicate that trading should be stopped
    }

    // Alert when drawdown approaches the limit (e.g., 80% of max drawdown)
    if (drawdown_percent >= MaxDrawdownPercent * 0.8)
    {
        Alert("Warning: Drawdown Approaching Limit.");
    }

    return false; // Indicate that trading can continue
}

//+------------------------------------------------------------------+
//| Calculate Dynamic SL/TP Levels Based on ATR                      |
//+------------------------------------------------------------------+
void CalculateDynamicSLTP(double &stop_loss, double &take_profit, double atr_multiplier)
{
    double atr = CalculateATR(14); // 14-period ATR

    if (atr <= 0)
    {
        Print("ATR calculation failed or returned zero. Using default SL/TP values.");
        stop_loss = 20 * _Point; // Default stop loss
        take_profit = 40 * _Point; // Default take profit
        return;
    }

    // Define SL/TP based on ATR
    double dynamicStopLoss = atr * atr_multiplier;
    stop_loss = MathMax(dynamicStopLoss, fixedStopLossPips * _Point); // Use the larger of dynamic or fixed SL
    take_profit = atr * atr_multiplier * 2.0; // Example: TP is twice the SL distance

    Print("Dynamic SL: ", stop_loss, " | Dynamic TP: ", take_profit);
}

//+------------------------------------------------------------------+
//| Log Trade Details                                                |
//+------------------------------------------------------------------+
void LogTradeDetails(double lot_size, double stop_loss, double take_profit)
{
    // Retrieve current account equity and balance
    double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);

    // Avoid division by zero
    if (account_balance == 0.0)
        account_balance = 0.0001;

    // Calculate current drawdown percentage
    double drawdown_percent = ((account_balance - account_equity) / account_balance) * 100.0;

    // Log trade details to the terminal
    Print("Trade Log: Lot Size: ", lot_size, ", SL: ", stop_loss, ", TP: ", take_profit, ", Equity: ", account_equity, ", Drawdown: ", drawdown_percent, "%");

    // Optionally, write to a file or external log
    // FileWrite(...);
}

//+------------------------------------------------------------------+
//| Check if Within Trading Hours                                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    datetime current_time = TimeCurrent();
    string current_time_str = TimeToString(current_time, TIME_MINUTES);

    if (current_time_str >= TradingStartTime && current_time_str <= TradingEndTime)
        return true;
    else
        return false;
}

//+------------------------------------------------------------------+
//| Trend Following Core Strategy                                    |
//+------------------------------------------------------------------+
int TrendFollowingCore()
{
    double sma = CalculateSMA(100); // Shortened SMA period
    double ema = CalculateEMA(20);  // Shortened EMA period
    double rsi = CalculateRSI(14);

    double adx, plusDI, minusDI;
    CalculateADX(ADXPeriod, adx, plusDI, minusDI);

    // Determine trend and generate signals
    if (ema > sma && rsi < RSIUpperThreshold && adx > TrendADXThreshold && plusDI > minusDI)
    {
        Print("Trend Following: Buy Signal");
        return 1; // Buy signal
    }
    else if (ema < sma && rsi > RSILowerThreshold && adx > TrendADXThreshold && minusDI > plusDI)
    {
        Print("Trend Following: Sell Signal");
        return -1; // Sell signal
    }
    return 0; // Hold signal
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
//| Detect Liquidity Pools                                           |
//+------------------------------------------------------------------+
void DetectLiquidityPools(MqlBookInfo &book_info[], int book_count, double liquidityThreshold)
{
    for (int i = 0; i < book_count; i++)
    {
        if (book_info[i].volume > liquidityThreshold)
        {
            Print("Liquidity Pool Detected at Price: ", book_info[i].price);
            // TODO
            // Return a List: Return a list of detected liquidity pool prices.
            // Trigger Actions: Trigger specific trading actions or signals when a liquidity pool is detected.
        }
    }
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
void MonitorOrderFlow()
{
    if (!UseDOMAnalysis)
        return;

    MqlBookInfo book_info[];
    int book_count = MarketBookGet(_Symbol, book_info);
    if (book_count > 0)
    {
        double buyVolume = 0.0;
        double sellVolume = 0.0;

        // Loop through DOM data and analyze order flow
        for (int i = 0; i < book_count; i++)
        {
            // Accumulate buy and sell volumes
            if (book_info[i].type == BOOK_TYPE_BUY)
                buyVolume += book_info[i].volume;
            else if (book_info[i].type == BOOK_TYPE_SELL)
                sellVolume += book_info[i].volume;
        }

        // Detect liquidity pools
        DetectLiquidityPools(book_info, book_count, LiquidityThreshold);

        // Detect order flow imbalances
        int imbalanceSignal = DetectOrderFlowImbalances(buyVolume, sellVolume, ImbalanceThreshold);
        
        // Get current RSI value
        double rsi = CalculateRSI(14);

        if (imbalanceSignal == 1 && !ManagePositions(POSITION_TYPE_BUY) && rsi < RSILowerThreshold)
        {
            PlaceBuyOrder();
        }
        else if (AllowShortTrades && imbalanceSignal == -1 && !ManagePositions(POSITION_TYPE_SELL) && rsi > RSIUpperThreshold)
        {
            PlaceSellOrder();
        }
    }
    else if (book_count == 0)
    {
        Print("No order flow data available.");
    }
    else
    {
        int error = GetLastError();
        Print("MarketBookGet() failed with error: ", error);
        ResetLastError();
        // Skip this feature
    }
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
    double rsi = CalculateRSI(RSI_Period);
    double macdMain, macdSignal, macdHistogram;
    CalculateMACD(macdMain, macdSignal, macdHistogram);
    
    // Previous values for crossover detection
    double prevMacdMain, prevMacdSignal, prevMacdHist;
    CalculateMACD(prevMacdMain, prevMacdSignal, prevMacdHist, 1);
    
    // Buy Signal Conditions
    bool buySignal = 
        rsi < RSILowerThreshold &&                  // RSI oversold
        macdMain > macdSignal &&                    // Current MACD above signal
        prevMacdMain <= prevMacdSignal &&           // Previous MACD below signal (crossover)
        macdHistogram > prevMacdHist;               // Increasing momentum
        
    // Sell Signal Conditions
    bool sellSignal = 
        rsi > RSIUpperThreshold &&                  // RSI overbought
        macdMain < macdSignal &&                    // Current MACD below signal
        prevMacdMain >= prevMacdSignal &&           // Previous MACD above signal (crossover)
        macdHistogram < prevMacdHist;               // Decreasing momentum
        
    // Exit Conditions
    bool exitLong = 
        rsi > RSI_Neutral &&                        // RSI above neutral
        macdHistogram < 0;                          // Negative momentum
        
    bool exitShort = 
        rsi < RSI_Neutral &&                        // RSI below neutral
        macdHistogram > 0;                          // Positive momentum
    
    // Log signals
    if(buySignal) Print("RSI-MACD Buy Signal: RSI=", rsi, " MACD Hist=", macdHistogram);
    if(sellSignal) Print("RSI-MACD Sell Signal: RSI=", rsi, " MACD Hist=", macdHistogram);
    if(exitLong) Print("RSI-MACD Exit Long Signal");
    if(exitShort) Print("RSI-MACD Exit Short Signal");
    
    return buySignal ? 1 : (sellSignal ? -1 : 0);
}

//+------------------------------------------------------------------+
//| Modify ExecuteTradingLogic to include RSI-MACD                   |
//+------------------------------------------------------------------+
void ExecuteTradingLogic()
{
    // Check if within trading hours
    if (!IsWithinTradingHours())
        return;

    // Check drawdown before executing any trades
    if (CheckDrawdown())
    {
        // Trading is halted due to excessive drawdown
        return;
    }

    // Manage open positions
    ManagePositions();

    // Execute Trend Strategy if enabled
    if (UseTrendStrategy)
    {
        int trendSignal = TrendFollowingCore();
        int patternSignal = IdentifyTrendPattern();
        int rsiMacdSignal = CheckRSIMACDSignal();
        
        // Long trades
        if (trendSignal == 1 && patternSignal == 1 && rsiMacdSignal == 1)
        {
            if (!ManagePositions(POSITION_TYPE_BUY) && !HasPendingOrder(ORDER_TYPE_BUY_LIMIT))
            {
                PlaceBuyOrder();
            }
        }
        // Short trades - only if enabled
        else if (AllowShortTrades && trendSignal == -1 && patternSignal == -1 && rsiMacdSignal == -1)
        {
            if (!ManagePositions(POSITION_TYPE_SELL) && !HasPendingOrder(ORDER_TYPE_SELL_LIMIT))
            {
                PlaceSellOrder();
            }
        }
    }

    // Monitor order flow
    MonitorOrderFlow();
}

//+------------------------------------------------------------------+
//| Check for Pending Orders                                         |
//+------------------------------------------------------------------+
bool HasPendingOrder(int type)
{
    int total = OrdersTotal();
    for (int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if (OrderSelect(ticket))
        {
            if (OrderGetInteger(ORDER_TYPE) == type && OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                return true;
            }
        }
    }
    return false;
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

    // Validate RecoveryFactor
    if (RecoveryFactor < 1.0 || RecoveryFactor > 2.0)
    {
        Alert("RecoveryFactor must be between 1.0 and 2.0");
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
//| Main OnInit Function                                             |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate input parameters
    ValidateInputs();

    // Initialize starting balance
    starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);

    // Print current configurations to the journal/log
    Print("Configuration: ");
    Print("  UseTrendStrategy=", UseTrendStrategy);
    Print("  RiskPercent=", RiskPercent);
    Print("  MaxDrawdownPercent=", MaxDrawdownPercent);
    Print("  Aggressiveness=", Aggressiveness);
    Print("  RecoveryFactor=", RecoveryFactor);
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

    // Additional initialization code can be added here

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main OnTick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Execute trading logic on each tick
    ExecuteTradingLogic();
}

//+------------------------------------------------------------------+
//| Cleanup Code                                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Deinitializing EA...");
    // Additional cleanup code can be added here
}

//+------------------------------------------------------------------+
//| Candle Pattern Analysis Functions                                |
//+------------------------------------------------------------------+

// Structure to hold candle data
struct CandleData {
    double open;
    double high;
    double low;
    double close;
    double body;
    double upperWick;
    double lowerWick;
    bool isBullish;
};

//+------------------------------------------------------------------+
//| Get Normalized Candle Data                                       |
//+------------------------------------------------------------------+
CandleData GetCandleData(int shift)
{
    CandleData candle;
    
    candle.open = iOpen(_Symbol, Timeframe, shift);
    candle.high = iHigh(_Symbol, Timeframe, shift);
    candle.low = iLow(_Symbol, Timeframe, shift);
    candle.close = iClose(_Symbol, Timeframe, shift);
    
    candle.isBullish = (candle.close > candle.open);
    
    // Calculate body and wick sizes
    candle.body = MathAbs(candle.close - candle.open);
    candle.upperWick = candle.high - (candle.isBullish ? candle.close : candle.open);
    candle.lowerWick = (candle.isBullish ? candle.open : candle.close) - candle.low;
    
    return candle;
}

//+------------------------------------------------------------------+
//| Check for Bullish Candle Pattern                                |
//+------------------------------------------------------------------+
bool IsBullishCandlePattern()
{
    CandleData current = GetCandleData(1);
    CandleData previous = GetCandleData(2);
    
    // Get average candle size for reference
    double avgCandleSize = 0;
    for(int i = 1; i <= 10; i++)
    {
        CandleData temp = GetCandleData(i);
        avgCandleSize += temp.body;
    }
    avgCandleSize /= 10;
    
    // 1. Bullish Engulfing
    bool isBullishEngulfing = 
        current.isBullish &&
        !previous.isBullish &&
        current.open < previous.close &&
        current.close > previous.open &&
        current.body > previous.body * 1.2; // Body should be significantly larger
    
    // 2. Morning Star
    CandleData twoDaysAgo = GetCandleData(3);
    bool isMorningStar =
        !twoDaysAgo.isBullish &&
        current.isBullish &&
        previous.body < avgCandleSize * 0.5 && // Small body in middle
        twoDaysAgo.body > avgCandleSize &&
        current.body > avgCandleSize &&
        current.close > (twoDaysAgo.open + twoDaysAgo.close) / 2;
    
    // 3. Hammer
    bool isHammer = 
        current.isBullish &&
        current.lowerWick > current.body * 2 && // Long lower wick
        current.upperWick < current.body * 0.2 && // Minimal upper wick
        current.body > avgCandleSize * 0.5;
    
    // 4. Bullish Harami
    bool isBullishHarami =
        current.isBullish &&
        !previous.isBullish &&
        current.body < previous.body * 0.6 &&
        current.high < previous.open &&
        current.low > previous.close;
    
    // Log pattern detection
    if(isBullishEngulfing) Print("Bullish Engulfing Pattern Detected");
    if(isMorningStar) Print("Morning Star Pattern Detected");
    if(isHammer) Print("Hammer Pattern Detected");
    if(isBullishHarami) Print("Bullish Harami Pattern Detected");
    
    return (isBullishEngulfing || isMorningStar || isHammer || isBullishHarami);
}

//+------------------------------------------------------------------+
//| Check for Bearish Candle Pattern                                |
//+------------------------------------------------------------------+
bool IsBearishCandlePattern()
{
    CandleData current = GetCandleData(1);
    CandleData previous = GetCandleData(2);
    
    // Get average candle size for reference
    double avgCandleSize = 0;
    for(int i = 1; i <= 10; i++)
    {
        CandleData temp = GetCandleData(i);
        avgCandleSize += temp.body;
    }
    avgCandleSize /= 10;
    
    // 1. Bearish Engulfing
    bool isBearishEngulfing = 
        !current.isBullish &&
        previous.isBullish &&
        current.open > previous.close &&
        current.close < previous.open &&
        current.body > previous.body * 1.2;
    
    // 2. Evening Star
    CandleData twoDaysAgo = GetCandleData(3);
    bool isEveningStar =
        twoDaysAgo.isBullish &&
        !current.isBullish &&
        previous.body < avgCandleSize * 0.5 &&
        twoDaysAgo.body > avgCandleSize &&
        current.body > avgCandleSize &&
        current.close < (twoDaysAgo.open + twoDaysAgo.close) / 2;
    
    // 3. Shooting Star
    bool isShootingStar = 
        !current.isBullish &&
        current.upperWick > current.body * 2 &&
        current.lowerWick < current.body * 0.2 &&
        current.body > avgCandleSize * 0.5;
    
    // 4. Bearish Harami
    bool isBearishHarami =
        !current.isBullish &&
        previous.isBullish &&
        current.body < previous.body * 0.6 &&
        current.high < previous.close &&
        current.low > previous.open;
    
    // Log pattern detection
    if(isBearishEngulfing) Print("Bearish Engulfing Pattern Detected");
    if(isEveningStar) Print("Evening Star Pattern Detected");
    if(isShootingStar) Print("Shooting Star Pattern Detected");
    if(isBearishHarami) Print("Bearish Harami Pattern Detected");
    
    return (isBearishEngulfing || isEveningStar || isShootingStar || isBearishHarami);
}

//+------------------------------------------------------------------+
//| Count Current Orders by Type                                      |
//+------------------------------------------------------------------+
int CountOrders(int type)
{
    int count = 0;
    int total = PositionsTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_TYPE) == type && 
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                count++;
            }
        }
    }
    return count;
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
    CalculateDynamicSLTP(stop_loss, take_profit, ATRMultiplier);

    double lot_size = CalculateDynamicLotSize(stop_loss / _Point);
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
    CalculateDynamicSLTP(stop_loss, take_profit, ATRMultiplier);

    double lot_size = CalculateDynamicLotSize(stop_loss / _Point);
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

//+------------------------------------------------------------------+
//| Comprehensive Pattern Recognition                                 |
//+------------------------------------------------------------------+
int IdentifyTrendPattern()
{
    // 1. Multiple EMA Crossover Analysis
    double current_ema_short = CalculateEMA(EMA_PERIODS_SHORT, 0);
    double current_ema_medium = CalculateEMA(EMA_PERIODS_MEDIUM, 0);
    double current_ema_long = CalculateEMA(EMA_PERIODS_LONG, 0);
    
    // Store historical EMA values
    double past_ema_short[5], past_ema_medium[5], past_ema_long[5];
    for(int i = 0; i < PATTERN_LOOKBACK; i++)
    {
        past_ema_short[i] = CalculateEMA(EMA_PERIODS_SHORT, i+1);
        past_ema_medium[i] = CalculateEMA(EMA_PERIODS_MEDIUM, i+1);
        past_ema_long[i] = CalculateEMA(EMA_PERIODS_LONG, i+1);
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
//| Order Placement Functions                                        |
//+------------------------------------------------------------------+
void PlaceBuyOrder()
{
    double stop_loss, take_profit;
    CalculateDynamicSLTP(stop_loss, take_profit, ATRMultiplier);

    double lot_size = CalculateDynamicLotSize(stop_loss / _Point);
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
    CalculateDynamicSLTP(stop_loss, take_profit, atr_multiplier);

    double lot_size = CalculateDynamicLotSize(stop_loss / _Point);
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
