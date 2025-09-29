//+------------------------------------------------------------------+
//| GrandeMonitorIndicator.mq5                                       |
//| Copyright 2024, Grande Tech                                      |
//| Monitor all Grande EA indicators without running the EA          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Monitor all Grande EA indicators and signals without running the EA"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots 6

// Plot properties for visual indicators
#property indicator_label1 "EMA 20"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrBlue
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1

#property indicator_label2 "EMA 50"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrOrange
#property indicator_style2 STYLE_SOLID
#property indicator_width2 1

#property indicator_label3 "EMA 200"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrRed
#property indicator_style3 STYLE_SOLID
#property indicator_width3 2

#property indicator_label4 "RSI"
#property indicator_type4 DRAW_LINE
#property indicator_color4 clrPurple
#property indicator_style4 STYLE_SOLID
#property indicator_width4 1

#property indicator_label5 "Stochastic %K"
#property indicator_type5 DRAW_LINE
#property indicator_color5 clrLime
#property indicator_style5 STYLE_SOLID
#property indicator_width5 1

#property indicator_label6 "Stochastic %D"
#property indicator_type6 DRAW_LINE
#property indicator_color6 clrYellow
#property indicator_style6 STYLE_SOLID
#property indicator_width6 1

// Include Grande EA components
#include "GrandeMarketRegimeDetector.mqh"
#include "GrandeKeyLevelDetector.mqh"
#include "GrandeMultiTimeframeAnalyzer.mqh"
#include "GrandeMT5CalendarReader.mqh"
#include "mcp/analyze_sentiment_server/GrandeNewsSentimentIntegration.mqh"
#include "GrandeDatabaseManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Display Settings ==="
input bool   InpShowRegimeInfo = true;           // Show Market Regime Information
input bool   InpShowKeyLevels = true;            // Show Key Levels
input bool   InpShowTechnicalIndicators = true;  // Show Technical Indicators
input bool   InpShowMultiTimeframe = true;       // Show Multi-Timeframe Analysis
input bool   InpShowRiskMetrics = true;          // Show Risk Management Metrics
input bool   InpShowTradingSignals = true;       // Show Trading Signals
input bool   InpShowCalendarEvents = true;       // Show Calendar Events
input color  InpTextColor = clrWhite;            // Text Color
input int    InpFontSize = 8;                    // Font Size
input string InpFontName = "Arial";              // Font Name

input group "=== Key Level Settings ==="
input int    InpKeyLevelLookback = 300;          // Key Level Lookback Period
input double InpKeyLevelMinStrength = 0.40;      // Minimum Level Strength
input double InpKeyLevelTouchZone = 0.0010;      // Touch Zone (0 = auto)
input int    InpKeyLevelMinTouches = 1;          // Minimum Touches Required

input group "=== Technical Indicator Settings ==="
input int    InpEMA20Period = 20;                // EMA 20 Period
input int    InpEMA50Period = 50;                // EMA 50 Period
input int    InpEMA200Period = 200;              // EMA 200 Period
input int    InpRSIPeriod = 14;                  // RSI Period
input int    InpStochPeriod = 14;                // Stochastic Period
input int    InpStochK = 3;                      // Stochastic %K
input int    InpStochD = 3;                      // Stochastic %D
input int    InpATRPeriod = 14;                  // ATR Period

input group "=== Market Regime Settings ==="
input double InpADXTrendThreshold = 25.0;        // ADX Threshold for Trending
input double InpADXBreakoutMin = 18.0;           // ADX Minimum for Breakout Setup

input group "=== Multi-Timeframe Settings ==="
input bool   InpShowH4Analysis = true;           // Show H4 Analysis
input bool   InpShowH1Analysis = true;           // Show H1 Analysis
input bool   InpShowM15Analysis = true;          // Show M15 Analysis

input group "=== Calendar Settings ==="
input bool   InpEnableCalendarAI = true;        // Enable Calendar AI analysis
input int    InpCalendarLookaheadHours = 24;     // Lookahead window for calendar events (hours)
input double InpCalendarMinConfidence = 0.60;    // Minimum confidence threshold

input group "=== Database Settings ==="
input bool   InpEnableDatabase = true;          // Enable Database Logging
input string InpDatabasePath = "GrandeTradingData.db"; // Database File Path
input bool   InpDatabaseDebug = false;           // Enable Database Debug Prints
input bool   InpShowDatabaseStatus = true;      // Show Database Status

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CGrandeMarketRegimeDetector* g_regimeDetector = NULL;
CGrandeKeyLevelDetector* g_keyLevelDetector = NULL;
CMultiTimeframeAnalyzer* g_multiTF = NULL;
CGrandeMT5NewsReader* g_calendarReader = NULL;
CNewsSentimentIntegration* g_newsSentiment = NULL;
CGrandeDatabaseManager* g_databaseManager = NULL;

// Indicator handles
int g_ema20_handle = INVALID_HANDLE;
int g_ema50_handle = INVALID_HANDLE;
int g_ema200_handle = INVALID_HANDLE;
int g_rsi_handle = INVALID_HANDLE;
int g_stoch_handle = INVALID_HANDLE;
int g_atr_handle = INVALID_HANDLE;

// Multi-timeframe handles
int g_ema50_h4_handle = INVALID_HANDLE;
int g_ema200_h4_handle = INVALID_HANDLE;
int g_rsi_h4_handle = INVALID_HANDLE;
int g_ema50_h1_handle = INVALID_HANDLE;
int g_ema200_h1_handle = INVALID_HANDLE;
int g_rsi_h1_handle = INVALID_HANDLE;

// Display variables
datetime g_lastUpdate = 0;
string g_displayText = "";
int g_displayY = 30;
int g_lineHeight = 16;
int g_displayX = 15;

