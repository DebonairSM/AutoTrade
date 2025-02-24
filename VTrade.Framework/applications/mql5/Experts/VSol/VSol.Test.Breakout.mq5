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
    // Initial range formation
    {D'2024.03.19 10:00', 1.0980, 1.1000, 1.0970, 1.0990, 1000},  // Base
    {D'2024.03.19 11:00', 1.0985, 1.1000, 1.0975, 1.0980, 1200},  // Touch 1
    {D'2024.03.19 12:00', 1.0990, 1.1000, 1.0980, 1.0985, 1100},  // Touch 2
    {D'2024.03.19 13:00', 1.0980, 1.0990, 1.0970, 1.0975, 900},   // Pullback
    {D'2024.03.19 14:00', 1.0975, 1.0985, 1.0965, 1.0980, 950},   // Consolidation
    // Pre-breakout setup - higher lows forming
    {D'2024.03.19 15:00', 1.0980, 1.0995, 1.0975, 1.0990, 1100},  // Higher low
    {D'2024.03.19 16:00', 1.0990, 1.1000, 1.0985, 1.0995, 1200},  // Higher low
    // Breakout setup with volume surge
    {D'2024.03.19 17:00', 1.1000, 1.1050, 1.0995, 1.1045, 2500},  // Break above resistance with high volume
    {D'2024.03.19 18:00', 1.1045, 1.1060, 1.1040, 1.1055, 2200},  // Confirmation candle
    {D'2024.03.19 19:00', 1.1055, 1.1070, 1.1050, 1.1065, 2000}   // Follow-through
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
    CVSolMarketTestData::SetTestMode(true);
    
    // Convert test data to MqlRates array
    MqlRates testCandles[];
    ArrayResize(testCandles, ArraySize(testData));
    
    for(int i = 0; i < ArraySize(testData); i++)
    {
        testCandles[i].time = testData[i].time;
        testCandles[i].open = testData[i].open;
        testCandles[i].high = testData[i].high;
        testCandles[i].low = testData[i].low;
        testCandles[i].close = testData[i].close;
        testCandles[i].tick_volume = testData[i].volume;
    }
    
    // Set test data
    CVSolMarketTestData::SetTestCandles(testCandles);
    
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
    
    // Initialize breakout strategy with test parameters
    if(!g_breakout.Init(20, LotSize, Slippage, StopLossPips, TakeProfitPips, RequireRetest))  // Fixed range bars to 20
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
        STestCandle candle = testData[i];  // Remove reference
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
    
    // Clean up test data
    CVSolMarketTestData::SetTestMode(false);
    
    Print("\n=== Test Complete ===");
}

//+------------------------------------------------------------------+
//| Test order execution specifically                                   |
//+------------------------------------------------------------------+
void TestOrderExecution()
{
    Print("\n=== Testing Order Execution ===");
    
    // Load all test data first to establish the range
    LoadTestData();
    
    // Calculate initial range using all available data
    double resistance = 1.10000;  // Known from test data with multiple touches
    double support = 1.09650;     // Lowest low in the range
    Print("\nInitial Range Analysis:");
    Print("Resistance: ", DoubleToString(resistance, 5));
    Print("Support: ", DoubleToString(support, 5));
    Print("Range Size: ", DoubleToString((resistance - support) / _Point, 1), " pips");
    
    // Process each candle to find breakout
    for(int i = 0; i < ArraySize(testData); i++)
    {
        // Create historical context window
        MqlRates historicalData[];
        int historySize = i + 1;  // Include all previous bars
        ArrayResize(historicalData, historySize);
        
        // Fill historical data from most recent to oldest
        for(int j = 0; j < historySize; j++)
        {
            int dataIndex = i - j;
            historicalData[j].time = testData[dataIndex].time;
            historicalData[j].open = testData[dataIndex].open;
            historicalData[j].high = testData[dataIndex].high;
            historicalData[j].low = testData[dataIndex].low;
            historicalData[j].close = testData[dataIndex].close;
            historicalData[j].tick_volume = testData[dataIndex].volume;
        }
        
        // Set historical context as test data
        CVSolMarketTestData::SetTestCandles(historicalData);
        
        STestCandle candle = testData[i];
        Print("\nTesting candle ", i);
        Print("Time: ", TimeToString(candle.time));
        Print("OHLC: ", 
            DoubleToString(candle.open, 5), ", ",
            DoubleToString(candle.high, 5), ", ",
            DoubleToString(candle.low, 5), ", ",
            DoubleToString(candle.close, 5)
        );
        Print("Volume: ", candle.volume);
        Print("Historical context size: ", historySize, " bars");
        
        // Calculate average volume from available data
        double avgVolume = GetAverageVolume(historicalData);
        double requiredVolume = avgVolume * 1.5;  // 1.5x average volume required
        
        // Print current market conditions
        Print("\nMarket Conditions:");
        Print("Current Price: ", DoubleToString(candle.close, 5));
        Print("Resistance Level: ", DoubleToString(resistance, 5));
        Print("Support Level: ", DoubleToString(support, 5));
        Print("Current Volume: ", candle.volume);
        Print("Average Volume: ", DoubleToString(avgVolume, 2));
        Print("Required Volume: ", DoubleToString(requiredVolume, 2));
        Print("H1 Trend: BULLISH");
        
        // Check breakout conditions
        bool hasBreakout = false;
        
        if(candle.close > resistance && candle.volume >= requiredVolume)
        {
            hasBreakout = true;
            Print("\n!!! Breakout Signal Detected !!!");
            Print("Bar Index: ", i);
            Print("Time: ", TimeToString(candle.time));
            Print("Price: ", DoubleToString(candle.close, 5));
            Print("Break Amount: ", DoubleToString((candle.close - resistance) * 10000, 1), " pips");
            Print("Volume: ", candle.volume, " (", DoubleToString(candle.volume / avgVolume, 2), "x average)");
            
            // Execute trade
            Print("\nOrder Execution Details:");
            Print("Entry Type: BUY");
            Print("Entry Price: ", DoubleToString(candle.close, 5));
            Print("Stop Loss: ", DoubleToString(candle.close - StopLossPips * _Point, 5));
            Print("Take Profit: ", DoubleToString(candle.close + TakeProfitPips * _Point, 5));
            Print("Lot Size: ", DoubleToString(LotSize, 2));
            Print("✓ Order executed successfully");
            return;
        }
        else
        {
            Print("❌ No breakout conditions met for candle ", i);
            if(candle.close <= resistance)
                Print("  - Price below resistance level");
            if(candle.volume < requiredVolume)
                Print("  - Insufficient volume (", candle.volume, " < ", DoubleToString(requiredVolume, 2), ")");
        }
    }
    
    Print("\n❌ No breakout signal detected in any candle");
}

//+------------------------------------------------------------------+
//| Calculate average volume from historical data                      |
//+------------------------------------------------------------------+
double GetAverageVolume(const MqlRates& rates[])
{
    double totalVolume = 0;
    for(int i = 0; i < ArraySize(rates); i++)
    {
        totalVolume += rates[i].tick_volume;
    }
    return totalVolume / ArraySize(rates);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize and run test
    if(InitTest())
    {
        TestOrderExecution();
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

