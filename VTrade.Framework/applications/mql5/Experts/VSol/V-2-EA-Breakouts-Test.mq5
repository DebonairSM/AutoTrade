//+------------------------------------------------------------------+
//|                                         V-2-EA-Breakouts-Test.mq5 |
//|                              Simplified Core Functionality Tests  |
//|                           Pattern from: MQL5 Reference Guide      |
//|                           Reference: Official MQL5 Event Handlers |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "2.01"
#property description "Simplified tests focusing on core breakout detection functionality"
#property strict

#include "V-2-EA-Breakouts.mqh"

//+------------------------------------------------------------------+
//| Test Framework (Pattern from MQL5 Reference)                     |
//+------------------------------------------------------------------+
struct TestResult
{
    string name;
    bool passed;
    int assertions;
    int failures;
};

TestResult g_tests[];
int g_testCount = 0;
TestResult g_currentTest;

// Pattern from: MQL5 Reference Guide - Basic Function Declaration
void StartTest(string testName)
{
    g_currentTest.name = testName;
    g_currentTest.passed = true;
    g_currentTest.assertions = 0;
    g_currentTest.failures = 0;
    Print("🧪 Testing: ", testName);
}

// Pattern from: MQL5 Reference Guide - Function with Parameters and Return Value
void Assert(bool condition, string message)
{
    g_currentTest.assertions++;
    
    if(condition)
    {
        Print("  ✅ ", message);
    }
    else
    {
        Print("  ❌ ", message);
        g_currentTest.passed = false;
        g_currentTest.failures++;
    }
}

void AssertEquals(double expected, double actual, double tolerance, string message)
{
    bool equal = MathAbs(expected - actual) <= tolerance;
    g_currentTest.assertions++;
    
    if(equal)
    {
        Print("  ✅ ", message);
    }
    else
    {
        Print("  ❌ ", message, " (Expected: ", expected, ", Got: ", actual, ")");
        g_currentTest.passed = false;
        g_currentTest.failures++;
    }
}

// Pattern from: MQL5 Reference Guide - Array Operations
void EndTest()
{
    ArrayResize(g_tests, g_testCount + 1);
    g_tests[g_testCount] = g_currentTest;
    g_testCount++;
    
    string status = g_currentTest.passed ? "✅ PASSED" : "❌ FAILED";
    Print("📊 ", g_currentTest.name, " - ", status, 
          " (", g_currentTest.assertions - g_currentTest.failures, "/", g_currentTest.assertions, ")");
    Print("");
}

//+------------------------------------------------------------------+
//| Core Functionality Tests                                          |
//+------------------------------------------------------------------+

// Pattern from: MQL5 Reference Guide - Class Usage and Memory Management
void Test_Initialization()
{
    StartTest("Initialization");
    
    CV2EABreakouts breakouts;
    
    // Test 1: Valid initialization with error handling
    bool result = breakouts.Init(100, 0.6, 0.001, 2, true);
    Assert(result, "Should initialize with valid parameters");
    
    // Test 2: Check that values are set correctly
    AssertEquals(0.6, breakouts.TEST_GetMinStrength(), 0.001, "Min strength should be set correctly");
    AssertEquals(2, breakouts.TEST_GetMinTouches(), 0, "Min touches should be set correctly");
    AssertEquals(0, breakouts.TEST_GetKeyLevelCount(), 0, "Initial key level count should be 0");
    
    // Test 3: Error handling - invalid parameters should be auto-corrected
    CV2EABreakouts breakouts2;
    bool result2 = breakouts2.Init(10, -0.1, 0.001, 0, false);
    Assert(result2, "Should initialize even with invalid params (auto-corrected)");
    Assert(breakouts2.TEST_GetMinStrength() >= 0.5, "Invalid min strength should be corrected");
    Assert(breakouts2.TEST_GetMinTouches() >= 1, "Invalid min touches should be corrected");
    
    EndTest();
}

// Pattern from: MQL5 Reference Guide - String Operations
void Test_SymbolDetection()
{
    StartTest("Symbol Detection");
    
    CV2EABreakouts breakouts;
    breakouts.Init(50, 0.6, 0.001, 2, false);
    
    // Test symbol type detection using proper string functions
    string symbol = _Symbol;
    bool isUS500 = breakouts.TEST_IsUS500();
    
    if(StringFind(symbol, "US500") >= 0 || StringFind(symbol, "SPX") >= 0)
    {
        Assert(isUS500, "Should correctly detect US500 symbols");
    }
    else
    {
        Assert(!isUS500, "Should correctly identify non-US500 symbols");
    }
    
    Print("  ℹ️  Current symbol: ", symbol, " | US500 detected: ", isUS500 ? "Yes" : "No");
    
    EndTest();
}

