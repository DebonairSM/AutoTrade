//+------------------------------------------------------------------+
//| GrandeEventBus.mqh                                               |
//| Copyright 2024, Grande Tech                                      |
//| Event-Driven Communication Between Components                    |
//+------------------------------------------------------------------+
// PURPOSE:
//   Provide decoupled event-driven communication between system components.
//   Enables components to publish and subscribe to events without direct dependencies.
//
// RESPONSIBILITIES:
//   - Publish events to subscribers
//   - Manage event subscriptions
//   - Queue events for async processing
//   - Log events for debugging and auditing
//   - Filter and route events
//
// DEPENDENCIES:
//   - None (base infrastructure)
//
// STATE MANAGED:
//   - Event queue
//   - Event subscriptions
//   - Event history
//
// PUBLIC INTERFACE:
//   void PublishEvent(EVENT_TYPE type, string data, double value)
//   bool SubscribeToEvent(EVENT_TYPE type, EventHandler* handler)
//   SystemEvent[] GetEvents(EVENT_TYPE filter)
//   void ClearEvents()
//
// BENEFITS:
//   - Decoupled component communication
//   - Easy to add logging/monitoring
//   - Clear audit trail
//   - Facilitates debugging
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestEventBus.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Event Type Enumeration                                            |
//+------------------------------------------------------------------+
enum EVENT_TYPE
{
    EVENT_SYSTEM_INIT,          // System initialized
    EVENT_SYSTEM_DEINIT,        // System shutting down
    EVENT_REGIME_CHANGED,       // Market regime changed
    EVENT_KEY_LEVEL_DETECTED,   // New key level detected
    EVENT_KEY_LEVEL_UPDATED,    // Key level updated
    EVENT_SIGNAL_GENERATED,     // Trading signal generated
    EVENT_SIGNAL_VALIDATED,     // Signal validation completed
    EVENT_SIGNAL_REJECTED,      // Signal rejected
    EVENT_ORDER_PLACED,         // Order placed
    EVENT_ORDER_FILLED,         // Order filled
    EVENT_ORDER_CANCELLED,      // Order cancelled
    EVENT_ORDER_FAILED,         // Order placement failed
    EVENT_POSITION_OPENED,      // Position opened
    EVENT_POSITION_MODIFIED,    // Position modified
    EVENT_POSITION_CLOSED,      // Position closed
    EVENT_STOP_LOSS_HIT,        // Stop loss triggered
    EVENT_TAKE_PROFIT_HIT,      // Take profit triggered
    EVENT_BREAKEVEN_MOVED,      // Stop moved to breakeven
    EVENT_TRAILING_STOP_MOVED,  // Trailing stop moved
    EVENT_PARTIAL_CLOSE,        // Partial position close
    EVENT_RISK_WARNING,         // Risk warning triggered
    EVENT_MARGIN_WARNING,       // Margin warning
    EVENT_MARGIN_CRITICAL,      // Margin critical
    EVENT_DRAWDOWN_WARNING,     // Drawdown warning
    EVENT_COMPONENT_ERROR,      // Component error occurred
    EVENT_COMPONENT_RECOVERED,  // Component recovered
    EVENT_DATABASE_ERROR,       // Database error
    EVENT_NETWORK_ERROR,        // Network/connection error
    EVENT_DATA_COLLECTED,       // Data collection completed
    EVENT_REPORT_GENERATED,     // Report generated
    EVENT_HEALTH_CHECK,         // Health check performed
    EVENT_CONFIG_CHANGED,       // Configuration changed
    EVENT_USER_ACTION,          // User action/keyboard input
    EVENT_CUSTOM                // Custom event
};

//+------------------------------------------------------------------+
//| System Event Structure                                            |
//+------------------------------------------------------------------+
struct SystemEvent
{
    EVENT_TYPE type;
    datetime timestamp;
    string data;
    double value;
    string source;              // Component that published the event
    int severity;               // 0=info, 1=warning, 2=error, 3=critical
    
    void SystemEvent()
    {
        type = EVENT_CUSTOM;
        timestamp = 0;
        data = "";
        value = 0.0;
        source = "";
        severity = 0;
    }
    
    // Create info event
    static SystemEvent Info(EVENT_TYPE t, string src, string msg, double val = 0.0)
    {
        SystemEvent e;
        e.type = t;
        e.timestamp = TimeCurrent();
        e.data = msg;
        e.value = val;
        e.source = src;
        e.severity = 0;
        return e;
    }
    
    // Create warning event
    static SystemEvent Warning(EVENT_TYPE t, string src, string msg, double val = 0.0)
    {
        SystemEvent e;
        e.type = t;
        e.timestamp = TimeCurrent();
        e.data = msg;
        e.value = val;
        e.source = src;
        e.severity = 1;
        return e;
    }
    
    // Create error event
    static SystemEvent Error(EVENT_TYPE t, string src, string msg, double val = 0.0)
    {
        SystemEvent e;
        e.type = t;
        e.timestamp = TimeCurrent();
        e.data = msg;
        e.value = val;
        e.source = src;
        e.severity = 2;
        return e;
    }
};

