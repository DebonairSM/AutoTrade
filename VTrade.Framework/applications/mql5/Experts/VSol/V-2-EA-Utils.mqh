//+------------------------------------------------------------------+
//|                                                   V-2-EA-Utils.mqh |
//|                                                                    |
//| Purpose: Common Trading Utility Functions for VSol Trading Systems |
//| Version: 1.00                                                      |
//| Author:  VSol Trading Systems                                      |
//| Website: https://vsol-systems.com                                 |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"
#property strict

// Standard includes
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| CV2EAUtils - Core Trading Utility Class                            |
//|                                                                    |
//| Provides essential trading utilities including:                    |
//| - Position sizing and risk management                             |
//| - Trade execution with validation                                 |
//| - Session management and time control                             |
//| - Position tracking and management                                |
//| - Array manipulation and debug utilities                          |
//+------------------------------------------------------------------+
class CV2EAUtils
{
private:
    //--- Trading Objects
    static CTrade     m_trade;                    // Trading object for order execution
    
    //--- Configuration Flags
    static bool       m_showDebugPrints;          // Enable/disable debug printing
    static bool       m_restrictTradingHours;     // Enable/disable trading hour restrictions
    
    //--- Session Control Parameters
    static int        m_londonOpenHour;           // London session open hour (ET)
    static int        m_londonCloseHour;          // London session close hour (ET)
    static int        m_newYorkOpenHour;          // NY session open hour (ET)
    static int        m_newYorkCloseHour;         // NY session close hour (ET)
    static int        m_brokerToLocalOffsetHours; // Broker to ET time offset

public:
    //--- Array Manipulation Methods
    template<typename T>
    static bool SafeResizeArray(T &arr[], int newSize, const string context)
    {
        if(!ArrayResize(arr, newSize))
        {
            LogError(StringFormat("[%s] Failed to resize array to %d elements", context, newSize));
            return false;
        }
        return true;
    }
    
    //--- Enhanced Logging Methods
    static void LogError(string message, bool showPrice = true)
    {
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        string priceStr = showPrice ? StringFormat("[%.5f]", SymbolInfoDouble(_Symbol, SYMBOL_BID)) : "";
        Print(StringFormat("[%s] %s ❌ %s", timestamp, priceStr, message));
    }
    
    //--- File Naming Utilities
    static string GenerateUniqueTimestamp()
    {
        datetime currentTime = TimeCurrent();
        ulong microseconds = GetMicrosecondCount();
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        
        // Format: YYYYMMDD_HHMMSS_microseconds
        return StringFormat("%04d%02d%02d_%02d%02d%02d_%06d", 
            dt.year, dt.mon, dt.day,
            dt.hour, dt.min, dt.sec,
            (int)(microseconds % 1000000)); // Last 6 digits for uniqueness
    }
    
    static string CreateUniqueLogFilename(string baseName, string extension = "txt", string symbol = "", string timeframe = "")
    {
        string timestamp = GenerateUniqueTimestamp();
        string symbolPart = (symbol != "") ? ("_" + symbol) : "";
        string timeframePart = (timeframe != "") ? ("_" + timeframe) : "";
        return baseName + symbolPart + timeframePart + "_" + timestamp + "." + extension;
    }
    
    static void LogWarning(string message, bool showPrice = true)
    {
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        string priceStr = showPrice ? StringFormat("[%.5f]", SymbolInfoDouble(_Symbol, SYMBOL_BID)) : "";
        Print(StringFormat("[%s] %s ⚠️ %s", timestamp, priceStr, message));
    }
    
    static void LogInfo(string message, string param1 = "", string param2 = "", string param3 = "", bool showPrice = true)
    {
        if(!m_showDebugPrints) return;
        string formattedMsg = message;
        if(param1 != "") formattedMsg = StringFormat(message, param1);
        if(param2 != "") formattedMsg = StringFormat(message, param1, param2);
        if(param3 != "") formattedMsg = StringFormat(message, param1, param2, param3);
        
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        string priceStr = showPrice ? StringFormat("[%.5f]", SymbolInfoDouble(_Symbol, SYMBOL_BID)) : "";
        Print(StringFormat("[%s] %s ℹ️ %s", timestamp, priceStr, formattedMsg));
    }
    
