//+------------------------------------------------------------------+
//| GrandeInterfaces.mqh                                             |
//| Copyright 2024, Grande Tech                                      |
//| Standard Interfaces for Grande Trading System Components        |
//+------------------------------------------------------------------+
// PURPOSE:
//   Define standard interfaces for all system components to ensure
//   consistent behavior, testing, and interchangeability.
//
// RESPONSIBILITIES:
//   - Define standard analysis result structure
//   - Define IMarketAnalyzer interface
//   - Define ISignalGenerator interface
//   - Define IOrderManager interface
//   - Define IPositionManager interface
//   - Define IDisplayManager interface
//   - Define IDataCollector interface
//
// DEPENDENCIES:
//   - None (base infrastructure)
//
// USAGE:
//   All analyzer components should implement IMarketAnalyzer
//   All specialized components should implement their respective interfaces
//
// BENEFITS:
//   - Components are interchangeable
//   - Consistent error handling
//   - Clear testing boundaries
//   - Easy to extend system with new components
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestInterfaces.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Signal Type Enumeration                                           |
//+------------------------------------------------------------------+
enum SIGNAL_TYPE
{
    SIGNAL_NONE,           // No signal
    SIGNAL_BUY,            // Buy signal
    SIGNAL_SELL,           // Sell signal
    SIGNAL_CLOSE_BUY,      // Close buy position
    SIGNAL_CLOSE_SELL,     // Close sell position
    SIGNAL_WAIT            // Wait for better setup
};

//+------------------------------------------------------------------+
//| Analysis Result Structure                                         |
//+------------------------------------------------------------------+
struct AnalysisResult
{
    bool isValid;                   // Is this result valid?
    double confidence;              // Confidence level (0.0 - 1.0)
    SIGNAL_TYPE signal;             // Signal type
    string reasoning;               // Explanation of the analysis
    datetime timestamp;             // When was this analysis performed
    double entryPrice;              // Suggested entry price (0 if N/A)
    double stopLoss;                // Suggested stop loss (0 if N/A)
    double takeProfit;              // Suggested take profit (0 if N/A)
    string componentName;           // Name of component that generated this
    
    // Constructor
    void AnalysisResult()
    {
        isValid = false;
        confidence = 0.0;
        signal = SIGNAL_NONE;
        reasoning = "";
        timestamp = 0;
        entryPrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        componentName = "";
    }
    
    // Create invalid result
    static AnalysisResult Invalid(string reason)
    {
        AnalysisResult result;
        result.isValid = false;
        result.reasoning = reason;
        result.timestamp = TimeCurrent();
        return result;
    }
    
    // Create valid result
    static AnalysisResult Valid(SIGNAL_TYPE sig, double conf, string reason)
    {
        AnalysisResult result;
        result.isValid = true;
        result.signal = sig;
        result.confidence = conf;
        result.reasoning = reason;
        result.timestamp = TimeCurrent();
        return result;
    }
};

//+------------------------------------------------------------------+
//| Market Analyzer Interface                                         |
//+------------------------------------------------------------------+
// All market analysis components should implement this interface
interface IMarketAnalyzer
{
    // Initialize the analyzer
    bool Initialize(string symbol);
    
    // Perform analysis and return result
    AnalysisResult Analyze();
    
    // Get component name
    string GetName();
    
    // Get last confidence level
    double GetConfidence();
    
    // Check if analyzer is healthy
    bool IsHealthy();
    
    // Get component status
    string GetStatus();
    
    // Cleanup resources
    void Cleanup();
};

//+------------------------------------------------------------------+
//| Signal Generator Interface                                        |
//+------------------------------------------------------------------+
// Signal generation components should implement this interface
interface ISignalGenerator
{
    // Initialize signal generator
    bool Initialize(string symbol);
    
    // Generate trading signal based on current market conditions
    AnalysisResult GenerateSignal();
    
    // Validate signal against current market conditions
    bool ValidateSignal(const AnalysisResult &signal);
    
    // Get signal generation statistics
    string GetStatistics();
    
    // Reset signal generator state
    void Reset();
};

//+------------------------------------------------------------------+
//| Order Manager Interface                                           |
//+------------------------------------------------------------------+
// Order management components should implement this interface
interface IOrderManager
{
    // Initialize order manager
    bool Initialize(string symbol, int magicNumber);
    
    // Place market order
    ulong PlaceMarketOrder(SIGNAL_TYPE signal, double volume, double sl, double tp);
    
    // Place limit order
    ulong PlaceLimitOrder(SIGNAL_TYPE signal, double price, double volume, double sl, double tp);
    
    // Place stop order
    ulong PlaceStopOrder(SIGNAL_TYPE signal, double price, double volume, double sl, double tp);
    
    // Modify order
    bool ModifyOrder(ulong ticket, double newPrice, double newSL, double newTP);
    
    // Cancel pending order
    bool CancelOrder(ulong ticket);
    
    // Get pending orders count
    int GetPendingOrdersCount();
    
    // Check if order exists
    bool OrderExists(ulong ticket);
};

