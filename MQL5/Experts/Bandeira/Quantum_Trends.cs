//+------------------------------------------------------------------+
//| QuantumTraderAI_TrendFollowing.mq5                               |
//| VSol Software                                                    |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.15"
#property strict

#include <Trade/Trade.mqh>
#include <Bandeira/Utility.mqh>
// Include our new signals and strategy class
#include "SignalsAndStrategy.mqh"

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+

// Strategy Activation
input group "Strategy Settings"
input bool UseTrendStrategy       = true;       // Enable or disable the Trend Following strategy
input ENUM_TIMEFRAMES Timeframe   = PERIOD_H1;  // Default timeframe
input bool AllowShortTrades       = true;       // Allow short (sell) trades

// Risk Management
input group "Risk Management"
input double RiskPercent          = 2.0;        // Percentage of account equity risked per trade
input double MaxDrawdownPercent   = 15.0;       // Maximum drawdown percentage allowed
input double ATRMultiplier        = 1.5;        // ATR multiplier for dynamic SL/TP
input double fixedStopLossPips    = 20.0;       // Fixed Stop Loss in pips

// Trend Indicators
input group "Trend Indicators"
input int ADXPeriod               = 14;         // ADX indicator period
input double TrendADXThreshold    = 25.0;       // ADX threshold for trend
input double RSIUpperThreshold    = 70.0;       // RSI overbought level
input double RSILowerThreshold    = 30.0;       // RSI oversold level

// Trading Hours
input group "Trading Time Settings"
input string TradingStartTime     = "00:00";    // Trading session start time
input string TradingEndTime       = "23:59";    // Trading session end time

// Position Management
input group "Position Management"
input bool UseTrailingStop        = false;      // Enable trailing stops
input double TrailingStopPips     = 20.0;       // Trailing stop distance in pips
input bool UseBreakeven           = false;      // Enable breakeven
input double BreakevenActivationPips = 30.0;    // Breakeven activation distance
input double BreakevenOffsetPips  = 5.0;        // Breakeven offset distance

// Order Flow Analysis
input group "Order Flow Settings"
input bool UseDOMAnalysis         = false;      // Enable DOM analysis
input double LiquidityThreshold   = 50.0;       // Liquidity pool threshold
input double ImbalanceThreshold   = 1.5;        // Order flow imbalance ratio

// Pattern Recognition
input group "Pattern Recognition"
input int EMA_PERIODS_SHORT       = 20;         // Short EMA period
input int EMA_PERIODS_MEDIUM      = 50;         // Medium EMA period
input int EMA_PERIODS_LONG        = 200;        // Long EMA period
input int PATTERN_LOOKBACK        = 5;          // Pattern lookback periods
input double GOLDEN_CROSS_THRESHOLD = 0.001;     // Golden cross threshold

// RSI/MACD Settings
input group "RSI/MACD Settings"
input int RSI_Period              = 14;         // RSI Period
input int MACD_Fast               = 12;         // MACD Fast EMA Period
input int MACD_Slow               = 26;         // MACD Slow EMA Period
input int MACD_Signal             = 9;          // MACD Signal Period
input double RSI_Neutral          = 50.0;       // RSI Neutral Level

// Order Management
input group "Order Management"
input double TakeProfitPips       = 50.0;       // Take Profit in pips
input double StopLossPips         = 30.0;       // Stop Loss in pips

//+------------------------------------------------------------------+
//| Global Variables and Objects                                     |
//+------------------------------------------------------------------+
CTrade trade;
double starting_balance;
double MinPriceChangeThreshold = 10;
double LastModificationPrice = 0;

