//+------------------------------------------------------------------+
//| RSI-MACD Scalping Include File                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property version   "1.01"

// Add these constants at the top of the file
const int SCALP_RSI_PERIOD = 7;           // Shorter RSI period for scalping
const int SCALP_MACD_FAST = 9;            // Faster MACD settings
const int SCALP_MACD_SLOW = 21;
const int SCALP_MACD_SIGNAL = 6;
const int SCALP_EMA_SHORT = 9;            // EMA periods for trend confirmation
const int SCALP_EMA_MEDIUM = 21;
const int SCALP_EMA_LONG = 50;
const int VOLUME_LOOKBACK = 20;           // For RVOL calculation
const double MIN_RVOL = 1.5;              // Minimum relative volume

// Logging utility
void LogMessage(string message, string symbol) {
    Print(TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + " [" + symbol + "]: " + message);
}

// Enhanced Logging utility for errors
void LogError(int errorCode, string context) {
    string errorDescription;
    switch (errorCode) {
        case 4756: errorDescription = "Invalid trade volume or broker restrictions"; break;
        case 4109: errorDescription = "Trade context busy"; break;
        default: errorDescription = "Unknown error"; break;
    }
    LogMessage(context + " Failed with Error " + IntegerToString(errorCode) + ": " + errorDescription, "N/A");
}

