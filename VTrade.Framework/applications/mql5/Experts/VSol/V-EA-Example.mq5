//+------------------------------------------------------------------+
//|                                                     V-EA-Example.mq5 |
//|                                          Copyright 2024, VTrade Ltd. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, VTrade Ltd."
#property link      "https://www.vtrade.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <VSol\VTradeTypes.mqh>

// Import VTrade Framework functions
#import "VTrade.Framework.dll"
   bool InitializeStrategy(string strategyName, string parameters);
   bool ProcessMarketData(string symbol, string timeframe, double open, double high, double low, double close, long volume);
   bool UpdatePosition(string symbol, string direction, double volume, double entryPrice, double currentPrice, double profitLoss);
#import

// Input parameters
input int Magic = 12345;        // EA Magic Number
input double MaxSpread = 20;    // Maximum allowed spread in points
input bool AllowHedging = false; // Allow hedging positions

// Trading object
CTrade trade;

// Helper function to send market data
bool SendMarketData()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) <= 0)
   {
      Print("Error: Failed to get market data");
      return false;
   }
   
   return ProcessMarketData(
      _Symbol,
      EnumToString(PERIOD_CURRENT),
      rates[0].open,
      rates[0].high,
      rates[0].low,
      rates[0].close,
      rates[0].tick_volume
   );
}

// Helper function to update position
bool SendPositionUpdate()
{
   if(PositionSelect(_Symbol))
   {
      string direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      
      return UpdatePosition(
         _Symbol,
         direction,
         PositionGetDouble(POSITION_VOLUME),
         PositionGetDouble(POSITION_PRICE_OPEN),
         PositionGetDouble(POSITION_PRICE_CURRENT),
         PositionGetDouble(POSITION_PROFIT)
      );
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   // Basic validation
   if(Magic <= 0)
   {
      Print("Error: Invalid Magic number");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(MaxSpread <= 0)
   {
      Print("Error: Invalid MaxSpread value");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Configure trade settings
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(5);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetMarginMode();
   
   // Initialize strategy with parameters
   string parameters = StringFormat(
      "Magic=%d;Timeframe=%s;MaxSpread=%.1f;AllowHedging=%s",
      Magic,
      EnumToString(PERIOD_CURRENT),
      MaxSpread,
      AllowHedging ? "true" : "false"
   );
   
   if(!InitializeStrategy("V-EA-Example", parameters))
   {
      Print("Error: Failed to initialize strategy");
      return INIT_FAILED;
   }
   
   Print("EA initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Process only on new bar
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(lastBar == currentBar) return;
   lastBar = currentBar;

   // Check if trading is allowed
   if(!IsTradeAllowed())
   {
      Print("Error: Trading not allowed");
      return;
   }
   
   // Check spread
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(currentSpread > MaxSpread)
   {
      Print("Warning: Current spread (", currentSpread, ") exceeds maximum allowed (", MaxSpread, ")");
      return;
   }

   // Process market data
   if(!SendMarketData())
   {
      Print("Error: Failed to process market data");
      return;
   }
   
   // Update position if exists
   if(PositionSelect(_Symbol))
   {
      if(!SendPositionUpdate())
      {
         Print("Error: Failed to update position");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up trade object
   trade.SetExpertMagicNumber(0);
   
   // Log deinitialization
   string reasonStr;
   switch(reason)
   {
      case REASON_PROGRAM:     reasonStr = "Program"; break;
      case REASON_REMOVE:      reasonStr = "Removed"; break;
      case REASON_RECOMPILE:   reasonStr = "Recompiled"; break;
      case REASON_CHARTCHANGE: reasonStr = "Chart changed"; break;
      case REASON_CHARTCLOSE:  reasonStr = "Chart closed"; break;
      case REASON_PARAMETERS:  reasonStr = "Parameters changed"; break;
      case REASON_ACCOUNT:     reasonStr = "Account changed"; break;
      default:                 reasonStr = "Other reason"; break;
   }
   
   Print("EA deinitialized - Reason: ", reasonStr);
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                        |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("Error: Algorithmic trading is not allowed");
      return false;
   }
   
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("Error: Trading is not allowed in the terminal");
      return false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Print("Error: Trading is not allowed for this account");
      return false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      Print("Error: Automated trading is not allowed for this account");
      return false;
   }
   
   return true;
} 