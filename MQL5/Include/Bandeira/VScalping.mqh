//+------------------------------------------------------------------+
//| RSI-MACD Scalping Include File                                  |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property version   "1.01"

#include <Trade/Trade.mqh>

// Add CTrade object
CTrade tradeScalp;

// Add these constants at the top of the file

const int SCALP_MACD_FAST = 5;            // More aggressive MACD settings
const int SCALP_MACD_SLOW = 13;
const int SCALP_MACD_SIGNAL = 4;
const int SCALP_EMA_SHORT = 5;            // Shorter EMA periods
const int SCALP_EMA_MEDIUM = 13;
const int SCALP_EMA_LONG = 34;
const int VOLUME_LOOKBACK = 10;           // Shorter volume lookback
const double MIN_RVOL = 1.2;              // Lower volume threshold

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
    
    // Get point value and calculate pip value
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double pipValue = (tickValue * point) / tickSize;
    
    // Calculate potential loss in account currency
    double potentialLoss = stopLossPips * pipValue;
    
    // Prevent division by zero
    if(potentialLoss <= 0) {
        LogMessage("Warning: Invalid potential loss calculation. Using minimum lot size.", symbol);
        return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    }
    
    // Calculate lot size based on risk amount and potential loss
    double lotSize = riskAmount / potentialLoss;
    
    // Ensure minimum viable lot size
    if (lotSize < SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN) || lotSize <= 0) {
        LogMessage("Warning: Calculated lot size too small. Using minimum lot size.", symbol);
        lotSize = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    }
    
    // Get symbol lot limits
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Add a dynamic maximum lot size based on account balance
    double dynamicMaxLot = MathMax(minLot, accountBalance / (50000 * lotStep)); // Ensure at least minLot
    double HARD_CAP_MAX_LOTS = MathMin(maxLot, dynamicMaxLot);
    
    // Normalize lot size to valid range
    lotSize = MathMin(HARD_CAP_MAX_LOTS, MathMax(minLot, lotSize));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
    
    LogMessage("Risk Calculation:" +
              "\nAccount Balance: " + DoubleToString(accountBalance, 2) +
              "\nRisk Amount: " + DoubleToString(riskAmount, 2) +
              "\nPip Value: " + DoubleToString(pipValue, 6) +
              "\nPotential Loss: " + DoubleToString(potentialLoss, 2) +
              "\nDynamic Max Lot: " + DoubleToString(dynamicMaxLot, 2) +
              "\nFinal Lot Size: " + DoubleToString(lotSize, 2), symbol);
              
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
    CalculateBollingerBands(symbol, bbUpper, bbMiddle, bbLower);
    
    LogMessage("Checking Enhanced Buy Condition:" +
              "\nRSI=" + DoubleToString(rsi, 2) +
              "\nMACD Main=" + DoubleToString(macdMain, 2) +
              "\nMACD Signal=" + DoubleToString(macdSignal, 2) +
              "\nRVOL=" + DoubleToString(rvol, 2), symbol);
    
    bool momentumConfirmation = (rsi > 20 && rsi < 80 && macdMain > macdSignal);
    bool trendConfirmation = (emaShort > emaMedium * 0.995);
    bool volumeConfirmation = (rvol >= MIN_RVOL);
    bool priceAction = (SymbolInfoDouble(symbol, SYMBOL_ASK) < bbUpper * 1.005);
    
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
    CalculateBollingerBands(symbol, bbUpper, bbMiddle, bbLower);
    
    LogMessage("Checking Enhanced Sell Condition:" +
              "\nRSI=" + DoubleToString(rsi, 2) +
              "\nMACD Main=" + DoubleToString(macdMain, 2) +
              "\nMACD Signal=" + DoubleToString(macdSignal, 2) +
              "\nRVOL=" + DoubleToString(rvol, 2), symbol);
    
    bool momentumConfirmation = (rsi > 20 && rsi < 80 && macdMain < macdSignal);
    bool trendConfirmation = (emaShort < emaMedium * 1.005);
    bool volumeConfirmation = (rvol >= MIN_RVOL);
    bool priceAction = (SymbolInfoDouble(symbol, SYMBOL_BID) > bbLower * 0.995);
    
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
void CalculateBollingerBands(string symbol, double &upper, double &middle, double &lower) {
    int bb_handle = iBands(symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) {
        LogMessage("Error creating Bollinger Bands indicator", symbol);
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

// Add this helper function at the top of the file
ENUM_ORDER_TYPE_FILLING GetSupportedFillingMode(string symbol)
{
    // Get the filling modes supported by the symbol
    uint filling = (uint)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
    
    // Check supported filling modes in order of preference
    if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
        return ORDER_FILLING_FOK;
    if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
        return ORDER_FILLING_IOC;
    
    return ORDER_FILLING_RETURN; // Default if nothing else is supported
}

// Function to execute a buy trade
void ExecuteBuyTrade(double lotSize, string symbol, double riskRewardRatio) {
    // Calculate dynamic SL/TP first
    double stopLossPips, takeProfitPips;
    CalculateDynamicSLTP(stopLossPips, takeProfitPips, symbol, riskRewardRatio);

    // Get symbol properties
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    // Normalize lot size
    lotSize = MathMin(maxLot, MathMax(minLot, lotSize));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;

    // Get current price
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // Ensure minimum stop level is respected
    stopLossPips = MathMax(stopLossPips, stopLevel * point);
    takeProfitPips = MathMax(takeProfitPips, stopLevel * point);
    
    // Calculate SL/TP prices with proper point multiplication
    double sl = price - (stopLossPips / point) * point;
    double tp = price + (takeProfitPips / point) * point;

    // Log trade parameters before execution
    LogMessage("Trade parameters:" +
              "\nType: BUY" +
              "\nLot Size: " + DoubleToString(lotSize, 2) +
              "\nStop Loss: " + DoubleToString(stopLossPips/point, 2) + " pips" +
              "\nTake Profit: " + DoubleToString(takeProfitPips/point, 2) + " pips" +
              "\nRisk/Reward: 1:" + DoubleToString(takeProfitPips/stopLossPips, 2), symbol);

    // Use the trade object instead of direct OrderSend
    tradeScalp.SetTypeFilling(GetSupportedFillingMode(symbol));
    tradeScalp.Buy(lotSize, symbol, 0, sl, tp, "RSI-MACD Buy");
    
    if(tradeScalp.ResultRetcode() != TRADE_RETCODE_DONE) {
        LogError(tradeScalp.ResultRetcode(), "Buy Trade");
    } else {
        LogMessage("Buy Trade Executed: Ticket=" + IntegerToString(tradeScalp.ResultOrder()), symbol);
        
        // ASCII Art for Buy
        Print("\n");
        Print("╔══════════════════════════════════════╗");
        Print("║          🚀 LONG POSITION 🚀         ║");
        Print("║----------------------------------------║");
        Print("║    TO THE MOON!     |    ^    |      ║");
        Print("║                      |   / \\   |      ║");
        Print("║                      |  /   \\  |      ║");
        Print("║                      | /     \\ |      ║");
        Print("║                      |/       \\|      ║");
        Print("╚══════════════════════════════════════╝");
        Print("\n");
    }
}


// Function to execute a sell trade
void ExecuteSellTrade(double lotSize, string symbol, double riskRewardRatio) {
    // Calculate dynamic SL/TP first
    double stopLossPips, takeProfitPips;
    CalculateDynamicSLTP(stopLossPips, takeProfitPips, symbol, riskRewardRatio);

    // Get symbol properties
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    int stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    // Normalize lot size
    lotSize = MathMin(maxLot, MathMax(minLot, lotSize));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;

    // Get current price
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Ensure minimum stop level is respected
    stopLossPips = MathMax(stopLossPips, stopLevel * point);
    takeProfitPips = MathMax(takeProfitPips, stopLevel * point);
    
    // Calculate SL/TP prices with proper point multiplication
    double sl = price + (stopLossPips / point) * point;
    double tp = price - (takeProfitPips / point) * point;

    // Log trade parameters before execution
    LogMessage("Trade parameters:" +
              "\nType: SELL" +
              "\nLot Size: " + DoubleToString(lotSize, 2) +
              "\nStop Loss: " + DoubleToString(stopLossPips/point, 2) + " pips" +
              "\nTake Profit: " + DoubleToString(takeProfitPips/point, 2) + " pips" +
              "\nRisk/Reward: 1:" + DoubleToString(takeProfitPips/stopLossPips, 2), symbol);

    // Use the trade object instead of direct OrderSend
    tradeScalp.SetTypeFilling(GetSupportedFillingMode(symbol));
    tradeScalp.Sell(lotSize, symbol, 0, sl, tp, "RSI-MACD Sell");
    
    if(tradeScalp.ResultRetcode() != TRADE_RETCODE_DONE) {
        LogError(tradeScalp.ResultRetcode(), "Sell Trade");
    } else {
        LogMessage("Sell Trade Executed: Ticket=" + IntegerToString(tradeScalp.ResultOrder()), symbol);
        
        // ASCII Art for Sell
        Print("\n");
        Print("╔══════════════════════════════════════╗");
        Print("║          🐻 SHORT POSITION 🐻        ║");
        Print("║----------------------------------------║");
        Print("║    RIDING THE WAVE    |\\       /|    ║");
        Print("║                       | \\     / |    ║");
        Print("║                       |  \\   /  |    ║");
        Print("║                       |   \\ /   |    ║");
        Print("║                       |    v    |    ║");
        Print("╚══════════════════════════════════════╝");
        Print("\n");
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
    if (rsi > 80 || rsi < 20 || MathAbs(macdHistogram) < 0.00005) {
        LogMessage("Exit condition met: " + 
                  (rsi > 80 ? "RSI Overbought" : 
                   rsi < 20 ? "RSI Oversold" : 
                   "MACD Momentum Reversal"), symbol);
        return true;
    }
    
    LogMessage("Exit condition not met.", symbol);
    return false;
}

void CalculateDynamicSLTP(double &stopLossPips, double &takeProfitPips, string symbol, double riskRewardRatio = 2.0) {
    // Get ATR for dynamic SL/TP
    int atrPeriod = 14;  // Standard ATR period
    double atrValues[];
    ArraySetAsSeries(atrValues, true);
    int atrHandle = iATR(symbol, PERIOD_CURRENT, atrPeriod);

    if (atrHandle == INVALID_HANDLE) {
        LogMessage("Error creating ATR indicator for SL/TP calculation", symbol);
        stopLossPips = 10;  // Default fallback
        takeProfitPips = 20; // Default fallback
        return;
    }

    if (CopyBuffer(atrHandle, 0, 0, 1, atrValues) < 0) {
        LogMessage("Error copying ATR values for SL/TP calculation", symbol);
        stopLossPips = 10;  // Default fallback
        takeProfitPips = 20; // Default fallback
        IndicatorRelease(atrHandle);
        return;
    }

    double atr = atrValues[0];  // Current ATR
    IndicatorRelease(atrHandle);

    // Calculate SL and TP
    stopLossPips = atr * 1.5;  // Example multiplier
    takeProfitPips = stopLossPips * riskRewardRatio;

    LogMessage("Dynamic SL/TP calculated: ATR=" + DoubleToString(atr, 5) +
               " SL=" + DoubleToString(stopLossPips, 2) + 
               " TP=" + DoubleToString(takeProfitPips, 2), symbol);
}

