//+------------------------------------------------------------------+
//| GrandeTestSuite.mqh                                              |
//| Copyright 2024, Grande Tech                                      |
//| Comprehensive Testing Suite for Grande Trading System           |
//+------------------------------------------------------------------+
// PURPOSE:
//   Provide comprehensive testing infrastructure for all system components.
//   Enables regression testing, validation, and quality assurance.
//
// RESPONSIBILITIES:
//   - Run tests for all components
//   - Report test results
//   - Track test statistics
//   - Provide test fixtures and utilities
//
// DEPENDENCIES:
//   - All Grande components
//
// PUBLIC INTERFACE:
//   bool RunAllTests() - Run complete test suite
//   string GetTestReport() - Get detailed test report
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"

#include "../Include/GrandeStateManager.mqh"
#include "../Include/GrandeConfigManager.mqh"
#include "../Include/GrandeComponentRegistry.mqh"
#include "../Include/GrandeHealthMonitor.mqh"
#include "../Include/GrandeEventBus.mqh"
#include "../Include/GrandeInterfaces.mqh"

//+------------------------------------------------------------------+
//| Test Result Structure                                             |
//+------------------------------------------------------------------+
struct TestResult
{
    string testName;
    bool passed;
    string message;
    datetime executionTime;
    int assertionsPassed;
    int assertionsFailed;
    
    void TestResult()
    {
        testName = "";
        passed = false;
        message = "";
        executionTime = 0;
        assertionsPassed = 0;
        assertionsFailed = 0;
    }
};

//+------------------------------------------------------------------+
//| Test Assertion Macro Helpers                                      |
//+------------------------------------------------------------------+
#define ASSERT_TRUE(condition, message) \
    if(condition) { \
        result.assertionsPassed++; \
    } else { \
        result.assertionsFailed++; \
        result.passed = false; \
        result.message += "FAILED: " + message + "\n"; \
        Print("[TEST] ASSERTION FAILED: ", message); \
    }

#define ASSERT_FALSE(condition, message) ASSERT_TRUE(!(condition), message)

#define ASSERT_EQUAL(expected, actual, message) \
    if(expected == actual) { \
        result.assertionsPassed++; \
    } else { \
        result.assertionsFailed++; \
        result.passed = false; \
        result.message += "FAILED: " + message + " (Expected: " + (string)expected + ", Actual: " + (string)actual + ")\n"; \
        Print("[TEST] ASSERTION FAILED: ", message); \
    }

#define ASSERT_NOT_NULL(pointer, message) \
    if(pointer != NULL) { \
        result.assertionsPassed++; \
    } else { \
        result.assertionsFailed++; \
        result.passed = false; \
        result.message += "FAILED: " + message + " (Pointer is NULL)\n"; \
        Print("[TEST] ASSERTION FAILED: ", message); \
    }

//+------------------------------------------------------------------+
//| Grande Test Suite Class                                          |
//+------------------------------------------------------------------+
class CGrandeTestSuite
{
private:
    TestResult m_results[];
    int m_resultCount;
    int m_testsPassed;
    int m_testsFailed;
    datetime m_suiteStartTime;
    datetime m_suiteEndTime;
    
    // Add test result
    void AddResult(const TestResult &result)
    {
        if(m_resultCount >= ArraySize(m_results))
            ArrayResize(m_results, m_resultCount + 10);
        
        m_results[m_resultCount] = result;
        m_resultCount++;
        
        if(result.passed)
            m_testsPassed++;
        else
            m_testsFailed++;
    }
    
    // Create test result template
    TestResult CreateTestResult(string name)
    {
        TestResult result;
        result.testName = name;
        result.passed = true;
        result.message = "";
        result.executionTime = TimeCurrent();
        result.assertionsPassed = 0;
        result.assertionsFailed = 0;
        return result;
    }
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CGrandeTestSuite(void) : m_resultCount(0), m_testsPassed(0), m_testsFailed(0)
    {
        ArrayResize(m_results, 50);
    }
    
