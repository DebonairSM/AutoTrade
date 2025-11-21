//+------------------------------------------------------------------+
//|                                   GrandeConfluenceDetector.mqh   |
//|                                  Grande Trading System Component |
//|                                                                  |
//| Purpose: Detect confluence zones for optimal limit order         |
//|          placement by analyzing multiple technical factors       |
//|                                                                  |
//| This module scores potential entry levels based on:              |
//| - Key support/resistance levels                                  |
//| - Fibonacci retracement levels                                   |
//| - Round number levels (psychological levels)                     |
//| - EMA levels (20, 50, 200)                                       |
//| - Recent candle structure and rejection points                   |
//+------------------------------------------------------------------+
//
// RESPONSIBILITIES:
//   - Identify confluence zones (multiple technical factors at same price)
//   - Score zones based on number of factors present
//   - Find optimal limit order placement prices
//   - Integrate key levels, Fibonacci levels, EMAs, and round numbers
//   - Rank confluence zones by score and proximity
//
// DEPENDENCIES:
//   - GrandeFibonacciCalculator.mqh (for Fibonacci level detection)
//   - GrandeCandleAnalyzer.mqh (for candle rejection detection)
//
// STATE MANAGED:
//   - Symbol and timeframe
//   - Proximity tolerance (pips for grouping factors)
//   - Minimum confluence score required
//   - Maximum number of zones to analyze
//   - Detected confluence zones
//
// PUBLIC INTERFACE:
//   bool Initialize(symbol, timeframe)
//   void AddKeyLevelsToAnalysis(resistance[], support[])
//   ConfluenceZone GetBestConfluenceZone(isBuy, price, maxDistancePips)
//   double GetBestLimitOrderPrice(isBuy, price, maxDistancePips)
//   int GetConfluenceZonesCount() - Get number of detected zones
//   void SetProximityPips(pips) - Set grouping tolerance
//   void SetMinConfluenceScore(score) - Set minimum score
//   void SetMaxZones(count) - Set max zones to analyze
//
// IMPLEMENTATION NOTES:
//   - Groups factors within proximity tolerance into zones
//   - Scores zones by count of factors present
//   - Considers distance from current price in ranking
//   - Validates limit order placement within broker requirements
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestConfluenceDetector.mqh
//+------------------------------------------------------------------+

#property copyright "Grande Trading System"
#property link      ""
#property version   "1.00"
#property strict

#include "GrandeFibonacciCalculator.mqh"
#include "GrandeCandleAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Structure for a single confluence zone                           |
//+------------------------------------------------------------------+
struct ConfluenceZone
{
    double price;                // Price level of the zone
    int score;                   // Confluence score (number of factors)
    string factors;              // List of factors present (e.g., "KeyLevel+Fib618+EMA50")
    double distanceFromPrice;    // Distance from current market price in pips
    double distanceAbs;          // Absolute distance from current price
    
    // Individual factor flags
    bool hasKeyLevel;
    bool hasFibLevel;
    bool hasRoundNumber;
    bool hasEMA;
    bool hasCandleRejection;
    
    // Details
    string keyLevelType;         // "RESISTANCE" or "SUPPORT"
    string fibLevelName;         // "Fib 61.8%" etc.
    string emaLevel;             // "EMA20", "EMA50", "EMA200"
    int roundNumberType;         // 0=50pips, 1=100pips, 2=major (e.g., 1.15000)
};

//+------------------------------------------------------------------+
//| Confluence Detector Class                                        |
//+------------------------------------------------------------------+
class CGrandeConfluenceDetector
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    
    // Component objects
    CGrandeFibonacciCalculator* m_fibCalculator;
    CGrandeCandleAnalyzer* m_candleAnalyzer;
    
    // Settings
    double            m_proximityPips;       // Pips to consider "at" a level
    int               m_minConfluenceScore;  // Minimum score to be valid zone
    int               m_maxZonesToReturn;    // Max number of zones to return
    
    // Helper functions
    double GetPipSize();
    bool IsRoundNumber(double price, int &roundType);
    double GetEMAValue(int period);
    double GetNearestEMA(double price, double proximityPips, string &emaName);
    void SortZonesByScore(ConfluenceZone &zones[]);
    void MergeNearbyZones(ConfluenceZone &zones[], double mergePips);
    
