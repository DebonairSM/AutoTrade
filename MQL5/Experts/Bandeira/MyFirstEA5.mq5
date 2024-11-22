#include <Trade\Trade.mqh> // Include trade operations

// Input Parameters
input double RiskPercentage = 1;       // Risk per trade as % of account balance
input int MA_Period = 20;              // Moving Average period
input int CCI_Period = 14;             // CCI period
input int StopLoss = 50;               // Stop Loss in pips
input int TakeProfit = 100;            // Take Profit in pips

#define EA_MAGIC_NUMBER 123456         // Unique identifier for this EA's trades

CTrade trade; // Create trade object
int cciHandle;
int maHandle;

// Function to calculate lot size based on risk percentage
double CalculateLotSize(double riskPercentage, int stopLossPips) {
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (riskPercentage / 100.0);
    double pipValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lotSize = riskAmount / (stopLossPips * pipValue);
    return NormalizeDouble(lotSize, 2);
}

// EA Initialization
int OnInit() {
    // Create indicator handles
    cciHandle = iCCI(Symbol(), PERIOD_CURRENT, CCI_Period, PRICE_TYPICAL);
    maHandle = iMA(Symbol(), PERIOD_CURRENT, MA_Period, 0, MODE_SMA, PRICE_CLOSE);

    if (cciHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE) {
        Print("Failed to initialize indicators.");
        return INIT_FAILED;
    }

    Print("EA Initialized for MQL5.");
    return INIT_SUCCEEDED;
}

// OnTick function: Main trading logic
void OnTick() {
    double cci[];
    double ma[];

    // Retrieve indicator values
    if (CopyBuffer(cciHandle, 0, 0, 1, cci) <= 0 || CopyBuffer(maHandle, 0, 0, 1, ma) <= 0) {
        Print("Failed to retrieve indicator values.");
        return;
    }

    double currentCCI = cci[0];
    double currentMA = ma[0];
    double bidPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double askPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

    // Calculate lot size based on risk management
    double lots = CalculateLotSize(RiskPercentage, StopLoss);

    // Check if no position is open for the current symbol and magic number
    if (!PositionSelectByMagic(Symbol(), EA_MAGIC_NUMBER)) {
        // Long trade condition: CCI < -100 and price > moving average
        if (currentCCI < -100 && bidPrice > currentMA) {
            if (!trade.Buy(lots, Symbol(), askPrice, askPrice - StopLoss * _Point, askPrice + TakeProfit * _Point, EA_MAGIC_NUMBER)) {
                Print("Failed to open Buy trade: ", trade.ResultRetcode());
            } else {
                Print("Buy trade opened successfully.");
            }
        }

        // Short trade condition: CCI > 100 and price < moving average
        if (currentCCI > 100 && bidPrice < currentMA) {
            if (!trade.Sell(lots, Symbol(), bidPrice, bidPrice + StopLoss * _Point, bidPrice - TakeProfit * _Point, EA_MAGIC_NUMBER)) {
                Print("Failed to open Sell trade: ", trade.ResultRetcode());
            } else {
                Print("Sell trade opened successfully.");
            }
        }
    } else {
        Print("Position already open for ", Symbol(), ". No new trade executed.");
    }
}

// OnDeinit function: Cleanup resources
void OnDeinit(const int reason) {
    if (cciHandle != INVALID_HANDLE) IndicatorRelease(cciHandle);
    if (maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);

    Print("EA Deinitialized.");
}

// Utility function to check if a position exists for the symbol and magic number
bool PositionSelectByMagic(string symbol, int magicNumber) {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetSymbol(i) == symbol && (int)PositionGetInteger(POSITION_MAGIC) == magicNumber) {
            return true;
        }
    }
    return false;
}