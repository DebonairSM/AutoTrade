//+------------------------------------------------------------------+
//| GrandeStateManager.mqh                                           |
//| Copyright 2024, Grande Tech                                      |
//| Centralized State Management for Grande Trading System          |
//+------------------------------------------------------------------+
// PURPOSE:
//   Centralized state management for the entire trading system.
//   Provides single source of truth for all system state.
//
// RESPONSIBILITIES:
//   - Manage all system state in one place
//   - Provide explicit getters/setters for state access
//   - Handle state persistence and loading
//   - Validate state consistency
//   - Track state changes for debugging
//
// DEPENDENCIES:
//   - GrandeMarketRegimeDetector.mqh (for RegimeSnapshot)
//   - GrandeKeyLevelDetector.mqh (for SKeyLevel)
//
// STATE MANAGED:
//   - Current market regime snapshot
//   - Nearest support and resistance levels
//   - Current ATR and volatility metrics
//   - Range information for scaling
//   - Cool-off period state
//   - RSI cache for performance
//   - Last update timestamps
//
// PUBLIC INTERFACE:
//   bool Initialize() - Initialize state manager
//   bool ValidateState() - Validate current state consistency
//   bool SaveState() - Persist state to disk
//   bool LoadState() - Load state from disk
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestStateManager.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"

#include "GrandeMarketRegimeDetector.mqh"
#include "GrandeKeyLevelDetector.mqh"

//+------------------------------------------------------------------+
//| Range Information Structure                                       |
//+------------------------------------------------------------------+
struct RangeInfo 
{
    double upperBound;
    double lowerBound;
    datetime rangeStartTime;
    bool isValid;
    int touchCount;
    double rangeSize;
    
