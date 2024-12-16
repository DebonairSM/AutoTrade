#include <Trade/Trade.mqh>
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
double CalculateSMA(int period, ENUM_TIMEFRAMES timeframe, int shift = 0)
{
    int handle = iMA(_Symbol, timeframe, period, 0, MODE_SMA, PRICE_CLOSE);
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

double CalculateEMA(int period, ENUM_TIMEFRAMES timeframe, int shift = 0)
{
    int handle = iMA(_Symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
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

double CalculateRSI(int period, ENUM_TIMEFRAMES timeframe, int shift = 0)
{
    int handle = iRSI(_Symbol, timeframe, period, PRICE_CLOSE);
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

double CalculateATR(int period, ENUM_TIMEFRAMES timeframe, int shift = 0)
{
    int handle = iATR(_Symbol, timeframe, period);
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
void CalculateADX(int period, ENUM_TIMEFRAMES timeframe, double &adx, double &plusDI, double &minusDI)
{
    int handle = iADX(_Symbol, timeframe, period);
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
double CalculateLotSize(double risk_percent, double stop_loss_pips, double accountEquity, 
                       double tickValue, double minVolume, double maxVolume, double volumeStep)
{
    // Convert risk percentage to decimal
    double risk_decimal = risk_percent / 100.0;
    
    // Calculate the risk amount in account currency
    double risk_amount = accountEquity * risk_decimal;
    
    // Calculate pip value (how much one pip is worth per lot)
    double pip_value = tickValue * 10; // Multiply by 10 because tickValue is per 0.1 pip
    
    // Calculate the lot size
    double lot_size = risk_amount / (stop_loss_pips * pip_value);
    
    // Round to nearest volume step
    lot_size = MathFloor(lot_size / volumeStep) * volumeStep;
    
    // Ensure lot size is within allowed range
    lot_size = MathMax(minVolume, MathMin(lot_size, maxVolume));
    
    // Normalize to avoid floating point issues
    int volume_step_digits = GetVolumeStepDigits(volumeStep);
    lot_size = NormalizeDouble(lot_size, volume_step_digits);
    
    Print("Risk Amount: ", risk_amount, 
          " Stop Loss Pips: ", stop_loss_pips,
          " Pip Value: ", pip_value,
          " Calculated Lot Size: ", lot_size);
          
    return lot_size;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size with improved safety and logging       |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(double stop_loss_points, double accountBalance, 
                              double riskPercent, double minVolume, double maxVolume)
{
    // Input validation
    if(stop_loss_points <= 0)
    {
        Print("Error: Invalid stop loss points (", stop_loss_points, ")");
        return minVolume;
    }
    
    if(accountBalance <= 0)
    {
        Print("Error: Invalid account balance (", accountBalance, ")");
        return minVolume;
    }
    
    if(riskPercent <= 0 || riskPercent > 100)
    {
        Print("Error: Invalid risk percent (", riskPercent, ")");
        return minVolume;
    }

    // Get symbol properties
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Validate symbol properties
    if(tick_value <= 0 || tick_size <= 0 || lot_step <= 0)
    {
        string error = StringFormat("Invalid symbol properties - Tick Value: %.5f, Tick Size: %.5f, Lot Step: %.5f",
                                  tick_value, tick_size, lot_step);
        Print(error);
        return minVolume;
    }

    // Calculate risk amount
    double risk_amount = accountBalance * (riskPercent / 100.0);
    
    // Calculate lot size
    double lot_size = 0;
    
    // Prevent division by zero
    if(tick_value > 0 && tick_size > 0)
    {
        lot_size = (risk_amount / stop_loss_points) / (tick_value / tick_size);
    }
    else
    {
        Print("Error: Invalid tick value or size");
        return minVolume;
    }

    // Round to nearest lot step
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    // Ensure lot size is within allowed range
    lot_size = MathMax(lot_size, minVolume);
    lot_size = MathMin(lot_size, maxVolume);
    
    // Normalize lot size to avoid floating point issues
    int digits = (int)SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lot_size = NormalizeDouble(lot_size, digits);

    // Log calculation details
    string log_message = StringFormat(
        "Lot Size Calculation:\n" +
        "Account Balance: %.2f\n" +
        "Risk Percent: %.2f%%\n" +
        "Risk Amount: %.2f\n" +
        "Stop Loss Points: %.2f\n" +
        "Tick Value: %.5f\n" +
        "Tick Size: %.5f\n" +
        "Calculated Lot Size: %.2f\n" +
        "Final Lot Size (after limits): %.2f",
        accountBalance,
        riskPercent,
        risk_amount,
        stop_loss_points,
        tick_value,
        tick_size,
        lot_size,
        lot_size
    );
    Print(log_message);

    return lot_size;
}

//+------------------------------------------------------------------+
//| Check Drawdown and Halt Trading if Necessary                     |
//+------------------------------------------------------------------+
bool CheckDrawdown(double maxDrawdownPercent, double accountBalance, double accountEquity)
{
    if (accountBalance == 0.0) accountBalance = 0.0001;
    
    double drawdown_percent = ((accountBalance - accountEquity) / accountBalance) * 100.0;
    
    // Only log if drawdown is significant
    if (drawdown_percent >= maxDrawdownPercent)
    {
        Print("ALERT: Maximum Drawdown Reached: ", drawdown_percent, "% - Trading Halted");
        return true;
    }
    else if (drawdown_percent >= maxDrawdownPercent * 0.8) // Only log when approaching max drawdown
    {
        Print("WARNING: Significant Drawdown: ", drawdown_percent, "% - Approaching Limit");
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic SL/TP Levels Based on ATR                      |
//+------------------------------------------------------------------+
void CalculateDynamicSLTP(double &stop_loss, double &take_profit, double atr_multiplier, ENUM_TIMEFRAMES timeframe, double fixedStopLossPips)
{
    double atr = CalculateATR(14, timeframe);

    if (atr <= 0)
    {
        Print("ATR calculation failed or returned zero. Using default SL/TP values.");
        stop_loss = fixedStopLossPips * _Point;
        take_profit = 40 * _Point;
        return;
    }

    double dynamicStopLoss = atr * atr_multiplier;
    stop_loss = MathMax(dynamicStopLoss, fixedStopLossPips * _Point);
    take_profit = atr * atr_multiplier * 2.0;

    // Use the new logging function
    LogDynamicSLTP(stop_loss, take_profit, _Symbol, timeframe);
}

//+------------------------------------------------------------------+
//| Log Dynamic SL/TP values with reduced noise                      |
//+------------------------------------------------------------------+
void LogDynamicSLTP(double stopLoss, double takeProfit, string symbol, ENUM_TIMEFRAMES timeframe)
{
    static double lastSL = 0;
    static double lastTP = 0;
    static datetime lastLogTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Prevent division by zero
    if (lastSL == 0) lastSL = stopLoss;
    if (lastTP == 0) lastTP = takeProfit;
    
    // Only log if SL/TP changed by more than 1% or after 5 minutes
    if (MathAbs(stopLoss - lastSL)/lastSL > 0.01 || 
        MathAbs(takeProfit - lastTP)/lastTP > 0.01 || 
        currentTime - lastLogTime >= 300)
    {
        Print(symbol, ",", EnumToString(timeframe), " Dynamic SL: ", stopLoss, " | Dynamic TP: ", takeProfit);
        lastSL = stopLoss;
        lastTP = takeProfit;
        lastLogTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Log DI Difference values with reduced noise                      |
//+------------------------------------------------------------------+
void LogDIDifference(double diDifference, double threshold, string symbol, ENUM_TIMEFRAMES timeframe)
{
    static double lastDIDifference = 0;
    static datetime lastLogTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Only log if the difference has changed by more than 0.5 or after 5 minutes
    if (MathAbs(diDifference - lastDIDifference) > 0.5 || currentTime - lastLogTime >= 300)
    {
        Print(symbol, ",", EnumToString(timeframe), " DI Difference: ", diDifference, " (Threshold: ", threshold, ")");
        lastDIDifference = diDifference;
        lastLogTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Log Trade Details                                                |
//+------------------------------------------------------------------+
void LogTradeDetails(double lot_size, double stop_loss, double take_profit)
{
    // Create log message
    string log_message = StringFormat(
        "\n=== Trade Log [%s] ===\n"
        "Time: %s\n"
        "Symbol: %s\n"
        "Lot Size: %.2f\n"
        "Stop Loss: %.5f\n"
        "Take Profit: %.5f\n"
        "Account Balance: %.2f\n"
        "Account Equity: %.2f\n"
        "Current Drawdown: %.2f%%\n"
        "===================\n",
        __FUNCTION__,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
        _Symbol,
        lot_size,
        stop_loss,
        take_profit,
        AccountInfoDouble(ACCOUNT_BALANCE),
        AccountInfoDouble(ACCOUNT_EQUITY),
        ((AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY)) / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0
    );
    
    // Print to Experts tab
    Print(log_message);
    
    // Write to file in the correct location
    string filename = "QuantumTraderAI_" + _Symbol + ".log";
    int filehandle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_SHARE_WRITE);
    
    if(filehandle != INVALID_HANDLE)
    {
        FileSeek(filehandle, 0, SEEK_END);     // Move to end of file
        FileWriteString(filehandle, log_message);  // Write the log
        FileClose(filehandle);
        Print("Log written to: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Logs\\", filename);
    }
    else
    {
        Print("Failed to open log file: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Check if Within Trading Hours                                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours(string startTime, string endTime)
{
    datetime current_time = TimeCurrent();
    string current_time_str = TimeToString(current_time, TIME_MINUTES);

    if (current_time_str >= startTime && current_time_str <= endTime)
        return true;
    else
        return false;
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
CandleData GetCandleData(int shift, ENUM_TIMEFRAMES timeframe)
{
    CandleData candle;
    
    candle.open = iOpen(_Symbol, timeframe, shift);
    candle.high = iHigh(_Symbol, timeframe, shift);
    candle.low = iLow(_Symbol, timeframe, shift);
    candle.close = iClose(_Symbol, timeframe, shift);
    
    candle.isBullish = (candle.close > candle.open);
    
    // Calculate body and wick sizes
    candle.body = MathAbs(candle.close - candle.open);
    candle.upperWick = candle.high - (candle.isBullish ? candle.close : candle.open);
    candle.lowerWick = (candle.isBullish ? candle.open : candle.close) - candle.low;
    
    return candle;
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
//| Add helper function to check for active trades or pending orders |
//+------------------------------------------------------------------+
bool HasActiveTradeOrPendingOrder(int type)
{
    // Check positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_TYPE) == type)
                return true;
        }
    }
    
    // Check pending orders
    for(int i = 0; i < OrdersTotal(); i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket))
        {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
                int orderType = (int)OrderGetInteger(ORDER_TYPE);
                if((type == POSITION_TYPE_BUY && (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)) ||
                   (type == POSITION_TYPE_SELL && (orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP)))
                    return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get Best Limit Order Price                                       |
//+------------------------------------------------------------------+
double GetBestLimitOrderPrice(ENUM_ORDER_TYPE orderType, double &tpPrice, double &slPrice, double liquidityThreshold, double takeProfitPips, double stopLossPips)
{
    MqlBookInfo book_info[];
    
    // Get market depth data
    if (!MarketBookGet(_Symbol, book_info))
    {
        Print("Failed to get market depth data - Error: ", GetLastError());
        return 0.0;
    }
    
    int book_count = ArraySize(book_info);
    if (book_count == 0)
    {
        Print("Empty market depth data");
        return 0.0;
    }
    
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spread = currentAsk - currentBid;
    double atr = CalculateATR(14, PERIOD_CURRENT);
    
    // Initialize variables for liquidity analysis
    double bestPrice = 0.0;
    double maxVolume = 0.0;
    
    // For buy limit orders
    if (orderType == ORDER_TYPE_BUY_LIMIT)
    {
        // Look for significant buy orders (support levels)
        for (int i = 0; i < book_count; i++)
        {
            if (book_info[i].type == BOOK_TYPE_BUY)
            {
                if (book_info[i].volume > liquidityThreshold && 
                    book_info[i].volume > maxVolume &&
                    book_info[i].price < currentBid)  // Look for prices below current bid
                {
                    maxVolume = book_info[i].volume;
                    bestPrice = book_info[i].price + (spread / 2); // Place order slightly above support
                }
            }
        }
        
        // If no significant liquidity found, use ATR-based placement
        if (bestPrice == 0.0)
        {
            bestPrice = currentBid - (atr * 0.1); // Place 10% of ATR below current bid
        }
        
        // Adjust TP/SL based on the limit price
        if (bestPrice > 0.0)
        {
            tpPrice = bestPrice + (takeProfitPips * _Point);
            slPrice = bestPrice - (stopLossPips * _Point);
            
            Print("Buy Limit Analysis - Price: ", bestPrice, 
                  " Volume: ", maxVolume,
                  " ATR: ", atr,
                  " Spread: ", spread);
        }
    }
    
    // For sell limit orders
    else if (orderType == ORDER_TYPE_SELL_LIMIT)
    {
        // Look for significant sell orders (resistance levels)
        for (int i = 0; i < book_count; i++)
        {
            if (book_info[i].type == BOOK_TYPE_SELL)
            {
                if (book_info[i].volume > liquidityThreshold && 
                    book_info[i].volume > maxVolume &&
                    book_info[i].price > currentAsk)  // Look for prices above current ask
                {
                    maxVolume = book_info[i].volume;
                    bestPrice = book_info[i].price - (spread / 2); // Place order slightly below resistance
                }
            }
        }
        
        // If no significant liquidity found, use ATR-based placement
        if (bestPrice == 0.0)
        {
            bestPrice = currentAsk + (atr * 0.1); // Place 10% of ATR above current ask
        }
        
        // Adjust TP/SL based on the limit price
        if (bestPrice > 0.0)
        {
            tpPrice = bestPrice - (takeProfitPips * _Point);
            slPrice = bestPrice + (stopLossPips * _Point);
            
            Print("Sell Limit Analysis - Price: ", bestPrice,
                  " Volume: ", maxVolume,
                  " ATR: ", atr,
                  " Spread: ", spread);
        }
    }
    
    // Validate the price
    if (bestPrice > 0.0)
    {
        // Ensure the price is within reasonable bounds
        double maxDeviation = atr * 2; // Maximum 2x ATR deviation
        if (orderType == ORDER_TYPE_BUY_LIMIT)
        {
            if (bestPrice > currentBid || bestPrice < (currentBid - maxDeviation))
            {
                Print("Buy limit price outside reasonable bounds");
                return 0.0;
            }
        }
        else if (orderType == ORDER_TYPE_SELL_LIMIT)
        {
            if (bestPrice < currentAsk || bestPrice > (currentAsk + maxDeviation))
            {
                Print("Sell limit price outside reasonable bounds");
                return 0.0;
            }
        }
    }
    
    // If no liquidity pool is detected or an invalid order type is provided, return 0.0
    return 0.0;
}

//+------------------------------------------------------------------+
//| Detect Liquidity Pools Near TP/SL                                |
//+------------------------------------------------------------------+
bool DetectLiquidityPoolsNearTPSL(MqlBookInfo &book_info[], int book_count, double liquidityThreshold, double tpPrice, double slPrice, double &poolPrice, double &poolVolume)
{
    bool liquidityPoolDetected = false;
    poolPrice = 0.0;
    poolVolume = 0.0;

    for (int i = 0; i < book_count; i++)
    {
        if (book_info[i].volume > liquidityThreshold)
        {
            double currentPrice = book_info[i].price;
            double tpDistance = MathAbs(currentPrice - tpPrice);
            double slDistance = MathAbs(currentPrice - slPrice);

            if (tpDistance <= 10 * _Point || slDistance <= 10 * _Point)
            {
                liquidityPoolDetected = true;
                poolPrice = currentPrice;
                poolVolume = book_info[i].volume;
                
                Print("Liquidity Pool Detected Near TP/SL - Price: ", poolPrice, " Volume: ", poolVolume);
                break;  // Exit loop after finding the first liquidity pool near TP/SL
            }
        }
    }

    return liquidityPoolDetected;
}

//+------------------------------------------------------------------+
//| Structure to hold market analysis data                           |
//+------------------------------------------------------------------+
struct MarketAnalysisData
{
    // Price data
    double currentPrice;
    
    // EMAs
    double ema_short;
    double ema_medium;
    double ema_long;
    
    // Trend indicators
    double adx;
    double plusDI;
    double minusDI;
    
    // Momentum indicators
    double rsi;
    double macdMain;
    double macdSignal;
    double macdHistogram;
    double atr;
    
    // Additional data
    bool bullishPattern;
    bool bearishPattern;
};

//+------------------------------------------------------------------+
//| Structure to hold market analysis parameters                      |
//+------------------------------------------------------------------+
struct MarketAnalysisParameters
{
    // EMA Periods
    int ema_period_short;
    int ema_period_medium;
    int ema_period_long;
    
    // ADX/RSI Parameters
    int adx_period;
    int rsi_period;
    double trend_adx_threshold;
    
    // RSI Thresholds
    double rsi_upper_threshold;
    double rsi_lower_threshold;
};

//+------------------------------------------------------------------+
//| Log Market Analysis using pre-calculated values                  |
//+------------------------------------------------------------------+
void LogMarketAnalysis(const MarketAnalysisData& data, 
                      const MarketAnalysisParameters& params,
                      ENUM_TIMEFRAMES timeframe,
                      bool useDOMAnalysis)
{
    static datetime last_check = 0;
    datetime current_time = TimeCurrent();
    
    // Check every 5 minutes (300 seconds)
    if (current_time - last_check < 300) return;
    last_check = current_time;
    
    // Create base analysis message
    string analysis = StringFormat(
        "\n=== Market Analysis [%s] ===\n"
        "Time: %s\n"
        "Symbol: %s\n"
        "Current Price: %.5f\n\n"
        "Trend Indicators:\n"
        "EMA(%d): %.5f\n"
        "EMA(%d): %.5f\n"
        "EMA(%d): %.5f\n"
        "ADX(%d): %.2f (DI+ %.2f, DI- %.2f)\n\n"
        "Momentum Indicators:\n"
        "RSI(%d): %.2f\n"
        "MACD: %.5f (Signal: %.5f, Hist: %.5f)\n"
        "ATR(14): %.5f\n\n",
        EnumToString(timeframe),
        TimeToString(current_time, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
        _Symbol,
        data.currentPrice,
        params.ema_period_short, data.ema_short,
        params.ema_period_medium, data.ema_medium,
        params.ema_period_long, data.ema_long,
        params.adx_period, data.adx, data.plusDI, data.minusDI,
        params.rsi_period, data.rsi,
        data.macdMain, data.macdSignal, data.macdHistogram,
        data.atr
    );
    
    // Add DOM analysis if enabled
    if (useDOMAnalysis)
    {
        MqlBookInfo book_info[];
        if (MarketBookGet(_Symbol, book_info))
        {
            double buyVolume = 0.0, sellVolume = 0.0;
            for (int i = 0; i < ArraySize(book_info); i++)
            {
                if (book_info[i].type == BOOK_TYPE_BUY)
                    buyVolume += book_info[i].volume;
                else if (book_info[i].type == BOOK_TYPE_SELL)
                    sellVolume += book_info[i].volume;
            }
            
            analysis += StringFormat(
                "Order Flow Analysis:\n"
                "Buy Volume: %.2f\n"
                "Sell Volume: %.2f\n"
                "Volume Ratio: %.2f\n\n",
                buyVolume,
                sellVolume,
                sellVolume > 0 ? buyVolume/sellVolume : 0
            );
        }
    }
    
    // Add signal analysis
    analysis += "Signal Analysis:\n";
    
    // Check trend conditions
    if (!(data.adx > params.trend_adx_threshold))
        analysis += "- ADX ("+DoubleToString(data.adx,1)+") below threshold ("+
                   DoubleToString(params.trend_adx_threshold,1)+")\n";
    
    // Check EMA alignment
    if (!(data.ema_short > data.ema_medium && data.ema_medium > data.ema_long) && 
        !(data.ema_short < data.ema_medium && data.ema_medium < data.ema_long))
        analysis += "- EMAs not properly aligned for trend\n";
    
    // Check RSI
    if (data.rsi > params.rsi_lower_threshold && data.rsi < params.rsi_upper_threshold)
        analysis += "- RSI ("+DoubleToString(data.rsi,1)+") in neutral zone ("+
                   DoubleToString(params.rsi_lower_threshold,1)+"-"+
                   DoubleToString(params.rsi_upper_threshold,1)+")\n";
    
    // Check MACD
    if (MathAbs(data.macdHistogram) < 0.0001)
        analysis += "- MACD histogram too small (weak momentum)\n";
    
    // Check DI lines
    if (MathAbs(data.plusDI - data.minusDI) < 5)
        analysis += "- DI+ and DI- too close (no clear direction)\n";
    
    // Check candlestick patterns
    if (data.bullishPattern)
        analysis += "- Bullish candlestick pattern detected\n";
    if (data.bearishPattern)
        analysis += "- Bearish candlestick pattern detected\n";
    
    analysis += "\nMarket Conditions:\n";
    analysis += "Trend Strength: " + (data.adx > params.trend_adx_threshold ? "Strong" : "Weak") + "\n";
    analysis += "Volatility: " + (data.atr > CalculateATR(14, timeframe, 20) ? "High" : "Normal") + "\n";
    analysis += "=====================\n";
    
    Print(analysis);
    
    // Write to file
    string filename = "MarketAnalysis_" + _Symbol + ".log";
    int filehandle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_ANSI);
    
    if(filehandle != INVALID_HANDLE)
    {
        FileSeek(filehandle, 0, SEEK_END);
        FileWriteString(filehandle, analysis);
        FileClose(filehandle);
    }
    else
    {
        Print("Failed to open market analysis log file: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Log Trade Rejection Reasons with Detailed Explanation            |
//+------------------------------------------------------------------+
void LogTradeRejection(const string reason, double currentPrice, double adx, double rsi, 
                      double emaShort, double emaMedium, double emaLong, 
                      double adxThreshold, double rsiUpperThreshold, double rsiLowerThreshold,
                      bool useDOMAnalysis)
{
    string log_message = StringFormat(
        "\n=== Trade Rejection Analysis [%s] ===\n"
        "Time: %s\n"
        "Symbol: %s\n\n"
        "Market Conditions:\n"
        "Current Price: %.5f\n"
        "ADX: %.2f\n"
        "RSI: %.2f\n"
        "EMA Short: %.5f\n"
        "EMA Medium: %.5f\n"
        "EMA Long: %.5f\n\n",
        __FUNCTION__,
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
        _Symbol,
        currentPrice,
        adx,
        rsi,
        emaShort,
        emaMedium,
        emaLong
    );

    // Add Trend Pattern Analysis
    log_message += "\nTrend Pattern Analysis:\n";
    
    // 1. EMA Analysis
    log_message += "EMA Analysis:\n";
    double emaGap = MathAbs(emaShort - emaMedium) / _Point;
    log_message += StringFormat("- EMA Gap: %.1f points\n", emaGap);
    
    if (emaShort > emaMedium && emaMedium > emaLong)
    {
        log_message += "- EMAs are in bullish alignment (Short > Medium > Long)\n";
        log_message += StringFormat("- Trend Strength: %.1f%%\n", (emaShort - emaLong) / emaLong * 100);
    }
    else if (emaShort < emaMedium && emaMedium < emaLong)
    {
        log_message += "- EMAs are in bearish alignment (Short < Medium < Long)\n";
        log_message += StringFormat("- Trend Strength: %.1f%%\n", (emaLong - emaShort) / emaLong * 100);
    }
    else
    {
        log_message += "- EMAs show no clear trend alignment\n";
    }

    // 2. Golden/Death Cross Analysis
    log_message += "\nCross Analysis:\n";
    if (MathAbs(emaMedium - emaLong) < 0.0001)
    {
        log_message += "- Potential Golden/Death Cross forming\n";
        log_message += StringFormat("- Cross Distance: %.5f\n", MathAbs(emaMedium - emaLong));
    }

    // 3. Momentum Analysis
    log_message += "\nMomentum Analysis:\n";
    log_message += StringFormat("- ADX: %.2f (Threshold: %.2f)\n", adx, adxThreshold);
    log_message += StringFormat("- RSI: %.2f (Upper: %.2f, Lower: %.2f)\n", rsi, rsiUpperThreshold, rsiLowerThreshold);

    // 4. Volume Analysis (if DOM is enabled)
    if (useDOMAnalysis)
    {
        MqlBookInfo book_info[];
        if (MarketBookGet(_Symbol, book_info))
        {
            double buyVolume = 0.0, sellVolume = 0.0;
            double buyValue = 0.0, sellValue = 0.0;
            
            for (int i = 0; i < ArraySize(book_info); i++)
            {
                if (book_info[i].type == BOOK_TYPE_BUY)
                {
                    buyVolume += book_info[i].volume;
                    buyValue += book_info[i].volume * book_info[i].price;
                }
                else if (book_info[i].type == BOOK_TYPE_SELL)
                {
                    sellVolume += book_info[i].volume;
                    sellValue += book_info[i].volume * book_info[i].price;
                }
            }
            
            log_message += "\nOrder Flow Analysis:\n";
            log_message += StringFormat("- Buy Volume: %.2f (Value: %.2f)\n", buyVolume, buyValue);
            log_message += StringFormat("- Sell Volume: %.2f (Value: %.2f)\n", sellVolume, sellValue);
            log_message += StringFormat("- Volume Imbalance: %.2f%%\n", 
                          ((buyVolume - sellVolume) / (buyVolume + sellVolume)) * 100);
            log_message += StringFormat("- Value Imbalance: %.2f%%\n",
                          ((buyValue - sellValue) / (buyValue + sellValue)) * 100);
        }
    }

    // 5. Pattern Recognition
    log_message += "\nPattern Recognition:\n";
    CandleData currentCandle = GetCandleData(0, PERIOD_CURRENT);
    CandleData prevCandle = GetCandleData(1, PERIOD_CURRENT);
    
    // Body/Wick Analysis
    double bodyToWickRatio = currentCandle.body / (currentCandle.upperWick + currentCandle.lowerWick + 0.000001);
    log_message += StringFormat("- Body/Wick Ratio: %.2f\n", bodyToWickRatio);
    
    // Candlestick Patterns
    if (currentCandle.body > prevCandle.body * 1.5)
        log_message += "- Strong momentum candle detected\n";
    if (currentCandle.upperWick > currentCandle.body * 2)
        log_message += "- Long upper wick indicates selling pressure\n";
    if (currentCandle.lowerWick > currentCandle.body * 2)
        log_message += "- Long lower wick indicates buying pressure\n";

    // Add conclusion
    log_message += "\nConclusion:\n";
    log_message += reason + "\n";
    log_message += "The trade setup does not meet all the required criteria for entry at this time.\n";
    log_message += "===================\n";

    // Print and save to file
    Print(log_message);
    
    string filename = "TradeRejection_" + _Symbol + ".log";
    int filehandle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_ANSI);
    
    if(filehandle != INVALID_HANDLE)
    {
        FileSeek(filehandle, 0, SEEK_END);
        FileWriteString(filehandle, log_message);
        FileClose(filehandle);
    }
    else
    {
        Print("Failed to open trade rejection log file: ", GetLastError());
    }
}

void LogPatternAnalysis(int bullishSignals, int bearishSignals, string symbol, ENUM_TIMEFRAMES timeframe, int threshold = 2)
{
    // Only log if the number of signals exceeds the threshold
    if (bullishSignals > threshold || bearishSignals > threshold)
    {
        string log_message = StringFormat(
            "%s (%s) Pattern Analysis - Bullish Signals: %d Bearish Signals: %d",
            symbol,
            EnumToString(timeframe),
            bullishSignals,
            bearishSignals
        );
        Print(log_message);
    }
}