// Function to calculate lot size based on risk management
double CalculateLotSize(double riskPercentage, double stopLossPips, string symbol) {
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (riskPercentage / 100.0);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    
    // Prevent division by zero
    if(stopLossPips <= 0 || tickValue <= 0) {
        LogMessage("Warning: Invalid stop loss or tick value. Using minimum lot size.", symbol);
        return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    }
    
    double lotSize = riskAmount / (stopLossPips * tickValue);
    
    // Get symbol lot limits
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Add a hard cap on maximum lot size (adjust this value based on your broker's limits)
    const double HARD_CAP_MAX_LOTS = 50.0;  // Added safety limit
    maxLot = MathMin(maxLot, HARD_CAP_MAX_LOTS);
    
    // Normalize lot size to valid range
    lotSize = MathMin(maxLot, MathMax(minLot, lotSize));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
    
    LogMessage("Risk Amount: " + DoubleToString(riskAmount, 2) + 
              " Account Balance: " + DoubleToString(accountBalance, 2) +  
              " Tick Value: " + DoubleToString(tickValue, 6), symbol);
    LogMessage("Calculated Lot Size: " + DoubleToString(lotSize, 2), symbol);
    return lotSize;
}

// Enhanced buy condition check with all confirmations
bool CheckBuyCondition(double rsi, double macdMain, double macdSignal, string symbol) {
    // Get EMAs for trend confirmation
    double emaShort = iMA(symbol, PERIOD_CURRENT, SCALP_EMA_SHORT, 0, MODE_EMA, PRICE_CLOSE);
    double emaMedium = iMA(symbol, PERIOD_CURRENT, SCALP_EMA_MEDIUM, 0, MODE_EMA, PRICE_CLOSE);
    
    // Calculate RVOL
    double currentVolume = iVolume(symbol, PERIOD_CURRENT, 0);
    double avgVolume = 0;
    for(int i = 1; i <= VOLUME_LOOKBACK; i++) {
        avgVolume += iVolume(symbol, PERIOD_CURRENT, i);
    }
    avgVolume /= VOLUME_LOOKBACK;
    double rvol = currentVolume / avgVolume;
    
    // Get Bollinger Bands
    double bbUpper, bbMiddle, bbLower;
    CalculateBollingerBands(bbUpper, bbMiddle, bbLower);
    
    LogMessage("Checking Enhanced Buy Condition:" +
              "\nRSI=" + DoubleToString(rsi, 2) +
              "\nMACD Main=" + DoubleToString(macdMain, 2) +
              "\nMACD Signal=" + DoubleToString(macdSignal, 2) +
              "\nRVOL=" + DoubleToString(rvol, 2), symbol);
    
    bool momentumConfirmation = (rsi > 30 && rsi < 70 && macdMain > macdSignal);
    bool trendConfirmation = (emaShort > emaMedium);
    bool volumeConfirmation = (rvol >= MIN_RVOL);
    bool priceAction = (SymbolInfoDouble(symbol, SYMBOL_ASK) < bbUpper);
    
    if (momentumConfirmation && trendConfirmation && volumeConfirmation && priceAction) {
        LogMessage("Buy condition met with all confirmations.", symbol);
        return true;
    }
    
    LogMessage("Buy condition not met. Failed confirmations:" +
              (!momentumConfirmation ? " Momentum" : "") +
              (!trendConfirmation ? " Trend" : "") +
              (!volumeConfirmation ? " Volume" : "") +
              (!priceAction ? " Price" : ""), symbol);
    return false;
}

// Enhanced sell condition check
bool CheckSellCondition(double rsi, double macdMain, double macdSignal, string symbol) {
    // Get EMAs for trend confirmation
    double emaShort = iMA(symbol, PERIOD_CURRENT, SCALP_EMA_SHORT, 0, MODE_EMA, PRICE_CLOSE);
    double emaMedium = iMA(symbol, PERIOD_CURRENT, SCALP_EMA_MEDIUM, 0, MODE_EMA, PRICE_CLOSE);
    
    // Calculate RVOL
    double currentVolume = iVolume(symbol, PERIOD_CURRENT, 0);
    double avgVolume = 0;
    for(int i = 1; i <= VOLUME_LOOKBACK; i++) {
        avgVolume += iVolume(symbol, PERIOD_CURRENT, i);
    }
    avgVolume /= VOLUME_LOOKBACK;
    double rvol = currentVolume / avgVolume;
    
    // Get Bollinger Bands
    double bbUpper, bbMiddle, bbLower;
    CalculateBollingerBands(bbUpper, bbMiddle, bbLower);
    
    LogMessage("Checking Enhanced Sell Condition:" +
              "\nRSI=" + DoubleToString(rsi, 2) +
              "\nMACD Main=" + DoubleToString(macdMain, 2) +
              "\nMACD Signal=" + DoubleToString(macdSignal, 2) +
              "\nRVOL=" + DoubleToString(rvol, 2), symbol);
    
    bool momentumConfirmation = (rsi > 30 && rsi < 70 && macdMain < macdSignal);
    bool trendConfirmation = (emaShort < emaMedium);
    bool volumeConfirmation = (rvol >= MIN_RVOL);
    bool priceAction = (SymbolInfoDouble(symbol, SYMBOL_BID) > bbLower);
    
    if (momentumConfirmation && trendConfirmation && volumeConfirmation && priceAction) {
        LogMessage("Sell condition met with all confirmations.", symbol);
        return true;
    }
    
    LogMessage("Sell condition not met. Failed confirmations:" +
              (!momentumConfirmation ? " Momentum" : "") +
              (!trendConfirmation ? " Trend" : "") +
              (!volumeConfirmation ? " Volume" : "") +
              (!priceAction ? " Price" : ""), symbol);
    return false;
}

// Add Bollinger Bands calculation
void CalculateBollingerBands(double &upper, double &middle, double &lower) {
    int bb_handle = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) {
        LogMessage("Error creating Bollinger Bands indicator", _Symbol);
        return;
    }
    
    // Create separate arrays for each buffer
    double middleBuffer[];
    double upperBuffer[];
    double lowerBuffer[];
    
    // Set arrays as series and allocate memory
    ArraySetAsSeries(middleBuffer, true);
    ArraySetAsSeries(upperBuffer, true);
    ArraySetAsSeries(lowerBuffer, true);
    ArrayResize(middleBuffer, 1);
    ArrayResize(upperBuffer, 1);
    ArrayResize(lowerBuffer, 1);
    
    // Copy data into the buffers
    CopyBuffer(bb_handle, 0, 0, 1, middleBuffer);  // Middle
    CopyBuffer(bb_handle, 1, 0, 1, upperBuffer);   // Upper
    CopyBuffer(bb_handle, 2, 0, 1, lowerBuffer);   // Lower
    
    // Assign values
    middle = middleBuffer[0];
    upper = upperBuffer[0];
    lower = lowerBuffer[0];
    
    IndicatorRelease(bb_handle);
}