public:
    // Constructor/Destructor
    CGrandeConfluenceDetector(string symbol, ENUM_TIMEFRAMES timeframe);
    ~CGrandeConfluenceDetector();
    
    // Main analysis functions
    void FindConfluenceZones(bool isBuy, double currentPrice, 
                             double maxDistancePips, ConfluenceZone &zones[]);
    ConfluenceZone GetBestConfluenceZone(bool isBuy, double currentPrice, 
                                         double maxDistancePips);
    double GetBestLimitOrderPrice(bool isBuy, double currentPrice, 
                                  double maxDistancePips);
    
    // Key level integration (requires external key level array)
    void AddKeyLevelsToAnalysis(double &resistanceLevels[], double &supportLevels[]);
    
    // Zone validation
    bool IsValidConfluenceZone(ConfluenceZone &zone, bool isBuy);
    int CalculateZoneStrength(ConfluenceZone &zone);
    
    // Utility functions
    void PrintConfluenceZones(ConfluenceZone &zones[]);
    void PrintZoneDetails(ConfluenceZone &zone);
    
    // Settings
    void SetProximityPips(double pips) { m_proximityPips = pips; }
    void SetMinConfluenceScore(int score) { m_minConfluenceScore = score; }
    void SetMaxZones(int maxZones) { m_maxZonesToReturn = maxZones; }
    
    // External storage for key levels (to be set before analysis)
    double m_resistanceLevels[];
    double m_supportLevels[];
    int m_numResistance;
    int m_numSupport;
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandeConfluenceDetector::CGrandeConfluenceDetector(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    
    // Create component objects
    m_fibCalculator = new CGrandeFibonacciCalculator(symbol, timeframe);
    m_candleAnalyzer = new CGrandeCandleAnalyzer(symbol, timeframe);
    
    // Default settings
    m_proximityPips = 10.0;      // Within 10 pips
    m_minConfluenceScore = 2;    // At least 2 factors
    m_maxZonesToReturn = 3;      // Return top 3 zones
    
    // Initialize key level arrays
    m_numResistance = 0;
    m_numSupport = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CGrandeConfluenceDetector::~CGrandeConfluenceDetector()
{
    if(m_fibCalculator != NULL)
        delete m_fibCalculator;
    if(m_candleAnalyzer != NULL)
        delete m_candleAnalyzer;
}

//+------------------------------------------------------------------+
//| Get pip size                                                      |
//+------------------------------------------------------------------+
double CGrandeConfluenceDetector::GetPipSize()
{
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    if(digits == 2 || digits == 3)
        return 0.01;
    else
        return 0.0001;
}

//+------------------------------------------------------------------+
//| Check if price is a round number                                 |
//+------------------------------------------------------------------+
bool CGrandeConfluenceDetector::IsRoundNumber(double price, int &roundType)
{
    double pip = GetPipSize();
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    // Major round numbers (e.g., 1.15000, 1.20000) - every 500 pips
    double major = MathRound(price / (500 * pip)) * (500 * pip);
    if(MathAbs(price - major) < 0.5 * pip)
    {
        roundType = 2;
        return true;
    }
    
    // 100-pip round numbers (e.g., 1.1400, 1.1500)
    double hundred = MathRound(price / (100 * pip)) * (100 * pip);
    if(MathAbs(price - hundred) < 0.5 * pip)
    {
        roundType = 1;
        return true;
    }
    
    // 50-pip round numbers (e.g., 1.1450, 1.1550)
    double fifty = MathRound(price / (50 * pip)) * (50 * pip);
    if(MathAbs(price - fifty) < 0.5 * pip)
    {
        roundType = 0;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get EMA value for a period                                       |
//+------------------------------------------------------------------+
double CGrandeConfluenceDetector::GetEMAValue(int period)
{
    int handle = iMA(m_symbol, m_timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
    if(handle == INVALID_HANDLE)
        return 0;
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    
    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
    {
        IndicatorRelease(handle);
        return 0;
    }
    
    double value = buffer[0];
    IndicatorRelease(handle);
    
    return value;
}

//+------------------------------------------------------------------+
//| Find nearest EMA to a price level                                |
//+------------------------------------------------------------------+
double CGrandeConfluenceDetector::GetNearestEMA(double price, double proximityPips, string &emaName)
{
    double proximity = proximityPips * GetPipSize();
    
    // Check EMA20, EMA50, EMA200
    int periods[] = {20, 50, 200};
    string names[] = {"EMA20", "EMA50", "EMA200"};
    
    double nearestEma = 0;
    double minDistance = DBL_MAX;
    
    for(int i = 0; i < ArraySize(periods); i++)
    {
        double ema = GetEMAValue(periods[i]);
        if(ema <= 0)
            continue;
        
        double distance = MathAbs(price - ema);
        if(distance <= proximity && distance < minDistance)
        {
            minDistance = distance;
            nearestEma = ema;
            emaName = names[i];
        }
    }
    
    return nearestEma;
}

//+------------------------------------------------------------------+
//| Set key levels for analysis                                      |
//+------------------------------------------------------------------+
void CGrandeConfluenceDetector::AddKeyLevelsToAnalysis(double &resistanceLevels[], 
                                                        double &supportLevels[])
{
    m_numResistance = ArraySize(resistanceLevels);
    m_numSupport = ArraySize(supportLevels);
    
    ArrayResize(m_resistanceLevels, m_numResistance);
    ArrayResize(m_supportLevels, m_numSupport);
    
    for(int i = 0; i < m_numResistance; i++)
        m_resistanceLevels[i] = resistanceLevels[i];
    
    for(int i = 0; i < m_numSupport; i++)
        m_supportLevels[i] = supportLevels[i];
}

//+------------------------------------------------------------------+
//| Find all confluence zones                                        |
//+------------------------------------------------------------------+
void CGrandeConfluenceDetector::FindConfluenceZones(bool isBuy, 
                                                     double currentPrice, 
                                                     double maxDistancePips,
                                                     ConfluenceZone &zones[])
{
    ArrayResize(zones, 0);
    
    double proximity = m_proximityPips * GetPipSize();
    double maxDistance = maxDistancePips * GetPipSize();
    
    // Calculate Fibonacci levels
    FibLevels fib = m_fibCalculator.CalculateAutoFibonacci();
    
    // Collect all potential price levels to analyze
    double priceLevels[];
    int levelCount = 0;
    
    // Add Fibonacci levels
    if(fib.isValid)
    {
        ArrayResize(priceLevels, levelCount + 7);
        priceLevels[levelCount++] = fib.level_000;
        priceLevels[levelCount++] = fib.level_236;
        priceLevels[levelCount++] = fib.level_382;
        priceLevels[levelCount++] = fib.level_500;
        priceLevels[levelCount++] = fib.level_618;
        priceLevels[levelCount++] = fib.level_786;
        priceLevels[levelCount++] = fib.level_100;
    }
    
    // Add key levels
    for(int i = 0; i < m_numResistance; i++)
    {
        ArrayResize(priceLevels, levelCount + 1);
        priceLevels[levelCount++] = m_resistanceLevels[i];
    }
    for(int i = 0; i < m_numSupport; i++)
    {
        ArrayResize(priceLevels, levelCount + 1);
        priceLevels[levelCount++] = m_supportLevels[i];
    }
    
    // Add EMA levels
    double ema20 = GetEMAValue(20);
    double ema50 = GetEMAValue(50);
    double ema200 = GetEMAValue(200);
    if(ema20 > 0) { ArrayResize(priceLevels, levelCount + 1); priceLevels[levelCount++] = ema20; }
    if(ema50 > 0) { ArrayResize(priceLevels, levelCount + 1); priceLevels[levelCount++] = ema50; }
    if(ema200 > 0) { ArrayResize(priceLevels, levelCount + 1); priceLevels[levelCount++] = ema200; }
    
    // Add round number levels within range
    double roundStart = currentPrice - maxDistance;
    double roundEnd = currentPrice + maxDistance;
    double pip = GetPipSize();
    
    for(double p = MathRound(roundStart / (50 * pip)) * (50 * pip); p <= roundEnd; p += 50 * pip)
    {
        int roundType;
        if(IsRoundNumber(p, roundType))
        {
            ArrayResize(priceLevels, levelCount + 1);
            priceLevels[levelCount++] = p;
        }
    }
    
    // Analyze each potential level for confluence
    for(int i = 0; i < levelCount; i++)
    {
        double price = priceLevels[i];
        
        // Skip if outside max distance
        double distanceAbs = MathAbs(price - currentPrice);
        if(distanceAbs > maxDistance)
            continue;
        
        // Skip if wrong direction
        if(isBuy && price > currentPrice)
            continue;
        if(!isBuy && price < currentPrice)
            continue;
        
        // Create zone
        ConfluenceZone zone;
        zone.price = price;
        zone.distanceAbs = distanceAbs;
        zone.distanceFromPrice = distanceAbs / GetPipSize();
        zone.score = 0;
        zone.factors = "";
        zone.hasKeyLevel = false;
        zone.hasFibLevel = false;
        zone.hasRoundNumber = false;
        zone.hasEMA = false;
        zone.hasCandleRejection = false;
        
        // Check for key level
        for(int k = 0; k < m_numResistance; k++)
        {
            if(MathAbs(price - m_resistanceLevels[k]) <= proximity)
            {
                zone.hasKeyLevel = true;
                zone.keyLevelType = "RESISTANCE";
                zone.score++;
                if(zone.factors != "") zone.factors += "+";
                zone.factors += "KeyRes";
                break;
            }
        }
        if(!zone.hasKeyLevel)
        {
            for(int k = 0; k < m_numSupport; k++)
            {
                if(MathAbs(price - m_supportLevels[k]) <= proximity)
                {
                    zone.hasKeyLevel = true;
                    zone.keyLevelType = "SUPPORT";
                    zone.score++;
                    if(zone.factors != "") zone.factors += "+";
                    zone.factors += "KeySup";
                    break;
                }
            }
        }
        
        // Check for Fibonacci level
        if(fib.isValid)
        {
            string fibName;
            if(m_fibCalculator.IsPriceNearFibLevel(price, fib, m_proximityPips, fibName))
            {
                zone.hasFibLevel = true;
                zone.fibLevelName = fibName;
                zone.score++;
                if(zone.factors != "") zone.factors += "+";
                zone.factors += StringSubstr(fibName, 4); // Remove "Fib " prefix
            }
        }
        
        // Check for round number
        int roundType;
        if(IsRoundNumber(price, roundType))
        {
            zone.hasRoundNumber = true;
            zone.roundNumberType = roundType;
            zone.score++;
            if(zone.factors != "") zone.factors += "+";
            if(roundType == 2) zone.factors += "MajorRound";
            else if(roundType == 1) zone.factors += "100pips";
            else zone.factors += "50pips";
        }
        
        // Check for EMA
        string emaName;
        double nearEma = GetNearestEMA(price, m_proximityPips, emaName);
        if(nearEma > 0)
        {
            zone.hasEMA = true;
            zone.emaLevel = emaName;
            zone.score++;
            if(zone.factors != "") zone.factors += "+";
            zone.factors += emaName;
        }
        
        // Check for recent candle rejection
        bool hasRejection = m_candleAnalyzer.HasRecentRejection(!isBuy, 5);
        if(hasRejection)
        {
            zone.hasCandleRejection = true;
            zone.score++;
            if(zone.factors != "") zone.factors += "+";
            zone.factors += "Rejection";
        }
        
        // Only add zones that meet minimum score
        if(zone.score >= m_minConfluenceScore)
        {
            int size = ArraySize(zones);
            ArrayResize(zones, size + 1);
            zones[size] = zone;
        }
    }
    
    // Merge nearby zones
    MergeNearbyZones(zones, m_proximityPips / 2);
    
    // Sort by score (highest first)
    SortZonesByScore(zones);
    
    // Limit to max zones
    if(ArraySize(zones) > m_maxZonesToReturn)
        ArrayResize(zones, m_maxZonesToReturn);
}

//+------------------------------------------------------------------+
//| Get best confluence zone                                         |
//+------------------------------------------------------------------+
ConfluenceZone CGrandeConfluenceDetector::GetBestConfluenceZone(bool isBuy, 
                                                                 double currentPrice, 
                                                                 double maxDistancePips)
{
    ConfluenceZone emptyZone;
    emptyZone.score = 0;
    emptyZone.price = 0;
    
    ConfluenceZone zones[];
    FindConfluenceZones(isBuy, currentPrice, maxDistancePips, zones);
    
    if(ArraySize(zones) == 0)
        return emptyZone;
    
    return zones[0]; // Already sorted by score
}

//+------------------------------------------------------------------+
//| Get best limit order price                                       |
//+------------------------------------------------------------------+
double CGrandeConfluenceDetector::GetBestLimitOrderPrice(bool isBuy, 
                                                          double currentPrice, 
                                                          double maxDistancePips)
{
    ConfluenceZone zone = GetBestConfluenceZone(isBuy, currentPrice, maxDistancePips);
    
    if(zone.score == 0)
        return 0; // No valid zone found
    
    return zone.price;
}

//+------------------------------------------------------------------+
//| Validate confluence zone for entry                               |
//+------------------------------------------------------------------+
bool CGrandeConfluenceDetector::IsValidConfluenceZone(ConfluenceZone &zone, bool isBuy)
{
    // Must meet minimum score
    if(zone.score < m_minConfluenceScore)
        return false;
    
    // For buy orders, prefer support levels
    // For sell orders, prefer resistance levels
    if(isBuy && zone.hasKeyLevel && zone.keyLevelType == "RESISTANCE")
        return false; // Don't buy at resistance
    
    if(!isBuy && zone.hasKeyLevel && zone.keyLevelType == "SUPPORT")
        return false; // Don't sell at support
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate zone strength (weighted score)                         |
//+------------------------------------------------------------------+
int CGrandeConfluenceDetector::CalculateZoneStrength(ConfluenceZone &zone)
{
    int strength = 0;
    
    // Key levels are most important
    if(zone.hasKeyLevel) strength += 3;
    
    // Fibonacci 61.8% is very strong
    if(zone.hasFibLevel && StringFind(zone.fibLevelName, "61.8") >= 0)
        strength += 3;
    else if(zone.hasFibLevel)
        strength += 2;
    
    // Major round numbers are significant
    if(zone.hasRoundNumber && zone.roundNumberType == 2)
        strength += 2;
    else if(zone.hasRoundNumber)
        strength += 1;
    
    // EMA levels add confirmation
    if(zone.hasEMA) strength += 2;
    
    // Recent rejection adds confirmation
    if(zone.hasCandleRejection) strength += 1;
    
    return strength;
}

//+------------------------------------------------------------------+
//| Sort zones by score (descending)                                 |
//+------------------------------------------------------------------+
void CGrandeConfluenceDetector::SortZonesByScore(ConfluenceZone &zones[])
{
    int size = ArraySize(zones);
    
    for(int i = 0; i < size - 1; i++)
    {
        for(int j = i + 1; j < size; j++)
        {
            // Sort by score first, then by distance (closer is better)
            bool shouldSwap = false;
            
            if(zones[j].score > zones[i].score)
                shouldSwap = true;
            else if(zones[j].score == zones[i].score && 
                    zones[j].distanceFromPrice < zones[i].distanceFromPrice)
                shouldSwap = true;
            
            if(shouldSwap)
            {
                ConfluenceZone temp = zones[i];
                zones[i] = zones[j];
                zones[j] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Merge nearby zones                                               |
//+------------------------------------------------------------------+
void CGrandeConfluenceDetector::MergeNearbyZones(ConfluenceZone &zones[], double mergePips)
{
    double mergeDistance = mergePips * GetPipSize();
    int size = ArraySize(zones);
    
    for(int i = 0; i < size - 1; i++)
    {
        if(zones[i].score == 0) continue; // Already merged
        
        for(int j = i + 1; j < size; j++)
        {
            if(zones[j].score == 0) continue;
            
            if(MathAbs(zones[i].price - zones[j].price) <= mergeDistance)
            {
                // Merge j into i
                zones[i].score += zones[j].score;
                if(zones[i].factors != "") zones[i].factors += "+";
                zones[i].factors += zones[j].factors;
                
                // Average the price
                zones[i].price = (zones[i].price + zones[j].price) / 2.0;
                
                // Mark j as merged
                zones[j].score = 0;
            }
        }
    }
    
    // Remove merged zones
    ConfluenceZone temp[];
    int tempCount = 0;
    
    for(int i = 0; i < size; i++)
    {
        if(zones[i].score > 0)
        {
            ArrayResize(temp, tempCount + 1);
            temp[tempCount++] = zones[i];
        }
    }
    
    // Manually copy array (ArrayCopy doesn't work with structures containing strings)
    ArrayResize(zones, tempCount);
    for(int i = 0; i < tempCount; i++)
    {
        zones[i] = temp[i];
    }
}

//+------------------------------------------------------------------+
//| Print confluence zones                                           |
//+------------------------------------------------------------------+
void CGrandeConfluenceDetector::PrintConfluenceZones(ConfluenceZone &zones[])
{
    int size = ArraySize(zones);
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    Print("========== Confluence Zones (", size, " found) ==========");
    
    for(int i = 0; i < size; i++)
    {
        Print(StringFormat("#%d: Price=%s | Score=%d | Distance=%.1f pips | Factors=%s",
              i + 1,
              DoubleToString(zones[i].price, digits),
              zones[i].score,
              zones[i].distanceFromPrice,
              zones[i].factors));
    }
    
    Print("=============================================");
}

//+------------------------------------------------------------------+
//| Print single zone details                                        |
//+------------------------------------------------------------------+
void CGrandeConfluenceDetector::PrintZoneDetails(ConfluenceZone &zone)
{
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    Print("===== Confluence Zone Details =====");
    Print("Price: ", DoubleToString(zone.price, digits));
    Print("Score: ", zone.score);
    Print("Distance: ", DoubleToString(zone.distanceFromPrice, 1), " pips");
    Print("Factors: ", zone.factors);
    Print("-----------------------------------");
    Print("Key Level: ", zone.hasKeyLevel ? "YES (" + zone.keyLevelType + ")" : "NO");
    Print("Fib Level: ", zone.hasFibLevel ? "YES (" + zone.fibLevelName + ")" : "NO");
    Print("Round Number: ", zone.hasRoundNumber ? "YES" : "NO");
    Print("EMA: ", zone.hasEMA ? "YES (" + zone.emaLevel + ")" : "NO");
    Print("Rejection: ", zone.hasCandleRejection ? "YES" : "NO");
    Print("===================================");
}
//+------------------------------------------------------------------+

