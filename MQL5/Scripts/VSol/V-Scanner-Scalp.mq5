//+------------------------------------------------------------------+
//|                                             ScalperScanner.mq5  |
//|                                  Copyright 2023, Your Name/Company |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window

#include <Trade\Trade.mqh>

//--- Constants
#define SCALP_MACD_FAST   8
#define SCALP_MACD_SLOW   21  
#define SCALP_MACD_SIGNAL 5
#define SCALP_EMA_SHORT   5
#define SCALP_EMA_MEDIUM  13
#define SCALP_EMA_LONG    34
#define VOLUME_LOOKBACK   15
#define MIN_RVOL          1.0

//--- Input parameters
input bool     UseTimeFilter     = true;
input string   TradingHourStart  = "16:00";
input string   TradingHourEnd    = "23:00";
input ENUM_TIMEFRAMES InpTimeFrame      = PERIOD_M5;   // Timeframe
input int             InpRSIPeriod      = 9;           // RSI Period
input double          InpRSIOverbought  = 75.0;        // RSI Overbought Level
input double          InpRSIOversold    = 25.0;        // RSI Oversold Level
input bool            InpDebugMode      = false;       // Debug Mode
input bool     SendNotifications = false;       // Send Push Notifications
input bool     SendEmails        = false;       // Send Email Alerts

//--- Indicator buffers
double         BuyBuffer[];
double         SellBuffer[];

//--- Global variables  
string         SymbolNames[];
int            RSIHandles[];
int            MACDHandles[];
int            BandsHandles[];
double         RSIValues[];
double         MACDMainValues[];
double         MACDSignalValues[];
double         RVOLValues[];
bool           BollingerSqueezeStatus[];
bool           MiddleBandTrendConfirmation[];  
bool           EngulfingBullish[];
bool           EngulfingBearish[];
bool           ConsecutiveBullish[];
bool           ConsecutiveBearish[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Indicator buffers mapping
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
   
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrGreen);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrRed);
   
//--- Get all symbols from Market Watch
   int symbolsTotal = SymbolsTotal(true);
   ArrayResize(SymbolNames, symbolsTotal);
   
   for(int i = 0; i < symbolsTotal; i++)
   {
      SymbolNames[i] = SymbolName(i, true);
   }
   
//--- Resize buffers and arrays
   ArrayResize(BuyBuffer, symbolsTotal);
   ArrayResize(SellBuffer, symbolsTotal);
   ArrayResize(RSIHandles, symbolsTotal);
   ArrayResize(MACDHandles, symbolsTotal);
   ArrayResize(BandsHandles, symbolsTotal);
   ArrayResize(RSIValues, symbolsTotal);
   ArrayResize(MACDMainValues, symbolsTotal);
   ArrayResize(MACDSignalValues, symbolsTotal);
   ArrayResize(RVOLValues, symbolsTotal);
   ArrayResize(BollingerSqueezeStatus, symbolsTotal);
   ArrayResize(MiddleBandTrendConfirmation, symbolsTotal);
   ArrayResize(EngulfingBullish, symbolsTotal);
   ArrayResize(EngulfingBearish, symbolsTotal);
   ArrayResize(ConsecutiveBullish, symbolsTotal);
   ArrayResize(ConsecutiveBearish, symbolsTotal);

//--- Initialize buffers and arrays   
   ArrayInitialize(BuyBuffer, EMPTY_VALUE);
   ArrayInitialize(SellBuffer, EMPTY_VALUE);
   ArrayInitialize(RSIHandles, INVALID_HANDLE);
   ArrayInitialize(MACDHandles, INVALID_HANDLE);
   ArrayInitialize(BandsHandles, INVALID_HANDLE);
   ArrayInitialize(RSIValues, 0);
   ArrayInitialize(MACDMainValues, 0);
   ArrayInitialize(MACDSignalValues, 0);
   ArrayInitialize(RVOLValues, 0);
   ArrayInitialize(BollingerSqueezeStatus, false);
   ArrayInitialize(MiddleBandTrendConfirmation, false);
   ArrayInitialize(EngulfingBullish, false);
   ArrayInitialize(EngulfingBearish, false);
   ArrayInitialize(ConsecutiveBullish, false);
   ArrayInitialize(ConsecutiveBearish, false);
   
