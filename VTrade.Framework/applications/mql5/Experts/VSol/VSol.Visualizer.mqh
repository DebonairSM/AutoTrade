//+------------------------------------------------------------------+
//|                                          V-2-EA-Visualizer.mqh |
//|                                   Visualization Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.0.3"  // Aligned with main EA version

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//--- Version Info
#define VSOL_VISUALIZER_VERSION      "1.0.3"
#define VSOL_VISUALIZER_BUILD_DATE   "2024-03-19"
#define VSOL_VISUALIZER_DESCRIPTION  "Added version tracking and improved crypto visualization"

//--- Visualization Constants
#define VIS_MAX_OBJECTS          1000   // Maximum chart objects
#define VIS_CLEANUP_INTERVAL     3600   // Object cleanup interval (seconds)
#define VIS_MAX_LABELS           100    // Maximum text labels
#define VIS_MAX_LINES           200    // Maximum trend/level lines
#define VIS_MAX_ZONES           50     // Maximum zones/rectangles
#define VIS_HISTORY_BARS        500    // Bars to maintain visuals
#define VIS_UPDATE_INTERVAL     1      // Visual update interval (seconds)
#define VIS_MAX_ALERTS         50     // Maximum active alerts

//--- Visual Object Types
enum ENUM_VISUAL_OBJECT
{
    VISUAL_OBJECT_NONE = 0,     // No specific object
    VISUAL_OBJECT_LINE,         // Trend/Level line
    VISUAL_OBJECT_ZONE,         // Price zone/rectangle
    VISUAL_OBJECT_LABEL,        // Text label
    VISUAL_OBJECT_ARROW,        // Direction arrow
    VISUAL_OBJECT_MARKER       // Point marker
};

//--- Visual Style Types
enum ENUM_VISUAL_STYLE
{
    STYLE_NONE = 0,            // No specific style
    STYLE_BREAKOUT,            // Breakout level style
    STYLE_SUPPORT,             // Support level style
    STYLE_RESISTANCE,          // Resistance level style
    STYLE_ENTRY,              // Entry point style
    STYLE_EXIT,               // Exit point style
    STYLE_WARNING            // Warning indicator style
};

//--- Visual State Structure
struct SVisualState
{
    int               objectCount;        // Current object count
    int               labelCount;         // Current label count
    int               lineCount;          // Current line count
    int               zoneCount;          // Current zone count
    datetime          lastCleanup;        // Last cleanup time
    bool              isUpdating;         // Update in progress
    string            lastError;          // Last error message
    
    void Reset()
    {
        objectCount = 0;
        labelCount = 0;
        lineCount = 0;
        zoneCount = 0;
        lastCleanup = 0;
        isUpdating = false;
        lastError = "";
    }
};

//--- Chart Object Structure
struct SChartObject
{
    string            name;               // Object name
    ENUM_VISUAL_OBJECT type;             // Object type
    ENUM_VISUAL_STYLE style;             // Visual style
    datetime          createTime;         // Creation time
    datetime          expiryTime;         // Expiry time
    color            objectColor;        // Object color
    int              objectWidth;        // Line width/size
    ENUM_LINE_STYLE  lineStyle;          // Line style
    bool             selected;           // Selection state
    bool             hidden;             // Visibility state
    string           description;        // Object description
    
    void Reset()
    {
        name = "";
        type = VISUAL_OBJECT_NONE;
        style = STYLE_NONE;
        createTime = 0;
        expiryTime = 0;
        objectColor = clrNONE;
        objectWidth = 1;
        lineStyle = STYLE_SOLID;
        selected = false;
        hidden = false;
        description = "";
    }
};

//+------------------------------------------------------------------+
//| Main Visualizer Class                                              |
//+------------------------------------------------------------------+
class CV2EABreakoutVisualizer : public CV2EAMarketDataBase
{
private:
    //--- State Management
    SVisualState        m_visualState;     // Visual state tracking
    SChartObject        m_objects[];       // Object registry
    ENUM_MARKET_TYPE    m_marketType;      // Current market type
    
