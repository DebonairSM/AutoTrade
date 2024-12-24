//+------------------------------------------------------------------+
//| VLogging.mqh - Logging utilities for V-EA                          |
//+------------------------------------------------------------------+

// Function to log signal updates
void LogSignalUpdates(string symbol, 
                      double trendSignal, double trendWeight,
                      double patternSignal, double patternWeight,
                      double rsiMacdSignal, double rsiMacdWeight,
                      double orderFlowSignal, double orderFlowWeight,
                      double totalScore, double scoreThreshold,
                      double stopLoss, double takeProfit,
                      datetime calculationTime)
{
    Print("=== Signal Updates for ", symbol, " ===");
    
    // Signal Values
    Print("Signal Values:");
    Print("  Trend Signal: ", trendSignal, " (weight: ", trendWeight, ")");
    Print("  Pattern Signal: ", patternSignal, " (weight: ", patternWeight, ")");
    Print("  RSI/MACD Signal: ", rsiMacdSignal, " (weight: ", rsiMacdWeight, ")");
    Print("  Order Flow Signal: ", orderFlowSignal, " (weight: ", orderFlowWeight, ")");
    
    // Score Analysis
    Print("\nScore Analysis:");
    Print("  Total Score: ", totalScore);
    Print("  Score Threshold: ", scoreThreshold);
    Print("  Score Breakdown:");
    Print("    Trend Contribution: ", trendSignal * trendWeight);
    Print("    Pattern Contribution: ", patternSignal * patternWeight);
    Print("    RSI/MACD Contribution: ", rsiMacdSignal * rsiMacdWeight);
    Print("    Order Flow Contribution: ", orderFlowSignal * orderFlowWeight);
    
    // Trade Parameters
    Print("\nTrade Parameters:");
    Print("  Stop Loss: ", stopLoss);
    Print("  Take Profit: ", takeProfit);
    Print("  Calculation Time: ", TimeToString(calculationTime, TIME_DATE | TIME_MINUTES));
    Print("===============================");
}

// Function to log lot size calculations
void LogLotSizeCalculation(string symbol, 
                          double accountBalance, 
                          double riskPercent,
                          double stopLoss,
                          double tickValue,
                          double lotSize)
{
    Print("=== Lot Size Calculation for ", symbol, " ===");
    Print("Account Details:");
    Print("  Balance: ", accountBalance);
    Print("  Risk Percent: ", riskPercent, "%");
    Print("  Intended Monetary Risk: ", riskPercent * accountBalance / 100);
    
    Print("\nSymbol Properties:");
    Print("  Stop Loss (pips): ", stopLoss / SymbolInfoDouble(symbol, SYMBOL_POINT));
    Print("  Tick Value: ", tickValue);
    Print("  Tick Size: ", SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE));
    Print("  Lot Step: ", SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP));
    
    Print("\nCalculation Results:");
    Print("  Calculated Lot Size: ", lotSize);
    Print("  Actual Monetary Risk: ", lotSize * stopLoss * tickValue);
    Print("===============================");
}

// Enhanced trade rejection logging
void LogTradeRejection(string reason, 
                       string symbol, 
                       double currentPrice,
                       double adx, 
                       double rsi, 
                       double ema_short, 
                       double ema_medium, 
                       double ema_long,
                       double adx_threshold, 
                       double rsi_upper, 
                       double rsi_lower, 
                       bool useDOMAnalysis, 
                       ENUM_TIMEFRAMES timeframe)
{
    Print("=== Trade Rejection for ", symbol, " ===");
    Print("Reason: ", reason);
    
    Print("\nCurrent Market Conditions:");
    Print("  Price: ", currentPrice);
    Print("  Timeframe: ", EnumToString(timeframe));
    
    Print("\nIndicator Values:");
    Print("  ADX: ", adx, " (threshold: ", adx_threshold, ")");
    Print("  RSI: ", rsi, " (bounds: ", rsi_lower, " - ", rsi_upper, ")");
    Print("  EMA Short: ", ema_short);
    Print("  EMA Medium: ", ema_medium);
    Print("  EMA Long: ", ema_long);
    Print("  DOM Analysis Enabled: ", useDOMAnalysis);
    Print("===============================");
} 