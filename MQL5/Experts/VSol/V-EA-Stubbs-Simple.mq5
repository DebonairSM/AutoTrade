//+------------------------------------------------------------------+
//|                                                     StubbsEA.mq5 |
//|                        VSol Software                             |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property link      ""
#property version   "2.00"
#property strict
#property description "Stubbs EA with EMA and MACD Strategy"

#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <Arrays\ArrayObj.mqh>

//--- EA Parameters
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES MainTimeframe = PERIOD_H2;  // Main Trading Timeframe [H1,H2,H4,D1]

input group "=== EMA Parameters ==="
input int EmaFastPeriod = 15;        // Fast EMA Period [8-21, step=1]
input int EmaMidPeriod = 23;         // Mid EMA Period [21-55, step=1]
input int EmaSlowPeriod = 37;        // Slow EMA Period [34-89, step=1]

input group "=== MACD Parameters ==="
input int MacdFastPeriod = 25;       // MACD Fast Length [12-34, step=2]
input int MacdSlowPeriod = 23;       // MACD Slow Length [21-55, step=1]
input int MacdSignalPeriod = 9;     // MACD Signal Length [9-21, step=2]

input group "=== ATR Settings ==="
input int ATRPeriod = 10;            // ATR Period [10-30, step=2]
input double SLMultiplier = 5;     // SL Multiplier [5.0-12.0, step=0.5]
input double TPMultiplier = 10.5;     // TP Multiplier [4.0-12.0, step=0.5]
input double SLBufferPips = 6.5;     // SL Buffer in Pips [2.0-8.0, step=0.5]

input group "=== Trailing Stop Settings ==="
input double MinimumProfitToTrail = 3.0;  // Minimum profit (ATR) before trailing [0.5-3.0, step=0.25]
input double TrailMultiplier = 2.25;       // Trail distance as ATR multiplier [1.0-3.0, step=0.25]
input bool UseFixedTrailStep = false;     // Use fixed step for trailing
input double TrailStepPips = 10.0;        // Fixed trail step in pips [10.0-50.0, step=5.0]

input group "=== Risk Management ==="
input double RiskPercentage = 5.0;   // Risk per trade (%) [0.5-5.0, step=0.5]

input group "=== Step-Out Stop Loss Settings ==="
input bool UseStepOutSL = false;        // Enable Step-Out Stop Loss
input double StepOutATRMultiplier = 0.5;  // Step-Out SL ATR Multiplier [0.3-1.0, step=0.1]
input int StepOutBarsCount = 2;        // Bars below threshold before step-out [1-5, step=1]
input double StepOutClosePercent = 100.0; // Percentage of position to close [25-100, step=25]

// Add position tracking struct
struct PositionInfo {
    ulong ticket;
    datetime openTime;
    double openPrice;
    ENUM_POSITION_TYPE type;
    int barsUnderThreshold;
};

// Global variables
PositionInfo g_positions[];
int g_positionCount = 0;

//--- Global Variables
int MagicNumber = 123456;            // Unique identifier for EA's trades
datetime lastBarTime = 0;            // Tracks the last processed bar time
int tradeDirection = 0;              // 0 = No position, 1 = Buy, -1 = Sell

// Indicator handles
int handleEmaFast;
int handleEmaMid;
int handleEmaSlow;
int handleMacd;
int handleATR;

