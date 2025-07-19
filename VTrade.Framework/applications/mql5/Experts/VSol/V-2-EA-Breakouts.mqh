#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.04"

#define VOLUME_SPIKE_MULTIPLIER      2.0
#define VOLUME_LOOKBACK_BARS         20
#define VOLUME_STRENGTH_MAX_BONUS    0.15


#define MIN_LOG_INTERVAL_SECONDS     60
#define MIN_CHART_UPDATE_SECONDS     5
#define MIN_HEALTH_REPORT_SECONDS    1800
#define MIN_LEVEL_REPORT_SECONDS     300
#define MIN_ALERT_INTERVAL_SECONDS   120

#include <Trade\Trade.mqh>
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"
#include "V-2-EA-US500Data.mqh"
#include "V-2-EA-ForexData.mqh"

#define DEFAULT_BUFFER_SIZE 100

struct SStrategyState
{
    bool      keyLevelFound;
    SKeyLevel activeKeyLevel;
    datetime  lastUpdate;
    
    void Reset()
    {
        keyLevelFound = false;
        lastUpdate = 0;
    }
};



struct SChartLine
{
    string name;
    double price;
    datetime lastUpdate;
    color lineColor;
    bool isActive;
};

struct STouchQuality 
{
    int touchCount;
    double avgBounceStrength;
    double avgBounceVolume;
    double maxBounceSize;
    int quickestBounce;
    int slowestBounce;
};

struct SLogThrottle
{
    datetime lastDebugMessage;
    datetime lastLevelReport;
    datetime lastHealthReport;
    datetime lastTradeAlert;
    datetime lastChartUpdate;
    string lastMessage;
    int duplicateCount;
    
    void Reset()
    {
        lastDebugMessage = 0;
        lastLevelReport = 0;
        lastHealthReport = 0;
        lastTradeAlert = 0;
        lastChartUpdate = 0;
        lastMessage = "";
        duplicateCount = 0;
    }
};

class CV2EABreakouts : public CV2EAMarketDataBase
{
private:
    bool            m_useVolumeFilter;
    bool            m_ignoreMarketHours;
    ENUM_TIMEFRAMES m_currentTimeframe;
    SLogThrottle    m_logThrottle;
    
    bool IsUS500()
    {
        return (StringFind(_Symbol, "US500") >= 0 || StringFind(_Symbol, "SPX") >= 0);
    }
    
    double GetOptimalTouchZone(double providedTouchZone)
    {
        double touchZone = providedTouchZone;
        
        if(IsUS500())
        {
            switch(_Period)
            {
                case PERIOD_MN1: touchZone = 50.0; break;
                case PERIOD_W1:  touchZone = 30.0; break;
                case PERIOD_D1:  touchZone = 20.0; break;
                case PERIOD_H4:  touchZone = 15.0; break;
                case PERIOD_H1:  touchZone = 10.0; break;
                case PERIOD_M30: touchZone = 7.5;  break;
                case PERIOD_M15: touchZone = 5.0;  break;
                case PERIOD_M5:  touchZone = 3.0;  break;
                case PERIOD_M1:  touchZone = 2.0;  break;
                default:         touchZone = 5.0;  break;
            }
            DebugLog("US500 touch zone set: " + DoubleToString(touchZone, 1));
        }
        else
        {
            if(touchZone == 0 || touchZone > 1.0)
            {
                switch(_Period)
                {
                    case PERIOD_MN1: touchZone = 0.0200; break;
                    case PERIOD_W1:  touchZone = 0.0100; break;
                    case PERIOD_D1:  touchZone = 0.0060; break;
                    case PERIOD_H4:  touchZone = 0.0040; break;
                    case PERIOD_H2:  touchZone = 0.0032; break;
                    case PERIOD_H1:  touchZone = 0.0025; break;
                    case PERIOD_M30: touchZone = 0.0010; break;
                    case PERIOD_M15: touchZone = 0.0007; break;
                    case PERIOD_M5:  touchZone = 0.0005; break;
                    case PERIOD_M1:  touchZone = 0.0003; break;
                    default:         touchZone = 0.0005; break;
                }
                DebugLog(StringFormat("Default forex touch zone: %.5f (%.1f pips)", 
                    touchZone, touchZone/_Point));
            }
            else
            {
                DebugLog(StringFormat("Using provided touch zone: %.5f (%.1f pips)", 
                    touchZone, touchZone/_Point));
            }
        }
        
        return touchZone;
    }
    
    bool InitializeArrays(string context)
    {
        if(!CV2EAUtils::SafeResizeArray(m_currentKeyLevels, DEFAULT_BUFFER_SIZE, context + " - m_currentKeyLevels") ||
           !CV2EAUtils::SafeResizeArray(m_chartLines, DEFAULT_BUFFER_SIZE, context + " - m_chartLines") ||
           !CV2EAUtils::SafeResizeArray(m_lastAlerts, DEFAULT_BUFFER_SIZE, context + " - m_lastAlerts"))
        {
            return false;
        }
        return true;
    }

    int           m_maxBounceDelay;
    SKeyLevel     m_currentKeyLevels[];
    int           m_keyLevelCount;
    datetime      m_lastKeyLevelUpdate;
    SStrategyState m_state;
    bool            m_initialized;
    
    struct SHourlyStats
    {
        int validLevels;
        int rejectedLevels;
        
        void Reset()
        {
            validLevels = 0;
            rejectedLevels = 0;
        }
    } m_hourlyStats;



    struct SAlertTime
    {
        double price;
        datetime lastAlert;
    };
    SAlertTime m_lastAlerts[];
    SChartLine m_chartLines[];
    datetime m_lastChartUpdate;

public:
    CV2EABreakouts(void) : m_initialized(false),
                           m_keyLevelCount(0),
                           m_lastKeyLevelUpdate(0),
                           m_maxBounceDelay(8),
                           m_useVolumeFilter(true),
                           m_ignoreMarketHours(false),
                           m_currentTimeframe(PERIOD_CURRENT)  
    {
        m_logThrottle.Reset();
        
        if(!InitializeArrays("Constructor"))
        {
            ThrottledLogError("Array initialization failed in constructor");
            return;
        }
        
        m_state.Reset();
    }
    
    ~CV2EABreakouts(void)
    {
        ClearAllChartObjects();  // Clean up chart objects before destruction
    }
    
    void ThrottledLog(string message, bool isError = false, bool forceShow = false)
    {
        if(!isError && !forceShow && !m_showDebugPrints) return;
        
        datetime currentTime = TimeCurrent();
        if(m_logThrottle.lastMessage == message)
        {
            m_logThrottle.duplicateCount++;
            if(currentTime - m_logThrottle.lastDebugMessage < MIN_LOG_INTERVAL_SECONDS)
                return;
            message = StringFormat("%s (x%d in last %d seconds)", message, 
                m_logThrottle.duplicateCount, MIN_LOG_INTERVAL_SECONDS);
            m_logThrottle.duplicateCount = 0;
        }
        
        if(isError)
            CV2EAUtils::LogError(message);
        else
            CV2EAUtils::LogInfo(message);
            
        m_logThrottle.lastDebugMessage = currentTime;
        m_logThrottle.lastMessage = message;
    }
    
    void ThrottledLogError(string message) { ThrottledLog(message, true, true); }
    void ThrottledLogInfo(string message) { ThrottledLog(message, false, false); }
    void ThrottledDebugPrint(string message) { ThrottledLog(message, false, false); }
    
    void DebugLog(string message) 
    { 
        if(m_showDebugPrints) CV2EAUtils::LogInfo(message); 
    }  
    void ResetStaticVariables()
    {
        CV2EAUtils::LogInfo("🔄 CRITICAL FIX: Forcing static variable reset for deterministic behavior");
        
        m_lastKeyLevelUpdate = 0;
        m_keyLevelCount = 0;
        m_lastChartUpdate = 0;
        m_hourlyStats.Reset();
        
        CV2EAUtils::LogInfo("🔄 Resetting static variables in data classes...");
        
        ResetUS500DataStatics();
        ResetForexDataStatics();
        
        ArrayFree(m_currentKeyLevels);
        ArrayFree(m_lastAlerts);
        
        if(!InitializeArrays("ResetStaticVariables"))
        {
            CV2EAUtils::LogError("❌ Failed to reinitialize arrays during static reset");
        }
        else
        {
            CV2EAUtils::LogInfo("✅ Static variables reset completed - algorithm should now be deterministic");
        }
    }
    
