//+------------------------------------------------------------------+
//|                                                  V-EA-Trends.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Input parameters
input double   InpLotSize         = 0.1;    // Lot size
input int      InpStopLoss        = 50;     // Stop Loss in points
input int      InpTakeProfit      = 100;    // Take Profit in points
input int      InpTrendPeriod     = 20;     // Trend EMA period
input int      InpRSIPeriod       = 8;      // RSI period
input double   InpRSIUpperLevel   = 60;     // RSI upper level
input double   InpRSILowerLevel   = 40;     // RSI lower level
input int      InpMACDFastPeriod  = 12;     // MACD Fast EMA period
input int      InpMACDSlowPeriod  = 26;     // MACD Slow EMA period
input int      InpMACDSignalPeriod= 9;      // MACD Signal period
input double   InpRSIExitLevel     = 50;     // RSI level to close position
input int      InpTrendExitPeriod  = 100;    // Trend EMA period for exit confirmation
input double   InpATRMultiplier    = 3.0;    // ATR multiplier for trailing stop
input int      InpATRPeriod        = 14;     // ATR period
input int      InpMinHoldDuration  = 60;     // Minimum holding duration in minutes

//--- Global variables
int            trendHandle;
int            rsiHandle;
int            macdHandle;
int            atrHandle;
CTrade         trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create handles for indicators
   trendHandle = iMA(_Symbol, PERIOD_H1, InpTrendPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle   = iRSI(_Symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);
   macdHandle  = iMACD(_Symbol, PERIOD_H1, InpMACDFastPeriod, InpMACDSlowPeriod, InpMACDSignalPeriod, PRICE_CLOSE);
   atrHandle   = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
   
   if(trendHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE) {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(trendHandle);
   IndicatorRelease(rsiHandle);  
   IndicatorRelease(macdHandle);
   IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get current prices
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Get indicator values
   double trendValue[];
   double rsiValue[];
   double macdMain[];
   double macdSignal[];
   
   ArraySetAsSeries(trendValue, true);
   ArraySetAsSeries(rsiValue, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   
   CopyBuffer(trendHandle, 0, 0, 3, trendValue);
   CopyBuffer(rsiHandle, 0, 0, 3, rsiValue);
   CopyBuffer(macdHandle, 0, 0, 3, macdMain);
   CopyBuffer(macdHandle, 1, 0, 3, macdSignal);
   
   // Get current ATR value
   double atrValue[];
   ArraySetAsSeries(atrValue, true);
   CopyBuffer(atrHandle, 0, 0, 1, atrValue);
   double currentATR = atrValue[0];
   
   // Log indicator values
   Print("Trend EMA Values: ", trendValue[0], ", ", trendValue[1], ", ", trendValue[2]);
   Print("RSI Values: ", rsiValue[0], ", ", rsiValue[1], ", ", rsiValue[2]);
   Print("MACD Main Values: ", macdMain[0], ", ", macdMain[1], ", ", macdMain[2]);
   Print("MACD Signal Values: ", macdSignal[0], ", ", macdSignal[1], ", ", macdSignal[2]);
   Print("Current ATR Value: ", currentATR);
   
   // Check for new bar
   static datetime prevBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
   
   if(currentBarTime == prevBarTime) {
      return;
   }
   prevBarTime = currentBarTime;
   
   // Check for long entry
   if(trendValue[0] > trendValue[1] &&                                    // Uptrend
      rsiValue[0] > InpRSILowerLevel && rsiValue[1] <= InpRSILowerLevel)   // RSI crossing above lower level
   {
      double sl = bid - InpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = ask + InpTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Trend EA Long");
      Print("Long position opened");
   }
   
   // Check for short entry 
   if(trendValue[0] < trendValue[1] &&                                    // Downtrend 
      rsiValue[0] < InpRSIUpperLevel && rsiValue[1] >= InpRSIUpperLevel)   // RSI crossing below upper level
   {
      double sl = ask + InpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = bid - InpTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Trend EA Short");
      Print("Short position opened");
   }
   
   // Check for exit based on higher timeframe reversal
   if(PositionSelect(_Symbol)) {
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double trendValueHigher[];
      double rsiValueHigher[];
      
      ArraySetAsSeries(trendValueHigher, true);
      ArraySetAsSeries(rsiValueHigher, true);
      
      int trendHandleHigher = iMA(_Symbol, PERIOD_D1, InpTrendPeriod, 0, MODE_EMA, PRICE_CLOSE); 
      int rsiHandleHigher   = iRSI(_Symbol, PERIOD_D1, InpRSIPeriod, PRICE_CLOSE);
      
      CopyBuffer(trendHandleHigher, 0, 0, 3, trendValueHigher);
      CopyBuffer(rsiHandleHigher, 0, 0, 3, rsiValueHigher);
      
      Print("D1 Trend EMA Values: ", trendValueHigher[0], ", ", trendValueHigher[1], ", ", trendValueHigher[2]);
      Print("D1 RSI Values: ", rsiValueHigher[0], ", ", rsiValueHigher[1], ", ", rsiValueHigher[2]);
      
      // Get position open time
      datetime posOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
      
      // Calculate position duration in minutes
      int posDuration = (int)((TimeCurrent() - posOpenTime) / 60);
      
      if(posType == POSITION_TYPE_BUY) {
         
         // Adjust RSI exit condition
         if(rsiValueHigher[0] > InpRSIExitLevel && rsiValueHigher[1] <= InpRSIExitLevel) {
            if(posDuration >= InpMinHoldDuration) {
               trade.PositionClose(_Symbol);
               Print("Long position closed due to RSI crossing above exit level");
            }
            else {
               Print("Long position RSI exit triggered but minimum holding period not met");
            }
         }
         
         // Modify Trend EMA exit condition
         double trendExitValue = iMA(_Symbol, PERIOD_D1, InpTrendExitPeriod, 0, MODE_EMA, PRICE_CLOSE);
         if(trendValueHigher[1] > trendExitValue && trendValueHigher[0] < trendExitValue) {
            if(posDuration >= InpMinHoldDuration) {
               trade.PositionClose(_Symbol);
               Print("Long position closed due to price crossing below Trend EMA");
            }
            else {
               Print("Long position trend exit triggered but minimum holding period not met");
            }
         }
         
         // Introduce ATR-based trailing stop loss
         double currentStop = PositionGetDouble(POSITION_SL);
         double newStop = bid - InpATRMultiplier * currentATR;
         if(newStop > currentStop) {
            trade.PositionModify(_Symbol, newStop, PositionGetDouble(POSITION_TP));
            Print("Long position ATR-based trailing stop updated to: ", newStop);
         }
      }
      else if(posType == POSITION_TYPE_SELL) {
         
         // Adjust RSI exit condition
         if(rsiValueHigher[0] < (100 - InpRSIExitLevel) && rsiValueHigher[1] >= (100 - InpRSIExitLevel)) {
            if(posDuration >= InpMinHoldDuration) {
               trade.PositionClose(_Symbol);
               Print("Short position closed due to RSI crossing below exit level");
            }
            else {
               Print("Short position RSI exit triggered but minimum holding period not met");
            }
         }
         
         // Modify Trend EMA exit condition 
         double trendExitValue = iMA(_Symbol, PERIOD_D1, InpTrendExitPeriod, 0, MODE_EMA, PRICE_CLOSE);
         if(trendValueHigher[1] < trendExitValue && trendValueHigher[0] > trendExitValue) {
            if(posDuration >= InpMinHoldDuration) {
               trade.PositionClose(_Symbol);
               Print("Short position closed due to price crossing above Trend EMA");
            }
            else {
               Print("Short position trend exit triggered but minimum holding period not met");  
            }
         }
         
         // Introduce ATR-based trailing stop loss
         double currentStop = PositionGetDouble(POSITION_SL);
         double newStop = ask + InpATRMultiplier * currentATR;
         if(newStop < currentStop) {
            trade.PositionModify(_Symbol, newStop, PositionGetDouble(POSITION_TP));
            Print("Short position ATR-based trailing stop updated to: ", newStop);
         }
      }
      
      IndicatorRelease(trendHandleHigher);
      IndicatorRelease(rsiHandleHigher);
   }
}