//+------------------------------------------------------------------+
//| Position Manager Interface                                        |
//+------------------------------------------------------------------+
// Position management components should implement this interface
interface IPositionManager
{
    // Initialize position manager
    bool Initialize(string symbol, int magicNumber);
    
    // Update all positions (trailing stop, breakeven, etc.)
    void UpdatePositions();
    
    // Update specific position
    bool UpdatePosition(ulong ticket);
    
    // Close position
    bool ClosePosition(ulong ticket, double volume);
    
    // Close all positions
    void CloseAllPositions();
    
    // Get open positions count
    int GetOpenPositionsCount();
    
    // Check if position exists
    bool PositionExists(ulong ticket);
    
    // Get position statistics
    string GetPositionStatistics();
};

//+------------------------------------------------------------------+
//| Display Manager Interface                                         |
//+------------------------------------------------------------------+
// Display/UI components should implement this interface
interface IDisplayManager
{
    // Initialize display manager
    bool Initialize(long chartID);
    
    // Update all display elements
    void UpdateDisplay();
    
    // Show specific panel
    void ShowPanel(string panelName);
    
    // Hide specific panel
    void HidePanel(string panelName);
    
    // Clear all display elements
    void ClearDisplay();
    
    // Update chart objects
    void UpdateChartObjects();
    
    // Check if display is active
    bool IsActive();
};

//+------------------------------------------------------------------+
//| Data Collector Interface                                          |
//+------------------------------------------------------------------+
// Data collection components should implement this interface
interface IDataCollector
{
    // Initialize data collector
    bool Initialize(string symbol);
    
    // Collect market data
    bool CollectMarketData();
    
    // Collect performance data
    bool CollectPerformanceData();
    
    // Export data to file
    bool ExportData(string filename);
    
    // Get collection statistics
    string GetStatistics();
    
    // Clear collected data
    void ClearData();
};

//+------------------------------------------------------------------+
//| Component Health Status                                           |
//+------------------------------------------------------------------+
enum COMPONENT_HEALTH
{
    HEALTH_UNKNOWN,        // Health status unknown
    HEALTH_OK,             // Component healthy
    HEALTH_WARNING,        // Component has warnings
    HEALTH_ERROR,          // Component has errors
    HEALTH_CRITICAL        // Component in critical state
};

//+------------------------------------------------------------------+
//| Component Status Structure                                        |
//+------------------------------------------------------------------+
struct ComponentStatus
{
    string componentName;
    COMPONENT_HEALTH health;
    string statusMessage;
    datetime lastUpdate;
    int errorCount;
    int warningCount;
    
    void ComponentStatus()
    {
        componentName = "";
        health = HEALTH_UNKNOWN;
        statusMessage = "";
        lastUpdate = 0;
        errorCount = 0;
        warningCount = 0;
    }
    
    static ComponentStatus OK(string name)
    {
        ComponentStatus status;
        status.componentName = name;
        status.health = HEALTH_OK;
        status.statusMessage = "Operating normally";
        status.lastUpdate = TimeCurrent();
        return status;
    }
    
    static ComponentStatus Error(string name, string message)
    {
        ComponentStatus status;
        status.componentName = name;
        status.health = HEALTH_ERROR;
        status.statusMessage = message;
        status.lastUpdate = TimeCurrent();
        status.errorCount = 1;
        return status;
    }
};

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+

// Convert signal type to string
string SignalTypeToString(SIGNAL_TYPE signal)
{
    switch(signal)
    {
        case SIGNAL_BUY:        return "BUY";
        case SIGNAL_SELL:       return "SELL";
        case SIGNAL_CLOSE_BUY:  return "CLOSE_BUY";
        case SIGNAL_CLOSE_SELL: return "CLOSE_SELL";
        case SIGNAL_WAIT:       return "WAIT";
        default:                return "NONE";
    }
}

// Convert string to signal type
SIGNAL_TYPE StringToSignalType(string signal)
{
    if(signal == "BUY") return SIGNAL_BUY;
    if(signal == "SELL") return SIGNAL_SELL;
    if(signal == "CLOSE_BUY") return SIGNAL_CLOSE_BUY;
    if(signal == "CLOSE_SELL") return SIGNAL_CLOSE_SELL;
    if(signal == "WAIT") return SIGNAL_WAIT;
    return SIGNAL_NONE;
}

// Convert health to string
string HealthToString(COMPONENT_HEALTH health)
{
    switch(health)
    {
        case HEALTH_OK:       return "OK";
        case HEALTH_WARNING:  return "WARNING";
        case HEALTH_ERROR:    return "ERROR";
        case HEALTH_CRITICAL: return "CRITICAL";
        default:              return "UNKNOWN";
    }
}

// Get health color
color GetHealthColor(COMPONENT_HEALTH health)
{
    switch(health)
    {
        case HEALTH_OK:       return clrGreen;
        case HEALTH_WARNING:  return clrYellow;
        case HEALTH_ERROR:    return clrOrange;
        case HEALTH_CRITICAL: return clrRed;
        default:              return clrGray;
    }
}

