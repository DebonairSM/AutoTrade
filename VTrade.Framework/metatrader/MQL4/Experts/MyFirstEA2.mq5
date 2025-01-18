// Define input parameters
input double Lots = 0.1;
input int MA_Period = 20;
input int StopLoss = 50;
input int TakeProfit = 100;

// Function to check if there's an open position
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

    // Check if there are no open orders
    if (!CheckOpenOrders()) {
        // Buy if current price crosses above the moving average
        if (currentPrice > movingAverage) {
            OrderSend(Symbol(), OP_BUY, Lots, currentPrice, 3, currentPrice - StopLoss * Point, currentPrice + TakeProfit * Point);
        }
    }
}
