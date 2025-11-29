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

// Include RegimeSnapshot definition for EnhancedLimitOrderRequest
#include "GrandeMarketRegimeDetector.mqh"
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
//| Profit Calculator Interface                                       |
//+------------------------------------------------------------------+
// Profit calculation components should implement this interface
interface IProfitCalculator
{
    // Initialize profit calculator
    bool Initialize(string symbol);
    
    // Calculate position profit
    double CalculatePositionProfitPips(ulong ticket);
    double CalculatePositionProfitCurrency(ulong ticket);
    
    // Calculate account-level metrics
    double CalculateAccountProfit();
    double CalculateProfitFactor(int magicNumber = -1);
    double CalculateWinRate(int magicNumber = -1);
};

//+------------------------------------------------------------------+
//| Risk Manager Interface                                            |
//+------------------------------------------------------------------+
// Risk management components should implement this interface
interface IRiskManager
{
    // Initialize risk manager
    bool Initialize(string symbol);
    
    // Position sizing
    double CalculateLotSize(double stopDistancePips, MARKET_REGIME regime);
    
    // Risk validation
    bool CheckDrawdown();
    bool CheckMaxPositions();
    bool ValidateMarginBeforeTrade(ENUM_ORDER_TYPE orderType, double lotSize, double entryPrice);
    
    // Stop loss and take profit
    double CalculateStopLoss(bool isBuy, double entryPrice, double atrValue);
    double CalculateTakeProfit(bool isBuy, double entryPrice, double stopLoss);
};

//+------------------------------------------------------------------+
//| Performance Tracker Interface                                     |
//+------------------------------------------------------------------+
// Performance tracking components should implement this interface
interface IPerformanceTracker
{
    // Initialize performance tracker
    bool Initialize(string symbol);
    
    // Record trade outcomes
    void RecordTradeOutcome(ulong ticket, string outcome, double closePrice);
    
    // Calculate performance metrics
    double CalculateWinRate(string signalType = "", string symbol = "", string regime = "");
    string GeneratePerformanceReport(int days = 30);
};

//+------------------------------------------------------------------+
//| Signal Quality Analyzer Interface                                 |
//+------------------------------------------------------------------+
// Signal quality analysis components should implement this interface
interface ISignalQualityAnalyzer
{
    // Initialize signal quality analyzer
    bool Initialize(string symbol);
    
    // Score signal quality
    double ScoreSignalQuality(string signalType, double regimeConfidence, 
                              int confluenceScore, double rsi, double adx, 
                              double sentimentConfidence);
    
    // Validate signal conditions
    bool ValidateSignalConditions(string signalType, double regimeConfidence, 
                                  int confluenceScore, double rsi);
    
    // Filter signals
    bool FilterLowQualitySignals(double qualityScore, double threshold = -1.0);
    
    // Get success rates
    double GetSignalSuccessRate(string signalType);
};

//+------------------------------------------------------------------+
//| Position Optimizer Interface                                      |
//+------------------------------------------------------------------+
// Position optimization components should implement this interface
interface IPositionOptimizer
{
    // Initialize position optimizer
    bool Initialize(string symbol);
    
    // Position management
    bool UpdateTrailingStops();
    bool UpdateBreakevenStops();
    bool ExecutePartialCloses();
    
    // Position optimization
    void ManageAllPositions();
    bool SetIntelligentSLTP(ulong ticket, bool isBuy, double entryPrice);
};

//+------------------------------------------------------------------+
//| Limit Order Fill Metrics Structure                                |
//+------------------------------------------------------------------+
// Tracks limit order fill performance for analysis and optimization
struct LimitOrderFillMetrics
{
    ulong ticket;                           // Order ticket
    datetime placedTime;                    // When order was placed
    datetime filledTime;                    // When order was filled (0 if not filled)
    double placedPrice;                     // Price at placement (limit price)
    double filledPrice;                     // Price at fill (0 if not filled)
    double slippagePips;                    // Slippage in pips
    bool wasFilled;                         // Whether order was filled
    string cancelReason;                    // Reason for cancellation (if not filled)
    double fillProbabilityAtPlacement;      // Estimated fill probability when placed
    double fillProbabilityAtCancel;         // Estimated fill probability when cancelled
    
    void LimitOrderFillMetrics()
    {
        ticket = 0;
        placedTime = 0;
        filledTime = 0;
        placedPrice = 0.0;
        filledPrice = 0.0;
        slippagePips = 0.0;
        wasFilled = false;
        cancelReason = "";
        fillProbabilityAtPlacement = 0.0;
        fillProbabilityAtCancel = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Enhanced Limit Order Request Structure                            |
//+------------------------------------------------------------------+
// Extended limit order request with full context for professional-grade validation
// Note: Requires RegimeSnapshot from GrandeMarketRegimeDetector.mqh
// Forward declaration - actual struct defined in GrandeLimitOrderManager.mqh
// This is a placeholder for the interface definition
struct EnhancedLimitOrderRequest
{
    // Existing fields from LimitOrderRequest
    bool isBuy;                             // Trade direction: true for buy, false for sell
    double lotSize;                         // Position size in lots
    double basePrice;                       // Current market price
    double stopLoss;                       // Stop loss level (relative to basePrice)
    double takeProfit;                     // Take profit level (relative to basePrice)
    string comment;                        // Order comment
    string tradeContext;                   // "TREND" or "BREAKOUT" for logging
    string logPrefix;                      // Log prefix for context-specific logging
    
    // New fields for enhanced validation
    RegimeSnapshot regimeSnapshot;          // Current regime for filtering
    double regimeConfidence;                // Regime confidence (0.0-1.0)
    double signalQualityScore;             // Signal quality score (0-100)
    double currentATR;                     // Current ATR for distance scaling
    double averageATR;                     // Average ATR for distance scaling
    datetime newsEventTime;                 // Upcoming news event (0 if none)
    int newsImpactLevel;                    // News impact level (0-3, 0=none)
    
    void EnhancedLimitOrderRequest()
    {
        isBuy = false;
        lotSize = 0.0;
        basePrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        comment = "";
        tradeContext = "";
        logPrefix = "";
        regimeConfidence = 0.0;
        signalQualityScore = 0.0;
        // Initialize RegimeSnapshot members
        regimeSnapshot.regime = REGIME_RANGING;
        regimeSnapshot.confidence = 0.0;
        regimeSnapshot.timestamp = 0;
        currentATR = 0.0;
        averageATR = 0.0;
        newsEventTime = 0;
        newsImpactLevel = 0;
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