    bool Init(int lookbackPeriod, double minStrength, double touchZone, int minTouches, bool showDebugPrints, bool useVolumeFilter = true, bool ignoreMarketHours = false)
    {
        int bars = Bars(_Symbol, Period());
        if(bars < lookbackPeriod + 10)
        {
            ThrottledLogError(StringFormat(
                "Not enough historical data loaded. Need at least %d bars, got %d", 
                lookbackPeriod + 10, bars));
            return false;
        }

        if(minStrength <= 0.0 || minStrength > 1.0)
        {
            CV2EAUtils::LogError("Invalid minStrength", minStrength);
            minStrength = 0.55;
        }
        if(minTouches < 1)
        {
            CV2EAUtils::LogError("Invalid minTouches", minTouches);
            minTouches = 2;
        }
        
        m_useVolumeFilter = useVolumeFilter;
        m_ignoreMarketHours = ignoreMarketHours;
        m_currentTimeframe = Period();  // Initialize current timeframe
        
        // Set appropriate touch zone for market type
        touchZone = GetOptimalTouchZone(touchZone);
        
        m_touchZone = touchZone;
        
        m_minStrength = minStrength;
        m_minTouches = minTouches;
        m_showDebugPrints = showDebugPrints;
        
        ENUM_TIMEFRAMES tf = Period();
        int periodMinutes = PeriodSeconds(tf) / 60;
        
        if(lookbackPeriod == 0)
        {
            // Set default lookback period based on timeframe
            switch(tf)
            {
                case PERIOD_MN1: m_lookbackPeriod = 36;   break;  // 3 years of monthly data
                case PERIOD_W1:  m_lookbackPeriod = 52;   break;  // ~1 year of weekly data
                case PERIOD_D1:  m_lookbackPeriod = 90;   break;  // ~3 months
                case PERIOD_H4:  m_lookbackPeriod = 180;  break;  // ~30 days
                case PERIOD_H2:  m_lookbackPeriod = 150;  break;  // ~12.5 days
                case PERIOD_H1:  m_lookbackPeriod = 120;  break;  // ~5 days
                default:
                {
                    int barsPerDay = 1440 / periodMinutes;  // 1440 minutes in a day
                    m_lookbackPeriod = barsPerDay * 5;      // 5 days of data
                }
            }
        }
        else
        {
            m_lookbackPeriod = lookbackPeriod;
        }
        
        if(!InitializeArrays("Init"))
        {
            ThrottledLogError("Failed to initialize arrays in Init");
            return false;
        }
        
        m_keyLevelCount = 0;

        m_state.Reset();
        m_lastChartUpdate = 0;
        
        m_logThrottle.Reset();
        
        // Validate symbol point value with error handling
        double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(symbolPoint <= 0)
        {
            ThrottledLogError("SymbolInfoDouble failed, checking _Point...");
            symbolPoint = _Point;
            if(symbolPoint <= 0)
            {
                ThrottledLogError("All point value retrievals failed. Using fallback value.");
                symbolPoint = 0.0001;
            }
        }
        
        // CRITICAL FIX: Reset static variables for deterministic behavior
        ResetStaticVariables();
        
        m_initialized = true;
        CV2EAUtils::LogInfo(StringFormat("Configuration complete for %s - Market Hours: %s, Volume Filter: %s, Timeframe: %s", 
            _Symbol, 
            m_ignoreMarketHours ? "IGNORED" : "RESPECTED",
            m_useVolumeFilter ? "ENABLED" : "DISABLED",
            EnumToString(m_currentTimeframe)));
        return true;
    }
    
    //--- Check if we should process strategy based on market conditions
    bool ShouldProcessStrategy()
    {
        // Always process in testing mode
        if(MQLInfoInteger(MQL_TESTER))
            return true;
            
        // If user wants to ignore market hours completely, always process
        if(m_ignoreMarketHours)
        {
            if(m_showDebugPrints)
            {
                static datetime lastIgnoreLog = 0;
                datetime currentTime = TimeCurrent();
                if(currentTime - lastIgnoreLog > 3600) // Log once per hour
                {
                    ThrottledLogInfo("Market hours ignored - processing normally");
                    lastIgnoreLog = currentTime;
                }
            }
            return true;
        }
            
        // For live trading, check basic market conditions
        datetime currentTime = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        
        // Skip processing on weekends (basic check)
        if(dt.day_of_week == 0 || dt.day_of_week == 6)
        {
            static datetime lastWeekendLog = 0;
            if(currentTime - lastWeekendLog > 3600) // Log once per hour max
            {
                ThrottledLogInfo("Skipping processing on weekend");
                lastWeekendLog = currentTime;
            }
            return false;
        }
        
        return true;
    }
    
    //--- Main Strategy Method
    void ProcessStrategy()
    {
        if(!m_initialized)
        {
            ThrottledLogError("Strategy not initialized");
            return;
        }
        
        // Quick market check to reduce unnecessary processing
        if(!ShouldProcessStrategy())
            return;
        
        datetime currentTime = TimeCurrent();
        
        // Check for timeframe changes and force immediate recalculation
        ENUM_TIMEFRAMES currentTF = Period();
        bool timeframeChanged = (currentTF != m_currentTimeframe);
        if(timeframeChanged)
        {
            CV2EAUtils::LogInfo(StringFormat("📊 Timeframe changed from %s to %s - forcing immediate recalculation", 
                EnumToString(m_currentTimeframe), EnumToString(currentTF)));
            m_currentTimeframe = currentTF;
            m_lastKeyLevelUpdate = 0;  // Force immediate update
            m_keyLevelCount = 0;       // Clear existing levels
        }
        
        // Step 1: Key Level Identification (only update if significant time has passed OR timeframe changed OR first run)
        bool shouldUpdateLevels = (currentTime - m_lastKeyLevelUpdate > MIN_CHART_UPDATE_SECONDS) ||
                                 (m_lastKeyLevelUpdate == 0) ||
                                 timeframeChanged;
        
        SKeyLevel strongestLevel;
        bool foundKeyLevel = false;
        
        if(shouldUpdateLevels)
        {
            foundKeyLevel = FindKeyLevels(strongestLevel);
        }
        else
        {
            // Use existing strongest level if available
            foundKeyLevel = GetStrongestLevel(strongestLevel);
        }
        
        // Update system state only if we have new data
        if(foundKeyLevel && shouldUpdateLevels)
        {
            // If we found a new key level that's significantly different from our active one
            if(!m_state.keyLevelFound || 
               MathAbs(strongestLevel.price - m_state.activeKeyLevel.price) > m_touchZone)
            {
                // Update strategy state with new key level
                m_state.keyLevelFound = true;
                m_state.activeKeyLevel = strongestLevel;
                m_state.lastUpdate = currentTime;
                
                // Print key levels report when we find a new significant level (throttled)
                if(currentTime - m_logThrottle.lastLevelReport > MIN_LEVEL_REPORT_SECONDS)
                {
                    PrintKeyLevelsReport();
                    m_logThrottle.lastLevelReport = currentTime;
                }
            }
        }
        else if(m_state.keyLevelFound && !IsKeyLevelValid(m_state.activeKeyLevel))
        {
            // If we had a key level but can't find it anymore, reset state
            ThrottledLogInfo("Previous key level no longer valid, resetting state");
            m_state.Reset();
        }
        
        // Step 2: Check for price approaching key levels (throttled alerts)
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            double distance = MathAbs(currentPrice - m_currentKeyLevels[i].price);
            if(distance <= m_touchZone * 2) // Alert when price is within 2x the touch zone
            {
                if(currentTime - m_logThrottle.lastTradeAlert > MIN_ALERT_INTERVAL_SECONDS)
                {
                    PrintTradeSetupAlert(m_currentKeyLevels[i], distance);
                    m_logThrottle.lastTradeAlert = currentTime;
                }
            }
        }
        
        // Step 3: Update and print system health report (throttled)
        if(currentTime - m_logThrottle.lastHealthReport > MIN_HEALTH_REPORT_SECONDS)
        {
            PrintSystemHealthReport();
            m_logThrottle.lastHealthReport = currentTime;
        }
        