// Function to execute a buy trade
void ExecuteBuyTrade(double lotSize, double stopLossPips, double takeProfitPips, string symbol) {
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    // Symbol properties
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT);

    // Cap and normalize lot size
    lotSize = MathMin(maxLot, MathMax(minLot, lotSize));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;

    // Validate stop-loss and take-profit
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double sl = price - stopLossPips * SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tp = price + takeProfitPips * SymbolInfoDouble(symbol, SYMBOL_POINT);

    if (stopLossPips < minStopLevel || takeProfitPips < minStopLevel) {
        LogMessage("Adjusting stop-loss and take-profit to minimum stop level: " +
                   DoubleToString(minStopLevel / SymbolInfoDouble(symbol, SYMBOL_POINT), 2) + " pips.", symbol);
        stopLossPips = MathMax(stopLossPips, minStopLevel / SymbolInfoDouble(symbol, SYMBOL_POINT));
        takeProfitPips = MathMax(takeProfitPips, minStopLevel / SymbolInfoDouble(symbol, SYMBOL_POINT));
    }

    // Prepare trade request
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 3;
    request.comment = "RSI-MACD Buy";
    request.type_filling = ORDER_FILLING_IOC;  // Use IOC for compatibility

    // Log trade parameters
    LogMessage("Executing Buy Trade: Price=" + DoubleToString(price, _Digits) +
               " LotSize=" + DoubleToString(lotSize, 2) + 
               " SL=" + DoubleToString(sl, _Digits) + 
               " TP=" + DoubleToString(tp, _Digits), symbol);

    bool success = OrderSend(request, result);
    if (!success) {
        LogError(GetLastError(), "Buy Trade");
    } else {
        LogMessage("Buy Trade Executed: Ticket=" + IntegerToString(result.deal), symbol);
    }
}


// Function to execute a sell trade
void ExecuteSellTrade(double lotSize, double stopLossPips, double takeProfitPips, string symbol) {
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    // Symbol properties
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT);

    // Cap and normalize lot size
    lotSize = MathMin(maxLot, MathMax(minLot, lotSize));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;

    // Validate stop-loss and take-profit
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl = price + stopLossPips * SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tp = price - takeProfitPips * SymbolInfoDouble(symbol, SYMBOL_POINT);

    if (stopLossPips < minStopLevel || takeProfitPips < minStopLevel) {
        LogMessage("Adjusting stop-loss and take-profit to minimum stop level: " +
                   DoubleToString(minStopLevel / SymbolInfoDouble(symbol, SYMBOL_POINT), 2) + " pips.", symbol);
        stopLossPips = MathMax(stopLossPips, minStopLevel / SymbolInfoDouble(symbol, SYMBOL_POINT));
        takeProfitPips = MathMax(takeProfitPips, minStopLevel / SymbolInfoDouble(symbol, SYMBOL_POINT));
    }

    // Prepare trade request
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 3;
    request.comment = "RSI-MACD Sell";
    request.type_filling = ORDER_FILLING_IOC;  // Use IOC for compatibility

    // Log trade parameters
    LogMessage("Executing Sell Trade: Price=" + DoubleToString(price, _Digits) +
               " LotSize=" + DoubleToString(lotSize, 2) + 
               " SL=" + DoubleToString(sl, _Digits) + 
               " TP=" + DoubleToString(tp, _Digits), symbol);

    bool success = OrderSend(request, result);
    if (!success) {
        LogError(GetLastError(), "Sell Trade");
    } else {
        LogMessage("Sell Trade Executed: Ticket=" + IntegerToString(result.deal), symbol);
    }
}

// Enhanced exit condition check
bool CheckExitCondition(double rsi, string symbol) {
    // Get MACD values for exit confirmation
    double macdMain, macdSignal, macdHistogram;
    int macd_handle = iMACD(symbol, PERIOD_CURRENT, SCALP_MACD_FAST, SCALP_MACD_SLOW, 
                           SCALP_MACD_SIGNAL, PRICE_CLOSE);
    
    if(macd_handle != INVALID_HANDLE) {
        double macdBuffer[];
        ArraySetAsSeries(macdBuffer, true);
        CopyBuffer(macd_handle, 0, 0, 2, macdBuffer);
        macdHistogram = macdBuffer[0] - macdBuffer[1];
        IndicatorRelease(macd_handle);
    }
    
    LogMessage("Checking Enhanced Exit Condition: RSI=" + DoubleToString(rsi, 2) +
              " MACD Histogram Change=" + DoubleToString(macdHistogram, 6), symbol);
              
    // Exit if RSI reaches extreme levels or MACD shows momentum reversal
    if (rsi > 70 || rsi < 30 || MathAbs(macdHistogram) < 0.0001) {
        LogMessage("Exit condition met: " + 
                  (rsi > 70 ? "RSI Overbought" : 
                   rsi < 30 ? "RSI Oversold" : 
                   "MACD Momentum Reversal"), symbol);
        return true;
    }
    
    LogMessage("Exit condition not met.", symbol);
    return false;
}
