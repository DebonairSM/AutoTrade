//+------------------------------------------------------------------+
//| GrandeHealthMonitor.mqh                                          |
//| Copyright 2024, Grande Tech                                      |
//| Component Health Monitoring and Graceful Degradation            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Monitor health of all system components and enable graceful degradation
//   when components fail. Ensures system continues operating even with failures.
//
// RESPONSIBILITIES:
//   - Monitor health of all registered components
//   - Detect component failures and errors
//   - Attempt automatic recovery of failed components
//   - Enable fallback/degraded operation modes
//   - Report system health status
//   - Log component issues
//
// DEPENDENCIES:
//   - GrandeComponentRegistry.mqh (for component access)
//   - GrandeInterfaces.mqh (for status structures)
//
// STATE MANAGED:
//   - Health status of each component
//   - Failure counts and timestamps
//   - Recovery attempts
//   - Degraded operation flags
//
// PUBLIC INTERFACE:
//   bool Initialize() - Initialize health monitor
//   void CheckSystemHealth() - Check all components
//   bool CanTrade() - Check if trading is safe
//   string GetHealthReport() - Get detailed health report
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestHealthMonitor.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"

#include "GrandeComponentRegistry.mqh"
#include "GrandeInterfaces.mqh"

//+------------------------------------------------------------------+
//| Component Health Entry                                            |
//+------------------------------------------------------------------+
struct ComponentHealthEntry
{
    string componentName;
    COMPONENT_HEALTH currentHealth;
    int consecutiveFailures;
    datetime lastFailureTime;
    datetime lastRecoveryAttempt;
    int recoveryAttempts;
    bool isInDegradedMode;
    string lastErrorMessage;
    
    void ComponentHealthEntry()
    {
        componentName = "";
        currentHealth = HEALTH_UNKNOWN;
        consecutiveFailures = 0;
        lastFailureTime = 0;
        lastRecoveryAttempt = 0;
        recoveryAttempts = 0;
        isInDegradedMode = false;
        lastErrorMessage = "";
    }
};

//+------------------------------------------------------------------+
//| System Health Status                                              |
//+------------------------------------------------------------------+
enum SYSTEM_HEALTH_STATUS
{
    SYSTEM_HEALTHY,          // All components operational
    SYSTEM_WARNING,          // Some components have warnings
    SYSTEM_DEGRADED,         // Operating in degraded mode
    SYSTEM_CRITICAL,         // Critical components failed
    SYSTEM_FAILED            // System cannot operate safely
};

//+------------------------------------------------------------------+
//| Grande Health Monitor Class                                       |
//+------------------------------------------------------------------+
class CGrandeHealthMonitor
{
private:
    CGrandeComponentRegistry* m_registry;
    ComponentHealthEntry m_healthEntries[];
    int m_entryCount;
    SYSTEM_HEALTH_STATUS m_systemHealth;
    datetime m_lastHealthCheck;
    bool m_initialized;
    bool m_showDebugPrints;
    
    // Configuration
    int m_maxConsecutiveFailures;
    int m_recoveryAttemptDelay;  // seconds
    int m_maxRecoveryAttempts;
    
    // Critical component flags
    bool m_regimeDetectorHealthy;
    bool m_keyLevelDetectorHealthy;
    bool m_riskManagerHealthy;
    bool m_databaseHealthy;
    
    // Find health entry index
    int FindHealthEntry(string componentName)
    {
        for(int i = 0; i < m_entryCount; i++)
        {
            if(m_healthEntries[i].componentName == componentName)
                return i;
        }
        return -1;
    }
    
    // Add or update health entry
    void UpdateHealthEntry(string componentName, COMPONENT_HEALTH health, string errorMsg = "")
    {
        int index = FindHealthEntry(componentName);
        
        if(index < 0)
        {
            // Add new entry
            if(m_entryCount >= ArraySize(m_healthEntries))
            {
                ArrayResize(m_healthEntries, m_entryCount + 10);
            }
            
            ComponentHealthEntry entry;
            entry.componentName = componentName;
            entry.currentHealth = health;
            entry.consecutiveFailures = (health >= HEALTH_ERROR) ? 1 : 0;
            entry.lastFailureTime = (health >= HEALTH_ERROR) ? TimeCurrent() : 0;
            entry.lastErrorMessage = errorMsg;
            
            m_healthEntries[m_entryCount] = entry;
            m_entryCount++;
        }
        else
        {
            // Update existing entry
            COMPONENT_HEALTH prevHealth = m_healthEntries[index].currentHealth;
            m_healthEntries[index].currentHealth = health;
            
            if(health >= HEALTH_ERROR)
            {
                if(prevHealth >= HEALTH_ERROR)
                    m_healthEntries[index].consecutiveFailures++;
                else
                    m_healthEntries[index].consecutiveFailures = 1;
                
                m_healthEntries[index].lastFailureTime = TimeCurrent();
                m_healthEntries[index].lastErrorMessage = errorMsg;
            }
            else if(health == HEALTH_OK)
            {
                // Component recovered
                m_healthEntries[index].consecutiveFailures = 0;
                m_healthEntries[index].isInDegradedMode = false;
            }
        }
    }
    
