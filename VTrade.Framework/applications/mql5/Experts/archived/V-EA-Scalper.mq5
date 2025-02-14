//+------------------------------------------------------------------+
//|                                                        ScalperEA |
//|                          RSI Scalping                            |
//|                          Version: 1.01                           |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.01"
#property strict

#include <Trade\Trade.mqh>
#include "V-2-EA-Utils.mqh"  // Add centralized logging utilities

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input double InpRiskPercentage   = 1.0;    // % of account balance to risk per trade (increased from 0.5)
input double InpRiskRewardRatio  = 2.0;    // Risk-to-reward ratio (reduced from 3.0)
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M15; // Timeframe for signals (changed from PERIOD_H1)
input bool   InpDebugMode        = false;  // Enable debug mode

// RSI thresholds
input int    InpRSIPeriod        = 14;     // RSI period (unchanged)
input double InpRSIOverbought    = 70.0;   // Overbought level (increased from 60.0)
input double InpRSIOversold      = 30.0;   // Oversold level (decreased from 40.0)

// MACD parameters
input int    InpMACDFast         = 8;      // MACD Fast EMA period (unchanged)
input int    InpMACDSlow         = 21;     // MACD Slow EMA period (unchanged)
input int    InpMACDSignal       = 3;      // MACD Signal period (reduced from 5)

// Logging parameters
input bool   InpLogRSI           = true;   // Log RSI values (unchanged)
input bool   InpLogMACD          = true;   // Log MACD values (unchanged)
input bool   InpLogTrend         = true;   // Log trend confirmation values (unchanged)
input bool   InpLogEntryExit     = true;   // Log entry and exit conditions (unchanged)

// Trend confirmation parameters
input int    InpTrendPeriod      = 34;     // EMA period for trend confirmation (unchanged)
input double InpTrendThreshold   = 0.25;   // Threshold for trend strength (reduced from 0.5)

// Global trade object
CTrade tradeScalp;

//--------------------------------------------------------------------
// These constants come from your original include code
//--------------------------------------------------------------------
const int SCALP_MACD_FAST    = 8;      // Faster MACD line for quicker momentum shifts
const int SCALP_MACD_SLOW    = 21;     // Slower MACD line to filter out noise
const int SCALP_MACD_SIGNAL  = 5;      // Shorter signal period for responsiveness

const int SCALP_EMA_SHORT    = 5;     
const int SCALP_EMA_MEDIUM   = 13;
const int SCALP_EMA_LONG     = 34;     // Matches InpTrendPeriod for consistency

const int VOLUME_LOOKBACK    = 15;     // Longer lookback for smoothing
const double MIN_RVOL        = 1.0;    // Lower threshold for US500's high volume

// Add input parameters for time filters
input bool   UseTimeFilter        = true;       // Enabled time-based filtering (changed from false)
input string TradingHourStart     = "07:00";    // Start of trading hours (adjusted to 07:00 EST)
input string TradingHourEnd       = "15:00";    // End of trading hours (adjusted to 15:00 EST)


//--------------------------------------------------------------------
// Utility Logging Functions
//--------------------------------------------------------------------
void LogMessage(string message, string symbol="") {
   CV2EAUtils::LogInfo(symbol != "" ? StringFormat("[%s] %s", symbol, message) : message);
}

void LogError(int errorCode, string context) {
   string errorDescription;
   switch (errorCode) {
      case 4756: errorDescription = "Invalid trade volume or broker restrictions"; break;
      case 4109: errorDescription = "Trade context busy"; break;
      default:   errorDescription = "Unknown error"; break;
   }
   CV2EAUtils::LogError(StringFormat("%s Failed with Error %d: %s", context, errorCode, errorDescription));
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk management                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercentage, double stopLossPips, string symbol) {
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount     = accountBalance * (riskPercentage / 100.0);
   
   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double pipValue  = (tickValue * point) / tickSize;
   
   double potentialLoss = stopLossPips * pipValue;
   if(potentialLoss <= 0) {
      LogMessage("Warning: Invalid potential loss calculation. Using minimum lot size.", symbol);
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   }
   
   double lotSize  = riskAmount / potentialLoss;
   double minLot   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Example dynamic max lot limit
   double dynamicMaxLot   = MathMax(minLot, accountBalance / (50000.0 * lotStep)); 
   double HARD_CAP_MAX_LOTS = MathMin(maxLot, dynamicMaxLot);
   
   lotSize = MathMin(HARD_CAP_MAX_LOTS, MathMax(minLot, lotSize));
   lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
   
   LogMessage("Risk Calculation:" +
              "\n  Account Balance: " + DoubleToString(accountBalance, 2) +
              "\n  Risk Amount:     " + DoubleToString(riskAmount, 2) +
              "\n  Pip Value:       " + DoubleToString(pipValue, 6) +
              "\n  Potential Loss:  " + DoubleToString(potentialLoss, 2) +
              "\n  Dynamic Max Lot: " + DoubleToString(dynamicMaxLot, 2) +
              "\n  Final Lot Size:  " + DoubleToString(lotSize, 2),
              symbol);
   return lotSize;
}

