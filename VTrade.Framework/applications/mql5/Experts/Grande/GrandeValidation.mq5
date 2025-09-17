//+------------------------------------------------------------------+
//| GrandeValidation.mq5                                             |
//| Copyright 2025, Grande Tech                                      |
//| Simple validation script for Grande Trading System              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Grande Tech"
#property version   "1.00"
#property description "Simple validation for Grande Trading System core components"

#include "GrandeMarketRegimeDetector.mqh"
#include "GrandeKeyLevelDetector.mqh"

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input bool InpRunValidation = true;    // Run validation on startup

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
CMarketRegimeDetector g_regimeDetector;
CKeyLevelDetector g_keyLevelDetector;
int g_testsPassed = 0;
int g_totalTests = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    if (InpRunValidation)
    {
        Print("=== GRANDE VALIDATION SUITE ===");
        RunValidation();
        
        double successRate = (g_totalTests > 0) ? (double)g_testsPassed / g_totalTests * 100.0 : 0.0;
        Print(StringFormat("Validation complete: %d/%d tests passed (%.1f%%)", 
              g_testsPassed, g_totalTests, successRate));
        
        if (g_testsPassed == g_totalTests)
            Print("✅ All validations passed - system ready");
        else
            Print("⚠️ Some validations failed - check logs");
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main validation function                                         |
//+------------------------------------------------------------------+
void RunValidation()
{
    ValidateRegimeDetector();
    ValidateKeyLevelDetector();
    ValidateSystemIntegration();
}

//+------------------------------------------------------------------+
//| Validate regime detector                                         |
//+------------------------------------------------------------------+
void ValidateRegimeDetector()
{
    Print("Testing Regime Detector...");
    
    // Test initialization
    bool initOk = g_regimeDetector.Initialize(Symbol(), Period());
    RecordTest("Regime Detector Initialization", initOk);
    
    if (initOk)
    {
        // Test regime detection
        MarketRegime regime = g_regimeDetector.GetCurrentRegime();
        bool regimeValid = (regime >= BULL_TREND && regime <= CONSOLIDATION);
        RecordTest("Regime Detection", regimeValid);
        
        // Test confidence calculation
        double confidence = g_regimeDetector.GetConfidence();
        bool confidenceValid = (confidence >= 0.0 && confidence <= 1.0);
        RecordTest("Confidence Calculation", confidenceValid);
        
        Print(StringFormat("Current regime: %s (confidence: %.2f)", 
              EnumToString(regime), confidence));
    }
}

//+------------------------------------------------------------------+
//| Validate key level detector                                      |
//+------------------------------------------------------------------+
void ValidateKeyLevelDetector()
{
    Print("Testing Key Level Detector...");
    
    // Test initialization
    bool initOk = g_keyLevelDetector.Initialize(Symbol(), Period());
    RecordTest("Key Level Detector Initialization", initOk);
    
    if (initOk)
    {
        // Test level detection
        g_keyLevelDetector.UpdateLevels();
        
        double nearestResistance = g_keyLevelDetector.GetNearestResistance();
        double nearestSupport = g_keyLevelDetector.GetNearestSupport();
        
        bool levelsValid = (nearestResistance > 0 && nearestSupport > 0);
        RecordTest("Level Detection", levelsValid);
        
        if (levelsValid)
        {
            Print(StringFormat("Nearest levels - R: %.5f, S: %.5f", 
                  nearestResistance, nearestSupport));
        }
    }
}

//+------------------------------------------------------------------+
//| Validate system integration                                      |
//+------------------------------------------------------------------+
void ValidateSystemIntegration()
{
    Print("Testing System Integration...");
    
    // Test symbol and timeframe
    bool symbolValid = (StringLen(Symbol()) > 0);
    RecordTest("Symbol Validation", symbolValid);
    
    bool timeframeValid = (Period() > 0);
    RecordTest("Timeframe Validation", timeframeValid);
    
    // Test basic market data access
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    bool pricesValid = (bid > 0 && ask > 0 && ask >= bid);
    RecordTest("Market Data Access", pricesValid);
    
    Print(StringFormat("Symbol: %s, Timeframe: %s, Bid: %.5f, Ask: %.5f", 
          Symbol(), EnumToString(Period()), bid, ask));
}

//+------------------------------------------------------------------+
//| Record test result                                               |
//+------------------------------------------------------------------+
void RecordTest(string testName, bool passed)
{
    g_totalTests++;
    if (passed)
    {
        g_testsPassed++;
        Print(StringFormat("✅ %s: PASSED", testName));
    }
    else
    {
        Print(StringFormat("❌ %s: FAILED", testName));
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Grande Validation Suite deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function (minimal)                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    // Validation runs once on init, no tick processing needed
}