    //--- Configuration
    int                m_maxObjects;       // Maximum allowed objects
    int                m_cleanupInterval;  // Cleanup interval
    int                m_historyBars;      // Visual history bars
    int                m_updateInterval;   // Update frequency
    
    //--- Style Configuration
    color              m_breakoutColor;    // Breakout level color
    color              m_supportColor;     // Support level color
    color              m_resistanceColor;  // Resistance level color
    color              m_entryColor;       // Entry marker color
    color              m_exitColor;        // Exit marker color
    color              m_warningColor;     // Warning indicator color
    
    //--- Private Methods
    double             GetScaledPrice(const double price, const double baseOffset)
    {
        return price + CVSolMarketScaling::GetScaledVisualizationOffset(baseOffset, price, m_marketType);
    }
    
    double             GetScaledZone(const double price, const double baseZone)
    {
        return CVSolMarketScaling::GetScaledTouchZone(baseZone, price, m_marketType);
    }
    
    double             GetScaledBounce(const double price, const double baseBounce)
    {
        return CVSolMarketScaling::GetScaledBounceSize(baseBounce, price, m_marketType);
    }
    
    bool               RegisterObject(const string name, const ENUM_VISUAL_OBJECT type);
    bool               UnregisterObject(const string name);
    void               CleanupObjects();
    bool               ValidateObjectLimit();
    string             GenerateObjectName(const ENUM_VISUAL_OBJECT type);
    void               UpdateObjectRegistry();
    
protected:
    //--- Protected utility methods
    virtual bool       IsObjectValid(const string name);
    virtual bool       CanAddObject();
    virtual void       HandleObjectError(const string error);
    virtual bool       UpdateObjectStyle(const string name, const ENUM_VISUAL_STYLE style);

public:
    //--- Constructor and Destructor
    CV2EABreakoutVisualizer(void) : m_marketType(MARKET_TYPE_UNKNOWN) {}
    