    //+------------------------------------------------------------------+
    //| Test State Manager                                                |
    //+------------------------------------------------------------------+
    bool TestStateManager()
    {
        TestResult result = CreateTestResult("State Manager");
        Print("[TEST] Running: State Manager tests...");
        
        // Create state manager
        CGrandeStateManager* sm = new CGrandeStateManager();
        ASSERT_NOT_NULL(sm, "State manager creation");
        
        // Test initialization
        bool initResult = sm.Initialize("EURUSD", false);
        ASSERT_TRUE(initResult, "State manager initialization");
        
        // Test regime state
        RegimeSnapshot regime;
        regime.regime = REGIME_TREND_BULL;
        regime.confidence = 0.85;
        regime.timestamp = TimeCurrent();
        sm.SetCurrentRegime(regime);
        
        RegimeSnapshot retrieved = sm.GetCurrentRegime();
        ASSERT_EQUAL((int)REGIME_TREND_BULL, (int)retrieved.regime, "Regime state get/set");
        ASSERT_TRUE(MathAbs(retrieved.confidence - 0.85) < 0.001, "Regime confidence get/set");
        
        // Test ATR state
        sm.SetCurrentATR(0.0010);
        ASSERT_TRUE(MathAbs(sm.GetCurrentATR() - 0.0010) < 0.00001, "ATR get/set");
        
        sm.SetAverageATR(0.0008);
        ASSERT_TRUE(MathAbs(sm.GetAverageATR() - 0.0008) < 0.00001, "Average ATR get/set");
        
        // Test cool-off state
        CoolOffInfo coolOff;
        coolOff.isActive = true;
        coolOff.lastExitTime = TimeCurrent();
        coolOff.lastDirection = 0;
        sm.SetCoolOffInfo(coolOff);
        
        ASSERT_TRUE(sm.IsInCoolOff(), "Cool-off status");
        
        // Test state validation
        ASSERT_TRUE(sm.ValidateState(), "State validation");
        
        // Cleanup
        delete sm;
        
        AddResult(result);
        return result.passed;
    }
    
    //+------------------------------------------------------------------+
    //| Test Config Manager                                               |
    //+------------------------------------------------------------------+
    bool TestConfigManager()
    {
        TestResult result = CreateTestResult("Config Manager");
        Print("[TEST] Running: Config Manager tests...");
        
        // Create config manager
        CGrandeConfigManager* cm = new CGrandeConfigManager();
        ASSERT_NOT_NULL(cm, "Config manager creation");
        
        // Test initialization
        bool initResult = cm.Initialize("EURUSD", false);
        ASSERT_TRUE(initResult, "Config manager initialization");
        
        // Test regime config
        RegimeDetectionConfig regimeConfig = cm.GetRegimeConfig();
        ASSERT_TRUE(regimeConfig.adx_trend_threshold > 0, "Regime config has defaults");
        
        // Test risk config
        RiskManagementConfig riskConfig = cm.GetRiskConfig();
        ASSERT_TRUE(riskConfig.max_risk_per_trade > 0, "Risk config has defaults");
        
        // Test validation
        ASSERT_TRUE(cm.Validate(), "Config validation passes with defaults");
        
        // Test invalid config
        riskConfig.max_risk_per_trade = -1.0;
        cm.SetRiskConfig(riskConfig);
        ASSERT_FALSE(cm.Validate(), "Config validation fails with invalid values");
        
        // Cleanup
        delete cm;
        
        AddResult(result);
        return result.passed;
    }
    
    //+------------------------------------------------------------------+
    //| Test Component Registry                                           |
    //+------------------------------------------------------------------+
    bool TestComponentRegistry()
    {
        TestResult result = CreateTestResult("Component Registry");
        Print("[TEST] Running: Component Registry tests...");
        
        // Create registry
        CGrandeComponentRegistry* registry = new CGrandeComponentRegistry();
        ASSERT_NOT_NULL(registry, "Registry creation");
        
        // Test initialization
        bool initResult = registry.Initialize(false);
        ASSERT_TRUE(initResult, "Registry initialization");
        
        // Test initial state
        ASSERT_EQUAL(0, registry.GetComponentCount(), "Initial component count is zero");
        ASSERT_EQUAL(0, registry.GetEnabledComponentCount(), "Initial enabled count is zero");
        
        // Note: Full registration tests would require actual component instances
        // This tests the registry infrastructure
        
        // Cleanup
        delete registry;
        
        AddResult(result);
        return result.passed;
    }
    
