#include <Trade/Trade.mqh>
//+------------------------------------------------------------------+
//| Global Variables and Constants                                    |
//+------------------------------------------------------------------+
// External parameters used across utility functions
input group "Utility Settings"
input double MinPriceChangeThreshold = 10;  // Minimum price change threshold (in points)

// Add these at the top of the file
class CUtilitySettings
{
public:
    // Trading Parameters
    ENUM_TIMEFRAMES Timeframe;
    int EMA_PERIODS_SHORT;
    int EMA_PERIODS_MEDIUM;
    int EMA_PERIODS_LONG;
    int RSI_Period;
    double RSI_Neutral;
    
    // Position Management
    bool UseTrailingStop;
    bool UseBreakeven;
    double TrailingStopPips;
    double BreakevenActivationPips;
    double BreakevenOffsetPips;
    
    // Indicator Parameters
    int MACD_Fast;
    int MACD_Slow;
    int MACD_Signal;
    
    // Constructor with default values
    CUtilitySettings()
    {
        Timeframe = PERIOD_H1;
        EMA_PERIODS_SHORT = 20;
        EMA_PERIODS_MEDIUM = 50;
        EMA_PERIODS_LONG = 200;
        RSI_Period = 14;
        RSI_Neutral = 50.0;
        UseTrailingStop = false;
        UseBreakeven = false;
        TrailingStopPips = 20.0;
        BreakevenActivationPips = 30.0;
        BreakevenOffsetPips = 5.0;
        MACD_Fast = 12;
        MACD_Slow = 26;
        MACD_Signal = 9;
    }
};

// Create a global instance
CUtilitySettings UtilitySettings;


// Add at the top with other global variables
input group "Symbol Settings"  // These should only be in the EA file
static string tradingSymbols[];           // Array to store trading symbols
static int symbolCount = 0;               // Number of symbols being traded
static datetime lastLotSizeCalcTimes[];   // Array to store last calculation time for each symbol
const int LOT_SIZE_CALC_INTERVAL = 60;    // Minimum seconds between lot size calculations

// Declare US market open and close times
const int US_MARKET_OPEN_HOUR = 16;    // 9 AM
const int US_MARKET_OPEN_MINUTE = 30; // 9:30 AM
const int US_MARKET_CLOSE_HOUR = 23;  // 4 PM
const int US_MARKET_CLOSE_MINUTE = 0; // 4:00 PM

// Define a simple LogMessage function
void LogGenericMessage(string message, string symbol)
{
    Print("Log: ", symbol, " - ", message);
}

CTrade tradeUtility;

// Function to set symbol count externally
void SetSymbolCount(int count)
{
    symbolCount = count;
}

// Function to add symbol to array
void AddTradingSymbol(string symbol, int index)
{
    if(index >= 0 && index < ArraySize(tradingSymbols))
    {
        tradingSymbols[index] = symbol;
    }
}

//+------------------------------------------------------------------+
//| Get index of symbol in trading symbols array                     |
//+------------------------------------------------------------------+
int GetSymbolIndex(string symbol)
{
    for(int i = 0; i < symbolCount; i++)
    {
        if(tradingSymbols[i] == symbol)
            return i;
    }
    return -1;  // Symbol not found
}

