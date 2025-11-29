//+------------------------------------------------------------------+
//| GrandeLimitOrderManager.mqh                                      |
//| Copyright 2024, Grande Tech                                      |
//| Centralized Limit Order Placement and Management                 |
//+------------------------------------------------------------------+
// PURPOSE:
//   Centralize all limit order placement logic to eliminate duplication,
//   improve maintainability, and enable LLM-driven strategy optimization.
//
// RESPONSIBILITIES:
//   - Place limit orders with full validation
//   - Find optimal limit order prices using confluence analysis
//   - Detect and prevent duplicate orders
//   - Manage stale order cancellation
//   - Adjust stop loss and take profit for limit prices
//   - Provide clear interface for strategy optimization
//
// DEPENDENCIES:
//   - CGrandeConfluenceDetector - For optimal price calculation
//   - CGrandeKeyLevelDetector - For key level extraction
//   - CTrade - For actual order placement
//   - GrandeConfluenceDetector.mqh - For ConfluenceZone structure
//
// STATE MANAGED:
//   - Symbol and magic number
//   - Configuration settings
//   - Dependencies (confluence detector, key level detector, trade object)
//
// PUBLIC INTERFACE:
//   bool Initialize(symbol, magicNumber, confluenceDetector, keyLevelDetector, trade, config)
//   LimitOrderResult PlaceLimitOrder(LimitOrderRequest &request)
//   double FindOptimalLimitPrice(isBuy, currentPrice, maxDistancePips)
//   bool HasSimilarOrder(isBuyLimit, levelPrice, tolerancePoints)
//   void ManageStaleOrders()
//   bool ValidateLimitOrder(request, limitPrice)
//   void AdjustStopsForLimitPrice(isBuy, basePrice, limitPrice, sl, tp)
//
// IMPLEMENTATION NOTES:
//   - Eliminates duplication between TrendTrade() and ExecuteBreakoutTrade()
//   - Provides structured error handling with error codes
//   - Centralizes all limit order logging
//   - Makes limit order strategy easy to optimize
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestLimitOrderManager.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property strict

#include "GrandeConfluenceDetector.mqh"
#include "GrandeKeyLevelDetector.mqh"
#include "GrandeDatabaseManager.mqh"
#include "GrandeInterfaces.mqh"
#include "GrandeMarketRegimeDetector.mqh"  // Phase 2: For regime-aware filtering
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Limit Order Request Structure                                    |
//+------------------------------------------------------------------+
struct LimitOrderRequest
{
    bool isBuy;                 // Trade direction: true for buy, false for sell
    double lotSize;              // Position size in lots
    double basePrice;            // Current market price
    double stopLoss;             // Stop loss level (relative to basePrice)
    double takeProfit;           // Take profit level (relative to basePrice)
    string comment;              // Order comment
    string tradeContext;         // "TREND" or "BREAKOUT" for logging
    string logPrefix;            // Log prefix for context-specific logging
    
    void LimitOrderRequest()
    {
        isBuy = false;
        lotSize = 0.0;
        basePrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        comment = "";
        tradeContext = "";
        logPrefix = "";
    }
};

//+------------------------------------------------------------------+
//| Phase 7: Enhanced Limit Order Request Structure                 |
//+------------------------------------------------------------------+
// Note: EnhancedLimitOrderRequest is defined in GrandeInterfaces.mqh
// This struct is included via the #include at the top of this file

//+------------------------------------------------------------------+
//| Limit Order Result Structure                                     |
//+------------------------------------------------------------------+
struct LimitOrderResult
{
    bool success;                // Whether order was placed successfully
    ulong ticket;                 // Order ticket (0 if failed)
    string orderType;             // "LIMIT", "MARKET", or "REJECTED"
    double limitPrice;            // Actual limit price used (or 0 if market/rejected)
    double adjustedSL;            // Adjusted stop loss
    double adjustedTP;            // Adjusted take profit
    string errorCode;             // Error code: "DUPLICATE", "TOO_FAR", "NO_CONFLUENCE", "MARGIN", etc.
    string errorMessage;          // Human-readable error message
    
    void LimitOrderResult()
    {
        success = false;
        ticket = 0;
        orderType = "REJECTED";
        limitPrice = 0.0;
        adjustedSL = 0.0;
        adjustedTP = 0.0;
        errorCode = "";
        errorMessage = "";
    }
    
    static LimitOrderResult Success(ulong orderTicket, string orderTypeStr, double limit, double sl, double tp)
    {
        LimitOrderResult result;
        result.success = true;
        result.ticket = orderTicket;
        result.orderType = orderTypeStr;
        result.limitPrice = limit;
        result.adjustedSL = sl;
        result.adjustedTP = tp;
        result.errorCode = "";
        result.errorMessage = "";
        return result;
    }
    
    static LimitOrderResult Failure(string code, string message)
    {
        LimitOrderResult result;
        result.success = false;
        result.ticket = 0;
        result.orderType = "REJECTED";
        result.limitPrice = 0.0;
        result.adjustedSL = 0.0;
        result.adjustedTP = 0.0;
        result.errorCode = code;
        result.errorMessage = message;
        return result;
    }
};

//+------------------------------------------------------------------+
//| Limit Order Manager Configuration                                |
//+------------------------------------------------------------------+
struct LimitOrderConfig
{
    bool useLimitOrders;                  // Enable/disable limit orders
    int maxLimitDistancePips;             // Maximum distance for limit order placement
    int expirationHours;                  // Limit order expiration time
    bool cancelStaleOrders;                // Enable stale order cancellation
    double staleOrderDistancePips;        // Distance to consider order stale
    int duplicateTolerancePoints;         // Tolerance for duplicate detection (in points)
    bool logConfluenceAnalysis;           // Log confluence zone analysis
    bool logDetailedInfo;                 // Log detailed information
    
