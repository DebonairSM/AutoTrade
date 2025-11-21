//+------------------------------------------------------------------+
//| GrandeComponentRegistry.mqh                                      |
//| Copyright 2024, Grande Tech                                      |
//| Dynamic Component Management and Health Monitoring               |
//+------------------------------------------------------------------+
// PURPOSE:
//   Manage all system components dynamically with health monitoring.
//   Provides centralized component registration, access, and status tracking.
//
// RESPONSIBILITIES:
//   - Register and manage system components
//   - Monitor component health status
//   - Provide component lifecycle management
//   - Enable/disable components dynamically
//   - Report component statistics
//
// DEPENDENCIES:
//   - GrandeInterfaces.mqh (for interface definitions)
//
// STATE MANAGED:
//   - List of registered components
//   - Component health statuses
//   - Component performance metrics
//
// PUBLIC INTERFACE:
//   bool RegisterComponent(string name, IMarketAnalyzer* component)
//   IMarketAnalyzer* GetComponent(string name)
//   bool CheckComponentHealth(string name)
//   string GetSystemHealthReport()
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestComponentRegistry.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"

#include "GrandeInterfaces.mqh"

//+------------------------------------------------------------------+
//| Component Registration Entry                                      |
//+------------------------------------------------------------------+
struct ComponentRegistration
{
    string name;
    IMarketAnalyzer* analyzer;
    bool isEnabled;
    ComponentStatus status;
    datetime registrationTime;
    int callCount;
    int successCount;
    int errorCount;
    double avgExecutionTime;
    
