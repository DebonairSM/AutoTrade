//+------------------------------------------------------------------+
//| QuantumTraderAI.mq5                                              |
//| Your Name or Company                                             |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
//#include <Errors.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+

// Strategy Activation
input bool UseTrendStrategy = true;         // Enable or disable the Trend Following strategy
input bool UseScalpingStrategy = true;      // Enable or disable the Scalping strategy
input bool UseCounterTrendStrategy = true;  // Enable or disable the Counter-Trend strategy

// Risk Management
input double RiskPercent = 1.0;             // Percentage of account equity risked per trade
input double MaxDrawdownPercent = 15.0;     // Maximum drawdown percentage allowed before trading halts

// Execution Settings
input double Aggressiveness = 1.0;          // Factor to adjust trade aggressiveness
input double RecoveryFactor = 1.2;          // Multiplier for lot size in recovery mode to regain losses
input double ATRMultiplier = 1.5;           // Multiplier for ATR to set dynamic SL/TP

// Scalping Parameters
input double ScalpingThreshold = 0.8;       // Sensitivity threshold for identifying favorable scalping conditions

// Counter-Trend Parameters
input double OverboughtLevel = 80.0;        // Stochastic indicator level above which the market is considered overbought
input double OversoldLevel = 20.0;          // Stochastic indicator level below which the market is considered oversold

// Other Parameters
input double ImbalanceThreshold = 1.5;      // Sensitivity to volume imbalance
input double LiquidityThreshold = 100;      // Threshold for identifying liquidity pools

//+------------------------------------------------------------------+
//| Global Variables and Objects                                     |
//+------------------------------------------------------------------+
CTrade trade;

//+------------------------------------------------------------------+
//| Helper function to get indicator value                           |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int bufferIndex, int shift = 0)
{
    double value[];
    if (CopyBuffer(handle, bufferIndex, shift, 1, value) > 0)
    {
        return value[0];
    }
    else
    {
        Print("Error copying data from indicator handle: ", GetLastError());
        return 0;
    }
}

//+------------------------------------------------------------------+
//| Indicator Calculation Functions                                  |
//+------------------------------------------------------------------+
double CalculateStochastic(int kPeriod, int dPeriod, int slowing, int shift = 0)
{
    int handle = iStochastic(_Symbol, PERIOD_CURRENT, kPeriod, dPeriod, slowing, MODE_SMA, STO_LOWHIGH);
    return GetIndicatorValue(handle, 0, shift); // %K line is buffer 0
}

double CalculateCCI(int period, int shift = 0)
{
    int handle = iCCI(_Symbol, PERIOD_CURRENT, period, PRICE_TYPICAL);
    return GetIndicatorValue(handle, 0, shift);
}

double CalculateSMA(int period, int shift = 0)
{
    int handle = iMA(_Symbol, PERIOD_CURRENT, period, 0, MODE_SMA, PRICE_CLOSE);
    return GetIndicatorValue(handle, 0, shift);
}

double CalculateEMA(int period, int shift = 0)
{
    int handle = iMA(_Symbol, PERIOD_CURRENT, period, 0, MODE_EMA, PRICE_CLOSE);
    return GetIndicatorValue(handle, 0, shift);
}

double CalculateRSI(int period, int shift = 0)
{
    int handle = iRSI(_Symbol, PERIOD_CURRENT, period, PRICE_CLOSE);
    return GetIndicatorValue(handle, 0, shift);
}

double CalculateATR(int period, int shift = 0)
{
    int handle = iATR(_Symbol, PERIOD_CURRENT, period);
    return GetIndicatorValue(handle, 0, shift);
}

//+------------------------------------------------------------------+
//| Identify Overbought/Oversold Conditions                          |
//+------------------------------------------------------------------+
bool IsOverbought(double stochastic, double cci)
{
    return (stochastic > OverboughtLevel && cci > 100); // Use input parameter
}

bool IsOversold(double stochastic, double cci)
{
    return (stochastic < OversoldLevel && cci < -100); // Use input parameter
}

//+------------------------------------------------------------------+
//| Access Depth of Market Data                                      |
//+------------------------------------------------------------------+
bool GetMarketDepthData(MqlBookInfo &book[])
{
    int depth = MarketBookGet(_Symbol, book);
    return (depth > 0);
}

