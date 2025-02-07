//+------------------------------------------------------------------+
//|                                         V-2-EA-Breakouts-Test.mq5 |
//|                                           Unit Tests for Breakouts |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

// Include the file to test
#include "V-2-EA-Breakouts.mqh"

// Test framework globals
struct STestCase
{
    string name;
    bool passed;
    int assertions;
    int passedAssertions;
};

STestCase g_currentTest;
STestCase g_tests[];
int g_testCount = 0;

//+------------------------------------------------------------------+
//| Test Framework Functions                                           |
//+------------------------------------------------------------------+
void BeginTest(string testName)
{
    // Reset current test
    g_currentTest.name = testName;
    g_currentTest.passed = true;  // Start as passed, will be set to false on any failure
    g_currentTest.assertions = 0;
    g_currentTest.passedAssertions = 0;
    
    Print("Running test: ", testName);
}

void EndTest()
{
    // Add test to array
    ArrayResize(g_tests, g_testCount + 1);
    g_tests[g_testCount] = g_currentTest;
    g_testCount++;
    
    // Print test summary
    string result = g_currentTest.passed ? "✓" : "✗";
    Print(StringFormat("%s Test complete: %s - %d/%d assertions passed", 
          result, g_currentTest.name, 
          g_currentTest.passedAssertions, g_currentTest.assertions));
}

void AssertTrue(bool condition, string message)
{
    g_currentTest.assertions++;
    
    if(condition)
    {
        Print("✓ ", g_currentTest.name, " - ", message);
        g_currentTest.passedAssertions++;
    }
    else
    {
        Print("✗ ", g_currentTest.name, " - ", message);
        g_currentTest.passed = false;
    }
}

void AssertEquals(double expected, double actual, double epsilon, string message)
{
    g_currentTest.assertions++;
    
    if(MathAbs(expected - actual) <= epsilon)
    {
        Print("✓ ", g_currentTest.name, " - ", message);
        g_currentTest.passedAssertions++;
    }
    else
    {
        Print("✗ ", g_currentTest.name, " - ", message, 
              " (Expected: ", expected, ", Actual: ", actual, ")");
        g_currentTest.passed = false;
    }
}

//+------------------------------------------------------------------+
//| Individual Test Cases                                              |
//+------------------------------------------------------------------+
void TestConstructor()
{
    BeginTest("Constructor Test");
    
    CV2EABreakouts breakouts;
    // Test that object is created successfully
    AssertTrue(GetLastError() == 0, "Constructor should not generate errors");
    
    EndTest();
}

void TestConstructorDefaults()
{
    BeginTest("Constructor Defaults Test");
    
    CV2EABreakouts breakouts;
    breakouts.Init(100, 0.55, 0.0025, 2, true);  // Initialize with test values
    
    // Test default values through base class methods
    AssertEquals(0.55, breakouts.TEST_GetMinStrength(), 0.0001, "Default min strength should be 0.55");
    AssertEquals(2, breakouts.TEST_GetMinTouches(), 0, "Default min touches should be 2");
    AssertTrue(breakouts.TEST_GetKeyLevelCount() == 0, "Initial key level count should be 0");
    
    EndTest();
}

void TestKeyLevelManagement()
{
    BeginTest("Key Level Management Test");
    
    CV2EABreakouts breakouts;
    
    // Create test data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, PERIOD_H1, 0, 100, rates);
    
    AssertTrue(copied > 0, "Should be able to copy price data");
    
    // Get initial key level count
    int initialCount = breakouts.TEST_GetKeyLevelCount();
    AssertTrue(initialCount == 0, "Initial key level count should be 0");
    
    // After processing some data, we should have some key levels
    // Note: You'll need to implement a method to process the rates data
    
    SKeyLevel level;
    bool hasLevel = breakouts.TEST_GetKeyLevel(0, level);
    if(hasLevel)
    {
        AssertTrue(level.touchCount >= breakouts.TEST_GetMinTouches(), 
                  "Key level should meet minimum touch count");
        AssertTrue(level.strength >= breakouts.TEST_GetMinStrength(), 
                  "Key level should meet minimum strength");
    }
}