    //+------------------------------------------------------------------+
    //| Test Health Monitor                                               |
    //+------------------------------------------------------------------+
    bool TestHealthMonitor()
    {
        TestResult result = CreateTestResult("Health Monitor");
        Print("[TEST] Running: Health Monitor tests...");
        
        // Create health monitor
        CGrandeHealthMonitor* hm = new CGrandeHealthMonitor();
        ASSERT_NOT_NULL(hm, "Health monitor creation");
        
        // Test initialization
        bool initResult = hm.Initialize(NULL, false);
        ASSERT_TRUE(initResult, "Health monitor initialization");
        
        // Test initial health
        ASSERT_EQUAL((int)SYSTEM_HEALTHY, (int)hm.GetSystemHealth(), "Initial system health is HEALTHY");
        
        // Test can trade
        ASSERT_TRUE(hm.CanTrade(), "Initially can trade");
        
        // Test critical component flags
        ASSERT_TRUE(hm.IsRegimeDetectorHealthy(), "Regime detector initially healthy");
        ASSERT_TRUE(hm.IsRiskManagerHealthy(), "Risk manager initially healthy");
        
        // Test setting component health
        hm.SetRiskManagerHealth(false);
        ASSERT_FALSE(hm.CanTrade(), "Cannot trade when risk manager unhealthy");
        
        // Cleanup
        delete hm;
        
        AddResult(result);
        return result.passed;
    }
    
    //+------------------------------------------------------------------+
    //| Test Event Bus                                                    |
    //+------------------------------------------------------------------+
    bool TestEventBus()
    {
        TestResult result = CreateTestResult("Event Bus");
        Print("[TEST] Running: Event Bus tests...");
        
        // Create event bus
        CGrandeEventBus* eb = new CGrandeEventBus();
        ASSERT_NOT_NULL(eb, "Event bus creation");
        
        // Test initialization
        bool initResult = eb.Initialize(100, false, false);
        ASSERT_TRUE(initResult, "Event bus initialization");
        
        // Test publishing events
        eb.PublishEvent(EVENT_SIGNAL_GENERATED, "TestComponent", "Test signal", 1.0, 0);
        ASSERT_TRUE(eb.GetEventCount() >= 1, "Event count increased after publish");
        
        // Test event retrieval
        SystemEvent events[];
        int count = eb.GetEvents(events, EVENT_SIGNAL_GENERATED);
        ASSERT_TRUE(count >= 1, "Event retrieved successfully");
        
        // Test recent events
        SystemEvent recentEvents[];
        int recentCount = eb.GetRecentEvents(recentEvents, 5);
        ASSERT_TRUE(recentCount >= 1, "Recent events retrieved");
        
        // Test clear events
        eb.ClearEvents();
        ASSERT_EQUAL(0, eb.GetEventCount(), "Events cleared successfully");
        
        // Cleanup
        delete eb;
        
        AddResult(result);
        return result.passed;
    }
    
    //+------------------------------------------------------------------+
    //| Test Interfaces and Structures                                    |
    //+------------------------------------------------------------------+
    bool TestInterfaces()
    {
        TestResult result = CreateTestResult("Interfaces and Structures");
        Print("[TEST] Running: Interfaces tests...");
        
        // Test AnalysisResult structure
        AnalysisResult ar = AnalysisResult::Valid(SIGNAL_BUY, 0.75, "Test signal");
        ASSERT_TRUE(ar.isValid, "AnalysisResult valid result");
        ASSERT_EQUAL((int)SIGNAL_BUY, (int)ar.signal, "AnalysisResult signal type");
        ASSERT_TRUE(MathAbs(ar.confidence - 0.75) < 0.001, "AnalysisResult confidence");
        
        AnalysisResult invalid = AnalysisResult::Invalid("Test error");
        ASSERT_FALSE(invalid.isValid, "AnalysisResult invalid result");
        
        // Test helper functions
        string signalStr = SignalTypeToString(SIGNAL_BUY);
        ASSERT_EQUAL("BUY", signalStr, "SignalTypeToString conversion");
        
        SIGNAL_TYPE signal = StringToSignalType("BUY");
        ASSERT_EQUAL((int)SIGNAL_BUY, (int)signal, "StringToSignalType conversion");
        
        // Test health status
        ComponentStatus status = ComponentStatus::OK("TestComponent");
        ASSERT_EQUAL((int)HEALTH_OK, (int)status.health, "ComponentStatus OK creation");
        
        ComponentStatus errorStatus = ComponentStatus::Error("TestComponent", "Test error");
        ASSERT_EQUAL((int)HEALTH_ERROR, (int)errorStatus.health, "ComponentStatus Error creation");
        ASSERT_EQUAL(1, errorStatus.errorCount, "Error count tracking");
        
        AddResult(result);
        return result.passed;
    }
    