    void LimitOrderConfig()
    {
        useLimitOrders = true;
        maxLimitDistancePips = 30;
        expirationHours = 4;
        cancelStaleOrders = true;
        staleOrderDistancePips = 50.0;
        duplicateTolerancePoints = 3;
        logConfluenceAnalysis = true;
        logDetailedInfo = true;
    }
};

//+------------------------------------------------------------------+
//| Limit Order Manager Class                                         |
//+------------------------------------------------------------------+
class CGrandeLimitOrderManager
{
private:
    string                  m_symbol;
    int                     m_magicNumber;
    LimitOrderConfig        m_config;
    
    // Dependencies
    CGrandeConfluenceDetector*  m_confluenceDetector;
    CGrandeKeyLevelDetector*    m_keyLevelDetector;
    CTrade*                     m_trade;
    CGrandeDatabaseManager*     m_dbManager;         // For fill tracking (optional)
    
    // Feature flags (Phase 1-7)
    bool                    m_trackFillMetrics;           // Phase 1: Enable fill tracking
    bool                    m_useRegimeFiltering;          // Phase 2: Enable regime-based filtering
    bool                    m_requireMultiTimeframeAlignment; // Phase 3: Require MTF alignment
    bool                    m_useATRScaling;              // Phase 4: Enable ATR scaling
    bool                    m_useFillProbability;         // Phase 5: Enable fill probability checks
    bool                    m_enableDynamicAdjustment;    // Phase 6: Enable dynamic price adjustment
    bool                    m_cancelOrdersBeforeNews;      // Phase 6: Cancel before news
    
    // Helper functions
    double GetPipSize();
    void PrepareKeyLevelsForConfluence(double &resistanceLevels[], double &supportLevels[]);
    void AdjustStopsForLimitPrice(bool isBuy, double basePrice, double limitPrice, double &sl, double &tp);
    bool ValidateLimitOrder(const LimitOrderRequest &request, double limitPrice);
    datetime CalculateExpiration();
    datetime CalculateExpiration(datetime newsEventTime, double currentATR);
    
public:
    // Constructor/Destructor
    CGrandeLimitOrderManager();
    ~CGrandeLimitOrderManager();
    
    // Initialization
    bool Initialize(string symbol, int magicNumber, 
                    CGrandeConfluenceDetector* confluenceDetector,
                    CGrandeKeyLevelDetector* keyLevelDetector,
                    CTrade* trade,
                    const LimitOrderConfig &config,
                    CGrandeDatabaseManager* dbManager = NULL);  // Optional for tracking
    
    // Fill tracking methods (Phase 1: Data Collection)
    void LogLimitOrderPlacement(const LimitOrderRequest &request, const LimitOrderResult &result,
                                double regimeConfidence = 0.0, double signalQualityScore = 0.0,
                                double confluenceScore = 0.0, double fillProbability = 0.0,
                                double atrAtPlacement = 0.0, double averageATR = 0.0);
    void LogLimitOrderFill(ulong ticket, double fillPrice);
    void LogLimitOrderCancel(ulong ticket, string cancelReason);
    
    // Main placement method
    LimitOrderResult PlaceLimitOrder(const LimitOrderRequest &request);
    // Phase 7: Enhanced placement method with full context
    LimitOrderResult PlaceLimitOrder(const EnhancedLimitOrderRequest &request);
    
    // Price calculation
    double FindOptimalLimitPrice(bool isBuy, double currentPrice, int maxDistancePips);
    // Phase 2: Overload with regime filtering
    double FindOptimalLimitPrice(bool isBuy, double currentPrice, int maxDistancePips,
                                 RegimeSnapshot &regime);
    // Phase 4: Overload with ATR scaling
    double FindOptimalLimitPrice(bool isBuy, double currentPrice, int maxDistancePips,
                                 double currentATR, double averageATR);
    
    // Phase 4: ATR-based distance scaling
    double CalculateATRScaledMaxDistance(double baseMaxDistancePips, double currentATR, double averageATR);
    
    // Phase 5: Fill probability estimation
    double EstimateFillProbability(double limitPrice, bool isBuy, double currentPrice,
                                  RegimeSnapshot &regime, double regimeConfidence,
                                  double confluenceScore, double signalQualityScore);
    
    // Phase 5: Risk aggregation
    double CalculatePendingOrderExposure();
    bool ValidatePendingOrderExposure(double newOrderLotSize, double newOrderPrice, double newOrderSL);
    
    // Phase 5: Order slot management
    int GetPendingOrderCount();
    bool CanPlaceNewOrder();
    void CancelLowestPriorityOrder();  // Placeholder for future implementation
    
    // Phase 6: Dynamic adjustment
    void AdjustLimitOrderPrice(ulong ticket);
    
    // Phase 6: News event checking
    bool HasUpcomingHighImpactNews(datetime newsEventTime, int newsCancelMinutesBefore);
    void CancelOrdersBeforeNews(datetime newsEventTime, int newsCancelMinutesBefore);
    
    // Duplicate detection
    bool HasSimilarOrder(bool isBuyLimit, double levelPrice, int tolerancePoints = -1);
    
    // Stale order management
    void ManageStaleOrders();
    // Phase 4: Overload with ATR scaling
    void ManageStaleOrders(double currentATR, double averageATR);
    
    // Configuration
    void SetConfig(const LimitOrderConfig &config) { m_config = config; }
    LimitOrderConfig GetConfig() const { return m_config; }
    