    static void LogSuccess(string message, bool showPrice = true)
    {
        if(!m_showDebugPrints) return;
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        string priceStr = showPrice ? StringFormat("[%.5f]", SymbolInfoDouble(_Symbol, SYMBOL_BID)) : "";
        Print(StringFormat("[%s] %s ✅ %s", timestamp, priceStr, message));
    }
    
    static void DebugPrint(string message, bool showPrice = true)
    {
        if(!m_showDebugPrints) return;
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        string priceStr = showPrice ? StringFormat("[%.5f]", SymbolInfoDouble(_Symbol, SYMBOL_BID)) : "";
        Print(StringFormat("[%s] %s %s", timestamp, priceStr, message));
    }

    //+------------------------------------------------------------------+
    //| Initialization Methods                                             |
    //+------------------------------------------------------------------+
    static void Init(bool showDebugPrints)
    {
        m_showDebugPrints = showDebugPrints;
    }
    
    static void SetMagicNumber(int magicNumber)
    {
        if(magicNumber <= 0)
        {
            LogWarning("Invalid magic number. Using default value 1");
            magicNumber = 1;
        }
        m_trade.SetExpertMagicNumber(magicNumber);
    }
    
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

    //--- Array Sorting Methods
    template<typename T>
    static void QuickSort(T &arr[], int left, int right, 
                         double &strengths[])  // Strengths array for sorting
    {
        if(left >= right) return;
        
        int i = left, j = right;
        double pivotStrength = strengths[(left + right) / 2];
        
        while(i <= j)
        {
            while(strengths[i] > pivotStrength) i++;
            while(strengths[j] < pivotStrength) j--;
            
            if(i <= j)
            {
                if(i != j)
                {
                    // Swap elements
                    T temp = arr[i];
                    arr[i] = arr[j];
                    arr[j] = temp;
                    
                    // Swap corresponding strengths
                    double tempStr = strengths[i];
                    strengths[i] = strengths[j];
                    strengths[j] = tempStr;
                }
                i++;
                j--;
            }
        }
        
        if(left < j) QuickSort(arr, left, j, strengths);
        if(i < right) QuickSort(arr, i, right, strengths);
    }

    // Add to CV2EAUtils class
    static bool IsForexPair(string symbol=NULL)
    {
        if(symbol == NULL) symbol = _Symbol;
        return StringFind(symbol, "US500") == -1 &&  // Exclude indices
              (StringLen(symbol) == 6 || StringLen(symbol) == 7); // Major/minor pairs
    }

    static bool IsUS500(string symbol=NULL)
    {
        if(symbol == NULL) symbol = _Symbol;
        return StringFind(symbol, "US500") != -1;
    }
};

//--- Initialize static class members
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
    // Input validation
    if(stopLossPrice <= 0 || entryPrice <= 0 || riskPercentage <= 0)
    {
        LogWarning("Invalid input parameters for lot size calculation");
        return SymbolInfoDouble(symbol == NULL ? _Symbol : symbol, SYMBOL_VOLUME_MIN);
    }

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
        LogWarning("[CalculateLotSize] Tick value = 0; using min lot fallback.");
        return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    }

    // 4) Calculate potential loss per 1.0 lot
    double potentialLossPerLot = stopDistancePoints * tickValue;
    if(potentialLossPerLot <= 0)
    {
        LogWarning("[CalculateLotSize] Potential loss per lot = 0; fallback to min lot.");
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
        LogWarning("[CalculateLotSize] OrderCalcMargin failed; fallback to min lot.");
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
    // Input validation
    if(lots <= 0 || entryPrice <= 0 || slPrice <= 0 || tpPrice <= 0)
    {
        LogWarning("Invalid trade parameters");
        return false;
    }

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

    if(!result)
        LogError(StringFormat("[PlaceTrade] Order failed, error = %d", GetLastError()));
    else
        LogSuccess(StringFormat("[PlaceTrade] Placed %s | Lots=%.2f | SL=%.5f | TP=%.5f", 
                              (isBullish ? "Buy" : "Sell"), lots, slPrice, tpPrice));

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
    if(symbol == NULL) symbol = _Symbol;
    
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