void TestSymbolDetection()
{
    BeginTest("Symbol Detection Test");
    
    CV2EABreakouts breakouts;
    
    if(_Symbol == "US500" || _Symbol == "SPX500")
    {
        AssertTrue(breakouts.TEST_IsUS500(), "Should detect US500 symbol");
    }
    else
    {
        AssertTrue(!breakouts.TEST_IsUS500(), "Should not detect non-US500 symbol");
    }
}

void TestKeyLevelDetection()
{
    BeginTest("Key Level Detection Test");
    
    CV2EABreakouts breakouts;
    
    // Create sample price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, PERIOD_H1, 0, 100, rates);
    
    AssertTrue(copied > 0, "Should be able to copy price data");
    
    // Test key level detection (this will depend on your implementation)
    // You'll need to expose some methods or results to test this properly
}

void TestTouchZoneCalculation()
{
    BeginTest("Touch Zone Test");
    
    CV2EABreakouts breakouts;
    
    // Test touch zone calculations if you have methods exposed for this
    // This might require making some methods public or adding test-specific methods
}

void TestVolumeAnalysis()
{
    BeginTest("Volume Analysis Test");
    
    CV2EABreakouts breakouts;
    breakouts.Init(100, 0.55, 0.0025, 2, true);
    
    // Create test volume data
    long volumes[];
    ArrayResize(volumes, 20);
    
    // Set up a clear volume spike
    for(int i = 0; i < 20; i++)
    {
        volumes[i] = 100;  // Base volume
    }
    volumes[10] = 300;  // Volume spike (3x normal)
    
    // Test volume spike detection
    SKeyLevel level;
    if(breakouts.TEST_GetKeyLevel(0, level))
    {
        AssertTrue(level.volumeConfirmed, "Volume spike should be confirmed");
        AssertTrue(level.volumeRatio >= 1.5, "Volume ratio should be at least 1.5x average");
    }
}

void TestKeyLevelStrength()
{
    BeginTest("Key Level Strength Test");
    
    CV2EABreakouts breakouts;
    breakouts.Init(100, 0.55, 0.0025, 2, true);
    
    // Process some test data
    MqlRates rates[];
    GenerateForexTestData(rates, 200, 1.2000, 0.0002);
    
    // Check strength calculation components
    SKeyLevel level;
    if(breakouts.TEST_GetKeyLevel(0, level))
    {
        AssertTrue(level.strength >= 0.45 && level.strength <= 0.98, 
                  "Strength should be within valid range (0.45-0.98)");
        
        if(level.volumeConfirmed)
        {
            AssertTrue(level.strength > level.volumeRatio * 0.5, 
                      "Volume-confirmed level should have higher strength");
        }
    }
}

//+------------------------------------------------------------------+
//| Forex Data Simulation Functions                                    |
//+------------------------------------------------------------------+
void GenerateForexTestData(MqlRates &rates[], int bars, 
                          double startPrice = 1.2000, 
                          double volatility = 0.0002)
{
    ArrayResize(rates, bars);
    ArraySetAsSeries(rates, true);
    
    double currentPrice = startPrice;
    datetime currentTime = TimeCurrent() - bars * PeriodSeconds(PERIOD_H1);
    
    for(int i = bars - 1; i >= 0; i--)
    {
        // Generate random price movement
        double movement = (MathRand() - 16383.5) / 32767.0 * volatility;
        
        // Create support/resistance levels every ~20 bars
        if(i % 20 == 0)
        {
            // Make price more likely to reverse here
            if(MathRand() % 2 == 0)
            {
                movement = MathAbs(movement) * -1;  // Force downward movement
            }
            else
            {
                movement = MathAbs(movement);       // Force upward movement
            }
            
            // Increase volume at these points
            rates[i].tick_volume = 1000 + MathRand() % 500;
        }
        else
        {
            rates[i].tick_volume = 100 + MathRand() % 200;
        }
        
        currentPrice += movement;
        
        // Fill rate data
        rates[i].time = currentTime;
        rates[i].open = currentPrice;
        rates[i].high = currentPrice + MathAbs(movement) * 0.5;
        rates[i].low = currentPrice - MathAbs(movement) * 0.5;
        rates[i].close = currentPrice;
        rates[i].real_volume = rates[i].tick_volume;
        
        currentTime += PeriodSeconds(PERIOD_H1);
    }
}