    // Feature flags (Phase 1-7)
    void SetFeatureFlags(bool trackFillMetrics, bool useRegimeFiltering, 
                         bool requireMultiTimeframeAlignment, bool useATRScaling,
                         bool useFillProbability, bool enableDynamicAdjustment,
                         bool cancelOrdersBeforeNews);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandeLimitOrderManager::CGrandeLimitOrderManager()
{
    m_symbol = "";
    m_magicNumber = 0;
    m_confluenceDetector = NULL;
    m_keyLevelDetector = NULL;
    m_trade = NULL;
    m_dbManager = NULL;
    
    // Initialize feature flags with defaults (matching plan defaults)
    m_trackFillMetrics = true;              // Phase 1: Enabled by default
    m_useRegimeFiltering = false;           // Phase 2: Disabled initially
    m_requireMultiTimeframeAlignment = false; // Phase 3: Disabled initially
    m_useATRScaling = true;                 // Phase 4: Enabled by default
    m_useFillProbability = false;          // Phase 5: Disabled initially
    m_enableDynamicAdjustment = false;      // Phase 6: Disabled (opt-in)
    m_cancelOrdersBeforeNews = true;        // Phase 6: Enabled by default
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CGrandeLimitOrderManager::~CGrandeLimitOrderManager()
{
    // Dependencies are managed externally, no cleanup needed
}

//+------------------------------------------------------------------+
//| Initialize manager                                                |
//+------------------------------------------------------------------+
bool CGrandeLimitOrderManager::Initialize(string symbol, int magicNumber,
                                          CGrandeConfluenceDetector* confluenceDetector,
                                          CGrandeKeyLevelDetector* keyLevelDetector,
                                          CTrade* trade,
                                          const LimitOrderConfig &config,
                                          CGrandeDatabaseManager* dbManager)
{
    if(symbol == "" || magicNumber <= 0)
        return false;
    
    if(confluenceDetector == NULL || keyLevelDetector == NULL || trade == NULL)
        return false;
    
    m_symbol = symbol;
    m_magicNumber = magicNumber;
    m_config = config;
    m_confluenceDetector = confluenceDetector;
    m_keyLevelDetector = keyLevelDetector;
    m_trade = trade;
    m_dbManager = dbManager;  // Optional - can be NULL
    
    return true;
}

//+------------------------------------------------------------------+
//| Get pip size                                                      |
//+------------------------------------------------------------------+
double CGrandeLimitOrderManager::GetPipSize()
{
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    if(digits >= 5)
        return SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10.0;
    if(digits == 3)
        return SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10.0;
    double ts = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    return (ts > 0 ? ts : SymbolInfoDouble(m_symbol, SYMBOL_POINT));
}

//+------------------------------------------------------------------+
//| Prepare key levels for confluence analysis                        |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::PrepareKeyLevelsForConfluence(double &resistanceLevels[], 
                                                              double &supportLevels[])
{
    ArrayResize(resistanceLevels, 0);
    ArrayResize(supportLevels, 0);
    
    if(m_keyLevelDetector == NULL)
        return;
    
    int resCount = 0;
    int supCount = 0;
    
    int levelCount = m_keyLevelDetector.GetKeyLevelCount();
    for(int i = 0; i < levelCount; i++)
    {
        SKeyLevel level;
        if(m_keyLevelDetector.GetKeyLevel(i, level))
        {
            if(level.isResistance)
            {
                ArrayResize(resistanceLevels, resCount + 1);
                resistanceLevels[resCount++] = level.price;
            }
            else
            {
                ArrayResize(supportLevels, supCount + 1);
                supportLevels[supCount++] = level.price;
            }
        }
    }
    
    // Add key levels to confluence detector
    if(m_confluenceDetector != NULL)
        m_confluenceDetector.AddKeyLevelsToAnalysis(resistanceLevels, supportLevels);
}

//+------------------------------------------------------------------+
//| Find optimal limit order price using confluence                   |
//+------------------------------------------------------------------+
double CGrandeLimitOrderManager::FindOptimalLimitPrice(bool isBuy, double currentPrice, int maxDistancePips)
{
    if(m_confluenceDetector == NULL)
        return 0;
    
    // Prepare key levels
    double resistanceLevels[];
    double supportLevels[];
    PrepareKeyLevelsForConfluence(resistanceLevels, supportLevels);
    
    // Find best limit order price
    return m_confluenceDetector.GetBestLimitOrderPrice(isBuy, currentPrice, maxDistancePips);
}

//+------------------------------------------------------------------+
//| Phase 2: Find optimal limit order price with regime filtering    |
//+------------------------------------------------------------------+
double CGrandeLimitOrderManager::FindOptimalLimitPrice(bool isBuy, double currentPrice, int maxDistancePips,
                                                       RegimeSnapshot &regime)
{
    if(m_confluenceDetector == NULL)
        return 0;
    
    // Prepare key levels
    double resistanceLevels[];
    double supportLevels[];
    PrepareKeyLevelsForConfluence(resistanceLevels, supportLevels);
    
    // Find confluence zones with regime filtering
    ConfluenceZone zones[];
    m_confluenceDetector.FindConfluenceZones(isBuy, currentPrice, maxDistancePips, zones, regime);
    
    // Return best zone price
    if(ArraySize(zones) > 0)
        return zones[0].price;
    
    return 0;
}

//+------------------------------------------------------------------+
//| Phase 4: Find optimal limit order price with ATR scaling        |
//+------------------------------------------------------------------+
double CGrandeLimitOrderManager::FindOptimalLimitPrice(bool isBuy, double currentPrice, int maxDistancePips,
                                                       double currentATR, double averageATR)
{
    if(m_confluenceDetector == NULL)
        return 0;
    
    // Apply ATR scaling
    double scaledMaxDistance = CalculateATRScaledMaxDistance(maxDistancePips, currentATR, averageATR);
    
    // Prepare key levels
    double resistanceLevels[];
    double supportLevels[];
    PrepareKeyLevelsForConfluence(resistanceLevels, supportLevels);
    
    // Use scaled distance for confluence analysis
    return m_confluenceDetector.GetBestLimitOrderPrice(isBuy, currentPrice, (int)scaledMaxDistance);
}

//+------------------------------------------------------------------+
//| Phase 4: Calculate ATR-scaled maximum distance                  |
//+------------------------------------------------------------------+
double CGrandeLimitOrderManager::CalculateATRScaledMaxDistance(double baseMaxDistancePips, double currentATR, double averageATR)
{
    // Phase 4: Only apply ATR scaling if feature flag enabled
    if(!m_useATRScaling)
        return baseMaxDistancePips;
    
    if(averageATR <= 0 || currentATR <= 0)
        return baseMaxDistancePips;
    
    double atrRatio = currentATR / averageATR;
    double scaledDistance = baseMaxDistancePips * atrRatio;
    
    // Clamp to reasonable bounds (0.5x to 2.0x)
    scaledDistance = MathMax(baseMaxDistancePips * 0.5, MathMin(scaledDistance, baseMaxDistancePips * 2.0));
    
    return scaledDistance;
}

//+------------------------------------------------------------------+
//| Phase 5: Estimate fill probability for limit order               |
//+------------------------------------------------------------------+
double CGrandeLimitOrderManager::EstimateFillProbability(double limitPrice, bool isBuy, double currentPrice,
                                                         RegimeSnapshot &regime, double regimeConfidence,
                                                         double confluenceScore, double signalQualityScore)
{
    double baseProbability = 0.5; // 50% baseline
    
    // Regime factor
    double regimeFactor = 1.0;
    if(regime.regime == REGIME_TREND_BULL && isBuy && limitPrice < currentPrice)
        regimeFactor = 1.2 * regimeConfidence;
    else if(regime.regime == REGIME_TREND_BEAR && !isBuy && limitPrice > currentPrice)
        regimeFactor = 1.2 * regimeConfidence;
    else if(regime.regime == REGIME_RANGING)
        regimeFactor = 0.9 * regimeConfidence;
    else
        regimeFactor = 0.6; // Low probability if regime doesn't support
    
    // Confluence factor
    double confluenceFactor = MathMin(1.0, confluenceScore / 10.0);
    
    // Signal quality factor
    double qualityFactor = signalQualityScore / 100.0;
    
    // Distance factor (closer = higher probability)
    double pipSize = GetPipSize();
    double distancePips = MathAbs(limitPrice - currentPrice) / pipSize;
    double maxDistancePips = m_config.maxLimitDistancePips;
    double distanceFactor = 1.0 - (distancePips / (maxDistancePips * 2.0)); // Linear decay
    distanceFactor = MathMax(0.3, distanceFactor); // Minimum 30%
    
    double fillProbability = baseProbability * regimeFactor * confluenceFactor * qualityFactor * distanceFactor;
    
    // Clamp to 0.0 - 1.0
    return MathMax(0.0, MathMin(1.0, fillProbability));
}

//+------------------------------------------------------------------+
//| Phase 5: Calculate total pending order exposure                 |
//+------------------------------------------------------------------+
double CGrandeLimitOrderManager::CalculatePendingOrderExposure()
{
    double totalExposure = 0.0;
    int total = OrdersTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
        
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
            continue;
        
        double lotSize = OrderGetDouble(ORDER_VOLUME_CURRENT);
        double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
        double sl = OrderGetDouble(ORDER_SL);
        
        // Calculate risk per order
        double riskPerOrder = 0.0;
        if(sl > 0)
        {
            double pipSize = GetPipSize();
            double riskPips = MathAbs(orderPrice - sl) / pipSize;
            double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
            if(tickSize > 0)
                riskPerOrder = (riskPips * pipSize / tickSize) * tickValue * lotSize;
        }
        else
        {
            // If no SL, estimate based on lot size (conservative)
            double contractSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
            riskPerOrder = lotSize * contractSize * tickValue * 0.01; // 1% estimate
        }
        
        totalExposure += riskPerOrder;
    }
    