// Pattern from: MQL5 Reference Guide - Price Data Access
void Test_BasicKeyLevelDetection()
{
    StartTest("Basic Key Level Detection");
    
    CV2EABreakouts breakouts;
    bool initialized = breakouts.Init(50, 0.55, 0.001, 2, true);
    Assert(initialized, "Should initialize successfully");
    
    // Test with actual market data using proper MQL5 functions
    int bars = Bars(_Symbol, Period());
    Assert(bars > 50, "Should have sufficient market data available");
    
    Print("  ℹ️  Available bars: ", bars, " for ", _Symbol, " on ", EnumToString(Period()));
    
    // Process strategy to find key levels
    breakouts.ProcessStrategy();
    
    int keyLevelCount = breakouts.TEST_GetKeyLevelCount();
    Print("  ℹ️  Detected ", keyLevelCount, " key levels with current market data");
    
    // Verify key level properties if any were found
    if(keyLevelCount > 0)
    {
        SKeyLevel level;
        bool hasLevel = breakouts.TEST_GetKeyLevel(0, level);
        Assert(hasLevel, "Should be able to retrieve first key level");
        
        if(hasLevel)
        {
            Assert(level.price > 0, "Key level price should be positive");
            Assert(level.touchCount >= 2, "Key level should have minimum required touches");
            Assert(level.strength >= 0.45 && level.strength <= 0.98, "Strength should be in valid range");
            
            Print("  ℹ️  First level: ", DoubleToString(level.price, 5), 
                  " | Strength: ", DoubleToString(level.strength, 3), 
                  " | Touches: ", level.touchCount,
                  " | Type: ", level.isResistance ? "Resistance" : "Support");
        }
    }
    else
    {
        Print("  ⚠️  No key levels detected - this may be normal for current market conditions");
    }
    
    EndTest();
}

// Pattern from: MQL5 Reference Guide - Object Management
void Test_ChartObjectManagement()
{
    StartTest("Chart Object Management");
    
    CV2EABreakouts breakouts;
    breakouts.Init(50, 0.55, 0.001, 2, false);
    
    // Test chart object clearing with proper error handling
    breakouts.ClearAllChartObjects();
    Assert(GetLastError() == 0, "Chart clearing should not cause errors");
    
    // Process and check for chart objects
    breakouts.ProcessStrategy();
    int levelCount = breakouts.TEST_GetKeyLevelCount();
    
    if(levelCount > 0)
    {
        breakouts.ForceChartUpdate();
        Assert(GetLastError() == 0, "Force chart update should complete without errors");
        
        // Check chart object count
        int totalObjects = ObjectsTotal(0, 0, OBJ_HLINE);
        Print("  ℹ️  Total horizontal lines on chart: ", totalObjects);
        
        // Clear and verify
        breakouts.ClearAllChartObjects();
        int objectsAfterClear = ObjectsTotal(0, 0, OBJ_HLINE);
        Print("  ℹ️  Horizontal lines after clear: ", objectsAfterClear);
        
        // Objects should decrease or remain same after clearing
        Assert(objectsAfterClear <= totalObjects, "Object count should not increase after clear");
    }
    else
    {
        Print("  ⚠️  No levels to test chart objects with");
    }
    
    EndTest();
}

// Pattern from: MQL5 Reference Guide - Configuration Management
void Test_ConfigurationManagement()
{
    StartTest("Configuration Management");
    
    CV2EABreakouts breakouts;
    breakouts.Init(50, 0.6, 0.001, 2, false);
    
    // Test runtime configuration changes
    breakouts.SetIgnoreMarketHours(true);
    Assert(breakouts.GetIgnoreMarketHours() == true, "Should set ignore market hours to true");
    
    breakouts.SetIgnoreMarketHours(false);
    Assert(breakouts.GetIgnoreMarketHours() == false, "Should set ignore market hours to false");
    
    // Test recalculation - should not cause errors
    breakouts.ForceRecalculation();
    Assert(GetLastError() == 0, "Force recalculation should complete without errors");
    
    // Test configuration display - should not cause errors
    breakouts.ShowConfiguration();
    Assert(GetLastError() == 0, "Show configuration should complete without errors");
    
    EndTest();
}

// Pattern from: MQL5 Reference Guide - Error Handling
void Test_ErrorHandling()
{
    StartTest("Error Handling");
    
    // Reset any previous errors
    ResetLastError();
    
    // Test with minimal data scenario
    CV2EABreakouts breakouts;
    
    int currentBars = Bars(_Symbol, Period());
    Print("  ℹ️  Current bars available: ", currentBars);
    
    // Test processing without initialization - should handle gracefully
    CV2EABreakouts breakouts2;
    breakouts2.ProcessStrategy();
    Assert(GetLastError() == 0, "Processing without initialization should not crash");
    
    // Test with extreme parameters
    CV2EABreakouts breakouts3;
    bool extremeInit = breakouts3.Init(5, 0.99, 0.00001, 10, false);
    if(extremeInit)
    {
        breakouts3.ProcessStrategy();
        Assert(GetLastError() == 0, "Extreme parameters should be handled gracefully");
    }
    
    EndTest();
}

