//+------------------------------------------------------------------+
//|                                     V-Scanner-Scalp-UnitTest.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

// Path to the EA
#include "../../../Experts/VSol/V-EA-Scalper.mq5"

// Test settings
input int      InpTestBars = 1000;  // Number of bars to test
input double   InpTestLotSize = 0.01;  // Fixed lot size for testing
input int      InpTestMagicNumber = 123456;  // Magic number for test trades
input double   InpTestRiskPercentage = 5.0;  // Higher risk percentage for testing
input double   InpTestRiskRewardRatio = 1.5;  // Lower RRR for more trades
input int      InpTestRSIPeriod = 14;  // Standard RSI period
input double   InpTestRSIOverbought = 60.0;  // Lower overbought threshold
input double   InpTestRSIOversold = 40.0;  // Higher oversold threshold
input bool     InpTestUseBollingerSqueeze = true;  // Enable Bollinger Squeeze
input bool     InpTestUseTimeFilter = false;  // Disable time filter

// Test results
int totalTrades = 0;
int profitableTrades = 0;
double totalNetProfit = 0.0;
double maxDrawdown = 0.0;
double maxProfit = 0.0;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("Starting unit test for V-EA-Scalper...");
   
   // Set up test parameters
   string testSymbol = Symbol();
   ENUM_TIMEFRAMES testPeriod = Period();
   int testSpread = SymbolInfoInteger(testSymbol, SYMBOL_SPREAD);
   
   Print("Test settings:");
   Print("- Symbol: ", testSymbol);
   Print("- Timeframe: ", EnumToString(testPeriod));
   Print("- Spread: ", testSpread, " points");
   Print("- Bars to test: ", InpTestBars);
   Print("- Lot size: ", InpTestLotSize);
   Print("- Magic number: ", InpTestMagicNumber);
   Print("- Risk percentage: ", InpTestRiskPercentage, "%");
   Print("- Risk/Reward ratio: 1:", InpTestRiskRewardRatio);
   Print("- RSI period: ", InpTestRSIPeriod);
   Print("- RSI overbought: ", InpTestRSIOverbought);
   Print("- RSI oversold: ", InpTestRSIOversold);
   Print("- Bollinger Squeeze: ", InpTestUseBollingerSqueeze ? "Enabled" : "Disabled");
   Print("- Time filter: ", InpTestUseTimeFilter ? "Enabled" : "Disabled");
   
   // Set up test environment
   datetime startDate = D'2022.01.01'; // Specify the start date for historical data
   datetime endDate = D'2022.12.31'; // Specify the end date for historical data
   int testBars = Bars(testSymbol, testPeriod, startDate, endDate);
   Print("Testing on ", testBars, " historical bars from ", startDate, " to ", endDate);
   
   // Prepare historical data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copiedRates = CopyRates(testSymbol, testPeriod, startDate, endDate, rates);
   
   if (copiedRates != testBars) {
      Print("Error copying historical rates. Copied ", copiedRates, " bars instead of ", testBars);
      return;
   }
   
   // Run the test on historical data
   for (int i = testBars - 1; i >= 0; i--) {
      // Update test settings in the EA
      InpRiskPercentage = InpTestRiskPercentage;
      InpRiskRewardRatio = InpTestRiskRewardRatio;
      InpRSIPeriod = InpTestRSIPeriod;
      InpRSIOverbought = InpTestRSIOverbought;
      InpRSIOversold = InpTestRSIOversold;
      InpUseBollingerSqueeze = InpTestUseBollingerSqueeze;
      UseTimeFilter = InpTestUseTimeFilter;
      
      // Update current price and other tick data based on historical rates
      MqlTick tick;
      tick.time = rates[i].time;
      tick.bid = rates[i].open;
      tick.ask = rates[i].open;
      // Set other tick fields as needed
      
      // Call the EA's OnTick function with historical data
      OnTick(tick);
      
      // Track test results
      TrackTestResults();
   }
   
   // Print test results
   PrintTestResults();
}

//+------------------------------------------------------------------+
//| Track test results                                               |
//+------------------------------------------------------------------+
void TrackTestResults()
{
   // Count total trades
   totalTrades = PositionsTotal();
   
   // Count profitable trades and total net profit
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(profit > 0) {
            profitableTrades++;
         }
         totalNetProfit += profit;
      }
   }
   
   // Track max drawdown and max profit
   double currentProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   if(currentProfit < maxDrawdown) {
      maxDrawdown = currentProfit;
   }
   if(currentProfit > maxProfit) {
      maxProfit = currentProfit;
   }
}

//+------------------------------------------------------------------+
//| Print test results                                               |
//+------------------------------------------------------------------+
void PrintTestResults()
{
   double profitFactor = totalNetProfit / MathAbs(maxDrawdown);
   double winRate = (profitableTrades / totalTrades) * 100;
   
   Print("Unit test completed. Results:");
   Print("- Total trades: ", totalTrades);
   Print("- Profitable trades: ", profitableTrades, " (", DoubleToString(winRate, 2), "%)");
   Print("- Total net profit: ", DoubleToString(totalNetProfit, 2));
   Print("- Max drawdown: ", DoubleToString(maxDrawdown, 2));
   Print("- Max profit: ", DoubleToString(maxProfit, 2));
   Print("- Profit factor: ", DoubleToString(profitFactor, 2));
} 