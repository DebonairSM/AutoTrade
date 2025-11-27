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
    
    // Helper functions
    double GetPipSize();
    void PrepareKeyLevelsForConfluence(double &resistanceLevels[], double &supportLevels[]);
    void AdjustStopsForLimitPrice(bool isBuy, double basePrice, double limitPrice, double &sl, double &tp);
    bool ValidateLimitOrder(const LimitOrderRequest &request, double limitPrice);
    datetime CalculateExpiration();
    
public:
    // Constructor/Destructor
    CGrandeLimitOrderManager();
    ~CGrandeLimitOrderManager();
    
    // Initialization
    bool Initialize(string symbol, int magicNumber, 
                    CGrandeConfluenceDetector* confluenceDetector,
                    CGrandeKeyLevelDetector* keyLevelDetector,
                    CTrade* trade,
                    const LimitOrderConfig &config);
    
    // Main placement method
    LimitOrderResult PlaceLimitOrder(const LimitOrderRequest &request);
    
    // Price calculation
    double FindOptimalLimitPrice(bool isBuy, double currentPrice, int maxDistancePips);
    
    // Duplicate detection
    bool HasSimilarOrder(bool isBuyLimit, double levelPrice, int tolerancePoints = -1);
    
    // Stale order management
    void ManageStaleOrders();
    
    // Configuration
    void SetConfig(const LimitOrderConfig &config) { m_config = config; }
    LimitOrderConfig GetConfig() const { return m_config; }
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
                                          const LimitOrderConfig &config)
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
    return TimeCurrent() + (m_config.expirationHours * 3600);
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
        return LimitOrderResult::Success(orderTicket, "LIMIT", limitPrice, adjustedSL, adjustedTP);
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
//| Manage stale limit orders                                         |
//+------------------------------------------------------------------+
void CGrandeLimitOrderManager::ManageStaleOrders()
{
    if(!m_config.cancelStaleOrders)
        return;
    
    double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double pipSize = GetPipSize();
    double maxStaleDistance = m_config.staleOrderDistancePips * pipSize;
    
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