// Indicator buffers for visual display
double g_ema20_buffer[];
double g_ema50_buffer[];
double g_ema200_buffer[];
double g_rsi_buffer[];
double g_stoch_k_buffer[];
double g_stoch_d_buffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Hide the grid for better readability
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, false);
    
    // Set up indicator buffers
    SetIndexBuffer(0, g_ema20_buffer, INDICATOR_DATA);
    SetIndexBuffer(1, g_ema50_buffer, INDICATOR_DATA);
    SetIndexBuffer(2, g_ema200_buffer, INDICATOR_DATA);
    SetIndexBuffer(3, g_rsi_buffer, INDICATOR_DATA);
    SetIndexBuffer(4, g_stoch_k_buffer, INDICATOR_DATA);
    SetIndexBuffer(5, g_stoch_d_buffer, INDICATOR_DATA);
    
    // Set buffer properties
    ArraySetAsSeries(g_ema20_buffer, true);
    ArraySetAsSeries(g_ema50_buffer, true);
    ArraySetAsSeries(g_ema200_buffer, true);
    ArraySetAsSeries(g_rsi_buffer, true);
    ArraySetAsSeries(g_stoch_k_buffer, true);
    ArraySetAsSeries(g_stoch_d_buffer, true);
    
    // Initialize Grande components
    if(!InitializeGrandeComponents())
    {
        Print("Failed to initialize Grande components");
        return INIT_FAILED;
    }
    
    // Initialize technical indicators
    if(!InitializeTechnicalIndicators())
    {
        Print("Failed to initialize technical indicators");
        return INIT_FAILED;
    }
    
    // Wait for indicators to be ready
    Sleep(1000); // Give indicators time to calculate
    
    // Initialize multi-timeframe indicators
    if(!InitializeMultiTimeframeIndicators())
    {
        Print("Failed to initialize multi-timeframe indicators");
        return INIT_FAILED;
    }
    
    Print("Grande Monitor Indicator initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Restore grid when indicator is removed
    ChartSetInteger(0, CHART_SHOW_GRID, true);
    ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, true);
    
    // Clean up Grande components
    if(g_regimeDetector != NULL)
    {
        delete g_regimeDetector;
        g_regimeDetector = NULL;
    }
    
    if(g_keyLevelDetector != NULL)
    {
        delete g_keyLevelDetector;
        g_keyLevelDetector = NULL;
    }
    
    if(g_multiTF != NULL)
    {
        delete g_multiTF;
        g_multiTF = NULL;
    }
    
    if(g_calendarReader != NULL)
    {
        delete g_calendarReader;
        g_calendarReader = NULL;
    }
    
    if(g_newsSentiment != NULL)
    {
        delete g_newsSentiment;
        g_newsSentiment = NULL;
    }
    
    if(g_databaseManager != NULL)
    {
        if(InpDatabaseDebug)
            Print("Closing database connection...");
        g_databaseManager.Close();
        delete g_databaseManager;
        g_databaseManager = NULL;
    }
    
    // Release indicator handles
    ReleaseIndicatorHandles();
    
    // Clear all chart objects
    ObjectsDeleteAll(0, "GRANDE_MONITOR_");
    
    Print("Grande Monitor Indicator deinitialized");
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
    // Calculate indicator values for visual display
    int start = prev_calculated;
    if(start == 0)
    {
        start = MathMax(0, rates_total - 1000); // Show last 1000 bars
        ArrayInitialize(g_ema20_buffer, EMPTY_VALUE);
        ArrayInitialize(g_ema50_buffer, EMPTY_VALUE);
        ArrayInitialize(g_ema200_buffer, EMPTY_VALUE);
        ArrayInitialize(g_rsi_buffer, EMPTY_VALUE);
        ArrayInitialize(g_stoch_k_buffer, EMPTY_VALUE);
        ArrayInitialize(g_stoch_d_buffer, EMPTY_VALUE);
    }
    
    // Populate indicator buffers
    for(int i = start; i < rates_total; i++)
    {
        if(i < rates_total - 1) // Don't calculate for the current bar
        {
            g_ema20_buffer[i] = GetIndicatorValueAtBar(g_ema20_handle, rates_total - 1 - i);
            g_ema50_buffer[i] = GetIndicatorValueAtBar(g_ema50_handle, rates_total - 1 - i);
            g_ema200_buffer[i] = GetIndicatorValueAtBar(g_ema200_handle, rates_total - 1 - i);
            g_rsi_buffer[i] = GetIndicatorValueAtBar(g_rsi_handle, rates_total - 1 - i);
            g_stoch_k_buffer[i] = GetIndicatorValueAtBar(g_stoch_handle, rates_total - 1 - i, 0);
            g_stoch_d_buffer[i] = GetIndicatorValueAtBar(g_stoch_handle, rates_total - 1 - i, 1);
        }
    }
    
    // Update text display every 5 seconds
    if(TimeCurrent() - g_lastUpdate < 5)
        return rates_total;
    
    g_lastUpdate = TimeCurrent();
    
    // Clear previous display
    ObjectsDeleteAll(0, "GRANDE_MONITOR_");
    
    // Update all components
    UpdateAllComponents();
    
    // Display information
    DisplayAllInformation();
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Initialize Grande components                                     |
//+------------------------------------------------------------------+
bool InitializeGrandeComponents()
{
    // Initialize market regime detector
    g_regimeDetector = new CGrandeMarketRegimeDetector();
    RegimeConfig config;
    if(!g_regimeDetector.Initialize(_Symbol, config, false))
    {
        Print("Failed to initialize regime detector");
        return false;
    }
    
    // Initialize key level detector
    g_keyLevelDetector = new CGrandeKeyLevelDetector();
    if(!g_keyLevelDetector.Initialize(InpKeyLevelLookback, InpKeyLevelMinStrength, 
                                     InpKeyLevelTouchZone, InpKeyLevelMinTouches, false, true))
    {
        Print("Failed to initialize key level detector");
        return false;
    }
    
    // Initialize multi-timeframe analyzer
    g_multiTF = new CMultiTimeframeAnalyzer();
    if(!g_multiTF.Initialize(_Symbol))
    {
        Print("Failed to initialize multi-timeframe analyzer");
        return false;
    }
    
    // Initialize calendar reader (non-fatal if unavailable)
    if(InpEnableCalendarAI)
    {
        g_calendarReader = new CGrandeMT5NewsReader();
        if(!g_calendarReader.Initialize(_Symbol))
        {
            Print("Failed to initialize calendar reader - calendar features disabled");
            delete g_calendarReader;
            g_calendarReader = NULL;
        }
        else
        {
            Print("Calendar reader initialized for ", _Symbol);
            
            // Check calendar availability and provide user guidance
            if(!g_calendarReader.CheckCalendarAvailability())
            {
                Print("[Monitor] ⚠️ Economic Calendar appears disabled or unavailable. Go to Tools > Options > Server and ensure 'Enable news' is checked. Then restart MT5 to allow calendar sync.");
            }
            
            // Initialize news sentiment integration only if calendar reader succeeded
            g_newsSentiment = new CNewsSentimentIntegration();
            if(!g_newsSentiment.Initialize())
            {
                Print("Failed to initialize news sentiment integration - AI analysis disabled");
                delete g_newsSentiment;
                g_newsSentiment = NULL;
            }
            else
            {
                Print("News sentiment integration initialized");
                
                // Try to load existing calendar analysis immediately with retry logic
                int retryCount = 0;
                bool loaded = false;
                while(retryCount < 3 && !loaded)
                {
                    if(g_newsSentiment.LoadLatestCalendarAnalysis())
                    {
                        Print("Loaded existing calendar analysis successfully");
                        loaded = true;
                    }
                    else
                    {
                        retryCount++;
                        Print("Calendar analysis not yet available, retry ", retryCount, "/3");
                        Sleep(1000); // Wait 1 second before retry
                    }
                }
                
                if(!loaded)
                {
                    Print("Info: Calendar analysis not available during initialization - will retry on next update cycle");
                }
            }
        }
    }
    
    // Initialize database manager
    if(InpEnableDatabase)
    {
        Print("[Monitor] Attempting to initialize Database Manager...");
        g_databaseManager = new CGrandeDatabaseManager();
        if(g_databaseManager == NULL)
        {
            Print("ERROR: Failed to create Database Manager");
        }
        else if(!g_databaseManager.Initialize(InpDatabasePath, InpDatabaseDebug))
        {
            Print("ERROR: Failed to initialize Database Manager");
            delete g_databaseManager;
            g_databaseManager = NULL;
            Print("[Monitor] WARNING: Database disabled due to initialization failure");
        }
        else
        {
            Print("[Monitor] ✅ Database Manager initialized successfully: ", InpDatabasePath);
        }
    }
    else
    {
        Print("[Monitor] Database logging is DISABLED");
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize technical indicators                                  |
//+------------------------------------------------------------------+
bool InitializeTechnicalIndicators()
{
    // Current timeframe indicators
    g_ema20_handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA20Period, 0, MODE_EMA, PRICE_CLOSE);
    g_ema50_handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
    g_ema200_handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
    g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    g_stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochPeriod, InpStochK, InpStochD, MODE_SMA, STO_LOWHIGH);
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
    
    // Check if all handles are valid
    if(g_ema20_handle == INVALID_HANDLE || g_ema50_handle == INVALID_HANDLE || 
       g_ema200_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE ||
       g_stoch_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE)
    {
        Print("Failed to create technical indicator handles");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize multi-timeframe indicators                           |
//+------------------------------------------------------------------+
bool InitializeMultiTimeframeIndicators()
{
    // H4 indicators
    g_ema50_h4_handle = iMA(_Symbol, PERIOD_H4, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
    g_ema200_h4_handle = iMA(_Symbol, PERIOD_H4, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
    g_rsi_h4_handle = iRSI(_Symbol, PERIOD_H4, InpRSIPeriod, PRICE_CLOSE);
    
    // H1 indicators
    g_ema50_h1_handle = iMA(_Symbol, PERIOD_H1, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
    g_ema200_h1_handle = iMA(_Symbol, PERIOD_H1, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
    g_rsi_h1_handle = iRSI(_Symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);
    
    return true;
}

//+------------------------------------------------------------------+
//| Update all components                                           |
//+------------------------------------------------------------------+
void UpdateAllComponents()
{
    // Update regime detection
    if(g_regimeDetector != NULL)
    {
        g_regimeDetector.DetectCurrentRegime();
    }
    
    // Update key level detection
    if(g_keyLevelDetector != NULL)
    {
        g_keyLevelDetector.DetectKeyLevels();
        g_keyLevelDetector.UpdateChartDisplay();
    }
    
    // Update multi-timeframe analysis
    if(g_multiTF != NULL && g_regimeDetector != NULL)
    {
        RegimeSnapshot snapshot = g_regimeDetector.GetLastSnapshot();
        g_multiTF.GetConsensusDecision(snapshot);
    }
    
    // Update calendar analysis (periodic) - enhanced stability
    if(InpEnableCalendarAI && g_calendarReader != NULL && g_newsSentiment != NULL)
    {
        static datetime lastCalendarUpdate = 0;
        static bool calendarInitialized = false;
        static int calendarLoadAttempts = 0;
        datetime currentTime = TimeCurrent();
        
        // First run: try to load existing analysis immediately
        if(!calendarInitialized)
        {
            if(g_newsSentiment.LoadLatestCalendarAnalysis())
            {
                Print("Monitor: Loaded existing calendar analysis");
                calendarInitialized = true;
            }
                else
                {
                    calendarLoadAttempts++;
                    if(calendarLoadAttempts < 5)
                    {
                        Print("Monitor: Calendar analysis not yet available (attempt ", calendarLoadAttempts, "/5) - will retry");
                    }
                    else
                    {
                        Print("Monitor: Calendar analysis not available - will retry on next update cycle");
                        calendarInitialized = true; // Stop trying
                    }
                }
            lastCalendarUpdate = currentTime;
        }
        
        // Update calendar every 15 minutes
        if(currentTime - lastCalendarUpdate >= 900) // 15 minutes
        {
            // Check if calendar is still available before updating
            if(g_calendarReader.IsCalendarAvailable())
            {
                bool eventsOk = g_calendarReader.GetEconomicCalendarEvents(InpCalendarLookaheadHours);
                if(eventsOk)
                {
                    // Try to run calendar analysis
                    bool analyzed = g_newsSentiment.RunCalendarAnalysis();
                    if(!analyzed)
                    {
                        // Fallback: try to load latest analysis
                        if(g_newsSentiment.LoadLatestCalendarAnalysis())
                        {
                            Print("Monitor: Reloaded calendar analysis");
                        }
                    }
                    else
                    {
                        Print("Monitor: Calendar analysis updated");
                    }
                }
                else
                {
                    Print("Monitor: Calendar events fetch failed");
                }
            }
            else
            {
                // Calendar became unavailable, try to reload existing data
                if(g_newsSentiment.LoadLatestCalendarAnalysis())
                {
                    Print("Monitor: Reloaded existing calendar data");
                }
                else
                {
                    Print("Monitor: Calendar unavailable and no cached data");
                }
            }
            lastCalendarUpdate = currentTime;
        }
    }
}

//+------------------------------------------------------------------+
//| Display all information                                         |
//+------------------------------------------------------------------+
void DisplayAllInformation()
{
    int yPos = g_displayY;
    
    // Display header
    CreateLabel("GRANDE_MONITOR_HEADER", "=== GRANDE EA MONITOR ===", g_displayX, yPos, InpTextColor, InpFontSize + 2, true);
    yPos += g_lineHeight + 5;
    
    // Market Regime Information
    if(InpShowRegimeInfo)
    {
        yPos = DisplayMarketRegimeInfo(yPos);
        yPos += 10;
    }
    
    // Key Levels Information
    if(InpShowKeyLevels)
    {
        yPos = DisplayKeyLevelsInfo(yPos);
        yPos += 10;
    }
    
    // Technical Indicators
    if(InpShowTechnicalIndicators)
    {
        yPos = DisplayTechnicalIndicators(yPos);
        yPos += 10;
    }
    
    // Multi-Timeframe Analysis
    if(InpShowMultiTimeframe)
    {
        yPos = DisplayMultiTimeframeAnalysis(yPos);
        yPos += 10;
    }
    
    // Risk Metrics
    if(InpShowRiskMetrics)
    {
        yPos = DisplayRiskMetrics(yPos);
        yPos += 10;
    }
    
    // Trading Signals
    if(InpShowTradingSignals)
    {
        yPos = DisplayTradingSignals(yPos);
        yPos += 10;
    }
    
    // Calendar Events
    if(InpShowCalendarEvents)
    {
        yPos = DisplayCalendarEvents(yPos);
    }
    
    // Database Status
    if(InpShowDatabaseStatus)
    {
        yPos = DisplayDatabaseStatus(yPos);
    }
}

//+------------------------------------------------------------------+
//| Display market regime information                               |
//+------------------------------------------------------------------+
int DisplayMarketRegimeInfo(int yPos)
{
    if(g_regimeDetector == NULL) return yPos;
    
    RegimeSnapshot snapshot = g_regimeDetector.GetLastSnapshot();
    
    CreateLabel("GRANDE_MONITOR_REGIME_HEADER", "📊 MARKET REGIME", g_displayX, yPos, clrYellow, InpFontSize + 1, true);
    yPos += g_lineHeight;
    
    string regimeText = g_regimeDetector.RegimeToString(snapshot.regime);
    color regimeColor = GetRegimeColor(snapshot.regime);
    
    CreateLabel("GRANDE_MONITOR_REGIME", "Regime: " + regimeText, g_displayX + 5, yPos, regimeColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_CONFIDENCE", "Confidence: " + DoubleToString(snapshot.confidence * 100, 1) + "%", g_displayX + 5, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_ADX", "ADX: " + DoubleToString(snapshot.adx_h1, 1) + " | +DI: " + DoubleToString(snapshot.plus_di, 1) + " | -DI: " + DoubleToString(snapshot.minus_di, 1), g_displayX + 5, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_ADX_THRESHOLDS", "ADX Thresholds: Trend>" + DoubleToString(InpADXTrendThreshold, 1) + " Breakout>" + DoubleToString(InpADXBreakoutMin, 1), g_displayX + 5, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_ATR", "ATR: " + DoubleToString(snapshot.atr_current, 5) + " | Avg: " + DoubleToString(snapshot.atr_avg, 5), g_displayX + 5, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    return yPos;
}

//+------------------------------------------------------------------+
//| Display key levels information                                  |
//+------------------------------------------------------------------+
int DisplayKeyLevelsInfo(int yPos)
{
    if(g_keyLevelDetector == NULL) return yPos;
    
    CreateLabel("GRANDE_MONITOR_LEVELS_HEADER", "🎯 KEY LEVELS", 10, yPos, clrYellow, InpFontSize + 1, true);
    yPos += g_lineHeight;
    
    int levelCount = g_keyLevelDetector.GetKeyLevelCount();
    CreateLabel("GRANDE_MONITOR_LEVELS_COUNT", "Total Levels: " + IntegerToString(levelCount), 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    // Display top 5 key levels
    for(int i = 0; i < MathMin(5, levelCount); i++)
    {
        SKeyLevel level;
        if(g_keyLevelDetector.GetKeyLevel(i, level))
        {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double distance = MathAbs(level.price - currentPrice);
            double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            if(pipSize <= 0) pipSize = _Point;
            
            string levelType = level.isResistance ? "RES" : "SUP";
            string direction = level.price > currentPrice ? "↑" : "↓";
            color levelColor = level.isResistance ? clrRed : clrGreen;
            
            string levelText = StringFormat("#%d %s %s %.5f (%.0fp) S:%.2f T:%d", 
                                          level.detectionOrder, direction, levelType, 
                                          level.price, distance/pipSize, 
                                          level.strength, level.touchCount);
            
            CreateLabel("GRANDE_MONITOR_LEVEL_" + IntegerToString(i), levelText, 15, yPos, levelColor, InpFontSize, false);
            yPos += g_lineHeight;
        }
    }
    
    return yPos;
}

//+------------------------------------------------------------------+
//| Display technical indicators                                     |
//+------------------------------------------------------------------+
int DisplayTechnicalIndicators(int yPos)
{
    CreateLabel("GRANDE_MONITOR_TECH_HEADER", "📈 TECHNICAL INDICATORS", 10, yPos, clrYellow, InpFontSize + 1, true);
    yPos += g_lineHeight;
    
    // Get current values
    double ema20 = GetIndicatorValue(g_ema20_handle, 0);
    double ema50 = GetIndicatorValue(g_ema50_handle, 0);
    double ema200 = GetIndicatorValue(g_ema200_handle, 0);
    double rsi = GetIndicatorValue(g_rsi_handle, 0);
    double stoch_main = GetIndicatorValue(g_stoch_handle, 0);
    double stoch_signal = GetIndicatorValue(g_stoch_handle, 1);
    double atr = GetIndicatorValue(g_atr_handle, 0);
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // EMA Analysis
    string emaTrend = "NEUTRAL";
    color emaColor = InpTextColor;
    if(ema20 > ema50 && ema50 > ema200)
    {
        emaTrend = "BULLISH";
        emaColor = clrGreen;
    }
    else if(ema20 < ema50 && ema50 < ema200)
    {
        emaTrend = "BEARISH";
        emaColor = clrRed;
    }
    
    CreateLabel("GRANDE_MONITOR_EMA", "EMA 20/50/200: " + DoubleToString(ema20, 5) + " / " + DoubleToString(ema50, 5) + " / " + DoubleToString(ema200, 5), 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_EMA_TREND", "EMA Trend: " + emaTrend, 15, yPos, emaColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    // RSI Analysis
    string rsiSignal = "NEUTRAL";
    color rsiColor = InpTextColor;
    if(rsi > 70)
    {
        rsiSignal = "OVERBOUGHT";
        rsiColor = clrRed;
    }
    else if(rsi < 30)
    {
        rsiSignal = "OVERSOLD";
        rsiColor = clrGreen;
    }
    
    CreateLabel("GRANDE_MONITOR_RSI", "RSI: " + DoubleToString(rsi, 1) + " (" + rsiSignal + ")", 15, yPos, rsiColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    // Stochastic Analysis
    string stochSignal = "NEUTRAL";
    color stochColor = InpTextColor;
    if(stoch_main > 80 && stoch_signal > 80)
    {
        stochSignal = "OVERBOUGHT";
        stochColor = clrRed;
    }
    else if(stoch_main < 20 && stoch_signal < 20)
    {
        stochSignal = "OVERSOLD";
        stochColor = clrGreen;
    }
    else if(stoch_main > stoch_signal)
    {
        stochSignal = "BULLISH";
        stochColor = clrGreen;
    }
    else if(stoch_main < stoch_signal)
    {
        stochSignal = "BEARISH";
        stochColor = clrRed;
    }
    
    CreateLabel("GRANDE_MONITOR_STOCH", "Stoch: " + DoubleToString(stoch_main, 1) + "/" + DoubleToString(stoch_signal, 1) + " (" + stochSignal + ")", 15, yPos, stochColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    // ATR
    CreateLabel("GRANDE_MONITOR_ATR", "ATR: " + DoubleToString(atr, 5), 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    return yPos;
}

//+------------------------------------------------------------------+
//| Display multi-timeframe analysis                                |
//+------------------------------------------------------------------+
int DisplayMultiTimeframeAnalysis(int yPos)
{
    CreateLabel("GRANDE_MONITOR_MTF_HEADER", "⏰ MULTI-TIMEFRAME ANALYSIS", 10, yPos, clrYellow, InpFontSize + 1, true);
    yPos += g_lineHeight;
    
    if(g_multiTF == NULL || g_regimeDetector == NULL) return yPos;
    
    RegimeSnapshot snapshot = g_regimeDetector.GetLastSnapshot();
    string consensus = g_multiTF.GetConsensusDecision(snapshot);
    double strength = g_multiTF.GetConsensusStrength();
    
    color consensusColor = GetConsensusColor(consensus);
    CreateLabel("GRANDE_MONITOR_CONSENSUS", "Consensus: " + consensus, 15, yPos, consensusColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_STRENGTH", "Strength: " + DoubleToString(strength, 1) + "%", 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    // Individual timeframe analysis
    if(InpShowH4Analysis)
    {
        double ema50_h4 = GetIndicatorValue(g_ema50_h4_handle, 0);
        double ema200_h4 = GetIndicatorValue(g_ema200_h4_handle, 0);
        double rsi_h4 = GetIndicatorValue(g_rsi_h4_handle, 0);
        
        string h4Trend = "NEUTRAL";
        if(ema50_h4 > ema200_h4) h4Trend = "BULLISH";
        else if(ema50_h4 < ema200_h4) h4Trend = "BEARISH";
        
        CreateLabel("GRANDE_MONITOR_H4", "H4: " + h4Trend + " (EMA50:" + DoubleToString(ema50_h4, 5) + " RSI:" + DoubleToString(rsi_h4, 1) + ")", 15, yPos, InpTextColor, InpFontSize, false);
        yPos += g_lineHeight;
    }
    
    if(InpShowH1Analysis)
    {
        double ema50_h1 = GetIndicatorValue(g_ema50_h1_handle, 0);
        double ema200_h1 = GetIndicatorValue(g_ema200_h1_handle, 0);
        double rsi_h1 = GetIndicatorValue(g_rsi_h1_handle, 0);
        
        string h1Trend = "NEUTRAL";
        if(ema50_h1 > ema200_h1) h1Trend = "BULLISH";
        else if(ema50_h1 < ema200_h1) h1Trend = "BEARISH";
        
        CreateLabel("GRANDE_MONITOR_H1", "H1: " + h1Trend + " (EMA50:" + DoubleToString(ema50_h1, 5) + " RSI:" + DoubleToString(rsi_h1, 1) + ")", 15, yPos, InpTextColor, InpFontSize, false);
        yPos += g_lineHeight;
    }
    
    return yPos;
}

//+------------------------------------------------------------------+
//| Display risk metrics                                            |
//+------------------------------------------------------------------+
int DisplayRiskMetrics(int yPos)
{
    CreateLabel("GRANDE_MONITOR_RISK_HEADER", "⚠️ RISK METRICS", 10, yPos, clrYellow, InpFontSize + 1, true);
    yPos += g_lineHeight;
    
    // Account information
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double margin = AccountInfoDouble(ACCOUNT_MARGIN);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    
    CreateLabel("GRANDE_MONITOR_EQUITY", "Equity: $" + DoubleToString(equity, 2), 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_BALANCE", "Balance: $" + DoubleToString(balance, 2), 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_MARGIN", "Margin Level: " + DoubleToString(marginLevel, 2) + "%", 15, yPos, GetMarginLevelColor(marginLevel), InpFontSize, false);
    yPos += g_lineHeight;
    
    // Open positions
    int totalPositions = PositionsTotal();
    int buyPositions = 0;
    int sellPositions = 0;
    double totalProfit = 0;
    
    for(int i = 0; i < totalPositions; i++)
    {
        if(PositionGetSymbol(i) == _Symbol)
        {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                buyPositions++;
            else
                sellPositions++;
            totalProfit += PositionGetDouble(POSITION_PROFIT);
        }
    }
    
    CreateLabel("GRANDE_MONITOR_POSITIONS", "Positions: " + IntegerToString(totalPositions) + " (B:" + IntegerToString(buyPositions) + " S:" + IntegerToString(sellPositions) + ")", 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    color profitColor = totalProfit >= 0 ? clrGreen : clrRed;
    CreateLabel("GRANDE_MONITOR_PROFIT", "P&L: $" + DoubleToString(totalProfit, 2), 15, yPos, profitColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    return yPos;
}

//+------------------------------------------------------------------+
//| Display trading signals                                         |
//+------------------------------------------------------------------+
int DisplayTradingSignals(int yPos)
{
    CreateLabel("GRANDE_MONITOR_SIGNALS_HEADER", "🚦 TRADING SIGNALS", 10, yPos, clrYellow, InpFontSize + 1, true);
    yPos += g_lineHeight;
    
    if(g_regimeDetector == NULL) return yPos;
    
    RegimeSnapshot snapshot = g_regimeDetector.GetLastSnapshot();
    
    // Generate trading signals based on regime and indicators
    string primarySignal = "NEUTRAL";
    color signalColor = InpTextColor;
    
    // Get current indicator values
    double ema20 = GetIndicatorValue(g_ema20_handle, 0);
    double ema50 = GetIndicatorValue(g_ema50_handle, 0);
    double ema200 = GetIndicatorValue(g_ema200_handle, 0);
    double rsi = GetIndicatorValue(g_rsi_handle, 0);
    double stoch_main = GetIndicatorValue(g_stoch_handle, 0);
    double stoch_signal = GetIndicatorValue(g_stoch_handle, 1);
    
    // Signal logic based on Grande EA rules
    if(snapshot.regime == REGIME_TREND_BULL && snapshot.confidence > 0.6)
    {
        if(ema20 > ema50 && rsi > 50 && stoch_main > stoch_signal)
        {
            primarySignal = "STRONG BUY";
            signalColor = clrLime;
        }
        else
        {
            primarySignal = "WEAK BUY";
            signalColor = clrGreen;
        }
    }
    else if(snapshot.regime == REGIME_TREND_BEAR && snapshot.confidence > 0.6)
    {
        if(ema20 < ema50 && rsi < 50 && stoch_main < stoch_signal)
        {
            primarySignal = "STRONG SELL";
            signalColor = clrRed;
        }
        else
        {
            primarySignal = "WEAK SELL";
            signalColor = clrOrange;
        }
    }
    else if(snapshot.regime == REGIME_BREAKOUT_SETUP)
    {
        primarySignal = "BREAKOUT WATCH";
        signalColor = clrYellow;
    }
    else if(snapshot.regime == REGIME_RANGING)
    {
        primarySignal = "RANGE TRADE";
        signalColor = clrCyan;
    }
    else if(snapshot.regime == REGIME_HIGH_VOLATILITY)
    {
        primarySignal = "HIGH VOL - CAUTION";
        signalColor = clrMagenta;
    }
    
    CreateLabel("GRANDE_MONITOR_PRIMARY_SIGNAL", "Primary Signal: " + primarySignal, 15, yPos, signalColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    // Additional signal details
    CreateLabel("GRANDE_MONITOR_SIGNAL_DETAILS", "Regime: " + g_regimeDetector.RegimeToString(snapshot.regime) + " | Conf: " + DoubleToString(snapshot.confidence * 100, 1) + "%", 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    return yPos;
}

//+------------------------------------------------------------------+
//| Display calendar events                                         |
//+------------------------------------------------------------------+
int DisplayCalendarEvents(int yPos)
{
    CreateLabel("GRANDE_MONITOR_CALENDAR_HEADER", "📅 CALENDAR EVENTS", 10, yPos, clrYellow, InpFontSize + 1, true);
    yPos += g_lineHeight;
    
    if(!InpEnableCalendarAI)
    {
        CreateLabel("GRANDE_MONITOR_CALENDAR", "Calendar AI: DISABLED", 15, yPos, clrGray, InpFontSize, false);
        yPos += g_lineHeight;
        return yPos;
    }
    
    if(g_calendarReader == NULL || g_newsSentiment == NULL)
    {
        CreateLabel("GRANDE_MONITOR_CALENDAR", "Calendar: NOT INITIALIZED", 15, yPos, clrRed, InpFontSize, false);
        yPos += g_lineHeight;
        return yPos;
    }
    
    // Get calendar signal and confidence
    string calendarSignal = "";
    double calendarConfidence = 0.0;
    double calendarScore = 0.0;
    
    // Safely get calendar data
    if(g_newsSentiment != NULL)
    {
        calendarSignal = g_newsSentiment.GetCalendarSignal();
        calendarConfidence = g_newsSentiment.GetCalendarConfidence();
        calendarScore = g_newsSentiment.GetCalendarScore();
    }
    
    // Display calendar status with enhanced information
    if(StringLen(calendarSignal) > 0)
    {
        color signalColor = clrWhite;
        if(calendarConfidence >= InpCalendarMinConfidence)
        {
            if(StringFind(calendarSignal, "BULLISH") >= 0 || StringFind(calendarSignal, "POSITIVE") >= 0)
                signalColor = clrGreen;
            else if(StringFind(calendarSignal, "BEARISH") >= 0 || StringFind(calendarSignal, "NEGATIVE") >= 0)
                signalColor = clrRed;
            else
                signalColor = clrYellow;
        }
        else
        {
            signalColor = clrGray;
        }
        
        CreateLabel("GRANDE_MONITOR_CALENDAR_SIGNAL", "Signal: " + calendarSignal, 15, yPos, signalColor, InpFontSize, false);
        yPos += g_lineHeight;
        
        CreateLabel("GRANDE_MONITOR_CALENDAR_CONFIDENCE", "Confidence: " + DoubleToString(calendarConfidence * 100, 1) + "%", 15, yPos, InpTextColor, InpFontSize, false);
        yPos += g_lineHeight;
        
        CreateLabel("GRANDE_MONITOR_CALENDAR_SCORE", "Score: " + DoubleToString(calendarScore, 2), 15, yPos, InpTextColor, InpFontSize, false);
        yPos += g_lineHeight;
        
        // Show confidence threshold
        string thresholdText = "Threshold: " + DoubleToString(InpCalendarMinConfidence * 100, 1) + "%";
        color thresholdColor = (calendarConfidence >= InpCalendarMinConfidence) ? clrGreen : clrRed;
        CreateLabel("GRANDE_MONITOR_CALENDAR_THRESHOLD", thresholdText, 15, yPos, thresholdColor, InpFontSize, false);
        yPos += g_lineHeight;
        
        // Show event count if available
        int eventCount = g_newsSentiment.GetEventCount();
        if(eventCount > 0)
        {
            CreateLabel("GRANDE_MONITOR_CALENDAR_EVENTS", "Events: " + IntegerToString(eventCount), 15, yPos, InpTextColor, InpFontSize, false);
            yPos += g_lineHeight;
        }
    }
    else
    {
        // Show detailed status based on initialization
        if(g_calendarReader == NULL)
        {
            CreateLabel("GRANDE_MONITOR_CALENDAR", "Calendar: READER NOT INITIALIZED", 15, yPos, clrRed, InpFontSize, false);
        }
        else if(g_newsSentiment == NULL)
        {
            CreateLabel("GRANDE_MONITOR_CALENDAR", "Calendar: SENTIMENT NOT INITIALIZED", 15, yPos, clrRed, InpFontSize, false);
        }
        else
        {
            // Check if calendar is available
            bool calendarAvailable = g_calendarReader.IsCalendarAvailable();
            if(calendarAvailable)
            {
                CreateLabel("GRANDE_MONITOR_CALENDAR", "Calendar: LOADING ANALYSIS...", 15, yPos, clrCyan, InpFontSize, false);
            }
            else
            {
                CreateLabel("GRANDE_MONITOR_CALENDAR", "Calendar: MT5 CALENDAR UNAVAILABLE", 15, yPos, clrOrange, InpFontSize, false);
            }
        }
        yPos += g_lineHeight;
    }
    
    // Display calendar availability status with helpful guidance
    bool calendarAvailable = false;
    if(g_calendarReader != NULL)
    {
        calendarAvailable = g_calendarReader.IsCalendarAvailable();
    }
    
    string availabilityText = calendarAvailable ? "Calendar: AVAILABLE" : "Calendar: UNAVAILABLE";
    color availabilityColor = calendarAvailable ? clrGreen : clrRed;
    CreateLabel("GRANDE_MONITOR_CALENDAR_AVAILABILITY", availabilityText, 15, yPos, availabilityColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    // Add helpful guidance if calendar is unavailable
    if(!calendarAvailable && g_calendarReader != NULL)
    {
        CreateLabel("GRANDE_MONITOR_CALENDAR_HELP", "Tip: Enable 'News' in Tools > Options > Server", 15, yPos, clrYellow, InpFontSize, false);
        yPos += g_lineHeight;
    }
    
    // Display lookahead window
    CreateLabel("GRANDE_MONITOR_CALENDAR_WINDOW", "Lookahead: " + IntegerToString(InpCalendarLookaheadHours) + " hours", 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    return yPos;
}

//+------------------------------------------------------------------+
//| Display database status                                          |
//+------------------------------------------------------------------+
int DisplayDatabaseStatus(int yPos)
{
    CreateLabel("GRANDE_MONITOR_DB_HEADER", "🗄️ DATABASE STATUS", 10, yPos, clrYellow, InpFontSize + 1, true);
    yPos += g_lineHeight;
    
    if(!InpEnableDatabase)
    {
        CreateLabel("GRANDE_MONITOR_DB", "Database: DISABLED", 15, yPos, clrGray, InpFontSize, false);
        yPos += g_lineHeight;
        return yPos;
    }
    
    if(g_databaseManager == NULL)
    {
        CreateLabel("GRANDE_MONITOR_DB", "Database: NOT INITIALIZED", 15, yPos, clrRed, InpFontSize, false);
        yPos += g_lineHeight;
        return yPos;
    }
    
    bool isConnected = g_databaseManager.IsConnected();
    string statusText = isConnected ? "Database: CONNECTED" : "Database: DISCONNECTED";
    color statusColor = isConnected ? clrGreen : clrRed;
    
    CreateLabel("GRANDE_MONITOR_DB_STATUS", statusText, 15, yPos, statusColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    CreateLabel("GRANDE_MONITOR_DB_PATH", "Path: " + InpDatabasePath, 15, yPos, InpTextColor, InpFontSize, false);
    yPos += g_lineHeight;
    
    // Show database file size if connected
    if(isConnected)
    {
        CreateLabel("GRANDE_MONITOR_DB_INFO", "Status: ACTIVE & LOGGING", 15, yPos, clrGreen, InpFontSize, false);
        yPos += g_lineHeight;
    }
    
    return yPos;
}

//+------------------------------------------------------------------+
//| Helper Functions                                                |
//+------------------------------------------------------------------+

// Create a text label on the chart
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize, bool bold)
{
    if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);  // Add background for better readability
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrNONE);
        ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrNONE);
    }
}

// Get indicator value safely
double GetIndicatorValue(int handle, int buffer)
{
    if(handle == INVALID_HANDLE) return 0.0;
    
    // Check if indicator is ready
    if(BarsCalculated(handle) < 0) return 0.0;
    
    double buffer_array[];
    ArraySetAsSeries(buffer_array, true);
    
    if(CopyBuffer(handle, buffer, 0, 1, buffer_array) > 0)
        return buffer_array[0];
    
    return 0.0;
}

// Get indicator value at specific bar
double GetIndicatorValueAtBar(int handle, int bar, int buffer = 0)
{
    if(handle == INVALID_HANDLE) return EMPTY_VALUE;
    
    // Check if indicator is ready
    if(BarsCalculated(handle) < 0) return EMPTY_VALUE;
    
    double buffer_array[];
    ArraySetAsSeries(buffer_array, true);
    
    if(CopyBuffer(handle, buffer, bar, 1, buffer_array) > 0)
        return buffer_array[0];
    
    return EMPTY_VALUE;
}

// Get regime color
color GetRegimeColor(MARKET_REGIME regime)
{
    switch(regime)
    {
        case REGIME_TREND_BULL: return clrGreen;
        case REGIME_TREND_BEAR: return clrRed;
        case REGIME_BREAKOUT_SETUP: return clrYellow;
        case REGIME_RANGING: return clrCyan;
        case REGIME_HIGH_VOLATILITY: return clrMagenta;
        default: return InpTextColor;
    }
}

// Get consensus color
color GetConsensusColor(string consensus)
{
    if(StringFind(consensus, "STRONG_LONG") >= 0) return clrLime;
    if(StringFind(consensus, "STRONG_SHORT") >= 0) return clrRed;
    if(StringFind(consensus, "STRONG_BREAKOUT") >= 0) return clrYellow;
    if(StringFind(consensus, "STRONG_RANGE") >= 0) return clrCyan;
    if(StringFind(consensus, "WEAK_LONG") >= 0) return clrGreen;
    if(StringFind(consensus, "WEAK_SHORT") >= 0) return clrOrange;
    return InpTextColor;
}

// Get margin level color
color GetMarginLevelColor(double marginLevel)
{
    if(marginLevel > 500) return clrGreen;
    if(marginLevel > 200) return clrYellow;
    if(marginLevel > 100) return clrOrange;
    return clrRed;
}

// Release all indicator handles
void ReleaseIndicatorHandles()
{
    if(g_ema20_handle != INVALID_HANDLE) IndicatorRelease(g_ema20_handle);
    if(g_ema50_handle != INVALID_HANDLE) IndicatorRelease(g_ema50_handle);
    if(g_ema200_handle != INVALID_HANDLE) IndicatorRelease(g_ema200_handle);
    if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
    if(g_stoch_handle != INVALID_HANDLE) IndicatorRelease(g_stoch_handle);
    if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
    if(g_ema50_h4_handle != INVALID_HANDLE) IndicatorRelease(g_ema50_h4_handle);
    if(g_ema200_h4_handle != INVALID_HANDLE) IndicatorRelease(g_ema200_h4_handle);
    if(g_rsi_h4_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_h4_handle);
    if(g_ema50_h1_handle != INVALID_HANDLE) IndicatorRelease(g_ema50_h1_handle);
    if(g_ema200_h1_handle != INVALID_HANDLE) IndicatorRelease(g_ema200_h1_handle);
    if(g_rsi_h1_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_h1_handle);
}