    // Attempt to recover component
    bool TryRecoverComponent(int index)
    {
        if(index < 0 || index >= m_entryCount)
            return false;
        
        ComponentHealthEntry entry = m_healthEntries[index];
        
        // Check if enough time has passed since last attempt
        if(TimeCurrent() - entry.lastRecoveryAttempt < m_recoveryAttemptDelay)
            return false;
        
        // Check if max recovery attempts exceeded
        if(entry.recoveryAttempts >= m_maxRecoveryAttempts)
        {
            if(m_showDebugPrints)
                Print("[HealthMonitor] Max recovery attempts exceeded for: ", entry.componentName);
            return false;
        }
        
        m_healthEntries[index].lastRecoveryAttempt = TimeCurrent();
        m_healthEntries[index].recoveryAttempts++;
        
        if(m_showDebugPrints)
            Print("[HealthMonitor] Attempting recovery for: ", entry.componentName, 
                  " (Attempt ", m_healthEntries[index].recoveryAttempts, "/", m_maxRecoveryAttempts, ")");
        
        // Recovery logic would go here (component-specific)
        // For now, just check if component has self-recovered
        if(m_registry != NULL)
        {
            return m_registry.CheckComponentHealth(entry.componentName);
        }
        
        return false;
    }
    
    // Update system health status
    void UpdateSystemHealthStatus()
    {
        int criticalCount = 0;
        int errorCount = 0;
        int warningCount = 0;
        int healthyCount = 0;
        
        for(int i = 0; i < m_entryCount; i++)
        {
            switch(m_healthEntries[i].currentHealth)
            {
                case HEALTH_OK:
                    healthyCount++;
                    break;
                case HEALTH_WARNING:
                    warningCount++;
                    break;
                case HEALTH_ERROR:
                    errorCount++;
                    break;
                case HEALTH_CRITICAL:
                    criticalCount++;
                    break;
            }
        }
        
        if(criticalCount > 0 || !m_riskManagerHealthy)
        {
            m_systemHealth = SYSTEM_CRITICAL;
        }
        else if(errorCount > 0 || !m_regimeDetectorHealthy || !m_keyLevelDetectorHealthy)
        {
            m_systemHealth = SYSTEM_DEGRADED;
        }
        else if(warningCount > 0)
        {
            m_systemHealth = SYSTEM_WARNING;
        }
        else
        {
            m_systemHealth = SYSTEM_HEALTHY;
        }
    }
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CGrandeHealthMonitor(void) : m_registry(NULL), m_entryCount(0), m_initialized(false), m_showDebugPrints(false)
    {
        m_systemHealth = SYSTEM_HEALTHY;
        m_lastHealthCheck = 0;
        
        m_maxConsecutiveFailures = 3;
        m_recoveryAttemptDelay = 60;
        m_maxRecoveryAttempts = 3;
        
        m_regimeDetectorHealthy = true;
        m_keyLevelDetectorHealthy = true;
        m_riskManagerHealthy = true;
        m_databaseHealthy = true;
        
        ArrayResize(m_healthEntries, 20);
    }
    
