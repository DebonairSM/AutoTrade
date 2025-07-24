//+------------------------------------------------------------------+
//| GrandeKeyLevelDetector.mqh                                       |
//| Copyright 2024, Grande Tech                                      |
//| Enterprise-Level Key Level Detection with Superior Chart Display |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation + V-2-EA-Breakouts Enhancements
// Reference: Advanced object-oriented programming and enterprise chart management

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "2.00"
#property description "Enterprise-grade key level detection with superior visual chart display"

//+------------------------------------------------------------------+
//| Enhanced Constants                                               |
//+------------------------------------------------------------------+
#define VOLUME_SPIKE_MULTIPLIER 2.0
#define VOLUME_LOOKBACK_BARS 20
#define VOLUME_STRENGTH_MAX_BONUS 0.15
#define MIN_CHART_UPDATE_SECONDS 5
#define MIN_LOG_INTERVAL_SECONDS 60
#define MAX_LEVELS_PER_TYPE 15
#define CHART_OBJECT_PREFIX "GKL_"

//+------------------------------------------------------------------+
//| Enhanced Structures                                              |
//+------------------------------------------------------------------+
struct SKeyLevel
{
    double      price;              // Level price
    bool        isResistance;       // true = resistance, false = support
    int         touchCount;         // Number of touches
    double      strength;           // Level strength (0.0 - 1.0)
    datetime    firstTouch;         // First touch time
    datetime    lastTouch;          // Last touch time
    bool        volumeConfirmed;    // Volume confirmation
    double      volumeRatio;        // Volume ratio at formation
    double      slopeConsistency;   // Slope validation score
    double      bounceQuality;      // Bounce quality score
    int         timeframeRelevance; // Cross-timeframe validation score
};

struct STouchQuality 
{
    int         touchCount;         // Number of touches
    double      avgBounceStrength;  // Average bounce strength in pips
    double      avgBounceVolume;    // Average volume during bounces
    double      maxBounceSize;      // Maximum bounce size
    int         quickestBounce;     // Quickest bounce in bars
    int         slowestBounce;      // Slowest bounce in bars
    double      bounceConsistency;  // Bounce consistency score
    double      touchSpacing;       // Average spacing between touches
    int         consecutiveTouches; // Number of consecutive touches
    bool        cleanBounces;       // All bounces were clean
};

struct SEnterpriseChartLine
{
    string      name;               // Object name
    double      price;              // Line price
    datetime    lastUpdate;         // Last update time
    color       lineColor;          // Line color
    bool        isActive;           // Is line active
    int         lineWidth;          // Line width
    ENUM_LINE_STYLE lineStyle;      // Line style
    bool        isVerified;         // Chart object verified
    double      strength;           // Level strength for sorting
    int         transparency;       // Line transparency
};

struct SChartDiagnostics
{
    int         totalObjectsCreated;
    int         totalObjectsFailed;
    int         totalObjectsVerified;
    datetime    lastDiagnostic;
    string      lastError;
    
    void Reset()
    {
        totalObjectsCreated = 0;
        totalObjectsFailed = 0;
        totalObjectsVerified = 0;
        lastDiagnostic = 0;
        lastError = "";
    }
};

struct SLogThrottle
{
    datetime    lastDebugMessage;
    datetime    lastChartUpdate;
    string      lastMessage;
    int         duplicateCount;
    
    void Reset()
    {
        lastDebugMessage = 0;
        lastChartUpdate = 0;
        lastMessage = "";
        duplicateCount = 0;
    }
};

//+------------------------------------------------------------------+
//| Enterprise Grande Key Level Detector Class                       |
//+------------------------------------------------------------------+
class CGrandeKeyLevelDetector
{
private:
    // Enhanced Configuration Parameters
    int         m_lookbackPeriod;       // Lookback period for analysis
    double      m_minStrength;          // Minimum level strength
    double      m_touchZone;            // Touch zone tolerance
    double      m_providedTouchZone;    // User-provided touch zone
    int         m_minTouches;           // Minimum touches required
    int         m_maxBounceDelay;       // Maximum bounce delay in bars
    bool        m_showDebugPrints;      // Debug output flag
    bool        m_useAdvancedValidation; // Use advanced swing validation
    
    // Enhanced Key Level Storage
    SKeyLevel   m_keyLevels[];          // Array of key levels
    int         m_levelCount;           // Number of levels found
    datetime    m_lastUpdate;           // Last update time
    
    // Enterprise Chart Management
    SEnterpriseChartLine m_chartLines[]; // Enhanced chart line objects
    datetime    m_lastChartUpdate;      // Last chart update
    long        m_chartID;              // Chart ID
    SChartDiagnostics m_diagnostics;    // Chart diagnostics
    SLogThrottle m_logThrottle;         // Logging throttle
    
    // Performance Monitoring
    int         m_totalCalculations;    // Total calculations performed
    double      m_avgCalculationTime;   // Average calculation time
    datetime    m_lastPerformanceReset; // Last performance reset
    
public:
    //+------------------------------------------------------------------+
    //| Enhanced Constructor and Destructor                             |
    //+------------------------------------------------------------------+
    CGrandeKeyLevelDetector(void)
    {
        // Initialize configuration with enterprise defaults
        m_lookbackPeriod = 100;
        m_minStrength = 0.55;
        m_touchZone = 0.0005;
        m_providedTouchZone = 0.0005;
        m_minTouches = 2;
        m_maxBounceDelay = 8;
        m_showDebugPrints = false;
        m_useAdvancedValidation = true;
        
        // Initialize counters and tracking
        m_levelCount = 0;
        m_lastUpdate = 0;
        m_lastChartUpdate = 0;
        m_chartID = ChartID();
        
        // Initialize arrays with intelligent sizing
        ArrayResize(m_keyLevels, 200);
        ArrayResize(m_chartLines, 200);
        
        // Initialize diagnostics and throttling
        m_diagnostics.Reset();
        m_logThrottle.Reset();
        
        // Initialize performance monitoring
        m_totalCalculations = 0;
        m_avgCalculationTime = 0;
        m_lastPerformanceReset = TimeCurrent();
        
        LogInfo("🚀 Enterprise Grande Key Level Detector initialized");
    }
    
    ~CGrandeKeyLevelDetector(void)
    {
        ClearAllChartObjects();
        LogInfo("🔚 Grande Key Level Detector destroyed - all chart objects cleared");
    }
    
