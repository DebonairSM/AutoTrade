//+------------------------------------------------------------------+
//|                                        VSol.Test.Breakout.mq5     |
//|                        Breakout Strategy Unit Test Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"
#property strict

// Include the files we need to test
#include "VSol.Strategy.mqh"
#include "VSol.Market.mqh"
#include "VSol.Utils.mqh"
#include "VSol.Market.Forex.mqh"
#include "VSol.Breakout.mqh"

// Test configuration
#define TEST_SYMBOL "EURUSD"
#define TEST_TIMEFRAME PERIOD_H1

// Test parameters (matching VSol.Main.mq5)
input int     LookbackPeriod = 100;    // Historical bars to analyze
input double  MinStrength = 0.55;      // Level strength threshold
input int     MinTouches = 2;          // Minimum level touches required
input int     RangeBars = 20;          // Number of bars for range
input double  LotSize = 0.1;           // Trade lot size
input int     Slippage = 3;            // Maximum slippage
input double  StopLossPips = 20;       // Stop Loss in pips
input double  TakeProfitPips = 40;     // Take Profit in pips
input bool    RequireRetest = true;    // Wait for retest before entry

// Global test objects
CVSolStrategy g_strategy;
CVSolBreakout g_breakout;
CVSolMarketConfig g_marketConfig;

//+------------------------------------------------------------------+
//| Custom test data structure                                         |
//+------------------------------------------------------------------+
struct STestCandle
{
    datetime time;
    double open;
    double high;
    double low;
    double close;
    long volume;
};

//+------------------------------------------------------------------+
//| Test data to simulate a complete trade cycle                        |
//+------------------------------------------------------------------+
STestCandle testData[] = {
    // Format: {time, open, high, low, close, volume}
    // Creating a resistance level around 1.1000
    {D'2024.03.19 10:00', 1.0980, 1.1000, 1.0970, 1.0990, 1000},  // Touch 1
    {D'2024.03.19 11:00', 1.0985, 1.1000, 1.0975, 1.0980, 1200},  // Touch 2
    {D'2024.03.19 12:00', 1.0990, 1.1000, 1.0980, 1.0985, 1100},  // Touch 3
    // Price consolidation below resistance
    {D'2024.03.19 13:00', 1.0980, 1.0990, 1.0970, 1.0975, 900},
    {D'2024.03.19 14:00', 1.0975, 1.0985, 1.0965, 1.0980, 950},
    // Breakout setup
    {D'2024.03.19 15:00', 1.0980, 1.1010, 1.0975, 1.1005, 1800},  // Breakout candle
    {D'2024.03.19 16:00', 1.1005, 1.1015, 1.0995, 1.1010, 1600},  // Confirmation
    // Post-breakout movement for trailing stop test
    {D'2024.03.19 17:00', 1.1010, 1.1030, 1.1005, 1.1025, 1400},  // Move towards TP
    {D'2024.03.19 18:00', 1.1025, 1.1045, 1.1020, 1.1040, 1300},  // Should activate trailing
    {D'2024.03.19 19:00', 1.1040, 1.1050, 1.1035, 1.1045, 1200}   // Final position
};

//+------------------------------------------------------------------+
//| Structure to track trade status                                    |
//+------------------------------------------------------------------+
struct STradeStatus
{
    bool isOpen;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double currentPrice;
    bool isTrailing;
    double trailingStop;
    
    void Reset()
    {
        isOpen = false;
        entryPrice = 0;
        stopLoss = 0;
        takeProfit = 0;
        currentPrice = 0;
        isTrailing = false;
        trailingStop = 0;
    }
};

//+------------------------------------------------------------------+
//| Load test data into the market interface                           |
//+------------------------------------------------------------------+
void LoadTestData()
{
    Print("Loading test data...");
    
    // Enable test mode
    CVSolMarketTestData::EnableTestMode(true);
    
    // Load test candles
    for(int i = 0; i < ArraySize(testData); i++)
    {
        STestCandle &candle = testData[i];
        CVSolMarketTestData::AddTestCandle(
            candle.time,
            candle.open,
            candle.high,
            candle.low,
            candle.close,
            candle.volume
        );
    }
    
    Print("✓ Test data loaded: ", ArraySize(testData), " candles");
}

//+------------------------------------------------------------------+
//| Test initialization function                                       |
//+------------------------------------------------------------------+
bool InitTest()
{
    Print("Initializing breakout buy signal test...");
    
    // Load test data first
    LoadTestData();
    
    // Initialize market config
    g_marketConfig.Configure(
        TEST_SYMBOL,
        MARKET_TYPE_FOREX,
        2.5,  // Touch zone
        1.0,  // Min bounce
        MinStrength,
        MinTouches,
        LookbackPeriod
    );
    
    // Initialize strategy
    if(!g_strategy.Init(LookbackPeriod, MinStrength, 2.5, MinTouches, true))
    {
        Print("❌ Failed to initialize strategy");
        return false;
    }
    
    // Initialize breakout strategy
    if(!g_breakout.Init(RangeBars, LotSize, Slippage, StopLossPips, TakeProfitPips, RequireRetest))
    {
        Print("❌ Failed to initialize breakout strategy");
        return false;
    }
    
    Print("✓ Test initialization successful");
    return true;
}