    void Reset()
    {
        upperBound = 0.0;
        lowerBound = 0.0;
        rangeStartTime = 0;
        isValid = false;
        touchCount = 0;
        rangeSize = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Cool-Off Information Structure                                    |
//+------------------------------------------------------------------+
struct CoolOffInfo
{
    datetime lastExitTime;
    double lastExitPrice;
    int lastDirection;      // 0=BUY, 1=SELL
    int exitReason;         // 0=TP, 1=SL, 2=OTHER
    bool isActive;
    
    void Reset()
    {
        lastExitTime = 0;
        lastExitPrice = 0.0;
        lastDirection = -1;
        exitReason = -1;
        isActive = false;
    }
};

//+------------------------------------------------------------------+
//| Cool-Off Statistics Structure                                     |
//+------------------------------------------------------------------+
struct CoolOffStats
{
    int tradesBlocked;
    int tradesAllowed;
    int overridesUsed;
    int blockedWouldWin;
    int blockedWouldLose;
    int allowedWins;
    int allowedLosses;
    datetime lastReportTime;
    
    void Reset()
    {
        tradesBlocked = 0;
        tradesAllowed = 0;
        overridesUsed = 0;
        blockedWouldWin = 0;
        blockedWouldLose = 0;
        allowedWins = 0;
        allowedLosses = 0;
        lastReportTime = 0;
    }
};

//+------------------------------------------------------------------+
//| Grande State Manager Class                                       |
//+------------------------------------------------------------------+
class CGrandeStateManager
{
private:
    // Core state structure
    struct SystemState
    {
        // Market regime state
        RegimeSnapshot currentRegime;
        datetime lastRegimeUpdate;
        
        // Key levels state
        SKeyLevel nearestSupport;
        SKeyLevel nearestResistance;
        datetime lastKeyLevelUpdate;
        
        // Volatility metrics
        double currentATR;
        double averageATR;
        datetime lastATRUpdate;
        
        // Range information
        RangeInfo currentRange;
        datetime lastRangeUpdate;
        
        // Cool-off state
        CoolOffInfo coolOff;
        CoolOffStats coolOffStats;
        
        // RSI cache
        double cachedRsiCTF;
        double cachedRsiH4;
        double cachedRsiD1;
        datetime lastRsiCacheTime;
        
        // Position tracking
        int lastPositionCount;
        
        // Display update tracking
        datetime lastDisplayUpdate;
        
        // Signal throttling
        datetime lastSignalAnalysisTime;
        string lastRejectionReason;
        MARKET_REGIME lastAnalysisRegime;
        
        // Data collection tracking
        datetime lastDataCollectionTime;
        datetime lastFinBERTAnalysisTime;
        datetime lastCalendarUpdate;
        datetime lastBarTime;
    };
    
    SystemState m_state;
    string m_symbol;
    bool m_initialized;
    bool m_showDebugPrints;
    string m_stateFile;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CGrandeStateManager(void) : m_initialized(false), m_showDebugPrints(false)
    {
        m_symbol = _Symbol;
        m_stateFile = StringFormat("GrandeState_%s.dat", m_symbol);
        ResetState();
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                        |
    //+------------------------------------------------------------------+
    ~CGrandeStateManager(void)
    {
        if(m_initialized)
        {
            SaveState();
        }
    }
    
    //+------------------------------------------------------------------+
    //| Initialize state manager                                          |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, bool showDebug = false)
    {
        m_symbol = symbol;
        m_showDebugPrints = showDebug;
        m_stateFile = StringFormat("GrandeState_%s.dat", m_symbol);
        
        ResetState();
        
        // Attempt to load existing state
        if(!LoadState())
        {
            if(m_showDebugPrints)
                Print("[StateManager] No existing state found, starting fresh");
        }
        
        m_initialized = true;
        
        if(m_showDebugPrints)
            Print("[StateManager] Initialized successfully for ", m_symbol);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Reset all state to defaults                                       |
    //+------------------------------------------------------------------+
    void ResetState()
    {
        m_state.currentRegime.regime = REGIME_RANGING;
        m_state.currentRegime.confidence = 0.0;
        m_state.currentRegime.timestamp = 0;
        m_state.lastRegimeUpdate = 0;
        
        m_state.nearestSupport.price = 0.0;
        m_state.nearestResistance.price = 0.0;
        m_state.lastKeyLevelUpdate = 0;
        
        m_state.currentATR = 0.0;
        m_state.averageATR = 0.0;
        m_state.lastATRUpdate = 0;
        
        m_state.currentRange.Reset();
        m_state.lastRangeUpdate = 0;
        
        m_state.coolOff.Reset();
        m_state.coolOffStats.Reset();
        
        m_state.cachedRsiCTF = EMPTY_VALUE;
        m_state.cachedRsiH4 = EMPTY_VALUE;
        m_state.cachedRsiD1 = EMPTY_VALUE;
        m_state.lastRsiCacheTime = 0;
        
        m_state.lastPositionCount = 0;
        m_state.lastDisplayUpdate = 0;
        
        m_state.lastSignalAnalysisTime = 0;
        m_state.lastRejectionReason = "";
        m_state.lastAnalysisRegime = REGIME_RANGING;
        
        m_state.lastDataCollectionTime = 0;
        m_state.lastFinBERTAnalysisTime = 0;
        m_state.lastCalendarUpdate = 0;
        m_state.lastBarTime = 0;
    }
    
    //+------------------------------------------------------------------+
    //| Regime State Accessors                                            |
    //+------------------------------------------------------------------+
    RegimeSnapshot GetCurrentRegime() const { return m_state.currentRegime; }
    void SetCurrentRegime(const RegimeSnapshot &regime) 
    { 
        m_state.currentRegime = regime;
        m_state.lastRegimeUpdate = TimeCurrent();
    }
    datetime GetLastRegimeUpdate() const { return m_state.lastRegimeUpdate; }
    
    //+------------------------------------------------------------------+
    //| Key Level State Accessors                                         |
    //+------------------------------------------------------------------+
    SKeyLevel GetNearestSupport() const { return m_state.nearestSupport; }
    void SetNearestSupport(const SKeyLevel &support) 
    { 
        m_state.nearestSupport = support;
        m_state.lastKeyLevelUpdate = TimeCurrent();
    }
    
    SKeyLevel GetNearestResistance() const { return m_state.nearestResistance; }
    void SetNearestResistance(const SKeyLevel &resistance) 
    { 
        m_state.nearestResistance = resistance;
        m_state.lastKeyLevelUpdate = TimeCurrent();
    }
    datetime GetLastKeyLevelUpdate() const { return m_state.lastKeyLevelUpdate; }
    
    //+------------------------------------------------------------------+
    //| ATR State Accessors                                               |
    //+------------------------------------------------------------------+
    double GetCurrentATR() const { return m_state.currentATR; }
    void SetCurrentATR(double atr) 
    { 
        m_state.currentATR = atr;
        m_state.lastATRUpdate = TimeCurrent();
    }
    
    double GetAverageATR() const { return m_state.averageATR; }
    void SetAverageATR(double avgATR) { m_state.averageATR = avgATR; }
    datetime GetLastATRUpdate() const { return m_state.lastATRUpdate; }
    
    //+------------------------------------------------------------------+
    //| Range State Accessors                                             |
    //+------------------------------------------------------------------+
    RangeInfo GetCurrentRange() const { return m_state.currentRange; }
    void SetCurrentRange(const RangeInfo &range) 
    { 
        m_state.currentRange = range;
        m_state.lastRangeUpdate = TimeCurrent();
    }
    datetime GetLastRangeUpdate() const { return m_state.lastRangeUpdate; }
    
    //+------------------------------------------------------------------+
    //| Cool-Off State Accessors                                          |
    //+------------------------------------------------------------------+
    CoolOffInfo GetCoolOffInfo() const { return m_state.coolOff; }
    void SetCoolOffInfo(const CoolOffInfo &coolOff) { m_state.coolOff = coolOff; }
    bool IsInCoolOff() const { return m_state.coolOff.isActive; }
    
    CoolOffStats GetCoolOffStats() const { return m_state.coolOffStats; }
    void SetCoolOffStats(const CoolOffStats &stats) { m_state.coolOffStats = stats; }
    
    //+------------------------------------------------------------------+
    //| RSI Cache Accessors                                               |
    //+------------------------------------------------------------------+
    double GetCachedRsiCTF() const { return m_state.cachedRsiCTF; }
    double GetCachedRsiH4() const { return m_state.cachedRsiH4; }
    double GetCachedRsiD1() const { return m_state.cachedRsiD1; }
    datetime GetLastRsiCacheTime() const { return m_state.lastRsiCacheTime; }
    
    void SetRsiCache(double rsiCTF, double rsiH4, double rsiD1)
    {
        m_state.cachedRsiCTF = rsiCTF;
        m_state.cachedRsiH4 = rsiH4;
        m_state.cachedRsiD1 = rsiD1;
        m_state.lastRsiCacheTime = TimeCurrent();
    }
    
    //+------------------------------------------------------------------+
    //| Position Tracking Accessors                                       |
    //+------------------------------------------------------------------+
    int GetLastPositionCount() const { return m_state.lastPositionCount; }
    void SetLastPositionCount(int count) { m_state.lastPositionCount = count; }
    
    //+------------------------------------------------------------------+
    //| Timing Accessors                                                  |
    //+------------------------------------------------------------------+
    datetime GetLastDisplayUpdate() const { return m_state.lastDisplayUpdate; }
    void SetLastDisplayUpdate(datetime time) { m_state.lastDisplayUpdate = time; }
    
    datetime GetLastSignalAnalysisTime() const { return m_state.lastSignalAnalysisTime; }
    void SetLastSignalAnalysisTime(datetime time) { m_state.lastSignalAnalysisTime = time; }
    
    string GetLastRejectionReason() const { return m_state.lastRejectionReason; }
    void SetLastRejectionReason(string reason) { m_state.lastRejectionReason = reason; }
    
    MARKET_REGIME GetLastAnalysisRegime() const { return m_state.lastAnalysisRegime; }
    void SetLastAnalysisRegime(MARKET_REGIME regime) { m_state.lastAnalysisRegime = regime; }
    
    datetime GetLastDataCollectionTime() const { return m_state.lastDataCollectionTime; }
    void SetLastDataCollectionTime(datetime time) { m_state.lastDataCollectionTime = time; }
    
    datetime GetLastFinBERTAnalysisTime() const { return m_state.lastFinBERTAnalysisTime; }
    void SetLastFinBERTAnalysisTime(datetime time) { m_state.lastFinBERTAnalysisTime = time; }
    
    datetime GetLastCalendarUpdate() const { return m_state.lastCalendarUpdate; }
    void SetLastCalendarUpdate(datetime time) { m_state.lastCalendarUpdate = time; }
    
    datetime GetLastBarTime() const { return m_state.lastBarTime; }
    void SetLastBarTime(datetime time) { m_state.lastBarTime = time; }
    
    //+------------------------------------------------------------------+
    //| State Validation                                                  |
    //+------------------------------------------------------------------+
    bool ValidateState()
    {
        bool isValid = true;
        
        // Validate ATR values
        if(m_state.currentATR < 0 || m_state.averageATR < 0)
        {
            if(m_showDebugPrints)
                Print("[StateManager] Invalid ATR values detected");
            isValid = false;
        }
        
        // Validate regime confidence
        if(m_state.currentRegime.confidence < 0.0 || m_state.currentRegime.confidence > 1.0)
        {
            if(m_showDebugPrints)
                Print("[StateManager] Invalid regime confidence: ", m_state.currentRegime.confidence);
            isValid = false;
        }
        
        // Validate range bounds
        if(m_state.currentRange.isValid)
        {
            if(m_state.currentRange.upperBound <= m_state.currentRange.lowerBound)
            {
                if(m_showDebugPrints)
                    Print("[StateManager] Invalid range bounds");
                isValid = false;
            }
        }
        
        return isValid;
    }
    
    //+------------------------------------------------------------------+
    //| Can Trade Query                                                   |
    //+------------------------------------------------------------------+
    bool CanTrade()
    {
        // Check if in cool-off period
        if(m_state.coolOff.isActive)
            return false;
        
        // Additional checks can be added here
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| State Persistence                                                 |
    //+------------------------------------------------------------------+
    bool SaveState()
    {
        int fileHandle = FileOpen(m_stateFile, FILE_WRITE|FILE_BIN);
        if(fileHandle == INVALID_HANDLE)
        {
            if(m_showDebugPrints)
                Print("[StateManager] Failed to create state file: ", m_stateFile);
            return false;
        }
        
        // Write magic number for validation
        FileWriteInteger(fileHandle, 0x47524E44); // "GRND"
        
        // Write version
        FileWriteInteger(fileHandle, 1);
        
        // Write state data
        FileWriteInteger(fileHandle, (int)m_state.currentRegime.regime);
        FileWriteDouble(fileHandle, m_state.currentRegime.confidence);
        FileWriteLong(fileHandle, (long)m_state.lastRegimeUpdate);
        
        FileWriteDouble(fileHandle, m_state.currentATR);
        FileWriteDouble(fileHandle, m_state.averageATR);
        
        FileWriteInteger(fileHandle, m_state.coolOff.isActive ? 1 : 0);
        FileWriteLong(fileHandle, (long)m_state.coolOff.lastExitTime);
        FileWriteDouble(fileHandle, m_state.coolOff.lastExitPrice);
        FileWriteInteger(fileHandle, m_state.coolOff.lastDirection);
        FileWriteInteger(fileHandle, m_state.coolOff.exitReason);
        
        FileClose(fileHandle);
        
        if(m_showDebugPrints)
            Print("[StateManager] State saved successfully");
        
        return true;
    }
    
    bool LoadState()
    {
        if(!FileIsExist(m_stateFile))
            return false;
        
        int fileHandle = FileOpen(m_stateFile, FILE_READ|FILE_BIN);
        if(fileHandle == INVALID_HANDLE)
            return false;
        
        // Validate magic number
        int magic = FileReadInteger(fileHandle);
        if(magic != 0x47524E44)
        {
            FileClose(fileHandle);
            return false;
        }
        
        // Read version
        int version = FileReadInteger(fileHandle);
        if(version != 1)
        {
            FileClose(fileHandle);
            return false;
        }
        
        // Read state data
        m_state.currentRegime.regime = (MARKET_REGIME)FileReadInteger(fileHandle);
        m_state.currentRegime.confidence = FileReadDouble(fileHandle);
        m_state.lastRegimeUpdate = (datetime)FileReadLong(fileHandle);
        
        m_state.currentATR = FileReadDouble(fileHandle);
        m_state.averageATR = FileReadDouble(fileHandle);
        
        m_state.coolOff.isActive = FileReadInteger(fileHandle) != 0;
        m_state.coolOff.lastExitTime = (datetime)FileReadLong(fileHandle);
        m_state.coolOff.lastExitPrice = FileReadDouble(fileHandle);
        m_state.coolOff.lastDirection = FileReadInteger(fileHandle);
        m_state.coolOff.exitReason = FileReadInteger(fileHandle);
        
        FileClose(fileHandle);
        
        if(m_showDebugPrints)
            Print("[StateManager] State loaded successfully");
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get State Summary                                                 |
    //+------------------------------------------------------------------+
    string GetStateSummary()
    {
        string summary = "\n=== SYSTEM STATE SUMMARY ===\n";
        summary += StringFormat("Regime: %s (Conf: %.2f)\n", 
                              EnumToString(m_state.currentRegime.regime), 
                              m_state.currentRegime.confidence);
        summary += StringFormat("ATR: %.5f (Avg: %.5f)\n", 
                              m_state.currentATR, m_state.averageATR);
        summary += StringFormat("Cool-Off: %s\n", m_state.coolOff.isActive ? "ACTIVE" : "Inactive");
        summary += StringFormat("Position Count: %d\n", m_state.lastPositionCount);
        summary += "==========================\n";
        
        return summary;
    }
};