//--- Create indicator handles
   for(int i = 0; i < symbolsTotal; i++)
   {
      string symbol = SymbolNames[i];
      RSIHandles[i] = iRSI(symbol, InpTimeFrame, InpRSIPeriod, PRICE_CLOSE);
      MACDHandles[i] = iMACD(symbol, InpTimeFrame, SCALP_MACD_FAST, SCALP_MACD_SLOW, SCALP_MACD_SIGNAL, PRICE_CLOSE);
      BandsHandles[i] = iBands(symbol, InpTimeFrame, 20, 2, 0, PRICE_CLOSE);
   }
   
   Print("Indicator handles created successfully for all symbols.");
   
//--- Log number of symbols   
   Print("Scanning ", symbolsTotal, " symbols.");
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
//--- Time filter
   if(UseTimeFilter)
   {
      MqlDateTime currentTime;
      TimeCurrent(currentTime);
      
      datetime startTime = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " " + TradingHourStart);
      datetime endTime = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " " + TradingHourEnd);
      
      if(TimeCurrent() < startTime || TimeCurrent() > endTime)
      {
         LogMessage("Outside trading hours. Skipping calculations.");
         return(rates_total);
      }
   }
   
//--- Iterate through symbols
   for(int i = 0; i < ArraySize(SymbolNames); i++)
   {
      string symbol = SymbolNames[i];
      
      //--- Get current rates
      MqlRates rates[];
      if(CopyRates(symbol, InpTimeFrame, 0, 3, rates) < 0)
      {
         LogMessage("Failed to get current rates for symbol: " + symbol);
         continue;
      }
      
      //--- Calculate RSI
      double rsi[];
      if(CopyBuffer(RSIHandles[i], 0, 0, 3, rsi) < 0)
      {
         LogError("Failed to copy RSI data for symbol: " + symbol);
         continue;
      }
      RSIValues[i] = rsi[0];
      
      //--- Calculate MACD
      double macdMain[], macdSignal[];
      if(CopyBuffer(MACDHandles[i], 0, 0, 3, macdMain) < 0 ||
         CopyBuffer(MACDHandles[i], 1, 0, 3, macdSignal) < 0)
      {
         LogMessage("Failed to calculate MACD for symbol: " + symbol);
         continue;
      }
      MACDMainValues[i] = macdMain[0];
      MACDSignalValues[i] = macdSignal[0];
      
      //--- Calculate RVOL
      double volume[];
      if(CopyBuffer(iVolume(symbol, InpTimeFrame, VOLUME_TICK), 0, 0, VOLUME_LOOKBACK, volume) < 0)
      {
         LogMessage("Failed to calculate RVOL for symbol: " + symbol);
         continue;
      }
      double avgVolume = 0;
      for(int j = 0; j < VOLUME_LOOKBACK; j++)
         avgVolume += volume[j];
      avgVolume /= VOLUME_LOOKBACK;
      RVOLValues[i] = volume[0] / avgVolume;
      
      //--- Calculate Bollinger Bands and Squeeze
      double upper[1], middle[1], lower[1];
      if(CopyBuffer(BandsHandles[i], 0, 0, 1, upper) < 0 ||
         CopyBuffer(BandsHandles[i], 1, 0, 1, middle) < 0 ||
         CopyBuffer(BandsHandles[i], 2, 0, 1, lower) < 0)
      {
         LogMessage("Failed to calculate Bollinger Bands for symbol: " + symbol);
         continue;
      }
      BollingerSqueezeStatus[i] = IsBollingerSqueeze(i, upper[0], middle[0], lower[0]);
      
      //--- Calculate Middle Band Confirmation
      double upperPrev[1], middlePrev[1], lowerPrev[1];
      if(CopyBuffer(BandsHandles[i], 0, 1, 1, upperPrev) < 0 ||
         CopyBuffer(BandsHandles[i], 1, 1, 1, middlePrev) < 0 ||
         CopyBuffer(BandsHandles[i], 2, 1, 1, lowerPrev) < 0)
      {
         MiddleBandTrendConfirmation[i] = false;
      }
      else
      {
         MiddleBandTrendConfirmation[i] = (close[0] > middle[0] && close[1] <= middlePrev[0]) || 
                                             (close[0] < middle[0] && close[1] >= middlePrev[0]);
      }
      
      //--- Detect Engulfing and Consecutive patterns
      EngulfingBullish[i] = IsEngulfingBullish(symbol, InpTimeFrame);
      EngulfingBearish[i] = IsEngulfingBearish(symbol, InpTimeFrame);
      ConsecutiveBullish[i] = IsConsecutiveBullish(symbol, InpTimeFrame);
      ConsecutiveBearish[i] = IsConsecutiveBearish(symbol, InpTimeFrame);
      
      //--- Check buy and sell conditions
      if(CheckBuyCondition(RSIValues[i], MACDMainValues[i], MACDSignalValues[i], symbol, RVOLValues[i],
                           BollingerSqueezeStatus[i], MiddleBandTrendConfirmation[i],
                           EngulfingBullish[i], ConsecutiveBullish[i]))
      {
         BuyBuffer[i] = low[0];
         SendAlerts(symbol, "Buy");
      }
      else
      {
         BuyBuffer[i] = EMPTY_VALUE;
      }
      
      if(CheckSellCondition(RSIValues[i], MACDMainValues[i], MACDSignalValues[i], symbol, RVOLValues[i],
                            BollingerSqueezeStatus[i], MiddleBandTrendConfirmation[i],
                            EngulfingBearish[i], ConsecutiveBearish[i]))
      {
         SellBuffer[i] = high[0];
         SendAlerts(symbol, "Sell");
      }
      else
      {
         SellBuffer[i] = EMPTY_VALUE;
      }
   }

