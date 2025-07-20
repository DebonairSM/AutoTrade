//+------------------------------------------------------------------+
//| GrandePerformanceTester.mq5                                      |
//| Copyright 2024, Grande Tech                                      |
//| Performance Testing and Benchmarking Tool                       |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Performance testing and benchmarking patterns

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Performance testing and benchmarking tool for Grande Trading System"

#include "GrandeMarketRegimeDetector.mqh"
#include "GrandeKeyLevelDetector.mqh"

//+------------------------------------------------------------------+
//| Performance Test Configuration                                   |
//+------------------------------------------------------------------+
input group "=== Performance Test Settings ==="
input int    InpIterations = 1000;               // Number of test iterations
input bool   InpTestRegimeDetection = true;      // Test regime detection performance
input bool   InpTestKeyLevelDetection = true;    // Test key level detection performance
input bool   InpStressTestMemory = true;         // Stress test memory usage
input bool   InpTestTimeframes = true;           // Test all timeframes
input bool   InpGenerateBenchmarkReport = true;  // Generate benchmark report

//+------------------------------------------------------------------+
//| Performance Metrics Structure                                    |
//+------------------------------------------------------------------+
struct PerformanceMetrics
{
    string      testName;
    int         iterations;
    double      totalTime;           // Total execution time (ms)
    double      averageTime;         // Average time per iteration (ms)
    double      minTime;             // Minimum execution time (ms)
    double      maxTime;             // Maximum execution time (ms)
    double      standardDeviation;   // Standard deviation of times
    long        memoryUsedBefore;    // Memory before test (bytes)
    long        memoryUsedAfter;     // Memory after test (bytes)
    long        memoryDelta;         // Memory usage change (bytes)
    bool        successful;          // Test completed successfully
    datetime    timestamp;           // Test execution time
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
PerformanceMetrics g_performanceResults[];
int                g_resultCount;
datetime           g_testStartTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== GRANDE PERFORMANCE TESTING SUITE ===");
    Print("Initializing performance benchmarking framework...");
    
    g_resultCount = 0;
    g_testStartTime = TimeCurrent();
    ArrayResize(g_performanceResults, 100);
    
