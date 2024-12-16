//+------------------------------------------------------------------+
//| Pattern Scanner                                                    |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.00"
#property strict

// Input parameters
input ENUM_TIMEFRAMES ScanTimeframe = PERIOD_H1;     // Timeframe to scan
input int EMA_PERIODS_SHORT = 20;                    // Short EMA period
input int EMA_PERIODS_MEDIUM = 50;                   // Medium EMA period
input int EMA_PERIODS_LONG = 200;                    // Long EMA period
input int PATTERN_LOOKBACK = 5;                      // Pattern lookback periods
input double GOLDEN_CROSS_THRESHOLD = 0.001;         // Golden cross threshold
input bool SaveToFile = true;                        // Save results to file

enum CrossType {
    CROSS_NONE,
    CROSS_GOLDEN,
    CROSS_DEATH
};

struct PatternResult {
    string pattern_type;
    int strength;
    string details;
    bool volume_confirmed;
    double confidence;
};

//+------------------------------------------------------------------+
//| Script program start function                                      |
//+------------------------------------------------------------------+
void OnStart()
{
    // Create or clear the results file
    string results_filename = "PatternScan_Results_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    if(SaveToFile)
    {
        int handle = FileOpen(results_filename, FILE_WRITE|FILE_CSV);
        if(handle != INVALID_HANDLE)
        {
            // Write header
            FileWrite(handle, "Symbol", "Pattern", "Signal Strength", "EMA Alignment", 
                     "Cross Type", "Volume Confirmation", "Current Price", "TimeStamp");
            FileClose(handle);
        }
    }

    // Create detailed log file
    string log_filename = "PatternScan_Log_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ".txt";
    int log_handle = FileOpen(log_filename, FILE_WRITE|FILE_TXT);
    if(log_handle != INVALID_HANDLE)
    {
        FileWrite(log_handle, "Pattern Scanner Log - Started at " + TimeToString(TimeCurrent()));
        FileWrite(log_handle, "Scanning Timeframe: " + EnumToString(ScanTimeframe));
        FileWrite(log_handle, "EMA Periods: " + IntegerToString(EMA_PERIODS_SHORT) + ", " + 
                             IntegerToString(EMA_PERIODS_MEDIUM) + ", " + 
                             IntegerToString(EMA_PERIODS_LONG));
        FileWrite(log_handle, "----------------------------------------");
        FileClose(log_handle);
    }

    // Get all symbols
    string symbols[];
    int symbolsTotal = GetAllSymbols(symbols);
    
    Print("Starting scan of ", symbolsTotal, " symbols...");
    
    // Scan each symbol
    for(int i = 0; i < symbolsTotal; i++)
    {
        string symbol = symbols[i];
        if(!SymbolSelect(symbol, true)) continue;
        
        // Log scanning progress
        if(log_handle != INVALID_HANDLE)
        {
            log_handle = FileOpen(log_filename, FILE_WRITE|FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
            if(log_handle != INVALID_HANDLE)
            {
                FileSeek(log_handle, 0, SEEK_END);
                FileWrite(log_handle, "Scanning " + symbol + " (" + IntegerToString(i+1) + "/" + IntegerToString(symbolsTotal) + ")");
                FileClose(log_handle);
            }
        }
        
        ScanSymbol(symbol, results_filename, log_filename);
        
        // Show progress
        if(i % 10 == 0)
        {
            Print("Scanned ", i, " of ", symbolsTotal, " symbols");
        }
    }
    
    // Log completion
    log_handle = FileOpen(log_filename, FILE_WRITE|FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
    if(log_handle != INVALID_HANDLE)
    {
        FileSeek(log_handle, 0, SEEK_END);
        FileWrite(log_handle, "----------------------------------------");
        FileWrite(log_handle, "Scan completed at " + TimeToString(TimeCurrent()));
        FileWrite(log_handle, "Total symbols scanned: " + IntegerToString(symbolsTotal));
        FileClose(log_handle);
    }
    
    Print("Scan completed! Results saved to: ", results_filename);
    Print("Detailed log saved to: ", log_filename);
}

//+------------------------------------------------------------------+
//| Get all available symbols                                         |
//+------------------------------------------------------------------+
int GetAllSymbols(string &symbols[])
{
    ArrayResize(symbols, 0);
    
    for(int i = 0; i < SymbolsTotal(false); i++)
    {
        string symbol = SymbolName(i, false);
        ArrayResize(symbols, ArraySize(symbols) + 1);
        symbols[ArraySize(symbols) - 1] = symbol;
    }
    
    return ArraySize(symbols);
}

//+------------------------------------------------------------------+
//| Scan individual symbol                                            |
//+------------------------------------------------------------------+
void ScanSymbol(string symbol, string results_filename, string log_filename)
{
    PatternResult pattern = AnalyzePattern(symbol, ScanTimeframe);
    
    if(pattern.pattern_type != "None")
    {
        // Save to results file
        if(SaveToFile)
        {
            int results_handle = FileOpen(results_filename, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
            if(results_handle != INVALID_HANDLE)
            {
                FileSeek(results_handle, 0, SEEK_END);
                FileWrite(results_handle, 
                         symbol,
                         pattern.pattern_type,
                         pattern.strength,
                         pattern.confidence,
                         pattern.details,
                         pattern.volume_confirmed ? "Yes" : "No",
                         SymbolInfoDouble(symbol, SYMBOL_BID),
                         TimeToString(TimeCurrent())
                         );
                FileClose(results_handle);
            }
        }
        
        // Save detailed analysis to log file
        int log_handle = FileOpen(log_filename, FILE_WRITE|FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
        if(log_handle != INVALID_HANDLE)
        {
            FileSeek(log_handle, 0, SEEK_END);
            FileWrite(log_handle, "----------------------------------------");
            FileWrite(log_handle, "Pattern detected for " + symbol);
            FileWrite(log_handle, "Type: " + pattern.pattern_type);
            FileWrite(log_handle, "Strength: " + IntegerToString(pattern.strength));
            FileWrite(log_handle, "Confidence: " + DoubleToString(pattern.confidence, 1) + "%");
            FileWrite(log_handle, "Details: " + pattern.details);
            FileWrite(log_handle, "Volume Confirmed: " + (pattern.volume_confirmed ? "Yes" : "No"));
            FileWrite(log_handle, "Current Price: " + DoubleToString(SymbolInfoDouble(symbol, SYMBOL_BID), _Digits));
            FileWrite(log_handle, "Time: " + TimeToString(TimeCurrent()));
            FileClose(log_handle);
        }
        
        Print(StringFormat("%s: %s pattern detected (Strength: %d, Confidence: %.1f%%)", 
              symbol, pattern.pattern_type, pattern.strength, pattern.confidence));
    }
}

//+------------------------------------------------------------------+
//| Enhanced Pattern Analysis                                          |
//+------------------------------------------------------------------+
PatternResult AnalyzePattern(string symbol, ENUM_TIMEFRAMES timeframe)
{
    PatternResult result;
    result.pattern_type = "None";
    result.strength = 0;
    result.confidence = 0;
    
    // Initialize indicator handles
    int handle_short = iMA(symbol, timeframe, EMA_PERIODS_SHORT, 0, MODE_EMA, PRICE_CLOSE);
    int handle_medium = iMA(symbol, timeframe, EMA_PERIODS_MEDIUM, 0, MODE_EMA, PRICE_CLOSE);
    int handle_long = iMA(symbol, timeframe, EMA_PERIODS_LONG, 0, MODE_EMA, PRICE_CLOSE);
    
    // Check if indicators were created successfully
    if(handle_short == INVALID_HANDLE || 
       handle_medium == INVALID_HANDLE || 
       handle_long == INVALID_HANDLE)
    {
        Print("Failed to create indicator handles for ", symbol);
        return result;
    }
    
    // Calculate EMAs and store historical values
    double ema_data[3][10]; // [short,medium,long][lookback periods]
    
    // Arrays for copying indicator data
    double short_buffer[];
    double medium_buffer[];
    double long_buffer[];
    
    ArraySetAsSeries(short_buffer, true);
    ArraySetAsSeries(medium_buffer, true);
    ArraySetAsSeries(long_buffer, true);
    
    // Copy indicator data
    if(CopyBuffer(handle_short, 0, 0, 10, short_buffer) <= 0 ||
       CopyBuffer(handle_medium, 0, 0, 10, medium_buffer) <= 0 ||
       CopyBuffer(handle_long, 0, 0, 10, long_buffer) <= 0)
    {
        Print("Failed to copy indicator data for ", symbol);
        return result;
    }
    
    // Fill the ema_data array
    for(int i = 0; i < 10; i++)
    {
        ema_data[0][i] = short_buffer[i];
        ema_data[1][i] = medium_buffer[i];
        ema_data[2][i] = long_buffer[i];
    }
    
    // Release indicator handles
    IndicatorRelease(handle_short);
    IndicatorRelease(handle_medium);
    IndicatorRelease(handle_long);
    
    // Pattern Analysis
    int bull_score = 0;
    int bear_score = 0;
    
    // 1. EMA Alignment Analysis
    if(IsStrongEMAAlignment(ema_data, true)) bull_score += 3;
    if(IsStrongEMAAlignment(ema_data, false)) bear_score += 3;
    
    // 2. Cross Detection
    CrossType cross = DetectCross(ema_data);
    switch(cross) {
        case CROSS_GOLDEN: bull_score += 4; break;
        case CROSS_DEATH:  bear_score += 4; break;
    }
    
    // 3. Volume Analysis
    bool volume_confirmed = AnalyzeVolume(symbol, timeframe);
    if(volume_confirmed) {
        bull_score += (bull_score > bear_score) ? 2 : 0;
        bear_score += (bear_score > bull_score) ? 2 : 0;
    }
    
    // 4. Momentum Confirmation
    int rsi_handle = iRSI(symbol, timeframe, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE)
    {
        Print("Failed to create RSI handle for ", symbol);
        return result;
    }
    
    double rsi_buffer[];
    ArraySetAsSeries(rsi_buffer, true);
    
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) <= 0)
    {
        Print("Failed to copy RSI data for ", symbol);
        IndicatorRelease(rsi_handle);
        return result;
    }
    
    double rsi = rsi_buffer[0];
    IndicatorRelease(rsi_handle);
    
    if(rsi > 50 && rsi < 70) bull_score++;
    if(rsi < 50 && rsi > 30) bear_score++;
    
    // Determine Pattern Type and Strength
    result.volume_confirmed = volume_confirmed;
    
    if(bull_score >= 5 && bull_score > bear_score * 1.5) {
        result.pattern_type = "Bullish";
        result.strength = bull_score;
        result.confidence = CalculateConfidence(bull_score, volume_confirmed);
        result.details = FormatPatternDetails(cross, rsi, volume_confirmed);
    }
    else if(bear_score >= 5 && bear_score > bull_score * 1.5) {
        result.pattern_type = "Bearish";
        result.strength = bear_score;
        result.confidence = CalculateConfidence(bear_score, volume_confirmed);
        result.details = FormatPatternDetails(cross, rsi, volume_confirmed);
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Helper Functions                                                   |
//+------------------------------------------------------------------+
bool IsStrongEMAAlignment(double &ema_data[][], bool bullish)
{
    if(bullish) {
        return ema_data[0][0] > ema_data[1][0] && 
               ema_data[1][0] > ema_data[2][0] &&
               ema_data[0][1] > ema_data[1][1] && 
               ema_data[1][1] > ema_data[2][1];
    }
    return ema_data[0][0] < ema_data[1][0] && 
           ema_data[1][0] < ema_data[2][0] &&
           ema_data[0][1] < ema_data[1][1] && 
           ema_data[1][1] < ema_data[2][1];
}

double CalculateConfidence(int score, bool volume_confirmed)
{
    double confidence = score * 10.0;
    if(volume_confirmed) confidence *= 1.2;
    return MathMin(confidence, 100.0);
}

//+------------------------------------------------------------------+
//| Detect EMA crosses                                                 |
//+------------------------------------------------------------------+
CrossType DetectCross(double &ema_data[][])
{
    // Check for Golden Cross (short crosses above long)
    if(ema_data[0][1] < ema_data[2][1] && ema_data[0][0] > ema_data[2][0])
        return CROSS_GOLDEN;
    
    // Check for Death Cross (short crosses below long)
    if(ema_data[0][1] > ema_data[2][1] && ema_data[0][0] < ema_data[2][0])
        return CROSS_DEATH;
        
    return CROSS_NONE;
}

//+------------------------------------------------------------------+
//| Analyze volume confirmation                                        |
//+------------------------------------------------------------------+
bool AnalyzeVolume(string symbol, ENUM_TIMEFRAMES timeframe)
{
    double current_volume = iVolume(symbol, timeframe, 0);
    double avg_volume = 0;
    
    // Calculate average volume over last 5 periods
    for(int i = 1; i <= 5; i++)
    {
        avg_volume += iVolume(symbol, timeframe, i);
    }
    avg_volume /= 5;
    
    return (current_volume > avg_volume * 1.2); // 20% above average
}

//+------------------------------------------------------------------+
//| Format pattern details as string                                   |
//+------------------------------------------------------------------+
string FormatPatternDetails(CrossType cross, double rsi, bool volume_confirmed)
{
    string cross_str = "";
    switch(cross)
    {
        case CROSS_GOLDEN: cross_str = "Golden Cross"; break;
        case CROSS_DEATH:  cross_str = "Death Cross";  break;
        default:           cross_str = "No Cross";     break;
    }
    
    return StringFormat("Cross: %s, RSI: %.1f, Volume: %s", 
                       cross_str, 
                       rsi,
                       volume_confirmed ? "Confirmed" : "Weak");
}