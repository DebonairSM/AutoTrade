//+------------------------------------------------------------------+
//| AdvancedTrendFollower.mqh                                        |
//| Copyright 2024, VTrade Framework                                 |
//| Advanced Multi-Timeframe Trend Following System                 |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Official MQL5 Expert Advisor patterns and event handling

#property copyright "Copyright 2024, VTrade Framework"
#property link      "https://www.vtradeframework.com"
#property version   "1.00"
#property description "Advanced multi-timeframe trend following system with diagnostic UI"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== EMA Settings ==="
input int InpEmaFastPeriod = 50;        // Fast EMA Period
input int InpEmaSlowPeriod = 200;       // Slow EMA Period  
input int InpEmaPullbackPeriod = 20;    // Pullback EMA Period

input group "=== MACD Settings ==="
input int InpMacdFastPeriod = 12;       // MACD Fast Period
input int InpMacdSlowPeriod = 26;       // MACD Slow Period
input int InpMacdSignalPeriod = 9;      // MACD Signal Period

input group "=== RSI Settings ==="
input int InpRsiPeriod = 14;            // RSI Period
input double InpRsiThreshold = 50.0;    // RSI Threshold

input group "=== ADX Settings ==="
input int InpAdxPeriod = 14;            // ADX Period
input double InpAdxThreshold = 25.0;    // ADX Minimum Threshold

input group "=== UI Settings ==="
input bool InpShowDiagnosticPanel = true;  // Show Diagnostic Panel
input int InpPanelXOffset = 10;             // Panel X Offset
input int InpPanelYOffset = 280;            // Panel Y Offset (moved below Grande header)
input bool InpLogDebugInfo = false;         // Log Debug Information

//+------------------------------------------------------------------+
//| MCP Logging Constants                                            |
//+------------------------------------------------------------------+
#define MCP_LOG_PREFIX "[TREND_FOLLOWER] "

//+------------------------------------------------------------------+
//| Advanced Trend Follower Class                                   |
//+------------------------------------------------------------------+
class CAdvancedTrendFollower
{
private:
    // === Indicator Handles ===
    // H1 Timeframe
    int m_emaFastH1Handle;
    int m_emaSlowH1Handle;
    int m_emaPullbackH1Handle;
    int m_macdH1Handle;
    int m_rsiH1Handle;
    int m_adxH1Handle;
    
    // H4 Timeframe
    int m_emaFastH4Handle;
    int m_emaSlowH4Handle;
    int m_adxH4Handle;
    
    // D1 Timeframe
    int m_emaFastD1Handle;
    int m_emaSlowD1Handle;
    int m_adxD1Handle;
    
    // === Indicator Buffers ===
    // H1 Buffers
    double m_emaFastH1[];
    double m_emaSlowH1[];
    double m_emaPullbackH1[];
    double m_macdMainH1[];
    double m_macdSignalH1[];
    double m_rsiH1[];
    double m_adxH1[];
    
    // H4 Buffers
    double m_emaFastH4[];
    double m_emaSlowH4[];
    double m_adxH4[];
    
    // D1 Buffers
    double m_emaFastD1[];
    double m_emaSlowD1[];
    double m_adxD1[];
    
    // === Configuration ===
    bool m_isInitialized;
    bool m_showDiagnosticPanel;
    
    // === UI Panel Management ===
    string m_panelObjectName;
    int m_panelXOffset;
    int m_panelYOffset;
    
    // === Helper Methods ===
    void MCP_LogError(const string message);
    void MCP_LogInfo(const string message);
    bool ValidateInputParameters();
    bool CreateIndicatorHandles();
    void ReleaseIndicatorHandles();
    bool CopyIndicatorData();
    void MCP_UI_CreatePanel();
    void MCP_UI_UpdatePanel();
    void UpdatePanelText(const string trendMode, const double adxValue, 
                        const bool h1Aligned, const bool h4Aligned, const bool d1Aligned);

public:
    //+------------------------------------------------------------------+
    //| Constructor/Destructor                                           |
    //+------------------------------------------------------------------+
    CAdvancedTrendFollower();
    ~CAdvancedTrendFollower();
    
    //+------------------------------------------------------------------+
    //| Core Methods                                                     |
    //+------------------------------------------------------------------+
    bool Init();
    void Deinit();
    bool Refresh();
    
