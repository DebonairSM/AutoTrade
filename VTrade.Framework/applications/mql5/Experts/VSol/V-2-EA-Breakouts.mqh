//+------------------------------------------------------------------+
//|                                              V-2-EA-Breakouts.mqh |
//|                                    Key Level Detection Implementation|
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include <Trade\Trade.mqh>
#include <VErrorDesc.mqh>  // Add this include for error descriptions
#include "V-2-EA-MarketData.mqh"  // Add this include for market data functions
#include "V-2-EA-KeyLevels.mqh"  // Add this include for key level detection

//+------------------------------------------------------------------+
//| Constants                                                          |
//+------------------------------------------------------------------+
#define DEFAULT_BUFFER_SIZE 100 // Default size for price buffers
#define DEFAULT_DEBUG_INTERVAL 300 // Default debug interval (5 minutes)
#define ERR_OBJECT_DOES_NOT_EXIST 4202 // MQL5 error code for non-existent object

//+------------------------------------------------------------------+
//| Structure Definitions                                              |
//+------------------------------------------------------------------+
// Note: SKeyLevel is defined in V-2-EA-MarketData.mqh

struct SStrategyState
{
    bool      keyLevelFound;    // Whether a valid key level was found
    SKeyLevel activeKeyLevel;   // Currently active key level
    datetime  lastUpdate;       // Last time the state was updated
    
    void Reset()
    {
        keyLevelFound = false;
        lastUpdate = 0;
    }
};

//--- Level Performance Tracking
struct SLevelPerformance
{
    int successfulBounces;    // Number of times price respected the level
    int falseBreaks;         // Number of times price broke but returned
    int trueBreaks;          // Number of times price broke decisively
    double avgBounceSize;    // Average size of bounces from this level
    double successRate;      // Ratio of successful bounces to total tests
    
    void Reset()
    {
        successfulBounces = 0;
        falseBreaks = 0;
        trueBreaks = 0;
        avgBounceSize = 0;
        successRate = 0;
    }
};

//--- System Health Tracking
struct SSystemHealth
{
    int missedOpportunities;  // Clear levels that weren't detected
    int falseSignals;        // Invalid levels that were detected
    double detectionRate;     // Ratio of correct detections to total
    double noiseRatio;       // Ratio of false signals to valid signals
    datetime lastUpdate;      // Last time health metrics were updated
    
    void Reset()
    {
        missedOpportunities = 0;
        falseSignals = 0;
        detectionRate = 0;
        noiseRatio = 0;
        lastUpdate = 0;
    }
};

// Add after other struct definitions
struct SChartLine
{
    string name;        // Unique line name
    double price;      // Price level
    datetime lastUpdate; // Last update time
    color lineColor;   // Line color
    bool isActive;     // Whether line is currently shown
    string labelName;   // Name of associated text label
};

struct STouchQuality {
    int touchCount;
    double avgBounceStrength;
    double avgBounceVolume;
    double maxBounceSize;
    int quickestBounce;
    int slowestBounce;
};

//+------------------------------------------------------------------+
//| Key Level Detection Class                                          |
//+------------------------------------------------------------------+
class CV2EABreakouts : public CV2EAMarketDataBase
{
private:
    //--- Key Level Handler
    CV2EAKeyLevels m_keyLevelHandler;  ///< Handles key level detection and processing
    
    //--- Strategy State
    SStrategyState m_state;            ///< Current strategy state
    
    //--- Chart Line Management
    SChartLine m_chartLines[];  ///< Array to track chart lines
    datetime m_lastChartUpdate; ///< Last chart update time
    
    //--- System Health Tracking
    SSystemHealth m_systemHealth;  ///< Track system health
    
    //--- Level Performance Tracking
    SLevelPerformance m_levelPerformance;  ///< Track level performance
    
    //--- Key level history
    double m_recentBreaks[];              ///< Store recent level breaks
    datetime m_recentBreakTimes[];        ///< Times of recent breaks
    int m_recentBreakCount;               ///< Count of recent breaks
    
