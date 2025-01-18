#property copyright "VSol Software"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- plot ATR_TP
#property indicator_label1  "ATR_TP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- plot ATR_SL
#property indicator_label2  "ATR_SL"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- plot Hybrid_TP
#property indicator_label3  "Hybrid_TP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- plot Hybrid_SL
#property indicator_label4  "Hybrid_SL"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMaroon
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

//--- indicator buffers
double ATR_TP_Buffer[];
double ATR_SL_Buffer[];
double Hybrid_TP_Buffer[];
double Hybrid_SL_Buffer[];

//--- EA Parameters from V-EA-Stubbs_EMA_MACD.mq5
input group "=== ATR Settings ==="
input int      ATRPeriod = 22;           // ATR Period
input double   ATRMultiplierSL = 8.5;    // ATR Multiplier for Stop Loss
input double   ATRMultiplierTP = 8.0;    // ATR Multiplier for Take Profit
input int      ATR_MA_Period = 15;       // Period for Average ATR calculation

input group "=== Hybrid Exit Settings ==="
input bool     UseHybridExits = true;    // Use both Pivot and ATR for exits
input double   PivotWeight    = 0.4;     // Weight for Pivot Points (Standard: 0.5) [0.3-0.7, Step: 0.1]
input double   ATRWeight      = 0.4;     // Weight for ATR-based exits (Standard: 0.5) [0.3-0.7, Step: 0.1]

input group "=== Buffer Settings ==="
input double   SL_ATR_Mult = 0.5;        // ATR multiplier for SL buffer
input double   TP_ATR_Mult = 0.25;       // ATR multiplier for TP buffer
input double   SL_Dist_Mult = 0.13;      // Distance multiplier for SL buffer
input double   TP_Dist_Mult = 0.12;      // Distance multiplier for TP buffer
input double   Max_Buffer_Pips = 50.0;   // Maximum buffer size in pips

//--- Global variables
int ATRHandle;
int EMAHandle;

// Add missing parameters from EA
input group "=== Pivot Points & Buffers ==="
input ENUM_TIMEFRAMES PivotTimeframe = PERIOD_D1;  // Timeframe for Pivot Points
input bool    UsePivotPoints = true;     // Use Pivot Points for Trading
input double  PivotBufferPips = 1.0;     // Buffer around pivot levels

// Add pivot point variables
double pivotPoint, r1Level, r2Level, r3Level, s1Level, s2Level, s3Level;
datetime lastPivotCalc = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
   SetIndexBuffer(0, ATR_TP_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, ATR_SL_Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, Hybrid_TP_Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, Hybrid_SL_Buffer, INDICATOR_DATA);
   
   //--- Initialize ATR indicator handle
   ATRHandle = iATR(_Symbol, PERIOD_D1, ATRPeriod);
   
   if(ATRHandle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator");
      return(INIT_FAILED);
   }
   
   //--- Set indicator labels
   PlotIndexSetString(0, PLOT_LABEL, "ATR Take Profit");
   PlotIndexSetString(1, PLOT_LABEL, "ATR Stop Loss");
   PlotIndexSetString(2, PLOT_LABEL, "Hybrid Take Profit");
   PlotIndexSetString(3, PLOT_LABEL, "Hybrid Stop Loss");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                                |
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
   //--- Check for minimum number of bars
   if(rates_total < ATRPeriod)
      return(0);
      
   //--- Calculate start position
   int start = prev_calculated == 0 ? ATRPeriod : prev_calculated - 1;
   
   //--- Copy ATR values
   double atr[];
   if(CopyBuffer(ATRHandle, 0, 0, rates_total, atr) <= 0)
      return(0);
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      //--- Calculate ATR-based levels
      double currentPrice = close[i];
      double atrPoints = atr[i];
      
      // ATR-based TP/SL
      ATR_TP_Buffer[i] = currentPrice + (atrPoints * ATRMultiplierTP);
      ATR_SL_Buffer[i] = currentPrice - (atrPoints * ATRMultiplierSL);
      
      // Hybrid TP/SL (including buffer calculations)
      double bufferTP = atrPoints * TP_ATR_Mult;
      double bufferSL = atrPoints * SL_ATR_Mult;
      
      // Apply maximum buffer limit
      bufferTP = MathMin(bufferTP, Max_Buffer_Pips * _Point);
      bufferSL = MathMin(bufferSL, Max_Buffer_Pips * _Point);
      
      if(UseHybridExits)
      {
         // Calculate weighted hybrid levels
         Hybrid_TP_Buffer[i] = (ATR_TP_Buffer[i] * ATRWeight + (currentPrice + bufferTP) * PivotWeight) / (ATRWeight + PivotWeight);
         Hybrid_SL_Buffer[i] = (ATR_SL_Buffer[i] * ATRWeight + (currentPrice - bufferSL) * PivotWeight) / (ATRWeight + PivotWeight);
      }
      else
      {
         Hybrid_TP_Buffer[i] = ATR_TP_Buffer[i];
         Hybrid_SL_Buffer[i] = ATR_SL_Buffer[i];
      }
   }
   
   //--- return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(ATRHandle != INVALID_HANDLE)
      IndicatorRelease(ATRHandle);
} 