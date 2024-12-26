//+------------------------------------------------------------------+
//|                                                        ScalperEA |
//|                RSI-MACD Scalping with Bollinger Bands            |
//|                          Version: 1.00                           |
//|              (c) 2024, ReplaceWithYourName or Company            |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input double InpRiskPercentage   = 1.0;   // % of account balance to risk per trade
input double InpRiskRewardRatio  = 2.0;   // Risk-to-reward ratio
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M5; // Timeframe for signals
input bool   InpDebugMode        = false; // Enable debug mode

// RSI thresholds (for demonstration; you can refine these as needed)
input int    InpRSIPeriod        = 14;
input double InpRSIOverbought    = 80.0;
input double InpRSIOversold      = 20.0;

// Global trade object
CTrade tradeScalp;

//--------------------------------------------------------------------
// These constants come from your original include code
//--------------------------------------------------------------------
const int SCALP_MACD_FAST  = 5;     
const int SCALP_MACD_SLOW  = 13;
const int SCALP_MACD_SIGNAL= 4;

const int SCALP_EMA_SHORT  = 5;     
const int SCALP_EMA_MEDIUM = 13;
const int SCALP_EMA_LONG   = 34;

const int VOLUME_LOOKBACK  = 10; 
const double MIN_RVOL      = 1.2;  

//--------------------------------------------------------------------
// Utility Logging Functions
//--------------------------------------------------------------------
void LogMessage(string message, string symbol="") {
   Print(TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + 
         (symbol != "" ? " [" + symbol + "]:" : "") + " " + message);
}

