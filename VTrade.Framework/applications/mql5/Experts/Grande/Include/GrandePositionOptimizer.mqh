//+------------------------------------------------------------------+
//| GrandePositionOptimizer.mqh                                      |
//| Copyright 2024, Grande Tech                                      |
//| Position Optimization and Management Module                      |
//+------------------------------------------------------------------+
// PURPOSE:
//   Position optimization and management for the Grande Trading System.
//   Provides high-level interface for position management operations.
//
// RESPONSIBILITIES:
//   - Trailing stop management
//   - Breakeven stop placement
//   - Partial position closing
//   - Position scaling (pyramiding)
//   - Position consolidation logic
//
// DEPENDENCIES:
//   - GrandeRiskManager (from VSol) - For position management operations
//   - GrandeStateManager.mqh - For position state tracking
//   - GrandeEventBus.mqh - For position modification events
//
// STATE MANAGED:
//   - Position state tracking
//   - Optimization history
//
// PUBLIC INTERFACE:
//   bool Initialize(symbol, riskManager, stateManager, eventBus)
//   bool UpdateTrailingStops() - Trailing stop logic
//   bool MoveToBreakeven() - Breakeven stop placement
//   bool ClosePartialPosition() - Partial close logic
//   void ManageAllPositions() - Comprehensive position management
//   bool OptimizePositionSize() - Dynamic position sizing
//   bool ConsolidatePositions() - Merge similar positions
//
// IMPLEMENTATION NOTES:
//   - Wraps GrandeRiskManager position management functions
//   - Adds event publishing for position modifications
//   - Provides additional optimization strategies
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestPositionOptimizer.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Position optimization and management module"

#include "GrandeStateManager.mqh"
#include "GrandeEventBus.mqh"

// Forward declaration - GrandeRiskManager is in VSol folder
// Note: This is a forward declaration only - actual class is in ..\VSol\GrandeRiskManager.mqh
// The main EA includes it directly, so we can use it here
class CGrandeRiskManager;

//+------------------------------------------------------------------+
//| Grande Position Optimizer Class                                  |
//+------------------------------------------------------------------+
class CGrandePositionOptimizer
{
private:
    string m_symbol;
    bool m_isInitialized;
    CGrandeRiskManager* m_riskManager;
    CGrandeStateManager* m_stateManager;
    CGrandeEventBus* m_eventBus;
    
    // Configuration
    bool m_enableTrailingStop;
    bool m_enableBreakeven;
    bool m_enablePartialCloses;
    double m_trailingATRMultiplier;
    double m_breakevenATR;
    double m_partialCloseATR;
    double m_partialClosePercent;
    
public:
    // Constructor/Destructor
    CGrandePositionOptimizer();
    ~CGrandePositionOptimizer();
    
    // Initialization
    bool Initialize(string symbol, CGrandeRiskManager* riskManager, 
                    CGrandeStateManager* stateManager, CGrandeEventBus* eventBus);
    
    // Position Management (wrappers around GrandeRiskManager)
    bool UpdateTrailingStops();
    bool UpdateBreakevenStops();
    bool ExecutePartialCloses();
    void ManageAllPositions();
    
    // Advanced Position Optimization
    bool OptimizePositionSize(ulong ticket);
    bool ConsolidatePositions();
    
