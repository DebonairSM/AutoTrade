//+------------------------------------------------------------------+
//| GrandeCleanIndicator.mq5                                         |
//| Copyright 2024, Grande Tech                                      |
//| Clean visual indicator showing actual EA indicators              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Clean visual indicator showing actual Grande EA indicators"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots 8

// Plot properties for visual indicators
#property indicator_label1 "RSI"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrPurple
#property indicator_style1 STYLE_SOLID
#property indicator_width1 2
#property indicator_minimum 0
#property indicator_maximum 100

#property indicator_label2 "Stochastic %K"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrLime
#property indicator_style2 STYLE_SOLID
#property indicator_width2 2

#property indicator_label3 "Stochastic %D"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrYellow
#property indicator_style3 STYLE_SOLID
#property indicator_width3 2

#property indicator_label4 "ADX"
#property indicator_type4 DRAW_LINE
#property indicator_color4 clrCyan
#property indicator_style4 STYLE_SOLID
#property indicator_width4 2

#property indicator_label5 "ATR"
#property indicator_type5 DRAW_LINE
#property indicator_color5 clrMagenta
#property indicator_style5 STYLE_SOLID
#property indicator_width5 2

#property indicator_label6 "EMA 20"
#property indicator_type6 DRAW_LINE
#property indicator_color6 clrBlue
#property indicator_style6 STYLE_SOLID
#property indicator_width6 1

#property indicator_label7 "EMA 50"
#property indicator_type7 DRAW_LINE
#property indicator_color7 clrOrange
#property indicator_style7 STYLE_SOLID
#property indicator_width7 1

#property indicator_label8 "EMA 200"
#property indicator_type8 DRAW_LINE
#property indicator_color8 clrRed
#property indicator_style8 STYLE_SOLID
#property indicator_width8 1

// Include Grande EA components
#include "GrandeMarketRegimeDetector.mqh"
#include "GrandeKeyLevelDetector.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Display Settings ==="
input bool   InpShowKeyLevels = true;            // Show Key Levels
input bool   InpShowRegimeInfo = true;           // Show Market Regime
input color  InpTextColor = clrWhite;            // Text Color
input int    InpFontSize = 9;                    // Font Size

input group "=== Technical Indicator Settings ==="
input int    InpEMA20Period = 20;                // EMA 20 Period
input int    InpEMA50Period = 50;                // EMA 50 Period
input int    InpEMA200Period = 200;              // EMA 200 Period
input int    InpRSIPeriod = 14;                  // RSI Period
input int    InpStochPeriod = 14;                // Stochastic Period
input int    InpStochK = 3;                      // Stochastic %K
input int    InpStochD = 3;                      // Stochastic %D
input int    InpATRPeriod = 14;                  // ATR Period
input int    InpADXPeriod = 14;                  // ADX Period

input group "=== Key Level Settings ==="
input int    InpKeyLevelLookback = 100;          // Key Level Lookback Period
input double InpKeyLevelMinStrength = 0.55;      // Minimum Level Strength
input double InpKeyLevelTouchZone = 0.0005;      // Touch Zone
input int    InpKeyLevelMinTouches = 2;          // Minimum Touches Required

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CGrandeMarketRegimeDetector* g_regimeDetector = NULL;
CGrandeKeyLevelDetector* g_keyLevelDetector = NULL;

// Indicator handles
int g_ema20_handle = INVALID_HANDLE;
int g_ema50_handle = INVALID_HANDLE;
int g_ema200_handle = INVALID_HANDLE;
int g_rsi_handle = INVALID_HANDLE;
int g_stoch_handle = INVALID_HANDLE;
int g_atr_handle = INVALID_HANDLE;
int g_adx_handle = INVALID_HANDLE;

// Indicator buffers
double g_rsi_buffer[];
double g_stoch_k_buffer[];
double g_stoch_d_buffer[];
double g_adx_buffer[];
double g_atr_buffer[];
double g_ema20_buffer[];
double g_ema50_buffer[];
double g_ema200_buffer[];