        // Step 4: Update chart lines (immediate update when we have key levels)
        if(m_keyLevelCount > 0)
        {
            UpdateChartLines();
            m_logThrottle.lastChartUpdate = currentTime;
        }
    }
    
    //--- Simple chart update logic - removed overly complex throttling
    

    

    
    //--- Key Level Methods
    bool FindKeyLevels(SKeyLevel &outStrongestLevel)
    {
        if(!m_initialized)
        {
            CV2EAUtils::LogError("Strategy not initialized");
            return false;
        }
            
        // Copy price and volume data
        double highPrices[];
        double lowPrices[];
        double closePrices[];
        datetime times[];
        long volumes[];
        
        ArraySetAsSeries(highPrices, true);
        ArraySetAsSeries(lowPrices, true);
        ArraySetAsSeries(closePrices, true);
        ArraySetAsSeries(times, true);
        ArraySetAsSeries(volumes, true);
        
        // Get available bars for the current timeframe
        long availableBars = SeriesInfoInteger(_Symbol, Period(), SERIES_BARS_COUNT);
        
        // Adjust minimum bars requirement based on timeframe
        int minRequiredBars;
        switch(Period())
        {
            case PERIOD_MN1: minRequiredBars = 6;  break; // 6 months minimum
            case PERIOD_W1:  minRequiredBars = 8;  break; // 8 weeks minimum
            case PERIOD_D1:  minRequiredBars = 10; break; // 10 days minimum
            default:         minRequiredBars = 10; break; // Default 10 bars
        }
        
        long barsToUse = MathMin((long)m_lookbackPeriod, availableBars - 5); // Leave room for swing detection
        
        if(barsToUse < minRequiredBars)
        {
            ThrottledLogError(StringFormat("Insufficient bars available: %d (needed at least %d for %s timeframe)", 
                (int)availableBars, minRequiredBars, EnumToString(Period())));
            return false;
        }
        
        // Copy with error handling
        if(CopyHigh(_Symbol, Period(), 0, (int)barsToUse, highPrices) <= 0 ||
           CopyLow(_Symbol, Period(), 0, (int)barsToUse, lowPrices) <= 0 ||
           CopyClose(_Symbol, Period(), 0, (int)barsToUse, closePrices) <= 0 ||
           CopyTime(_Symbol, Period(), 0, (int)barsToUse, times) <= 0 ||
           CopyTickVolume(_Symbol, Period(), 0, (int)barsToUse, volumes) <= 0)
        {
            ThrottledLogError(StringFormat("Failed to copy price/volume data. Available bars: %d, Requested: %d, Error: %d", 
                (int)availableBars, (int)barsToUse, GetLastError()));
            return false;
        }
        

        
        // Reset key levels array
        m_keyLevelCount = 0;
        
        // Get current hour for stats tracking
        datetime currentTime = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        datetime currentHour = currentTime - dt.min * 60 - dt.sec;
        
        static datetime lastStatReset = 0;
        
        // Check if we need to reset hourly stats
        if(lastStatReset < currentHour)
        {
            // Reset hourly stats structure
            m_hourlyStats.Reset();
            lastStatReset = currentHour;
            
            CV2EAUtils::LogInfo("Reset hourly stats for new hour");
        }
        
        // Find swing highs (resistance levels)
        for(int i = 2; i < m_lookbackPeriod - 2; i++)
        {
            if(IsSwingHigh(highPrices, i))
            {
                double level = highPrices[i];
                
                if(!IsNearExistingLevel(level))
                {
                    SKeyLevel newLevel;
                    newLevel.price = level;
                    newLevel.isResistance = true;
                    newLevel.firstTouch = times[i];
                    newLevel.lastTouch = times[i];
                    STouchQuality quality;
                    newLevel.touchCount = CountTouches(level, true, highPrices, lowPrices, times, quality);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.rejectedLevels++;
                        continue;
                    }
                    
                    newLevel.strength = CalculateLevelStrength(newLevel, quality);
                    
                    // Add volume strength bonus if there's a volume spike
                    double volumeBonus = GetVolumeStrengthBonus(volumes, i);
                    if(volumeBonus > 0)
                    {
                        newLevel.strength = MathMin(newLevel.strength * (1.0 + volumeBonus), 0.98);
                        newLevel.volumeConfirmed = true;
                        newLevel.volumeRatio = (double)volumes[i] / GetAverageVolume(volumes, i, 20);
                    }
                    else
                    {
                        newLevel.volumeConfirmed = false;
                        newLevel.volumeRatio = 1.0;
                    }
                    
                    if(newLevel.strength >= m_minStrength)
                    {
                        AddKeyLevel(newLevel);
                        m_hourlyStats.validLevels++;
                    }
                    else
                    {
                        m_hourlyStats.rejectedLevels++;
                    }
                }
                else
                {
                    m_hourlyStats.rejectedLevels++;
                }
            }
        }
        
        // Find swing lows (support levels)
        for(int i = 2; i < m_lookbackPeriod - 2; i++)
        {
            if(IsSwingLow(lowPrices, i))
            {
                double level = lowPrices[i];
                
                if(!IsNearExistingLevel(level))
                {
                    SKeyLevel newLevel;
                    newLevel.price = level;
                    newLevel.isResistance = false;
                    newLevel.firstTouch = times[i];
                    newLevel.lastTouch = times[i];
                    STouchQuality quality;
                    newLevel.touchCount = CountTouches(level, false, highPrices, lowPrices, times, quality);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.rejectedLevels++;
                        continue;
                    }
                    
                    newLevel.strength = CalculateLevelStrength(newLevel, quality);
                    
                    // Add volume strength bonus if there's a volume spike
                    double volumeBonus = GetVolumeStrengthBonus(volumes, i);
                    if(volumeBonus > 0)
                    {
                        newLevel.strength = MathMin(newLevel.strength * (1.0 + volumeBonus), 0.98);
                        newLevel.volumeConfirmed = true;
                        newLevel.volumeRatio = (double)volumes[i] / GetAverageVolume(volumes, i, 20);
                    }
                    else
                    {
                        newLevel.volumeConfirmed = false;
                        newLevel.volumeRatio = 1.0;
                    }
                    
                    if(newLevel.strength >= m_minStrength)
                    {
                        AddKeyLevel(newLevel);
                        m_hourlyStats.validLevels++;
                    }
                    else
                    {
                        m_hourlyStats.rejectedLevels++;
                    }
                }
                else
                {
                    m_hourlyStats.rejectedLevels++;
                }
            }
        }
        
        // Find strongest level
        if(m_keyLevelCount > 0)
        {
            int strongestIdx = 0;
            double maxStrength = m_currentKeyLevels[0].strength;
            
            for(int i = 1; i < m_keyLevelCount; i++)
            {
                if(m_currentKeyLevels[i].strength > maxStrength)
                {
                    maxStrength = m_currentKeyLevels[i].strength;
                    strongestIdx = i;
                }
            }
            
            outStrongestLevel = m_currentKeyLevels[strongestIdx];
            m_lastKeyLevelUpdate = TimeCurrent();
            
            // Immediately update chart lines when key levels are found
            UpdateChartLines();
            
            CV2EAUtils::LogInfo(StringFormat("Found %d key levels. Strongest: %.5f (strength: %.4f)", 
                m_keyLevelCount, outStrongestLevel.price, outStrongestLevel.strength));
            
            return true;
        }
        
        CV2EAUtils::LogInfo("No key levels found in current analysis");
        return false;
    }



    // Test-specific methods
    bool TEST_GetKeyLevel(int index, SKeyLevel &level) const
    {
        if(index >= 0 && index < m_keyLevelCount)
        {
            level = m_currentKeyLevels[index];
            return true;
        }
        return false;
    }
    
    int TEST_GetKeyLevelCount() const
    {
        return m_keyLevelCount;
    }
    
    double TEST_GetMinStrength() const
    {
        return m_minStrength;
    }
    
    double TEST_GetTouchZone() const
    {
        return m_touchZone;
    }
    
    int TEST_GetMinTouches() const
    {
        return m_minTouches;
    }

    bool TEST_IsUS500()  // Add this test-specific method
    {
        return IsUS500();
    }

    //--- Process timeframe method
    bool ProcessTimeframe(ENUM_TIMEFRAMES timeframe)
        {
            if(!m_initialized) {
                CV2EAUtils::LogError("Strategy not initialized");
                return false;
            }
            
            // Store current timeframe and rates
            ENUM_TIMEFRAMES currentTF = Period();
            
            // Check if we're in testing mode
            bool isTesting = MQLInfoInteger(MQL_TESTER);
            
            if(isTesting) {
                // Testing mode - use CopyRates
                MqlRates rates[];
                double high[], low[], close[];
                long volume[];
                datetime time[];
                
                ArraySetAsSeries(rates, true);
                ArraySetAsSeries(high, true);
                ArraySetAsSeries(low, true);
                ArraySetAsSeries(close, true);
                ArraySetAsSeries(volume, true);
                ArraySetAsSeries(time, true);
                
                // Get enough bars for lookback plus buffer
                int barsNeeded = m_lookbackPeriod + 10;  // Add buffer for swing detection
                
                // Copy all necessary data
                if(CopyHigh(_Symbol, timeframe, 0, barsNeeded, high) <= 0 ||
                   CopyLow(_Symbol, timeframe, 0, barsNeeded, low) <= 0 ||
                   CopyClose(_Symbol, timeframe, 0, barsNeeded, close) <= 0 ||
                   CopyTickVolume(_Symbol, timeframe, 0, barsNeeded, volume) <= 0 ||
                   CopyTime(_Symbol, timeframe, 0, barsNeeded, time) <= 0) {
                    CV2EAUtils::LogError(StringFormat("Failed to copy data for %s", EnumToString(timeframe)));
                    return false;
                }
                
                // Process strategy using the copied data
                SKeyLevel strongestLevel;
                FindKeyLevels(strongestLevel);
                
                // Update chart lines after processing each timeframe
                m_lastChartUpdate = 0; // Force update
                UpdateChartLines();
                ChartRedraw(0);
            }
            else {
                // Live trading - use chart switching for proper visualization
                if(timeframe == currentTF) {
                    ProcessStrategy();
                }
                else if(!ChartSetSymbolPeriod(0, _Symbol, timeframe)) {
                    CV2EAUtils::LogError(StringFormat("Failed to switch from %s to %s", 
                        EnumToString(currentTF), EnumToString(timeframe)));
                    return false;
                }
                
                // Process strategy on this timeframe
                ProcessStrategy();
                
                // Switch back to original timeframe
                ChartSetSymbolPeriod(0, _Symbol, currentTF);
            }
            
            return true;
        }
        
        bool GetStrongestLevel(SKeyLevel &outLevel)
        {
            if(m_keyLevelCount == 0)
                return false;
                
            double maxStrength = 0;
            int strongestIdx = -1;
            
            // Find strongest level
            for(int i = 0; i < m_keyLevelCount; i++) {
                if(m_currentKeyLevels[i].strength > maxStrength) {
                    maxStrength = m_currentKeyLevels[i].strength;
                    strongestIdx = i;
                }
            }
            
            if(strongestIdx >= 0) {
                outLevel = m_currentKeyLevels[strongestIdx];
                return true;
            }
            
            return false;
        }

        //--- Chart object cleanup and manual update with proper error handling
        void ClearAllChartObjects()
        {
            long chart_id = ChartID();
            
            // Clear all objects with our prefix
            int deletedCount = ObjectsDeleteAll(chart_id, "KL_");
            
            // Reset our internal tracking arrays
            ArrayFree(m_chartLines);
            m_lastChartUpdate = 0;
            
            // Force chart redraw
            Sleep(100);  // Allow deletion to complete
            ChartRedraw(chart_id);
            
            CV2EAUtils::LogInfo(StringFormat("🗑️ Cleared %d chart objects and reset tracking", deletedCount));
        }
        
        //--- Force immediate chart update (for manual testing)
        void ForceChartUpdate()
        {
            CV2EAUtils::LogInfo("🔄 Forcing immediate chart update...");
            
            // Clear throttling to force immediate update
            m_lastChartUpdate = 0;
            
            if(m_keyLevelCount > 0)
            {
                UpdateChartLines();
                CV2EAUtils::LogInfo(StringFormat("✅ Forced update complete: %d lines displayed out of %d key levels", 
                    ArraySize(m_chartLines), m_keyLevelCount));
                    
                // Additional verification
                long chart_id = ChartID();
                int totalHLines = ObjectsTotal(chart_id, 0, OBJ_HLINE);
                CV2EAUtils::LogInfo(StringFormat("📊 Chart now has %d total horizontal lines", totalHLines));
            }
            else
            {
                CV2EAUtils::LogInfo("⚠️ No key levels found to display - running level detection...");
                
                // Try to find key levels if none exist
                SKeyLevel strongestLevel;
                if(FindKeyLevels(strongestLevel))
                {
                    CV2EAUtils::LogInfo(StringFormat("🎯 Found %d key levels after detection", m_keyLevelCount));
                    UpdateChartLines();
                }
                else
                {
                    CV2EAUtils::LogInfo("❌ No key levels detected in current market data");
                }
            }
        }

        //--- Runtime configuration methods
        void SetIgnoreMarketHours(bool ignore)
        {
            m_ignoreMarketHours = ignore;
            CV2EAUtils::LogInfo(StringFormat("🕐 Market hours setting changed to: %s", 
                ignore ? "IGNORED" : "RESPECTED"));
        }
        
        bool GetIgnoreMarketHours() const
        {
            return m_ignoreMarketHours;
        }
        
        //--- Force immediate recalculation (useful when switching timeframes manually)
        void ForceRecalculation()
        {
            CV2EAUtils::LogInfo("🔄 Forcing immediate level recalculation...");
            m_lastKeyLevelUpdate = 0;  // Force immediate update
            m_keyLevelCount = 0;       // Clear existing levels
            m_currentTimeframe = Period(); // Update current timeframe
            
            // Process strategy immediately
            ProcessStrategy();
        }
        
        //--- Show current configuration status
        void ShowConfiguration()
        {
            CV2EAUtils::LogInfo(StringFormat(
                "\n📋 BREAKOUTS CONFIGURATION STATUS\n" +
                "================================\n" +
                "Symbol: %s\n" +
                "Current Timeframe: %s\n" +
                "Market Hours: %s\n" +
                "Volume Filter: %s\n" +
                "Min Strength: %.2f\n" +
                "Min Touches: %d\n" +
                "Touch Zone: %.5f\n" +
                "Lookback Period: %d\n" +
                "Debug Prints: %s\n" +
                "Key Levels Found: %d\n" +
                "Last Update: %s\n" +
                "================================",
                _Symbol,
                EnumToString(m_currentTimeframe),
                m_ignoreMarketHours ? "IGNORED" : "RESPECTED",
                m_useVolumeFilter ? "ENABLED" : "DISABLED",
                m_minStrength,
                m_minTouches,
                m_touchZone,
                m_lookbackPeriod,
                m_showDebugPrints ? "ON" : "OFF",
                m_keyLevelCount,
                m_lastKeyLevelUpdate > 0 ? TimeToString(m_lastKeyLevelUpdate, TIME_DATE|TIME_MINUTES) : "Never"
            ));
        }