    // Configuration
    void SetTrailingStopEnabled(bool enabled) { m_enableTrailingStop = enabled; }
    void SetBreakevenEnabled(bool enabled) { m_enableBreakeven = enabled; }
    void SetPartialClosesEnabled(bool enabled) { m_enablePartialCloses = enabled; }
    void SetTrailingATRMultiplier(double multiplier) { m_trailingATRMultiplier = multiplier; }
    void SetBreakevenATR(double atr) { m_breakevenATR = atr; }
    void SetPartialCloseATR(double atr) { m_partialCloseATR = atr; }
    void SetPartialClosePercent(double percent) { m_partialClosePercent = percent; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandePositionOptimizer::CGrandePositionOptimizer()
{
    m_symbol = "";
    m_isInitialized = false;
    m_riskManager = NULL;
    m_stateManager = NULL;
    m_eventBus = NULL;
    m_enableTrailingStop = true;
    m_enableBreakeven = true;
    m_enablePartialCloses = true;
    m_trailingATRMultiplier = 0.8;
    m_breakevenATR = 1.5;
    m_partialCloseATR = 2.0;
    m_partialClosePercent = 33.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CGrandePositionOptimizer::~CGrandePositionOptimizer()
{
}

//+------------------------------------------------------------------+
//| Initialize Position Optimizer                                    |
//+------------------------------------------------------------------+
// PURPOSE:
//   Initialize the position optimizer with required dependencies.
//
// PARAMETERS:
//   symbol (string) - Trading symbol
//   riskManager (CGrandeRiskManager*) - Risk manager instance
//   stateManager (CGrandeStateManager*) - State manager instance
//   eventBus (CGrandeEventBus*) - Event bus instance
//
// RETURNS:
//   (bool) - true if initialization successful, false otherwise
//
// SIDE EFFECTS:
//   - Sets internal references to dependencies
//
// ERROR CONDITIONS:
//   - Returns false if symbol is empty
//   - Returns false if riskManager is NULL
//+------------------------------------------------------------------+
bool CGrandePositionOptimizer::Initialize(string symbol, CGrandeRiskManager* riskManager, 
                                          CGrandeStateManager* stateManager, CGrandeEventBus* eventBus)
{
    if(symbol == "")
    {
        Print("[GrandePositionOptimizer] ERROR: Invalid symbol");
        return false;
    }
    
    if(riskManager == NULL)
    {
        Print("[GrandePositionOptimizer] ERROR: Risk manager is NULL");
        return false;
    }
    
    m_symbol = symbol;
    m_riskManager = riskManager;
    m_stateManager = stateManager;
    m_eventBus = eventBus;
    m_isInitialized = true;
    
    return true;
}

//+------------------------------------------------------------------+
//| Update Trailing Stops                                             |
//+------------------------------------------------------------------+
// PURPOSE:
//   Update trailing stops for all open positions.
//
// RETURNS:
//   (bool) - true if any trailing stops were updated, false otherwise
//
// SIDE EFFECTS:
//   - Modifies position stop loss levels
//   - Publishes EVENT_POSITION_MODIFIED events
//
// NOTES:
//   - Wraps GrandeRiskManager::UpdateTrailingStops()
//   - Only updates if trailing stops are enabled
//+------------------------------------------------------------------+
bool CGrandePositionOptimizer::UpdateTrailingStops()
{
    if(!m_isInitialized || !m_enableTrailingStop || m_riskManager == NULL)
        return false;
    
    bool updated = m_riskManager.UpdateTrailingStops();
    
    if(updated && m_eventBus != NULL)
    {
        m_eventBus.PublishEvent(EVENT_POSITION_MODIFIED, "PositionOptimizer",
                               "Trailing stops updated", 0.0, 0);
    }
    
    return updated;
}

//+------------------------------------------------------------------+
//| Update Breakeven Stops                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Move stop loss to breakeven for positions that have moved in profit.
//
// RETURNS:
//   (bool) - true if any breakeven stops were set, false otherwise
//
// SIDE EFFECTS:
//   - Modifies position stop loss levels
//   - Publishes EVENT_POSITION_MODIFIED events
//
// NOTES:
//   - Wraps GrandeRiskManager::UpdateBreakevenStops()
//   - Only updates if breakeven stops are enabled
//+------------------------------------------------------------------+
bool CGrandePositionOptimizer::UpdateBreakevenStops()
{
    if(!m_isInitialized || !m_enableBreakeven || m_riskManager == NULL)
        return false;
    
    bool updated = m_riskManager.UpdateBreakevenStops();
    
    if(updated && m_eventBus != NULL)
    {
        m_eventBus.PublishEvent(EVENT_POSITION_MODIFIED, "PositionOptimizer",
                               "Breakeven stops updated", 0.0, 0);
    }
    
    return updated;
}

//+------------------------------------------------------------------+
//| Execute Partial Closes                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Execute partial position closes for positions that have reached profit targets.
//
// RETURNS:
//   (bool) - true if any partial closes were executed, false otherwise
//
// SIDE EFFECTS:
//   - Closes partial position volumes
//   - Publishes EVENT_POSITION_MODIFIED events
//
// NOTES:
//   - Wraps GrandeRiskManager::ExecutePartialCloses()
//   - Only executes if partial closes are enabled
//+------------------------------------------------------------------+
bool CGrandePositionOptimizer::ExecutePartialCloses()
{
    if(!m_isInitialized || !m_enablePartialCloses || m_riskManager == NULL)
        return false;
    
    bool executed = m_riskManager.ExecutePartialCloses();
    
    if(executed && m_eventBus != NULL)
    {
        m_eventBus.PublishEvent(EVENT_POSITION_MODIFIED, "PositionOptimizer",
                               "Partial closes executed", 0.0, 0);
    }
    
    return executed;
}

//+------------------------------------------------------------------+
//| Manage All Positions                                              |
//+------------------------------------------------------------------+
// PURPOSE:
//   Comprehensive position management - updates all position management features.
//
// SIDE EFFECTS:
//   - Updates trailing stops, breakeven stops, and partial closes
//   - Publishes events for all modifications
//
// NOTES:
//   - Wraps GrandeRiskManager::ManageAllPositions()
//   - Calls all position management functions in sequence
//+------------------------------------------------------------------+
void CGrandePositionOptimizer::ManageAllPositions()
{
    if(!m_isInitialized || m_riskManager == NULL)
        return;
    
    // Update all position management features
    if(m_enableBreakeven)
        UpdateBreakevenStops();
    
    if(m_enableTrailingStop)
        UpdateTrailingStops();
    
    if(m_enablePartialCloses)
        ExecutePartialCloses();
    
    // Also call risk manager's comprehensive management
    m_riskManager.ManageAllPositions();
}

//+------------------------------------------------------------------+
//| Optimize Position Size                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Optimize position size based on current market conditions.
//
// PARAMETERS:
//   ticket (ulong) - Position ticket number
//
// RETURNS:
//   (bool) - true if position size was optimized, false otherwise
//
// NOTES:
//   - Placeholder for future position scaling/pyramiding logic
//   - Currently returns false (not implemented)
//+------------------------------------------------------------------+
bool CGrandePositionOptimizer::OptimizePositionSize(ulong ticket)
{
    if(!m_isInitialized)
        return false;
    
    // Future implementation: Add position scaling/pyramiding logic
    // For now, this is a placeholder
    return false;
}

//+------------------------------------------------------------------+
//| Consolidate Positions                                             |
//+------------------------------------------------------------------+
// PURPOSE:
//   Consolidate similar positions (same direction, same symbol) into single position.
//
// RETURNS:
//   (bool) - true if positions were consolidated, false otherwise
//
// NOTES:
//   - Placeholder for future position consolidation logic
//   - Currently returns false (not implemented)
//+------------------------------------------------------------------+
bool CGrandePositionOptimizer::ConsolidatePositions()
{
    if(!m_isInitialized)
        return false;
    
    // Future implementation: Add position consolidation logic
    // For now, this is a placeholder
    return false;
}

//+------------------------------------------------------------------+