    //+------------------------------------------------------------------+
    //| Enhanced Initialization Method                                   |
    //+------------------------------------------------------------------+
    bool Initialize(int lookbackPeriod = 100, 
                    double minStrength = 0.55, 
                    double touchZone = 0.0005, 
                    int minTouches = 2,
                    bool showDebugPrints = false,
                    bool useAdvancedValidation = true)
    {
        // Enhanced parameter validation
        if(lookbackPeriod < 10 || lookbackPeriod > 2000)
        {
            LogError("Invalid lookback period. Must be between 10 and 2000, got: " + IntegerToString(lookbackPeriod));
            return false;
        }
        
        if(minStrength < 0.1 || minStrength > 1.0)
        {
            LogError("Invalid minimum strength. Must be between 0.1 and 1.0, got: " + DoubleToString(minStrength, 3));
            return false;
        }
        
        if(minTouches < 1 || minTouches > 15)
        {
            LogError("Invalid minimum touches. Must be between 1 and 15, got: " + IntegerToString(minTouches));
            return false;
        }
        
        // Store provided touch zone for intelligent processing
        m_providedTouchZone = touchZone;
        
        // Set enhanced configuration
        m_lookbackPeriod = lookbackPeriod;
        m_minStrength = minStrength;
        m_touchZone = GetEnhancedTouchZone(touchZone);
        m_minTouches = minTouches;
        m_showDebugPrints = showDebugPrints;
        m_useAdvancedValidation = useAdvancedValidation;
        
        // Enhanced data availability check
        int bars = Bars(_Symbol, Period());
        int requiredBars = m_lookbackPeriod + 20; // Extra buffer for advanced analysis
        
        if(bars < requiredBars)
        {
            LogError(StringFormat("Insufficient historical data. Need %d bars, got %d", requiredBars, bars));
            return false;
        }
        
        // Initialize enterprise features
        m_chartID = ChartID();
        m_levelCount = 0;
        m_lastUpdate = 0;
        m_lastChartUpdate = 0;
        m_diagnostics.Reset();
        m_logThrottle.Reset();
        
        // Performance validation
        uint testStart = GetTickCount();
        bool testSuccess = PerformInitializationTests();
        uint testTime = GetTickCount() - testStart;
        
        if(!testSuccess)
        {
            LogError("Initialization tests failed");
            return false;
        }
        
        LogInfo(StringFormat("✅ Enterprise initialization completed in %d ms", testTime));
        LogInfo(StringFormat("📊 Configuration: Symbol=%s, TF=%s, Lookback=%d, MinStrength=%.2f, TouchZone=%.5f", 
               _Symbol, EnumToString(Period()), m_lookbackPeriod, m_minStrength, m_touchZone));
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Enhanced Main Detection Method                                   |
    //+------------------------------------------------------------------+
    bool DetectKeyLevels()
    {
        uint startTime = GetTickCount();
        
        // Get enhanced price data with validation
        double highPrices[], lowPrices[], closePrices[], openPrices[];
        datetime times[];
        long volumes[];
        
        if(!GetValidatedMarketData(highPrices, lowPrices, closePrices, openPrices, times, volumes))
        {
            LogError("Failed to retrieve validated market data");
            return false;
        }
        
        // Reset level count and prepare for analysis
        m_levelCount = 0;
        int resistanceLevels = 0, supportLevels = 0;
        int potentialSwingHighs = 0, potentialSwingLows = 0;
        int validSwingHighs = 0, validSwingLows = 0;
        
        LogInfo(StringFormat("🔍 Starting enhanced level detection with %d bars", ArraySize(highPrices)));
        
        // Enhanced swing high detection (resistance levels) with fallback
        for(int i = 3; i < m_lookbackPeriod - 3; i++)
        {
            // Try enhanced detection first
            bool isSwingHigh = IsEnhancedSwingHigh(highPrices, lowPrices, i);
            
            // Fallback to simple detection if enhanced is too restrictive
            if(!isSwingHigh && (potentialSwingHighs + potentialSwingLows) < 5 && i > m_lookbackPeriod / 2)
            {
                isSwingHigh = IsSimpleSwingHigh(highPrices, i);
            }
            
            if(isSwingHigh)
            {
                potentialSwingHighs++;
                double level = highPrices[i];
                
                if(!IsNearExistingLevel(level))
                {
                    validSwingHighs++;
                    SKeyLevel newLevel = CreateKeyLevel(level, true, times[i]);
                    STouchQuality quality;
                    
                    newLevel.touchCount = CountEnhancedTouches(level, true, highPrices, lowPrices, times, quality);
                    
                    if(newLevel.touchCount >= m_minTouches)
                    {
                        newLevel.strength = CalculateEnhancedStrength(newLevel, quality);
                        newLevel.slopeConsistency = CalculateSlopeConsistency(highPrices, i);
                        newLevel.bounceQuality = quality.bounceConsistency;
                        
                        // Enhanced volume analysis
                        ApplyVolumeEnhancements(newLevel, volumes, i);
                        
                        if(newLevel.strength >= m_minStrength)
                        {
                            AddKeyLevel(newLevel);
                            resistanceLevels++;
                        }
                    }
                }
            }
        }
        
        // Enhanced swing low detection (support levels) with fallback
        for(int i = 3; i < m_lookbackPeriod - 3; i++)
        {
            // Try enhanced detection first
            bool isSwingLow = IsEnhancedSwingLow(lowPrices, highPrices, i);
            
            // Fallback to simple detection if enhanced is too restrictive
            if(!isSwingLow && (potentialSwingHighs + potentialSwingLows) < 5 && i > m_lookbackPeriod / 2)
            {
                isSwingLow = IsSimpleSwingLow(lowPrices, i);
            }
            
            if(isSwingLow)
            {
                potentialSwingLows++;
                double level = lowPrices[i];
                
                if(!IsNearExistingLevel(level))
                {
                    validSwingLows++;
                    SKeyLevel newLevel = CreateKeyLevel(level, false, times[i]);
                    STouchQuality quality;
                    
                    newLevel.touchCount = CountEnhancedTouches(level, false, highPrices, lowPrices, times, quality);
                    
                    if(newLevel.touchCount >= m_minTouches)
                    {
                        newLevel.strength = CalculateEnhancedStrength(newLevel, quality);
                        newLevel.slopeConsistency = CalculateSlopeConsistency(lowPrices, i);
                        newLevel.bounceQuality = quality.bounceConsistency;
                        
                        // Enhanced volume analysis
                        ApplyVolumeEnhancements(newLevel, volumes, i);
                        
                        if(newLevel.strength >= m_minStrength)
                        {
                            AddKeyLevel(newLevel);
                            supportLevels++;
                        }
                    }
                }
            }
        }
        
        // Level optimization and cleanup
        OptimizeKeyLevels();
        
        uint calculationTime = GetTickCount() - startTime;
        UpdatePerformanceMetrics(calculationTime);
        
        m_lastUpdate = TimeCurrent();
        
        LogInfo(StringFormat("📊 DETECTION ANALYSIS: Swings Found - %d highs (%d valid), %d lows (%d valid)", 
                potentialSwingHighs, validSwingHighs, potentialSwingLows, validSwingLows));
        LogInfo(StringFormat("⚙️ FILTER SETTINGS: MinStrength=%.2f, TouchZone=%.5f, MinTouches=%d", 
                m_minStrength, m_touchZone, m_minTouches));
        LogInfo(StringFormat("✅ Detection completed: %d levels (%dR/%dS) in %d ms", 
               m_levelCount, resistanceLevels, supportLevels, calculationTime));
        
        // Trigger enhanced chart update
        if(m_levelCount > 0)
        {
            UpdateEnhancedChartDisplay();
        }
        
        return m_levelCount > 0;
    }
    
    //+------------------------------------------------------------------+
    //| Enterprise Chart Display Methods                                 |
    //+------------------------------------------------------------------+
    void UpdateChartDisplay()
    {
        UpdateEnhancedChartDisplay();
    }
    
    void UpdateEnhancedChartDisplay()
    {
        if(m_levelCount == 0)
        {
            LogInfo("📊 No key levels to display on chart");
            return;
        }
        
        // Throttle chart updates for performance
        datetime currentTime = TimeCurrent();
        if(currentTime - m_lastChartUpdate < MIN_CHART_UPDATE_SECONDS)
        {
            return;
        }
        
        LogInfo(StringFormat("🎨 Starting enhanced chart display update for %d levels", m_levelCount));
        
        // Clear existing objects with verification
        ClearAllChartObjectsWithVerification();
        
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        int successCount = 0;
        int failureCount = 0;
        
        // Reset and prepare chart lines array
        ArrayFree(m_chartLines);
        ArrayResize(m_chartLines, m_levelCount);
        
        // Reclassify levels based on current price relationship
        ReclassifyLevelsBasedOnCurrentPrice(currentPrice);
        
        // Sort levels by strength for optimal display
        SortLevelsByStrength();
        
        for(int i = 0; i < m_levelCount; i++)
        {
            if(CreateEnhancedChartLine(m_keyLevels[i], currentPrice, currentTime, i))
            {
                successCount++;
            }
            else
            {
                failureCount++;
            }
        }
        
        // Force chart redraw with verification
        Sleep(100);
        ChartRedraw(m_chartID);
        
        // Verify all objects were created successfully
        VerifyChartObjects();
        
        m_lastChartUpdate = currentTime;
        m_logThrottle.lastChartUpdate = currentTime;
        
        LogInfo(StringFormat("✅ Chart display updated: %d/%d lines created successfully", 
               successCount, m_levelCount));
        
        if(failureCount > 0)
        {
            LogError(StringFormat("⚠️ %d chart objects failed to create", failureCount));
        }
        
        // Update diagnostics
        m_diagnostics.totalObjectsCreated += successCount;
        m_diagnostics.totalObjectsFailed += failureCount;
        m_diagnostics.lastDiagnostic = currentTime;
    }
    
    //+------------------------------------------------------------------+
    //| Enhanced Public Access Methods                                   |
    //+------------------------------------------------------------------+
    int GetKeyLevelCount() const { return m_levelCount; }
    
    bool GetKeyLevel(int index, SKeyLevel &level) const
    {
        if(index >= 0 && index < m_levelCount)
        {
            level = m_keyLevels[index];
            return true;
        }
        return false;
    }
    
    bool GetStrongestLevel(SKeyLevel &level) const
    {
        if(m_levelCount == 0) return false;
        
        double maxStrength = 0;
        int strongestIdx = -1;
        
        for(int i = 0; i < m_levelCount; i++)
        {
            if(m_keyLevels[i].strength > maxStrength)
            {
                maxStrength = m_keyLevels[i].strength;
                strongestIdx = i;
            }
        }
        
        if(strongestIdx >= 0)
        {
            level = m_keyLevels[strongestIdx];
            return true;
        }
        
        return false;
    }
    
    void PrintKeyLevelsReport()
    {
        PrintEnhancedReport();
    }
    
    void PrintEnhancedReport()
    {
        if(!m_showDebugPrints) return;
        
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        LogInfo("┌" + StringRepeat("─", 78) + "┐");
        LogInfo("│" + StringFormat("%76s", "🏆 ENTERPRISE GRANDE KEY LEVELS REPORT") + " │");
        LogInfo("├" + StringRepeat("─", 78) + "┤");
        LogInfo(StringFormat("│ Symbol: %-15s │ Current Price: %15.5f │ Levels: %8d │", 
               _Symbol, currentPrice, m_levelCount));
        LogInfo(StringFormat("│ Timeframe: %-12s │ Last Update: %17s │ Avg Time: %5.1fms │", 
               EnumToString(Period()), 
               TimeToString(m_lastUpdate, TIME_DATE|TIME_MINUTES),
               m_avgCalculationTime));
        LogInfo("├" + StringRepeat("─", 78) + "┤");
        
        // Sort levels by distance from current price for better reporting
        int indices[];
        double distances[];
        ArrayResize(indices, m_levelCount);
        ArrayResize(distances, m_levelCount);
        
        for(int i = 0; i < m_levelCount; i++)
        {
            indices[i] = i;
            distances[i] = MathAbs(currentPrice - m_keyLevels[i].price);
        }
        
        // Simple bubble sort by distance
        for(int i = 0; i < m_levelCount - 1; i++)
        {
            for(int j = 0; j < m_levelCount - 1 - i; j++)
            {
                if(distances[j] > distances[j + 1])
                {
                    // Swap distances
                    double tempDist = distances[j];
                    distances[j] = distances[j + 1];
                    distances[j + 1] = tempDist;
                    
                    // Swap indices
                    int tempIdx = indices[j];
                    indices[j] = indices[j + 1];
                    indices[j + 1] = tempIdx;
                }
            }
        }
        
        for(int i = 0; i < MathMin(m_levelCount, 10); i++) // Show top 10 closest levels
        {
            int idx = indices[i];
            double distance = distances[i];
            string arrow = m_keyLevels[idx].price > currentPrice ? "↑" : "↓";
            string type = m_keyLevels[idx].isResistance ? "R" : "S";
            string strength = GetStrengthDescription(m_keyLevels[idx].strength);
            string volumeIcon = m_keyLevels[idx].volumeConfirmed ? "🔊" : "🔇";
            
            LogInfo(StringFormat("│ %s %s %.5f │ %8s │ S:%.3f │ T:%2d │ %4dpips │ %s %s │", 
                   arrow, type, m_keyLevels[idx].price, strength,
                   m_keyLevels[idx].strength, m_keyLevels[idx].touchCount,
                   (int)(distance / _Point), volumeIcon,
                   TimeToString(m_keyLevels[idx].lastTouch, TIME_DATE)));
        }
        
        LogInfo("└" + StringRepeat("─", 78) + "┘");
    }
    
    //+------------------------------------------------------------------+
    //| Enhanced Configuration Methods                                   |
    //+------------------------------------------------------------------+
    void SetDebugMode(bool enabled) 
    { 
        m_showDebugPrints = enabled; 
        LogInfo(StringFormat("🐛 Debug mode %s", enabled ? "ENABLED" : "DISABLED"));
    }
    
    bool GetDebugMode() const { return m_showDebugPrints; }
    
    void SetMinStrength(double strength)
    {
        if(strength >= 0.1 && strength <= 1.0)
        {
            m_minStrength = strength;
            LogInfo(StringFormat("🎯 Minimum strength updated to %.3f", strength));
        }
    }
    
    double GetMinStrength() const { return m_minStrength; }
    
    void SetAdvancedValidation(bool enabled)
    {
        m_useAdvancedValidation = enabled;
        LogInfo(StringFormat("🔬 Advanced validation %s", enabled ? "ENABLED" : "DISABLED"));
    }
    
    bool GetAdvancedValidation() const { return m_useAdvancedValidation; }
    
    //+------------------------------------------------------------------+
    //| Enterprise Diagnostic Methods                                    |
    //+------------------------------------------------------------------+
    void PrintDiagnosticReport()
    {
        if(!m_showDebugPrints) return;
        
        LogInfo("┌" + StringRepeat("─", 60) + "┐");
        LogInfo("│" + StringFormat("%58s", "🔧 SYSTEM DIAGNOSTICS") + " │");
        LogInfo("├" + StringRepeat("─", 60) + "┤");
        LogInfo(StringFormat("│ Chart Objects Created: %8d │ Failed: %8d │", 
               m_diagnostics.totalObjectsCreated, m_diagnostics.totalObjectsFailed));
        LogInfo(StringFormat("│ Objects Verified: %11d │ Success Rate: %5.1f%% │", 
               m_diagnostics.totalObjectsVerified, 
               GetSuccessRate()));
        LogInfo(StringFormat("│ Total Calculations: %9d │ Avg Time: %7.2fms │", 
               m_totalCalculations, m_avgCalculationTime));
        LogInfo(StringFormat("│ Last Update: %20s │ Status: %8s │", 
               m_lastUpdate > 0 ? TimeToString(m_lastUpdate, TIME_DATE|TIME_MINUTES) : "Never",
               GetSystemStatus()));
        LogInfo("└" + StringRepeat("─", 60) + "┘");
    }
    
    void ForceChartUpdate()
    {
        LogInfo("🔄 Forcing immediate enhanced chart update...");
        m_lastChartUpdate = 0; // Reset throttle
        
        if(m_levelCount > 0)
        {
            UpdateEnhancedChartDisplay();
            LogInfo("✅ Forced chart update completed");
        }
        else
        {
            LogInfo("⚠️ No key levels to display");
        }
    }
    
    void ClearAllChartObjects()
    {
        int deletedCount = ObjectsDeleteAll(m_chartID, CHART_OBJECT_PREFIX);
        ArrayFree(m_chartLines);
        
        if(deletedCount > 0)
        {
            LogInfo(StringFormat("🗑️ Cleared %d chart objects", deletedCount));
        }
        
        ChartRedraw(m_chartID);
    }
    
    datetime GetLastUpdateTime() const { return m_lastUpdate; }
    
private:
    //+------------------------------------------------------------------+
    //| Enhanced Private Helper Methods                                  |
    //+------------------------------------------------------------------+
    
    // Enhanced touch zone calculation with intelligent defaults
    double GetEnhancedTouchZone(double providedTouchZone)
    {
        // Respect user's provided touch zone if it's reasonable
        if(providedTouchZone > 0 && providedTouchZone <= 1.0)
        {
            LogInfo(StringFormat("✅ Using provided touch zone: %.5f", providedTouchZone));
            return providedTouchZone;
        }
        
        double touchZone;
        bool isUS500 = (StringFind(_Symbol, "US500") >= 0 || StringFind(_Symbol, "SPX") >= 0);
        
        if(isUS500)
        {
            switch(_Period)
            {
                case PERIOD_MN1: touchZone = 80.0; break;
                case PERIOD_W1:  touchZone = 50.0; break;
                case PERIOD_D1:  touchZone = 30.0; break;
                case PERIOD_H4:  touchZone = 20.0; break;
                case PERIOD_H1:  touchZone = 12.0; break;
                case PERIOD_M30: touchZone = 8.0;  break;
                case PERIOD_M15: touchZone = 5.0;  break;
                case PERIOD_M5:  touchZone = 3.0;  break;
                case PERIOD_M1:  touchZone = 2.0;  break;
                default:         touchZone = 10.0; break;
            }
            LogInfo(StringFormat("📊 US500 auto-adjusted touch zone: %.1f points", touchZone));
        }
        else
        {
            // Enhanced forex touch zones with better granularity
            switch(_Period)
            {
                case PERIOD_MN1: touchZone = 0.0300; break;
                case PERIOD_W1:  touchZone = 0.0150; break;
                case PERIOD_D1:  touchZone = 0.0080; break;
                case PERIOD_H4:  touchZone = 0.0050; break;
                case PERIOD_H2:  touchZone = 0.0035; break;
                case PERIOD_H1:  touchZone = 0.0025; break;
                case PERIOD_M30: touchZone = 0.0015; break;
                case PERIOD_M15: touchZone = 0.0010; break;
                case PERIOD_M5:  touchZone = 0.0007; break;
                case PERIOD_M1:  touchZone = 0.0005; break;
                default:         touchZone = 0.0010; break;
            }
            LogInfo(StringFormat("💱 Forex auto-adjusted touch zone: %.5f (%.1f pips)", 
                   touchZone, touchZone/_Point));
        }
        
        return touchZone;
    }
    
    // Enhanced swing high detection with slope validation
    bool IsEnhancedSwingHigh(const double &highs[], const double &lows[], int index)
    {
        int size = ArraySize(highs);
        if(index < 3 || index >= size - 3) return false;
        
        // Basic pattern validation (6-point instead of 4-point)
        bool basicPattern = highs[index] > highs[index-1] && 
                          highs[index] > highs[index-2] &&
                          highs[index] > highs[index-3] &&
                          highs[index] > highs[index+1] && 
                          highs[index] > highs[index+2] &&
                          highs[index] > highs[index+3];
        
        if(!basicPattern) return false;
        
        if(m_useAdvancedValidation)
        {
            // Advanced slope consistency validation
            double leftSlopes[3];
            double rightSlopes[3];
            
            for(int i = 0; i < 3; i++)
            {
                leftSlopes[i] = highs[index-i] - highs[index-i-1];
                rightSlopes[i] = highs[index+i] - highs[index+i+1];
            }
            
            // Validate slope consistency
            bool validLeftSlopes = true;
            bool validRightSlopes = true;
            
            for(int i = 0; i < 3; i++)
            {
                if(leftSlopes[i] <= 0) validLeftSlopes = false;
                if(rightSlopes[i] <= 0) validRightSlopes = false;
            }
            
            if(!validLeftSlopes || !validRightSlopes) return false;
            
            // Enhanced height validation with dynamic thresholds
            double minHeight = GetDynamicMinHeight();
            double leftHeight = highs[index] - MathMin(MathMin(highs[index-1], highs[index-2]), highs[index-3]);
            double rightHeight = highs[index] - MathMin(MathMin(highs[index+1], highs[index+2]), highs[index+3]);
            
            if(leftHeight < minHeight || rightHeight < minHeight) return false;
            
            // Window-based validation - ensure it's the highest in a wider window
            int windowSize = GetValidationWindowSize();
            int startIdx = MathMax(0, index - windowSize);
            int endIdx = MathMin(size - 1, index + windowSize);
            
            for(int i = startIdx; i <= endIdx; i++)
            {
                if(i != index && highs[i] > highs[index])
                    return false;
            }
        }
        
        return true;
    }
    
    // Enhanced swing low detection with slope validation
    bool IsEnhancedSwingLow(const double &lows[], const double &highs[], int index)
    {
        int size = ArraySize(lows);
        if(index < 3 || index >= size - 3) return false;
        
        // Basic pattern validation (6-point instead of 4-point)
        bool basicPattern = lows[index] < lows[index-1] && 
                          lows[index] < lows[index-2] &&
                          lows[index] < lows[index-3] &&
                          lows[index] < lows[index+1] && 
                          lows[index] < lows[index+2] &&
                          lows[index] < lows[index+3];
        
        if(!basicPattern) return false;
        
        if(m_useAdvancedValidation)
        {
            // Advanced slope consistency validation
            double leftSlopes[3];
            double rightSlopes[3];
            
            for(int i = 0; i < 3; i++)
            {
                leftSlopes[i] = lows[index-i] - lows[index-i-1];
                rightSlopes[i] = lows[index+i] - lows[index+i+1];
            }
            
            // Validate slope consistency
            bool validLeftSlopes = true;
            bool validRightSlopes = true;
            
            for(int i = 0; i < 3; i++)
            {
                if(leftSlopes[i] <= 0) validLeftSlopes = false;
                if(rightSlopes[i] <= 0) validRightSlopes = false;
            }
            
            if(!validLeftSlopes || !validRightSlopes) return false;
            
            // Enhanced height validation with dynamic thresholds
            double minHeight = GetDynamicMinHeight();
            double leftHeight = MathMax(MathMax(lows[index-1], lows[index-2]), lows[index-3]) - lows[index];
            double rightHeight = MathMax(MathMax(lows[index+1], lows[index+2]), lows[index+3]) - lows[index];
            
            if(leftHeight < minHeight || rightHeight < minHeight) return false;
            
            // Window-based validation - ensure it's the lowest in a wider window
            int windowSize = GetValidationWindowSize();
            int startIdx = MathMax(0, index - windowSize);
            int endIdx = MathMin(size - 1, index + windowSize);
            
            for(int i = startIdx; i <= endIdx; i++)
            {
                if(i != index && lows[i] < lows[index])
                    return false;
            }
        }
        
        return true;
    }
    
    // Simple traditional swing detection for fallback
    bool IsSimpleSwingHigh(const double &highs[], int index)
    {
        int size = ArraySize(highs);
        if(index < 1 || index >= size - 1) return false;
        
        // Traditional 2-point swing high: higher than previous and next bar
        return (highs[index] > highs[index-1] && highs[index] > highs[index+1]);
    }
    
    bool IsSimpleSwingLow(const double &lows[], int index)
    {
        int size = ArraySize(lows);
        if(index < 1 || index >= size - 1) return false;
        
        // Traditional 2-point swing low: lower than previous and next bar
        return (lows[index] < lows[index-1] && lows[index] < lows[index+1]);
    }
    
    // Enhanced touch counting with consecutive touch prevention and quality analysis
    int CountEnhancedTouches(double level, bool isResistance, const double &highs[], 
                           const double &lows[], const datetime &times[], STouchQuality &quality)
    {
        // Initialize quality metrics
        quality.touchCount = 0;
        quality.avgBounceStrength = 0;
        quality.avgBounceVolume = 0;
        quality.maxBounceSize = 0;
        quality.quickestBounce = INT_MAX;
        quality.slowestBounce = 0;
        quality.bounceConsistency = 0;
        quality.touchSpacing = 0;
        quality.consecutiveTouches = 0;
        quality.cleanBounces = true;
        
        int touches = 0;
        double totalBounceStrength = 0;
        double totalTouchSpacing = 0;
        double minBounceDistance = m_touchZone * 0.4; // Increased threshold
        double minTouchSpacing = m_touchZone * 0.25;  // Minimum spacing between touches
        
        int lastValidTouchBar = -1;
        int consecutiveTouchCount = 0;
        
        for(int i = 0; i < m_lookbackPeriod - m_maxBounceDelay; i++)
        {
            if(i >= ArraySize(highs) || i >= ArraySize(lows)) break;
            
            double currentPrice = isResistance ? highs[i] : lows[i];
            double touchDistance = MathAbs(currentPrice - level);
            
            if(touchDistance <= m_touchZone)
            {
                // Check spacing from last valid touch to prevent consecutive touches
                bool validSpacing = true;
                if(lastValidTouchBar >= 0)
                {
                    double spacing = MathAbs(i - lastValidTouchBar);
                    if(spacing < 3) // Minimum 3 bars between touches
                    {
                        consecutiveTouchCount++;
                        if(consecutiveTouchCount > 2) // Allow max 2 consecutive touches
                        {
                            validSpacing = false;
                        }
                    }
                    else
                    {
                        consecutiveTouchCount = 0;
                        totalTouchSpacing += spacing;
                    }
                }
                
                if(validSpacing)
                {
                    // Enhanced bounce detection with clean bounce validation
                    double extremePrice = currentPrice;
                    int bounceBar = 0;
                    bool cleanBounce = true;
                    
                    // Find the bounce
                    for(int j = 1; j <= m_maxBounceDelay && (i+j) < ArraySize(highs) && (i+j) < ArraySize(lows); j++)
                    {
                        double price = isResistance ? lows[i+j] : highs[i+j];
                        if(isResistance ? (price < extremePrice) : (price > extremePrice))
                        {
                            extremePrice = price;
                            bounceBar = j;
                        }
                    }
                    
                    // Verify clean bounce (no re-test during bounce)
                    for(int j = 1; j < bounceBar && (i+j) < ArraySize(highs) && (i+j) < ArraySize(lows); j++)
                    {
                        double checkPrice = isResistance ? highs[i+j] : lows[i+j];
                        double retestDistance = MathAbs(checkPrice - level);
                        if(retestDistance <= m_touchZone * 0.8) // 80% of touch zone
                        {
                            cleanBounce = false;
                            break;
                        }
                    }
                    
                    double bounceSize = MathAbs(currentPrice - extremePrice);
                    if(bounceSize >= minBounceDistance && cleanBounce)
                    {
                        touches++;
                        lastValidTouchBar = i;
                        totalBounceStrength += bounceSize / _Point;
                        
                        // Update quality metrics
                        quality.maxBounceSize = MathMax(quality.maxBounceSize, bounceSize);
                        quality.quickestBounce = MathMin(quality.quickestBounce, bounceBar);
                        quality.slowestBounce = MathMax(quality.slowestBounce, bounceBar);
                    }
                    else if(!cleanBounce)
                    {
                        quality.cleanBounces = false;
                    }
                }
            }
        }
        
        // Calculate final quality metrics
        if(touches > 0)
        {
            quality.touchCount = touches;
            quality.avgBounceStrength = totalBounceStrength / touches;
            quality.consecutiveTouches = consecutiveTouchCount;
            
            if(touches > 1)
            {
                quality.touchSpacing = totalTouchSpacing / (touches - 1);
            }
            
            // Calculate bounce consistency
            if(quality.maxBounceSize > 0)
            {
                quality.bounceConsistency = quality.avgBounceStrength / (quality.maxBounceSize / _Point);
            }
        }
        
        return touches;
    }
    
    // Enhanced strength calculation with multiple factors
    double CalculateEnhancedStrength(const SKeyLevel &level, const STouchQuality &quality)
    {
        // Base strength from touch count (enhanced scale)
        double touchBase = 0.45; // Lower starting point
        switch(level.touchCount)
        {
            case 2: touchBase = 0.45; break;
            case 3: touchBase = 0.65; break;
            case 4: touchBase = 0.80; break;
            case 5: touchBase = 0.88; break;
            case 6: touchBase = 0.92; break;
            default: touchBase = MathMin(0.94 + ((level.touchCount - 7) * 0.005), 0.97);
        }
        
        // Enhanced recency modifier
        int periodMinutes = PeriodSeconds(Period()) / 60;
        double barsElapsed = (double)(TimeCurrent() - level.lastTouch) / (periodMinutes * 60);
        double recencyMod = 0;
        
        if(barsElapsed <= m_lookbackPeriod / 10)      // Very recent
            recencyMod = 0.35;
        else if(barsElapsed <= m_lookbackPeriod / 6)  // Recent
            recencyMod = 0.25;
        else if(barsElapsed <= m_lookbackPeriod / 4)  // Moderately recent
            recencyMod = 0.15;
        else if(barsElapsed <= m_lookbackPeriod / 2)  // Within half lookback
            recencyMod = 0.05;
        else if(barsElapsed <= m_lookbackPeriod)      // Within lookback
            recencyMod = 0;
        else                                          // Old
            recencyMod = -0.65;
        
        // Enhanced duration bonus
        double barsDuration = (double)(level.lastTouch - level.firstTouch) / (periodMinutes * 60);
        double durationMod = 0;
        
        if(barsDuration >= m_lookbackPeriod * 0.8)      // Very long-lasting
            durationMod = 0.40;
        else if(barsDuration >= m_lookbackPeriod * 0.6) // Long-lasting
            durationMod = 0.30;
        else if(barsDuration >= m_lookbackPeriod / 3)   // Medium duration
            durationMod = 0.20;
        else if(barsDuration >= m_lookbackPeriod / 6)   // Short duration
            durationMod = 0.10;
        
        // Enhanced quality bonus based on multiple factors
        double qualityBonus = 0;
        
        // Bounce consistency bonus
        qualityBonus += quality.bounceConsistency * 0.12;
        
        // Clean bounces bonus
        if(quality.cleanBounces)
            qualityBonus += 0.08;
        
        // Touch spacing bonus (well-distributed touches)
        if(quality.touchSpacing > 5)
            qualityBonus += 0.06;
        
        // Bounce speed bonus
        if(quality.quickestBounce < INT_MAX && quality.slowestBounce > 0)
        {
            double avgBounceSpeed = (double)(quality.quickestBounce + quality.slowestBounce) / 2.0;
            double speedBonus = 1.0 - (avgBounceSpeed / m_maxBounceDelay);
            qualityBonus += speedBonus * 0.05;
        }
        
        // Timeframe relevance bonus
        double timeframeBonus = GetTimeframeRelevanceBonus();
        
        // Volume confirmation bonus (applied separately)
        double volumeBonus = level.volumeConfirmed ? 0.08 : 0;
        
        // Calculate final strength with all modifiers
        double strength = touchBase * (1.0 + recencyMod + durationMod + qualityBonus + timeframeBonus + volumeBonus);
        
        // Add small random variation to prevent identical strengths
        strength += 0.0002 * MathMod((int)(level.price * 100000), 10) / 10;
        
        return MathMin(MathMax(strength, 0.40), 0.99);
    }
    
    // Enhanced chart line creation with advanced visual properties
    bool CreateEnhancedChartLine(const SKeyLevel &level, double currentPrice, datetime currentTime, int index)
    {
        string lineName = StringFormat("%s%s_%.5f_%d_%d", 
            CHART_OBJECT_PREFIX,
            level.isResistance ? "R" : "S",
            level.price,
            currentTime,
            index);
        
        // Determine sophisticated visual properties
        bool isAbovePrice = level.price > currentPrice;
        color lineColor = GetEnhancedLineColor(level, isAbovePrice);
        int lineWidth = GetDynamicLineWidth(level.strength);
        ENUM_LINE_STYLE lineStyle = GetIntelligentLineStyle(level);
        int transparency = GetDynamicTransparency(level, currentPrice);
        
        // Create chart object with enhanced error handling
        if(!ObjectCreate(m_chartID, lineName, OBJ_HLINE, 0, 0, level.price))
        {
            int error = GetLastError();
            LogError(StringFormat("Chart object creation failed: %s (Error: %d)", lineName, error));
            return false;
        }
        
        // Set enhanced properties with validation
        bool success = true;
        success &= ObjectSetInteger(m_chartID, lineName, OBJPROP_COLOR, lineColor);
        success &= ObjectSetInteger(m_chartID, lineName, OBJPROP_STYLE, lineStyle);
        success &= ObjectSetInteger(m_chartID, lineName, OBJPROP_WIDTH, lineWidth);
        success &= ObjectSetInteger(m_chartID, lineName, OBJPROP_BACK, false);
        success &= ObjectSetInteger(m_chartID, lineName, OBJPROP_SELECTABLE, false);
        success &= ObjectSetInteger(m_chartID, lineName, OBJPROP_HIDDEN, false);
        success &= ObjectSetInteger(m_chartID, lineName, OBJPROP_RAY_RIGHT, true);
        success &= ObjectSetInteger(m_chartID, lineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        
        if(!success)
        {
            LogError(StringFormat("Failed to set properties for: %s", lineName));
            ObjectDelete(m_chartID, lineName);
            return false;
        }
        
        // Create enhanced tooltip with comprehensive information
        string tooltip = CreateEnhancedTooltip(level, currentPrice);
        ObjectSetString(m_chartID, lineName, OBJPROP_TOOLTIP, tooltip);
        
        // Add to tracking array
        m_chartLines[index].name = lineName;
        m_chartLines[index].price = level.price;
        m_chartLines[index].lastUpdate = currentTime;
        m_chartLines[index].lineColor = lineColor;
        m_chartLines[index].isActive = true;
        m_chartLines[index].lineWidth = lineWidth;
        m_chartLines[index].lineStyle = lineStyle;
        m_chartLines[index].isVerified = true;
        m_chartLines[index].strength = level.strength;
        m_chartLines[index].transparency = transparency;
        
        return true;
    }
    
    // Enhanced color scheme with gradient support
    color GetEnhancedLineColor(const SKeyLevel &level, bool isAbovePrice)
    {
        color baseColor;
        
        // Determine base color by position and type
        if(level.isResistance)
        {
            // All resistance levels should use red color scheme for consistency
            if(level.strength >= 0.90)      baseColor = clrDarkRed;     // Strongest resistance - dark red
            else if(level.strength >= 0.80) baseColor = clrRed;         // Strong resistance - red
            else if(level.strength >= 0.70) baseColor = clrCrimson;     // Medium-strong resistance - crimson
            else if(level.strength >= 0.60) baseColor = clrOrangeRed;   // Medium resistance - orange-red
            else                            baseColor = clrIndianRed;    // Weak resistance - indian red
            
            // Debug validation for 15-minute timeframe
            if(m_showDebugPrints && Period() == PERIOD_M15)
            {
                LogInfo(StringFormat("🔴 RESISTANCE %.5f: Strength=%.3f, Color=%s, AbovePrice=%s", 
                    level.price, level.strength, 
                    (baseColor == clrDarkRed ? "DarkRed" : baseColor == clrRed ? "Red" : "Other"), 
                    isAbovePrice ? "YES" : "NO"));
            }
        }
        else // Support
        {
            // Support levels use green color scheme
            if(level.strength >= 0.90)      baseColor = clrDarkGreen;   // Strongest support
            else if(level.strength >= 0.80) baseColor = clrGreen;       // Strong support
            else if(level.strength >= 0.70) baseColor = clrLimeGreen;   // Medium-strong support
            else if(level.strength >= 0.60) baseColor = clrSeaGreen;    // Medium support
            else                            baseColor = clrCadetBlue;    // Weak support
        }
        
        // Add volume confirmation accent
        if(level.volumeConfirmed && level.volumeRatio > 1.5)
        {
            // Brighten color for volume-confirmed levels using MQL5 color manipulation
            uint argb = ColorToARGB(baseColor, 255);
            int r = (int)((argb & 0x00FF0000) >> 16);
            int g = (int)((argb & 0x0000FF00) >> 8);
            int b = (int)(argb & 0x000000FF);
            
            r = MathMin(255, (int)(r * 1.2));
            g = MathMin(255, (int)(g * 1.2));
            b = MathMin(255, (int)(b * 1.2));
            
            // Create color from RGB components
            baseColor = (color)((r << 16) | (g << 8) | b);
        }
        
        return baseColor;
    }
    
    // Dynamic line width based on strength
    int GetDynamicLineWidth(double strength)
    {
        if(strength >= 0.90)      return 5;
        else if(strength >= 0.80) return 4;
        else if(strength >= 0.70) return 3;
        else if(strength >= 0.60) return 2;
        else                      return 1;
    }
    
    // Intelligent line style based on level characteristics
    ENUM_LINE_STYLE GetIntelligentLineStyle(const SKeyLevel &level)
    {
        if(level.volumeConfirmed && level.strength >= 0.80)
            return STYLE_SOLID;        // Strongest levels - solid line
        else if(level.strength >= 0.70)
            return STYLE_SOLID;        // Strong levels - solid line
        else if(level.strength >= 0.60)
            return STYLE_DASH;         // Medium levels - dashed line
        else
            return STYLE_DOT;          // Weaker levels - dotted line
    }
    
    // Dynamic transparency based on distance and recency
    int GetDynamicTransparency(const SKeyLevel &level, double currentPrice)
    {
        double distance = MathAbs(level.price - currentPrice);
        double normalizedDistance = distance / (m_touchZone * 20); // Normalize to 20x touch zone
        
        // Base transparency on distance
        int transparency = (int)(normalizedDistance * 30); // 0-30% based on distance
        
        // Adjust for recency
        datetime currentTime = TimeCurrent();
        double hoursElapsed = (double)(currentTime - level.lastTouch) / 3600.0;
        
        if(hoursElapsed > 168) // More than a week old
            transparency += 20;
        else if(hoursElapsed > 24) // More than a day old
            transparency += 10;
        
        return MathMin(transparency, 70); // Max 70% transparency
    }
    
    // Create comprehensive tooltip
    string CreateEnhancedTooltip(const SKeyLevel &level, double currentPrice)
    {
        double distance = MathAbs(level.price - currentPrice);
        string levelType = level.isResistance ? "🔴 RESISTANCE" : "🟢 SUPPORT";
        string strengthDesc = GetStrengthDescription(level.strength);
        string volumeIcon = level.volumeConfirmed ? "🔊" : "🔇";
        
        // Handle invalid/uninitialized datetime values
        string firstTouchStr = (level.firstTouch > 0) ? TimeToString(level.firstTouch, TIME_DATE|TIME_MINUTES) : "Not Available";
        string lastTouchStr = (level.lastTouch > 0) ? TimeToString(level.lastTouch, TIME_DATE|TIME_MINUTES) : "Not Available";
        
        return StringFormat(
            "%s LEVEL\n" +
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
            "💰 Price: %.5f\n" +
            "💪 Strength: %.3f (%s)\n" +
            "👆 Touches: %d\n" +
            "📏 Distance: %d pips\n" +
            "🕐 First Touch: %s\n" +
            "🕐 Last Touch: %s\n" +
            "%s Volume: %.1fx average\n" +
            "📊 Bounce Quality: %.2f\n" +
            "🎯 Slope Score: %.2f",
            levelType,
            level.price,
            level.strength, strengthDesc,
            level.touchCount,
            (int)(distance / _Point),
            firstTouchStr,
            lastTouchStr,
            volumeIcon, level.volumeRatio,
            level.bounceQuality,
            level.slopeConsistency
        );
    }
    
    //+------------------------------------------------------------------+
    //| Utility and Helper Methods                                       |
    //+------------------------------------------------------------------+
    
    bool GetValidatedMarketData(double &highs[], double &lows[], double &closes[], 
                               double &opens[], datetime &times[], long &volumes[])
    {
        ArraySetAsSeries(highs, true);
        ArraySetAsSeries(lows, true);
        ArraySetAsSeries(closes, true);
        ArraySetAsSeries(opens, true);
        ArraySetAsSeries(times, true);
        ArraySetAsSeries(volumes, true);
        
        int barsNeeded = m_lookbackPeriod + 10;
        
        if(CopyHigh(_Symbol, Period(), 0, barsNeeded, highs) <= 0 ||
           CopyLow(_Symbol, Period(), 0, barsNeeded, lows) <= 0 ||
           CopyClose(_Symbol, Period(), 0, barsNeeded, closes) <= 0 ||
           CopyOpen(_Symbol, Period(), 0, barsNeeded, opens) <= 0 ||
           CopyTime(_Symbol, Period(), 0, barsNeeded, times) <= 0 ||
           CopyTickVolume(_Symbol, Period(), 0, barsNeeded, volumes) <= 0)
        {
            return false;
        }
        
        // Validate data integrity including datetime values
        for(int i = 0; i < MathMin(10, ArraySize(highs)); i++)
        {
            if(highs[i] <= 0 || lows[i] <= 0 || highs[i] < lows[i])
            {
                LogError(StringFormat("Invalid price data at index %d: H=%.5f, L=%.5f", i, highs[i], lows[i]));
                return false;
            }
            
            // Validate datetime values
            if(times[i] <= 0)
            {
                LogError(StringFormat("Invalid datetime at index %d: %s", i, TimeToString(times[i])));
                return false;
            }
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Level Classification Correction Methods                          |
    //+------------------------------------------------------------------+
    void ReclassifyLevelsBasedOnCurrentPrice(double currentPrice)
    {
        int reclassified = 0;
        
        for(int i = 0; i < m_levelCount; i++)
        {
            bool shouldBeResistance = (m_keyLevels[i].price > currentPrice);
            
            if(m_keyLevels[i].isResistance != shouldBeResistance)
            {
                string oldType = m_keyLevels[i].isResistance ? "RESISTANCE" : "SUPPORT";
                string newType = shouldBeResistance ? "RESISTANCE" : "SUPPORT";
                
                if(m_showDebugPrints)
                {
                    LogInfo(StringFormat("🔄 Reclassifying level %.5f: %s → %s (Current price: %.5f)", 
                        m_keyLevels[i].price, oldType, newType, currentPrice));
                }
                
                m_keyLevels[i].isResistance = shouldBeResistance;
                reclassified++;
            }
        }
        
        if(reclassified > 0)
        {
            LogInfo(StringFormat("✅ Reclassified %d levels based on current price %.5f", reclassified, currentPrice));
        }
        
        // Validate all levels after reclassification
        if(m_showDebugPrints && Period() == PERIOD_M15)
        {
            LogInfo("🔍 Post-reclassification validation:");
            for(int i = 0; i < m_levelCount; i++)
            {
                bool isCorrect = (m_keyLevels[i].isResistance && m_keyLevels[i].price > currentPrice) ||
                               (!m_keyLevels[i].isResistance && m_keyLevels[i].price < currentPrice);
                
                LogInfo(StringFormat("  Level %d: %.5f %s %s", 
                    i, m_keyLevels[i].price,
                    m_keyLevels[i].isResistance ? "RESISTANCE" : "SUPPORT",
                    isCorrect ? "✅" : "❌"));
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Enhanced Validation Methods                                      |
    //+------------------------------------------------------------------+
    bool ValidateKeyLevelData(const SKeyLevel &level, int index = -1)
    {
        bool isValid = true;
        string prefix = (index >= 0) ? StringFormat("[Level %d] ", index) : "";
        
        // Validate price
        if(level.price <= 0)
        {
            LogError(StringFormat("%sInvalid price: %.5f", prefix, level.price));
            isValid = false;
        }
        
        // Validate datetime values
        if(level.firstTouch <= 0)
        {
            LogError(StringFormat("%sInvalid firstTouch: %s (timestamp: %d)", 
                prefix, TimeToString(level.firstTouch), (int)level.firstTouch));
            isValid = false;
        }
        
        if(level.lastTouch <= 0)
        {
            LogError(StringFormat("%sInvalid lastTouch: %s (timestamp: %d)", 
                prefix, TimeToString(level.lastTouch), (int)level.lastTouch));
            isValid = false;
        }
        
        // Validate touch count
        if(level.touchCount <= 0)
        {
            LogError(StringFormat("%sInvalid touchCount: %d", prefix, level.touchCount));
            isValid = false;
        }
        
        // Log level type validation for 15-minute timeframe
        if(m_showDebugPrints && Period() == PERIOD_M15)
        {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            bool shouldBeResistance = (level.price > currentPrice);
            
            if(level.isResistance != shouldBeResistance)
            {
                LogError(StringFormat("%s⚠️  Type mismatch: Level %.5f marked as %s but price %.5f suggests %s", 
                    prefix, level.price, 
                    level.isResistance ? "RESISTANCE" : "SUPPORT",
                    currentPrice,
                    shouldBeResistance ? "RESISTANCE" : "SUPPORT"));
            }
            else
            {
                LogInfo(StringFormat("%s✅ %s %.5f correctly identified (current: %.5f)", 
                    prefix, level.isResistance ? "RESISTANCE" : "SUPPORT", 
                    level.price, currentPrice));
            }
        }
        
        return isValid;
    }
    
    SKeyLevel CreateKeyLevel(double price, bool isResistance, datetime firstTouch)
    {
        SKeyLevel level;
        level.price = price;
        level.isResistance = isResistance;
        level.touchCount = 1;
        level.strength = 0.0;
        
        // Validate and set first touch - use current time if invalid
        if(firstTouch <= 0)
        {
            firstTouch = TimeCurrent();
            if(m_showDebugPrints)
            {
                LogError(StringFormat("Invalid firstTouch time for level %.5f, using current time: %s", 
                    price, TimeToString(firstTouch, TIME_DATE|TIME_MINUTES)));
            }
        }
        
        level.firstTouch = firstTouch;
        level.lastTouch = firstTouch;
        level.volumeConfirmed = false;
        level.volumeRatio = 1.0;
        level.slopeConsistency = 0.0;
        level.bounceQuality = 0.0;
        level.timeframeRelevance = 0;
        return level;
    }
    
    void ApplyVolumeEnhancements(SKeyLevel &level, const long &volumes[], int index)
    {
        if(index >= 0 && index < ArraySize(volumes))
        {
            double avgVolume = GetAverageVolume(volumes, index, VOLUME_LOOKBACK_BARS);
            if(avgVolume > 0)
            {
                level.volumeRatio = (double)volumes[index] / avgVolume;
                
                if(level.volumeRatio >= VOLUME_SPIKE_MULTIPLIER)
                {
                    level.volumeConfirmed = true;
                    double volumeBonus = MathMin((level.volumeRatio - 1.0) * 0.1, VOLUME_STRENGTH_MAX_BONUS);
                    level.strength = MathMin(level.strength * (1.0 + volumeBonus), 0.98);
                }
            }
        }
    }
    
    double CalculateSlopeConsistency(const double &prices[], int index)
    {
        if(index < 3 || index >= ArraySize(prices) - 3) return 0.0;
        
        double leftSlopes[3];
        double rightSlopes[3];
        
        for(int i = 0; i < 3; i++)
        {
            leftSlopes[i] = prices[index-i] - prices[index-i-1];
            rightSlopes[i] = prices[index+i] - prices[index+i+1];
        }
        
        // Calculate slope consistency (lower variance = higher consistency)
        double leftVariance = CalculateVariance(leftSlopes, 3);
        double rightVariance = CalculateVariance(rightSlopes, 3);
        
        return 1.0 / (1.0 + leftVariance + rightVariance);
    }
    
    double CalculateVariance(const double &values[], int count)
    {
        if(count <= 1) return 0.0;
        
        double sum = 0;
        for(int i = 0; i < count; i++)
        {
            sum += values[i];
        }
        double mean = sum / count;
        
        double variance = 0;
        for(int i = 0; i < count; i++)
        {
            variance += MathPow(values[i] - mean, 2);
        }
        
        return variance / count;
    }
    
    void OptimizeKeyLevels()
    {
        if(m_levelCount <= MAX_LEVELS_PER_TYPE * 2) return;
        
        // Sort levels by strength
        for(int i = 0; i < m_levelCount - 1; i++)
        {
            for(int j = i + 1; j < m_levelCount; j++)
            {
                if(m_keyLevels[i].strength < m_keyLevels[j].strength)
                {
                    SKeyLevel temp = m_keyLevels[i];
                    m_keyLevels[i] = m_keyLevels[j];
                    m_keyLevels[j] = temp;
                }
            }
        }
        
        // Keep only the strongest levels
        int newCount = MathMin(m_levelCount, MAX_LEVELS_PER_TYPE * 2);
        m_levelCount = newCount;
        
        LogInfo(StringFormat("🔧 Optimized to %d strongest levels", newCount));
    }
    
    void SortLevelsByStrength()
    {
        // Simple bubble sort by strength (descending)
        for(int i = 0; i < m_levelCount - 1; i++)
        {
            for(int j = 0; j < m_levelCount - 1 - i; j++)
            {
                if(m_keyLevels[j].strength < m_keyLevels[j + 1].strength)
                {
                    SKeyLevel temp = m_keyLevels[j];
                    m_keyLevels[j] = m_keyLevels[j + 1];
                    m_keyLevels[j + 1] = temp;
                }
            }
        }
    }
    
    bool IsNearExistingLevel(double price)
    {
        double adjustedTouchZone = m_touchZone;
        
        // Adjust touch zone based on timeframe for level spacing
        switch(Period())
        {
            case PERIOD_MN1: adjustedTouchZone *= 2.5; break;
            case PERIOD_W1:  adjustedTouchZone *= 2.0; break;
            case PERIOD_D1:  adjustedTouchZone *= 1.5; break;
            case PERIOD_H4:  adjustedTouchZone *= 1.2; break;
        }
        
        for(int i = 0; i < m_levelCount; i++)
        {
            if(MathAbs(price - m_keyLevels[i].price) <= adjustedTouchZone)
                return true;
        }
        return false;
    }
    
    void AddKeyLevel(const SKeyLevel &level)
    {
        // Validate key level data before adding
        if(!ValidateKeyLevelData(level, m_levelCount))
        {
            LogError(StringFormat("❌ Skipping invalid key level at price %.5f", level.price));
            return;
        }
        
        if(m_levelCount >= ArraySize(m_keyLevels))
        {
            ArrayResize(m_keyLevels, m_levelCount + 100);
        }
        
        m_keyLevels[m_levelCount] = level;
        m_levelCount++;
        
        // Log successful addition for 15-minute timeframe debugging
        if(m_showDebugPrints && Period() == PERIOD_M15)
        {
            LogInfo(StringFormat("✅ Added %s level: %.5f (Strength: %.3f, First Touch: %s)", 
                level.isResistance ? "RESISTANCE" : "SUPPORT",
                level.price, level.strength,
                TimeToString(level.firstTouch, TIME_DATE|TIME_MINUTES)));
        }
    }
    
    double GetDynamicMinHeight()
    {
        switch(Period())
        {
            case PERIOD_MN1: return _Point * 300;
            case PERIOD_W1:  return _Point * 200;
            case PERIOD_D1:  return _Point * 120;
            case PERIOD_H4:  return _Point * 60;
            case PERIOD_H2:  return _Point * 40;
            case PERIOD_H1:  return _Point * 30;
            case PERIOD_M30: return _Point * 20;
            case PERIOD_M15: return _Point * 12;
            case PERIOD_M5:  return _Point * 8;
            case PERIOD_M1:  return _Point * 5;
            default:         return _Point * 15;
        }
    }
    
    int GetValidationWindowSize()
    {
        switch(Period())
        {
            case PERIOD_MN1: return 6;
            case PERIOD_W1:  return 5;
            case PERIOD_D1:  return 5;
            case PERIOD_H4:  return 4;
            case PERIOD_H2:  return 4;
            case PERIOD_H1:  return 3;
            default:         return 3;
        }
    }
    
    double GetTimeframeRelevanceBonus()
    {
        // Higher bonus for higher timeframes
        switch(Period())
        {
            case PERIOD_MN1: return 0.15;
            case PERIOD_W1:  return 0.12;
            case PERIOD_D1:  return 0.10;
            case PERIOD_H4:  return 0.08;
            case PERIOD_H2:  return 0.06;
            case PERIOD_H1:  return 0.04;
            case PERIOD_M30: return 0.02;
            default:         return 0.00;
        }
    }
    
    bool PerformInitializationTests()
    {
        // Test basic array operations
        double testArray[5] = {1.0, 2.0, 3.0, 4.0, 5.0};
        if(ArraySize(testArray) != 5) return false;
        
        // Test chart ID validity
        if(m_chartID < 0) return false;
        
        // Test symbol info access
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(point <= 0) return false;
        
        return true;
    }
    
    void UpdatePerformanceMetrics(uint calculationTime)
    {
        m_totalCalculations++;
        m_avgCalculationTime = ((m_avgCalculationTime * (m_totalCalculations - 1)) + calculationTime) / m_totalCalculations;
        
        // Reset performance metrics daily
        datetime currentTime = TimeCurrent();
        if(currentTime - m_lastPerformanceReset > 86400) // 24 hours
        {
            m_totalCalculations = 1;
            m_avgCalculationTime = calculationTime;
            m_lastPerformanceReset = currentTime;
        }
    }
    
    void ClearAllChartObjectsWithVerification()
    {
        int beforeCount = ObjectsTotal(m_chartID, 0, OBJ_HLINE);
        int deletedCount = ObjectsDeleteAll(m_chartID, CHART_OBJECT_PREFIX);
        int afterCount = ObjectsTotal(m_chartID, 0, OBJ_HLINE);
        
        ArrayFree(m_chartLines);
        
        LogInfo(StringFormat("🗑️ Chart cleanup: %d objects deleted, %d→%d total lines", 
               deletedCount, beforeCount, afterCount));
        
        // Force redraw
        Sleep(100);
        ChartRedraw(m_chartID);
    }
    
    void VerifyChartObjects()
    {
        int verifiedCount = 0;
        int totalExpected = ArraySize(m_chartLines);
        
        for(int i = 0; i < totalExpected; i++)
        {
            if(ObjectFind(m_chartID, m_chartLines[i].name) >= 0)
            {
                verifiedCount++;
                m_chartLines[i].isVerified = true;
            }
            else
            {
                m_chartLines[i].isVerified = false;
            }
        }
        
        m_diagnostics.totalObjectsVerified = verifiedCount;
        
        if(verifiedCount != totalExpected)
        {
            LogError(StringFormat("Chart verification failed: %d/%d objects verified", verifiedCount, totalExpected));
        }
    }
    
    double GetAverageVolume(const long &volumes[], int startIndex, int barsToAverage)
    {
        if(startIndex < 0 || barsToAverage <= 0) return 0.0;
        
        double totalVolume = 0;
        int validBars = 0;
        
        for(int i = 0; i < barsToAverage && (startIndex + i) < ArraySize(volumes); i++)
        {
            totalVolume += (double)volumes[startIndex + i];
            validBars++;
        }
        
        return validBars > 0 ? totalVolume / validBars : 0.0;
    }
    
    string GetStrengthDescription(double strength) const
    {
        if(strength >= 0.90)      return "ULTIMATE";
        else if(strength >= 0.80) return "VERY STRONG";
        else if(strength >= 0.70) return "STRONG";
        else if(strength >= 0.60) return "MODERATE";
        else if(strength >= 0.50) return "WEAK";
        else                      return "VERY WEAK";
    }
    
    double GetSuccessRate() const
    {
        int total = m_diagnostics.totalObjectsCreated + m_diagnostics.totalObjectsFailed;
        if(total == 0) return 100.0;
        return (double)m_diagnostics.totalObjectsCreated / total * 100.0;
    }
    
    string GetSystemStatus() const
    {
        double successRate = GetSuccessRate();
        if(successRate >= 95.0) return "EXCELLENT";
        else if(successRate >= 85.0) return "GOOD";
        else if(successRate >= 70.0) return "OK";
        else return "POOR";
    }
    
    string StringRepeat(string str, int count) const
    {
        string result = "";
        for(int i = 0; i < count; i++)
            result += str;
        return result;
    }
    
    void LogInfo(string message)
    {
        if(!m_showDebugPrints) return;
        
        datetime currentTime = TimeCurrent();
        if(m_logThrottle.lastMessage == message)
        {
            m_logThrottle.duplicateCount++;
            if(currentTime - m_logThrottle.lastDebugMessage < MIN_LOG_INTERVAL_SECONDS)
                return;
            message = StringFormat("%s (x%d)", message, m_logThrottle.duplicateCount);
            m_logThrottle.duplicateCount = 0;
        }
        
        Print("[GRANDE] ", message);
        m_logThrottle.lastDebugMessage = currentTime;
        m_logThrottle.lastMessage = message;
    }
    
    void LogError(string message)
    {
        Print("[GRANDE ERROR] ", message);
        m_diagnostics.lastError = message;
    }
}; 