    //+------------------------------------------------------------------+
    //| Run All Tests                                                     |
    //+------------------------------------------------------------------+
    bool RunAllTests()
    {
        Print("\n====================================");
        Print("GRANDE TRADING SYSTEM - TEST SUITE");
        Print("====================================\n");
        
        m_suiteStartTime = TimeCurrent();
        m_resultCount = 0;
        m_testsPassed = 0;
        m_testsFailed = 0;
        
        // Run infrastructure tests
        Print("\n--- Infrastructure Tests ---");
        TestInterfaces();
        TestStateManager();
        TestConfigManager();
        TestComponentRegistry();
        TestHealthMonitor();
        TestEventBus();
        
        // Component tests would go here
        Print("\n--- Component Tests ---");
        Print("[TEST] Component tests not yet implemented");
        
        // Integration tests would go here
        Print("\n--- Integration Tests ---");
        Print("[TEST] Integration tests not yet implemented");
        
        m_suiteEndTime = TimeCurrent();
        
        // Print summary
        PrintTestReport();
        
        return m_testsFailed == 0;
    }
    
    //+------------------------------------------------------------------+
    //| Get Test Report                                                   |
    //+------------------------------------------------------------------+
    string GetTestReport()
    {
        string report = "\n====================================\n";
        report += "TEST SUITE REPORT\n";
        report += "====================================\n\n";
        
        report += StringFormat("Total Tests: %d\n", m_resultCount);
        report += StringFormat("Passed: %d (%.1f%%)\n", 
                              m_testsPassed, 
                              m_resultCount > 0 ? (double)m_testsPassed / m_resultCount * 100.0 : 0.0);
        report += StringFormat("Failed: %d\n", m_testsFailed);
        
        int totalAssertions = 0;
        int totalAssertionsPassed = 0;
        for(int i = 0; i < m_resultCount; i++)
        {
            totalAssertions += m_results[i].assertionsPassed + m_results[i].assertionsFailed;
            totalAssertionsPassed += m_results[i].assertionsPassed;
        }
        
        report += StringFormat("Total Assertions: %d\n", totalAssertions);
        report += StringFormat("Assertions Passed: %d (%.1f%%)\n\n", 
                              totalAssertionsPassed,
                              totalAssertions > 0 ? (double)totalAssertionsPassed / totalAssertions * 100.0 : 0.0);
        
        report += "TEST DETAILS:\n";
        report += "------------------------------------\n";
        
        for(int i = 0; i < m_resultCount; i++)
        {
            string status = m_results[i].passed ? "PASS" : "FAIL";
            report += StringFormat("[%s] %s\n", status, m_results[i].testName);
            report += StringFormat("  Assertions: %d passed, %d failed\n", 
                                 m_results[i].assertionsPassed, 
                                 m_results[i].assertionsFailed);
            
            if(!m_results[i].passed)
            {
                report += "  Failures:\n";
                report += StringFormat("  %s\n", m_results[i].message);
            }
        }
        
        report += "\n====================================\n";
        report += StringFormat("Suite completed in %d seconds\n", 
                              (int)(m_suiteEndTime - m_suiteStartTime));
        report += "====================================\n";
        
        return report;
    }
    
    //+------------------------------------------------------------------+
    //| Print Test Report                                                 |
    //+------------------------------------------------------------------+
    void PrintTestReport()
    {
        Print(GetTestReport());
    }
    
    //+------------------------------------------------------------------+
    //| Get Test Statistics                                               |
    //+------------------------------------------------------------------+
    string GetTestStatistics()
    {
        string stats = "\n=== TEST STATISTICS ===\n";
        stats += StringFormat("Tests Run: %d\n", m_resultCount);
        stats += StringFormat("Passed: %d\n", m_testsPassed);
        stats += StringFormat("Failed: %d\n", m_testsFailed);
        stats += StringFormat("Success Rate: %.1f%%\n", 
                            m_resultCount > 0 ? (double)m_testsPassed / m_resultCount * 100.0 : 0.0);
        stats += "======================\n";
        
        return stats;
    }
};

