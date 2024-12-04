//+------------------------------------------------------------------+
//| QuantumTraderAI_TrendFollowing.mq5                               |
//| VSol Software                                                    |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.02"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+

// Strategy Activation
input bool UseTrendStrategy = true;         // Enable or disable the Trend Following strategy

// Risk Management
input double RiskPercent = 2.0;             // Percentage of account equity risked per trade
input double MaxDrawdownPercent = 15.0;     // Maximum drawdown percentage allowed before trading halts

// Execution Settings
input double Aggressiveness = 1.0;          // Factor to adjust trade aggressiveness
input double RecoveryFactor = 1.2;          // Multiplier for lot size in recovery mode to regain losses
input double ATRMultiplier = 1.0;           // Multiplier for ATR to set dynamic SL/TP

// ADX Parameters
input int ADXPeriod = 14;                   // ADX indicator period
input double TrendADXThreshold = 15.0;      // ADX threshold for Trend Following strategy

// Time Filters
input string TradingStartTime = "00:00";    // Start of trading time (expanded)
input string TradingEndTime = "23:59";      // End of trading time (expanded)

// Trailing Stop Settings
input bool UseTrailingStop = false;          // Enable or disable trailing stops
input double TrailingStopPips = 20.0;       // Trailing stop distance in pips

// Breakeven Settings
input bool UseBreakeven = true;             // Enable or disable breakeven mechanism
input double BreakevenActivationPips = 30.0;// Profit in pips to activate breakeven
input double BreakevenOffsetPips = 5.0;     // Offset in pips from entry price when moving SL to breakeven

// DOM Analysis Settings
input bool UseDOMAnalysis = false;          // Disable DOM analysis to reduce constraints
input double LiquidityThreshold = 50.0;     // Threshold volume to identify liquidity pools
input double ImbalanceThreshold = 1.5;      // Ratio to detect order flow imbalances

// Timeframe Setting
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1; // Default to 1-Hour timeframe

// Stop Loss Settings
input double fixedStopLossPips = 20.0;    // Fixed Stop Loss in pips

//+------------------------------------------------------------------+
//| Global Variables and Objects                                     |
//+------------------------------------------------------------------+
CTrade trade;
double starting_balance;

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