//+------------------------------------------------------------------+
//| Run the breakout trade execution test                              |
//+------------------------------------------------------------------+
void RunBreakoutTradeTest()
{
    Print("\n=== Running Breakout Trade Execution Test ===");
    
    STradeStatus trade;
    trade.Reset();
    
    // Process each test candle
    for(int i = 0; i < ArraySize(testData); i++)
    {
        STestCandle &candle = testData[i];
        Print("\nProcessing candle ", i + 1, "/", ArraySize(testData));
        Print("Time: ", TimeToString(candle.time));
        Print("OHLC: ", 
            DoubleToString(candle.open, 5), ", ",
            DoubleToString(candle.high, 5), ", ",
            DoubleToString(candle.low, 5), ", ",
            DoubleToString(candle.close, 5)
        );
        Print("Volume: ", candle.volume);
        
        // Update levels
        g_breakout.UpdateLevels();
        
        if(!trade.isOpen)
        {
            // Check for entry
            bool isLong = false;
            if(g_breakout.CheckBreakout(isLong))
            {
                Print("\n!!! Breakout signal detected !!!");
                Print("Direction: ", isLong ? "BUY" : "SELL");
                
                // Validate signal
                if(isLong && candle.close > 1.1000)
                {
                    // Execute trade
                    if(g_breakout.ExecuteBreakoutTrade(isLong))
                    {
                        trade.isOpen = true;
                        trade.entryPrice = candle.close;
                        trade.stopLoss = trade.entryPrice - StopLossPips * _Point;
                        trade.takeProfit = trade.entryPrice + TakeProfitPips * _Point;
                        
                        Print("\n✓ Trade executed successfully");
                        Print("  Entry price: ", DoubleToString(trade.entryPrice, 5));
                        Print("  Stop Loss:   ", DoubleToString(trade.stopLoss, 5));
                        Print("  Take Profit: ", DoubleToString(trade.takeProfit, 5));
                    }
                }
            }
        }
        else
        {
            // Update position status
            trade.currentPrice = candle.close;
            
            // Check for trailing stop activation
            double profitTarget = trade.takeProfit - trade.entryPrice;
            double currentProfit = trade.currentPrice - trade.entryPrice;
            
            if(!trade.isTrailing && currentProfit >= profitTarget * TRAILING_ACTIVATION_PCT)
            {
                trade.isTrailing = true;
                trade.trailingStop = trade.stopLoss;
                Print("\n➜ Trailing Stop Activated");
                Print("  Current Price: ", DoubleToString(trade.currentPrice, 5));
                Print("  Initial Trail: ", DoubleToString(trade.trailingStop, 5));
            }
            
            // Update trailing stop
            if(trade.isTrailing)
            {
                double newTrailStop = trade.currentPrice - StopLossPips * _Point;
                if(newTrailStop > trade.trailingStop)
                {
                    trade.trailingStop = newTrailStop;
                    Print("\n➜ Trailing Stop Updated");
                    Print("  New Trail: ", DoubleToString(trade.trailingStop, 5));
                }
            }
            
            // Check for exit conditions
            if(trade.currentPrice <= trade.stopLoss || 
               (trade.isTrailing && trade.currentPrice <= trade.trailingStop))
            {
                Print("\n⚠ Stop Loss Hit");
                Print("  Exit Price: ", DoubleToString(trade.currentPrice, 5));
                Print("  P/L: ", DoubleToString(trade.currentPrice - trade.entryPrice, 5));
                trade.Reset();
            }
            else if(trade.currentPrice >= trade.takeProfit && !trade.isTrailing)
            {
                Print("\n✓ Take Profit Hit");
                Print("  Exit Price: ", DoubleToString(trade.currentPrice, 5));
                Print("  P/L: ", DoubleToString(trade.currentPrice - trade.entryPrice, 5));
                trade.Reset();
            }
        }
    }
    
    // Report final trade status
    if(trade.isOpen)
    {
        Print("\n=== Final Trade Status ===");
        Print("Position: Open");
        Print("Entry Price: ", DoubleToString(trade.entryPrice, 5));
        Print("Current Price: ", DoubleToString(trade.currentPrice, 5));
        Print("P/L: ", DoubleToString(trade.currentPrice - trade.entryPrice, 5));
        if(trade.isTrailing)
        {
            Print("Trailing Stop: ", DoubleToString(trade.trailingStop, 5));
        }
    }
    
    Print("\n=== Test Complete ===");
    
    // Clean up test data
    CVSolMarketTestData::ClearTestData();
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize and run tests
    if(InitTest())
    {
        RunBreakoutTradeTest();  // Run the enhanced trade test
    }
    
    // Remove EA from chart after testing
    return(INIT_FAILED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Not used in test
} 
} 