// Trade object
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize EMA indicators
    handleEmaFast = iMA(_Symbol, MainTimeframe, EmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    handleEmaMid  = iMA(_Symbol, MainTimeframe, EmaMidPeriod,  0, MODE_EMA, PRICE_CLOSE);
    handleEmaSlow = iMA(_Symbol, MainTimeframe, EmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    // Initialize MACD indicator
    handleMacd = iMACD(_Symbol, MainTimeframe, MacdFastPeriod, MacdSlowPeriod, MacdSignalPeriod, PRICE_CLOSE);
    
    // Initialize ATR indicator
    handleATR = iATR(_Symbol, MainTimeframe, ATRPeriod);
    
    // Check if indicators are initialized successfully
    if(handleEmaFast == INVALID_HANDLE || handleEmaMid == INVALID_HANDLE || 
       handleEmaSlow == INVALID_HANDLE || handleMacd == INVALID_HANDLE || 
       handleATR == INVALID_HANDLE)
    {
        string errorMsg = "Failed to initialize indicators: ";
        if(handleEmaFast == INVALID_HANDLE) errorMsg += "Fast EMA, ";
        if(handleEmaMid == INVALID_HANDLE) errorMsg += "Mid EMA, ";
        if(handleEmaSlow == INVALID_HANDLE) errorMsg += "Slow EMA, ";
        if(handleMacd == INVALID_HANDLE) errorMsg += "MACD, ";
        if(handleATR == INVALID_HANDLE) errorMsg += "ATR, ";
        Print(errorMsg);
        return(INIT_FAILED);
    }
    
    // Set magic number and trade settings
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);
    
    Print("V-EA-Stubbs-Simple initialized successfully on ", _Symbol, " ", EnumToString(MainTimeframe));
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(handleEmaFast);
    IndicatorRelease(handleEmaMid);
    IndicatorRelease(handleEmaSlow);
    IndicatorRelease(handleMacd);
    IndicatorRelease(handleATR);
    
    Print("EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Get entry signal                                                    |
//+------------------------------------------------------------------+
bool GetEntrySignal(bool isBuy, string &signalReason)
{
    // Get current indicator values
    double emaFast = GetIndicatorValue(handleEmaFast, 0);
    double emaMid = GetIndicatorValue(handleEmaMid, 0);
    double emaSlow = GetIndicatorValue(handleEmaSlow, 0);
    double macdMain = GetIndicatorValue(handleMacd, 0, 0);
    double macdSignal = GetIndicatorValue(handleMacd, 0, 1);
    
    if(isBuy)
    {
        // Buy signal: EMA crossover (Fast crosses Mid) AND Fast > Slow AND MACD conditions
        bool emaCrossover = emaFast > emaMid && emaFast > emaSlow;
        bool macdCondition = macdMain > macdSignal || macdMain > 0;
        
        if(emaCrossover && macdCondition)
        {
            signalReason = StringFormat("📈 EMAs Aligned (Fast: %.2f > Mid: %.2f > Slow: %.2f) | MACD(%.2f > %.2f)", 
                                      emaFast, emaMid, emaSlow, macdMain, macdSignal);
            return true;
        }
    }
    else
    {
        // Sell signal: EMA crossunder (Fast crosses Mid) AND Fast < Slow AND MACD conditions
        bool emaCrossunder = emaFast < emaMid && emaFast < emaSlow;
        bool macdCondition = macdMain < macdSignal || macdMain < 0;
        
        if(emaCrossunder && macdCondition)
        {
            signalReason = StringFormat("📉 EMAs Aligned (Fast: %.2f < Mid: %.2f < Slow: %.2f) | MACD(%.2f < %.2f)", 
                                      emaFast, emaMid, emaSlow, macdMain, macdSignal);
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calculate dynamic SL/TP levels                                     |
//+------------------------------------------------------------------+
void GetDynamicSLTP(bool isBuy, double &sl, double &tp)
{
    double atr = GetIndicatorValue(handleATR, 0);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Calculate distances based on ATR
    double slDistance = atr * SLMultiplier;
    double tpDistance = atr * TPMultiplier;
    
    // Add buffer for SL
    double buffer = SLBufferPips * point;
    
    if(isBuy)
    {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);  // Use BID for more conservative SL on longs
        sl = currentPrice - slDistance - buffer;
        tp = currentPrice + tpDistance;
    }
    else
    {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);  // Use ASK for more conservative SL on shorts
        sl = currentPrice + slDistance + buffer;
        tp = currentPrice - tpDistance;
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new bar
    datetime currentBar = iTime(_Symbol, MainTimeframe, 0);
    if(currentBar <= lastBarTime)
        return;
        
    lastBarTime = currentBar;
    
    // Update position tracking on each new bar
    UpdatePositionTracking();
    
    // Check step-out conditions on each new bar
    CheckStepOutSL();
    
    // Update SL/TP for existing positions on each new bar
    if(tradeDirection != 0)
    {
        UpdatePositionSLTP();
    }
    
    // Process signals only on new bar
    if(tradeDirection == 0) // No position
    {
        OpenPositionOnSignal();
    }
    else // Have position
    {
        // Check for exit signal
        string signalReason;  // Add temporary string for signal reason
        bool buySignal = GetEntrySignal(true, signalReason);
        bool sellSignal = GetEntrySignal(false, signalReason);
        
        if((tradeDirection == 1 && sellSignal) ||
           (tradeDirection == -1 && buySignal))
        {
            if(CloseAllPositions())
            {
                int oldDirection = tradeDirection;
                tradeDirection = 0;
                Print("Position closed - Opposite signal detected");
                
                // Immediately open position in the new direction
                if(oldDirection == 1 && sellSignal)
                {
                    OpenNewPosition(false);  // Open sell position
                }
                else if(oldDirection == -1 && buySignal)
                {
                    OpenNewPosition(true);   // Open buy position
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open a new position based on signal                               |
//+------------------------------------------------------------------+
void OpenNewPosition(bool isBuy)
{
    string signalReason;
    if(!GetEntrySignal(isBuy, signalReason))
        return;
        
    double sl, tp;
    GetDynamicSLTP(isBuy, sl, tp);
    
    double entryPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lotSize = CalculateLotSize(RiskPercentage, MathAbs(entryPrice - sl));
    
    if(lotSize == 0)
    {
        Print("❌ Error: Invalid lot size calculated");
        return;
    }
    
    bool success;
    if(isBuy)
    {
        success = trade.Buy(lotSize, _Symbol, 0, sl, tp, "Buy Signal");
        if(success)
        {
            tradeDirection = 1;
            Print("🔵 LONG Entry | ", signalReason);
            Print("💰 Price: ", entryPrice, " | SL: ", sl, " (", NormalizeDouble(MathAbs(entryPrice-sl)/Point(),1), " pips) | ",
                  "TP: ", tp, " (", NormalizeDouble(MathAbs(tp-entryPrice)/Point(),1), " pips) | Lots: ", lotSize);
        }
    }
    else
    {
        success = trade.Sell(lotSize, _Symbol, 0, sl, tp, "Sell Signal");
        if(success)
        {
            tradeDirection = -1;
            Print("🔴 SHORT Entry | ", signalReason);
            Print("💰 Price: ", entryPrice, " | SL: ", sl, " (", NormalizeDouble(MathAbs(entryPrice-sl)/Point(),1), " pips) | ",
                  "TP: ", tp, " (", NormalizeDouble(MathAbs(tp-entryPrice)/Point(),1), " pips) | Lots: ", lotSize);
        }
    }
    
    if(!success)
    {
        Print("❌ ", (isBuy ? "Buy" : "Sell"), " order failed. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Process signals and open position if needed                        |
//+------------------------------------------------------------------+
void OpenPositionOnSignal()
{
    string signalReason;  // Add temporary string for signal reason
    if(GetEntrySignal(true, signalReason))
    {
        OpenNewPosition(true);
    }
    else if(GetEntrySignal(false, signalReason))
    {
        OpenNewPosition(false);
    }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double slDistance)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (riskPercent / 100.0);
    
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(tickSize == 0 || slDistance == 0)
        return 0;
        
    double riskedLots = riskAmount / (slDistance * (tickValue / tickSize));
    
    // Normalize lot size
    riskedLots = MathFloor(riskedLots / lotStep) * lotStep;
    
    // Apply lot limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    riskedLots = MathMax(minLot, MathMin(maxLot, riskedLots));
    
    return NormalizeDouble(riskedLots, 2);
}

//+------------------------------------------------------------------+
//| Get indicator buffer value                                          |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int shift, int buffer = 0)
{
    double value[];
    ArraySetAsSeries(value, true);
    
    if(CopyBuffer(handle, buffer, shift, 1, value) > 0)
        return value[0];
        
    return 0.0;
}

//+------------------------------------------------------------------+
//| Close all open positions                                          |
//+------------------------------------------------------------------+
bool CloseAllPositions()
{
    bool success = true;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
            double closePrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            if(!trade.PositionClose(ticket))
            {
                Print("❌ Failed to close position #", ticket, ". Error: ", GetLastError());
                success = false;
            }
            else
            {
                Print((isLong ? "🔵" : "🔴"), " Closed ", (isLong ? "LONG" : "SHORT"), " #", ticket,
                      " | Profit: $", NormalizeDouble(profit, 2),
                      " (", NormalizeDouble(MathAbs(closePrice-openPrice)/Point(),1), " pips)");
            }
        }
    }
    return success;
}

//+------------------------------------------------------------------+
//| Update SL/TP levels for existing positions                         |
//+------------------------------------------------------------------+
void UpdatePositionSLTP()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
            double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            // Calculate current profit in ATR terms
            double atr = GetIndicatorValue(handleATR, 0);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double profitInPrice = isLong ? (currentPrice - openPrice) : (openPrice - currentPrice);
            double profitInATR = profitInPrice / atr;
            
            // Only trail if we have minimum profit
            if(profitInATR < MinimumProfitToTrail)
                continue;
                
            // Calculate trail distance
            double trailDistance;
            if(UseFixedTrailStep)
            {
                trailDistance = TrailStepPips * point;
            }
            else
            {
                trailDistance = atr * TrailMultiplier;
            }
            
            double buffer = SLBufferPips * point;
            double newSL;
            
            if(isLong)
            {
                newSL = currentPrice - trailDistance - buffer;
                if(newSL > currentSL)
                {
                    trade.PositionModify(ticket, newSL, currentTP);
                    Print("📍 Trail Long #", ticket, " | Profit: ", NormalizeDouble(profitInATR, 2), " ATR | New SL: ", 
                          newSL, " (", NormalizeDouble(MathAbs(currentPrice-newSL)/Point(),1), " pips from price)");
                }
            }
            else
            {
                newSL = currentPrice + trailDistance + buffer;
                if(newSL < currentSL || currentSL == 0)
                {
                    trade.PositionModify(ticket, newSL, currentTP);
                    Print("📍 Trail Short #", ticket, " | Profit: ", NormalizeDouble(profitInATR, 2), " ATR | New SL: ", 
                          newSL, " (", NormalizeDouble(MathAbs(currentPrice-newSL)/Point(),1), " pips from price)");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check for step-out stop loss conditions                            |
//+------------------------------------------------------------------+
void CheckStepOutSL()
{
    if(!UseStepOutSL) return;
    
    double atr = GetIndicatorValue(handleATR, 0);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double stepOutThreshold = atr * StepOutATRMultiplier;
    
    for(int i = g_positionCount - 1; i >= 0; i--)
    {
        if(g_positions[i].ticket <= 0) continue;
        
        // Verify position still exists and get current price
        if(!PositionSelectByTicket(g_positions[i].ticket)) continue;
        
        bool isLong = (g_positions[i].type == POSITION_TYPE_BUY);
        double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double profitInPrice = isLong ? (currentPrice - g_positions[i].openPrice) : (g_positions[i].openPrice - currentPrice);
        
        // Check if position is below step-out threshold
        if(profitInPrice < -stepOutThreshold)
        {
            g_positions[i].barsUnderThreshold++;
            
            if(g_positions[i].barsUnderThreshold >= StepOutBarsCount)
            {
                double closeVolume = PositionGetDouble(POSITION_VOLUME) * (StepOutClosePercent / 100.0);
                
                Print("=== STEP-OUT STOP LOSS TRIGGERED ===");
                Print("Position Type: ", EnumToString(g_positions[i].type));
                Print("Entry Price: ", g_positions[i].openPrice);
                Print("Current Price: ", currentPrice);
                Print("Loss in ATR: ", MathAbs(profitInPrice/atr));
                Print("Bars under threshold: ", g_positions[i].barsUnderThreshold);
                Print("Closing ", StepOutClosePercent, "% of position");
                
                if(trade.PositionClosePartial(g_positions[i].ticket, closeVolume))
                {
                    Print("Successfully executed step-out for position #", g_positions[i].ticket);
                    
                    // If closing entire position, update tracking
                    if(StepOutClosePercent >= 100.0)
                    {
                        UpdatePositionTracking();
                        
                        // Check if this was the last position
                        if(g_positionCount == 0)
                        {
                            tradeDirection = 0;
                            Print("=== TRADE DIRECTION RESET ===");
                            Print("Reason: All positions closed after step-out stop loss");
                        }
                    }
                }
            }
            else
            {
                Print("Position #", g_positions[i].ticket, " below step-out threshold for ", 
                      g_positions[i].barsUnderThreshold, "/", StepOutBarsCount, " bars");
            }
        }
        else
        {
            // Reset counter if position moves back above threshold
            g_positions[i].barsUnderThreshold = 0;
        }
    }
}

//+------------------------------------------------------------------+
//| Update tracked positions                                           |
//+------------------------------------------------------------------+
void UpdatePositionTracking()
{
    // Store existing bars under threshold for positions that still exist
    int oldPositionCount = g_positionCount;
    PositionInfo oldPositions[];
    ArrayCopy(oldPositions, g_positions);
    
    // Reset position array
    ArrayResize(g_positions, 0);
    g_positionCount = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            ArrayResize(g_positions, g_positionCount + 1);
            g_positions[g_positionCount].ticket = ticket;
            g_positions[g_positionCount].openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            g_positions[g_positionCount].openTime = (datetime)PositionGetInteger(POSITION_TIME);
            g_positions[g_positionCount].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Preserve bars under threshold count for existing positions
            for(int j = 0; j < oldPositionCount; j++)
            {
                if(oldPositions[j].ticket == ticket)
                {
                    g_positions[g_positionCount].barsUnderThreshold = oldPositions[j].barsUnderThreshold;
                    break;
                }
            }
            
            g_positionCount++;
        }
    }
}