//+------------------------------------------------------------------+
//| Check DOM Liquidity Gaps                                         |
//+------------------------------------------------------------------+
bool CheckDOMLiquidityGaps(MqlBookInfo &book[], int depth)
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Check for low liquidity at key price levels
    for (int i = 0; i < depth; i++)
    {
        if ((MathAbs(book[i].price - bid) < point * 5 ||
             MathAbs(book[i].price - ask) < point * 5) &&
            book[i].volume < 10)
            return true; // Example threshold for low liquidity
    }
    return false;
}

//+------------------------------------------------------------------+
//| Generate Counter-Trend Trade Signals                             |
//+------------------------------------------------------------------+
void GenerateCounterTrendSignals()
{
    double stochastic = CalculateStochastic(14, 3, 3);
    double cci = CalculateCCI(20);

    MqlBookInfo book[32];
    if (!GetMarketDepthData(book))
        return;

    int depth = ArraySize(book);

    if (IsOverbought(stochastic, cci) && CheckDOMLiquidityGaps(book, depth))
    {
        Print("Counter-Trend: Sell Signal Generated");
        PlaceSellOrder();
    }
    else if (IsOversold(stochastic, cci) && CheckDOMLiquidityGaps(book, depth))
    {
        Print("Counter-Trend: Buy Signal Generated");
        PlaceBuyOrder();
    }
}