    //--- Initialization and Configuration
    virtual bool Initialize(void)
    {
        if(!CV2EAMarketDataBase::Initialize())
            return false;
            
        // Determine market type based on symbol
        m_marketType = CVSolMarketBase::GetMarketType(Symbol());
        
        if(m_marketType == MARKET_TYPE_UNKNOWN)
        {
            Print("Warning: Unknown market type for symbol ", Symbol());
            m_marketType = MARKET_TYPE_FOREX; // Default to forex
        }
        
        // Log initialization with version and market type
        Print("=== VSol Visualizer v", VSOL_VISUALIZER_VERSION, " (", VSOL_VISUALIZER_BUILD_DATE, ") ===");
        Print("Changes: ", VSOL_VISUALIZER_DESCRIPTION);
        Print("Symbol: ", Symbol());
        Print("Calculation Mode: ", CVSolMarketBase::GetCalcModeDescription(Symbol()));
        Print("Market Type: ", EnumToString(m_marketType));
        
        if(m_marketType == MARKET_TYPE_CRYPTO)
        {
            double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            double touchZone = GetScaledZone(currentPrice, 50.0);
            double bounceSize = GetScaledBounce(currentPrice, 30.0);
            
            Print("Configuring crypto settings for ", Symbol(), ":");
            Print("Current Price: $", NormalizeDouble(currentPrice, 2));
            Print("Touch Zone: $", NormalizeDouble(touchZone, 2), 
                  " (", NormalizeDouble(touchZone/currentPrice*100, 2), "%)");
            Print("Min Bounce: $", NormalizeDouble(bounceSize, 2),
                  " (", NormalizeDouble(bounceSize/currentPrice*100, 2), "%)");
            Print("Initializing Market Data Base");
            Print("Forex settings initialized with debug prints enabled");
            
            // Use consistent pip values for all timeframes
            double pipValue = 0.01;
            double touchZonePips = 50000.0;  // 500.0 price
            double bounceSizePips = 25000.0; // 250.0 price
            
            Print("UpdatePipValues: Symbol=", Symbol(), 
                  ", Digits=", SymbolInfoInteger(Symbol(), SYMBOL_DIGITS),
                  ", PipValue=", pipValue,
                  ", Point=", SymbolInfoDouble(Symbol(), SYMBOL_POINT),
                  ", Bid=", NormalizeDouble(currentPrice, 2),
                  ", TouchZone[M15]=", touchZonePips, " pips",
                  ", BounceSize[M15]=", bounceSizePips, " pips",
                  ", 1 pip = ", pipValue, " (1.0 points)");
            Print("InitForex: Symbol=", Symbol(),
                  ", PipValue=", pipValue,
                  ", Digits=", SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
            Print("Configuring Forex settings: TouchZone=", touchZonePips,
                  " pips (", NormalizeDouble(touchZone, 1), " price), MinBounce=",
                  bounceSizePips, " pips (", NormalizeDouble(bounceSize, 1), " price)");
            Print("Using Crypto settings:");
            Print("Touch Zone: $", NormalizeDouble(touchZone, 2));
            Print("Min Bounce: $", NormalizeDouble(bounceSize, 2));
            Print("Initializing EA on ", EnumToString(Period()), " timeframe (", PeriodSeconds(Period())/60, " minutes)");
        }
            
        return true;
    }
    
    //--- Style Configuration Methods
    virtual void       ConfigureColors(
                           const color breakout,
                           const color support,
                           const color resistance,
                           const color entry,
                           const color exit,
                           const color warning
                       );
    
    //--- Level Visualization Methods with Market-Aware Scaling
    virtual bool DrawBreakoutLevel(const double price, const datetime time, const string label = "")
    {
        double scaledZone = GetScaledZone(price, 50.0); // Base zone of 50 points
        double upperPrice = price + scaledZone;
        double lowerPrice = price - scaledZone;
        
        // Draw the main breakout level
        if(!ObjectCreate(0, label + "_main", OBJ_TREND, 0, time, price, time + PeriodSeconds(PERIOD_D1), price))
            return false;
            
        ObjectSetInteger(0, label + "_main", OBJPROP_COLOR, m_breakoutColor);
        ObjectSetInteger(0, label + "_main", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, label + "_main", OBJPROP_WIDTH, 2);
        
        // Draw the zone boundaries
        ObjectCreate(0, label + "_upper", OBJ_TREND, 0, time, upperPrice, time + PeriodSeconds(PERIOD_D1), upperPrice);
        ObjectCreate(0, label + "_lower", OBJ_TREND, 0, time, lowerPrice, time + PeriodSeconds(PERIOD_D1), lowerPrice);
        
        ObjectSetInteger(0, label + "_upper", OBJPROP_COLOR, m_breakoutColor);
        ObjectSetInteger(0, label + "_lower", OBJPROP_COLOR, m_breakoutColor);
        ObjectSetInteger(0, label + "_upper", OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, label + "_lower", OBJPROP_STYLE, STYLE_DOT);
        
        // Add zone fill if it's a crypto market
        if(m_marketType == MARKET_TYPE_CRYPTO)
        {
            string zoneName = label + "_zone";
            ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, time, upperPrice, time + PeriodSeconds(PERIOD_D1), lowerPrice);
            ObjectSetInteger(0, zoneName, OBJPROP_COLOR, m_breakoutColor);
            ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
            ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
            ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, ColorToARGB(m_breakoutColor, 10)); // 10% opacity
        }
        
