#include <Trade\Trade.mqh> // Include trade operations

// Input Parameters
input double RiskPercentage = 1;             // Risk per trade as % of account balance
input int MA_Period = 20;                    // Moving Average period
input int CCI_Period = 14;                   // CCI period
input int ATR_Period = 14;                   // ATR period
input double SL_Multiplier = 2.0;            // Stop Loss multiplier of ATR
input double TP_Multiplier = 4.0;            // Take Profit multiplier of ATR
input int TradingStartHour = 9;              // Start trading hour (server time)
input int TradingEndHour = 18;               // End trading hour (server time)
input ENUM_TIMEFRAMES HigherTF = PERIOD_H4;  // Higher timeframe for MA
input bool UseTrailingStop = true;           // Enable Trailing Stop
input double TrailingStopMultiplier = 1.5;   // Trailing Stop multiplier of ATR

#define EA_MAGIC_NUMBER 123456               // Unique identifier for this EA's trades

CTrade trade; // Create trade object
int cciHandle;
int maHandle;
int atrHandle;
int maHandle_HTF;

// Function to calculate lot size based on risk percentage
double CalculateLotSize(double riskPercentage, double dynamicSL) {
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (riskPercentage / 100.0);
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lotSize = riskAmount / (dynamicSL / _Point * tickValue);
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    lotSize = MathMax(minLot, MathMin(NormalizeDouble(lotSize, 2), maxLot));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep; // Adjust to lot step
    return lotSize;
}

// EA Initialization
int OnInit() {
    // Create indicator handles
    cciHandle = iCCI(Symbol(), PERIOD_CURRENT, CCI_Period, PRICE_TYPICAL);
    maHandle = iMA(Symbol(), PERIOD_CURRENT, MA_Period, 0, MODE_SMA, PRICE_CLOSE);
    atrHandle = iATR(Symbol(), PERIOD_CURRENT, ATR_Period);
    maHandle_HTF = iMA(Symbol(), HigherTF, MA_Period, 0, MODE_SMA, PRICE_CLOSE);

    if (cciHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE ||
        atrHandle == INVALID_HANDLE || maHandle_HTF == INVALID_HANDLE) {
        Print("Failed to initialize indicators.");
        return INIT_FAILED;
    }

    Print("EA Initialized with advanced features.");
    return INIT_SUCCEEDED;
}

// OnTick function: Main trading logic
void OnTick() {
    // Time-Based Filter
    MqlDateTime tm;
    TimeToStruct(TimeTradeServer(), tm); // Use server time for trading hours
    int currentHour = tm.hour;
    if (currentHour < TradingStartHour || currentHour >= TradingEndHour) {
        return;
    }

    double cci[];
    double ma[];
    double atr[];
    double ma_HTF[];

    // Retrieve indicator values
    if (CopyBuffer(cciHandle, 0, 0, 1, cci) <= 0 ||
        CopyBuffer(maHandle, 0, 0, 1, ma) <= 0 ||
        CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0 ||
        CopyBuffer(maHandle_HTF, 0, 0, 1, ma_HTF) <= 0) {
        Print("Failed to retrieve indicator values.");
        return;
    }

    double currentCCI = cci[0];
    double currentMA = ma[0];
    double atrValue = atr[0];
    double currentMA_HTF = ma_HTF[0];

    double bidPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double askPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

    // Calculate dynamic Stop Loss and Take Profit
    double dynamicSL = atrValue * SL_Multiplier;
    double dynamicTP = atrValue * TP_Multiplier;

    // Calculate lot size based on risk management
    double lots = CalculateLotSize(RiskPercentage, dynamicSL);

    // Check if no position is open for the current symbol and magic number
    if (!PositionSelectByMagic(Symbol(), EA_MAGIC_NUMBER)) {
        // Long trade condition: CCI < -100, price > MA, MA trending up
        if (currentCCI < -100 && bidPrice > currentMA && currentMA > currentMA_HTF) {
            double slPrice = askPrice - dynamicSL;
            double tpPrice = askPrice + dynamicTP;

            if (!trade.Buy(lots, Symbol(), askPrice, slPrice, tpPrice, EA_MAGIC_NUMBER)) {
                Print("Failed to open Buy trade: ", trade.ResultRetcode());
            } else {
                Print("Buy trade opened successfully.");
            }
        }

        // Short trade condition: CCI > 100, price < MA, MA trending down
        if (currentCCI > 100 && bidPrice < currentMA && currentMA < currentMA_HTF) {
            double slPrice = bidPrice + dynamicSL;
            double tpPrice = bidPrice - dynamicTP;

            //if (!trade.Sell(lots, Symbol(), bidPrice, slPrice, tpPrice, EA_MAGIC_NUMBER)) {
            //    Print("Failed to open Sell trade: ", trade.ResultRetcode());
            //} else {
            //    Print("Sell trade opened successfully.");
            //}
        }
    } else {
        // Manage existing positions (Trailing Stop)
        if (UseTrailingStop) {
            ManageTrailingStop();
        }
    }
}

// Function to manage trailing stop
void ManageTrailingStop() {
    // Retrieve open positions
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket)) {
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            int positionMagic = (int)PositionGetInteger(POSITION_MAGIC);

            if (positionSymbol == Symbol() && positionMagic == EA_MAGIC_NUMBER) {
                int positionType = (int)PositionGetInteger(POSITION_TYPE);
                double stopLoss = PositionGetDouble(POSITION_SL);
                double takeProfit = PositionGetDouble(POSITION_TP);

                // Get current ATR value
                double atr[];
                if (CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) {
                    Print("Failed to retrieve ATR values for trailing stop.");
                    continue;
                }
                double atrValue = atr[0];
                double trailingStop = atrValue * TrailingStopMultiplier;

                if (positionType == POSITION_TYPE_BUY) {
                    double newSL = SymbolInfoDouble(Symbol(), SYMBOL_BID) - trailingStop;
                    if (newSL > stopLoss || stopLoss == 0) {
                        trade.PositionModify(ticket, newSL, takeProfit);
                    }
                } else if (positionType == POSITION_TYPE_SELL) {
                    double newSL = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + trailingStop;
                    if (newSL < stopLoss || stopLoss == 0) {
                        trade.PositionModify(ticket, newSL, takeProfit);
                    }
                }
            }
        }
    }
}

// OnDeinit function: Cleanup resources
void OnDeinit(const int reason) {
    if (cciHandle != INVALID_HANDLE) IndicatorRelease(cciHandle);
    if (maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
    if (atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
    if (maHandle_HTF != INVALID_HANDLE) IndicatorRelease(maHandle_HTF);

    Print("EA Deinitialized.");
}

// Utility function to check if a position exists for the symbol and magic number
bool PositionSelectByMagic(string symbol, int magicNumber) {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket)) {
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            int positionMagic = (int)PositionGetInteger(POSITION_MAGIC);
            if (positionSymbol == symbol && positionMagic == magicNumber) {
                return true;
            }
        }
    }
    return false;
}