//--- Set labels and plot signals
   for(int i = 0; i < ArraySize(SymbolNames); i++)
   {
      string symbol = SymbolNames[i];
      
      //--- Set label for buy signals
      if(BuyBuffer[i] != EMPTY_VALUE)
      {
         PlotIndexSetString(0, PLOT_LABEL, symbol);
         PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
      }
      else
      {
         PlotIndexSetString(0, PLOT_LABEL, "");
         PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
      }
      
      //--- Set label for sell signals  
      if(SellBuffer[i] != EMPTY_VALUE)
      {
         PlotIndexSetString(1, PLOT_LABEL, symbol);
         PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
      }
      else
      {
         PlotIndexSetString(1, PLOT_LABEL, "");
         PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
      }
   }

   DisplayScannerResults();
   
   //--- Release indicator handles
   for(int i = 0; i < ArraySize(SymbolNames); i++)
   {
      IndicatorRelease(RSIHandles[i]);
      IndicatorRelease(MACDHandles[i]);  
      IndicatorRelease(BandsHandles[i]);
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
//| Bollinger Bands Calculation                                      |
//+------------------------------------------------------------------+
bool CalculateBollingerBands(string symbol, double &upper, double &middle, double &lower, int shift = 0)
{
   int bbPeriod = 20;
   double bbDeviation = 2.0;
   
   int handle = iBands(symbol, InpTimeFrame, bbPeriod, bbDeviation, shift, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
   {
      LogError("Failed to create Bollinger Bands indicator handle for symbol: " + symbol);
      return false;
   }
   
   double upperArray[1], middleArray[1], lowerArray[1];
   if(CopyBuffer(handle, 0, 0, 1, upperArray) < 0 || 
      CopyBuffer(handle, 1, 0, 1, middleArray) < 0 || 
      CopyBuffer(handle, 2, 0, 1, lowerArray) < 0)
   {
      LogError("Failed to copy Bollinger Bands indicator data for symbol: " + symbol);
      IndicatorRelease(handle);
      return false;
   }
   
   upper = upperArray[0];
   middle = middleArray[0];
   lower = lowerArray[0];
   
   IndicatorRelease(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Bollinger Bands Squeeze Detection                                |
//+------------------------------------------------------------------+
bool IsBollingerSqueeze(int symbolIndex, double upper, double middle, double lower, int lookbackPeriod = 20, double squeezeFactor = 0.4)
{
   double bandWidth = upper - lower;
   
   double avgBandWidth = 0;
   for(int i = 1; i < lookbackPeriod; i++)
   {
      double upperPrev[1], middlePrev[1], lowerPrev[1];
      if(CopyBuffer(BandsHandles[symbolIndex], 0, i, 1, upperPrev) < 0 ||
         CopyBuffer(BandsHandles[symbolIndex], 1, i, 1, middlePrev) < 0 ||
         CopyBuffer(BandsHandles[symbolIndex], 2, i, 1, lowerPrev) < 0)
         return false;
         
      avgBandWidth += upperPrev[0] - lowerPrev[0];
   }
   avgBandWidth /= (lookbackPeriod - 1);
   
   if(avgBandWidth == 0)
      return false;
      
   double bandWidthRatio = bandWidth / avgBandWidth;
   
   return (bandWidthRatio < squeezeFactor);
}

//+------------------------------------------------------------------+
//| Log Message Function                                             |
//+------------------------------------------------------------------+
void LogMessage(string message)
{
   if(InpDebugMode)
      Print(message);
}
   
//+------------------------------------------------------------------+
//| Log Error Function                                               |
//+------------------------------------------------------------------+   
void LogError(string message)
{
   Print("ERROR: ", message);
}

//+------------------------------------------------------------------+
//| Check Buy Condition                                              |
//+------------------------------------------------------------------+
bool CheckBuyCondition(double rsi, double macdMain, double macdSignal, string symbol, double rvol, 
                       bool bollingerSqueeze, bool middleBandTrendConfirmation, 
                       bool engulfingBullish, bool consecutiveBullish)
{
   if(rsi > InpRSIOversold && rsi < 50 && macdMain > macdSignal && rvol >= MIN_RVOL)
   {
      if(bollingerSqueeze && middleBandTrendConfirmation)
      {
         LogMessage("Buy condition met for " + symbol + ": RSI, MACD, RVOL, Bollinger Squeeze, Middle Band Trend Confirmation.");
         return true;
      }
      else if(engulfingBullish || consecutiveBullish)
      {
         LogMessage("Buy condition met for " + symbol + ": RSI, MACD, RVOL, Engulfing/Consecutive Bullish.");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Sell Condition                                             |
//+------------------------------------------------------------------+
bool CheckSellCondition(double rsi, double macdMain, double macdSignal, string symbol, double rvol,
                        bool bollingerSqueeze, bool middleBandTrendConfirmation,
                        bool engulfingBearish, bool consecutiveBearish)
{
   if(rsi < InpRSIOverbought && rsi > 50 && macdMain < macdSignal && rvol >= MIN_RVOL)
   {
      if(bollingerSqueeze && middleBandTrendConfirmation)
      {
         LogMessage("Sell condition met for " + symbol + ": RSI, MACD, RVOL, Bollinger Squeeze, Middle Band Trend Confirmation.");
         return true;
      }
      else if(engulfingBearish || consecutiveBearish)
      {
         LogMessage("Sell condition met for " + symbol + ": RSI, MACD, RVOL, Engulfing/Consecutive Bearish.");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Display Scanner Results                                          |
//+------------------------------------------------------------------+
void DisplayScannerResults()
{
   string output = "";
   
   output += StringFormat("%-10s %-10s %-10s %-10s %-10s %-10s %-10s\n", 
                          "Symbol", "RSI", "MACD", "RVOL", "BolSqz", "MidTrend", "Signal");
   output += StringFormat("%-10s %-10s %-10s %-10s %-10s %-10s %-10s\n",
                          "----------", "----------", "----------", "----------", "----------", "----------", "----------");
   
   for(int i = 0; i < ArraySize(SymbolNames); i++)
   {
      string symbol = SymbolNames[i];
      double rsi = RSIValues[i];
      double macd = MACDMainValues[i] - MACDSignalValues[i];
      double rvol = RVOLValues[i];
      string bolSqz = BollingerSqueezeStatus[i] ? "Yes" : "No";
      string midTrend = MiddleBandTrendConfirmation[i] ? "Up" : "Down";
      string signal = "";
      
      if(BuyBuffer[i] != EMPTY_VALUE)
         signal = "Buy";
      else if(SellBuffer[i] != EMPTY_VALUE)
         signal = "Sell";
      else
         signal = "None";
      
      output += StringFormat("%-10s %-10.2f %-10.2f %-10.2f %-10s %-10s %-10s\n",
                             symbol, rsi, macd, rvol, bolSqz, midTrend, signal);
   }
   
   Comment(output);
}

//+------------------------------------------------------------------+
//| Send Alerts                                                      |
//+------------------------------------------------------------------+
void SendAlerts(string symbol, string signalType)
{
   string alertMessage = symbol + " - " + signalType + " signal detected!";
   
   Alert(alertMessage);
   
   if(SendNotifications)
   {
      SendNotification(alertMessage);
   }
   
   if(SendEmails)
   {
      SendMail("Scalper Scanner Alert", alertMessage);
   }
}

//+------------------------------------------------------------------+
//| Engulfing Bullish Pattern                                        |
//+------------------------------------------------------------------+
bool IsEngulfingBullish(string symbol, ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   CopyOpen(symbol, timeframe, 0, 3, open);
   CopyClose(symbol, timeframe, 0, 3, close);
   CopyHigh(symbol, timeframe, 0, 3, high);
   CopyLow(symbol, timeframe, 0, 3, low);
   
   return (open[1] > close[1] && close[0] > open[0] && open[0] < close[1] && close[0] > open[1]);
}

//+------------------------------------------------------------------+
//| Engulfing Bearish Pattern                                        |
//+------------------------------------------------------------------+
bool IsEngulfingBearish(string symbol, ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   CopyOpen(symbol, timeframe, 0, 3, open);
   CopyClose(symbol, timeframe, 0, 3, close);
   CopyHigh(symbol, timeframe, 0, 3, high);
   CopyLow(symbol, timeframe, 0, 3, low);
   
   return (open[1] < close[1] && close[0] < open[0] && open[0] > close[1] && close[0] < open[1]);
}

//+------------------------------------------------------------------+
//| Consecutive Bullish Pattern                                      |
//+------------------------------------------------------------------+
bool IsConsecutiveBullish(string symbol, ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   CopyOpen(symbol, timeframe, 0, 3, open);
   CopyClose(symbol, timeframe, 0, 3, close);
   CopyHigh(symbol, timeframe, 0, 3, high);
   CopyLow(symbol, timeframe, 0, 3, low);
   
   return (close[0] > open[0] && close[1] > open[1] && close[0] > close[1]);
}

//+------------------------------------------------------------------+
//| Consecutive Bearish Pattern                                      |
//+------------------------------------------------------------------+
bool IsConsecutiveBearish(string symbol, ENUM_TIMEFRAMES timeframe)
{
   double open[], close[], high[], low[];
   CopyOpen(symbol, timeframe, 0, 3, open);
   CopyClose(symbol, timeframe, 0, 3, close);
   CopyHigh(symbol, timeframe, 0, 3, high);
   CopyLow(symbol, timeframe, 0, 3, low);
   
   return (close[0] < open[0] && close[1] < open[1] && close[0] < close[1]);
}