    struct SAlertTime
    {
        double price;
        datetime lastAlert;
    };
    SAlertTime m_lastAlerts[];  ///< Array to track last alert times for each level
    
    //--- Debug settings
    bool m_initialized;      ///< Initialization state
    bool m_showDebugPrints; ///< Whether to show debug prints

public:
    //--- Constructor and destructor
    CV2EABreakouts(void) : m_initialized(false),
                           m_recentBreakCount(0),
                           m_lastChartUpdate(0)
    {
        // Initialize arrays with proper error checking
        if(!ArrayResize(m_chartLines, DEFAULT_BUFFER_SIZE))
        {
            Print("❌ [CV2EABreakouts::Constructor] Failed to initialize chart lines array");
            return;
        }
        
        if(!ArrayResize(m_recentBreaks, DEFAULT_BUFFER_SIZE) ||
           !ArrayResize(m_recentBreakTimes, DEFAULT_BUFFER_SIZE))
        {
            Print("❌ [CV2EABreakouts::Constructor] Failed to initialize recent breaks arrays");
            return;
        }
        
        if(!ArrayResize(m_lastAlerts, DEFAULT_BUFFER_SIZE))
        {
            Print("❌ [CV2EABreakouts::Constructor] Failed to initialize last alerts array");
            return;
        }
        
        m_state.Reset();
    }
    
    ~CV2EABreakouts(void)
    {
        // Clear all chart objects created by this EA
        for(int i = 0; i < ArraySize(m_chartLines); i++)
        {
            ObjectDelete(0, m_chartLines[i].name);
        }
    }
    
    //--- Initialization
    bool Init(int lookbackPeriod, double minStrength, double touchZone, int minTouches, bool showDebugPrints)
    {
        m_showDebugPrints = showDebugPrints;
        
        // Initialize key level handler with symbol-specific settings
        if(!m_keyLevelHandler.Init(_Symbol, lookbackPeriod, minStrength, touchZone, minTouches, showDebugPrints))
        {
            Print("❌ [CV2EABreakouts::Init] Failed to initialize key level handler");
            return false;
        }
        
        m_initialized = true;
        Print("✅ [CV2EABreakouts::Init] Configuration complete for ", _Symbol);
        return true;
    }
    
    //--- Main Strategy Method
    void ProcessStrategy()
    {
        if(!m_initialized)
        {
            DebugPrint("❌ Strategy not initialized");
            return;
        }
        
        datetime currentTime = TimeCurrent();
        
        // Step 1: Key Level Identification
        SKeyLevel strongestLevel;
        bool foundKeyLevel = m_keyLevelHandler.FindKeyLevels(strongestLevel);
        
        // Update system state
        if(foundKeyLevel)
        {
            // If we found a new key level that's significantly different from our active one
            if(!m_state.keyLevelFound || 
               MathAbs(strongestLevel.price - m_state.activeKeyLevel.price) > m_keyLevelHandler.GetTouchZone())
            {
                // Update strategy state with new key level
                m_state.keyLevelFound = true;
                m_state.activeKeyLevel = strongestLevel;
                m_state.lastUpdate = currentTime;
                
                // Print key levels report when we find a new significant level
                m_keyLevelHandler.PrintKeyLevelsReport();
            }
        }
        else if(m_state.keyLevelFound)
        {
            // If we had a key level but can't find it anymore, reset state
            DebugPrint("ℹ️ Previous key level no longer valid, resetting state");
            m_state.Reset();
        }
        
        // Step 2: Check for price approaching key levels
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        for(int i = 0; i < m_keyLevelHandler.GetKeyLevelCount(); i++)
        {
            SKeyLevel level;
            if(m_keyLevelHandler.GetKeyLevel(i, level))
            {
                double distance = MathAbs(currentPrice - level.price);
                if(distance <= m_keyLevelHandler.GetTouchZone() * 2) // Alert when price is within 2x the touch zone
                {
                    PrintTradeSetupAlert(level, distance);
                }
            }
        }
        
        // Step 3: Update and print system health report (hourly)
        PrintSystemHealthReport();
        
        // Step 4: Update chart lines - Force update on each call
        m_lastChartUpdate = 0; // Reset last update time to force update
        UpdateChartLines();
    }
    