void LogError(int errorCode, string context) {
   string errorDescription;
   switch (errorCode) {
      case 4756: errorDescription = "Invalid trade volume or broker restrictions"; break;
      case 4109: errorDescription = "Trade context busy"; break;
      default:   errorDescription = "Unknown error"; break;
   }
   LogMessage(context + " Failed with Error " + IntegerToString(errorCode) + 
              ": " + errorDescription, "N/A");
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
   int bb_handle = iBands(symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
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
   double emaShort  = iMA(symbol, PERIOD_CURRENT, SCALP_EMA_SHORT, 0, MODE_EMA, PRICE_CLOSE);
   double emaMedium = iMA(symbol, PERIOD_CURRENT, SCALP_EMA_MEDIUM, 0, MODE_EMA, PRICE_CLOSE);
   
   // Calculate RVOL
   double currentVolume = iVolume(symbol, PERIOD_CURRENT, 0);
   double avgVolume     = 0;
   for(int i = 1; i <= VOLUME_LOOKBACK; i++) {
      avgVolume += iVolume(symbol, PERIOD_CURRENT, i);
   }
   avgVolume /= VOLUME_LOOKBACK;
   double rvol = currentVolume / avgVolume;
   
   // Get Bollinger Bands
   double bbUpper, bbMiddle, bbLower;
   CalculateBollingerBands(symbol, bbUpper, bbMiddle, bbLower);
   
   LogMessage("Checking Enhanced Buy Condition:" +
              "\n  RSI=" + DoubleToString(rsi, 2) +
              "\n  MACD Main=" + DoubleToString(macdMain, 2) +
              "\n  MACD Signal=" + DoubleToString(macdSignal, 2) +
              "\n  RVOL=" + DoubleToString(rvol, 2),
              symbol);
   
   bool momentumConfirmation = (rsi > InpRSIOversold && rsi < InpRSIOverbought && macdMain > macdSignal);
   bool trendConfirmation    = (emaShort > emaMedium * 0.995);
   bool volumeConfirmation   = (rvol >= MIN_RVOL);
   bool priceAction          = (SymbolInfoDouble(symbol, SYMBOL_ASK) < bbUpper * 1.005);
   
   if (momentumConfirmation && trendConfirmation && volumeConfirmation && priceAction) {
      LogMessage("Buy condition met with all confirmations.", symbol);
      return true;
   }
   
   LogMessage("Buy condition not met. Failed confirmations:" +
              (!momentumConfirmation ? " Momentum" : "") +
              (!trendConfirmation    ? " Trend" : "") +
              (!volumeConfirmation   ? " Volume" : "") +
              (!priceAction         ? " Price" : ""),
              symbol);
   
   if(InpDebugMode) {
      LogMessage("Buy Condition Debug:" +
                 "\n  EMA Short=" + DoubleToString(emaShort, 5) + 
                 "\n  EMA Medium=" + DoubleToString(emaMedium, 5) +
                 "\n  BB Upper=" + DoubleToString(bbUpper, 5) +
                 "\n  BB Middle=" + DoubleToString(bbMiddle, 5) +
                 "\n  BB Lower=" + DoubleToString(bbLower, 5),
                 symbol);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for Sell Condition                                         |
//+------------------------------------------------------------------+
bool CheckSellCondition(double rsi, double macdMain, double macdSignal, string symbol) {
   double emaShort  = iMA(symbol, PERIOD_CURRENT, SCALP_EMA_SHORT, 0, MODE_EMA, PRICE_CLOSE);
   double emaMedium = iMA(symbol, PERIOD_CURRENT, SCALP_EMA_MEDIUM, 0, MODE_EMA, PRICE_CLOSE);
   
   // Calculate RVOL
   double currentVolume = iVolume(symbol, PERIOD_CURRENT, 0);
   double avgVolume     = 0;
   for(int i = 1; i <= VOLUME_LOOKBACK; i++) {
      avgVolume += iVolume(symbol, PERIOD_CURRENT, i);
   }
   avgVolume /= VOLUME_LOOKBACK;
   double rvol = currentVolume / avgVolume;
   
   // Get Bollinger Bands
   double bbUpper, bbMiddle, bbLower;
   CalculateBollingerBands(symbol, bbUpper, bbMiddle, bbLower);
   
   LogMessage("Checking Enhanced Sell Condition:" +
              "\n  RSI=" + DoubleToString(rsi, 2) +
              "\n  MACD Main=" + DoubleToString(macdMain, 2) +
              "\n  MACD Signal=" + DoubleToString(macdSignal, 2) +
              "\n  RVOL=" + DoubleToString(rvol, 2),
              symbol);
   
   bool momentumConfirmation = (rsi > InpRSIOversold && rsi < InpRSIOverbought && macdMain < macdSignal);
   bool trendConfirmation    = (emaShort < emaMedium * 1.005);
   bool volumeConfirmation   = (rvol >= MIN_RVOL);
   bool priceAction          = (SymbolInfoDouble(symbol, SYMBOL_BID) > bbLower * 0.995);
   
   if (momentumConfirmation && trendConfirmation && volumeConfirmation && priceAction) {
      LogMessage("Sell condition met with all confirmations.", symbol);
      return true;
   }
   
   LogMessage("Sell condition not met. Failed confirmations:" +
              (!momentumConfirmation ? " Momentum" : "") +
              (!trendConfirmation    ? " Trend" : "") +
              (!volumeConfirmation   ? " Volume" : "") +
              (!priceAction         ? " Price" : ""),
              symbol);
   
   if(InpDebugMode) {
      LogMessage("Sell Condition Debug:" +
                 "\n  EMA Short=" + DoubleToString(emaShort, 5) + 
                 "\n  EMA Medium=" + DoubleToString(emaMedium, 5) +
                 "\n  BB Upper=" + DoubleToString(bbUpper, 5) +
                 "\n  BB Middle=" + DoubleToString(bbMiddle, 5) +
                 "\n  BB Lower=" + DoubleToString(bbLower, 5),
                 symbol);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Exit Condition                                             |
//+------------------------------------------------------------------+
bool CheckExitCondition(double rsi, string symbol) {
   double macdMain, macdSignal, macdHistogram = 0.0;
   int macd_handle = iMACD(symbol, PERIOD_CURRENT, SCALP_MACD_FAST, SCALP_MACD_SLOW, 
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
   // Example of a straightforward approach:
   // 1) If there is no open position, check for Buy or Sell signals.
   // 2) If there is an open position, check if exit condition is met.

   string symbol = _Symbol;
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) {
      Print("Error getting tick info for ", symbol);
      return;
   }

   // Retrieve RSI
   double rsiValue = iRSI(symbol, InpTimeFrame, InpRSIPeriod, PRICE_CLOSE);
   
   // Retrieve MACD
   int macd_handle = iMACD(symbol, InpTimeFrame, SCALP_MACD_FAST, SCALP_MACD_SLOW, 
                           SCALP_MACD_SIGNAL, PRICE_CLOSE);
   double macdMain   = 0.0, 
          macdSignal = 0.0;
   if(macd_handle != INVALID_HANDLE) {
      double macdMainBuffer[], macdSignalBuffer[];
      ArraySetAsSeries(macdMainBuffer, true);
      ArraySetAsSeries(macdSignalBuffer, true);
      // Buffer 0 => MACD main, Buffer 1 => MACD signal
      if(CopyBuffer(macd_handle, 0, 0, 1, macdMainBuffer) > 0)
         macdMain = macdMainBuffer[0];
      if(CopyBuffer(macd_handle, 1, 0, 1, macdSignalBuffer) > 0)
         macdSignal = macdSignalBuffer[0];
      IndicatorRelease(macd_handle);
   }
   
   // Check if we already have an open position in this symbol.
   // (In a more advanced EA, you might track multiple positions or MagicNumbers.)
   bool haveOpenPosition = false;
   double openPrice      = 0.0;
   long   ticket         = -1;
   for(int iPos = PositionsTotal() - 1; iPos >= 0; iPos--) {
      ulong posTicket = PositionGetTicket(iPos);
      if(posTicket > 0) {
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if(posSymbol == symbol) {
            haveOpenPosition = true;
            openPrice        = PositionGetDouble(POSITION_PRICE_OPEN);
            ticket           = posTicket;
            break;
         }
      }
   }

   // If we have an open position, check exit
   if(haveOpenPosition) {
      // If exit condition is met, close the position
      if(CheckExitCondition(rsiValue, symbol)) {
         tradeScalp.PositionClose(symbol);
         LogMessage("Position closed due to exit condition. Ticket=" + IntegerToString(ticket), symbol);
      }
      return; // done for this tick
   }

   // If no open position, check Buy or Sell signals
   bool buySignal  = CheckBuyCondition(rsiValue, macdMain, macdSignal, symbol);
   bool sellSignal = CheckSellCondition(rsiValue, macdMain, macdSignal, symbol);
   
   if(buySignal) {
      // We'll do a quick placeholder stopLossPips to compute a lot
      // so that our lot size is based on the approximate dynamic SL
      double tmpSL, tmpTP;
      CalculateDynamicSLTP(tmpSL, tmpTP, symbol, InpRiskRewardRatio);
      double lotSize = CalculateLotSize(InpRiskPercentage, tmpSL, symbol);
      ExecuteBuyTrade(lotSize, symbol, InpRiskRewardRatio);
   }
   else if(sellSignal) {
      double tmpSL, tmpTP;
      CalculateDynamicSLTP(tmpSL, tmpTP, symbol, InpRiskRewardRatio);
      double lotSize = CalculateLotSize(InpRiskPercentage, tmpSL, symbol);
      ExecuteSellTrade(lotSize, symbol, InpRiskRewardRatio);
   }

   if(InpDebugMode) {
      LogMessage("OnTick Debug:" +
                 "\n  RSI=" + DoubleToString(rsiValue, 2) +
                 "\n  MACD Main=" + DoubleToString(macdMain, 6) +
                 "\n  MACD Signal=" + DoubleToString(macdSignal, 6),
                 symbol);
   }
}
//+------------------------------------------------------------------+