// Instantiate the signals and strategy class
CSignalsAndStrategy signalsAndStrategy(
   Timeframe,
   ADXPeriod,
   TrendADXThreshold,
   RSIUpperThreshold,
   RSILowerThreshold,
   RSI_Period,
   MACD_Fast,
   MACD_Slow,
   MACD_Signal,
   UseDOMAnalysis,
   ImbalanceThreshold
);

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   ValidateInputs();

   // Initialize starting balance
   starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   Print("Configuration Initialized:");
   Print("  UseTrendStrategy=", UseTrendStrategy);
   Print("  RiskPercent=", RiskPercent);
   Print("  MaxDrawdownPercent=", MaxDrawdownPercent);
   Print("  ATRMultiplier=", ATRMultiplier);
   Print("  ADXPeriod=", ADXPeriod);
   Print("  TrendADXThreshold=", TrendADXThreshold);
   Print("  TradingStartTime=", TradingStartTime);
   Print("  TradingEndTime=", TradingEndTime);
   Print("  UseTrailingStop=", UseTrailingStop);
   Print("  TrailingStopPips=", TrailingStopPips);
   Print("  UseBreakeven=", UseBreakeven);
   Print("  BreakevenActivationPips=", BreakevenActivationPips);
   Print("  BreakevenOffsetPips=", BreakevenOffsetPips);
   Print("  UseDOMAnalysis=", UseDOMAnalysis);
   Print("  LiquidityThreshold=", LiquidityThreshold);
   Print("  ImbalanceThreshold=", ImbalanceThreshold);
   Print("  Timeframe=", EnumToString(Timeframe));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   string symbol = _Symbol; // Get current symbol
   
   if(!IsWithinTradingHours(TradingStartTime, TradingEndTime))
      return;

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if (CheckDrawdown(symbol, MaxDrawdownPercent, accountBalance, accountEquity))
      return;

   // Manage existing positions first (e.g., trailing stop, breakeven)
   ManagePositions(symbol);

   if (UseTrendStrategy)
   {
      // Get signals from the signals and strategy class
      int trendSignal, rsiMacdSignal, orderFlowSignal;
      signalsAndStrategy.GetSignals(symbol, trendSignal, rsiMacdSignal, orderFlowSignal);

      // Implement your logic using the retrieved signals
      if (trendSignal == 1 && rsiMacdSignal == 1 && orderFlowSignal == 1)
      {
         // Buy logic
         // Calculate SL/TP and place order if no active buy trades/pending orders
         if (!HasActiveTradeOrPendingOrder(symbol, POSITION_TYPE_BUY))
         {
            double stopLoss, takeProfit;
            CalculateDynamicSLTP(symbol, stopLoss, takeProfit, ATRMultiplier, Timeframe, fixedStopLossPips);

            double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            
            if(point <= 0)
            {
                Print("Error: Invalid point value for symbol ", symbol);
                return;
            }
            
            double lotSize = CalculateDynamicLotSize(symbol, stopLoss / point, accountBalance, RiskPercent, minVolume, maxVolume);

            Print("Placing Buy Trade for symbol ", symbol);
            PlaceBuyOrder(symbol, RiskPercent, ATRMultiplier, Timeframe, fixedStopLossPips);
         }
      }
      else if (AllowShortTrades && trendSignal == -1 && rsiMacdSignal == -1 && orderFlowSignal == -1)
      {
         // Sell logic
         if (!HasActiveTradeOrPendingOrder(symbol, POSITION_TYPE_SELL))
         {
            double stopLoss, takeProfit;
            CalculateDynamicSLTP(symbol, stopLoss, takeProfit, ATRMultiplier, Timeframe, fixedStopLossPips);

            double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            
            if(point <= 0)
            {
                Print("Error: Invalid point value for symbol ", symbol);
                return;
            }
            
            double lotSize = CalculateDynamicLotSize(symbol, stopLoss / point, accountBalance, RiskPercent, minVolume, maxVolume);

            Print("Placing Sell Trade for symbol ", symbol);
            PlaceSellOrder(symbol, RiskPercent, ATRMultiplier, Timeframe, fixedStopLossPips);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Deinitializing EA...");
}

//+------------------------------------------------------------------+
//| Manage Positions                                                 |
//+------------------------------------------------------------------+
bool ManagePositions(string symbol, int checkType = -1)
{
   bool hasPosition = false;
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if(posSymbol != symbol) continue;

         int posType = (int)PositionGetInteger(POSITION_TYPE);
         if(checkType != -1 && posType != checkType) continue;

         hasPosition = true;

         // Apply trailing stop or breakeven if enabled
         if(UseTrailingStop || UseBreakeven)
         {
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            double stop_loss = PositionGetDouble(POSITION_SL);

            if(UseTrailingStop)
               ApplyTrailingStop(symbol, ticket, posType, open_price, stop_loss);
            if(UseBreakeven)
               ApplyBreakeven(symbol, ticket, posType, open_price, stop_loss);
         }
      }
   }
   return hasPosition;
}