//+------------------------------------------------------------------+
//| Forex Simulation Test Cases                                        |
//+------------------------------------------------------------------+
void TestForexBreakoutDetection()
{
    BeginTest("Forex Breakout Detection Test");
    
    // Initialize breakouts detector with specific settings for testing
    CV2EABreakouts breakouts;
    bool initialized = breakouts.Init(
        100,    // lookbackPeriod
        0.55,   // minStrength
        0.0025, // touchZone (25 pips for forex)
        2,      // minTouches
        true    // showDebugPrints
    );
    
    AssertTrue(initialized, "Breakouts detector should initialize successfully");
    
    // Generate simulated forex data
    MqlRates rates[];
    GenerateForexTestData(rates, 200);  // Generate 200 bars of test data
    
    // Override the current rates data with our simulated data
    // Note: In a real test environment, this would require mocking the price feed
    
    // Process the data
    breakouts.ProcessStrategy();
    
    // Verify key levels were detected
    int keyLevelCount = breakouts.TEST_GetKeyLevelCount();
    Print("Detected ", keyLevelCount, " key levels");
    AssertTrue(keyLevelCount > 0, "Should detect at least one key level");
    
    // Check properties of detected levels
    SKeyLevel level;
    if(breakouts.TEST_GetKeyLevel(0, level))
    {
        AssertTrue(level.touchCount >= breakouts.TEST_GetMinTouches(), 
                  "Key level should have minimum required touches");
        AssertTrue(level.strength >= breakouts.TEST_GetMinStrength(), 
                  "Key level should meet minimum strength requirement");
        
        Print(StringFormat(
            "First Key Level Details:\n" +
            "Price: %.5f\n" +
            "Strength: %.4f\n" +
            "Touch Count: %d\n" +
            "Is Resistance: %s",
            level.price,
            level.strength,
            level.touchCount,
            level.isResistance ? "Yes" : "No"
        ));
    }
}

void TestForexVolatilityScenarios()
{
    BeginTest("Forex Volatility Scenarios Test");
    
    CV2EABreakouts breakouts;
    breakouts.Init(100, 0.55, 0.0025, 2, true);
    
    // Test different volatility scenarios
    double volatilities[] = {0.0001, 0.0005, 0.001};  // Low, Medium, High volatility
    
    for(int i = 0; i < ArraySize(volatilities); i++)
    {
        Print(StringFormat("\nTesting volatility scenario: %.4f", volatilities[i]));
        
        MqlRates rates[];
        GenerateForexTestData(rates, 200, 1.2000, volatilities[i]);
        
        // Process data and check results
        breakouts.ProcessStrategy();
        
        int keyLevelCount = breakouts.TEST_GetKeyLevelCount();
        Print(StringFormat("Detected %d key levels with volatility %.4f", 
              keyLevelCount, volatilities[i]));
        
        // Check the strongest level in each scenario
        SKeyLevel level;
        if(breakouts.TEST_GetKeyLevel(0, level))
        {
            Print(StringFormat(
                "Strongest Level:\n" +
                "Price: %.5f\n" +
                "Strength: %.4f\n" +
                "Touch Count: %d",
                level.price,
                level.strength,
                level.touchCount
            ));
        }
    }
}