//+------------------------------------------------------------------+
//| Bollinger Bands Calculation                                      |
//+------------------------------------------------------------------+
void CalculateBollingerBands(string symbol, double &upper, double &middle, double &lower) {
   int bb_handle = iBands(symbol, InpTimeFrame, 18, 0, 1.9, PRICE_CLOSE);
   if(bb_handle == INVALID_HANDLE) {
      LogMessage("Error creating Bollinger Bands indicator", symbol);
      return;
   }
   
   // Create separate arrays for each buffer
   double middleBuffer[], upperBuffer[], lowerBuffer[];
   ArraySetAsSeries(middleBuffer, true);
   ArraySetAsSeries(upperBuffer, true);
   ArraySetAsSeries(lowerBuffer, true);
   ArrayResize(middleBuffer, 1);
   ArrayResize(upperBuffer, 1);
   ArrayResize(lowerBuffer, 1);
   
   // Copy data into the buffers
   CopyBuffer(bb_handle, 0, 0, 1, middleBuffer); // Middle
   CopyBuffer(bb_handle, 1, 0, 1, upperBuffer);  // Upper
   CopyBuffer(bb_handle, 2, 0, 1, lowerBuffer);  // Lower
   
   middle = middleBuffer[0];
   upper  = upperBuffer[0];
   lower  = lowerBuffer[0];
   
   IndicatorRelease(bb_handle);
}

//+------------------------------------------------------------------+
//| Check for Bollinger Squeeze                                      |
//+------------------------------------------------------------------+
bool IsBollingerSqueeze(string symbol, int lookbackPeriod = 20, double squeezeFactor = 0.4) {
   double bbUpper, bbMiddle, bbLower;
   CalculateBollingerBands(symbol, bbUpper, bbMiddle, bbLower);
   
   double currentBandWidth = bbUpper - bbLower;
   
   double avgBandWidth = 0;
   for(int i = 1; i <= lookbackPeriod; i++) {
      double upper, middle, lower;
      CalculateBollingerBands(symbol, upper, middle, lower);
      avgBandWidth += upper - lower;
   }
   avgBandWidth /= lookbackPeriod;
   
   bool isSqueeze = (currentBandWidth < avgBandWidth * squeezeFactor);
   
   if(isSqueeze) {
      LogMessage("Bollinger Squeeze detected. Current Band Width: " + DoubleToString(currentBandWidth, 5) +
                 " Avg Band Width: " + DoubleToString(avgBandWidth, 5), symbol);
   }
   
   return isSqueeze;
}

//+------------------------------------------------------------------+
//| Determine best filling mode for orders                           |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetSupportedFillingMode(string symbol)
{
   uint filling = (uint)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   
   return ORDER_FILLING_RETURN; // Fallback
}

//+------------------------------------------------------------------+
//| Calculate Dynamic SL/TP                                          |
//+------------------------------------------------------------------+
void CalculateDynamicSLTP(double &stopLossPips, double &takeProfitPips, string symbol, double riskRewardRatio = 2.0) {
   // Get ATR for dynamic SL/TP
   int atrPeriod = 14;
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   int atrHandle = iATR(symbol, PERIOD_CURRENT, atrPeriod);

   if (atrHandle == INVALID_HANDLE) {
      LogMessage("Error creating ATR indicator for SL/TP calculation", symbol);
      stopLossPips    = 10;  
      takeProfitPips  = 20;  
      return;
   }

   if (CopyBuffer(atrHandle, 0, 0, 1, atrValues) < 0) {
      LogMessage("Error copying ATR values for SL/TP calculation", symbol);
      stopLossPips    = 10;  
      takeProfitPips  = 20;  
      IndicatorRelease(atrHandle);
      return;
   }

   double atr = atrValues[0];
   IndicatorRelease(atrHandle);

   // Example of using a multiplier on ATR
   stopLossPips   = atr * 1.5;  
   takeProfitPips = stopLossPips * riskRewardRatio;

   LogMessage("Dynamic SL/TP calculated: ATR=" + DoubleToString(atr, 5) +
              " SL=" + DoubleToString(stopLossPips, 2) + 
              " TP=" + DoubleToString(takeProfitPips, 2), symbol);
}