    void ComponentRegistration()
    {
        name = "";
        analyzer = NULL;
        isEnabled = true;
        registrationTime = 0;
        callCount = 0;
        successCount = 0;
        errorCount = 0;
        avgExecutionTime = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Component Registry Class                                          |
//+------------------------------------------------------------------+
class CGrandeComponentRegistry
{
private:
    ComponentRegistration m_components[];
    int m_componentCount;
    bool m_initialized;
    bool m_showDebugPrints;
    datetime m_lastHealthCheck;
    
    // Find component index by name
    int FindComponentIndex(string name)
    {
        for(int i = 0; i < m_componentCount; i++)
        {
            if(m_components[i].name == name)
                return i;
        }
        return -1;
    }
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CGrandeComponentRegistry(void) : m_componentCount(0), m_initialized(false), m_showDebugPrints(false)
    {
        m_lastHealthCheck = 0;
        ArrayResize(m_components, 20); // Initial capacity for 20 components
    }
    
    //+------------------------------------------------------------------+
    //| Destructor                                                        |
    //+------------------------------------------------------------------+
    ~CGrandeComponentRegistry(void)
    {
        // Note: We don't delete component instances here as they may be managed externally
        if(m_showDebugPrints)
            Print("[ComponentRegistry] Destroyed with ", m_componentCount, " registered components");
    }
    
    //+------------------------------------------------------------------+
    //| Initialize                                                        |
    //+------------------------------------------------------------------+
    bool Initialize(bool showDebug = false)
    {
        m_showDebugPrints = showDebug;
        m_initialized = true;
        
        if(m_showDebugPrints)
            Print("[ComponentRegistry] Initialized");
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Register Component                                                |
    //+------------------------------------------------------------------+
    bool RegisterComponent(string name, IMarketAnalyzer* analyzer)
    {
        if(analyzer == NULL)
        {
            Print("[ComponentRegistry] ERROR: Cannot register NULL component: ", name);
            return false;
        }
        
        // Check if already registered
        int existingIndex = FindComponentIndex(name);
        if(existingIndex >= 0)
        {
            Print("[ComponentRegistry] WARNING: Component already registered: ", name);
            return false;
        }
        
        // Expand array if needed
        if(m_componentCount >= ArraySize(m_components))
        {
            ArrayResize(m_components, m_componentCount + 10);
        }
        
        // Register new component
        ComponentRegistration reg;
        reg.name = name;
        reg.analyzer = analyzer;
        reg.isEnabled = true;
        reg.status = ComponentStatus::OK(name);
        reg.registrationTime = TimeCurrent();
        reg.callCount = 0;
        reg.successCount = 0;
        reg.errorCount = 0;
        reg.avgExecutionTime = 0.0;
        
        m_components[m_componentCount] = reg;
        m_componentCount++;
        
        if(m_showDebugPrints)
            Print("[ComponentRegistry] Registered component: ", name);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Unregister Component                                              |
    //+------------------------------------------------------------------+
    bool UnregisterComponent(string name)
    {
        int index = FindComponentIndex(name);
        if(index < 0)
        {
            Print("[ComponentRegistry] WARNING: Component not found: ", name);
            return false;
        }
        
        // Shift remaining components
        for(int i = index; i < m_componentCount - 1; i++)
        {
            m_components[i] = m_components[i + 1];
        }
        
        m_componentCount--;
        
        if(m_showDebugPrints)
            Print("[ComponentRegistry] Unregistered component: ", name);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get Component                                                     |
    //+------------------------------------------------------------------+
    IMarketAnalyzer* GetComponent(string name)
    {
        int index = FindComponentIndex(name);
        if(index < 0)
            return NULL;
        
        return m_components[index].analyzer;
    }
    
    //+------------------------------------------------------------------+
    //| Enable/Disable Component                                          |
    //+------------------------------------------------------------------+
    bool EnableComponent(string name, bool enable)
    {
        int index = FindComponentIndex(name);
        if(index < 0)
        {
            Print("[ComponentRegistry] WARNING: Component not found: ", name);
            return false;
        }
        
        m_components[index].isEnabled = enable;
        
        if(m_showDebugPrints)
            Print("[ComponentRegistry] Component ", name, " ", enable ? "enabled" : "disabled");
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check if Component is Enabled                                     |
    //+------------------------------------------------------------------+
    bool IsComponentEnabled(string name)
    {
        int index = FindComponentIndex(name);
        if(index < 0)
            return false;
        
        return m_components[index].isEnabled;
    }
    
    //+------------------------------------------------------------------+
    //| Check Component Health                                            |
    //+------------------------------------------------------------------+
    bool CheckComponentHealth(string name)
    {
        int index = FindComponentIndex(name);
        if(index < 0)
        {
            Print("[ComponentRegistry] WARNING: Component not found: ", name);
            return false;
        }
        
        if(m_components[index].analyzer == NULL)
            return false;
        
        bool isHealthy = m_components[index].analyzer.IsHealthy();
        
        // Update status
        if(isHealthy)
        {
            m_components[index].status.health = HEALTH_OK;
            m_components[index].status.statusMessage = "Component operating normally";
        }
        else
        {
            m_components[index].status.health = HEALTH_ERROR;
            m_components[index].status.statusMessage = m_components[index].analyzer.GetStatus();
        }
        
        m_components[index].status.lastUpdate = TimeCurrent();
        
        return isHealthy;
    }
    
    //+------------------------------------------------------------------+
    //| Check All Components Health                                       |
    //+------------------------------------------------------------------+
    void CheckAllComponentsHealth()
    {
        for(int i = 0; i < m_componentCount; i++)
        {
            if(m_components[i].isEnabled)
            {
                CheckComponentHealth(m_components[i].name);
            }
        }
        
        m_lastHealthCheck = TimeCurrent();
    }
    
    //+------------------------------------------------------------------+
    //| Get Component Status                                              |
    //+------------------------------------------------------------------+
    ComponentStatus GetComponentStatus(string name)
    {
        int index = FindComponentIndex(name);
        if(index < 0)
            return ComponentStatus::Error(name, "Component not found");
        
        return m_components[index].status;
    }
    
    //+------------------------------------------------------------------+
    //| Run All Enabled Analyzers                                        |
    //+------------------------------------------------------------------+
    int RunAllAnalyzers(AnalysisResult &results[])
    {
        int resultsCount = 0;
        ArrayResize(results, m_componentCount);
        
        for(int i = 0; i < m_componentCount; i++)
        {
            if(!m_components[i].isEnabled)
                continue;
            
            if(m_components[i].analyzer == NULL)
                continue;
            
            // Track execution time
            uint startTime = GetTickCount();
            
            // Run analyzer
            AnalysisResult result = m_components[i].analyzer.Analyze();
            result.componentName = m_components[i].name;
            
            // Track execution time
            uint executionTime = GetTickCount() - startTime;
            
            // Update statistics
            m_components[i].callCount++;
            if(result.isValid)
                m_components[i].successCount++;
            else
                m_components[i].errorCount++;
            
            // Update average execution time
            double prevAvg = m_components[i].avgExecutionTime;
            m_components[i].avgExecutionTime = (prevAvg * (m_components[i].callCount - 1) + executionTime) / m_components[i].callCount;
            
            // Store result
            results[resultsCount] = result;
            resultsCount++;
        }
        
        // Resize results array to actual count
        if(resultsCount < ArraySize(results))
            ArrayResize(results, resultsCount);
        
        return resultsCount;
    }
    
    //+------------------------------------------------------------------+
    //| Get Component Count                                               |
    //+------------------------------------------------------------------+
    int GetComponentCount() { return m_componentCount; }
    
    //+------------------------------------------------------------------+
    //| Get Enabled Component Count                                       |
    //+------------------------------------------------------------------+
    int GetEnabledComponentCount()
    {
        int count = 0;
        for(int i = 0; i < m_componentCount; i++)
        {
            if(m_components[i].isEnabled)
                count++;
        }
        return count;
    }
    
    //+------------------------------------------------------------------+
    //| Get System Health Report                                          |
    //+------------------------------------------------------------------+
    string GetSystemHealthReport()
    {
        string report = "\n=== COMPONENT HEALTH REPORT ===\n";
        report += StringFormat("Total Components: %d (Enabled: %d)\n", 
                              m_componentCount, GetEnabledComponentCount());
        report += StringFormat("Last Health Check: %s\n", 
                              TimeToString(m_lastHealthCheck, TIME_DATE|TIME_MINUTES));
        report += "\nCOMPONENTS:\n";
        
        for(int i = 0; i < m_componentCount; i++)
        {
            string status = m_components[i].isEnabled ? "ENABLED" : "DISABLED";
            string health = HealthToString(m_components[i].status.health);
            
            report += StringFormat("  [%s] %s - %s\n", status, m_components[i].name, health);
            
            if(m_components[i].status.health != HEALTH_OK)
            {
                report += StringFormat("    Status: %s\n", m_components[i].status.statusMessage);
                report += StringFormat("    Errors: %d, Warnings: %d\n", 
                                     m_components[i].status.errorCount, 
                                     m_components[i].status.warningCount);
            }
            
            if(m_components[i].callCount > 0)
            {
                double successRate = (double)m_components[i].successCount / m_components[i].callCount * 100.0;
                report += StringFormat("    Calls: %d, Success: %.1f%%, Avg Time: %.1fms\n", 
                                     m_components[i].callCount, 
                                     successRate, 
                                     m_components[i].avgExecutionTime);
            }
        }
        
        report += "==============================\n";
        
        return report;
    }
    
    //+------------------------------------------------------------------+
    //| Get Component Statistics                                          |
    //+------------------------------------------------------------------+
    string GetComponentStatistics(string name)
    {
        int index = FindComponentIndex(name);
        if(index < 0)
            return "Component not found: " + name;
        
        ComponentRegistration reg = m_components[index];
        
        string stats = "\n=== COMPONENT STATISTICS ===\n";
        stats += StringFormat("Name: %s\n", reg.name);
        stats += StringFormat("Status: %s (%s)\n", 
                            reg.isEnabled ? "ENABLED" : "DISABLED",
                            HealthToString(reg.status.health));
        stats += StringFormat("Registered: %s\n", 
                            TimeToString(reg.registrationTime, TIME_DATE|TIME_MINUTES));
        stats += StringFormat("Total Calls: %d\n", reg.callCount);
        
        if(reg.callCount > 0)
        {
            double successRate = (double)reg.successCount / reg.callCount * 100.0;
            stats += StringFormat("Success Rate: %.1f%% (%d/%d)\n", 
                                successRate, reg.successCount, reg.callCount);
            stats += StringFormat("Error Count: %d\n", reg.errorCount);
            stats += StringFormat("Avg Execution Time: %.2fms\n", reg.avgExecutionTime);
        }
        
        stats += "===========================\n";
        
        return stats;
    }
    
    //+------------------------------------------------------------------+
    //| Reset Component Statistics                                        |
    //+------------------------------------------------------------------+
    void ResetComponentStatistics(string name)
    {
        int index = FindComponentIndex(name);
        if(index < 0)
            return;
        
        m_components[index].callCount = 0;
        m_components[index].successCount = 0;
        m_components[index].errorCount = 0;
        m_components[index].avgExecutionTime = 0.0;
        
        if(m_showDebugPrints)
            Print("[ComponentRegistry] Reset statistics for: ", name);
    }
    
    //+------------------------------------------------------------------+
    //| Reset All Statistics                                              |
    //+------------------------------------------------------------------+
    void ResetAllStatistics()
    {
        for(int i = 0; i < m_componentCount; i++)
        {
            m_components[i].callCount = 0;
            m_components[i].successCount = 0;
            m_components[i].errorCount = 0;
            m_components[i].avgExecutionTime = 0.0;
        }
        
        if(m_showDebugPrints)
            Print("[ComponentRegistry] Reset all component statistics");
    }
};