//+------------------------------------------------------------------+
//| US500 Data Simulation Functions                                    |
//+------------------------------------------------------------------+
void GenerateUS500TestData(MqlRates &rates[], int bars, 
                          double startPrice = 4500.0, 
                          double volatility = 15.0)  // Default 15 points volatility
{
    ArrayResize(rates, bars);
    ArraySetAsSeries(rates, true);
    
    double currentPrice = startPrice;
    datetime currentTime = TimeCurrent() - bars * PeriodSeconds(PERIOD_H1);
    
    // US500 specific patterns
    double dailyTrend = 0.5;  // Slight upward bias (typical for US500)
    
    // Initialize volume profile array properly
    double volumeProfile[];
    ArrayResize(volumeProfile, 7);
    volumeProfile[0] = 1.2;  // 9:30
    volumeProfile[1] = 1.5;  // 10:30
    volumeProfile[2] = 1.8;  // 11:30
    volumeProfile[3] = 1.3;  // 12:30
    volumeProfile[4] = 1.0;  // 13:30
    volumeProfile[5] = 0.8;  // 14:30
    volumeProfile[6] = 0.7;  // 15:30
    
    for(int i = bars - 1; i >= 0; i--)
    {
        // Time-based volatility adjustment (higher at open, lower at close)
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        int hourIndex = (dt.hour >= 16) ? 6 : (dt.hour - 9) % 7;  // Market hours 9:30-16:00
        double timeVolatilityMult = hourIndex >= 0 ? volumeProfile[hourIndex] : 0.5;
        
        // Generate price movement with US500 characteristics
        double baseMovement = (MathRand() - 16383.5) / 32767.0 * volatility;
        double trend = dailyTrend + MathSin(i * 2 * M_PI / 20) * 0.2;  // Add cyclic behavior
        double movement = baseMovement * timeVolatilityMult + trend;
        
        // Create major support/resistance levels
        if(i % 25 == 0)  // Psychological levels every ~25 bars
        {
            // Round to nearest 50 points for psychological levels
            currentPrice = MathRound(currentPrice / 50.0) * 50.0;
            
            // Increase volume at these levels
            rates[i].tick_volume = 5000 + MathRand() % 2000;  // Higher volume for US500
            
            // Add resistance/support behavior
            if(MathRand() % 2 == 0)
            {
                movement = -MathAbs(movement) * 1.5;  // Strong reversal down
            }
            else
            {
                movement = MathAbs(movement) * 1.5;   // Strong reversal up
            }
        }
        else
        {
            // Normal volume profile
            rates[i].tick_volume = 1000 + MathRand() % 1000;
        }
        
        currentPrice += movement;
        
        // Ensure realistic price range
        currentPrice = MathMax(currentPrice, startPrice * 0.9);  // Prevent unrealistic drops
        currentPrice = MathMin(currentPrice, startPrice * 1.1);  // Prevent unrealistic spikes
        
        // Fill rate data with typical US500 characteristics
        rates[i].time = currentTime;
        rates[i].open = currentPrice;
        rates[i].high = currentPrice + MathAbs(movement) * 0.7;  // Smaller wicks for US500
        rates[i].low = currentPrice - MathAbs(movement) * 0.7;
        rates[i].close = currentPrice;
        rates[i].real_volume = rates[i].tick_volume;
        
        currentTime += PeriodSeconds(PERIOD_H1);
    }
}