    //--- Test-specific methods
    bool TEST_GetKeyLevel(int index, SKeyLevel &level) const
    {
        return m_keyLevelHandler.GetKeyLevel(index, level);
    }
    
    int TEST_GetKeyLevelCount() const
    {
        return m_keyLevelHandler.GetKeyLevelCount();
    }
    
    double TEST_GetMinStrength() const
    {
        return m_keyLevelHandler.GetMinStrength();
    }
    
    double TEST_GetTouchZone() const
    {
        return m_keyLevelHandler.GetTouchZone();
    }
    
    int TEST_GetMinTouches() const
    {
        return m_keyLevelHandler.GetMinTouches();
    }
    
    bool TEST_IsUS500()
    {
        return IsUS500();
    }

private:
    //--- Helper Methods
    void DebugPrint(string message)
    {
        if(!m_showDebugPrints)
            return;
            
        // Add timestamp and current price to debug messages
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        Print(StringFormat("[%s] [%.5f] %s", timestamp, currentPrice, message));
    }
    
    //+------------------------------------------------------------------+
    //| Print trade setup alert when price approaches key level            |
    //+------------------------------------------------------------------+
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
            if(MathAbs(m_lastAlerts[i].price - level.price) < m_keyLevelHandler.GetTouchZone())
            {
                lastAlertTime = m_lastAlerts[i].lastAlert;
                found = true;
                break;
            }
        }
        
        // Prevent alert spam by requiring minimum 5 minutes between alerts for same level
        datetime currentTime = TimeCurrent();
        if(found && currentTime - lastAlertTime < 300) return;
        
        // Only alert if level has some proven success
        if(m_levelPerformance.successRate < 0.30) return;
        
        DebugPrint(StringFormat(
            "\n🔔 TRADE SETUP ALERT\n" +
            "Price approaching %s @ %.5f\n" +
            "Distance: %.1f pips\n" +
            "Level Strength: %.2f\n" +
            "Previous Touches: %d\n" +
            "Success Rate: %.1f%%",
            level.isResistance ? "resistance" : "support",
            level.price,
            distance / _Point,
            level.strength,
            level.touchCount,
            m_levelPerformance.successRate * 100));
        
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
                if(MathAbs(m_lastAlerts[i].price - level.price) < m_keyLevelHandler.GetTouchZone())
                {
                    m_lastAlerts[i].lastAlert = currentTime;
                    break;
                }
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Update chart lines to visualize key levels                          |
    //+------------------------------------------------------------------+
    void UpdateChartLines()
    {
        // Only update if enough time has passed (prevent excessive updates)
        datetime currentTime = TimeCurrent();
        if(currentTime - m_lastChartUpdate < 1) return;  // Update at most once per second
        
        // Clear old lines first
        for(int i = 0; i < ArraySize(m_chartLines); i++)
        {
            if(m_chartLines[i].isActive)
            {
                ObjectDelete(0, m_chartLines[i].name);
                ObjectDelete(0, m_chartLines[i].labelName);
                m_chartLines[i].isActive = false;
            }
        }
        
        // Create lines for current key levels
        for(int i = 0; i < m_keyLevelHandler.GetKeyLevelCount(); i++)
        {
            SKeyLevel level;
            if(!m_keyLevelHandler.GetKeyLevel(i, level)) continue;
            
            // Generate unique names for the line and label
            string lineName = StringFormat("KL_%s_%d", _Symbol, i);
            string labelName = StringFormat("KL_Label_%s_%d", _Symbol, i);
            
            // Set line color based on level type and strength
            color lineColor;
            if(level.isResistance)
            {
                if(level.strength >= 0.80) lineColor = clrCrimson;
                else if(level.strength >= 0.60) lineColor = clrRed;
                else lineColor = clrPink;
            }
            else
            {
                if(level.strength >= 0.80) lineColor = clrForestGreen;
                else if(level.strength >= 0.60) lineColor = clrGreen;
                else lineColor = clrLimeGreen;
            }
            
            // Create horizontal line
            if(!ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, level.price))
            {
                Print("❌ Failed to create line object: ", GetLastError());
                continue;
            }
            
            // Set line properties
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, level.strength >= 0.80 ? STYLE_SOLID : STYLE_DOT);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, level.strength >= 0.80 ? 2 : 1);
            ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            
            // Create label
            if(!ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, level.price))
            {
                Print("❌ Failed to create label object: ", GetLastError());
                continue;
            }
            
            // Format label text
            string labelText = StringFormat("%s %.4f [%.0f%%]", 
                level.isResistance ? "R" : "S",
                level.price,
                level.strength * 100);
            
            // Set label properties
            ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
            
            // Store line info
            m_chartLines[i].name = lineName;
            m_chartLines[i].labelName = labelName;
            m_chartLines[i].price = level.price;
            m_chartLines[i].lineColor = lineColor;
            m_chartLines[i].lastUpdate = currentTime;
            m_chartLines[i].isActive = true;
        }
        
        // Force chart update
        ChartRedraw(0);
        m_lastChartUpdate = currentTime;
    }
    
    //+------------------------------------------------------------------+
    //| Print system health report                                         |
    //+------------------------------------------------------------------+
    void PrintSystemHealthReport()
    {
        if(!m_showDebugPrints) return;
        
        datetime currentTime = TimeCurrent();
        
        // Only update hourly
        if(currentTime - m_systemHealth.lastUpdate < 3600) return;
        
        // Calculate detection rate
        int totalSignals = m_systemHealth.missedOpportunities + m_keyLevelHandler.GetKeyLevelCount();
        if(totalSignals > 0)
        {
            m_systemHealth.detectionRate = (double)m_keyLevelHandler.GetKeyLevelCount() / totalSignals;
        }
        
        // Calculate noise ratio
        int totalValidations = m_systemHealth.falseSignals + m_keyLevelHandler.GetKeyLevelCount();
        if(totalValidations > 0)
        {
            m_systemHealth.noiseRatio = (double)m_systemHealth.falseSignals / totalValidations;
        }
        
        // Calculate level performance metrics
        if(m_levelPerformance.successfulBounces + m_levelPerformance.falseBreaks + m_levelPerformance.trueBreaks > 0)
        {
            m_levelPerformance.successRate = (double)m_levelPerformance.successfulBounces / 
                (m_levelPerformance.successfulBounces + m_levelPerformance.falseBreaks + m_levelPerformance.trueBreaks);
        }
        
        DebugPrint(StringFormat(
            "\n📊 SYSTEM HEALTH REPORT\n" +
            "Active Key Levels: %d\n" +
            "Detection Rate: %.1f%%\n" +
            "Noise Ratio: %.1f%%\n" +
            "Level Performance:\n" +
            "  - Successful Bounces: %d\n" +
            "  - False Breaks: %d\n" +
            "  - True Breaks: %d\n" +
            "  - Success Rate: %.1f%%\n" +
            "  - Avg Bounce Size: %.1f pips",
            m_keyLevelHandler.GetKeyLevelCount(),
            m_systemHealth.detectionRate * 100,
            m_systemHealth.noiseRatio * 100,
            m_levelPerformance.successfulBounces,
            m_levelPerformance.falseBreaks,
            m_levelPerformance.trueBreaks,
            m_levelPerformance.successRate * 100,
            m_levelPerformance.avgBounceSize / _Point
        ));
        
        m_systemHealth.lastUpdate = currentTime;
    }
}; 