//+------------------------------------------------------------------+
//| Execute a Buy Trade                                              |
//+------------------------------------------------------------------+
void ExecuteBuyTrade(double lotSize, string symbol, double riskRewardRatio) {
   double stopLossPips, takeProfitPips;
   CalculateDynamicSLTP(stopLossPips, takeProfitPips, symbol, riskRewardRatio);

   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minLot    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   int    stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   
   lotSize = MathMin(maxLot, MathMax(minLot, lotSize));
   lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;

   double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   stopLossPips    = MathMax(stopLossPips, stopLevel * point);
   takeProfitPips  = MathMax(takeProfitPips, stopLevel * point);
   
   double sl = price - (stopLossPips / point) * point;
   double tp = price + (takeProfitPips / point) * point;

   LogMessage("Trade parameters:" +
              "\n  Type: BUY" +
              "\n  Lot Size:     " + DoubleToString(lotSize, 2) +
              "\n  Stop Loss:    " + DoubleToString(stopLossPips/point, 2) + " pips" +
              "\n  Take Profit:  " + DoubleToString(takeProfitPips/point, 2) + " pips" +
              "\n  Risk/Reward:  1:" + DoubleToString(takeProfitPips/stopLossPips, 2),
              symbol);

   tradeScalp.SetTypeFilling(GetSupportedFillingMode(symbol));
   tradeScalp.Buy(lotSize, symbol, price, sl, tp, "RSI-MACD Buy");
   
   if(tradeScalp.ResultRetcode() != TRADE_RETCODE_DONE) {
      LogError(tradeScalp.ResultRetcode(), "Buy Trade");
   } else {
      LogMessage("Buy Trade Executed: Ticket=" + IntegerToString(tradeScalp.ResultOrder()), symbol);
      
      // Fun ASCII Art for Buy
      Print("\n");
      Print("╔══════════════════════════════════════╗");
      Print("║          🚀 LONG POSITION 🚀         ║");
      Print("║--------------------------------------║");
      Print("║    TO THE MOON!     |    ^    |      ║");
      Print("║                      |   / \\   |      ║");
      Print("║                      |  /   \\  |      ║");
      Print("║                      | /     \\ |      ║");
      Print("║                      |/       \\|      ║");
      Print("╚══════════════════════════════════════╝");
      Print("\n");
   }
}

//+------------------------------------------------------------------+
//| Execute a Sell Trade                                             |
//+------------------------------------------------------------------+
void ExecuteSellTrade(double lotSize, string symbol, double riskRewardRatio) {
   double stopLossPips, takeProfitPips;
   CalculateDynamicSLTP(stopLossPips, takeProfitPips, symbol, riskRewardRatio);

   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minLot    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   int    stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   
   lotSize = MathMin(maxLot, MathMax(minLot, lotSize));
   lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;

   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   stopLossPips    = MathMax(stopLossPips, stopLevel * point);
   takeProfitPips  = MathMax(takeProfitPips, stopLevel * point);
   
   double sl = price + (stopLossPips / point) * point;
   double tp = price - (takeProfitPips / point) * point;

   LogMessage("Trade parameters:" +
              "\n  Type: SELL" +
              "\n  Lot Size:     " + DoubleToString(lotSize, 2) +
              "\n  Stop Loss:    " + DoubleToString(stopLossPips/point, 2) + " pips" +
              "\n  Take Profit:  " + DoubleToString(takeProfitPips/point, 2) + " pips" +
              "\n  Risk/Reward:  1:" + DoubleToString(takeProfitPips/stopLossPips, 2),
              symbol);

   tradeScalp.SetTypeFilling(GetSupportedFillingMode(symbol));
   tradeScalp.Sell(lotSize, symbol, price, sl, tp, "RSI-MACD Sell");
   
   if(tradeScalp.ResultRetcode() != TRADE_RETCODE_DONE) {
      LogError(tradeScalp.ResultRetcode(), "Sell Trade");
   } else {
      LogMessage("Sell Trade Executed: Ticket=" + IntegerToString(tradeScalp.ResultOrder()), symbol);
      
      // Fun ASCII Art for Sell
      Print("\n");
      Print("╔══════════════════════════════════════╗");
      Print("║          🐻 SHORT POSITION 🐻        ║");
      Print("║--------------------------------------║");
      Print("║    RIDING THE WAVE    |\\       /|    ║");
      Print("║                       | \\     / |    ║");
      Print("║                       |  \\   /  |    ║");
      Print("║                       |   \\ /   |    ║");
      Print("║                       |    v    |    ║");
      Print("╚══════════════════════════════════════╝");
      Print("\n");
   }
}

