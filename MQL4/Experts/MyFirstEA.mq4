// Input Parameters
input double RiskPercentage = 1;       // Risk per trade as % of account balance
input double Lots = 0.1;               // Default lot size (used if risk-based lot calculation is disabled)
input int MA_Period = 20;              // Moving Average period
input int CCI_Period = 14;             // CCI period
input int StopLoss = 50;               // Stop Loss in pips
input int TakeProfit = 100;            // Take Profit in pips

// Function to calculate lot size based on risk
double CalculateLotSize(double stopLossPips) {
    double riskAmount = AccountBalance() * (RiskPercentage / 100); // Risk amount in dollars
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE) * stopLossPips;

    // Prevent division by zero and ensure reasonable pip value
    if (pipValue <= 0) pipValue = 0.01;

    double lotSize = riskAmount / pipValue;

    // Calculate maximum lot size based on available margin and leverage
    double leverage = AccountLeverage(); // Get the account leverage (e.g., 50)
    double marginRequiredPerLot = MarketInfo(Symbol(), MODE_MARGINREQUIRED); // Margin required for 1 lot
    double maxAffordableLots = AccountFreeMargin() / (marginRequiredPerLot / leverage);

    // Limit lot size to what is affordable given the account balance and leverage
    lotSize = MathMin(lotSize, maxAffordableLots);

    // Enforce micro range limits (0.10 to 1.00 lots)
    lotSize = MathMax(0.10, MathMin(lotSize, 1.00));

    return NormalizeDouble(lotSize, 2); // Round to 2 decimal places
}


// Function to check for open orders
bool CheckOpenOrders() {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol()) {
            return true;
        }
    }
    return false;
}

// Main trading logic
void OnTick() {
    double currentPrice = iClose(Symbol(), PERIOD_M1, 0); // Current close price
    double movingAverage = iMA(Symbol(), PERIOD_M1, MA_Period, 0, MODE_SMA, PRICE_CLOSE, 0);
    double cci = iCCI(Symbol(), PERIOD_M1, CCI_Period, PRICE_TYPICAL, 0);

    // Declare variables for trade execution
    int ticket;
    int errorCode;

    // Check for open orders
    if (!CheckOpenOrders()) {
        double calculatedLots = CalculateLotSize(StopLoss);

        // Ensure margin is sufficient before placing the trade
        double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED) * calculatedLots;
        if (marginRequired > AccountFreeMargin()) {
            Print("Trade canceled: Insufficient margin. Required: ", marginRequired, ", Available: ", AccountFreeMargin());
            return;
        }

        // Long Trade: Oversold Market
        if (cci < -100 && currentPrice > movingAverage) {
            ticket = OrderSend(Symbol(), OP_BUY, calculatedLots, Ask, 3, Ask - StopLoss * Point, Ask + TakeProfit * Point, "Buy Trade", 0, 0, clrGreen);
            if (ticket < 0) {
                errorCode = GetLastError();
                Print("OrderSend (Buy) failed with error #", errorCode);
            } else {
                Print("Buy trade opened successfully. Ticket #", ticket);
            }
        }

        // Short Trade: Overbought Market
        if (cci > 100 && currentPrice < movingAverage) {
            ticket = OrderSend(Symbol(), OP_SELL, calculatedLots, Bid, 3, Bid + StopLoss * Point, Bid - TakeProfit * Point, "Sell Trade", 0, 0, clrRed);
            if (ticket < 0) {
                errorCode = GetLastError();
                Print("OrderSend (Sell) failed with error #", errorCode);
            } else {
                Print("Sell trade opened successfully. Ticket #", ticket);
            }
        }
    }
}