    return totalExposure;
}

//+------------------------------------------------------------------+
//| Phase 5: Validate pending order exposure limit                   |
//+------------------------------------------------------------------+
bool CGrandeLimitOrderManager::ValidatePendingOrderExposure(double newOrderLotSize, double newOrderPrice, double newOrderSL)
{
    // Calculate current pending exposure
    double currentExposure = CalculatePendingOrderExposure();
    
    // Calculate new order exposure
    double newOrderExposure = 0.0;
    if(newOrderSL > 0)
    {
        double pipSize = GetPipSize();
        double riskPips = MathAbs(newOrderPrice - newOrderSL) / pipSize;
        double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
        if(tickSize > 0)
            newOrderExposure = (riskPips * pipSize / tickSize) * tickValue * newOrderLotSize;
    }
    else
    {
        // Estimate if no SL
        double contractSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
        newOrderExposure = newOrderLotSize * contractSize * tickValue * 0.01; // 1% estimate
    }
    
    // Get current open positions exposure (approximate from account equity)
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double positionsExposure = accountEquity * 0.02; // Estimate 2% of equity in positions
    
    // Note: maxPendingOrderExposureMultiplier will be in EnhancedLimitOrderConfig
    // For now, use default of 2.0x
    double maxPendingExposure = positionsExposure * 2.0;
    
    if((currentExposure + newOrderExposure) > maxPendingExposure)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if similar pending limit order already exists                |
//+------------------------------------------------------------------+
bool CGrandeLimitOrderManager::HasSimilarOrder(bool isBuyLimit, double levelPrice, int tolerancePoints = -1)
{
    if(tolerancePoints < 0)
        tolerancePoints = m_config.duplicateTolerancePoints;
    
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double tol = MathMax(1, tolerancePoints) * point;
    int total = OrdersTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket))
            continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        
        long type = OrderGetInteger(ORDER_TYPE);
        if(isBuyLimit && type != ORDER_TYPE_BUY_LIMIT) continue;
        if(!isBuyLimit && type != ORDER_TYPE_SELL_LIMIT) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
        
        double price = OrderGetDouble(ORDER_PRICE_OPEN);
        if(MathAbs(price - levelPrice) <= tol)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Validate limit order before placement                             |
