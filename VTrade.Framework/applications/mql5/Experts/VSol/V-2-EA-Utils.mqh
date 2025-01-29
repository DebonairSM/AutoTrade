//+------------------------------------------------------------------+
//|                                                 V-2-EA-Utils.mqh |
//|                                    Common Trading Utility Functions|
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.00"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Trading Utility Class                                              |
//+------------------------------------------------------------------+
class CV2EAUtils
{
private:
    static CTrade     m_trade;           // Trading object
    static bool       m_showDebugPrints; // Debug mode
    
    // Session control defaults
    static bool       m_restrictTradingHours;
    static int        m_londonOpenHour;
    static int        m_londonCloseHour;
    static int        m_newYorkOpenHour;
    static int        m_newYorkCloseHour;
    static int        m_brokerToLocalOffsetHours;

public:
    //--- Initialization
    static void Init(bool showDebugPrints)
    {
        m_showDebugPrints = showDebugPrints;
    }
    
    //--- Set magic number for trades
    static void SetMagicNumber(int magicNumber)
    {
        m_trade.SetExpertMagicNumber(magicNumber);
    }
    
    //--- Session Control Setup
    static void SetSessionControl(bool restrictHours, 
                                int londonOpen, 
                                int londonClose,
                                int nyOpen, 
                                int nyClose, 
                                int brokerOffset)
    {
        m_restrictTradingHours = restrictHours;
        m_londonOpenHour = londonOpen;
        m_londonCloseHour = londonClose;
        m_newYorkOpenHour = nyOpen;
        m_newYorkCloseHour = nyClose;
        m_brokerToLocalOffsetHours = brokerOffset;
    }
    
    //--- Time and Session Methods
    static bool IsTradeAllowed(void);
    static bool IsWithinSession(int currentHourET, int sessionOpenHour, int sessionCloseHour);
    static int  GetCurrentHourET(void);
    static bool CheckNewBar(string symbol, ENUM_TIMEFRAMES timeframe, 
                          datetime &lastBarTime, int &lastBarIndex);
    
    //--- Risk Management Methods
    static double CalculateLotSize(double stopLossPrice, 
                                 double entryPrice, 
                                 double riskPercentage,
                                 string symbol = NULL);
    
    //--- Order Management Methods
    static bool PlaceTrade(bool isBullish, 
                          double entryPrice, 
                          double slPrice, 
                          double tpPrice, 
                          double lots,
                          string symbol = NULL,
                          string comment = "");
                          
    //--- Position Management Methods
    static bool HasOpenPosition(string symbol, int magicNumber);
    static int  GetOpenPositionsCount(string symbol, int magicNumber);
};

// Initialize static members
CTrade CV2EAUtils::m_trade;
bool   CV2EAUtils::m_showDebugPrints = false;
bool   CV2EAUtils::m_restrictTradingHours = true;
int    CV2EAUtils::m_londonOpenHour = 3;
int    CV2EAUtils::m_londonCloseHour = 11;
int    CV2EAUtils::m_newYorkOpenHour = 9;
int    CV2EAUtils::m_newYorkCloseHour = 16;
int    CV2EAUtils::m_brokerToLocalOffsetHours = 7;

//+------------------------------------------------------------------+
//| Calculate position size based on risk                              |
//+------------------------------------------------------------------+
double CV2EAUtils::CalculateLotSize(double stopLossPrice, 
                                   double entryPrice, 
                                   double riskPercentage,
                                   string symbol = NULL)
{
    if(symbol == NULL) symbol = _Symbol;
    
    // 1) Determine the account balance and base risk amount
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (riskPercentage / 100.0);

    // 2) Calculate distance from entry to SL in points
    double stopDistancePoints = MathAbs(entryPrice - stopLossPrice) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(stopDistancePoints < 1.0)  // prevent nonsensical math
        stopDistancePoints = 10.0; // fallback, e.g., 10 points

    // 3) Get tick value in account currency
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    if(tickValue <= 0)
    {
        if(m_showDebugPrints)
            Print("⚠️ [CalculateLotSize] Tick value = 0; using min lot fallback.");
        return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    }

    // 4) Calculate potential loss per 1.0 lot
    double potentialLossPerLot = stopDistancePoints * tickValue;
    if(potentialLossPerLot <= 0)
    {
        if(m_showDebugPrints)
            Print("⚠️ [CalculateLotSize] Potential loss per lot = 0; fallback to min lot.");
        return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    }

    // 5) Initial lot size based on risk
    double lots = riskAmount / potentialLossPerLot;

    // 6) Broker constraints
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    // Round down to nearest lot step
    lots = MathFloor(lots / lotStep) * lotStep;
    // Enforce boundaries
    lots = MathMax(minLot, MathMin(lots, maxLot));

    // 7) Margin check
    double marginRequiredBuy = 0.0;
    double marginRequiredSell = 0.0;
    if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, lots, entryPrice, marginRequiredBuy) ||
       !OrderCalcMargin(ORDER_TYPE_SELL, symbol, lots, entryPrice, marginRequiredSell))
    {
        if(m_showDebugPrints)
            Print("⚠️ [CalculateLotSize] OrderCalcMargin failed; fallback to min lot.");
        return minLot;
    }

    // Use the higher margin requirement for safety
    double marginRequired = MathMax(marginRequiredBuy, marginRequiredSell);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double safeMargin = freeMargin * 0.8; // only 80% usage

    // If margin is too high, reduce lots
    if(marginRequired > safeMargin)
    {
        double reduceFactor = safeMargin / marginRequired;
        lots = lots * reduceFactor;
        // Round to lot step again
        lots = MathFloor(lots / lotStep) * lotStep;
        lots = MathMax(minLot, lots);
    }

    return lots;
}