//+------------------------------------------------------------------+
//| Event Handler Interface (Callback Pattern)                        |
//+------------------------------------------------------------------+
// Note: MQL5 doesn't support function pointers or true interfaces for callbacks
// This is a placeholder for future implementation using class-based handlers

//+------------------------------------------------------------------+
//| Grande Event Bus Class                                            |
//+------------------------------------------------------------------+
class CGrandeEventBus
{
private:
    SystemEvent m_eventQueue[];
    int m_eventCount;
    int m_maxQueueSize;
    bool m_initialized;
    bool m_showDebugPrints;
    bool m_logEvents;
    string m_logFile;
    
    // Event statistics
    int m_totalEventsPublished;
    int m_eventsDropped;
    datetime m_lastEventTime;
    
    // Add event to queue
    void AddToQueue(const SystemEvent &event)
    {
        if(m_eventCount >= m_maxQueueSize)
        {
            // Queue full - remove oldest event
            for(int i = 0; i < m_eventCount - 1; i++)
            {
                m_eventQueue[i] = m_eventQueue[i + 1];
            }
            m_eventCount--;
            m_eventsDropped++;
        }
        
        m_eventQueue[m_eventCount] = event;
        m_eventCount++;
        m_lastEventTime = TimeCurrent();
    }
    