//+------------------------------------------------------------------+
bool CGrandeLimitOrderManager::ValidateLimitOrder(const LimitOrderRequest &request, double limitPrice)
{
    if(limitPrice <= 0)
        return false;
    
    double pipSize = GetPipSize();
    double distance = MathAbs(limitPrice - request.basePrice) / pipSize;
    
    // Check distance
    if(distance > m_config.maxLimitDistancePips)
        return false;
    
    // Check duplicate
    if(HasSimilarOrder(request.isBuy, limitPrice))
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Adjust stop loss and take profit for limit price                  |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::AdjustStopsForLimitPrice(bool isBuy, double basePrice, 
                                                         double limitPrice, double &sl, double &tp)
{
    // Adjust SL/TP based on limit price (not current market price)
    if(isBuy)
    {
        sl = limitPrice - MathAbs(basePrice - sl);
        tp = limitPrice + MathAbs(tp - basePrice);
    }
    else
    {
        sl = limitPrice + MathAbs(basePrice - sl);
        tp = limitPrice - MathAbs(tp - basePrice);
    }
}

//+------------------------------------------------------------------+
//| Calculate expiration time                                         |
//+------------------------------------------------------------------+
datetime CGrandeLimitOrderManager::CalculateExpiration()
{
    return CalculateExpiration(0, 0.0); // Call overloaded version
}

//+------------------------------------------------------------------+
//| Phase 6: Calculate expiration with volatility and news adjustment |
//+------------------------------------------------------------------+
datetime CGrandeLimitOrderManager::CalculateExpiration(datetime newsEventTime, double currentATR)
{
    datetime baseExpiration = TimeCurrent() + (m_config.expirationHours * 3600);
    
    // Adjust for upcoming news events
    if(newsEventTime > 0)
    {
        // Expire before news if news is within expiration window
        int newsCancelMinutesBefore = 30; // Default, will be in EnhancedLimitOrderConfig
        datetime newsCancelTime = newsEventTime - (newsCancelMinutesBefore * 60);
        if(newsCancelTime < baseExpiration && newsCancelTime > TimeCurrent())
        {
            return newsCancelTime;
        }
    }
    
    // Adjust for volatility (high vol = shorter expiration, low vol = longer)
    // This is a placeholder - actual implementation would use ATR ratio
    // For now, return base expiration
    
    return baseExpiration;
}

//+------------------------------------------------------------------+
//| Place limit order with full validation                            |
//+------------------------------------------------------------------+
LimitOrderResult CGrandeLimitOrderManager::PlaceLimitOrder(const LimitOrderRequest &request)
{
    string logPrefix = request.logPrefix != "" ? request.logPrefix : "[LIMIT-ORDER]";
    
    // Check if limit orders are enabled
    if(!m_config.useLimitOrders || m_confluenceDetector == NULL)
    {
        return LimitOrderResult::Failure("LIMIT_ORDERS_DISABLED", 
                                        "Limit orders are disabled or confluence detector unavailable");
    }
    
    // Find optimal limit order price
    double limitPrice = FindOptimalLimitPrice(request.isBuy, request.basePrice, m_config.maxLimitDistancePips);
    
    // Validate limit order
    if(!ValidateLimitOrder(request, limitPrice))
    {
        if(limitPrice <= 0)
        {
            if(m_config.logConfluenceAnalysis)
                Print(logPrefix + " No valid confluence zone found - skipping trade (limit orders required)");
            return LimitOrderResult::Failure("NO_CONFLUENCE", 
                                            "No valid confluence zone for limit order");
        }
        
        double pipSize = GetPipSize();
        double distance = MathAbs(limitPrice - request.basePrice) / pipSize;
        
        if(distance > m_config.maxLimitDistancePips)
        {
            return LimitOrderResult::Failure("TOO_FAR", 
                                            StringFormat("Limit price %.5f is %.1f pips away (max: %d)", 
                                                        limitPrice, distance, m_config.maxLimitDistancePips));
        }
        
        if(HasSimilarOrder(request.isBuy, limitPrice))
        {
            if(m_config.logDetailedInfo)
                Print(logPrefix + " Skip: similar pending limit order already exists near ", 
                      DoubleToString(limitPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)));
            return LimitOrderResult::Failure("DUPLICATE", 
                                            "Similar pending limit order already exists");
        }
    }
    
    // Adjust SL/TP for limit price
    double adjustedSL = request.stopLoss;
    double adjustedTP = request.takeProfit;
    AdjustStopsForLimitPrice(request.isBuy, request.basePrice, limitPrice, adjustedSL, adjustedTP);
    
    // Normalize stops to broker requirements
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    int stopLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistance = (stopLevel > 0 ? stopLevel : 0) * point;
    
    // Correct side sanity
    if(request.isBuy)
    {
        if(adjustedSL >= limitPrice) adjustedSL = limitPrice - minDistance;
        if(adjustedTP <= limitPrice) adjustedTP = limitPrice + minDistance;
    }
    else
    {
        if(adjustedSL <= limitPrice) adjustedSL = limitPrice + minDistance;
        if(adjustedTP >= limitPrice) adjustedTP = limitPrice - minDistance;
    }
    
    // Enforce minimum distances
    if(minDistance > 0)
    {
        if(request.isBuy)
        {
            if((limitPrice - adjustedSL) < minDistance) adjustedSL = limitPrice - minDistance;
            if((adjustedTP - limitPrice) < minDistance) adjustedTP = limitPrice + minDistance;
        }
        else
        {
            if((adjustedSL - limitPrice) < minDistance) adjustedSL = limitPrice + minDistance;
            if((limitPrice - adjustedTP) < minDistance) adjustedTP = limitPrice - minDistance;
        }
    }
    
    adjustedSL = NormalizeDouble(adjustedSL, digits);
    adjustedTP = NormalizeDouble(adjustedTP, digits);
    
    // Calculate expiration
    datetime expiration = CalculateExpiration();
    
    // Log confluence zone details if enabled
    if(m_config.logConfluenceAnalysis)
    {
        ConfluenceZone zone = m_confluenceDetector.GetBestConfluenceZone(request.isBuy, request.basePrice, 
                                                                         m_config.maxLimitDistancePips);
        Print(logPrefix + " LIMIT ORDER CONFLUENCE ZONE:");
        Print(logPrefix + "   Price: ", DoubleToString(limitPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)));
        Print(logPrefix + "   Score: ", zone.score);
        Print(logPrefix + "   Factors: ", zone.factors);
        Print(logPrefix + "   Distance: ", DoubleToString(zone.distanceFromPrice, 1), " pips");
        Print(logPrefix + "   Expiration: ", TimeToString(expiration));
    }
    
    // Place limit order
    bool tradeResult = false;
    
    if(request.isBuy)
    {
        tradeResult = m_trade.BuyLimit(NormalizeDouble(request.lotSize, 2), 
                                       NormalizeDouble(limitPrice, digits), 
                                       m_symbol, 
                                       NormalizeDouble(adjustedSL, digits), 
                                       NormalizeDouble(adjustedTP, digits), 
                                       ORDER_TIME_SPECIFIED, 
                                       expiration, 
                                       request.comment);
    }
    else
    {
        tradeResult = m_trade.SellLimit(NormalizeDouble(request.lotSize, 2), 
                                        NormalizeDouble(limitPrice, digits), 
                                        m_symbol, 
                                        NormalizeDouble(adjustedSL, digits), 
                                        NormalizeDouble(adjustedTP, digits), 
                                        ORDER_TIME_SPECIFIED, 
                                        expiration, 
                                        request.comment);
    }
    
    if(tradeResult)
    {
        ulong orderTicket = m_trade.ResultOrder();
        Print(StringFormat(logPrefix + " LIMIT ORDER PLACED OK ticket=%I64u", orderTicket));
        
        LimitOrderResult result = LimitOrderResult::Success(orderTicket, "LIMIT", limitPrice, adjustedSL, adjustedTP);
        
        // Phase 1: Log placement for tracking (non-breaking, only if tracking enabled)
        // Note: regimeConfidence, signalQualityScore, confluenceScore, fillProbability will be added in later phases
        // For now, pass default values (0.0) - tracking will work but metrics will be incomplete until Phase 2+
        LogLimitOrderPlacement(request, result, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        
        return result;
    }
    else
    {
        string errorMsg = StringFormat("retcode=%d desc=%s", 
                                      m_trade.ResultRetcode(), 
                                      m_trade.ResultRetcodeDescription());
        Print(StringFormat(logPrefix + " LIMIT ORDER FAILED %s", errorMsg));
        return LimitOrderResult::Failure("ORDER_PLACEMENT_FAILED", errorMsg);
    }
}