//+------------------------------------------------------------------+
//| Initialize lot size calculation times                            |
//+------------------------------------------------------------------+
void InitializeLotSizeCalcTimes()
{
    ArrayResize(lastLotSizeCalcTimes, symbolCount);
    datetime currentTime = TimeCurrent();
    
    for(int i = 0; i < symbolCount; i++)
    {
        lastLotSizeCalcTimes[i] = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Helper function to get indicator value                           |
//+------------------------------------------------------------------+
double GetIndicatorValue(string symbol, int handle, int bufferIndex, int shift = 0)
{
    double value[];
    if (handle == INVALID_HANDLE)
    {
        Print("Invalid indicator handle for symbol ", symbol);
        return 0;
    }

    if (CopyBuffer(handle, bufferIndex, shift, 1, value) > 0)
    {
        return value[0];
    }
    else
    {
        int error = GetLastError();
        Print("Error copying data from indicator handle for symbol ", symbol, ": ", error);
        ResetLastError();
        return 0;
    }
}

//+------------------------------------------------------------------+
//| Indicator Calculation Functions                                  |
//+------------------------------------------------------------------+
double CalculateSMA(string symbol, int period, ENUM_TIMEFRAMES timeframe, int shift = 0)
{
    if (!IsValidTimeframe(timeframe)) return 0;
    
    int handle = iMA(symbol, timeframe, period, 0, MODE_SMA, PRICE_CLOSE);
    if (handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("Failed to create SMA indicator handle for symbol ", symbol, ": ", error);
        ResetLastError();
        return 0;
    }
    double value = GetIndicatorValue(symbol, handle, 0, shift);
    IndicatorRelease(handle);
    return value;
}

double CalculateEMA(string symbol, int period, ENUM_TIMEFRAMES timeframe, int shift = 0)
{
    if (!IsValidTimeframe(timeframe)) return 0;
    
    // Use the appropriate EMA period from UtilitySettings based on input
    int emaPeriod;
    if (period == UtilitySettings.EMA_PERIODS_SHORT)
        emaPeriod = UtilitySettings.EMA_PERIODS_SHORT;
    else if (period == UtilitySettings.EMA_PERIODS_MEDIUM)
        emaPeriod = UtilitySettings.EMA_PERIODS_MEDIUM;
    else if (period == UtilitySettings.EMA_PERIODS_LONG)
        emaPeriod = UtilitySettings.EMA_PERIODS_LONG;
    else
        emaPeriod = period;  // Use provided period if it doesn't match any standard ones
    
    int handle = iMA(symbol, timeframe, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if (handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("Failed to create EMA indicator handle for symbol ", symbol, ": ", error);
        ResetLastError();
        return 0;
    }
    double value = GetIndicatorValue(symbol, handle, 0, shift);
    IndicatorRelease(handle);
    return value;
}

double CalculateRSI(string symbol, int period, ENUM_TIMEFRAMES timeframe, int shift = 0)
{
    if (!IsValidTimeframe(timeframe)) return 0;
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    
    int handle = iRSI(symbol, timeframe, UtilitySettings.RSI_Period, PRICE_CLOSE);
    if (handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("Failed to create RSI indicator handle for symbol ", symbol, ": ", error);
        ResetLastError();
        return 0;
    }
    if (CopyBuffer(handle, 0, shift, 1, rsi) <= 0)
    {
        Print("Error copying RSI data: ", GetLastError());
        return 0;
    }
    IndicatorRelease(handle);
    return rsi[0];
}

double CalculateATR(string symbol, int period, ENUM_TIMEFRAMES timeframe, int shift = 0)
{
    if (!IsValidTimeframe(timeframe)) return 0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    
    int handle = iATR(symbol, timeframe, period);
    if(handle == INVALID_HANDLE)
    {
        Print("Error creating ATR indicator: ", GetLastError());
        return -1;
    }
    
    if(CopyBuffer(handle, 0, shift, 1, atr) <= 0)
    {
        Print("Error copying ATR data: ", GetLastError());
        return -1;
    }
    
    IndicatorRelease(handle);
    return atr[0];
}

//+------------------------------------------------------------------+
//| Calculate ADX, +DI, and -DI                                      |
//+------------------------------------------------------------------+
void CalculateADX(string symbol, int period, ENUM_TIMEFRAMES timeframe, double &adx, double &plusDI, double &minusDI)
{
    if (!IsValidTimeframe(timeframe)) return;
    
    int handle = iADX(symbol, timeframe, period);
    if (handle == INVALID_HANDLE)
    {
        Print("Failed to create ADX handle for symbol ", symbol);
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
//| Enhanced and Renamed to Avoid Function Overloading               |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(
    string symbol,
    double stop_loss_pips,  // Already in correct units (e.g., 1 pip = 1 price unit)
    double accountBalance,  // Current account balance
    double riskPercent,     // e.g., 2.0 for 2%
    double minVolume,       // Minimum allowed volume
    double maxVolume        // Maximum allowed volume
)
{
    // Validate Inputs
    if (stop_loss_pips <= 0)
    {
        Print("Error: Invalid stop loss pips (", stop_loss_pips, ") for symbol ", symbol);
        return minVolume;
    }

    if (accountBalance <= 0)
    {
        Print("Error: Invalid account balance (", accountBalance, ") for symbol ", symbol);
        return minVolume;
    }

    if (riskPercent <= 0 || riskPercent > 100)
    {
        Print("Error: Invalid risk percent (", riskPercent, ") for symbol ", symbol);
        return minVolume;
    }

    // Retrieve Symbol Properties
    double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

    if (tick_value <= 0 || tick_size <= 0 || lot_step <= 0)
    {
        string error = StringFormat("Invalid symbol properties - Tick Value: %.5f, Tick Size: %.5f, Lot Step: %.5f for symbol %s",
                                    tick_value, tick_size, lot_step, symbol);
        Print(error);
        return minVolume;
    }

    // Calculate Pip Value
    // For most indices like US500, 1 pip is typically 1 point. Adjust if different.
    double pip_value = tick_value; // Assuming 1 pip = 1 point

    // Calculate Intended Monetary Risk
    double risk_amount = accountBalance * (riskPercent / 100.0);

    // Calculate Lot Size
    double lot_size = risk_amount / (stop_loss_pips * pip_value);

    // Round to Nearest Lot Step
    lot_size = MathFloor(lot_size / lot_step) * lot_step;

    // Ensure Lot Size is Within Allowed Range
    lot_size = MathMax(lot_size, minVolume);
    lot_size = MathMin(lot_size, maxVolume);

    // Normalize Lot Size to Allowed Decimal Places
    int volume_step_digits = GetVolumeStepDigits(lot_step);
    lot_size = NormalizeDouble(lot_size, volume_step_digits);

    // Calculate Actual Monetary Risk
    double actual_risk = lot_size * stop_loss_pips * pip_value;

    // Comprehensive Debug Logging
    Print(
        "=== CalculateDynamicLotSizeNew Debug ===\n",
        "Symbol: ", symbol, "\n",
        "Account Balance: ", accountBalance, "\n",
        "Risk Percent: ", riskPercent, "%\n",
        "Intended Monetary Risk: ", risk_amount, "\n",
        "Stop Loss Pips: ", stop_loss_pips, "\n",
        "Tick Value: ", tick_value, "\n",
        "Tick Size: ", tick_size, "\n",
        "Lot Step: ", lot_step, "\n",
        "Digits: ", digits, "\n",
        "Pip Value: ", pip_value, "\n",
        "Calculated Lot Size (Pre-Round): ", (risk_amount / (stop_loss_pips * pip_value)), "\n",
        "Calculated Lot Size (Rounded): ", lot_size, "\n",
        "Actual Monetary Risk: ", actual_risk, "\n",
        "=============================="
    );

    return lot_size;
}



//+------------------------------------------------------------------+
//| Check Drawdown and Halt Trading if Necessary                     |
//+------------------------------------------------------------------+
bool CheckDrawdown(string symbol, double maxDrawdownPercent, double accountBalance, double accountEquity)
{
    if (accountBalance == 0.0) accountBalance = 0.0001;
    
    double drawdown_percent = ((accountBalance - accountEquity) / accountBalance) * 100.0;
    
    // Only log if drawdown is significant
    if (drawdown_percent >= maxDrawdownPercent)
    {
        Print("ALERT: Maximum Drawdown Reached for ", symbol, ": ", drawdown_percent, "% - Trading Halted");
        return true;
    }
    else if (drawdown_percent >= maxDrawdownPercent * 0.8) // Only log when approaching max drawdown
    {
        Print("WARNING: Significant Drawdown for ", symbol, ": ", drawdown_percent, "% - Approaching Limit");
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Dynamic SL/TP Levels Based on ATR                      |
//+------------------------------------------------------------------+
void CalculateDynamicSLTP(string symbol, double &stop_loss, double &take_profit, double atr_multiplier, ENUM_TIMEFRAMES timeframe, double inFixedStopLossPips)
{
    double atr = CalculateATR(symbol, 14, timeframe);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if (point <= 0)
    {
        Print("Error: Invalid point value for symbol ", symbol);
        return;
    }

    if (atr <= 0)
    {
        Print("ATR calculation failed or returned zero for ", symbol, ". Using default SL/TP values.");
        stop_loss = inFixedStopLossPips * point;
        take_profit = 40 * point;
        return;
    }

    double dynamicStopLoss = atr * atr_multiplier;
    stop_loss = MathMax(dynamicStopLoss, inFixedStopLossPips * point);
    take_profit = atr * atr_multiplier * 2.0;

    // Use the new logging function
    LogDynamicSLTP(stop_loss, take_profit, symbol, timeframe);
}

//+------------------------------------------------------------------+
//| Log Dynamic SL/TP values with reduced noise                      |
//+------------------------------------------------------------------+
void LogDynamicSLTP(double stopLoss, double takeProfit, string symbol, ENUM_TIMEFRAMES timeframe)
{
    static datetime utilityLastLogTime = 0;
    static datetime utilityLastCalculationTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Prevent division by zero
    if (utilityLastLogTime == 0) utilityLastLogTime = (datetime)stopLoss;
    if (utilityLastCalculationTime == 0) utilityLastCalculationTime = currentTime;
    
    // Only log if SL/TP changed by more than 1% or after 5 minutes
    if (MathAbs(stopLoss - utilityLastLogTime)/utilityLastLogTime > 0.01 || 
        MathAbs(takeProfit - utilityLastCalculationTime)/utilityLastCalculationTime > 0.01 || 
        currentTime - utilityLastCalculationTime >= 300)
    {
        Print(symbol, ",", EnumToString(timeframe), " Dynamic SL: ", stopLoss, " | Dynamic TP: ", takeProfit);
        utilityLastLogTime = (datetime)stopLoss;
        utilityLastCalculationTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Log DI Difference values with reduced noise                      |
//+------------------------------------------------------------------+
void LogDIDifference(double diDifference, double threshold, string symbol, ENUM_TIMEFRAMES timeframe)
{
    static double lastDIDifference = 0;
    static datetime utilityLastLogTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Only log if the difference has changed by more than 0.5 or after 5 minutes
    if (MathAbs(diDifference - lastDIDifference) > 0.5 || currentTime - utilityLastLogTime >= 300)
    {
        Print(StringFormat("%s,%s DI Difference: %f (Threshold: %f)", 
              symbol, EnumToString(timeframe), diDifference, threshold));
        lastDIDifference = diDifference;
        utilityLastLogTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Log Trade Details                                                |
//+------------------------------------------------------------------+
void LogTradeDetails(string symbol, double lot_size, double stop_loss, double take_profit)
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
        symbol,
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
    string filename = "QuantumTraderAI_" + symbol + ".log";
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
bool IsWithinTradingHours(int startHour, int startMinute, int endHour, int endMinute)
{
    datetime serverTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(serverTime, dt);
    
    // Convert current time, start time, and end time to minutes since midnight
    int currentMinutes = dt.hour * 60 + dt.min;
    int startMinutes = startHour * 60 + startMinute;
    int endMinutes = endHour * 60 + endMinute;
    
    // Check if the trading hours cross midnight
    if (startMinutes > endMinutes)
    {
        // If current time is after start time or before end time
        return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
    }
    else
    {
        // Normal case where start time is before end time
        return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
    }
}

//+------------------------------------------------------------------+
//| Check for Pending Orders                                         |
//+------------------------------------------------------------------+
bool HasPendingOrder(string symbol, int type)
{
    int total = OrdersTotal();
    for (int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if (OrderSelect(ticket))
        {
            if (OrderGetInteger(ORDER_TYPE) == type && OrderGetString(ORDER_SYMBOL) == symbol)
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
CandleData GetCandleData(string symbol, int shift, ENUM_TIMEFRAMES timeframe)
{
    CandleData candle;
    
    candle.open = iOpen(symbol, timeframe, shift);
    candle.high = iHigh(symbol, timeframe, shift);
    candle.low = iLow(symbol, timeframe, shift);
    candle.close = iClose(symbol, timeframe, shift);
    
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
int CountOrders(string symbol, int type)
{
    int count = 0;
    int total = PositionsTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_TYPE) == type && 
               PositionGetString(POSITION_SYMBOL) == symbol)
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
bool HasActiveTradeOrPendingOrder(string symbol, int type)
{
    // Check positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
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
            if(OrderGetString(ORDER_SYMBOL) == symbol)
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
double GetBestLimitOrderPrice(string symbol, ENUM_ORDER_TYPE orderType, double &tpPrice, double &slPrice, 
                            double liquidityThreshold, double takeProfitPips, double stopLossPips)
{
    MqlBookInfo book_info[];
    
    // Get market depth data
    if (!MarketBookGet(symbol, book_info))
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
    
    double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double spread = currentAsk - currentBid;
    double atr = CalculateATR(symbol, 14, PERIOD_CURRENT, 0);
    
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
void LogMarketAnalysis(const string symbol, const MarketAnalysisData& data, 
                      const MarketAnalysisParameters& params,
                      ENUM_TIMEFRAMES timeframe,
                      bool useDOMAnalysis)
{
    static datetime utilityLastLogTime = 0;
    datetime current_time = TimeCurrent();
    
    // Check every 5 minutes (300 seconds)
    if (current_time - utilityLastLogTime < 300) return;
    utilityLastLogTime = current_time;
    
    // Create base analysis message with emoji delimiter
    string analysis = StringFormat(
        "\n=== 📈 Trend Pattern Analysis for %s (Timeframe: %s) ===\n"  // Added symbol here
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
        symbol,  // Added symbol here
        EnumToString(timeframe),
        TimeToString(current_time, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
        symbol,
        data.currentPrice,
        params.ema_period_short, data.ema_short,
        params.ema_period_medium, data.ema_medium,
        params.ema_period_long, data.ema_long,
        params.adx_period, data.adx, data.plusDI, data.minusDI,
        params.rsi_period, data.rsi,
        data.macdMain, data.macdSignal, data.macdHistogram,
        data.atr
    );

    // Add ending delimiter
    analysis += "\n=== 📈 End of Trend Pattern Analysis ===\n";
    
    // Add DOM analysis if enabled
    if (useDOMAnalysis)
    {
        MqlBookInfo book_info[];
        if (MarketBookGet(symbol, book_info))
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
    string filename = "MarketAnalysis_" + symbol + ".log";
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
void LogTradeRejection(const string reason, string symbol, double currentPrice, double adx, double rsi, 
                      double emaShort, double emaMedium, double emaLong, 
                      double adxThreshold, double rsiUpperThreshold, double rsiLowerThreshold,
                      bool useDOMAnalysis, ENUM_TIMEFRAMES timeframe)
{
    string log_message = StringFormat(
        "\n=== ❌ Trade Rejection Analysis [%s] ===\n"
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
        symbol,  // Log the symbol
        currentPrice,
        adx,
        rsi,
        emaShort,
        emaMedium,
        emaLong
    );

    log_message += StringFormat("\n=== ❌ Trend Pattern Analysis (Timeframe: %s) ===\n", EnumToString(timeframe));
    
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
        if (MarketBookGet(symbol, book_info))
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
    CandleData currentCandle;
    currentCandle = GetCandleData(symbol, 0, PERIOD_CURRENT);
    CandleData prevCandle;
    prevCandle = GetCandleData(symbol, 1, PERIOD_CURRENT);
    
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

    // Add ending delimiter
    log_message += "\n=== ❌ End of Trade Rejection Analysis ===\n";  // Good end delimiter

    // Print and save to file
    Print(log_message);
    
    string filename = "TradeRejection_" + symbol + ".log";
    int filehandle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_ANSI);
    
    if(filehandle != INVALID_HANDLE)
    {
        FileSeek(filehandle, 0, SEEK_END);
        bool writeSuccess = FileWriteString(filehandle, log_message);
        if(!writeSuccess)
        {
            Print("Failed to write to log file. Error: ", GetLastError());
        }
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

//+------------------------------------------------------------------+
//| Validate timeframe parameter                                     |
//+------------------------------------------------------------------+
bool IsValidTimeframe(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_M1:
        case PERIOD_M5:
        case PERIOD_M15:
        case PERIOD_M30:
        case PERIOD_H1:
        case PERIOD_H4:
        case PERIOD_D1:
        case PERIOD_W1:
        case PERIOD_MN1:
            return true;
        default:
            Print("Invalid timeframe parameter: ", EnumToString(timeframe));
            return false;
    }
}

//+------------------------------------------------------------------+
//| Apply Breakeven                                                  |
//+------------------------------------------------------------------+
void ApplyBreakeven(string symbol, ulong ticket, int type, double open_price, double stop_loss, 
                   double breakeven_level, double breakeven_offset, double min_price_change)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if (point <= 0)
    {
        Print("Error: Invalid point value for symbol ", symbol);
        return;
    }

    static datetime lastModificationTime = 0;
    datetime currentTime = TimeCurrent();

    if (type == POSITION_TYPE_BUY)
    {
        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        if (price - open_price >= breakeven_level)
        {
            double new_stop_loss = open_price + breakeven_offset;
            if (stop_loss < new_stop_loss)
            {
                if (MathAbs(price - stop_loss) >= min_price_change)
                {
                    if (tradeUtility.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP)))
                    {
                        lastModificationTime = currentTime;
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
                if (MathAbs(price - stop_loss) >= min_price_change)
                {
                    if (tradeUtility.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP)))
                    {
                        lastModificationTime = currentTime;
                        Print("Breakeven Activated for Sell Position ", ticket);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(string symbol, ulong ticket, int type, double open_price, double stop_loss,
                      double trailing_stop_pips, double min_price_change)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if (point <= 0)
    {
        Print("Error: Invalid point value for symbol ", symbol);
        return;
    }

    static datetime lastModificationTime = 0;
    datetime currentTime = TimeCurrent();
    double trailing_stop = trailing_stop_pips * point;

    if (type == POSITION_TYPE_BUY)
    {
        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        double new_stop_loss = price - trailing_stop;

        if (new_stop_loss > stop_loss)
        {
            if (MathAbs(price - stop_loss) >= min_price_change)
            {
                if (tradeUtility.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP)))
                {
                    lastModificationTime = currentTime;
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
            if (MathAbs(price - stop_loss) >= min_price_change)
            {
                if (tradeUtility.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP)))
                {
                    lastModificationTime = currentTime;
                    Print("Trailing Stop Updated for Sell Position ", ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Place Buy Limit Order                                            |
//+------------------------------------------------------------------+
void PlaceBuyLimitOrder(string symbol, double limitPrice, double riskPercent)
{
    if (!ManagePositions(symbol, POSITION_TYPE_BUY) && !HasPendingOrder(symbol, ORDER_TYPE_BUY_LIMIT))
    {
        double stop_loss, take_profit;
        CalculateDynamicSLTP(symbol, stop_loss, take_profit, 1.5, UtilitySettings.Timeframe, 20); // Example ATR multiplier and fixed SL

        double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double lot_size = CalculateDynamicLotSize(
            symbol,                          // symbol
            (stop_loss / _Point),            // stop_loss_pips
            accountBalance,                  // accountBalance
            riskPercent,                     // riskPercent
            minVolume,                       // minVolume
            maxVolume                        // maxVolume
        );

        double tpPrice = limitPrice + take_profit;
        double slPrice = limitPrice - stop_loss;

        if (tradeUtility.BuyLimit(lot_size, limitPrice, symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, "Buy Limit Order"))
        {
            LogTradeDetails(symbol, lot_size, slPrice, tpPrice);
            Print("🚀🚀 Buy Limit Order Placed - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
            Print("  ____  _     _     _ _ _   _ _ _ ");
            Print(" |  _ \\| |__ (_) __| (_) |_(_) | |");
            Print(" | |_) | '_ \\| |/ _` | | __| | | |");
            Print(" |  __/| | | | | (_| | | |_| | | |");
            Print(" |_|   |_| |_|_|\\__,_|_|\\__|_|_|_|");
        }
        else
        {
            int error = GetLastError();
            Print("Buy Limit Order Failed with Error: ", error);
            ResetLastError();
        }
    }
    else
    {
        Print("Buy Limit Order not placed - Duplicate order or active position exists.");
    }
}

//+------------------------------------------------------------------+
//| Place Sell Limit Order                                           |
//+------------------------------------------------------------------+
void PlaceSellLimitOrder(string symbol, double limitPrice, double riskPercent)
{
    if (!ManagePositions(symbol, POSITION_TYPE_SELL) && !HasPendingOrder(symbol, ORDER_TYPE_SELL_LIMIT))
    {
        double stop_loss, take_profit;
        CalculateDynamicSLTP(symbol, stop_loss, take_profit, 1.5, UtilitySettings.Timeframe, 20); // Example ATR multiplier and fixed SL

        double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double lot_size = CalculateDynamicLotSize(
            symbol,                          // symbol
            (stop_loss / _Point),            // stop_loss_pips
            accountBalance,                  // accountBalance
            riskPercent,                     // riskPercent
            minVolume,                       // minVolume
            maxVolume                        // maxVolume
        );

        double tpPrice = limitPrice - take_profit;
        double slPrice = limitPrice + stop_loss;

        if (tradeUtility.SellLimit(lot_size, limitPrice, symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, "Sell Limit Order"))
        {
            LogTradeDetails(symbol, lot_size, slPrice, tpPrice);
            Print("🔻🔻 Sell Limit Order Placed - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
            Print("  ____  _     _     _ _ _   _ _ _ ");
            Print(" |  _ \\| |__ (_) __| (_) |_(_) | |");
            Print(" | |_) | '_ \\| |/ _` | | __| | | |");
            Print(" |  __/| | | | | (_| | | |_| | | |");
            Print(" |_|   |_| |_|_|\\__,_|_|\\__|_|_|_|");
        }
        else
        {
            int error = GetLastError();
            Print("Sell Limit Order Failed with Error: ", error);
            ResetLastError();
        }
    }
    else
    {
        Print("Sell Limit Order not placed - Duplicate order or active position exists.");
    }
}

//+------------------------------------------------------------------+
//| Order Placement Functions                                        |
//+------------------------------------------------------------------+
void PlaceBuyOrder(string symbol, double riskPercent, double atrMultiplier, 
                   ENUM_TIMEFRAMES timeframe, double fixedStopLossPips)
{
    double stop_loss, take_profit;
    CalculateDynamicSLTP(symbol, stop_loss, take_profit, atrMultiplier, timeframe, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(
        symbol,                          // symbol
        stop_loss / _Point,             // stop_loss_pips
        accountBalance,                  // accountBalance
        riskPercent,                    // riskPercent
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

    if (tradeUtility.BuyLimit(lot_size, limit_price, symbol, sl, tp, ORDER_TIME_GTC, 0, "Buy Limit Order with Dynamic SL/TP"))
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

void PlaceSellOrder(string symbol, double riskPercent, double atrMultiplier, 
                    ENUM_TIMEFRAMES timeframe, double fixedStopLossPips)
{
    double stop_loss, take_profit;
    CalculateDynamicSLTP(symbol, stop_loss, take_profit, atrMultiplier, timeframe, fixedStopLossPips);

    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_size = CalculateDynamicLotSize(
        symbol,                          // symbol
        stop_loss / _Point,             // stop_loss_pips
        accountBalance,                  // accountBalance
        riskPercent,                    // riskPercent
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

    if (tradeUtility.SellLimit(lot_size, limit_price, symbol, sl, tp, ORDER_TIME_GTC, 0, "Sell Limit Order with Dynamic SL/TP"))
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
//| Signal Processing Functions                                      |
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
    double macd_main_values[];  // Added to store MACD main values
    double macd_signal_values[]; // Added to store MACD signal values
    
    // Initialize arrays
    ArrayResize(ema_short_values, requiredBars);
    ArrayResize(ema_medium_values, requiredBars);
    ArrayResize(ema_long_values, requiredBars);
    ArrayResize(macd_histogram_values, requiredBars);
    ArrayResize(rsi_values, requiredBars);
    ArrayResize(macd_main_values, requiredBars);  // Initialize MACD main array
    ArrayResize(macd_signal_values, requiredBars); // Initialize MACD signal array
    
    // Get historical values for all indicators
    for(int i = 1; i <= requiredBars; i++)
    {
        ema_short_values[i-1] = CalculateEMA(symbol, UtilitySettings.EMA_PERIODS_SHORT, UtilitySettings.Timeframe, i);
        ema_medium_values[i-1] = CalculateEMA(symbol, UtilitySettings.EMA_PERIODS_MEDIUM, UtilitySettings.Timeframe, i);
        ema_long_values[i-1] = CalculateEMA(symbol, UtilitySettings.EMA_PERIODS_LONG, UtilitySettings.Timeframe, i);
        
        double macdMain, macdSignal, macdHistogram;
        CalculateMACD(symbol, macdMain, macdSignal, macdHistogram, i, UtilitySettings.Timeframe);
        macd_histogram_values[i-1] = macdHistogram;
        macd_main_values[i-1] = macdMain;  // Store MACD main value
        macd_signal_values[i-1] = macdSignal; // Store MACD signal value
        
        rsi_values[i-1] = CalculateRSI(symbol, UtilitySettings.RSI_Period, UtilitySettings.Timeframe, i);
    }
    
    int confirmedBars = 0; // Count of confirmed bars in a row
    
    for(int i = 0; i < requiredBars; i++)
    {
        bool signalConfirmed = false;
        
        if(isBuySignal)
        {
            // Check for upward slopes instead of strict alignment
            bool shortEmaSlopingUp  = (i < requiredBars - 1) && (ema_short_values[i] > ema_short_values[i + 1]);
            bool mediumEmaSlopingUp = (i < requiredBars - 1) && (ema_medium_values[i] > ema_medium_values[i + 1]);
            bool longEmaSlopingUp   = (i < requiredBars - 1) && (ema_long_values[i] > ema_long_values[i + 1]);
            
            bool macdAboveSignalLine = (macd_main_values[i] > macd_signal_values[i]); // Check if MACD main is above signal
            bool macdSlope = (i > 0) ? (macd_main_values[i] > macd_main_values[i-1]) : true; // Check slope if not the first bar
            bool rsiSupport = (rsi_values[i] > UtilitySettings.RSI_Neutral);
            
            signalConfirmed = (shortEmaSlopingUp && mediumEmaSlopingUp && longEmaSlopingUp && macdAboveSignalLine && macdSlope && rsiSupport);
        }
        else
        {
            bool emaAligned = (ema_short_values[i] < ema_medium_values[i] && 
                             ema_medium_values[i] < ema_long_values[i]);
            bool macdNegative = (macd_histogram_values[i] < 0);
            bool rsiSupport = (rsi_values[i] < UtilitySettings.RSI_Neutral);
            
            signalConfirmed = (emaAligned && macdNegative && rsiSupport);
        }
        
        if(signalConfirmed)
        {
            confirmedBars++; // Increment confirmed bars count
            if (confirmedBars >= requiredBars) // Check if we have enough confirmed bars
            {
                return true; // Return true if we have enough confirmed bars
            }
        }
        else
        {
            confirmedBars = 0; // Reset count if a bar fails
        }
    }
    
    return false; // Return false if not enough confirmed bars found
}

//+------------------------------------------------------------------+
//| Check for Bullish Candle Pattern                                |
//+------------------------------------------------------------------+
bool IsBullishCandlePattern(string symbol)
{
    CandleData current, previous;
    current = GetCandleData(symbol, 1, UtilitySettings.Timeframe);
    previous = GetCandleData(symbol, 2, UtilitySettings.Timeframe);
    
    double avgCandleSize = 0;
    double avgVolume = 0;
    for(int i = 1; i <= 10; i++)
    {
        CandleData temp = GetCandleData(symbol, i, UtilitySettings.Timeframe);
        avgCandleSize += temp.body;
        avgVolume += iVolume(symbol, UtilitySettings.Timeframe, i);
    }
    avgCandleSize /= 10;
    avgVolume /= 10;
    
    bool isStrongBullishEngulfing = 
        current.isBullish &&
        !previous.isBullish &&
        current.open < previous.close &&
        current.close > previous.open &&
        current.body > previous.body * 1.5 &&
        current.body > avgCandleSize * 1.2 &&
        iVolume(symbol, UtilitySettings.Timeframe, 1) > avgVolume * 1.5;
    
    CandleData twoDaysAgo = GetCandleData(symbol, 3, UtilitySettings.Timeframe);
    bool isPerfectMorningStar =
        !twoDaysAgo.isBullish &&
        current.isBullish &&
        previous.body < avgCandleSize * 0.3 &&
        twoDaysAgo.body > avgCandleSize * 1.2 &&
        current.body > avgCandleSize * 1.2 &&
        current.close > twoDaysAgo.open &&
        iVolume(symbol, UtilitySettings.Timeframe, 1) > avgVolume * 1.5;
    
    bool isClearHammer = 
        current.isBullish &&
        current.lowerWick > current.body * 3 &&
        current.upperWick < current.body * 0.1 &&
        current.body > avgCandleSize * 0.8 &&
        current.low < previous.low &&
        iVolume(symbol, UtilitySettings.Timeframe, 1) > avgVolume * 1.5;
    
    return (isStrongBullishEngulfing || isPerfectMorningStar || isClearHammer);
}

//+------------------------------------------------------------------+
//| Check for Bearish Candle Pattern                                |
//+------------------------------------------------------------------+
bool IsBearishCandlePattern(string symbol)
{
    CandleData current, previous;
    current = GetCandleData(symbol, 1, UtilitySettings.Timeframe);
    previous = GetCandleData(symbol, 2, UtilitySettings.Timeframe);
    
    double avgCandleSize = 0;
    double avgVolume = 0;
    for(int i = 1; i <= 10; i++)
    {
        CandleData temp = GetCandleData(symbol, i, UtilitySettings.Timeframe);
        avgCandleSize += temp.body;
        avgVolume += iVolume(symbol, UtilitySettings.Timeframe, i);
    }
    avgCandleSize /= 10;
    avgVolume /= 10;
    
    bool isStrongBearishEngulfing = 
        !current.isBullish &&
        previous.isBullish &&
        current.open > previous.close &&
        current.close < previous.open &&
        current.body > previous.body * 1.5 &&
        current.body > avgCandleSize * 1.2 &&
        iVolume(symbol, UtilitySettings.Timeframe, 1) > avgVolume * 1.5;
    
    CandleData twoDaysAgo = GetCandleData(symbol, 3, UtilitySettings.Timeframe);
    bool isPerfectEveningStar =
        twoDaysAgo.isBullish &&
        !current.isBullish &&
        previous.body < avgCandleSize * 0.3 &&
        twoDaysAgo.body > avgCandleSize * 1.2 &&
        current.body > avgCandleSize * 1.2 &&
        current.close < twoDaysAgo.open &&
        iVolume(symbol, UtilitySettings.Timeframe, 1) > avgVolume * 1.5;
    
    bool isClearShootingStar = 
        !current.isBullish &&
        current.upperWick > current.body * 3 &&
        current.lowerWick < current.body * 0.1 &&
        current.body > avgCandleSize * 0.8 &&
        current.high > previous.high &&
        iVolume(symbol, UtilitySettings.Timeframe, 1) > avgVolume * 1.5;
    
    return (isStrongBearishEngulfing || isPerfectEveningStar || isClearShootingStar);
}

//+------------------------------------------------------------------+
//| Manage Positions                                                 |
//+------------------------------------------------------------------+
bool ManagePositions(string symbol, int checkType = -1)
{
    bool hasPosition = false;
    int total = PositionsTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            if(posSymbol != symbol) continue;
            
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            if(checkType != -1 && posType != checkType) continue;
            
            hasPosition = true;
            
            if(UtilitySettings.UseTrailingStop || UtilitySettings.UseBreakeven)
            {
                double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
                double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
                double stop_loss = PositionGetDouble(POSITION_SL);
                
                if(UtilitySettings.UseTrailingStop)
                    ApplyTrailingStop(symbol, ticket, posType, open_price, stop_loss, UtilitySettings.TrailingStopPips, MinPriceChangeThreshold);
                if(UtilitySettings.UseBreakeven)
                    ApplyBreakeven(symbol, ticket, posType, open_price, current_price, 
                                 UtilitySettings.BreakevenActivationPips * _Point,
                                 UtilitySettings.BreakevenOffsetPips * _Point,
                                 MinPriceChangeThreshold * _Point);
            }
        }
    }
    
    return hasPosition;
}

//+------------------------------------------------------------------+
//| Calculate MACD Values                                            |
//+------------------------------------------------------------------+
void CalculateMACD(string symbol, double &macdMain, double &macdSignal, double &macdHistogram, int shift, ENUM_TIMEFRAMES timeframe)
{
    if (!IsValidTimeframe(timeframe)) return;
    
    int handle = iMACD(symbol, timeframe, 
                      UtilitySettings.MACD_Fast,    // Fast EMA period
                      UtilitySettings.MACD_Slow,    // Slow EMA period
                      UtilitySettings.MACD_Signal,  // Signal period
                      PRICE_CLOSE);
                      
    if (handle == INVALID_HANDLE)
    {
        Print("Failed to create MACD handle for symbol ", symbol);
        return;
    }

    double macdBuffer[];
    double signalBuffer[];
    double histogramBuffer[];
    
    ArraySetAsSeries(macdBuffer, true);
    ArraySetAsSeries(signalBuffer, true);
    ArraySetAsSeries(histogramBuffer, true);
    
    if (CopyBuffer(handle, 0, shift, 1, macdBuffer) > 0 &&
        CopyBuffer(handle, 1, shift, 1, signalBuffer) > 0 &&
        CopyBuffer(handle, 2, shift, 1, histogramBuffer) > 0)
    {
        macdMain = macdBuffer[0];
        macdSignal = signalBuffer[0];
        macdHistogram = histogramBuffer[0];
    }
    
    IndicatorRelease(handle);
}
//+------------------------------------------------------------------+
//| Calculate Dynamic RSI Thresholds                                 |
//+------------------------------------------------------------------+
void GetDynamicRSIThresholds(string symbol, ENUM_TIMEFRAMES timeframe, double rsiUpperThreshold, double rsiLowerThreshold, double &upper_threshold, double &lower_threshold)
{
    double atr = CalculateATR(symbol, 14, timeframe);
    double avg_atr = 0;
    
    // Calculate average ATR for last 20 periods
    for(int i = 0; i < 20; i++)
    {
        avg_atr += CalculateATR(symbol, 14, timeframe, i);
    }
    avg_atr /= 20;
    
    // Adjust thresholds based on relative volatility
    double volatility_factor = atr / avg_atr;
    
    // More volatile market = wider thresholds
    upper_threshold = rsiUpperThreshold + (volatility_factor - 1) * 10;
    lower_threshold = rsiLowerThreshold - (volatility_factor - 1) * 10;
    
    // Keep thresholds within reasonable bounds
    upper_threshold = MathMin(MathMax(upper_threshold, 65), 85);
    lower_threshold = MathMax(MathMin(lower_threshold, 35), 15);
}

//+------------------------------------------------------------------+
//| Check for RSI Divergence                                         |
//+------------------------------------------------------------------+
bool CheckRSIDivergence(string symbol, ENUM_TIMEFRAMES timeframe, int rsiPeriod, int lookback, bool &bullish, bool &bearish)
{
    double rsi_values[];
    double price_values[];
    ArrayResize(rsi_values, lookback);
    ArrayResize(price_values, lookback);
    
    // Get RSI and price values
    for(int i = 0; i < lookback; i++)
    {
        rsi_values[i] = CalculateRSI(symbol, rsiPeriod, timeframe, i);
        price_values[i] = iLow(symbol, timeframe, i);
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
int MonitorOrderFlow(string symbol, bool useDOMAnalysis, double liquidityThreshold, double imbalanceThreshold)
{
    if (!useDOMAnalysis)
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
    double adjustedImbalanceThreshold = imbalanceThreshold * 0.8; // 20% more lenient

    // More lenient liquidity check
    bool sufficientLiquidity = (totalVolume >= liquidityThreshold * 0.7); // 30% more lenient

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
//| Check RSI and MACD Combination Signal                            |
//+------------------------------------------------------------------+
int CheckRSIMACDSignal(string symbol, ENUM_TIMEFRAMES timeframe, int rsiPeriod, double rsiUpperThreshold, double rsiLowerThreshold)
{
    double rsi = CalculateRSI(symbol, rsiPeriod, timeframe, 0);
    double macdMain, macdSignal, macdHistogram;
    CalculateMACD(symbol, macdMain, macdSignal, macdHistogram, 0, timeframe);
    
    // Get dynamic thresholds
    double upper_threshold, lower_threshold;
    GetDynamicRSIThresholds(symbol, timeframe, rsiUpperThreshold, rsiLowerThreshold, upper_threshold, lower_threshold);
    
    // Check for divergence
    bool bullish_div, bearish_div;
    CheckRSIDivergence(symbol, timeframe, rsiPeriod, 10, bullish_div, bearish_div);
    
    // Enhanced Buy Signal Conditions
    bool buySignal = 
        ((rsi < lower_threshold) || bullish_div) &&    // RSI oversold OR bullish divergence
        macdMain > macdSignal &&                     // MACD above signal
        macdHistogram > 0 &&                         // Positive momentum
        rsi > CalculateRSI(symbol, rsiPeriod, timeframe, 1);          // RSI increasing
        
    // Enhanced Sell Signal Conditions    
    bool sellSignal = 
        ((rsi > upper_threshold) || bearish_div) &&    // RSI overbought OR bearish divergence
        macdMain < macdSignal &&                     // MACD below signal
        macdHistogram < 0 &&                         // Negative momentum
        rsi < CalculateRSI(symbol, rsiPeriod, timeframe, 1);          // RSI decreasing
    
    // Return signals with logging
    if(buySignal)
    {
        Print("RSI Buy Signal - Value: ", rsi, 
              " Dynamic Lower: ", lower_threshold,
              " Divergence: ", bullish_div);
        return 1;
    }
    if(sellSignal)
    {
        Print("RSI Sell Signal - Value: ", rsi,
              " Dynamic Upper: ", upper_threshold,
              " Divergence: ", bearish_div);
        return -1;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Calculate RSI Trend Strength                                     |
//+------------------------------------------------------------------+
double GetRSITrendStrength(string symbol, ENUM_TIMEFRAMES timeframe, int rsiPeriod, int periods)
{
    double strength = 0;
    double prev_rsi = CalculateRSI(symbol, rsiPeriod, timeframe, periods);
    
    // Calculate the strength of the RSI trend
    for(int i = periods - 1; i >= 0; i--)
    {
        double current_rsi = CalculateRSI(symbol, rsiPeriod, timeframe, i);
        strength += (current_rsi - prev_rsi);
        prev_rsi = current_rsi;
    }
    
    return strength / periods;  // Positive = strengthening, Negative = weakening
}

//+------------------------------------------------------------------+
//| Initialize log times for all symbols                             |
//+------------------------------------------------------------------+
// Add these variables to track last log times
struct LogTimes {
    datetime calculationLogTime;
    datetime analysisLogTime;
    datetime signalLogTime;
};
static LogTimes symbolLogTimes[];  // Array to store log times for each symbol

void InitializeLogTimes(LogTimes &symbolLogTimes[], int symbolCount)
{
    datetime currentTime = TimeCurrent();
    for(int i = 0; i < symbolCount; i++)
    {
        symbolLogTimes[i].calculationLogTime = currentTime;
        symbolLogTimes[i].analysisLogTime = currentTime;
        symbolLogTimes[i].signalLogTime = currentTime;
    }
}
// Add this helper function to close all positions
void CloseAllPositions(string symbol, CTrade &trade)
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (PositionGetString(POSITION_SYMBOL) == symbol)
            {
                trade.PositionClose(ticket);
            }
        }
    }
}

// Add this function to check if a symbol is a stock
bool IsStockSymbol(string symbol)
{
    // Check for common stock exchange suffixes
    return StringFind(symbol, ".NYSE") >= 0 || 
           StringFind(symbol, ".NAS") >= 0 || 
           StringFind(symbol, ".LSE") >= 0;
}

// Add this function to check US market hours
bool IsWithinUSMarketHours()
{
    datetime serverTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(serverTime, dt);
    
    // Check if it's a weekday (1-5, Monday-Friday)
    if(dt.day_of_week <= 0 || dt.day_of_week > 5)
        return false;
        
    // Convert current time to minutes since midnight
    int currentMinutes = dt.hour * 60 + dt.min;
    int openMinutes = US_MARKET_OPEN_HOUR * 60 + US_MARKET_OPEN_MINUTE;
    int closeMinutes = US_MARKET_CLOSE_HOUR * 60 + US_MARKET_CLOSE_MINUTE;
    
    return (currentMinutes >= openMinutes && currentMinutes < closeMinutes);
}

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
void ValidateInputs(double riskPercent, double maxDrawdownPercent, double atrMultiplier, int adxPeriod, double trendADXThreshold, double trailingStopPips, double breakevenActivationPips, double breakevenOffsetPips, double liquidityThreshold, double imbalanceThreshold, int emaPeriodsShort, int emaPeriodsMedium, int emaPeriodsLong, int patternLookback, double goldenCrossThreshold)
{
    // Validate RiskPercent
    if (riskPercent <= 0.0 || riskPercent > 10.0)
    {
        Alert("RiskPercent must be between 0.1 and 10.0");
        ExpertRemove();
        return;
    }

    // Validate MaxDrawdownPercent
    if (maxDrawdownPercent <= 0.0 || maxDrawdownPercent > 100.0)
    {
        Alert("MaxDrawdownPercent must be between 0.1 and 100.0");
        ExpertRemove();
        return;
    }

    // Validate ATRMultiplier
    if (atrMultiplier <= 0.0 || atrMultiplier > 5.0)
    {
        Alert("ATRMultiplier must be between 0.1 and 5.0");
        ExpertRemove();
        return;
    }

    // Validate ADXPeriod
    if (adxPeriod <= 0)
    {
        Alert("ADXPeriod must be greater than 0");
        ExpertRemove();
        return;
    }

    // Validate TrendADXThreshold
    if (trendADXThreshold <= 0.0 || trendADXThreshold > 100.0)
    {
        Alert("TrendADXThreshold must be between 0.1 and 100.0");
        ExpertRemove();
        return;
    }

    // Validate TrailingStopPips
    if (trailingStopPips <= 0.0)
    {
        Alert("TrailingStopPips must be greater than 0");
        ExpertRemove();
        return;
    }

    // Validate BreakevenActivationPips and BreakevenOffsetPips
    if (breakevenActivationPips <= 0.0 || breakevenOffsetPips < 0.0)
    {
        Alert("BreakevenActivationPips must be greater than 0 and BreakevenOffsetPips cannot be negative");
        ExpertRemove();
        return;
    }

    // Validate LiquidityThreshold
    if (liquidityThreshold <= 0.0)
    {
        Alert("LiquidityThreshold must be greater than 0");
        ExpertRemove();
        return;
    }

    // Validate ImbalanceThreshold
    if (imbalanceThreshold <= 1.0)
    {
        Alert("ImbalanceThreshold must be greater than 1.0");
        ExpertRemove();
        return;
    }

    // Validate Pattern Recognition parameters
    if (emaPeriodsShort >= emaPeriodsMedium || emaPeriodsMedium >= emaPeriodsLong)
    {
        Alert("EMA periods must be in ascending order: SHORT < MEDIUM < LONG");
        ExpertRemove();
        return;
    }

    if (patternLookback <= 0 || patternLookback > 100)
    {
        Alert("PATTERN_LOOKBACK must be between 1 and 100");
        ExpertRemove();
        return;
    }

    if (goldenCrossThreshold <= 0)
    {
        Alert("GOLDEN_CROSS_THRESHOLD must be greater than 0");
        ExpertRemove();
        return;
    }
}

//+------------------------------------------------------------------+
//| Process a sell signal for a given symbol                         |
//+------------------------------------------------------------------+
void ProcessSellSignal(string symbol, double lotSize, double stopLoss, double takeProfit, double liquidityThreshold, double takeProfitPips, double stopLossPips, double riskPercent, CTrade &trade)
{

    if (!IsBullishCandlePattern(symbol))
    {
        if (!ManagePositions(symbol, POSITION_TYPE_SELL) && !HasPendingOrder(symbol, ORDER_TYPE_SELL_LIMIT))
        {
            double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
            double tpPrice = bid - takeProfit;
            double slPrice = bid + stopLoss;
            
            double limitPrice = GetBestLimitOrderPrice(symbol, ORDER_TYPE_SELL_LIMIT, tpPrice, slPrice, 
                                                       liquidityThreshold, takeProfitPips, stopLossPips);
            
            if (limitPrice > 0.0)
            {
                Print("🔻🔻 Sell Limit Order Placed - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
                trade.SellLimit(lotSize, limitPrice, symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, "Sell Limit Order");
                Print("  ____  _     _     _ _ _   _ _ _ ");
                Print(" |  _ \\| |__ (_) __| (_) |_(_) | |");
                Print(" | |_) | '_ \\| |/ _` | | __| | | |");
                Print(" |  __/| | | | | (_| | | |_| | | |");
                Print(" |_|   |_| |_|_|\\__,_|_|\\__|_|_|_|");
            }
            else
            {
                Print("🔻 Sell Market Order Placed - TP: ", tpPrice, " SL: ", slPrice);
                trade.Sell(lotSize, symbol, slPrice, tpPrice, "Sell Market Order");
                Print("  ____  _     _     _ _ _   _ _ _ ");
                Print(" |  _ \\| |__ (_) __| (_) |_(_) | |");
                Print(" | |_) | '_ \\| |/ _` | | __| | | |");
                Print(" |  __/| | | | | (_| | | |_| | | |");
                Print(" |_|   |_| |_|_|\\__,_|_|\\__|_|_|_|");
            }
        }
    }
    else
    {
        Print("Sell Signal Rejected - Strong bullish pattern detected");
    }
}

//+------------------------------------------------------------------+
//| Process a buy signal for a given symbol                          |
//+------------------------------------------------------------------+
void ProcessBuySignal(string symbol, double lotSize, double stopLoss, double takeProfit, double liquidityThreshold, double takeProfitPips, double stopLossPips, double riskPercent, CTrade &trade)
{

    if (!IsBearishCandlePattern(symbol))
    {
        if (!ManagePositions(symbol, POSITION_TYPE_BUY) && !HasPendingOrder(symbol, ORDER_TYPE_BUY_LIMIT))
        {
            double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double tpPrice = ask + takeProfit;
            double slPrice = ask - stopLoss;

            double limitPrice = GetBestLimitOrderPrice(symbol, ORDER_TYPE_BUY_LIMIT, tpPrice, slPrice, 
                                                       liquidityThreshold, takeProfitPips, stopLossPips);

            if (limitPrice > 0.0)
            {
                Print("🚀🚀 Buy Limit Order Placed - Price: ", limitPrice, " TP: ", tpPrice, " SL: ", slPrice);
                trade.BuyLimit(lotSize, limitPrice, symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, "Buy Limit Order");
                Print("  ____  _     _     _ _ _   _ _ _ ");
                Print(" |  _ \\| |__ (_) __| (_) |_(_) | |");
                Print(" | |_) | '_ \\| |/ _` | | __| | | |");
                Print(" |  __/| | | | | (_| | | |_| | | |");
                Print(" |_|   |_| |_|_|\\__,_|_|\\__|_|_|_|");
            }
            else
            {
                Print("🚀 Buy Market Order Placed - TP: ", tpPrice, " SL: ", slPrice);
                trade.Buy(lotSize, symbol, slPrice, tpPrice, "Buy Market Order");
                Print("  ____  _     _     _ _ _   _ _ _ ");
                Print(" |  _ \\| |__ (_) __| (_) |_(_) | |");
                Print(" | |_) | '_ \\| |/ _` | | __| | | |");
                Print(" |  __/| | | | | (_| | | |_| | | |");
                Print(" |_|   |_| |_|_|\\__,_|_|\\__|_|_|_|");
            }
        }
    }
    else
    {
        Print("Buy Signal Rejected - Strong bearish pattern detected");
    }
}