//+------------------------------------------------------------------+
//| US500 Simulation Test Cases                                        |
//+------------------------------------------------------------------+
void TestUS500BreakoutDetection()
{
    BeginTest("US500 Breakout Detection Test");
    
    // Initialize with US500-specific settings
    CV2EABreakouts breakouts;
    bool initialized = breakouts.Init(
        100,    // lookbackPeriod
        0.55,   // minStrength
        10.0,   // touchZone (10 points for US500 H1)
        2,      // minTouches
        true    // showDebugPrints
    );
    
    AssertTrue(initialized, "Breakouts detector should initialize successfully");
    
    // Generate simulated US500 data with appropriate scale
    MqlRates rates[];
    GenerateUS500TestData(rates, 200, 4500.0, 15.0);  // 15 point volatility
    
    // Process the data
    breakouts.ProcessStrategy();
    
    // Verify key levels were detected
    int keyLevelCount = breakouts.TEST_GetKeyLevelCount();
    Print("Detected ", keyLevelCount, " key levels");
    AssertTrue(keyLevelCount > 0, "Should detect at least one key level");
    
    // Check properties of detected levels
    SKeyLevel level;
    if(breakouts.TEST_GetKeyLevel(0, level))
    {
        AssertTrue(level.touchCount >= breakouts.TEST_GetMinTouches(), 
                  "Key level should have minimum required touches");
        AssertTrue(level.strength >= breakouts.TEST_GetMinStrength(), 
                  "Key level should meet minimum strength requirement");
        
        // Verify if the level is near a psychological number (multiple of 50)
        double levelMod50 = MathMod(level.price, 50.0);
        bool isPsychological = levelMod50 < 5.0 || levelMod50 > 45.0;
        
        Print(StringFormat(
            "First Key Level Details:\n" +
            "Price: %.2f\n" +
            "Strength: %.4f\n" +
            "Touch Count: %d\n" +
            "Is Resistance: %s\n" +
            "Near Psychological Level: %s",
            level.price,
            level.strength,
            level.touchCount,
            level.isResistance ? "Yes" : "No",
            isPsychological ? "Yes" : "No"
        ));
    }
}

void TestUS500MarketConditions()
{
    BeginTest("US500 Market Conditions Test");
    
    CV2EABreakouts breakouts;
    breakouts.Init(100, 0.55, 10.0, 2, true);  // 10 points for US500 H1
    
    // Test different market conditions
    struct MarketCondition {
        string name;
        double volatility;
        double startPrice;
    };
    
    MarketCondition conditions[] = {
        {"Low Volatility", 5.0, 4500.0},      // Quiet market
        {"Normal Trading", 15.0, 4500.0},     // Normal market
        {"High Volatility", 30.0, 4500.0},    // Volatile market
        {"Gap Up", 15.0, 4600.0},            // Gap up scenario
        {"Gap Down", 15.0, 4400.0}           // Gap down scenario
    };
    
    for(int i = 0; i < ArraySize(conditions); i++)
    {
        Print(StringFormat("\nTesting %s condition", conditions[i].name));
        
        MqlRates rates[];
        GenerateUS500TestData(rates, 200, conditions[i].startPrice, conditions[i].volatility);
        
        // Process data and check results
        breakouts.ProcessStrategy();
        
        int keyLevelCount = breakouts.TEST_GetKeyLevelCount();
        Print(StringFormat("Detected %d key levels in %s condition", 
              keyLevelCount, conditions[i].name));
        
        // Check the strongest level
        SKeyLevel level;
        if(breakouts.TEST_GetKeyLevel(0, level))
        {
            // Check if level is near a psychological price point
            double nearestHundred = MathRound(level.price / 100.0) * 100.0;
            double distanceToHundred = MathAbs(level.price - nearestHundred);
            
            Print(StringFormat(
                "Strongest Level:\n" +
                "Price: %.2f\n" +
                "Strength: %.4f\n" +
                "Touch Count: %d\n" +
                "Distance to Psychological Level: %.2f points",
                level.price,
                level.strength,
                level.touchCount,
                distanceToHundred
            ));
        }
    }
}