//+------------------------------------------------------------------+
//| Validate Input Parameters                                        |
//+------------------------------------------------------------------+
void ValidateInputs()
{
   if (RiskPercent <= 0.0 || RiskPercent > 10.0)
   {
      Alert("RiskPercent must be between 0.1 and 10.0");
      ExpertRemove();
      return;
   }

   if (MaxDrawdownPercent <= 0.0 || MaxDrawdownPercent > 100.0)
   {
      Alert("MaxDrawdownPercent must be between 0.1 and 100.0");
      ExpertRemove();
      return;
   }

   // If you had a RecoveryFactor parameter as in the original code, ensure to either remove or redefine it.
   // For now, let's comment out recovery factor checks since it is not defined in this snippet.
   // if (RecoveryFactor < 1.0 || RecoveryFactor > 2.0)
   // {
   //    Alert("RecoveryFactor must be between 1.0 and 2.0");
   //    ExpertRemove();
   //    return;
   // }

   if (ATRMultiplier <= 0.0 || ATRMultiplier > 5.0)
   {
      Alert("ATRMultiplier must be between 0.1 and 5.0");
      ExpertRemove();
      return;
   }

   if (ADXPeriod <= 0)
   {
      Alert("ADXPeriod must be greater than 0");
      ExpertRemove();
      return;
   }

   if (TrendADXThreshold <= 0.0 || TrendADXThreshold > 100.0)
   {
      Alert("TrendADXThreshold must be between 0.1 and 100.0");
      ExpertRemove();
      return;
   }

   if (TrailingStopPips <= 0.0)
   {
      Alert("TrailingStopPips must be greater than 0");
      ExpertRemove();
      return;
   }

   if (BreakevenActivationPips <= 0.0 || BreakevenOffsetPips < 0.0)
   {
      Alert("BreakevenActivationPips must be > 0 and BreakevenOffsetPips >= 0");
      ExpertRemove();
      return;
   }

   if (LiquidityThreshold <= 0.0)
   {
      Alert("LiquidityThreshold must be greater than 0");
      ExpertRemove();
      return;
   }

   if (ImbalanceThreshold <= 1.0)
   {
      Alert("ImbalanceThreshold must be greater than 1.0");
      ExpertRemove();
      return;
   }

   if (EMA_PERIODS_SHORT >= EMA_PERIODS_MEDIUM || EMA_PERIODS_MEDIUM >= EMA_PERIODS_LONG)
   {
      Alert("EMA periods must be in ascending order: SHORT < MEDIUM < LONG");
      ExpertRemove();
      return;
   }

   if (PATTERN_LOOKBACK <= 0 || PATTERN_LOOKBACK > 100)
   {
      Alert("PATTERN_LOOKBACK must be between 1 and 100");
      ExpertRemove();
      return;
   }

   if (GOLDEN_CROSS_THRESHOLD <= 0)
   {
      Alert("GOLDEN_CROSS_THRESHOLD must be greater than 0");
      ExpertRemove();
      return;
   }

   // Add symbol-specific validations
   string symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   if(point <= 0 || tickSize <= 0 || minVolume <= 0 || maxVolume <= 0)
   {
       string error = StringFormat("Invalid symbol properties for %s - Point: %.5f, Tick Size: %.5f, Min Volume: %.2f, Max Volume: %.2f",
                                 symbol, point, tickSize, minVolume, maxVolume);
       Alert(error);
       ExpertRemove();
       return;
   }
}
