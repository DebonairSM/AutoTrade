//+------------------------------------------------------------------+
//|                                          V-2-EA-Visualizer.mqh |
//|                                   Visualization Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

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
    CV2EABreakoutVisualizer(void);
    ~CV2EABreakoutVisualizer(void);
    
    //--- Initialization and Configuration
    virtual bool       Initialize(void);
    virtual void       ConfigureVisualizer(
                           const int maxObj,
                           const int cleanupInt,
                           const int historyBars
                       );
    
    //--- Style Configuration Methods
    virtual void       ConfigureColors(
                           const color breakout,
                           const color support,
                           const color resistance,
                           const color entry,
                           const color exit,
                           const color warning
                       );
    
    //--- Level Visualization Methods
    virtual bool       DrawBreakoutLevel(
                           const double price,
                           const datetime time,
                           const string label = ""
                       );
    virtual bool       DrawSupportLevel(
                           const double price,
                           const datetime time,
                           const string label = ""
                       );
    virtual bool       DrawResistanceLevel(
                           const double price,
                           const datetime time,
                           const string label = ""
                       );
    
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