    //+------------------------------------------------------------------+
    //| Initialize                                                        |
    //+------------------------------------------------------------------+
    bool Initialize(CGrandeComponentRegistry* registry, bool showDebug = false)
    {
        m_registry = registry;
        m_showDebugPrints = showDebug;
        m_initialized = true;
        
        if(m_showDebugPrints)
            Print("[HealthMonitor] Initialized");
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check System Health                                               |
    //+------------------------------------------------------------------+
    void CheckSystemHealth()
    {
        if(!m_initialized || m_registry == NULL)
            return;
        
        // Check all registered components
        m_registry.CheckAllComponentsHealth();
        
        // Get component statuses and update our entries
        int componentCount = m_registry.GetComponentCount();
        for(int i = 0; i < componentCount; i++)
        {
            // Would need to iterate through component names
            // For now, update critical component flags
        }
        
        // Attempt recovery for failed components
        for(int i = 0; i < m_entryCount; i++)
        {
            if(m_healthEntries[i].consecutiveFailures >= m_maxConsecutiveFailures)
            {
                if(TryRecoverComponent(i))
                {
                    if(m_showDebugPrints)
                        Print("[HealthMonitor] Successfully recovered: ", m_healthEntries[i].componentName);
                }
                else
                {
                    // Enable degraded mode for this component
                    m_healthEntries[i].isInDegradedMode = true;
                    
                    if(m_showDebugPrints)
                        Print("[HealthMonitor] Component in degraded mode: ", m_healthEntries[i].componentName);
                }
            }
        }
        
        UpdateSystemHealthStatus();
        m_lastHealthCheck = TimeCurrent();
    }
    
    //+------------------------------------------------------------------+
    //| Can Trade                                                         |
    //+------------------------------------------------------------------+
    bool CanTrade()
    {
        // Cannot trade if system is in critical or failed state
        if(m_systemHealth >= SYSTEM_CRITICAL)
            return false;
        
        // Cannot trade if risk manager is not healthy
        if(!m_riskManagerHealthy)
            return false;
        
        // Can trade in degraded mode but with reduced functionality
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get Health Report                                                 |
    //+------------------------------------------------------------------+
    string GetHealthReport()
    {
        string report = "\n=== SYSTEM HEALTH REPORT ===\n";
        report += StringFormat("System Status: %s\n", GetSystemHealthString());
        report += StringFormat("Last Check: %s\n", TimeToString(m_lastHealthCheck, TIME_DATE|TIME_MINUTES));
        report += StringFormat("Can Trade: %s\n", CanTrade() ? "YES" : "NO");
        
        report += "\nCRITICAL COMPONENTS:\n";
        report += StringFormat("  Regime Detector: %s\n", m_regimeDetectorHealthy ? "OK" : "FAILED");
        report += StringFormat("  Key Level Detector: %s\n", m_keyLevelDetectorHealthy ? "OK" : "FAILED");
        report += StringFormat("  Risk Manager: %s\n", m_riskManagerHealthy ? "OK" : "FAILED");
        report += StringFormat("  Database: %s\n", m_databaseHealthy ? "OK" : "WARNING");
        
        if(m_entryCount > 0)
        {
            report += "\nCOMPONENT HEALTH:\n";
            for(int i = 0; i < m_entryCount; i++)
            {
                ComponentHealthEntry entry = m_healthEntries[i];
                string status = HealthToString(entry.currentHealth);
                
                report += StringFormat("  %s: %s", entry.componentName, status);
                
                if(entry.consecutiveFailures > 0)
                    report += StringFormat(" (Failures: %d)", entry.consecutiveFailures);
                
                if(entry.isInDegradedMode)
                    report += " [DEGRADED MODE]";
                
                report += "\n";
                
                if(entry.lastErrorMessage != "")
                    report += StringFormat("    Last Error: %s\n", entry.lastErrorMessage);
            }
        }
        
        report += "==========================\n";
        
        return report;
    }
    
    //+------------------------------------------------------------------+
    //| Get System Health Status                                          |
    //+------------------------------------------------------------------+
    SYSTEM_HEALTH_STATUS GetSystemHealth() { return m_systemHealth; }
    
    string GetSystemHealthString()
    {
        switch(m_systemHealth)
        {
            case SYSTEM_HEALTHY:  return "HEALTHY";
            case SYSTEM_WARNING:  return "WARNING";
            case SYSTEM_DEGRADED: return "DEGRADED";
            case SYSTEM_CRITICAL: return "CRITICAL";
            case SYSTEM_FAILED:   return "FAILED";
            default:              return "UNKNOWN";
        }
    }
    
    //+------------------------------------------------------------------+
    //| Set Critical Component Health                                     |
    //+------------------------------------------------------------------+
    void SetRegimeDetectorHealth(bool healthy) { m_regimeDetectorHealthy = healthy; }
    void SetKeyLevelDetectorHealth(bool healthy) { m_keyLevelDetectorHealthy = healthy; }
    void SetRiskManagerHealth(bool healthy) { m_riskManagerHealthy = healthy; }
    void SetDatabaseHealth(bool healthy) { m_databaseHealthy = healthy; }
    
    //+------------------------------------------------------------------+
    //| Get Critical Component Health                                     |
    //+------------------------------------------------------------------+
    bool IsRegimeDetectorHealthy() { return m_regimeDetectorHealthy; }
    bool IsKeyLevelDetectorHealthy() { return m_keyLevelDetectorHealthy; }
    bool IsRiskManagerHealthy() { return m_riskManagerHealthy; }
    bool IsDatabaseHealthy() { return m_databaseHealthy; }
    
    //+------------------------------------------------------------------+
    //| Enable Fallback Mode for Component                                |
    //+------------------------------------------------------------------+
    bool EnableFallbackMode(string componentName)
    {
        int index = FindHealthEntry(componentName);
        if(index < 0)
            return false;
        
        m_healthEntries[index].isInDegradedMode = true;
        
        if(m_showDebugPrints)
            Print("[HealthMonitor] Enabled fallback mode for: ", componentName);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check if Component is in Degraded Mode                            |
    //+------------------------------------------------------------------+
    bool IsComponentDegraded(string componentName)
    {
        int index = FindHealthEntry(componentName);
        if(index < 0)
            return false;
        
        return m_healthEntries[index].isInDegradedMode;
    }
};