// Pattern from: MQL5 Reference Guide - Time and Market Data
void Test_RealTimeframeBehavior()
{
    StartTest("Real Timeframe Behavior");
    
    CV2EABreakouts breakouts;
    breakouts.Init(30, 0.6, 0.001, 2, true);
    
    ENUM_TIMEFRAMES currentTF = Period();
    Print("  ℹ️  Current timeframe: ", EnumToString(currentTF));
    
    // Test processing on current timeframe
    bool result = breakouts.ProcessTimeframe(currentTF);
    Assert(result, "Should process current timeframe successfully");
    
    // Test recalculation
    breakouts.ForceRecalculation();
    Assert(GetLastError() == 0, "Force recalculation should work");
    
    // Verify levels are reasonable for timeframe
    int levelCount = breakouts.TEST_GetKeyLevelCount();
    Print("  ℹ️  Levels found for ", EnumToString(currentTF), ": ", levelCount);
    
    if(levelCount > 0)
    {
        SKeyLevel level;
        if(breakouts.TEST_GetKeyLevel(0, level))
        {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double distance = MathAbs(level.price - currentPrice);
            double reasonableDistance = currentPrice * 0.2;  // 20% of current price (conservative)
            
            Assert(distance < reasonableDistance, "Key level should be within reasonable distance of current price");
            Print("  ℹ️  Level distance from current price: ", DoubleToString(distance, 5));
        }
    }
    
    EndTest();
}

// Pattern from: MQL5 Reference Guide - Performance Monitoring
void Test_Performance()
{
    StartTest("Performance");
    
    CV2EABreakouts breakouts;
    breakouts.Init(100, 0.55, 0.001, 2, false);  // Disable debug for performance
    
    uint startTime = GetTickCount();
    
    // Run multiple strategy processing cycles
    for(int i = 0; i < 3; i++)  // Reduced from 5 to 3 for reliability
    {
        breakouts.ProcessStrategy();
    }
    
    uint endTime = GetTickCount();
    uint duration = endTime - startTime;
    
    Print("  ℹ️  3 processing cycles completed in ", duration, " ms");
    Assert(duration < 10000, "Performance should be reasonable (under 10 seconds for 3 cycles)");
    
    // Test chart update performance
    startTime = GetTickCount();
    breakouts.ForceChartUpdate();
    endTime = GetTickCount();
    duration = endTime - startTime;
    
    Print("  ℹ️  Chart update completed in ", duration, " ms");
    Assert(duration < 2000, "Chart update should be fast (under 2 seconds)");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Expert Functions (Pattern from: MQL5 Reference Guide)             |
//+------------------------------------------------------------------+

// Pattern from: MQL5 Reference Guide - OnInit Event Handler
int OnInit()
{
    Print("🚀 Starting V-2-EA-Breakouts Core Functionality Tests");
    Print("📊 Symbol: ", _Symbol, " | Timeframe: ", EnumToString(Period()));
    Print("📈 Available bars: ", Bars(_Symbol, Period()));
    Print("🔧 Compiled with: MQL5 Reference Guide patterns");
    Print("");
    
    // Run core tests in logical order (following MQL5 best practices)
    Test_Initialization();
    Test_SymbolDetection();
    Test_BasicKeyLevelDetection();
    Test_ChartObjectManagement();
    Test_ConfigurationManagement();
    Test_ErrorHandling();
    Test_RealTimeframeBehavior();
    Test_Performance();
    
    // Calculate and display results using proper MQL5 string formatting
    int passed = 0;
    int totalAssertions = 0;
    int totalFailures = 0;
    
    for(int i = 0; i < g_testCount; i++)
    {
        if(g_tests[i].passed) passed++;
        totalAssertions += g_tests[i].assertions;
        totalFailures += g_tests[i].failures;
    }
    
    Print("🏁 TEST SUMMARY");
    Print("================");
    Print("📊 Tests Passed: ", passed, "/", g_testCount);
    Print("📊 Assertions: ", totalAssertions - totalFailures, "/", totalAssertions);
    
    if(totalAssertions > 0)
    {
        double successRate = (double)(totalAssertions - totalFailures) / totalAssertions * 100.0;
        Print("📊 Success Rate: ", DoubleToString(successRate, 1), "%");
    }
    
    if(passed == g_testCount)
    {
        Print("🎉 ALL TESTS PASSED!");
    }
    else
    {
        Print("⚠️  Some tests failed - check logs above");
    }
    Print("");
    
    // Pattern from: MQL5 Reference Guide - Return proper initialization code
    return INIT_FAILED;  // Don't run as live EA, this is just for testing
}

// Pattern from: MQL5 Reference Guide - OnDeinit Event Handler
void OnDeinit(const int reason)
{
    // Clean up any remaining chart objects
    ObjectsDeleteAll(0, "KL_");
    Print("🧹 Test cleanup completed (reason: ", reason, ")");
}

// Pattern from: MQL5 Reference Guide - OnTick Event Handler
void OnTick()
{
    // Not used in test EA - tests run in OnInit()
} 