private:
    //--- Key Level Helper Methods
    bool IsSwingHigh(const double &prices[], int index)
    {
        // Validate array bounds first
        int size = ArraySize(prices);
        if(index < 2 || index >= size - 2)
        {
            if(m_showDebugPrints)
                CV2EAUtils::LogInfo(StringFormat("IsSwingHigh: Index %d out of valid range [2, %d]", index, size - 3));
            return false;
        }
        
        // Basic swing high pattern
        bool basicPattern = prices[index] > prices[index-1] && 
                          prices[index] > prices[index-2] &&
                          prices[index] > prices[index+1] && 
                          prices[index] > prices[index+2];
                          
        if(!basicPattern) return false;
        
        // Calculate slopes for better validation
        double leftSlope1 = prices[index] - prices[index-1];
        double leftSlope2 = prices[index-1] - prices[index-2];
        double rightSlope1 = prices[index] - prices[index+1];
        double rightSlope2 = prices[index+1] - prices[index+2];
        
        // Validate slope consistency
        bool validSlopes = (leftSlope1 > 0 && leftSlope2 >= 0) &&    // Increasing slope on left
                          (rightSlope1 > 0 && rightSlope2 >= 0);      // Decreasing slope on right
        
        if(!validSlopes) return false;
        
        // Calculate the minimum required height based on timeframe
        double minHeight;
        int windowSize;
        
        // Adjust requirements based on timeframe
        switch(Period()) {
            case PERIOD_MN1: 
                minHeight = _Point * 200;
                windowSize = 5;
                break;
            case PERIOD_W1:  
                minHeight = _Point * 150;
                windowSize = 4;
                break;
            case PERIOD_D1:  
                minHeight = _Point * 100;
                windowSize = 4;
                break;
            case PERIOD_H4:  
                minHeight = _Point * 50;
                windowSize = 3;
                break;
            case PERIOD_H1:
                minHeight = _Point * 25;
                windowSize = 3;
                break;
            case PERIOD_M30:
                minHeight = _Point * 15;
                windowSize = 2;
                break;
            case PERIOD_M15:
                minHeight = _Point * 10;
                windowSize = 2;
                break;
            case PERIOD_M5:
                minHeight = _Point * 6;
                windowSize = 2;
                break;
            case PERIOD_M1:
                minHeight = _Point * 4;
                windowSize = 2;
                break;
            default:         
                minHeight = _Point * 10;
                windowSize = 2;
        }
        
        // Check if the swing is significant enough
        double leftHeight = prices[index] - MathMin(prices[index-1], prices[index-2]);
        double rightHeight = prices[index] - MathMin(prices[index+1], prices[index+2]);
        
        // Both sides should have significant height
        if(leftHeight < minHeight || rightHeight < minHeight)
            return false;
            
        // Additional validation: check if it's the highest in a wider window
        // Make sure we don't go out of bounds
        int startIdx = MathMax(0, index - windowSize);
        int endIdx = MathMin(size - 1, index + windowSize);
        
        for(int i = startIdx; i <= endIdx; i++)
        {
            if(i != index && prices[i] > prices[index])
                return false;  // Found a higher point nearby
        }
        
        return true;
    }
    
    bool IsSwingLow(const double &prices[], int index)
    {
        // Validate array bounds first
        int size = ArraySize(prices);
        if(index < 2 || index >= size - 2)
        {
            if(m_showDebugPrints)
                CV2EAUtils::LogInfo(StringFormat("IsSwingLow: Index %d out of valid range [2, %d]", index, size - 3));
            return false;
        }
        
        // Basic swing low pattern
        bool basicPattern = prices[index] < prices[index-1] && 
                          prices[index] < prices[index-2] &&
                          prices[index] < prices[index+1] && 
                          prices[index] < prices[index+2];
                          
        if(!basicPattern) return false;
        
        // Calculate the minimum required height based on timeframe
        double minHeight;
        int windowSize;
        
        // Adjust requirements based on timeframe
        switch(Period()) {
            case PERIOD_MN1: 
                minHeight = _Point * 200;  // 200 points for monthly
                windowSize = 5;            // Increased for better monthly validation
                break;
            case PERIOD_W1:  
                minHeight = _Point * 150;  // 150 points for weekly
                windowSize = 4;
                break;
            case PERIOD_D1:  
                minHeight = _Point * 100;  // 100 points for daily
                windowSize = 4;
                break;
            case PERIOD_H4:  
                minHeight = _Point * 50;   // 50 points for 4h
                windowSize = 3;
                break;
            case PERIOD_H1:
                minHeight = _Point * 25;   // Reduced from 30 to 25 for 1h
                windowSize = 3;
                break;
            case PERIOD_M30:
                minHeight = _Point * 15;   // Reduced from 20 to 15 for M30
                windowSize = 2;            // Reduced window size for faster timeframes
                break;
            case PERIOD_M15:
                minHeight = _Point * 10;   // Reduced from 15 to 10 for M15
                windowSize = 2;
                break;
            case PERIOD_M5:
                minHeight = _Point * 6;    // Reduced from 8 to 6 for M5
                windowSize = 2;
                break;
            case PERIOD_M1:
                minHeight = _Point * 4;    // Reduced from 5 to 4 for M1
                windowSize = 2;
                break;
            default:         
                minHeight = _Point * 10;   // Default fallback
                windowSize = 2;
        }
        
        // Check if the swing is significant enough
        double leftHeight = MathMax(prices[index-1], prices[index-2]) - prices[index];
        double rightHeight = MathMax(prices[index+1], prices[index+2]) - prices[index];
        
        // Both sides should have significant height
        if(leftHeight < minHeight || rightHeight < minHeight)
            return false;
            
        // Additional validation: check if it's the lowest in a wider window
        // Make sure we don't go out of bounds
        int startIdx = MathMax(0, index - windowSize);
        int endIdx = MathMin(size - 1, index + windowSize);
        
        for(int i = startIdx; i <= endIdx; i++)
        {
            if(i != index && prices[i] < prices[index])
                return false;  // Found a lower point nearby
        }
        
        return true;
    }
    
    bool IsNearExistingLevel(const double price)
    {
        // Calculate appropriate touch zone based on timeframe
        double adjustedTouchZone = m_touchZone;
        switch(Period()) {
            case PERIOD_MN1: adjustedTouchZone *= 2.0; break;
            case PERIOD_W1:  adjustedTouchZone *= 1.8; break;
            case PERIOD_D1:  adjustedTouchZone *= 1.5; break;
            case PERIOD_H4:  adjustedTouchZone *= 1.2; break;
        }
        
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            double currentDistance = MathAbs(price - m_currentKeyLevels[i].price);
            if(currentDistance <= adjustedTouchZone)
                return true;
        }
        
        return false;
    }
    
    bool IsNearExistingLevel(const double price, SKeyLevel &nearestLevel, double &distance)
    {
        // Calculate appropriate touch zone based on timeframe
        double adjustedTouchZone = m_touchZone;
        switch(Period()) {
            case PERIOD_MN1: adjustedTouchZone *= 2.0; break;
            case PERIOD_W1:  adjustedTouchZone *= 1.8; break;
            case PERIOD_D1:  adjustedTouchZone *= 1.5; break;
            case PERIOD_H4:  adjustedTouchZone *= 1.2; break;
        }
        
        bool found = false;
        double minDistance = DBL_MAX;
        int nearestIdx = -1;
        
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            double currentDistance = MathAbs(price - m_currentKeyLevels[i].price);
            if(currentDistance <= adjustedTouchZone)
            {
                found = true;
                if(currentDistance < minDistance)
                {
                    minDistance = currentDistance;
                    nearestIdx = i;
                }
            }
        }
        
        // If a nearest level was found, fill the reference parameters
        if(found && nearestIdx >= 0)
        {
            nearestLevel = m_currentKeyLevels[nearestIdx];
            distance = minDistance;
            
            if(m_showDebugPrints)
            {
                CV2EAUtils::LogInfo(StringFormat(
                    "Found nearby level: %.5f (%.1f pips away)",
                    m_currentKeyLevels[nearestIdx].price,
                    minDistance / _Point
                ));
            }
        }
        
        return found;
    }
    
    int CountTouches(double level, bool isResistance, const double &highs[], 
                     const double &lows[], const datetime &times[], STouchQuality &quality)
    {
        quality.touchCount = 0;
        quality.avgBounceStrength = 0;
        quality.avgBounceVolume = 0;
        quality.maxBounceSize = 0;
        quality.quickestBounce = INT_MAX;
        quality.slowestBounce = 0;
        
        int touches = 0;
        double lastPrice = 0;
        datetime lastTouchTime = 0;
        double totalBounceStrength = 0;
        double totalBounceVolume = 0;
        
        // Calculate pip size based on digits
        double pipSize = _Point;
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        if(digits == 3 || digits == 5)
            pipSize = _Point * 10;
            
        // Get volume data if available
        bool hasVolume = true;  // We'll check each volume individually with iVolume
            
        // Adjust touch and bounce requirements based on timeframe
        double minTouchDistance = m_touchZone * 0.2;  // 20% of touch zone
        double minBounceDistance = m_touchZone * 0.3;  // 30% of touch zone
        
        // Debug info
        if(m_showDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat(
                "\n=== TOUCH DETECTION FOR LEVEL %.5f ===\n" +
                "Type: %s\n" +
                "Touch Zone: %.5f (%d pips)\n" +
                "Min Touch Distance: %d pips\n" +
                "Min Bounce Distance: %d pips\n" +
                "Max Bounce Delay: %d bars",
                level,
                isResistance ? "RESISTANCE" : "SUPPORT",
                m_touchZone,
                (int)(m_touchZone / pipSize),
                (int)(minTouchDistance / pipSize),
                (int)(minBounceDistance / pipSize),
                m_maxBounceDelay
            ));
        }
        
        // Track consecutive touches within the same zone
        int consecutiveTouches = 0;
        double lastValidTouch = 0;
        
        // Add safety check for array size
        if(ArraySize(highs) < m_lookbackPeriod || ArraySize(lows) < m_lookbackPeriod)
        {
            if(m_showDebugPrints)
                CV2EAUtils::LogError(StringFormat("[%s] Insufficient data for analysis. Need %d bars, got High:%d Low:%d", 
                    TimeToString(TimeCurrent()), m_lookbackPeriod, ArraySize(highs), ArraySize(lows)));
            return 0;
        }
        
        for(int i = 0; i < m_lookbackPeriod - m_maxBounceDelay; i++)
        {
            // Add bounds check for main arrays
            if(i >= ArraySize(highs) || i >= ArraySize(lows))
            {
                CV2EAUtils::LogError("Array index out of bounds in touch detection");
                break;
            }
            
            double currentPrice = isResistance ? highs[i] : lows[i];
            double touchDistance = MathAbs(currentPrice - level);
            
            // Check if price is within touch zone
            if(touchDistance <= m_touchZone)
            {
                // Validate touch spacing
                bool validTouch = true;
                if(lastValidTouch != 0)
                {
                    double spacing = MathAbs(currentPrice - lastValidTouch);
                    if(spacing < minTouchDistance)
                    {
                        consecutiveTouches++;
                        if(consecutiveTouches > 2)  // Allow up to 2 consecutive touches
                        {
                            validTouch = false;
                        }
                    }
                    else
                    {
                        consecutiveTouches = 0;
                    }
                }
                
                if(validTouch)
                {
                    // Look for bounce
                    double extremePrice = currentPrice;
                    int bounceBar = 0;
                    bool cleanBounce = true;
                    double bounceVolume = 0;
                    
                    // Find the bounce with bounds checking
                    for(int j = 1; j <= m_maxBounceDelay && (i+j) < ArraySize(highs) && (i+j) < ArraySize(lows); j++)
                    {
                        if(i+j >= m_lookbackPeriod) break;  // Safety check
                        
                        double price = isResistance ? lows[i+j] : highs[i+j];
                        if(isResistance ? (price < extremePrice) : (price > extremePrice))
                        {
                            extremePrice = price;
                            bounceBar = j;
                            if(hasVolume && (i+j) < ArraySize(times)) 
                                bounceVolume = (double)iVolume(_Symbol, Period(), i+j);
                        }
                    }
                    
                    // Verify clean bounce with bounds checking
                    for(int j = 1; j < bounceBar && (i+j) < ArraySize(highs) && (i+j) < ArraySize(lows); j++)
                    {
                        double checkPrice = isResistance ? highs[i+j] : lows[i+j];
                        if(isResistance ? (checkPrice > currentPrice - m_touchZone) : 
                                        (checkPrice < currentPrice + m_touchZone))
                        {
                            cleanBounce = false;
                            break;
                        }
                    }
                    
                    double bounceSize = MathAbs(currentPrice - extremePrice);
                    if(bounceSize >= minBounceDistance && cleanBounce)
                    {
                        touches++;
                        lastValidTouch = currentPrice;
                        totalBounceStrength += bounceSize / pipSize;
                        if(hasVolume) totalBounceVolume += bounceVolume;
                        
                        // Update quality metrics
                        quality.maxBounceSize = MathMax(quality.maxBounceSize, bounceSize);
                        quality.quickestBounce = MathMin(quality.quickestBounce, bounceBar);
                        quality.slowestBounce = MathMax(quality.slowestBounce, bounceBar);
                        
                        if(m_showDebugPrints)
                        {
                            CV2EAUtils::LogInfo(StringFormat(
                                "Touch %d at %.5f (%.1f pips from level) - Bounce Size: %.1f pips, Bounce Bar: %d, Bounce Volume: %.2f",
                                touches,
                                currentPrice,
                                touchDistance / pipSize,
                                bounceSize / pipSize,
                                bounceBar,
                                bounceVolume
                            ));
                        }
                    }
                }
            }
            else if(touchDistance > m_touchZone * 3)
            {
                // Reset consecutive touch counter when price moves far from level
                consecutiveTouches = 0;
                lastValidTouch = 0;
            }
        }
        
        // Calculate final quality metrics
        if(touches > 0)
        {
            quality.touchCount = touches;
            quality.avgBounceStrength = totalBounceStrength / touches;
            if(hasVolume) quality.avgBounceVolume = totalBounceVolume / touches;
            
            if(m_showDebugPrints)
            {
                CV2EAUtils::LogInfo(StringFormat(
                    "=== TOUCH QUALITY SUMMARY ===\n" +
                    "Total Touches: %d\n" +
                    "Avg Bounce: %.1f pips\n" +
                    "Max Bounce: %.1f pips\n" +
                    "Bounce Range: %d-%d bars\n" +
                    "Avg Volume: %.2f\n" +
                    "===================",
                    touches,
                    quality.avgBounceStrength,
                    quality.maxBounceSize / pipSize,
                    quality.quickestBounce,
                    quality.slowestBounce,
                    quality.avgBounceVolume
                ));
            }
        }
        
        return touches;
    }
    
    double CalculateLevelStrength(const SKeyLevel &level, const STouchQuality &quality)
    {
        // Base strength from touch count (0.50-0.95 range)
        double touchBase = 0;
        switch(level.touchCount) {
            case 2: touchBase = 0.50; break;  // Base level
            case 3: touchBase = 0.70; break;  // Significant jump
            case 4: touchBase = 0.85; break;  // Strong level
            default: touchBase = MathMin(0.90 + ((level.touchCount - 5) * 0.01), 0.95); // Cap at 0.95
        }
        
        // Recency modifier (-60% to +30% of base)
        ENUM_TIMEFRAMES tf = Period();
        int periodMinutes = PeriodSeconds(tf) / 60;
        double barsElapsed = (double)(TimeCurrent() - level.lastTouch) / (periodMinutes * 60);
        double recencyMod = 0;
        
        // Enhanced recency calculation based on timeframe
        if(barsElapsed <= m_lookbackPeriod / 8) {      // Very recent (within 1/8 of lookback)
            recencyMod = 0.30;
        } else if(barsElapsed <= m_lookbackPeriod / 4) {  // Recent (within 1/4 of lookback)
            recencyMod = 0.20;
        } else if(barsElapsed <= m_lookbackPeriod / 2) {  // Moderately recent
            recencyMod = 0.10;
        } else if(barsElapsed <= m_lookbackPeriod) {      // Within lookback
            recencyMod = 0;
        } else {                                          // Old
            recencyMod = -0.60;
        }
        
        // Duration bonus (up to +35% of base)
        double barsDuration = (double)(level.lastTouch - level.firstTouch) / (periodMinutes * 60);
        double durationMod = 0;
        
        // Enhanced duration calculation
        if(barsDuration >= m_lookbackPeriod * 0.75) {     // Very long-lasting
            durationMod = 0.35;
        } else if(barsDuration >= m_lookbackPeriod / 2) {  // Long-lasting
            durationMod = 0.25;
        } else if(barsDuration >= m_lookbackPeriod / 4) {  // Medium duration
            durationMod = 0.15;
        } else if(barsDuration >= m_lookbackPeriod / 8) {  // Short duration
            durationMod = 0.05;
        }
        
        // Timeframe bonus - adjusted weights
        double timeframeBonus = 0;
        if(CV2EAUtils::IsUS500()) {
            timeframeBonus = CV2EAUS500Data::GetTimeframeBonus(tf);
        }
        else if(CV2EAUtils::IsForexPair()) {
            timeframeBonus = CV2EAForexData::GetTimeframeBonus(tf);
        }
        else {
            timeframeBonus = 0.0; // Default for other instruments
        }
        
        // Touch quality bonus (up to +20% based on bounce characteristics)
        double qualityBonus = 0;
        double bounceSpeed = 0;  // Declare bounceSpeed here
        
        // Bonus for consistent bounce sizes
        double bounceConsistency = quality.maxBounceSize > 0 ? 
            quality.avgBounceStrength / (quality.maxBounceSize / _Point) : 0;
        qualityBonus += bounceConsistency * 0.10;  // Up to 10% for consistent bounces
        
        // Bonus for quick bounces
        if(quality.quickestBounce < INT_MAX)
        {
            bounceSpeed = 1.0 - ((double)(quality.quickestBounce + quality.slowestBounce) / 
                                      (2.0 * m_maxBounceDelay));
            qualityBonus += bounceSpeed * 0.05;  // Up to 5% for quick bounces
        }
        
        // Bonus for volume confirmation
        if(quality.avgBounceVolume > 0)
        {
            qualityBonus += 0.05;  // 5% bonus for volume confirmation
        }
        
        // Calculate final strength with all modifiers
        double strength = touchBase * (1.0 + recencyMod + durationMod + timeframeBonus + qualityBonus);
        
        // Add tiny random variation (0.05% max) to prevent identical strengths
        strength += 0.0005 * MathMod(level.price * 10000, 10) / 10;
        
        // Debug output for strength calculation
        if(m_showDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat(
                "\n=== STRENGTH CALCULATION FOR LEVEL %.5f ===\n" +
                "Base Strength (from %d touches): %.4f\n" +
                "Recency Modifier: %.2f%%\n" +
                "Duration Modifier: %.2f%%\n" +
                "Timeframe Bonus: %.2f%%\n" +
                "Quality Bonus: %.2f%%\n" +
                "  - Bounce Consistency: %.2f\n" +
                "  - Bounce Speed: %.2f\n" +
                "  - Volume Confirmation: %s\n" +
                "Final Strength: %.4f",
                level.price,
                level.touchCount,
                touchBase,
                recencyMod * 100,
                durationMod * 100,
                timeframeBonus * 100,
                qualityBonus * 100,
                bounceConsistency,
                bounceSpeed,
                quality.avgBounceVolume > 0 ? "Yes" : "No",
                strength
            ));
        }
        
        // Ensure bounds
        return MathMin(MathMax(strength, 0.45), 0.98);
    }
    
    void AddKeyLevel(const SKeyLevel &level)
    {
        // Validate level
        if(level.price <= 0 || level.touchCount < m_minTouches || level.strength < m_minStrength)
        {
            if(m_showDebugPrints)
            {
                CV2EAUtils::LogError(StringFormat(
                    "Invalid level rejected: Price=%.5f, Touches=%d, Strength=%.4f",
                    level.price,
                    level.touchCount,
                    level.strength
                ));
            }
            return;
        }
        
        // Check array capacity
        if(m_keyLevelCount >= ArraySize(m_currentKeyLevels))
        {
            int newSize = MathMax(10, ArraySize(m_currentKeyLevels) * 2);
            if(!CV2EAUtils::SafeResizeArray(m_currentKeyLevels, newSize, "CV2EABreakouts::AddKeyLevel"))
            {
                CV2EAUtils::LogError("Failed to resize key levels array");
                return;
            }
        }
        
        // Find insertion point to maintain sorted array (by price)
        int insertIdx = m_keyLevelCount;
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            if(level.price < m_currentKeyLevels[i].price)
            {
                insertIdx = i;
                break;
            }
        }
        
        // Shift elements to make room for new level
        if(insertIdx < m_keyLevelCount)
        {
            for(int i = m_keyLevelCount; i > insertIdx; i--)
            {
                m_currentKeyLevels[i] = m_currentKeyLevels[i-1];
            }
        }
        
        // Insert new level
        m_currentKeyLevels[insertIdx] = level;
        m_keyLevelCount++;
        
        // Debug output
        if(m_showDebugPrints)
        {
            string levelType = level.isResistance ? "resistance" : "support";
            string strengthDesc;
            
            if(level.strength >= 0.90) strengthDesc = "Very Strong";
            else if(level.strength >= 0.80) strengthDesc = "Strong";
            else if(level.strength >= 0.70) strengthDesc = "Moderate";
            else strengthDesc = "Normal";
            
            // Calculate actual duration in hours
            double durationHours = (double)(level.lastTouch - level.firstTouch) / 3600.0;
            
            CV2EAUtils::LogInfo(StringFormat(
                "Added %s level at %.5f\n" +
                "   Strength: %.4f (%s)\n" +
                "   Touches: %d\n" +
                "   First Touch: %s\n" +
                "   Last Touch: %s\n" +
                "   Duration: %.1f hours",
                levelType,
                level.price,
                level.strength,
                strengthDesc,
                level.touchCount,
                TimeToString(level.firstTouch),
                TimeToString(level.lastTouch),
                durationHours
            ));
        }
        
        // Maintain maximum number of levels per type if needed
        const int maxLevelsPerType = 10;  // Adjust as needed
        int resistanceCount = 0;
        int supportCount = 0;
        
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            if(m_currentKeyLevels[i].isResistance)
                resistanceCount++;
            else
                supportCount++;
        }
        
        // Remove weakest levels if we have too many
        if(resistanceCount > maxLevelsPerType || supportCount > maxLevelsPerType)
        {
            RemoveWeakestLevels(maxLevelsPerType);
        }
    }
    
    void RemoveWeakestLevels(int maxPerType)
    {
        // Create arrays for sorting
        SKeyLevel resistanceLevels[];
        SKeyLevel supportLevels[];
        double resistanceStrengths[];
        double supportStrengths[];
        int resistanceCount = 0;
        int supportCount = 0;
        
        // Separate levels by type
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            if(m_currentKeyLevels[i].isResistance)
            {
                if(!CV2EAUtils::SafeResizeArray(resistanceLevels, resistanceCount + 1, "CV2EABreakouts::RemoveWeakestLevels - resistanceLevels") ||
                   !CV2EAUtils::SafeResizeArray(resistanceStrengths, resistanceCount + 1, "CV2EABreakouts::RemoveWeakestLevels - resistanceStrengths"))
                {
                    CV2EAUtils::LogError("Failed to resize resistance arrays");
                    return;
                }
                resistanceLevels[resistanceCount] = m_currentKeyLevels[i];
                resistanceStrengths[resistanceCount] = m_currentKeyLevels[i].strength;
                resistanceCount++;
            }
            else
            {
                if(!CV2EAUtils::SafeResizeArray(supportLevels, supportCount + 1, "CV2EABreakouts::RemoveWeakestLevels - supportLevels") ||
                   !CV2EAUtils::SafeResizeArray(supportStrengths, supportCount + 1, "CV2EABreakouts::RemoveWeakestLevels - supportStrengths"))
                {
                    CV2EAUtils::LogError("Failed to resize support arrays");
                    return;
                }
                supportLevels[supportCount] = m_currentKeyLevels[i];
                supportStrengths[supportCount] = m_currentKeyLevels[i].strength;
                supportCount++;
            }
        }
        
        // Sort levels by strength (descending)
        if(resistanceCount > 1)
            CV2EAUtils::QuickSort(resistanceLevels, 0, resistanceCount - 1, resistanceStrengths);
        if(supportCount > 1)
            CV2EAUtils::QuickSort(supportLevels, 0, supportCount - 1, supportStrengths);
        
        m_keyLevelCount = 0;
        
        // Resize arrays to keep only strongest levels
        if(!CV2EAUtils::SafeResizeArray(resistanceLevels, MathMin(maxPerType, resistanceCount), "CV2EABreakouts::RemoveWeakestLevels - resistanceLevels"))
        {
            CV2EAUtils::LogError("Failed to resize resistance levels array to final size");
            return;
        }
        
        if(!CV2EAUtils::SafeResizeArray(supportLevels, MathMin(maxPerType, supportCount), "CV2EABreakouts::RemoveWeakestLevels - supportLevels"))
        {
            CV2EAUtils::LogError("Failed to resize support levels array to final size");
            return;
        }
        
        // Copy strongest levels back to main array
        for(int i = 0; i < MathMin(maxPerType, resistanceCount); i++)
            m_currentKeyLevels[m_keyLevelCount++] = resistanceLevels[i];
        for(int i = 0; i < MathMin(maxPerType, supportCount); i++)
            m_currentKeyLevels[m_keyLevelCount++] = supportLevels[i];
        
        CV2EAUtils::LogInfo(StringFormat("Cleaned up levels. Kept %d resistance and %d support levels.",
              IntegerToString(MathMin(maxPerType, resistanceCount)),
              IntegerToString(MathMin(maxPerType, supportCount))));
    }
    
    //--- Debug print method (now throttled)
    void DebugPrint(string message)
    {
        if(!m_showDebugPrints)
            return;
            
        // Add timestamp and current price to debug messages
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        ThrottledLogInfo(StringFormat("[%s] [%.5f] %s", timestamp, currentPrice, message));
    }

    void PrintKeyLevelsReport()
    {
        if(!m_showDebugPrints) return;

        string timeStr = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        CV2EAUtils::DebugPrint(StringFormat("=== KEY LEVELS REPORT [%s] ===\nPrice: %.5f", 
            timeStr, currentPrice));
        
        // Create arrays to store and sort levels
        SKeyLevel supportLevels[];
        SKeyLevel resistanceLevels[];
        ArrayResize(supportLevels, m_keyLevelCount);
        ArrayResize(resistanceLevels, m_keyLevelCount);
        int supportCount = 0;
        int resistanceCount = 0;
        
        // Separate levels into support and resistance
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            if(m_currentKeyLevels[i].isResistance)
                resistanceLevels[resistanceCount++] = m_currentKeyLevels[i];
            else
                supportLevels[supportCount++] = m_currentKeyLevels[i];
        }
        
        // Sort levels by distance from current price
        for(int i = 0; i < supportCount - 1; i++)
        {
            for(int j = i + 1; j < supportCount; j++)
            {
                if(MathAbs(supportLevels[i].price - currentPrice) > MathAbs(supportLevels[j].price - currentPrice))
                {
                    SKeyLevel temp = supportLevels[i];
                    supportLevels[i] = supportLevels[j];
                    supportLevels[j] = temp;
                }
            }
        }
        
        for(int i = 0; i < resistanceCount - 1; i++)
        {
            for(int j = i + 1; j < resistanceCount; j++)
            {
                if(MathAbs(resistanceLevels[i].price - currentPrice) > MathAbs(resistanceLevels[j].price - currentPrice))
                {
                    SKeyLevel temp = resistanceLevels[i];
                    resistanceLevels[i] = resistanceLevels[j];
                    resistanceLevels[j] = temp;
                }
            }
        }
        
        // Print header without timestamp in each line
        CV2EAUtils::DebugPrint(StringFormat("=== KEY LEVELS REPORT [%s] ===\nPrice: %.5f", timeStr, currentPrice));
        
        // Print Support Levels
        if(supportCount > 0)
        {
            CV2EAUtils::DebugPrint("\nSUPPORT:");
            for(int i = 0; i < supportCount; i++)
            {
                double distance = MathAbs(currentPrice - supportLevels[i].price);
                string marker = (supportLevels[i].strength > 0.8) ? "⭐" : "";
                string arrow = (currentPrice > supportLevels[i].price) ? "↓" : " ";
                string distanceStr = StringFormat("%d pips", (int)(distance / _Point));
                
                CV2EAUtils::DebugPrint(StringFormat("%s %.5f (%s) | S:%.2f T:%d %s",
                    arrow,
                    supportLevels[i].price,
                    distanceStr,
                    supportLevels[i].strength,
                    supportLevels[i].touchCount,
                    marker));
            }
        }
        
        // Print Resistance Levels
        if(resistanceCount > 0)
        {
            CV2EAUtils::DebugPrint("\nRESISTANCE:");
            for(int i = 0; i < resistanceCount; i++)
            {
                double distance = MathAbs(currentPrice - resistanceLevels[i].price);
                string marker = (resistanceLevels[i].strength > 0.8) ? "⭐" : "";
                string arrow = (currentPrice < resistanceLevels[i].price) ? "↑" : " ";
                string distanceStr = StringFormat("%d pips", (int)(distance / _Point));
                
                CV2EAUtils::DebugPrint(StringFormat("%s %.5f (%s) | S:%.2f T:%d %s",
                    arrow,
                    resistanceLevels[i].price,
                    distanceStr,
                    resistanceLevels[i].strength,
                    resistanceLevels[i].touchCount,
                    marker));
            }
        }
        

    }
    
    void PrintSystemHealthReport()
    {
        if(!m_showDebugPrints) return;
        
        // Basic system health info
        CV2EAUtils::LogInfo(StringFormat(
            "\n=== SYSTEM HEALTH REPORT ===\n" +
            "Key Levels Found: %d\n" +
            "Last Update: %s\n" +
            "Chart Objects: %d",
            m_keyLevelCount,
            m_lastKeyLevelUpdate > 0 ? TimeToString(m_lastKeyLevelUpdate, TIME_DATE|TIME_MINUTES) : "Never",
            ArraySize(m_chartLines)));
    }
    
    void PrintTradeSetupAlert(const SKeyLevel &level, double distance)
    {
        if(!m_showDebugPrints) return;
        
        // Only alert if price is within 30 pips of the level
        if(distance > 0.0030) return;
        
        // Check last alert time for this level
        datetime lastAlertTime = 0;
        bool found = false;
        
        for(int i = 0; i < ArraySize(m_lastAlerts); i++)
        {
            if(MathAbs(m_lastAlerts[i].price - level.price) < m_touchZone)
            {
                lastAlertTime = m_lastAlerts[i].lastAlert;
                found = true;
                break;
            }
        }
        
        // Prevent alert spam by requiring minimum 5 minutes between alerts for same level
        datetime currentTime = TimeCurrent();
        if(found && currentTime - lastAlertTime < 300) return;
        
        // Alert for any valid level
        
        CV2EAUtils::LogInfo(StringFormat(
            "\n🔔 TRADE SETUP ALERT\n" +
            "Price approaching %s @ %.5f\n" +
            "Distance: %.1f pips\n" +
            "Level Strength: %.2f\n" +
            "Previous Touches: %d",
            level.isResistance ? "resistance" : "support",
            level.price,
            distance / _Point,
            level.strength,
            level.touchCount));
        
        // Update last alert time
        if(!found)
        {
            int size = ArraySize(m_lastAlerts);
            ArrayResize(m_lastAlerts, size + 1);
            m_lastAlerts[size].price = level.price;
            m_lastAlerts[size].lastAlert = currentTime;
        }
        else
        {
            for(int i = 0; i < ArraySize(m_lastAlerts); i++)
            {
                if(MathAbs(m_lastAlerts[i].price - level.price) < m_touchZone)
                {
                    m_lastAlerts[i].lastAlert = currentTime;
                    break;
                }
            }
        }
    }
    
    //--- Fixed chart line methods with proper MQL5 patterns
    void UpdateChartLines()
    {
        long chart_id = ChartID();  // Use actual chart ID instead of 0
        datetime currentTime = TimeCurrent();
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        CV2EAUtils::LogInfo(StringFormat("🔄 UpdateChartLines: Starting update for %d key levels", m_keyLevelCount));
        
        // Clear existing objects
        int deletedCount = ObjectsDeleteAll(chart_id, "KL_");
        if(deletedCount > 0)
        {
            CV2EAUtils::LogInfo(StringFormat("🗑️ Deleted %d existing chart objects", deletedCount));
            Sleep(200);
        }
        
        // Reset internal tracking
        ArrayFree(m_chartLines);
        ArrayResize(m_chartLines, 0);
        
        if(m_keyLevelCount == 0)
        {
            CV2EAUtils::LogInfo("ℹ️ No key levels to display");
            ChartRedraw(chart_id);
            return;
        }
        
        int successCount = 0;
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            string lineName = StringFormat("KL_%s_%.5f_%d", 
                m_currentKeyLevels[i].isResistance ? "R" : "S",
                m_currentKeyLevels[i].price,
                currentTime);
                    
            // Determine if this is above or below current price
            bool isAbovePrice = m_currentKeyLevels[i].price > currentPrice;
            
            // Determine line properties based on position and strength
            color lineColor;
            ENUM_LINE_STYLE lineStyle = STYLE_SOLID;
            int lineWidth;
            
            // Set line properties based on strength
            if(m_currentKeyLevels[i].strength >= 0.85) {
                lineColor = isAbovePrice ? clrRed : clrLime;
                lineWidth = 3;
            }
            else if(m_currentKeyLevels[i].strength >= 0.70) {
                lineColor = isAbovePrice ? clrOrange : clrAqua;
                lineWidth = 2;
            }
            else {
                lineColor = isAbovePrice ? clrPink : clrYellow;
                lineWidth = 1;
            }
            
            // Create chart object
            if(!ObjectCreate(chart_id, lineName, OBJ_HLINE, 0, 0, m_currentKeyLevels[i].price))
            {
                int error = GetLastError();
                CV2EAUtils::LogError(StringFormat("❌ ObjectCreate failed for %s at %.5f. Error: %d (%s)", 
                    lineName, m_currentKeyLevels[i].price, error, 
                    error == 4200 ? "Object already exists" : 
                    error == 4202 ? "Object does not exist" :
                    error == 4207 ? "Graphical object error" : "Unknown error"));
                continue;
            }
            
            // Set object properties
            bool propertySuccess = true;
            string failedProperty = "";
            
            if(!ObjectSetInteger(chart_id, lineName, OBJPROP_COLOR, lineColor))
            {
                propertySuccess = false;
                failedProperty = "COLOR";
            }
            else if(!ObjectSetInteger(chart_id, lineName, OBJPROP_STYLE, lineStyle))
            {
                propertySuccess = false;
                failedProperty = "STYLE";
            }
            else if(!ObjectSetInteger(chart_id, lineName, OBJPROP_WIDTH, lineWidth))
            {
                propertySuccess = false;
                failedProperty = "WIDTH";
            }
            else if(!ObjectSetInteger(chart_id, lineName, OBJPROP_BACK, false))
            {
                propertySuccess = false;
                failedProperty = "BACK";
            }
            else if(!ObjectSetInteger(chart_id, lineName, OBJPROP_SELECTABLE, false))
            {
                propertySuccess = false;
                failedProperty = "SELECTABLE";
            }
            else if(!ObjectSetInteger(chart_id, lineName, OBJPROP_HIDDEN, false))
            {
                propertySuccess = false;
                failedProperty = "HIDDEN";
            }
            else if(!ObjectSetInteger(chart_id, lineName, OBJPROP_RAY_RIGHT, true))
            {
                propertySuccess = false;
                failedProperty = "RAY_RIGHT";
            }
            else if(!ObjectSetInteger(chart_id, lineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS))
            {
                propertySuccess = false;
                failedProperty = "TIMEFRAMES";
            }
            
            if(!propertySuccess)
            {
                CV2EAUtils::LogError(StringFormat("❌ Property %s setting failed for %s. Error: %d", 
                    failedProperty, lineName, GetLastError()));
                ObjectDelete(chart_id, lineName);
                continue;
            }
            
            // Set tooltip
            string tooltip = StringFormat("%s Level: %.5f\nStrength: %.2f\nTouches: %d\nDistance: %d pips", 
                isAbovePrice ? "Resistance" : "Support",
                m_currentKeyLevels[i].price,
                m_currentKeyLevels[i].strength,
                m_currentKeyLevels[i].touchCount,
                (int)(MathAbs(m_currentKeyLevels[i].price - currentPrice) / _Point));
                
            if(!ObjectSetString(chart_id, lineName, OBJPROP_TOOLTIP, tooltip))
            {
                CV2EAUtils::LogError(StringFormat("⚠️ Tooltip setting failed for %s", lineName));
            }
            
            // Add to tracking array
            int size = ArraySize(m_chartLines);
            ArrayResize(m_chartLines, size + 1);
            
            m_chartLines[size].name = lineName;
            m_chartLines[size].price = m_currentKeyLevels[i].price;
            m_chartLines[size].lastUpdate = currentTime;
            m_chartLines[size].lineColor = lineColor;
            m_chartLines[size].isActive = true;
            
            successCount++;
            
            CV2EAUtils::LogInfo(StringFormat("✅ Successfully created line %s at %.5f (%s, strength %.2f, width %d)", 
                lineName, m_currentKeyLevels[i].price, 
                isAbovePrice ? "Resistance" : "Support", 
                m_currentKeyLevels[i].strength, lineWidth));
        }
        
        // Force chart redraw
        Sleep(100);
        ChartRedraw(chart_id);
        
        m_lastChartUpdate = currentTime;
        CV2EAUtils::LogInfo(StringFormat("✅ Chart update complete: %d/%d lines created successfully", 
            successCount, m_keyLevelCount));
            
        if(successCount != m_keyLevelCount)
        {
            CV2EAUtils::LogError(StringFormat("⚠️ Only %d out of %d key levels were successfully drawn", 
                successCount, m_keyLevelCount));
        }
        
        VerifyChartObjects(chart_id);
    }
    
    // Add verification method to ensure objects are actually visible
    void VerifyChartObjects(long chart_id)
    {
        int totalObjects = ObjectsTotal(chart_id, 0, OBJ_HLINE);
        int ourObjects = 0;
        
        for(int i = 0; i < totalObjects; i++)
        {
            string objName = ObjectName(chart_id, i, 0, OBJ_HLINE);
            if(StringFind(objName, "KL_") == 0)  // Starts with "KL_"
            {
                ourObjects++;
                double objPrice = ObjectGetDouble(chart_id, objName, OBJPROP_PRICE);
                bool isHidden = (bool)ObjectGetInteger(chart_id, objName, OBJPROP_HIDDEN);
                int timeframes = (int)ObjectGetInteger(chart_id, objName, OBJPROP_TIMEFRAMES);
                
                CV2EAUtils::LogInfo(StringFormat("🔍 Verified object %s: Price=%.5f, Hidden=%s, Timeframes=%d", 
                    objName, objPrice, isHidden ? "YES" : "NO", timeframes));
            }
        }
        
                 CV2EAUtils::LogInfo(StringFormat("🔍 Verification complete: Found %d key level objects out of %d total horizontal lines", 
             ourObjects, totalObjects));
     }
     