double CalculateADX(int period, int shift = 0)
{
    int handle = iADX(_Symbol, Timeframe, period);
    if (handle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("Failed to create ADX handle: ", error);
        ResetLastError();
        return 0;
    }
    double value = GetIndicatorValue(handle, 0, shift); // ADX is buffer 0
    IndicatorRelease(handle);
    return value;
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
//| Calculate Recovery Lot Size                                      |
//+------------------------------------------------------------------+
double CalculateRecoveryLotSize(double stop_loss_pips)
{
    // Retrieve current account equity
    double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    // Retrieve broker's minimum and maximum lot sizes
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

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

        // Adjust lot size to valid volume step
        recovery_lot_size = MathFloor(recovery_lot_size / lot_step) * lot_step;

        // Ensure the adjusted lot size is not less than minimum lot
        recovery_lot_size = MathMax(recovery_lot_size, min_lot);

        // Normalize lot size to avoid floating-point issues
        int volume_step_digits = GetVolumeStepDigits(lot_step);
        recovery_lot_size = NormalizeDouble(recovery_lot_size, volume_step_digits);

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
    double adx = CalculateADX(ADXPeriod);

    // Determine trend and generate signals
    if (ema > sma && rsi > 50 && adx > TrendADXThreshold)
    {
        Print("Trend Following: Buy Signal");
        return 1; // Buy signal
    }
    else if (ema < sma && rsi < 50 && adx > TrendADXThreshold)
    {
        Print("Trend Following: Sell Signal");
        return -1; // Sell signal
    }
    return 0; // Hold signal
}

//+------------------------------------------------------------------+
//| Check for Open Positions                                         |
//+------------------------------------------------------------------+
bool HasOpenPosition(int type)
{
    int total = PositionsTotal();
    for (int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (PositionGetInteger(POSITION_TYPE) == type && PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Order Placement Functions                        |
//+------------------------------------------------------------------+
void PlaceBuyOrder()
{
    double stop_loss, take_profit;
    CalculateDynamicSLTP(stop_loss, take_profit, ATRMultiplier);

    double lot_size = CalculateRecoveryLotSize(stop_loss / _Point);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = price - stop_loss;
    double tp = price + take_profit;

    // Normalize SL and TP
    int price_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);

    if (trade.Buy(lot_size, _Symbol, price, sl, tp, "Buy Order with Dynamic SL/TP"))
    {
        LogTradeDetails(lot_size, stop_loss, take_profit);
    }
    else
    {
        int error = GetLastError();
        Print("Buy Order Failed with Error: ", error);
        ResetLastError();
    }
}

void PlaceSellOrder()
{
    double atr_multiplier = ATRMultiplier; // Use the input parameter
    double stop_loss, take_profit;
    CalculateDynamicSLTP(stop_loss, take_profit, atr_multiplier);

    double lot_size = CalculateRecoveryLotSize(stop_loss / _Point);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = price + stop_loss;
    double tp = price - take_profit;

    // Normalize SL and TP
    int price_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, price_digits);
    tp = NormalizeDouble(tp, price_digits);

    if (trade.Sell(lot_size, _Symbol, price, sl, tp, "Sell Order with Dynamic SL/TP"))
    {
        LogTradeDetails(lot_size, stop_loss, take_profit);
    }
    else
    {
        int error = GetLastError();
        Print("Sell Order Failed with Error: ", error);
        ResetLastError();
    }
}

//+------------------------------------------------------------------+
//| Monitor Open Positions                                           |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    int total = PositionsTotal();
    for (int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            string symbol = PositionGetString(POSITION_SYMBOL);
            if (symbol != _Symbol)
                continue;

            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            double stop_loss = PositionGetDouble(POSITION_SL);
            int type = PositionGetInteger(POSITION_TYPE);
            double profit = PositionGetDouble(POSITION_PROFIT);

            // Implement Trailing Stop
            if (UseTrailingStop)
                ApplyTrailingStop(ticket, type, open_price, stop_loss);

            // Implement Breakeven
            if (UseBreakeven)
                ApplyBreakeven(ticket, type, open_price, stop_loss);
        }
    }
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
            trade.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP));
            Print("Trailing Stop Updated for Buy Position ", ticket);
        }
    }
    else if (type == POSITION_TYPE_SELL)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        new_stop_loss = price + trailing_stop;

        if (new_stop_loss < stop_loss || stop_loss == 0.0)
        {
            trade.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP));
            Print("Trailing Stop Updated for Sell Position ", ticket);
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
                trade.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP));
                Print("Breakeven Activated for Buy Position ", ticket);
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
                trade.PositionModify(ticket, new_stop_loss, PositionGetDouble(POSITION_TP));
                Print("Breakeven Activated for Sell Position ", ticket);
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

        if (imbalanceSignal == 1 && !HasOpenPosition(POSITION_TYPE_BUY) && rsi < 30)
        {
            PlaceBuyOrder();
        }
        else if (imbalanceSignal == -1 && !HasOpenPosition(POSITION_TYPE_SELL) && rsi > 70)
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
//| Execute Trading Logic                                            |
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
    ManageOpenPositions();

    // Execute Trend Strategy if enabled
    if (UseTrendStrategy)
    {
        int trendSignal = TrendFollowingCore();
        if (trendSignal == 1 && !HasOpenPosition(POSITION_TYPE_BUY))
        {
            PlaceBuyOrder();
        }
        else if (trendSignal == -1 && !HasOpenPosition(POSITION_TYPE_SELL))
        {
            PlaceSellOrder();
        }
    }

    // Monitor order flow
    MonitorOrderFlow();
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