//+------------------------------------------------------------------+
//| Utility Function Tests                                             |
//+------------------------------------------------------------------+
void TestUtilityFunctions()
{
    BeginTest("Utility Functions Test");
    
    // Test SafeResizeArray
    double testArray[];
    bool resizeResult = CV2EAUtils::SafeResizeArray(testArray, 10, "TestUtilityFunctions");
    AssertTrue(resizeResult, "SafeResizeArray should succeed with valid size");
    AssertTrue(ArraySize(testArray) == 10, "Array should be resized to 10 elements");
    
    // Test array resize with invalid size
    resizeResult = CV2EAUtils::SafeResizeArray(testArray, -1, "TestUtilityFunctions");
    AssertTrue(!resizeResult, "SafeResizeArray should fail with invalid size");
    
    // Test QuickSort
    SKeyLevel levels[];
    double strengths[];
    CV2EAUtils::SafeResizeArray(levels, 5, "TestQuickSort");
    CV2EAUtils::SafeResizeArray(strengths, 5, "TestQuickSort");
    
    // Initialize test data
    strengths[0] = 0.75;  // Middle strength
    strengths[1] = 0.90;  // Highest strength
    strengths[2] = 0.60;  // Lower strength
    strengths[3] = 0.85;  // Second highest
    strengths[4] = 0.65;  // Second lowest
    
    for(int i = 0; i < 5; i++)
    {
        levels[i].price = (i + 1) * 100.0;
        levels[i].strength = strengths[i];
    }
    
    // Sort arrays
    CV2EAUtils::QuickSort(levels, 0, 4, strengths);
    
    // Verify sorting
    AssertTrue(strengths[0] > strengths[1], "First element should have highest strength");
    AssertTrue(strengths[3] > strengths[4], "Last element should have lowest strength");
    AssertTrue(levels[0].strength == 0.90, "Level sorting should match strength sorting");
    
    // Test debug print control
    CV2EAUtils::Init(true);  // Enable debug prints
    
    // Test LogInfo with different parameter counts
    CV2EAUtils::LogInfo("Simple message");
    CV2EAUtils::LogInfo("Message with one param: %s", "TEST1");
    CV2EAUtils::LogInfo("Message with two params: %s, %s", "TEST1", "TEST2");
    CV2EAUtils::LogInfo("Message with three params: %s, %s, %s", "TEST1", "TEST2", "TEST3");
    
    CV2EAUtils::Init(false); // Disable debug prints
    CV2EAUtils::LogInfo("Test message - should not be printed");
    
    // Test error logging (these should always print regardless of debug setting)
    CV2EAUtils::LogError("Test error message");
    CV2EAUtils::LogWarning("Test warning message");
    
    EndTest();
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Run all tests
    TestConstructor();
    TestConstructorDefaults();
    TestKeyLevelManagement();
    TestSymbolDetection();
    TestKeyLevelDetection();
    TestTouchZoneCalculation();
    TestVolumeAnalysis();
    TestKeyLevelStrength();
    TestUtilityFunctions();  // Add the new test
    
    // Run forex-specific tests
    TestForexBreakoutDetection();
    TestForexVolatilityScenarios();
    
    // Run US500-specific tests
    TestUS500BreakoutDetection();
    TestUS500MarketConditions();
    
    // Calculate final test results
    int passedTests = 0;
    int totalAssertions = 0;
    int passedAssertions = 0;
    
    for(int i = 0; i < g_testCount; i++)
    {
        if(g_tests[i].passed)
            passedTests++;
            
        totalAssertions += g_tests[i].assertions;
        passedAssertions += g_tests[i].passedAssertions;
    }
    
    // Print test results
    Print("\n=== TEST SUMMARY ===");
    Print(StringFormat("Tests: %d/%d passed", passedTests, g_testCount));
    Print(StringFormat("Assertions: %d/%d passed", passedAssertions, totalAssertions));
    Print("==================\n");
    
    // Since this is a test EA, we don't want it running on charts
    return(INIT_FAILED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up any test artifacts here
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Not used in test EA
} 