//+------------------------------------------------------------------+
//| Check for Buy Condition                                          |
//+------------------------------------------------------------------+
bool CheckBuyCondition(double rsi, double macdMain, double macdSignal, string symbol) {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) {
      LogMessage("Error getting tick info for " + symbol, symbol);
      return false;
   }
   
   // Get Bollinger Bands
   double bbUpper, bbMiddle, bbLower;
   CalculateBollingerBands(symbol, bbUpper, bbMiddle, bbLower);
   
   // Middle Band Trend Confirmation
   double emaShort = iMA(symbol, InpTimeFrame, 5, 0, MODE_EMA, PRICE_CLOSE);
   bool middleBandTrendConfirmation = (emaShort > bbMiddle);
   
   bool bollingerSqueeze = IsBollingerSqueeze(symbol);
   
   bool buySignal = bollingerSqueeze && middleBandTrendConfirmation;

   if (buySignal) {
      LogMessage("Buy condition met with Bollinger Squeeze and Middle Band Trend confirmation.", symbol);
      return true;
   }
   
   if(InpDebugMode) {
      LogMessage("Buy condition not met. Failed confirmations:" +
                 (!bollingerSqueeze ? " Bollinger Squeeze" : "") +
                 (!middleBandTrendConfirmation ? " Middle Band Trend" : ""),
                 symbol);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for Sell Condition                                         |
//+------------------------------------------------------------------+
bool CheckSellCondition(double rsi, double macdMain, double macdSignal, string symbol) {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) {
      LogMessage("Error getting tick info for " + symbol, symbol);
      return false;
   }
   
   // Get Bollinger Bands
   double bbUpper, bbMiddle, bbLower;
   CalculateBollingerBands(symbol, bbUpper, bbMiddle, bbLower);
   
   // Middle Band Trend Confirmation
   double emaShort = iMA(symbol, InpTimeFrame, 5, 0, MODE_EMA, PRICE_CLOSE);
   bool middleBandTrendConfirmation = (emaShort < bbMiddle);
   
   bool bollingerSqueeze = IsBollingerSqueeze(symbol);
   
   bool sellSignal = bollingerSqueeze && middleBandTrendConfirmation;

   if (sellSignal) {
      LogMessage("Sell condition met with Bollinger Squeeze and Middle Band Trend confirmation.", symbol);
      return true;
   }
   
   if(InpDebugMode) {
      LogMessage("Sell condition not met. Failed confirmations:" +
                 (!bollingerSqueeze ? " Bollinger Squeeze" : "") + 
                 (!middleBandTrendConfirmation ? " Middle Band Trend" : ""),
                 symbol);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Exit Condition                                             |
//+------------------------------------------------------------------+
bool CheckExitCondition(double rsi, string symbol) {
   double macdMain, macdSignal, macdHistogram = 0.0;
   int macd_handle = iMACD(symbol, PERIOD_CURRENT, 
                           SCALP_MACD_FAST, SCALP_MACD_SLOW, 
                           SCALP_MACD_SIGNAL, PRICE_CLOSE);
   
   if(macd_handle != INVALID_HANDLE) {
      double macdBuffer[];
      ArraySetAsSeries(macdBuffer, true);
      // We copy 2 elements: index 0 = macdMain, index 1 = macdSignal
      // So the histogram is macdMain - macdSignal
      if(CopyBuffer(macd_handle, 0, 0, 2, macdBuffer) > 0) {
         macdHistogram = macdBuffer[0] - macdBuffer[1];
      }
      IndicatorRelease(macd_handle);
   }
   
   LogMessage("Checking Enhanced Exit Condition:" +
              "\n  RSI=" + DoubleToString(rsi, 2) +
              "\n  MACD Histogram=" + DoubleToString(macdHistogram, 6),
              symbol);
   
   // If RSI is at extremes or MACD histogram is near zero => exit
   if (rsi > 80 || rsi < 20 || MathAbs(macdHistogram) < 0.00005) {
      LogMessage("Exit condition met: " + 
                 (rsi > 80 ? "RSI Overbought" :
                  rsi < 20 ? "RSI Oversold"  :
                  "MACD Momentum Reversal"), symbol);
      return true;
   }
   
   LogMessage("Exit condition not met.", symbol);
   
   if(InpDebugMode) {
      LogMessage("Exit Condition Debug:" +
                 "\n  MACD Main=" + DoubleToString(macdMain, 6) +
                 "\n  MACD Signal=" + DoubleToString(macdSignal, 6),
                 symbol);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   LogMessage("ScalperEA initialized.");
   // Optionally set trade parameters, margin check, or schedule a Timer if needed
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LogMessage("ScalperEA deinitialized. Reason code=" + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   string symbol = _Symbol;
   
   // Retrieve RSI
   int rsi_handle = iRSI(symbol, InpTimeFrame, InpRSIPeriod, PRICE_CLOSE);

   if (rsi_handle == INVALID_HANDLE) {
      LogMessage("Error creating RSI indicator handle.", symbol);
      return;
   }

   double rsiValue[];
   ArraySetAsSeries(rsiValue, true);

   if (CopyBuffer(rsi_handle, 0, 0, 1, rsiValue) != 1) {
      LogMessage("Error copying RSI value from indicator buffer.", symbol);
      IndicatorRelease(rsi_handle);
      return;
   }

   IndicatorRelease(rsi_handle);

   if (rsiValue[0] == EMPTY_VALUE) {
      LogMessage("Error retrieving RSI value. EMPTY_VALUE returned.", symbol);
      return;
   }
   
   LogMessage("iRSI Input - Symbol: " + symbol + 
              ", TimeFrame: " + EnumToString(InpTimeFrame) + 
              ", Period: " + IntegerToString(InpRSIPeriod) + 
              ", Price Type: PRICE_CLOSE", symbol);
              
   if (rsiValue[0] == INVALID_HANDLE) {
      LogMessage("Error calculating RSI. Handle is invalid.", symbol);
   }
   
   LogMessage("RSI Value: " + DoubleToString(rsiValue[0], 2), symbol);
   
   // Log price data used for RSI calculation
   double rsiClosePrice = iClose(symbol, InpTimeFrame, 0);
   LogMessage("RSI Close Price: " + DoubleToString(rsiClosePrice, 5), symbol);
   
   if(InpLogRSI) {
      LogMessage("RSI: " + DoubleToString(rsiValue[0], 2), symbol);
   }
   
   // Check if we already have an open position
   bool haveOpenPosition = false;
   ulong ticket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == symbol) {
         haveOpenPosition = true;
         break;
      }
   }

   // If we have an open position, check RSI for exit
   if(haveOpenPosition) {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         if(rsiValue[0] >= InpRSIOverbought) {
            tradeScalp.PositionClose(symbol);
            if(InpLogEntryExit) {
               LogMessage("Long position closed due to overbought RSI. Ticket=" + IntegerToString(ticket), symbol);
            }
         }
      }
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
         if(rsiValue[0] <= InpRSIOversold) {
            tradeScalp.PositionClose(symbol);
            if(InpLogEntryExit) {
               LogMessage("Short position closed due to oversold RSI. Ticket=" + IntegerToString(ticket), symbol);
            }
         }  
      }
      return;
   }

   // Retrieve MACD
   double macdMain = 0, macdSignal = 0;
   int macd_handle = iMACD(symbol, InpTimeFrame, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   if(macd_handle != INVALID_HANDLE) {
      double macdMainBuffer[], macdSignalBuffer[];
      ArraySetAsSeries(macdMainBuffer, true);
      ArraySetAsSeries(macdSignalBuffer, true);
      if(CopyBuffer(macd_handle, 0, 0, 1, macdMainBuffer) > 0)
         macdMain = macdMainBuffer[0];
      if(CopyBuffer(macd_handle, 1, 0, 1, macdSignalBuffer) > 0)
         macdSignal = macdSignalBuffer[0];
      IndicatorRelease(macd_handle);
   }
   if(InpLogMACD) {
      LogMessage("MACD Main: " + DoubleToString(macdMain, 6) + 
                 " Signal: " + DoubleToString(macdSignal, 6), symbol);
   }

   // Check trend confirmation
   LogMessage("iMA Input - Symbol: " + symbol + 
              ", TimeFrame: " + EnumToString(InpTimeFrame) + 
              ", Period: " + IntegerToString(InpTrendPeriod) + 
              ", Shift: 0" +
              ", Mode: MODE_EMA" +
              ", Price Type: PRICE_CLOSE", symbol);
              
   LogMessage("InpTrendPeriod Value: " + IntegerToString(InpTrendPeriod), symbol);
              
   double ema[];
   ArraySetAsSeries(ema, true);
   int ema_handle = iMA(symbol, InpTimeFrame, InpTrendPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if (ema_handle == INVALID_HANDLE) {
      LogMessage("Error creating EMA indicator handle.", symbol);
      return;
   }

   if (CopyBuffer(ema_handle, 0, 0, 1, ema) != 1) {
      LogMessage("Error copying EMA value from indicator buffer.", symbol);
      IndicatorRelease(ema_handle);
      return;
   }

   IndicatorRelease(ema_handle);

   if (ema[0] == EMPTY_VALUE) {
      LogMessage("Error retrieving EMA value. EMPTY_VALUE returned.", symbol);
      return;
   }

   LogMessage("EMA Value: " + DoubleToString(ema[0], 5), symbol);

   // Log price data used for EMA calculation
   double emaClosePrice = iClose(symbol, InpTimeFrame, 0);
   LogMessage("EMA Close Price: " + DoubleToString(emaClosePrice, 5), symbol);

   LogMessage("iClose Input - Symbol: " + symbol + 
              ", TimeFrame: " + EnumToString(InpTimeFrame) + 
              ", Shift: 0", symbol);
              
   double close = iClose(symbol, InpTimeFrame, 0);

   if (close == INVALID_HANDLE) {
      LogMessage("Error retrieving close price. Handle is invalid.", symbol);
   }

   LogMessage("Close Price: " + DoubleToString(close, 5), symbol);

   bool trendConfirmation = (close > ema[0] * (1 + InpTrendThreshold/100)) || 
                            (close < ema[0] * (1 - InpTrendThreshold/100));
                            
   LogMessage("Trend Confirmation Calculation:" +
              "\n  Close: " + DoubleToString(close, 5) +
              "\n  EMA: " + DoubleToString(ema[0], 5) +
              "\n  Threshold: " + DoubleToString(InpTrendThreshold, 2) + "%" +
              "\n  Upper Threshold: " + DoubleToString(ema[0] * (1 + InpTrendThreshold/100), 5) +
              "\n  Lower Threshold: " + DoubleToString(ema[0] * (1 - InpTrendThreshold/100), 5),
              symbol);
              
   if(InpLogTrend) {
      LogMessage("Trend Confirmation: " + (trendConfirmation ? "Yes" : "No") +
                 " EMA: " + DoubleToString(ema[0], 5) + 
                 " Close: " + DoubleToString(close, 5), symbol);
   }
   
   // If no open position, check RSI, MACD, and trend for entry
   if(rsiValue[0] <= InpRSIOversold && macdMain > macdSignal && trendConfirmation) {
      double lotSize = CalculateLotSize(InpRiskPercentage, 100, symbol); // Placeholder 100 pips SL
      ExecuteBuyTrade(lotSize, symbol, InpRiskRewardRatio);
      if(InpLogEntryExit) {
         LogMessage("Buy trade executed. RSI: " + DoubleToString(rsiValue[0], 2) +
                    " MACD Main: " + DoubleToString(macdMain, 6) + 
                    " Signal: " + DoubleToString(macdSignal, 6) +
                    " Trend: " + (trendConfirmation ? "Confirmed" : "Not Confirmed"), symbol);
      }
   }
   else if(rsiValue[0] >= InpRSIOverbought && macdMain < macdSignal && trendConfirmation) {
      double lotSize = CalculateLotSize(InpRiskPercentage, 100, symbol); // Placeholder 100 pips SL  
      ExecuteSellTrade(lotSize, symbol, InpRiskRewardRatio);
      if(InpLogEntryExit) {
         LogMessage("Sell trade executed. RSI: " + DoubleToString(rsiValue[0], 2) +
                    " MACD Main: " + DoubleToString(macdMain, 6) + 
                    " Signal: " + DoubleToString(macdSignal, 6) +
                    " Trend: " + (trendConfirmation ? "Confirmed" : "Not Confirmed"), symbol);
      }
   }
}