    // Log event to file
    void LogEvent(const SystemEvent &event)
    {
        if(!m_logEvents)
            return;
        
        int fileHandle = FileOpen(m_logFile, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON, "\t");
        if(fileHandle == INVALID_HANDLE)
            return;
        
        FileSeek(fileHandle, 0, SEEK_END);
        
        string severityStr = "";
        switch(event.severity)
        {
            case 0: severityStr = "INFO"; break;
            case 1: severityStr = "WARNING"; break;
            case 2: severityStr = "ERROR"; break;
            case 3: severityStr = "CRITICAL"; break;
        }
        
        string line = StringFormat("%s\t%s\t%s\t%s\t%s\t%.5f\n",
                                  TimeToString(event.timestamp, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                                  EventTypeToString(event.type),
                                  severityStr,
                                  event.source,
                                  event.data,
                                  event.value);
        
        FileWriteString(fileHandle, line);
        FileClose(fileHandle);
    }
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CGrandeEventBus(void) : m_eventCount(0), m_initialized(false), m_showDebugPrints(false)
    {
        m_maxQueueSize = 1000;
        m_logEvents = true;
        m_logFile = "GrandeEventLog.txt";
        m_totalEventsPublished = 0;
        m_eventsDropped = 0;
        m_lastEventTime = 0;
        
        ArrayResize(m_eventQueue, m_maxQueueSize);
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                        |
    //+------------------------------------------------------------------+
    ~CGrandeEventBus(void)
    {
        if(m_showDebugPrints)
            Print("[EventBus] Destroyed. Total events published: ", m_totalEventsPublished);
    }
    
    //+------------------------------------------------------------------+
    //| Initialize                                                        |
    //+------------------------------------------------------------------+
    bool Initialize(int maxQueueSize = 1000, bool logEvents = true, bool showDebug = false)
    {
        m_maxQueueSize = maxQueueSize;
        m_logEvents = logEvents;
        m_showDebugPrints = showDebug;
        m_initialized = true;
        
        ArrayResize(m_eventQueue, m_maxQueueSize);
        
        // Publish initialization event
        PublishEvent(EVENT_SYSTEM_INIT, "EventBus", "Event bus initialized", 0.0);
        
        if(m_showDebugPrints)
            Print("[EventBus] Initialized (Queue size: ", m_maxQueueSize, ", Logging: ", m_logEvents ? "ON" : "OFF", ")");
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Publish Event                                                     |
    //+------------------------------------------------------------------+
    void PublishEvent(EVENT_TYPE type, string source, string data, double value = 0.0, int severity = 0)
    {
        SystemEvent event;
        event.type = type;
        event.timestamp = TimeCurrent();
        event.data = data;
        event.value = value;
        event.source = source;
        event.severity = severity;
        
        AddToQueue(event);
        LogEvent(event);
        
        m_totalEventsPublished++;
        
        if(m_showDebugPrints)
        {
            Print("[EventBus] Event published: ", EventTypeToString(type), 
                  " from ", source, " - ", data);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Publish Event (using SystemEvent struct)                         |
    //+------------------------------------------------------------------+
    void PublishEvent(const SystemEvent &event)
    {
        AddToQueue(event);
        LogEvent(event);
        
        m_totalEventsPublished++;
        
        if(m_showDebugPrints)
        {
            Print("[EventBus] Event published: ", EventTypeToString(event.type), 
                  " from ", event.source, " - ", event.data);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Get Events (with optional filter)                                |
    //+------------------------------------------------------------------+
    int GetEvents(SystemEvent &events[], EVENT_TYPE filter = EVENT_CUSTOM)
    {
        int matchCount = 0;
        ArrayResize(events, m_eventCount);
        
        for(int i = 0; i < m_eventCount; i++)
        {
            if(filter == EVENT_CUSTOM || m_eventQueue[i].type == filter)
            {
                events[matchCount] = m_eventQueue[i];
                matchCount++;
            }
        }
        
        if(matchCount < ArraySize(events))
            ArrayResize(events, matchCount);
        
        return matchCount;
    }
    
    //+------------------------------------------------------------------+
    //| Get Recent Events                                                 |
    //+------------------------------------------------------------------+
    int GetRecentEvents(SystemEvent &events[], int maxCount)
    {
        int count = MathMin(maxCount, m_eventCount);
        ArrayResize(events, count);
        
        int startIndex = m_eventCount - count;
        for(int i = 0; i < count; i++)
        {
            events[i] = m_eventQueue[startIndex + i];
        }
        
        return count;
    }
    
    //+------------------------------------------------------------------+
    //| Clear Event Queue                                                 |
    //+------------------------------------------------------------------+
    void ClearEvents()
    {
        m_eventCount = 0;
        
        if(m_showDebugPrints)
            Print("[EventBus] Event queue cleared");
    }
    
    //+------------------------------------------------------------------+
    //| Get Event Count                                                   |
    //+------------------------------------------------------------------+
    int GetEventCount() { return m_eventCount; }
    
    //+------------------------------------------------------------------+
    //| Get Statistics                                                    |
    //+------------------------------------------------------------------+
    string GetStatistics()
    {
        string stats = "\n=== EVENT BUS STATISTICS ===\n";
        stats += StringFormat("Total Events Published: %d\n", m_totalEventsPublished);
        stats += StringFormat("Events in Queue: %d/%d\n", m_eventCount, m_maxQueueSize);
        stats += StringFormat("Events Dropped: %d\n", m_eventsDropped);
        stats += StringFormat("Last Event: %s\n", TimeToString(m_lastEventTime, TIME_DATE|TIME_MINUTES));
        stats += "===========================\n";
        
        return stats;
    }
    
    //+------------------------------------------------------------------+
    //| Event Type to String                                              |
    //+------------------------------------------------------------------+
    string EventTypeToString(EVENT_TYPE type)
    {
        switch(type)
        {
            case EVENT_SYSTEM_INIT: return "SYSTEM_INIT";
            case EVENT_SYSTEM_DEINIT: return "SYSTEM_DEINIT";
            case EVENT_REGIME_CHANGED: return "REGIME_CHANGED";
            case EVENT_KEY_LEVEL_DETECTED: return "KEY_LEVEL_DETECTED";
            case EVENT_KEY_LEVEL_UPDATED: return "KEY_LEVEL_UPDATED";
            case EVENT_SIGNAL_GENERATED: return "SIGNAL_GENERATED";
            case EVENT_SIGNAL_VALIDATED: return "SIGNAL_VALIDATED";
            case EVENT_SIGNAL_REJECTED: return "SIGNAL_REJECTED";
            case EVENT_ORDER_PLACED: return "ORDER_PLACED";
            case EVENT_ORDER_FILLED: return "ORDER_FILLED";
            case EVENT_ORDER_CANCELLED: return "ORDER_CANCELLED";
            case EVENT_ORDER_FAILED: return "ORDER_FAILED";
            case EVENT_POSITION_OPENED: return "POSITION_OPENED";
            case EVENT_POSITION_MODIFIED: return "POSITION_MODIFIED";
            case EVENT_POSITION_CLOSED: return "POSITION_CLOSED";
            case EVENT_STOP_LOSS_HIT: return "STOP_LOSS_HIT";
            case EVENT_TAKE_PROFIT_HIT: return "TAKE_PROFIT_HIT";
            case EVENT_BREAKEVEN_MOVED: return "BREAKEVEN_MOVED";
            case EVENT_TRAILING_STOP_MOVED: return "TRAILING_STOP_MOVED";
            case EVENT_PARTIAL_CLOSE: return "PARTIAL_CLOSE";
            case EVENT_RISK_WARNING: return "RISK_WARNING";
            case EVENT_MARGIN_WARNING: return "MARGIN_WARNING";
            case EVENT_MARGIN_CRITICAL: return "MARGIN_CRITICAL";
            case EVENT_DRAWDOWN_WARNING: return "DRAWDOWN_WARNING";
            case EVENT_COMPONENT_ERROR: return "COMPONENT_ERROR";
            case EVENT_COMPONENT_RECOVERED: return "COMPONENT_RECOVERED";
            case EVENT_DATABASE_ERROR: return "DATABASE_ERROR";
            case EVENT_NETWORK_ERROR: return "NETWORK_ERROR";
            case EVENT_DATA_COLLECTED: return "DATA_COLLECTED";
            case EVENT_REPORT_GENERATED: return "REPORT_GENERATED";
            case EVENT_HEALTH_CHECK: return "HEALTH_CHECK";
            case EVENT_CONFIG_CHANGED: return "CONFIG_CHANGED";
            case EVENT_USER_ACTION: return "USER_ACTION";
            default: return "CUSTOM";
        }
    }
};