// Display variables
int g_lineHeight = 20;
int g_yPos = 30;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set indicator buffers
    SetIndexBuffer(0, g_rsi_buffer, INDICATOR_DATA);
    SetIndexBuffer(1, g_stoch_k_buffer, INDICATOR_DATA);
    SetIndexBuffer(2, g_stoch_d_buffer, INDICATOR_DATA);
    SetIndexBuffer(3, g_adx_buffer, INDICATOR_DATA);
    SetIndexBuffer(4, g_atr_buffer, INDICATOR_DATA);
    SetIndexBuffer(5, g_ema20_buffer, INDICATOR_DATA);
    SetIndexBuffer(6, g_ema50_buffer, INDICATOR_DATA);
    SetIndexBuffer(7, g_ema200_buffer, INDICATOR_DATA);
    
    // Initialize Grande components
    g_regimeDetector = new CGrandeMarketRegimeDetector();
    g_keyLevelDetector = new CGrandeKeyLevelDetector();
    
    if(g_regimeDetector == NULL || g_keyLevelDetector == NULL)
    {
        Print("ERROR: Failed to initialize Grande components");
        return INIT_FAILED;
    }
    
    // Initialize key level detector
    g_keyLevelDetector.Initialize(
        InpKeyLevelLookback,
        InpKeyLevelMinStrength,
        InpKeyLevelTouchZone,
        InpKeyLevelMinTouches
    );
    
    // Create indicator handles
    g_ema20_handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA20Period, 0, MODE_EMA, PRICE_CLOSE);
    g_ema50_handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
    g_ema200_handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
    g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    g_stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochPeriod, InpStochK, InpStochD, MODE_SMA, STO_LOWHIGH);
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
    g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
    
    // Check handles
    if(g_ema20_handle == INVALID_HANDLE || g_ema50_handle == INVALID_HANDLE || 
       g_ema200_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE ||
       g_stoch_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE ||
       g_adx_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create indicator handles");
        return INIT_FAILED;
    }
    
    // Set indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "Grande EA Indicators");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up handles
    if(g_ema20_handle != INVALID_HANDLE) IndicatorRelease(g_ema20_handle);
    if(g_ema50_handle != INVALID_HANDLE) IndicatorRelease(g_ema50_handle);
    if(g_ema200_handle != INVALID_HANDLE) IndicatorRelease(g_ema200_handle);
    if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
    if(g_stoch_handle != INVALID_HANDLE) IndicatorRelease(g_stoch_handle);
    if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
    if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
    
    // Clean up objects
    if(g_regimeDetector != NULL) delete g_regimeDetector;
    if(g_keyLevelDetector != NULL) delete g_keyLevelDetector;
    
    // Remove all objects
    ObjectsDeleteAll(0, "GRANDE_CLEAN_");
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
    if(rates_total < 100) return 0;
    
    int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
    
    // Copy indicator data for subwindow display
    if(CopyBuffer(g_rsi_handle, 0, 0, rates_total, g_rsi_buffer) <= 0) return 0;
    if(CopyBuffer(g_stoch_handle, 0, 0, rates_total, g_stoch_k_buffer) <= 0) return 0;
    if(CopyBuffer(g_stoch_handle, 1, 0, rates_total, g_stoch_d_buffer) <= 0) return 0;
    if(CopyBuffer(g_adx_handle, 0, 0, rates_total, g_adx_buffer) <= 0) return 0;
    if(CopyBuffer(g_atr_handle, 0, 0, rates_total, g_atr_buffer) <= 0) return 0;
    
    // Copy EMA data for subwindow (normalized)
    if(CopyBuffer(g_ema20_handle, 0, 0, rates_total, g_ema20_buffer) <= 0) return 0;
    if(CopyBuffer(g_ema50_handle, 0, 0, rates_total, g_ema50_buffer) <= 0) return 0;
    if(CopyBuffer(g_ema200_handle, 0, 0, rates_total, g_ema200_buffer) <= 0) return 0;
    
    // Normalize EMA values for subwindow display (scale to 0-100 range)
    NormalizeEMAs(rates_total, close);
    
    // Update regime detector
    if(g_regimeDetector != NULL)
    {
        g_regimeDetector.Update();
    }
    
    // Update key level detector
    if(g_keyLevelDetector != NULL)
    {
        g_keyLevelDetector.Update();
    }
    
    // Draw EMAs on main chart
    DrawEMAsOnChart();
    
    // Draw key levels
    if(InpShowKeyLevels && g_keyLevelDetector != NULL)
    {
        DrawKeyLevels();
    }
    
    // Draw regime info
    if(InpShowRegimeInfo && g_regimeDetector != NULL)
    {
        DrawRegimeInfo();
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Draw key levels on chart                                         |
//+------------------------------------------------------------------+
void DrawKeyLevels()
{
    if(g_keyLevelDetector == NULL) return;
    
    // Remove existing key level objects
    ObjectsDeleteAll(0, "GRANDE_CLEAN_KEY_");
    
    int levelCount = g_keyLevelDetector.GetKeyLevelCount();
    for(int i = 0; i < levelCount; i++)
    {
        KeyLevel level = g_keyLevelDetector.GetKeyLevel(i);
        if(level.price <= 0) continue;
        
        string objName = "GRANDE_CLEAN_KEY_" + IntegerToString(i);
        color levelColor = (level.type == KEY_LEVEL_SUPPORT) ? clrLime : clrRed;
        
        // Create horizontal line
        if(ObjectCreate(0, objName, OBJ_HLINE, 0, 0, level.price))
        {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, levelColor);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetString(0, objName, OBJPROP_TEXT, "S/R: " + DoubleToString(level.price, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Draw regime information                                          |
//+------------------------------------------------------------------+
void DrawRegimeInfo()
{
    if(g_regimeDetector == NULL) return;
    
    // Remove existing regime objects
    ObjectsDeleteAll(0, "GRANDE_CLEAN_REGIME_");
    
    RegimeSnapshot snapshot = g_regimeDetector.GetLastSnapshot();
    
    // Create regime label
    string objName = "GRANDE_CLEAN_REGIME_INFO";
    if(ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 10);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, InpTextColor);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, InpFontSize);
        ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
        
        string regimeText = "Regime: " + g_regimeDetector.RegimeToString(snapshot.regime) + 
                           " (Conf: " + DoubleToString(snapshot.confidence, 2) + ")";
        ObjectSetString(0, objName, OBJPROP_TEXT, regimeText);
    }
}

//+------------------------------------------------------------------+
//| Normalize EMA values for subwindow display                       |
//+------------------------------------------------------------------+
void NormalizeEMAs(int rates_total, const double &close[])
{
    if(rates_total < 2) return;
    
    // Find min/max price range for normalization
    double minPrice = close[0];
    double maxPrice = close[0];
    
    for(int i = 0; i < rates_total; i++)
    {
        if(close[i] < minPrice) minPrice = close[i];
        if(close[i] > maxPrice) maxPrice = close[i];
    }
    
    double priceRange = maxPrice - minPrice;
    if(priceRange == 0) return;
    
    // Normalize EMAs to 0-100 range
    for(int i = 0; i < rates_total; i++)
    {
        if(g_ema20_buffer[i] > 0)
            g_ema20_buffer[i] = ((g_ema20_buffer[i] - minPrice) / priceRange) * 100.0;
        if(g_ema50_buffer[i] > 0)
            g_ema50_buffer[i] = ((g_ema50_buffer[i] - minPrice) / priceRange) * 100.0;
        if(g_ema200_buffer[i] > 0)
            g_ema200_buffer[i] = ((g_ema200_buffer[i] - minPrice) / priceRange) * 100.0;
    }
}

//+------------------------------------------------------------------+
//| Draw EMAs on main chart                                          |
//+------------------------------------------------------------------+
void DrawEMAsOnChart()
{
    // Remove existing EMA objects
    ObjectsDeleteAll(0, "GRANDE_CLEAN_EMA_");
    
    // Get current EMA values
    double ema20 = GetIndicatorValue(g_ema20_handle, 0, 0);
    double ema50 = GetIndicatorValue(g_ema50_handle, 0, 0);
    double ema200 = GetIndicatorValue(g_ema200_handle, 0, 0);
    
    if(ema20 <= 0 || ema50 <= 0 || ema200 <= 0) return;
    
    // Draw EMA lines on chart
    datetime currentTime = TimeCurrent();
    
    // EMA 20
    if(ObjectCreate(0, "GRANDE_CLEAN_EMA_20", OBJ_HLINE, 0, 0, ema20))
    {
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_20", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_20", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_20", OBJPROP_WIDTH, 2);
        ObjectSetString(0, "GRANDE_CLEAN_EMA_20", OBJPROP_TEXT, "EMA 20: " + DoubleToString(ema20, _Digits));
    }
    
    // EMA 50
    if(ObjectCreate(0, "GRANDE_CLEAN_EMA_50", OBJ_HLINE, 0, 0, ema50))
    {
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_50", OBJPROP_COLOR, clrOrange);
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_50", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_50", OBJPROP_WIDTH, 2);
        ObjectSetString(0, "GRANDE_CLEAN_EMA_50", OBJPROP_TEXT, "EMA 50: " + DoubleToString(ema50, _Digits));
    }
    
    // EMA 200
    if(ObjectCreate(0, "GRANDE_CLEAN_EMA_200", OBJ_HLINE, 0, 0, ema200))
    {
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_200", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_200", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "GRANDE_CLEAN_EMA_200", OBJPROP_WIDTH, 3);
        ObjectSetString(0, "GRANDE_CLEAN_EMA_200", OBJPROP_TEXT, "EMA 200: " + DoubleToString(ema200, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Get current indicator values for display                         |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift = 0)
{
    if(handle == INVALID_HANDLE) return 0;
    
    double buffer_array[];
    ArraySetAsSeries(buffer_array, true);
    
    if(CopyBuffer(handle, buffer, 0, shift + 1, buffer_array) <= 0)
        return 0;
    
    return buffer_array[shift];
}