//+------------------------------------------------------------------+
//| Process DOM Data                                                 |
//+------------------------------------------------------------------+
void ProcessDOMData(const MqlBookInfo &book_info[], int book_count, double &buyVolume, double &sellVolume,
                    double &buyVolumeAtLevel[], double &sellVolumeAtLevel[], double &priceLevels[], int &levelCount)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    for (int i = 0; i < book_count; i++)
    {
        double price = book_info[i].price;
        int index = -1;
        for (int j = 0; j < levelCount; j++)
        {
            if (MathAbs(priceLevels[j] - price) < point)
            {
                index = j;
                break;
            }
        }

        if (index < 0) // New price level
        {
            priceLevels[levelCount] = price;
            buyVolumeAtLevel[levelCount] = 0.0;
            sellVolumeAtLevel[levelCount] = 0.0;
            index = levelCount;
            levelCount++;
        }

        if (book_info[i].type == BOOK_TYPE_BUY)
        {
            buyVolume += book_info[i].volume;
            buyVolumeAtLevel[index] += book_info[i].volume;
        }
        else if (book_info[i].type == BOOK_TYPE_SELL)
        {
            sellVolume += book_info[i].volume;
            sellVolumeAtLevel[index] += book_info[i].volume;
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Order Imbalances                                          |
//+------------------------------------------------------------------+
void DetectOrderImbalances(double buyVolume, double sellVolume)
{
    double imbalanceRatio = (sellVolume > 0.0) ? buyVolume / sellVolume : 0.0;

    if (imbalanceRatio > ImbalanceThreshold)
    {
        Print("Significant Buy Imbalance Detected: Potential Upward Breakout");
        Alert("Buy Imbalance Detected: Potential Upward Breakout");
        PlaceBuyOrder();
    }
    else if (imbalanceRatio < 1.0 / ImbalanceThreshold)
    {
        Print("Significant Sell Imbalance Detected: Potential Downward Breakout");
        Alert("Sell Imbalance Detected: Potential Downward Breakout");
        PlaceSellOrder();
    }
}

//+------------------------------------------------------------------+
//| Identify Liquidity Pools                                         |
//+------------------------------------------------------------------+
void IdentifyLiquidityPools(const double &buyVolumeAtLevel[], const double &sellVolumeAtLevel[],
                            const double &priceLevels[], int levelCount)
{
    for (int i = 0; i < levelCount; i++)
    {
        double totalVolume = buyVolumeAtLevel[i] + sellVolumeAtLevel[i];
        if (totalVolume > LiquidityThreshold)
        {
            if (buyVolumeAtLevel[i] > sellVolumeAtLevel[i])
            {
                Print("Support Zone Detected at Price: ", priceLevels[i], " with Buy Volume: ", buyVolumeAtLevel[i]);
                Alert("Support Zone Detected at Price: ", priceLevels[i]);
                // Placeholder for support zone logic
            }
            else
            {
                Print("Resistance Zone Detected at Price: ", priceLevels[i], " with Sell Volume: ", sellVolumeAtLevel[i]);
                Alert("Resistance Zone Detected at Price: ", priceLevels[i]);
                // Placeholder for resistance zone logic
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Monitor DOM                                                      |
//+------------------------------------------------------------------+
void MonitorDOM()
{
    MqlBookInfo book_info[];
    int book_count = MarketBookGet(_Symbol, book_info);
    if (book_count > 0)
    {
        double buyVolume = 0.0;
        double sellVolume = 0.0;
        double buyVolumeAtLevel[100];
        double sellVolumeAtLevel[100];
        double priceLevels[100];
        int levelCount = 0;

        // Initialize arrays
        ArrayInitialize(buyVolumeAtLevel, 0.0);
        ArrayInitialize(sellVolumeAtLevel, 0.0);
        ArrayInitialize(priceLevels, 0.0);

        // Process DOM data
        ProcessDOMData(book_info, book_count, buyVolume, sellVolume, buyVolumeAtLevel, sellVolumeAtLevel, priceLevels, levelCount);

        // Detect order imbalances
        DetectOrderImbalances(buyVolume, sellVolume);

        // Identify liquidity pools
        IdentifyLiquidityPools(buyVolumeAtLevel, sellVolumeAtLevel, priceLevels, levelCount);
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk Percentage and Stop Loss        |
//+------------------------------------------------------------------+
double CalculateLotSize(double risk_percent, double stop_loss_pips)
{
    // Retrieve account and symbol information
    double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    // Calculate the risk amount in account currency
    double risk_amount = account_equity * risk_percent / 100.0;

    // Calculate the lot size based on risk and stop-loss distance
    double lot_size = risk_amount / (stop_loss_pips * tick_value / tick_size);

    // Ensure the lot size is within broker constraints
    lot_size = MathMax(min_lot, MathMin(lot_size, max_lot));

    Print("Calculated Lot Size: ", lot_size);
    return lot_size;
}

//+------------------------------------------------------------------+
//| Calculate Recovery Lot Size                                      |
//+------------------------------------------------------------------+
double CalculateRecoveryLotSize(double stop_loss_pips, double starting_balance)
{
    // Retrieve current account equity
    double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    // Retrieve broker's minimum and maximum lot sizes
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    // Calculate base lot size using standard risk management
    double base_lot_size = CalculateLotSize(RiskPercent, stop_loss_pips);

    // Define equity threshold for activating recovery mode
    double equity_threshold = starting_balance * 0.8; // Example: 80% of starting balance
    if (account_equity < equity_threshold)
    {
        // Increase lot size slightly for recovery, capped at 150% of base lot size
        double recovery_lot_size = base_lot_size * RecoveryFactor;
        recovery_lot_size = MathMin(recovery_lot_size, base_lot_size * 1.5);

        // Ensure the recovery lot size is within broker constraints
        recovery_lot_size = MathMax(min_lot, MathMin(recovery_lot_size, max_lot));

        Print("Recovery Mode Active: Adjusted Lot Size: ", recovery_lot_size);
        return recovery_lot_size;
    }

    // Return base lot size if no recovery is needed
    return base_lot_size;
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
    // Calculate ATR for volatility measurement
    double atr = CalculateATR(14); // 14-period ATR

    // Define SL/TP based on ATR
    stop_loss = atr * atr_multiplier;
    take_profit = atr * atr_multiplier * 2.0; // Example: TP is twice the SL distance

    Print("Dynamic SL: ", stop_loss, " | Dynamic TP: ", take_profit);
}

//+------------------------------------------------------------------+
//| Place Order with Dynamic SL/TP                                   |
//+------------------------------------------------------------------+
void PlaceOrderWithDynamicSLTP(double lot_size, double stop_loss, double take_profit)
{
    int signal = TrendFollowingCore();

    if (signal == 1)
    {
        Print("Placing Buy Order with Dynamic SL/TP");
        PlaceBuyOrderWithSLTP(lot_size, stop_loss, take_profit);
    }
    else if (signal == -1)
    {
        Print("Placing Sell Order with Dynamic SL/TP");
        PlaceSellOrderWithSLTP(lot_size, stop_loss, take_profit);
    }
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
//| Execute Trading Logic                                            |
//+------------------------------------------------------------------+
void ExecuteTradingLogic(double starting_balance)
{
    // Check drawdown before executing any trades
    if (CheckDrawdown())
    {
        // Trading is halted due to excessive drawdown
        return;
    }

    // Execute Trend Strategy if enabled
    if (UseTrendStrategy)
    {
        int trendSignal = TrendFollowingCore();
        if (trendSignal == 1)
        {
            PlaceBuyOrder();
        }
        else if (trendSignal == -1)
        {
            PlaceSellOrder();
        }
    }

    // Execute Scalping Strategy if enabled
    if (UseScalpingStrategy)
    {
        int scalpingSignal = ScalpingModule();
        if (scalpingSignal == 1)
        {
            PlaceBuyOrder();
        }
        else if (scalpingSignal == -1)
        {
            PlaceSellOrder();
        }
    }

    // Execute Counter-Trend Strategy if enabled
    if (UseCounterTrendStrategy)
    {
        int counterTrendSignal = CounterTrendTrading();
        if (counterTrendSignal == 1)
        {
            PlaceBuyOrder();
        }
        else if (counterTrendSignal == -1)
        {
            PlaceSellOrder();
        }
    }
}

//+------------------------------------------------------------------+
//| Placeholder for Order Placement Functions                        |
//+------------------------------------------------------------------+
void PlaceBuyOrder()
{
    double stop_loss_pips = 20; // Example value
    double take_profit_pips = 40; // Example value
    double lot_size = CalculateLotSize(RiskPercent, stop_loss_pips);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = price - stop_loss_pips * _Point;
    double tp = price + take_profit_pips * _Point;

    trade.Buy(lot_size, _Symbol, price, sl, tp, "Buy Order");
    LogTradeDetails(lot_size, stop_loss_pips, take_profit_pips);
}

void PlaceSellOrder()
{
    double stop_loss_pips = 20; // Example value
    double take_profit_pips = 40; // Example value
    double lot_size = CalculateLotSize(RiskPercent, stop_loss_pips);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = price + stop_loss_pips * _Point;
    double tp = price - take_profit_pips * _Point;

    trade.Sell(lot_size, _Symbol, price, sl, tp, "Sell Order");
    LogTradeDetails(lot_size, stop_loss_pips, take_profit_pips);
}

void PlaceBuyOrderWithSLTP(double lot_size, double stop_loss, double take_profit)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = price - stop_loss;
    double tp = price + take_profit;

    trade.Buy(lot_size, _Symbol, price, sl, tp, "Buy Order with Dynamic SL/TP");
    LogTradeDetails(lot_size, stop_loss, take_profit);
}

void PlaceSellOrderWithSLTP(double lot_size, double stop_loss, double take_profit)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = price + stop_loss;
    double tp = price - take_profit;

    trade.Sell(lot_size, _Symbol, price, sl, tp, "Sell Order with Dynamic SL/TP");
    LogTradeDetails(lot_size, stop_loss, take_profit);
}

//+------------------------------------------------------------------+
//| Trend Following Core Strategy                                    |
//+------------------------------------------------------------------+
int TrendFollowingCore()
{
    double sma = CalculateSMA(50);
    double ema = CalculateEMA(20);
    double rsi = CalculateRSI(14);
    double atr = CalculateATR(14); // Calculate ATR for volatility measurement

    // Determine trend and generate signals
    if (ema > sma && rsi > 50 && atr > 0.0001)
    {
        Print("Trend Following: Buy Signal");
        return 1; // Buy signal
    }
    else if (ema < sma && rsi < 50 && atr > 0.0001)
    {
        Print("Trend Following: Sell Signal");
        return -1; // Sell signal
    }
    return 0; // Hold signal
}

//+------------------------------------------------------------------+
//| Monitor Order Flow                                               |
//+------------------------------------------------------------------+
void MonitorOrderFlow()
{
    MqlBookInfo book_info[];
    int book_count = MarketBookGet(_Symbol, book_info);
    if (book_count > 0)
    {
        double buyVolume = 0.0;
        double sellVolume = 0.0;
        double liquidityThreshold = 50.0; // Example threshold for identifying liquidity pools

        // Loop through DOM data and analyze order flow
        for (int i = 0; i < book_count; i++)
        {
            Print("Price: ", book_info[i].price,
                  " | Volume: ", book_info[i].volume,
                  " | Type: ", book_info[i].type);

            // Accumulate buy and sell volumes
            if (book_info[i].type == BOOK_TYPE_BUY)
                buyVolume += book_info[i].volume;
            else if (book_info[i].type == BOOK_TYPE_SELL)
                sellVolume += book_info[i].volume;

            // Identify liquidity pools
            if (book_info[i].volume > liquidityThreshold)
            {
                Print("Liquidity Pool Detected at Price: ", book_info[i].price);
            }
        }

        // Detect order flow imbalances
        if (buyVolume > sellVolume * 1.5) // Example imbalance threshold
        {
            Print("Order Flow Imbalance Detected: More Buy Orders");
            // Signal potential upward price movement
        }
        else if (sellVolume > buyVolume * 1.5)
        {
            Print("Order Flow Imbalance Detected: More Sell Orders");
            // Signal potential downward price movement
        }
    }
}

//+------------------------------------------------------------------+
//| Scalping Module Strategy                                         |
//+------------------------------------------------------------------+
int ScalpingModule()
{
    MqlBookInfo book[32];
    if (!GetMarketDepthData(book))
        return 0; // Hold if no data

    int depth = ArraySize(book);
    if (IsFavorableScalpingCondition(book, depth))
    {
        Print("Scalping: Favorable Conditions Detected");
        // Implement specific buy/sell logic here
        return 1; // Example: Buy signal
    }
    return 0; // Hold signal
}

//+------------------------------------------------------------------+
//| Placeholder for Scalping Condition Function                      |
//+------------------------------------------------------------------+
bool IsFavorableScalpingCondition(MqlBookInfo &book[], int depth)
{
    // Placeholder logic for favorable scalping conditions
    // For now, we'll return false to avoid compilation errors
    return false;
}

//+------------------------------------------------------------------+
//| Counter-Trend Trading Strategy                                   |
//+------------------------------------------------------------------+
int CounterTrendTrading()
{
    double stochastic = CalculateStochastic(14, 3, 3);
    double cci = CalculateCCI(20);

    MqlBookInfo book[32];
    if (!GetMarketDepthData(book))
        return 0; // Hold if no data

    int depth = ArraySize(book);

    if (IsOverbought(stochastic, cci) && CheckDOMLiquidityGaps(book, depth))
    {
        Print("Counter-Trend: Sell Signal");
        return -1; // Sell signal
    }
    else if (IsOversold(stochastic, cci) && CheckDOMLiquidityGaps(book, depth))
    {
        Print("Counter-Trend: Buy Signal");
        return 1; // Buy signal
    }
    return 0; // Hold signal
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
        return;
    }

    // Validate MaxDrawdownPercent
    if (MaxDrawdownPercent <= 0.0 || MaxDrawdownPercent > 100.0)
    {
        Alert("MaxDrawdownPercent must be between 0.1 and 100.0");
        return;
    }

    // Validate RecoveryFactor
    if (RecoveryFactor < 1.0 || RecoveryFactor > 2.0)
    {
        Alert("RecoveryFactor must be between 1.0 and 2.0");
        return;
    }

    // Validate ATRMultiplier
    if (ATRMultiplier <= 0.0 || ATRMultiplier > 5.0)
    {
        Alert("ATRMultiplier must be between 0.1 and 5.0");
        return;
    }

    // Validate ScalpingThreshold
    if (ScalpingThreshold <= 0.0 || ScalpingThreshold > 2.0)
    {
        Alert("ScalpingThreshold must be between 0.1 and 2.0");
        return;
    }

    // Validate OverboughtLevel
    if (OverboughtLevel <= 50.0 || OverboughtLevel > 100.0)
    {
        Alert("OverboughtLevel must be between 50.1 and 100.0");
        return;
    }

    // Validate OversoldLevel
    if (OversoldLevel < 0.0 || OversoldLevel >= 50.0)
    {
        Alert("OversoldLevel must be between 0.0 and 49.9");
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

    // Print current configurations to the journal/log
    Print("Configuration: ");
    Print("  UseTrendStrategy=", UseTrendStrategy);
    Print("  UseScalpingStrategy=", UseScalpingStrategy);
    Print("  UseCounterTrendStrategy=", UseCounterTrendStrategy);
    Print("  RiskPercent=", RiskPercent);
    Print("  MaxDrawdownPercent=", MaxDrawdownPercent);
    Print("  Aggressiveness=", Aggressiveness);
    Print("  RecoveryFactor=", RecoveryFactor);
    Print("  ATRMultiplier=", ATRMultiplier);
    Print("  ScalpingThreshold=", ScalpingThreshold);
    Print("  OverboughtLevel=", OverboughtLevel);
    Print("  OversoldLevel=", OversoldLevel);

    // Additional initialization code can be added here

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main OnTick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static double starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);

    // Execute trading logic on each tick
    ExecuteTradingLogic(starting_balance);

    // Generate counter-trend signals
    if (UseCounterTrendStrategy)
    {
        GenerateCounterTrendSignals();
    }

    // Monitor order flow
    MonitorOrderFlow();

    // Additional strategies can be called here
    if (UseScalpingStrategy)
    {
        int scalping_signal = ScalpingModule();
        if (scalping_signal != 0)
        {
            // Implement scalping trade logic
        }
    }
}

//+------------------------------------------------------------------+
//| Cleanup Code                                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Deinitializing EA...");
}