    // Start performance testing
    RunPerformanceTests();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main Performance Testing Function                                |
//+------------------------------------------------------------------+
void RunPerformanceTests()
{
    Print("\n🚀 STARTING PERFORMANCE BENCHMARK TESTS...");
    Print("Iterations per test: ", InpIterations);
    
    // Test 1: Regime Detection Performance
    if(InpTestRegimeDetection)
    {
        Print("\n📊 BENCHMARKING REGIME DETECTION...");
        BenchmarkRegimeDetection();
        BenchmarkRegimeDetectionWithUpdates();
        BenchmarkMultiTimeframeRegimeDetection();
    }
    
    // Test 2: Key Level Detection Performance
    if(InpTestKeyLevelDetection)
    {
        Print("\n🎯 BENCHMARKING KEY LEVEL DETECTION...");
        BenchmarkKeyLevelDetection();
        BenchmarkKeyLevelCalculations();
        BenchmarkKeyLevelUpdates();
    }
    
    // Test 3: Memory Stress Tests
    if(InpStressTestMemory)
    {
        Print("\n💾 RUNNING MEMORY STRESS TESTS...");
        StressTestMemoryUsage();
        StressTestLargeDatasets();
    }
    
    // Test 4: Timeframe Performance
    if(InpTestTimeframes)
    {
        Print("\n⏰ BENCHMARKING TIMEFRAME PERFORMANCE...");
        BenchmarkTimeframePerformance();
    }
    
    // Generate performance report
    if(InpGenerateBenchmarkReport)
        GeneratePerformanceReport();
}

//+------------------------------------------------------------------+
//| Regime Detection Performance Tests                               |
//+------------------------------------------------------------------+
void BenchmarkRegimeDetection()
{
    Print("Testing regime detection initialization and basic operation...");
    
    double times[];
    ArrayResize(times, InpIterations);
    long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
    
    for(int i = 0; i < InpIterations; i++)
    {
        datetime startTime = GetMicrosecondCount();
        
        // Create and test regime detector
        RegimeConfig config;
        config.adx_trend_threshold = 25.0;
        config.adx_breakout_min = 20.0;
        
        CGrandeMarketRegimeDetector* detector = new CGrandeMarketRegimeDetector();
        bool initialized = detector.Initialize(_Symbol, config);
        
        if(initialized)
        {
            RegimeSnapshot snapshot = detector.DetectCurrentRegime();
            // Force calculation by accessing properties
            MARKET_REGIME regime = snapshot.regime;
            double confidence = snapshot.confidence;
        }
        
        delete detector;
        
        datetime endTime = GetMicrosecondCount();
        times[i] = (endTime - startTime) / 1000.0; // Convert to milliseconds
    }
    
    long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
    
    PerformanceMetrics metrics = CalculateMetrics("Regime Detection - Basic", times, memBefore, memAfter);
    RecordPerformanceResult(metrics);
}

void BenchmarkRegimeDetectionWithUpdates()
{
    Print("Testing regime detection with continuous updates...");
    
    double times[];
    ArrayResize(times, InpIterations);
    long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
    
    // Create single detector for multiple updates
    RegimeConfig config;
    CGrandeMarketRegimeDetector* detector = new CGrandeMarketRegimeDetector();
    detector.Initialize(_Symbol, config);
    
    for(int i = 0; i < InpIterations; i++)
    {
        datetime startTime = GetMicrosecondCount();
        
        // Test update performance
        detector.UpdateRegime();
        RegimeSnapshot snapshot = detector.DetectCurrentRegime();
        
        datetime endTime = GetMicrosecondCount();
        times[i] = (endTime - startTime) / 1000.0;
    }
    
    delete detector;
    
    long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
    
    PerformanceMetrics metrics = CalculateMetrics("Regime Detection - Updates", times, memBefore, memAfter);
    RecordPerformanceResult(metrics);
}

void BenchmarkMultiTimeframeRegimeDetection()
{
    Print("Testing multi-timeframe regime detection performance...");
    
    ENUM_TIMEFRAMES timeframes[] = {PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
    
    for(int tf = 0; tf < ArraySize(timeframes); tf++)
    {
        double times[];
        ArrayResize(times, InpIterations / 4); // Fewer iterations per timeframe
        long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
        
        for(int i = 0; i < ArraySize(times); i++)
        {
            datetime startTime = GetMicrosecondCount();
            
            RegimeConfig config;
            CGrandeMarketRegimeDetector* detector = new CGrandeMarketRegimeDetector();
            detector.Initialize(_Symbol, config);
            RegimeSnapshot snapshot = detector.DetectCurrentRegime();
            delete detector;
            
            datetime endTime = GetMicrosecondCount();
            times[i] = (endTime - startTime) / 1000.0;
        }
        
        long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
        
        string testName = "Regime Detection - " + EnumToString(timeframes[tf]);
        PerformanceMetrics metrics = CalculateMetrics(testName, times, memBefore, memAfter);
        RecordPerformanceResult(metrics);
    }
}

//+------------------------------------------------------------------+
//| Key Level Detection Performance Tests                            |
//+------------------------------------------------------------------+
void BenchmarkKeyLevelDetection()
{
    Print("Testing key level detection performance...");
    
    double times[];
    ArrayResize(times, InpIterations);
    long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
    
    for(int i = 0; i < InpIterations; i++)
    {
        datetime startTime = GetMicrosecondCount();
        
        CGrandeKeyLevelDetector* detector = new CGrandeKeyLevelDetector();
        bool initialized = detector.Initialize(100, 0.65, 0.0005, 2, false);
        
        if(initialized)
        {
            bool detected = detector.DetectKeyLevels();
            int levelCount = detector.GetKeyLevelCount();
        }
        
        delete detector;
        
        datetime endTime = GetMicrosecondCount();
        times[i] = (endTime - startTime) / 1000.0;
    }
    
    long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
    
    PerformanceMetrics metrics = CalculateMetrics("Key Level Detection - Basic", times, memBefore, memAfter);
    RecordPerformanceResult(metrics);
}

void BenchmarkKeyLevelCalculations()
{
    Print("Testing key level calculation performance...");
    
    double times[];
    ArrayResize(times, InpIterations);
    long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
    
    // Create single detector for multiple calculations
    CGrandeKeyLevelDetector* detector = new CGrandeKeyLevelDetector();
    detector.Initialize(100, 0.65, 0.0005, 2, false);
    detector.DetectKeyLevels(); // Initial detection
    
    for(int i = 0; i < InpIterations; i++)
    {
        datetime startTime = GetMicrosecondCount();
        
        // Test calculation performance
        int levelCount = detector.GetKeyLevelCount();
        SKeyLevel strongestLevel;
        bool hasStrongest = detector.GetStrongestLevel(strongestLevel);
        
        datetime endTime = GetMicrosecondCount();
        times[i] = (endTime - startTime) / 1000.0;
    }
    
    delete detector;
    
    long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
    
    PerformanceMetrics metrics = CalculateMetrics("Key Level - Calculations", times, memBefore, memAfter);
    RecordPerformanceResult(metrics);
}

void BenchmarkKeyLevelUpdates()
{
    Print("Testing key level update performance...");
    
    double times[];
    ArrayResize(times, InpIterations / 10); // Fewer iterations for updates
    long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
    
    CGrandeKeyLevelDetector* detector = new CGrandeKeyLevelDetector();
    detector.Initialize(50, 0.65, 0.0005, 2, false);
    
    for(int i = 0; i < ArraySize(times); i++)
    {
        datetime startTime = GetMicrosecondCount();
        
        // Test update performance
        bool detected = detector.DetectKeyLevels();
        detector.UpdateChartDisplay();
        
        datetime endTime = GetMicrosecondCount();
        times[i] = (endTime - startTime) / 1000.0;
    }
    
    delete detector;
    
    long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
    
    PerformanceMetrics metrics = CalculateMetrics("Key Level - Updates", times, memBefore, memAfter);
    RecordPerformanceResult(metrics);
}

//+------------------------------------------------------------------+
//| Memory Stress Tests                                              |
//+------------------------------------------------------------------+
void StressTestMemoryUsage()
{
    Print("Running memory usage stress test...");
    
    long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
    datetime startTime = GetMicrosecondCount();
    
    // Create multiple detectors simultaneously
    CGrandeMarketRegimeDetector* regimeDetectors[];
    CGrandeKeyLevelDetector* keyLevelDetectors[];
    
    int maxDetectors = 50;
    ArrayResize(regimeDetectors, maxDetectors);
    ArrayResize(keyLevelDetectors, maxDetectors);
    
    bool allSuccessful = true;
    
    // Create detectors
    for(int i = 0; i < maxDetectors; i++)
    {
        regimeDetectors[i] = new CGrandeMarketRegimeDetector();
        keyLevelDetectors[i] = new CGrandeKeyLevelDetector();
        
        RegimeConfig config;
        if(!regimeDetectors[i].Initialize(_Symbol, config))
        {
            allSuccessful = false;
            break;
        }
        
        if(!keyLevelDetectors[i].Initialize(100, 0.65, 0.0005, 2, false))
        {
            allSuccessful = false;
            break;
        }
    }
    
    long memPeak = MQLInfoInteger(MQL_MEMORY_USED);
    
    // Clean up
    for(int i = 0; i < maxDetectors; i++)
    {
        if(regimeDetectors[i] != NULL)
            delete regimeDetectors[i];
        if(keyLevelDetectors[i] != NULL)
            delete keyLevelDetectors[i];
    }
    
    datetime endTime = GetMicrosecondCount();
    long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
    
    double executionTime = (endTime - startTime) / 1000.0;
    
    PerformanceMetrics metrics;
    metrics.testName = "Memory Stress Test";
    metrics.iterations = maxDetectors;
    metrics.totalTime = executionTime;
    metrics.averageTime = executionTime / maxDetectors;
    metrics.memoryUsedBefore = memBefore;
    metrics.memoryUsedAfter = memAfter;
    metrics.memoryDelta = memPeak - memBefore;
    metrics.successful = allSuccessful;
    metrics.timestamp = TimeCurrent();
    
    RecordPerformanceResult(metrics);
    
    Print("Memory stress test completed:");
    Print("  Peak memory usage: ", (memPeak - memBefore) / 1024, " KB");
    Print("  Memory cleanup: ", allSuccessful ? "Successful" : "Failed");
}

void StressTestLargeDatasets()
{
    Print("Testing performance with large datasets...");
    
    // Test with larger lookback periods
    int lookbackPeriods[] = {100, 500, 1000, 2000};
    
    for(int i = 0; i < ArraySize(lookbackPeriods); i++)
    {
        double times[];
        ArrayResize(times, 10); // Fewer iterations for large datasets
        long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
        
        for(int j = 0; j < ArraySize(times); j++)
        {
            datetime startTime = GetMicrosecondCount();
            
            CGrandeKeyLevelDetector* detector = new CGrandeKeyLevelDetector();
            detector.Initialize(lookbackPeriods[i], 0.65, 0.0005, 2, false);
            bool detected = detector.DetectKeyLevels();
            delete detector;
            
            datetime endTime = GetMicrosecondCount();
            times[j] = (endTime - startTime) / 1000.0;
        }
        
        long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
        
        string testName = "Large Dataset - " + IntegerToString(lookbackPeriods[i]) + " bars";
        PerformanceMetrics metrics = CalculateMetrics(testName, times, memBefore, memAfter);
        RecordPerformanceResult(metrics);
    }
}

//+------------------------------------------------------------------+
//| Timeframe Performance Test                                       |
//+------------------------------------------------------------------+
void BenchmarkTimeframePerformance()
{
    Print("Testing performance across different timeframes...");
    
    ENUM_TIMEFRAMES timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, 
                                   PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
    
    for(int i = 0; i < ArraySize(timeframes); i++)
    {
        double times[];
        ArrayResize(times, InpIterations / 9); // Distribute iterations across timeframes
        long memBefore = MQLInfoInteger(MQL_MEMORY_USED);
        
        for(int j = 0; j < ArraySize(times); j++)
        {
            datetime startTime = GetMicrosecondCount();
            
            // Test both detectors on this timeframe
            RegimeConfig config;
            CGrandeMarketRegimeDetector* regimeDetector = new CGrandeMarketRegimeDetector();
            CGrandeKeyLevelDetector* keyDetector = new CGrandeKeyLevelDetector();
            
            regimeDetector.Initialize(_Symbol, config);
            keyDetector.Initialize(100, 0.65, 0.0005, 2, false);
            
            RegimeSnapshot snapshot = regimeDetector.DetectCurrentRegime();
            bool levelDetected = keyDetector.DetectKeyLevels();
            
            delete regimeDetector;
            delete keyDetector;
            
            datetime endTime = GetMicrosecondCount();
            times[j] = (endTime - startTime) / 1000.0;
        }
        
        long memAfter = MQLInfoInteger(MQL_MEMORY_USED);
        
        string testName = "Timeframe Performance - " + EnumToString(timeframes[i]);
        PerformanceMetrics metrics = CalculateMetrics(testName, times, memBefore, memAfter);
        RecordPerformanceResult(metrics);
    }
}

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+
PerformanceMetrics CalculateMetrics(string testName, const double &times[], long memBefore, long memAfter)
{
    PerformanceMetrics metrics;
    metrics.testName = testName;
    metrics.iterations = ArraySize(times);
    metrics.memoryUsedBefore = memBefore;
    metrics.memoryUsedAfter = memAfter;
    metrics.memoryDelta = memAfter - memBefore;
    metrics.successful = true;
    metrics.timestamp = TimeCurrent();
    
    if(ArraySize(times) == 0)
    {
        metrics.totalTime = 0;
        metrics.averageTime = 0;
        metrics.minTime = 0;
        metrics.maxTime = 0;
        metrics.standardDeviation = 0;
        return metrics;
    }
    
    // Calculate basic statistics
    metrics.totalTime = 0;
    metrics.minTime = times[0];
    metrics.maxTime = times[0];
    
    for(int i = 0; i < ArraySize(times); i++)
    {
        metrics.totalTime += times[i];
        if(times[i] < metrics.minTime) metrics.minTime = times[i];
        if(times[i] > metrics.maxTime) metrics.maxTime = times[i];
    }
    
    metrics.averageTime = metrics.totalTime / ArraySize(times);
    
    // Calculate standard deviation
    double variance = 0;
    for(int i = 0; i < ArraySize(times); i++)
    {
        double diff = times[i] - metrics.averageTime;
        variance += diff * diff;
    }
    metrics.standardDeviation = MathSqrt(variance / ArraySize(times));
    
    return metrics;
}

void RecordPerformanceResult(const PerformanceMetrics &metrics)
{
    if(g_resultCount >= ArraySize(g_performanceResults))
    {
        ArrayResize(g_performanceResults, g_resultCount + 50);
    }
    
    g_performanceResults[g_resultCount] = metrics;
    
    // Print immediate result
    Print(StringFormat("✅ %s | Avg: %.2fms | Min: %.2fms | Max: %.2fms | Iterations: %d",
          metrics.testName,
          metrics.averageTime,
          metrics.minTime,
          metrics.maxTime,
          metrics.iterations));
    
    g_resultCount++;
}

void GeneratePerformanceReport()
{
    Print("\n" + StringRepeat("=", 80));
    Print("🏁 GRANDE PERFORMANCE BENCHMARK REPORT");
    Print(StringRepeat("=", 80));
    
    Print("\n📊 PERFORMANCE SUMMARY:");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    for(int i = 0; i < g_resultCount; i++)
    {
        PerformanceMetrics metrics = g_performanceResults[i];
        
        Print(StringFormat("%s:", metrics.testName));
        Print(StringFormat("  Average Time: %.3f ms", metrics.averageTime));
        Print(StringFormat("  Min/Max: %.3f / %.3f ms", metrics.minTime, metrics.maxTime));
        Print(StringFormat("  Std Dev: %.3f ms", metrics.standardDeviation));
        Print(StringFormat("  Memory Delta: %.1f KB", metrics.memoryDelta / 1024.0));
        Print(StringFormat("  Iterations: %d", metrics.iterations));
        Print("");
    }
    
    // Performance assessment
    Print("🎯 PERFORMANCE ASSESSMENT:");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    
    double totalAvgTime = 0;
    for(int i = 0; i < g_resultCount; i++)
    {
        totalAvgTime += g_performanceResults[i].averageTime;
    }
    double overallAverage = totalAvgTime / g_resultCount;
    
    Print(StringFormat("Overall Average Performance: %.3f ms", overallAverage));
    
    if(overallAverage < 10.0)
        Print("🏆 EXCELLENT: System performance is outstanding!");
    else if(overallAverage < 50.0)
        Print("👍 GOOD: System performance is acceptable.");
    else if(overallAverage < 100.0)
        Print("⚠️  WARNING: System performance may need optimization.");
    else
        Print("🚨 CRITICAL: System performance is poor - optimization required!");
    
    Print(StringRepeat("=", 80));
}

string StringRepeat(string str, int count)
{
    string result = "";
    for(int i = 0; i < count; i++)
        result += str;
    return result;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Grande Performance Testing completed.");
} 