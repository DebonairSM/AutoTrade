//+------------------------------------------------------------------+
//|                                                    VTradeTypes.mqh |
//|                                          Copyright 2024, VTrade Ltd |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, VTrade Ltd"
#property link      "https://www.vtrade.com"

// Trade signal structure that matches C# MQL5TradeSignal struct
struct TradeSignal
{
    ENUM_ORDER_TYPE type;     // Order type (matches C# int type field)
    double volume;           // Trade volume
    double price;           // Order price (for pending orders)
    double sl;              // Stop loss
    double tp;              // Take profit
    string comment;         // Trade comment (max 63 chars)
};

// Function to initialize a trade signal
void InitTradeSignal(TradeSignal &signal)
{
    signal.type = (ENUM_ORDER_TYPE)NULL;  // Cast NULL to ENUM_ORDER_TYPE
    signal.volume = 0.0;
    signal.price = 0.0;
    signal.sl = 0.0;
    signal.tp = 0.0;
    signal.comment = "";
}

// Function to validate trade signal
bool ValidateTradeSignal(const TradeSignal &signal)
{
    // Check volume
    if(signal.volume <= 0.0 || signal.volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX))
        return false;
        
    // Check price for pending orders
    if((signal.type >= ORDER_TYPE_BUY_LIMIT && signal.type <= ORDER_TYPE_SELL_STOP) && signal.price <= 0.0)
        return false;
        
    // Check stop loss and take profit
    if(signal.sl < 0.0 || signal.tp < 0.0)
        return false;
        
    return true;
}

// Function to print trade signal details
string TradeSignalToString(const TradeSignal &signal)
{
    string typeStr = EnumToString(signal.type);
    return StringFormat(
        "Signal: Type=%s, Volume=%.2f, Price=%.5f, SL=%.5f, TP=%.5f, Comment=%s",
        typeStr, signal.volume, signal.price, signal.sl, signal.tp, signal.comment
    );
} 