        return true;
    }
    
    virtual bool DrawSupportLevel(const double price, const datetime time, const string label = "")
    {
        double scaledZone = GetScaledZone(price, 30.0); // Base zone of 30 points
        double lowerPrice = price - scaledZone;
        
        if(!ObjectCreate(0, label, OBJ_TREND, 0, time, price, time + PeriodSeconds(PERIOD_D1), price))
            return false;
            
        ObjectSetInteger(0, label, OBJPROP_COLOR, m_supportColor);
        ObjectSetInteger(0, label, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, label, OBJPROP_WIDTH, 2);
        
        // Draw support zone
        ObjectCreate(0, label + "_zone", OBJ_TREND, 0, time, lowerPrice, time + PeriodSeconds(PERIOD_D1), lowerPrice);
        ObjectSetInteger(0, label + "_zone", OBJPROP_COLOR, m_supportColor);
        ObjectSetInteger(0, label + "_zone", OBJPROP_STYLE, STYLE_DOT);
        
        // Add zone fill for crypto
        if(m_marketType == MARKET_TYPE_CRYPTO)
        {
            string zoneName = label + "_fill";
            ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, time, price, time + PeriodSeconds(PERIOD_D1), lowerPrice);
            ObjectSetInteger(0, zoneName, OBJPROP_COLOR, m_supportColor);
            ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
            ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
            ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, ColorToARGB(m_supportColor, 10)); // 10% opacity
        }
        
        return true;
    }
    
    virtual bool DrawResistanceLevel(const double price, const datetime time, const string label = "")
    {
        double scaledZone = GetScaledZone(price, 30.0); // Base zone of 30 points
        double upperPrice = price + scaledZone;
        
        if(!ObjectCreate(0, label, OBJ_TREND, 0, time, price, time + PeriodSeconds(PERIOD_D1), price))
            return false;
            
        ObjectSetInteger(0, label, OBJPROP_COLOR, m_resistanceColor);
        ObjectSetInteger(0, label, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, label, OBJPROP_WIDTH, 2);
        
        // Draw resistance zone
        ObjectCreate(0, label + "_zone", OBJ_TREND, 0, time, upperPrice, time + PeriodSeconds(PERIOD_D1), upperPrice);
        ObjectSetInteger(0, label + "_zone", OBJPROP_COLOR, m_resistanceColor);
        ObjectSetInteger(0, label + "_zone", OBJPROP_STYLE, STYLE_DOT);
        
        // Add zone fill for crypto
        if(m_marketType == MARKET_TYPE_CRYPTO)
        {
            string zoneName = label + "_fill";
            ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, time, upperPrice, time + PeriodSeconds(PERIOD_D1), price);
            ObjectSetInteger(0, zoneName, OBJPROP_COLOR, m_resistanceColor);
            ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
            ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
            ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, ColorToARGB(m_resistanceColor, 10)); // 10% opacity
        }
        
        return true;
    }
    
    //--- Trade Visualization Methods
    virtual bool       MarkEntryPoint(
                           const double price,
                           const datetime time,
                           const string label = ""
                       );
    virtual bool       MarkExitPoint(
                           const double price,
                           const datetime time,
                           const string label = ""
                       );
    virtual bool       DrawTradeLine(
                           const double entryPrice,
                           const double exitPrice,
                           const datetime entryTime,
                           const datetime exitTime
                       );
    
    //--- Pattern Visualization Methods
    virtual bool       DrawBreakoutPattern(
                           const double &prices[],
                           const datetime &times[],
                           const string label = ""
                       );
    virtual bool       HighlightRetestZone(
                           const double upperPrice,
                           const double lowerPrice,
                           const datetime startTime,
                           const datetime endTime
                       );
    
    //--- Information Display Methods
    virtual bool       ShowTradeInfo(
                           const string info,
                           const int corner = CORNER_RIGHT_UPPER
                       );
    virtual bool       ShowAlert(
                           const string message,
                           const color messageColor = clrYellow
                       );
    virtual bool       UpdatePerformanceDisplay(
                           const double winRate,
                           const double profitFactor,
                           const double drawdown
                       );
    
    //--- Object Management Methods
    virtual bool       RemoveObject(const string name);
    virtual bool       RemoveAllObjects();
    virtual bool       HideObject(const string name);
    virtual bool       ShowObject(const string name);
    virtual bool       UpdateObject(
                           const string name,
                           const color newColor,
                           const int newWidth = 0
                       );
    
    //--- Utility Methods
    virtual void       GetVisualState(SVisualState &state) const;
    virtual int        GetObjectCount() const;
    virtual bool       ExportChartTemplate(const string filename);
    virtual bool       LoadChartTemplate(const string filename);
    virtual string     GetLastError() const;
    
    //--- Event Handlers
    virtual void       OnChartEvent(
                           const int id,
                           const long &lparam,
                           const double &dparam,
                           const string &sparam
                       );
    virtual void       OnObjectClick(const string name);
    virtual void       OnObjectDrag(const string name);
    virtual void       OnObjectDelete(const string name);
}; 