//+------------------------------------------------------------------+
//| Place trade with all validations                                   |
//+------------------------------------------------------------------+
bool CV2EAUtils::PlaceTrade(bool isBullish, 
                           double entryPrice, 
                           double slPrice, 
                           double tpPrice, 
                           double lots,
                           string symbol = NULL,
                           string comment = "")
{
    if(symbol == NULL) symbol = _Symbol;
    if(comment == "") comment = isBullish ? "Long Entry" : "Short Entry";

    // Normalize price
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    entryPrice = NormalizeDouble(entryPrice, digits);
    slPrice = NormalizeDouble(slPrice, digits);
    tpPrice = NormalizeDouble(tpPrice, digits);

    // Place the trade
    bool result = isBullish
                ? m_trade.Buy(lots, symbol, 0, slPrice, tpPrice, comment)
                : m_trade.Sell(lots, symbol, 0, slPrice, tpPrice, comment);

    if(!result && m_showDebugPrints)
        Print("❌ [PlaceTrade] Order failed, error = ", GetLastError());
    else if(result && m_showDebugPrints)
        Print("✅ [PlaceTrade] Placed ", (isBullish ? "Buy" : "Sell"), 
              " | Lots=", lots, " | SL=", slPrice, " | TP=", tpPrice);

    return result;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed based on session times                 |
//+------------------------------------------------------------------+
bool CV2EAUtils::IsTradeAllowed(void)
{
    if(!m_restrictTradingHours)
        return true;
        
    int currentHourET = GetCurrentHourET();
    
    bool inLondonSession = IsWithinSession(currentHourET, m_londonOpenHour, m_londonCloseHour);
    bool inNYSession = IsWithinSession(currentHourET, m_newYorkOpenHour, m_newYorkCloseHour);
                       
    return (inLondonSession || inNYSession);
}

//+------------------------------------------------------------------+
//| Check if current hour is within session hours                      |
//+------------------------------------------------------------------+
bool CV2EAUtils::IsWithinSession(int currentHourET, int sessionOpenHour, int sessionCloseHour)
{
    return (currentHourET >= sessionOpenHour && currentHourET < sessionCloseHour);
}

//+------------------------------------------------------------------+
//| Get current hour in Eastern Time                                   |
//+------------------------------------------------------------------+
int CV2EAUtils::GetCurrentHourET(void)
{
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    
    return (dt.hour - m_brokerToLocalOffsetHours + 24) % 24;
}

//+------------------------------------------------------------------+
//| Check for new bar and update tracking variables                    |
//+------------------------------------------------------------------+
bool CV2EAUtils::CheckNewBar(string symbol, ENUM_TIMEFRAMES timeframe, 
                           datetime &lastBarTime, int &lastBarIndex)
{
    datetime currentBarTime = iTime(symbol, timeframe, 0);
    bool isNewBar = (currentBarTime != lastBarTime);
    
    if(isNewBar)
    {
        lastBarTime = currentBarTime;
        lastBarIndex = iBarShift(symbol, timeframe, currentBarTime, false);
    }
    
    return isNewBar;
}

//+------------------------------------------------------------------+
//| Check if there's an open position for symbol/magic number          |
//+------------------------------------------------------------------+
bool CV2EAUtils::HasOpenPosition(string symbol, int magicNumber)
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == symbol && 
           PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get count of open positions for symbol/magic number                |
//+------------------------------------------------------------------+
int CV2EAUtils::GetOpenPositionsCount(string symbol, int magicNumber)
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == symbol && 
           PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
            count++;
        }
    }
    return count;
} 