//+------------------------------------------------------------------+
//| Phase 7: Place limit order with enhanced validation              |
//+------------------------------------------------------------------+
LimitOrderResult CGrandeLimitOrderManager::PlaceLimitOrder(const EnhancedLimitOrderRequest &request)
{
    // Extract basic fields from enhanced request
    LimitOrderRequest basicRequest;
    basicRequest.isBuy = request.isBuy;
    basicRequest.lotSize = request.lotSize;
    basicRequest.basePrice = request.basePrice;
    basicRequest.stopLoss = request.stopLoss;
    basicRequest.takeProfit = request.takeProfit;
    basicRequest.comment = request.comment;
    basicRequest.tradeContext = request.tradeContext;
    basicRequest.logPrefix = request.logPrefix;
    
    // Note: minRegimeConfidence, minSignalQualityScore, etc. will be in EnhancedLimitOrderConfig
    // For now, use default thresholds
    double minRegimeConfidence = 0.65;
    double minSignalQualityScore = 75.0;
    int newsCancelMinutesBefore = 30;
    
    // Phase 2: Validate regime confidence (if regime filtering enabled)
    if(m_useRegimeFiltering && request.regimeConfidence < minRegimeConfidence)
    {
        return LimitOrderResult::Failure("LOW_REGIME_CONFIDENCE",
            StringFormat("Regime confidence %.2f below minimum %.2f",
            request.regimeConfidence, minRegimeConfidence));
    }
    
    // Validate signal quality (always check, but only reject if filtering enabled)
    if(request.signalQualityScore < minSignalQualityScore)
    {
        return LimitOrderResult::Failure("LOW_SIGNAL_QUALITY",
            StringFormat("Signal quality %.1f below minimum %.1f",
            request.signalQualityScore, minSignalQualityScore));
    }
    
    // Check pending order exposure
    if(!ValidatePendingOrderExposure(request.lotSize, request.basePrice, request.stopLoss))
    {
        return LimitOrderResult::Failure("EXCEEDS_PENDING_EXPOSURE",
            "Pending order exposure limit exceeded");
    }
    
    // Phase 6: Check for upcoming news events (if news cancellation enabled)
    if(m_cancelOrdersBeforeNews && request.newsEventTime > 0)
    {
        datetime timeToNews = request.newsEventTime - TimeCurrent();
        if(timeToNews > 0 && timeToNews < (newsCancelMinutesBefore * 60))
        {
            return LimitOrderResult::Failure("NEWS_EVENT_NEAR",
                "High-impact news event too close");
        }
    }
    
    // Check order slot availability
    if(!CanPlaceNewOrder())
    {
        return LimitOrderResult::Failure("MAX_ORDERS_REACHED",
            "Maximum pending orders limit reached");
    }
    
    // Find optimal limit price with regime filtering and ATR scaling
    double limitPrice = 0.0;
    // Phase 4: Use ATR scaling if enabled and ATR values available
    if(m_useATRScaling && request.currentATR > 0 && request.averageATR > 0)
    {
        // Use ATR-scaled version
        limitPrice = FindOptimalLimitPrice(request.isBuy, request.basePrice, 
                                          m_config.maxLimitDistancePips,
                                          request.currentATR, request.averageATR);
    }
    // Phase 2: Use regime-filtered version if regime filtering enabled
    else if(m_useRegimeFiltering && request.regimeSnapshot.timestamp > 0)
    {
        RegimeSnapshot regime = request.regimeSnapshot; // Create local copy for reference
        limitPrice = FindOptimalLimitPrice(request.isBuy, request.basePrice, 
                                          m_config.maxLimitDistancePips,
                                          regime);
    }
    else
    {
        // Fallback to basic version
        limitPrice = FindOptimalLimitPrice(request.isBuy, request.basePrice, 
                                          m_config.maxLimitDistancePips);
    }
    
    if(limitPrice <= 0)
    {
        return LimitOrderResult::Failure("NO_CONFLUENCE",
            "No valid confluence zone for limit order");
    }
    
    // Phase 5: Estimate fill probability (if enabled)
    double fillProbability = 0.0;
    if(m_useFillProbability)
    {
        RegimeSnapshot regime = request.regimeSnapshot; // Create local copy for reference
        fillProbability = EstimateFillProbability(limitPrice, request.isBuy, request.basePrice,
                                                  regime, request.regimeConfidence,
                                                  0.0, request.signalQualityScore); // Confluence score not available here
        
        // Note: minFillProbability will be in EnhancedLimitOrderConfig
        double minFillProbability = 0.4;
        if(fillProbability < minFillProbability)
        {
            return LimitOrderResult::Failure("LOW_FILL_PROBABILITY",
                StringFormat("Fill probability %.2f below minimum %.2f",
                fillProbability, minFillProbability));
        }
    }
    
    // Continue with existing placement logic using basic request
    LimitOrderResult result = PlaceLimitOrder(basicRequest);
    
    // Phase 1: If successful, log with enhanced metrics (if tracking enabled)
    if(result.success && m_trackFillMetrics)
    {
        // Get confluence score (would need to query confluence detector)
        double confluenceScore = 0.0; // Placeholder
        
        LogLimitOrderPlacement(basicRequest, result, request.regimeConfidence, 
                              request.signalQualityScore, confluenceScore, fillProbability,
                              request.currentATR, request.averageATR);
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Manage stale limit orders                                         |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::ManageStaleOrders()
{
    // Call overloaded version without ATR (backward compatibility)
    ManageStaleOrders(0.0, 0.0);
}

//+------------------------------------------------------------------+
//| Phase 4: Manage stale limit orders with ATR scaling              |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::ManageStaleOrders(double currentATR, double averageATR)
{
    if(!m_config.cancelStaleOrders)
        return;
    
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double pipSize = GetPipSize();
    
    // Phase 4: Use ATR-scaled stale distance if feature flag enabled and ATR available
    double maxStaleDistance = m_config.staleOrderDistancePips;
    if(m_useATRScaling && averageATR > 0 && currentATR > 0)
    {
        double atrRatio = currentATR / averageATR;
        maxStaleDistance = m_config.staleOrderDistancePips * atrRatio;
        // Clamp to reasonable bounds (0.5x to 2.0x)
        maxStaleDistance = MathMax(m_config.staleOrderDistancePips * 0.5, 
                                   MathMin(maxStaleDistance, m_config.staleOrderDistancePips * 2.0));
    }
    
    double maxStaleDistancePoints = maxStaleDistance * pipSize;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        
        // Check if order is ours
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if(OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
        
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        
        // Only manage limit orders (not stop orders)
        if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
            continue;
        
        double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
        double distance = MathAbs(currentPrice - orderPrice) / pipSize;
        
        bool shouldCancel = false;
        string cancelReason = "";
        
        // Check if order has moved too far from current price
        if(distance > m_config.staleOrderDistancePips)
        {
            shouldCancel = true;
            cancelReason = StringFormat("Price moved %.1f pips away (max: %.1f)", 
                                       distance, m_config.staleOrderDistancePips);
        }
        
        // Check if order has expired (if not already handled by broker)
        datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
        if(expiration > 0 && TimeCurrent() >= expiration)
        {
            shouldCancel = true;
            cancelReason = "Order expired";
        }
        
        // Cancel stale orders
        if(shouldCancel)
        {
            if(m_trade.OrderDelete(ticket))
            {
                Print(StringFormat("[LIMIT-ORDER] Cancelled limit order #%I64u: %s", ticket, cancelReason));
                
                // Phase 1: Log cancellation for tracking
                LogLimitOrderCancel(ticket, cancelReason);
            }
            else
            {
                Print(StringFormat("[LIMIT-ORDER] Failed to cancel order #%I64u: %s (error: %d)", 
                     ticket, cancelReason, GetLastError()));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Log limit order placement for tracking                            |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::LogLimitOrderPlacement(const LimitOrderRequest &request, const LimitOrderResult &result,
                                                      double regimeConfidence, double signalQualityScore,
                                                      double confluenceScore, double fillProbability,
                                                      double atrAtPlacement, double averageATR)
{
    // Only track if database manager is available and tracking is enabled
    // Note: For Phase 1, we check if m_dbManager is set, but actual tracking config
    // will be added in EnhancedLimitOrderConfig in later phases
    if(m_dbManager == NULL)
        return;
    
    if(!result.success || result.ticket == 0)
        return;
    
    // Calculate distance in pips
    double pipSize = GetPipSize();
    double distancePips = MathAbs(result.limitPrice - request.basePrice) / pipSize;
    
    // Get order type string
    string orderType = request.isBuy ? "BUY" : "SELL";
    
    // Insert into database
    // Note: regimeAtPlacement will be added in Phase 2 when we have regime context
    m_dbManager.InsertLimitOrder(
        m_symbol,
        result.ticket,
        TimeCurrent(),
        request.basePrice,
        result.limitPrice,
        result.adjustedSL,
        result.adjustedTP,
        request.lotSize,
        orderType,
        "",  // regimeAtPlacement - will be populated in Phase 2
        regimeConfidence,
        signalQualityScore,
        confluenceScore,
        fillProbability,
        atrAtPlacement,
        averageATR,
        distancePips
    );
}

//+------------------------------------------------------------------+
//| Log limit order fill for tracking                                |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::LogLimitOrderFill(ulong ticket, double fillPrice)
{
    if(m_dbManager == NULL)
        return;
    
    // Update database with fill information
    m_dbManager.UpdateLimitOrderFill(ticket, TimeCurrent(), fillPrice);
    
    Print(StringFormat("[LIMIT-ORDER] Order #%I64u filled at %.5f", ticket, fillPrice));
}

//+------------------------------------------------------------------+
//| Log limit order cancellation for tracking                        |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::LogLimitOrderCancel(ulong ticket, string cancelReason)
{
    if(m_dbManager == NULL)
        return;
    
    // Update database with cancellation information
    m_dbManager.UpdateLimitOrderCancel(ticket, TimeCurrent(), cancelReason);
}

//+------------------------------------------------------------------+
//| Phase 6: Adjust limit order price dynamically                    |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::AdjustLimitOrderPrice(ulong ticket)
{
    // Phase 6: Only adjust if dynamic adjustment feature flag enabled
    if(!m_enableDynamicAdjustment)
        return;
    
    if(!OrderSelect(ticket)) return;
    if(OrderGetString(ORDER_SYMBOL) != m_symbol) return;
    if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) return;
    
    ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
    if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
        return;
    
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
    double pipSize = GetPipSize();
    double distance = MathAbs(currentPrice - orderPrice) / pipSize;
    
    // Default adjustment trigger: 5 pips
    double adjustmentTriggerPips = 5.0;
    
    // Check if price is approaching
    if(distance <= adjustmentTriggerPips && distance > 2.0)
    {
        // Move limit price closer (within 2 pips)
        bool isBuy = (orderType == ORDER_TYPE_BUY_LIMIT);
        double newLimitPrice = 0.0;
        
        if(isBuy)
            newLimitPrice = currentPrice - (2.0 * pipSize); // 2 pips below current
        else
            newLimitPrice = currentPrice + (2.0 * pipSize); // 2 pips above current
        
        // Normalize price
        int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
        newLimitPrice = NormalizeDouble(newLimitPrice, digits);
        
        // Modify order
        datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
        if(m_trade.OrderModify(ticket, newLimitPrice, OrderGetDouble(ORDER_SL), 
                              OrderGetDouble(ORDER_TP), ORDER_TIME_SPECIFIED, expiration))
        {
            Print(StringFormat("[LIMIT-ORDER] Adjusted order #%I64u from %.5f to %.5f",
                  ticket, orderPrice, newLimitPrice));
        }
    }
}

//+------------------------------------------------------------------+
//| Phase 6: Check if high-impact news is upcoming                  |
//+------------------------------------------------------------------+
bool CGrandeLimitOrderManager::HasUpcomingHighImpactNews(datetime newsEventTime, int newsCancelMinutesBefore)
{
    if(newsEventTime <= 0)
        return false;
    
    datetime timeToNews = newsEventTime - TimeCurrent();
    return (timeToNews > 0 && timeToNews < (newsCancelMinutesBefore * 60));
}

//+------------------------------------------------------------------+
//| Phase 6: Cancel orders before high-impact news                  |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::CancelOrdersBeforeNews(datetime newsEventTime, int newsCancelMinutesBefore)
{
    if(newsEventTime <= 0)
        return;
    
    if(!HasUpcomingHighImpactNews(newsEventTime, newsCancelMinutesBefore))
        return;
    
    // Cancel all pending limit orders
    int total = OrdersTotal();
    for(int i = total - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
        
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
        {
            if(m_trade.OrderDelete(ticket))
            {
                Print(StringFormat("[LIMIT-ORDER] Cancelled order #%I64u before news event at %s",
                      ticket, TimeToString(newsEventTime)));
                LogLimitOrderCancel(ticket, "Cancelled before high-impact news");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get count of pending limit orders                                |
//+------------------------------------------------------------------+
int CGrandeLimitOrderManager::GetPendingOrderCount()
{
    int count = 0;
    int total = OrdersTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket)) continue;
        if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
        
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
            count++;
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Check if a new order can be placed                              |
//+------------------------------------------------------------------+
bool CGrandeLimitOrderManager::CanPlaceNewOrder()
{
    // Maximum pending orders limit (can be made configurable later)
    const int MAX_PENDING_ORDERS = 20;
    
    int currentCount = GetPendingOrderCount();
    return (currentCount < MAX_PENDING_ORDERS);
}

//+------------------------------------------------------------------+
//| Set feature flags for enhanced limit order features             |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::SetFeatureFlags(bool trackFillMetrics, bool useRegimeFiltering,
                                                bool requireMultiTimeframeAlignment, bool useATRScaling,
                                                bool useFillProbability, bool enableDynamicAdjustment,
                                                bool cancelOrdersBeforeNews)
{
    m_trackFillMetrics = trackFillMetrics;
    m_useRegimeFiltering = useRegimeFiltering;
    m_requireMultiTimeframeAlignment = requireMultiTimeframeAlignment;
    m_useATRScaling = useATRScaling;
    m_useFillProbability = useFillProbability;
    m_enableDynamicAdjustment = enableDynamicAdjustment;
    m_cancelOrdersBeforeNews = cancelOrdersBeforeNews;
}
//+------------------------------------------------------------------+