    //+------------------------------------------------------------------+
    //| Trend Analysis Methods                                           |
    //+------------------------------------------------------------------+
    bool IsBullish();
    bool IsBearish();
    double TrendStrength();
    double EntryPricePullback();
    
    //+------------------------------------------------------------------+
    //| UI Methods                                                       |
    //+------------------------------------------------------------------+
    void ShowDiagnosticPanel(const bool show);
    void UpdateDiagnosticUI();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAdvancedTrendFollower::CAdvancedTrendFollower()
{
    // Initialize handles to invalid
    m_emaFastH1Handle = INVALID_HANDLE;
    m_emaSlowH1Handle = INVALID_HANDLE;
    m_emaPullbackH1Handle = INVALID_HANDLE;
    m_macdH1Handle = INVALID_HANDLE;
    m_rsiH1Handle = INVALID_HANDLE;
    m_adxH1Handle = INVALID_HANDLE;
    m_emaFastH4Handle = INVALID_HANDLE;
    m_emaSlowH4Handle = INVALID_HANDLE;
    m_adxH4Handle = INVALID_HANDLE;
    m_emaFastD1Handle = INVALID_HANDLE;
    m_emaSlowD1Handle = INVALID_HANDLE;
    m_adxD1Handle = INVALID_HANDLE;
    
    // Initialize state
    m_isInitialized = false;
    m_showDiagnosticPanel = InpShowDiagnosticPanel;
    m_panelObjectName = "TrendFollowerPanel_" + (string)GetTickCount();
    m_panelXOffset = InpPanelXOffset;
    m_panelYOffset = InpPanelYOffset;
    
    // Set buffer arrays as series
    ArraySetAsSeries(m_emaFastH1, true);
    ArraySetAsSeries(m_emaSlowH1, true);
    ArraySetAsSeries(m_emaPullbackH1, true);
    ArraySetAsSeries(m_macdMainH1, true);
    ArraySetAsSeries(m_macdSignalH1, true);
    ArraySetAsSeries(m_rsiH1, true);
    ArraySetAsSeries(m_adxH1, true);
    ArraySetAsSeries(m_emaFastH4, true);
    ArraySetAsSeries(m_emaSlowH4, true);
    ArraySetAsSeries(m_adxH4, true);
    ArraySetAsSeries(m_emaFastD1, true);
    ArraySetAsSeries(m_emaSlowD1, true);
    ArraySetAsSeries(m_adxD1, true);
    
    if(InpLogDebugInfo)
        MCP_LogInfo("Advanced Trend Follower initialized");
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CAdvancedTrendFollower::~CAdvancedTrendFollower()
{
    Deinit();
    if(InpLogDebugInfo)
        MCP_LogInfo("Advanced Trend Follower destroyed");
}

//+------------------------------------------------------------------+
//| Initialize all indicator handles                                 |
//+------------------------------------------------------------------+
bool CAdvancedTrendFollower::Init()
{
    if(InpLogDebugInfo)
        MCP_LogInfo("Starting initialization...");
    
    // Validate input parameters
    if(!ValidateInputParameters())
    {
        MCP_LogError("Invalid input parameters");
        return false;
    }
    
    // Create indicator handles
    if(!CreateIndicatorHandles())
    {
        MCP_LogError("Failed to create indicator handles");
        ReleaseIndicatorHandles();
        return false;
    }
    
    // Create diagnostic panel if enabled
    if(m_showDiagnosticPanel)
    {
        MCP_UI_CreatePanel();
    }
    
    m_isInitialized = true;
    if(InpLogDebugInfo)
        MCP_LogInfo("Initialization completed successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Release all indicator handles                                    |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::Deinit()
{
    if(InpLogDebugInfo)
        MCP_LogInfo("Starting deinitialization...");
    
    // Release handles
    ReleaseIndicatorHandles();
    
    // Remove UI panel and all labels
    if(ObjectFind(0, m_panelObjectName) >= 0)
    {
        ObjectDelete(0, m_panelObjectName);
    }
    
    // Remove all text labels
    for(int i = 0; i < 8; i++)
    {
        string labelName = m_panelObjectName + "_Label" + (string)i;
        if(ObjectFind(0, labelName) >= 0)
        {
            ObjectDelete(0, labelName);
        }
    }
    
    ChartRedraw(0);
    
    m_isInitialized = false;
    if(InpLogDebugInfo)
        MCP_LogInfo("Deinitialization completed");
}

//+------------------------------------------------------------------+
//| Refresh all indicator values                                     |
//+------------------------------------------------------------------+
bool CAdvancedTrendFollower::Refresh()
{
    if(!m_isInitialized)
    {
        MCP_LogError("Trend follower not initialized");
        return false;
    }
    
    // Copy latest indicator values
    if(!CopyIndicatorData())
    {
        MCP_LogError("Failed to refresh indicator data");
        return false;
    }
    
    // Update diagnostic UI
    if(m_showDiagnosticPanel)
    {
        UpdateDiagnosticUI();
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if market is bullish                                      |
//+------------------------------------------------------------------+
bool CAdvancedTrendFollower::IsBullish()
{
    if(!m_isInitialized || ArraySize(m_emaFastH1) < 1)
        return false;
    
    // Fast EMA > Slow EMA on H1, H4, D1
    bool h1EmaAlignment = (m_emaFastH1[0] > m_emaSlowH1[0]);
    bool h4EmaAlignment = (m_emaFastH4[0] > m_emaSlowH4[0]);
    bool d1EmaAlignment = (m_emaFastD1[0] > m_emaSlowD1[0]);
    
    // ADX (H1) >= threshold
    bool adxCondition = (m_adxH1[0] >= InpAdxThreshold);
    
    // MACD main > signal (H1)
    bool macdCondition = (m_macdMainH1[0] > m_macdSignalH1[0]);
    
    // RSI (H1) > threshold
    bool rsiCondition = (m_rsiH1[0] > InpRsiThreshold);
    
    return (h1EmaAlignment && h4EmaAlignment && d1EmaAlignment && 
            adxCondition && macdCondition && rsiCondition);
}

//+------------------------------------------------------------------+
//| Check if market is bearish                                      |
//+------------------------------------------------------------------+
bool CAdvancedTrendFollower::IsBearish()
{
    if(!m_isInitialized || ArraySize(m_emaFastH1) < 1)
        return false;
    
    // Fast EMA < Slow EMA on H1, H4, D1
    bool h1EmaAlignment = (m_emaFastH1[0] < m_emaSlowH1[0]);
    bool h4EmaAlignment = (m_emaFastH4[0] < m_emaSlowH4[0]);
    bool d1EmaAlignment = (m_emaFastD1[0] < m_emaSlowD1[0]);
    
    // ADX (H1) >= threshold
    bool adxCondition = (m_adxH1[0] >= InpAdxThreshold);
    
    // MACD main < signal (H1)
    bool macdCondition = (m_macdMainH1[0] < m_macdSignalH1[0]);
    
    // RSI (H1) < threshold
    bool rsiCondition = (m_rsiH1[0] < InpRsiThreshold);
    
    return (h1EmaAlignment && h4EmaAlignment && d1EmaAlignment && 
            adxCondition && macdCondition && rsiCondition);
}

//+------------------------------------------------------------------+
//| Get current trend strength (ADX H1 value)                       |
//+------------------------------------------------------------------+
double CAdvancedTrendFollower::TrendStrength()
{
    if(!m_isInitialized || ArraySize(m_adxH1) < 1)
        return 0.0;
    
    return m_adxH1[0];
}

//+------------------------------------------------------------------+
//| Get entry pullback price (H1 EMA20 value)                       |
//+------------------------------------------------------------------+
double CAdvancedTrendFollower::EntryPricePullback()
{
    if(!m_isInitialized || ArraySize(m_emaPullbackH1) < 1)
        return 0.0;
    
    return m_emaPullbackH1[0];
}

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
bool CAdvancedTrendFollower::ValidateInputParameters()
{
    if(InpEmaFastPeriod <= 0 || InpEmaSlowPeriod <= 0 || InpEmaPullbackPeriod <= 0)
    {
        MCP_LogError("Invalid EMA periods");
        return false;
    }
    
    if(InpEmaFastPeriod >= InpEmaSlowPeriod)
    {
        MCP_LogError("Fast EMA period must be less than slow EMA period");
        return false;
    }
    
    if(InpMacdFastPeriod <= 0 || InpMacdSlowPeriod <= 0 || InpMacdSignalPeriod <= 0)
    {
        MCP_LogError("Invalid MACD periods");
        return false;
    }
    
    if(InpRsiPeriod <= 0 || InpAdxPeriod <= 0)
    {
        MCP_LogError("Invalid RSI or ADX periods");
        return false;
    }
    
    if(InpAdxThreshold < 0 || InpAdxThreshold > 100)
    {
        MCP_LogError("Invalid ADX threshold");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Create all indicator handles                                     |
//+------------------------------------------------------------------+
bool CAdvancedTrendFollower::CreateIndicatorHandles()
{
    // H1 Indicators
    m_emaFastH1Handle = iMA(_Symbol, PERIOD_H1, InpEmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    m_emaSlowH1Handle = iMA(_Symbol, PERIOD_H1, InpEmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    m_emaPullbackH1Handle = iMA(_Symbol, PERIOD_H1, InpEmaPullbackPeriod, 0, MODE_EMA, PRICE_CLOSE);
    m_macdH1Handle = iMACD(_Symbol, PERIOD_H1, InpMacdFastPeriod, InpMacdSlowPeriod, InpMacdSignalPeriod, PRICE_CLOSE);
    m_rsiH1Handle = iRSI(_Symbol, PERIOD_H1, InpRsiPeriod, PRICE_CLOSE);
    m_adxH1Handle = iADX(_Symbol, PERIOD_H1, InpAdxPeriod);
    
    // H4 Indicators
    m_emaFastH4Handle = iMA(_Symbol, PERIOD_H4, InpEmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    m_emaSlowH4Handle = iMA(_Symbol, PERIOD_H4, InpEmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    m_adxH4Handle = iADX(_Symbol, PERIOD_H4, InpAdxPeriod);
    
    // D1 Indicators
    m_emaFastD1Handle = iMA(_Symbol, PERIOD_D1, InpEmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    m_emaSlowD1Handle = iMA(_Symbol, PERIOD_D1, InpEmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    m_adxD1Handle = iADX(_Symbol, PERIOD_D1, InpAdxPeriod);
    
    // Check all handles
    if(m_emaFastH1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create EMA Fast H1 handle");
        return false;
    }
    if(m_emaSlowH1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create EMA Slow H1 handle");
        return false;
    }
    if(m_emaPullbackH1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create EMA Pullback H1 handle");
        return false;
    }
    if(m_macdH1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create MACD H1 handle");
        return false;
    }
    if(m_rsiH1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create RSI H1 handle");
        return false;
    }
    if(m_adxH1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create ADX H1 handle");
        return false;
    }
    if(m_emaFastH4Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create EMA Fast H4 handle");
        return false;
    }
    if(m_emaSlowH4Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create EMA Slow H4 handle");
        return false;
    }
    if(m_adxH4Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create ADX H4 handle");
        return false;
    }
    if(m_emaFastD1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create EMA Fast D1 handle");
        return false;
    }
    if(m_emaSlowD1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create EMA Slow D1 handle");
        return false;
    }
    if(m_adxD1Handle == INVALID_HANDLE)
    {
        MCP_LogError("Failed to create ADX D1 handle");
        return false;
    }
    
    if(InpLogDebugInfo)
        MCP_LogInfo("All indicator handles created successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Release all indicator handles                                    |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::ReleaseIndicatorHandles()
{
    if(m_emaFastH1Handle != INVALID_HANDLE) IndicatorRelease(m_emaFastH1Handle);
    if(m_emaSlowH1Handle != INVALID_HANDLE) IndicatorRelease(m_emaSlowH1Handle);
    if(m_emaPullbackH1Handle != INVALID_HANDLE) IndicatorRelease(m_emaPullbackH1Handle);
    if(m_macdH1Handle != INVALID_HANDLE) IndicatorRelease(m_macdH1Handle);
    if(m_rsiH1Handle != INVALID_HANDLE) IndicatorRelease(m_rsiH1Handle);
    if(m_adxH1Handle != INVALID_HANDLE) IndicatorRelease(m_adxH1Handle);
    if(m_emaFastH4Handle != INVALID_HANDLE) IndicatorRelease(m_emaFastH4Handle);
    if(m_emaSlowH4Handle != INVALID_HANDLE) IndicatorRelease(m_emaSlowH4Handle);
    if(m_adxH4Handle != INVALID_HANDLE) IndicatorRelease(m_adxH4Handle);
    if(m_emaFastD1Handle != INVALID_HANDLE) IndicatorRelease(m_emaFastD1Handle);
    if(m_emaSlowD1Handle != INVALID_HANDLE) IndicatorRelease(m_emaSlowD1Handle);
    if(m_adxD1Handle != INVALID_HANDLE) IndicatorRelease(m_adxD1Handle);
    
    if(InpLogDebugInfo)
        MCP_LogInfo("All indicator handles released");
}

//+------------------------------------------------------------------+
//| Copy indicator data to internal buffers                         |
//+------------------------------------------------------------------+
bool CAdvancedTrendFollower::CopyIndicatorData()
{
    // Copy H1 data
    if(CopyBuffer(m_emaFastH1Handle, 0, 0, 2, m_emaFastH1) <= 0)
    {
        MCP_LogError("Failed to copy EMA Fast H1 buffer");
        return false;
    }
    if(CopyBuffer(m_emaSlowH1Handle, 0, 0, 2, m_emaSlowH1) <= 0)
    {
        MCP_LogError("Failed to copy EMA Slow H1 buffer");
        return false;
    }
    if(CopyBuffer(m_emaPullbackH1Handle, 0, 0, 2, m_emaPullbackH1) <= 0)
    {
        MCP_LogError("Failed to copy EMA Pullback H1 buffer");
        return false;
    }
    if(CopyBuffer(m_macdH1Handle, MAIN_LINE, 0, 2, m_macdMainH1) <= 0)
    {
        MCP_LogError("Failed to copy MACD Main H1 buffer");
        return false;
    }
    if(CopyBuffer(m_macdH1Handle, SIGNAL_LINE, 0, 2, m_macdSignalH1) <= 0)
    {
        MCP_LogError("Failed to copy MACD Signal H1 buffer");
        return false;
    }
    if(CopyBuffer(m_rsiH1Handle, 0, 0, 2, m_rsiH1) <= 0)
    {
        MCP_LogError("Failed to copy RSI H1 buffer");
        return false;
    }
    if(CopyBuffer(m_adxH1Handle, MAIN_LINE, 0, 2, m_adxH1) <= 0)
    {
        MCP_LogError("Failed to copy ADX H1 buffer");
        return false;
    }
    
    // Copy H4 data
    if(CopyBuffer(m_emaFastH4Handle, 0, 0, 2, m_emaFastH4) <= 0)
    {
        MCP_LogError("Failed to copy EMA Fast H4 buffer");
        return false;
    }
    if(CopyBuffer(m_emaSlowH4Handle, 0, 0, 2, m_emaSlowH4) <= 0)
    {
        MCP_LogError("Failed to copy EMA Slow H4 buffer");
        return false;
    }
    if(CopyBuffer(m_adxH4Handle, MAIN_LINE, 0, 2, m_adxH4) <= 0)
    {
        MCP_LogError("Failed to copy ADX H4 buffer");
        return false;
    }
    
    // Copy D1 data
    if(CopyBuffer(m_emaFastD1Handle, 0, 0, 2, m_emaFastD1) <= 0)
    {
        MCP_LogError("Failed to copy EMA Fast D1 buffer");
        return false;
    }
    if(CopyBuffer(m_emaSlowD1Handle, 0, 0, 2, m_emaSlowD1) <= 0)
    {
        MCP_LogError("Failed to copy EMA Slow D1 buffer");
        return false;
    }
    if(CopyBuffer(m_adxD1Handle, MAIN_LINE, 0, 2, m_adxD1) <= 0)
    {
        MCP_LogError("Failed to copy ADX D1 buffer");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Show/Hide diagnostic panel                                       |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::ShowDiagnosticPanel(const bool show)
{
    m_showDiagnosticPanel = show;
    
    if(show)
    {
        MCP_UI_CreatePanel();
    }
    else
    {
        // Remove panel background
        if(ObjectFind(0, m_panelObjectName) >= 0)
        {
            ObjectDelete(0, m_panelObjectName);
        }
        
        // Remove all text labels
        for(int i = 0; i < 8; i++)
        {
            string labelName = m_panelObjectName + "_Label" + (string)i;
            if(ObjectFind(0, labelName) >= 0)
            {
                ObjectDelete(0, labelName);
            }
        }
        
        ChartRedraw(0);
    }
}

//+------------------------------------------------------------------+
//| Update diagnostic UI                                             |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::UpdateDiagnosticUI()
{
    if(!m_showDiagnosticPanel) return;
    
    string trendMode = "None";
    if(IsBullish()) trendMode = "Bullish";
    else if(IsBearish()) trendMode = "Bearish";
    
    bool h1Aligned = (ArraySize(m_emaFastH1) > 0) ? (m_emaFastH1[0] > m_emaSlowH1[0]) : false;
    bool h4Aligned = (ArraySize(m_emaFastH4) > 0) ? (m_emaFastH4[0] > m_emaSlowH4[0]) : false;
    bool d1Aligned = (ArraySize(m_emaFastD1) > 0) ? (m_emaFastD1[0] > m_emaSlowD1[0]) : false;
    
    UpdatePanelText(trendMode, TrendStrength(), h1Aligned, h4Aligned, d1Aligned);
}

//+------------------------------------------------------------------+
//| Create diagnostic panel                                          |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::MCP_UI_CreatePanel()
{
    // Remove existing panel
    if(ObjectFind(0, m_panelObjectName) >= 0)
    {
        ObjectDelete(0, m_panelObjectName);
    }
    
    // Create panel background with MASSIVE room
    ObjectCreate(0, m_panelObjectName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_XDISTANCE, m_panelXOffset);
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_YDISTANCE, m_panelYOffset);
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_XSIZE, 250);     // Even wider
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_YSIZE, 200);     // Much taller - huge spacing
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_BGCOLOR, clrDarkSlateGray);
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, m_panelObjectName, OBJPROP_HIDDEN, false);  // Make background visible
    
    MCP_UI_UpdatePanel();
}

//+------------------------------------------------------------------+
//| Update panel with current data                                   |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::MCP_UI_UpdatePanel()
{
    string trendMode = "None";
    if(IsBullish()) trendMode = "Bullish";
    else if(IsBearish()) trendMode = "Bearish";
    
    bool h1Aligned = (ArraySize(m_emaFastH1) > 0) ? (m_emaFastH1[0] > m_emaSlowH1[0]) : false;
    bool h4Aligned = (ArraySize(m_emaFastH4) > 0) ? (m_emaFastH4[0] > m_emaSlowH4[0]) : false;
    bool d1Aligned = (ArraySize(m_emaFastD1) > 0) ? (m_emaFastD1[0] > m_emaSlowD1[0]) : false;
    
    UpdatePanelText(trendMode, TrendStrength(), h1Aligned, h4Aligned, d1Aligned);
}

//+------------------------------------------------------------------+
//| Update panel text content                                        |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::UpdatePanelText(const string trendMode, const double adxValue,
                                            const bool h1Aligned, const bool h4Aligned, const bool d1Aligned)
{
    // Remove existing labels
    for(int i = 0; i < 8; i++)
    {
        string labelName = m_panelObjectName + "_Label" + (string)i;
        if(ObjectFind(0, labelName) >= 0)
        {
            ObjectDelete(0, labelName);
        }
    }
    
    // Create separate labels for each line
    string lines[8];
    lines[0] = "TREND FOLLOWER";
    lines[1] = "===============";
    lines[2] = StringFormat("Mode: %s", trendMode);
    lines[3] = StringFormat("ADX: %.1f", adxValue);
    lines[4] = "===============";
    lines[5] = StringFormat("H1 EMA: %s", h1Aligned ? "BULL" : "BEAR");
    lines[6] = StringFormat("H4 EMA: %s", h4Aligned ? "BULL" : "BEAR");
    lines[7] = StringFormat("D1 EMA: %s", d1Aligned ? "BULL" : "BEAR");
    
    bool allCreated = true;
    
    for(int i = 0; i < 8; i++)
    {
        string labelName = m_panelObjectName + "_Label" + (string)i;
        bool created = ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        
         if(created)
         {
             ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, m_panelXOffset + 15);
             ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, m_panelYOffset + 15 + (i * 22)); // HUGE spacing - 22 pixels between lines
             ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLime);
             ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);               // Slightly larger font
             ObjectSetString(0, labelName, OBJPROP_FONT, "Consolas");
             ObjectSetString(0, labelName, OBJPROP_TEXT, lines[i]);
             ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
             ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
             ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
         }
        else
        {
            MCP_LogError("Failed to create label " + (string)i + ". Error: " + (string)GetLastError());
            allCreated = false;
        }
    }
    
    if(allCreated && InpLogDebugInfo)
    {
        MCP_LogInfo("All panel labels created successfully");
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| MCP Logging Helper - Error                                       |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::MCP_LogError(const string message)
{
    Print(MCP_LOG_PREFIX + "ERROR: " + message);
}

//+------------------------------------------------------------------+
//| MCP Logging Helper - Info                                        |
//+------------------------------------------------------------------+
void CAdvancedTrendFollower::MCP_LogInfo(const string message)
{
    Print(MCP_LOG_PREFIX + "INFO: " + message);
} 