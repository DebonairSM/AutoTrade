//+------------------------------------------------------------------+
//|                                             V-2-EA-Logger.mqh |
//|                                      Logging Implementation    |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

#ifndef _V2_EA_LOGGER_MQH_
#define _V2_EA_LOGGER_MQH_

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"
#include "V-2-EA-Stubs.mqh"

//--- Logging Constants
#define LOG_MAX_ENTRIES          10000  // Maximum log entries to keep
#define LOG_FLUSH_INTERVAL       3600   // Log flush interval (seconds)
#define LOG_MAX_FILE_SIZE        10     // Maximum log file size (MB)
#define LOG_ROTATION_COUNT       5      // Number of backup log files
#define LOG_BUFFER_SIZE         1000   // Memory buffer size for logs
#define LOG_UPDATE_INTERVAL     1      // Log update interval (seconds)
#define LOG_MAX_MESSAGE_SIZE    1024   // Maximum message length
#define LOG_DATE_FORMAT        "%Y.%m.%d %H:%M:%S"  // Date format

//--- Log Level Types
enum ENUM_LOG_LEVEL
{
    LOG_LEVEL_NONE = 0,         // No logging
    LOG_LEVEL_ERROR,            // Error messages only
    LOG_LEVEL_WARNING,          // Warnings and errors
    LOG_LEVEL_INFO,            // General information
    LOG_LEVEL_DEBUG,           // Debug information
    LOG_LEVEL_VERBOSE         // Detailed debug info
};

//--- Log Category Types
enum ENUM_LOG_CATEGORY
{
    LOG_CATEGORY_NONE = 0,      // No specific category
    LOG_CATEGORY_SYSTEM,        // System messages
    LOG_CATEGORY_TRADE,         // Trade operations
    LOG_CATEGORY_SIGNAL,        // Trading signals
    LOG_CATEGORY_RISK,          // Risk management
    LOG_CATEGORY_PATTERN,       // Pattern detection
    LOG_CATEGORY_PERFORMANCE   // Performance metrics
};

//--- Log Entry Structure
struct SLogEntry
{
    datetime          timestamp;         // Entry timestamp
    ENUM_LOG_LEVEL    level;            // Log level
    ENUM_LOG_CATEGORY category;         // Log category
    string            message;          // Log message
    string            source;           // Source of the log
    int              errorCode;        // Error code if any
    string           additionalInfo;   // Additional information
    
    void Reset()
    {
        timestamp = 0;
        level = LOG_LEVEL_NONE;
        category = LOG_CATEGORY_NONE;
        message = "";
        source = "";
        errorCode = 0;
        additionalInfo = "";
    }
};

//--- Log State Structure
struct SLogState
{
    int               entryCount;        // Current entry count
    datetime          lastFlush;         // Last flush time
    long              totalBytes;        // Total bytes logged
    int               errorCount;        // Number of errors
    int               warningCount;      // Number of warnings
    bool              isEnabled;         // Logging enabled state
    string            currentFile;       // Current log file
    string            lastError;         // Last logging error
    
    void Reset()
    {
        entryCount = 0;
        lastFlush = 0;
        totalBytes = 0;
        errorCount = 0;
        warningCount = 0;
        isEnabled = true;
        currentFile = "";
        lastError = "";
    }
};

//+------------------------------------------------------------------+
//| Main Logger Class                                                  |
//+------------------------------------------------------------------+
class CV2EABreakoutLogger : public CV2EABreakoutLogger
{
private:
    //--- State Management
    SLogState          m_logState;        // Logging state
    SLogEntry          m_buffer[];        // Log entry buffer
    
    //--- Configuration
    ENUM_LOG_LEVEL     m_logLevel;        // Current log level
    int                m_maxEntries;       // Maximum entries
    int                m_flushInterval;    // Flush interval
    int                m_maxFileSize;      // Max file size (MB)
    int                m_rotationCount;    // Log rotation count
    string             m_logDirectory;     // Log file directory
    string             m_logPrefix;        // Log file prefix
    
    //--- Private Methods
    bool               FlushBuffer();
    bool               RotateLogFiles();
    bool               ValidateLogEntry(const SLogEntry &entry);
    string             FormatLogMessage(const SLogEntry &entry);
    bool               WriteToFile(const string message);
    void               UpdateLogMetrics();
    bool               CleanupOldLogs();
    string             GenerateLogFileName();
    
protected:
    //--- Protected utility methods
    virtual bool       IsLoggingEnabled();
    virtual bool       ShouldLog(const ENUM_LOG_LEVEL level);
    virtual bool       ValidateLogLevel(const ENUM_LOG_LEVEL level);
    virtual string     GetLogLevelString(const ENUM_LOG_LEVEL level);

public:
    //--- Constructor and Destructor
    CV2EABreakoutLogger(void);
    ~CV2EABreakoutLogger(void);
    
    //--- Initialization and Configuration
    virtual bool       Initialize(void);
    virtual void       ConfigureLogger(
                           const ENUM_LOG_LEVEL level,
                           const int maxEntries,
                           const string directory
                       );
    
    //--- Logging Methods
    virtual bool       Log(
                           const ENUM_LOG_LEVEL level,
                           const ENUM_LOG_CATEGORY category,
                           const string message,
                           const string source = "",
                           const int errorCode = 0
                       );
    
    virtual bool       LogError(
                           const string message,
                           const int errorCode = 0,
                           const string source = ""
                       );
    
    virtual bool       LogWarning(
                           const string message,
                           const string source = ""
                       );
    
    virtual bool       LogInfo(
                           const string message,
                           const string source = ""
                       );
    
    virtual bool       LogDebug(
                           const string message,
                           const string source = ""
                       );
    
    virtual bool       LogVerbose(
                           const string message,
                           const string source = ""
                       );
    
    //--- Trade Logging Methods
    virtual bool       LogTradeSignal(
                           const string pattern,
                           const string direction,
                           const double price,
                           const string reason = ""
                       );
    
    virtual bool       LogTradeExecution(
                           const string orderType,
                           const double volume,
                           const double price,
                           const string symbol = ""
                       );
    
    virtual bool       LogTradeExit(
                           const string exitType,
                           const double profit,
                           const int duration,
                           const string reason = ""
                       );
    
    //--- Pattern Logging Methods
    virtual bool       LogPatternDetection(
                           const string pattern,
                           const double price,
                           const string details = ""
                       );
    
    virtual bool       LogPatternValidation(
                           const string pattern,
                           const bool isValid,
                           const string reason = ""
                       );
    
    //--- Performance Logging Methods
    virtual bool       LogPerformanceMetrics(
                           const double winRate,
                           const double profitFactor,
                           const double drawdown
                       );
    
    virtual bool       LogRiskMetrics(
                           const double exposure,
                           const double margin,
                           const string details = ""
                       );
    
    //--- Utility Methods
    virtual void       GetLogState(SLogState &state) const;
    virtual bool       ExportLogs(const string filename);
    virtual bool       ClearLogs();
    virtual bool       SetLogLevel(const ENUM_LOG_LEVEL level);
    virtual ENUM_LOG_LEVEL GetLogLevel() const;
    virtual string     GetLastError() const;
    
    //--- Event Handlers
    virtual void       OnLogBufferFull();
    virtual void       OnLogFileRotation();
    virtual void       OnLogError(const string error);
    virtual void       OnCriticalError(const int errorCode);
};

#endif // _V2_EA_LOGGER_MQH_ 