public:
     //--- Simplified diagnostic method
     void DiagnoseChartIssues()
     {
         if(!m_showDebugPrints) return;
         
         CV2EAUtils::LogInfo("🔧 CHART DIAGNOSTIC");
         CV2EAUtils::LogInfo(StringFormat("Symbol: %s | TF: %s | Levels: %d | Bars: %d", 
             _Symbol, EnumToString(Period()), m_keyLevelCount, Bars(_Symbol, Period())));
             
         // Show key levels (max 3)
         if(m_keyLevelCount > 0)
         {
             for(int i = 0; i < MathMin(m_keyLevelCount, 3); i++)
             {
                 CV2EAUtils::LogInfo(StringFormat("  Level %d: %.5f (%s, %.2f strength)", 
                     i+1, m_currentKeyLevels[i].price,
                     m_currentKeyLevels[i].isResistance ? "R" : "S",
                     m_currentKeyLevels[i].strength));
             }
         }
         else
         {
             CV2EAUtils::LogInfo("❌ No key levels found");
         }
         
         // Chart objects summary
         int ourObjects = 0;
         long chart_id = ChartID();
         int totalHLines = ObjectsTotal(chart_id, 0, OBJ_HLINE);
         for(int i = 0; i < totalHLines; i++)
         {
             string objName = ObjectName(chart_id, i, 0, OBJ_HLINE);
             if(StringFind(objName, "KL_") == 0) ourObjects++;
         }
         CV2EAUtils::LogInfo(StringFormat("Chart Lines: %d visible", ourObjects));
     }
    
    // Removed ClearInactiveChartLines - using simplified approach

    //--- Volume Detection Helper Methods
    double GetAverageVolume(const long &volumes[], int startIndex, int barsToAverage)
    {
        return CV2EAMarketDataBase::GetAverageVolume(volumes, startIndex, barsToAverage);
    }
    
    bool IsVolumeSpike(const long &volumes[], int index)
    {
        return CV2EAMarketDataBase::IsVolumeSpike(volumes, index);
    }
    
    double GetVolumeStrengthBonus(const long &volumes[], int index)
    {
        if(index < 0 || index >= ArraySize(volumes))
            return 0.0;
            
        double avgVolume = GetAverageVolume(volumes, index, VOLUME_LOOKBACK_BARS);
        if(avgVolume <= 0)
            return 0.0;
            
        double volumeRatio = (double)volumes[index] / avgVolume;
        
        // Return bonus based on volume ratio, capped at maximum
        if(volumeRatio >= VOLUME_SPIKE_MULTIPLIER)
        {
            double bonus = MathMin((volumeRatio - 1.0) * 0.1, VOLUME_STRENGTH_MAX_BONUS);
            
            if(m_showDebugPrints)
            {
                CV2EAUtils::LogInfo(StringFormat(
                    "Volume spike detected at bar %d:\n" +
                    "Current Volume: %d\n" +
                    "Average Volume: %.2f\n" +
                    "Ratio: %.2fx\n" +
                    "Strength Bonus: +%.1f%%",
                    index,
                    volumes[index],
                    avgVolume,
                    volumeRatio,
                    bonus * 100
                ));
            }
            
            return bonus;
        }
        
        return 0.0;
    }
    
    bool ValidateBounce(const double &prices[], double price, double level, double minBounceSize)
    {
        return CV2EAMarketDataBase::ValidateBounce(prices, price, level, minBounceSize);
    }
    
    bool IsTouchValid(double price, double level, double touchZone)
    {
        return CV2EAMarketDataBase::IsTouchValid(price, level, touchZone);
    }

    // Add this function before ProcessStrategy()
    bool IsKeyLevelValid(const SKeyLevel &level)
    {
        if(level.price <= 0 || level.touchCount < m_minTouches || level.strength < m_minStrength)
            return false;
            
        // Check if level is still within our lookback period
        datetime currentTime = TimeCurrent();
        
        // Use current timeframe instead of level's timeframe
        if(currentTime - level.lastTouch > PeriodSeconds(Period()) * m_lookbackPeriod)
            return false;
            
        return true;
    }


}; 