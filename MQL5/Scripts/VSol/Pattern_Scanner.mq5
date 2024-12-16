//+------------------------------------------------------------------+
//| Pattern Scanner                                                   |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.15"
#property strict

// Input parameters
input ENUM_TIMEFRAMES ScanTimeframe = PERIOD_H1;     // Timeframe to scan
input int EMA_PERIODS_SHORT = 20;                    // Short EMA period
input int EMA_PERIODS_MEDIUM = 50;                   // Medium EMA period
input int EMA_PERIODS_LONG = 200;                    // Long EMA period
input int PATTERN_LOOKBACK = 5;                      // Pattern lookback periods
input double GOLDEN_CROSS_THRESHOLD = 1.0;           // Adjusted Golden cross threshold from 0.001 to a larger value
input bool SaveToFile = true;                        // Save results to file

// Enhanced Analysis Parameters
input double ADX_THRESHOLD = 20.0;                   // ADX threshold
input double RSI_UPPER_THRESHOLD = 70.0;             // RSI upper threshold
input double RSI_LOWER_THRESHOLD = 30.0;             // RSI lower threshold
input double DI_DIFFERENCE_THRESHOLD = 2.0;          // DI difference threshold
input int RSI_Period = 14;                           // RSI period
input int MACD_Fast = 12;                            // MACD fast period
input int MACD_Slow = 26;                            // MACD slow period
input int MACD_Signal = 9;                           // MACD signal period
input double RSI_Neutral = 50.0;                     // RSI neutral level

// Volume Analysis Parameters
input double VOLUME_THRESHOLD = 1.5;                 // Volume threshold multiplier
input bool USE_VOLUME_CONFIRMATION = true;           // Use volume confirmation

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
    double rsi_value;
    double macd_value;
    double adx_value;
    double currentPrice;
    double ema_short;
    double ema_medium;
    double ema_long;
    double volume;
    double avgVolume;
};

struct MarketAnalysisData {
    double currentPrice;
    double ema_short;
    double ema_medium;
    double ema_long;
    double adx;
    double plusDI;
    double minusDI;
    double rsi;
    double macdMain;
    double macdSignal;
    double macdHistogram;
    double atr;
    bool bullishPattern;
    bool bearishPattern;
    double volume;
    double avgVolume;
};

struct MarketAnalysisParameters {
    int ema_period_short;
    int ema_period_medium;
    int ema_period_long;
    int adx_period;
    int rsi_period;
    double trend_adx_threshold;
    double rsi_upper_threshold;
    double rsi_lower_threshold;
};

// Global variables for logging
datetime lastLogTime = 0;
int logHandle = INVALID_HANDLE;

struct ScanFiles {
    string txtFile;
    string csvFile;
};

ScanFiles CreateUniqueFileNames()
{
    ScanFiles files;
    string timeStamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
    timeStamp = StringReplace(timeStamp, ":", "-");
    timeStamp = StringReplace(timeStamp, ".", "");
    
    files.txtFile = "Scanner_" + timeStamp + ".txt"; 
    files.csvFile = "Scanner_" + timeStamp + ".csv";
    
    return files;
}

// Helper function to safely add scores with a cap
void AddScore(double &target, double value, string reason, string &reasons[])
{
    // Cap individual contributions at a certain amount, e.g., 5 points
    double cappedValue = MathMin(value, 5.0);
    // Add reason if value added
    if(cappedValue != 0)
    {
        ArrayResize(reasons, ArraySize(reasons)+1);
        reasons[ArraySize(reasons)-1] = reason;
    }
    target += cappedValue;
}

//+------------------------------------------------------------------+
//| Script program start function                                     |
//+------------------------------------------------------------------+
void OnStart()
{
    // Create files immediately and verify they're ready
    ScanFiles files = CreateUniqueFileNames();
    Print("Attempting to create log files...");
    
    // Create and verify TXT file
    logHandle = FileOpen(files.txtFile, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_SHARE_READ);
    if(logHandle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create log file: ", files.txtFile);
        return;
    }
    Print("Successfully created log file: ", files.txtFile);
    
    // Create and verify CSV file
    int csvHandle = FileOpen(files.csvFile, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ);
    if(csvHandle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create CSV file: ", files.csvFile);
        FileClose(logHandle);
        return;
    }
    Print("Successfully created CSV file: ", files.csvFile);
    
    // Write CSV headers immediately
    FileWrite(csvHandle, 
        "Scan Time",
        "Symbol",
        "Pattern Type",
        "Strength",
        "Confidence",
        "Volume Confirmed",
        "RSI",
        "MACD",
        "ADX",
        "Current Price",
        "EMA Short",
        "EMA Medium",
        "EMA Long",
        "Volume",
        "Avg Volume",
        "Timeframe"
    );
    FileFlush(csvHandle);

    // Log scan start
    string scanStartTime = TimeToString(TimeCurrent());
    LogMessage("=== Pattern Scan Started at " + scanStartTime + " ===", true);
    LogMessage("Timeframe: " + EnumToString(ScanTimeframe));
    FileFlush(logHandle);

    // Get symbols and log count
    string symbols[];
    int symbolCount = GetTradeableSymbols(symbols);
    LogMessage("Found " + IntegerToString(symbolCount) + " tradeable symbols");
    FileFlush(logHandle);
    
    // Log configuration
    LogMessage("=== Pattern Scan Configuration ===", true);
    LogMessage("Timeframe: " + EnumToString(ScanTimeframe));
    LogMessage("EMA Periods: " + IntegerToString(EMA_PERIODS_SHORT) + "/" + 
              IntegerToString(EMA_PERIODS_MEDIUM) + "/" + 
              IntegerToString(EMA_PERIODS_LONG));
    LogMessage("ADX Threshold: " + DoubleToString(ADX_THRESHOLD, 1));
    LogMessage("RSI Thresholds: " + DoubleToString(RSI_LOWER_THRESHOLD, 1) + 
              "/" + DoubleToString(RSI_UPPER_THRESHOLD, 1));
    LogMessage("Volume Confirmation: " + (USE_VOLUME_CONFIRMATION ? "Yes" : "No"));
    LogMessage("=== Scan Progress ===", true);
    FileFlush(logHandle);

    int patternsFound = 0;
    
    for(int i = 0; i < symbolCount; i++)
    {
        double progress = (double)i / symbolCount * 100;
        if(i == 0 || i == symbolCount-1 || MathMod(progress, 10) < (100.0/symbolCount))
        {
            LogMessage(StringFormat("Scanning progress: %.0f%% (%d/%d)", 
                      progress, i, symbolCount), true);
            FileFlush(logHandle);
        }
        
        PatternResult result = AnalyzePattern(symbols[i], ScanTimeframe);
        if(result.strength > 0)
        {
            patternsFound++;
            string message = FormatPatternResult(symbols[i], result);
            LogMessage("Pattern Found: " + symbols[i], true);
            LogMessage(message);
            // Log detailed reasons if present
            if(result.details != "")
            {
                LogMessage("Detailed Analysis:");
                LogMessage(result.details);
            }
            FileFlush(logHandle);
            
            // Write to CSV
            if(csvHandle != INVALID_HANDLE)
            {
                string currentTime = TimeToString(TimeCurrent());
                FileWrite(csvHandle,
                    currentTime,
                    symbols[i],
                    result.pattern_type,
                    result.strength,
                    DoubleToString(result.confidence, 2),
                    result.volume_confirmed ? "Yes" : "No",
                    DoubleToString(result.rsi_value, 2),
                    DoubleToString(result.macd_value, 5),
                    DoubleToString(result.adx_value, 2),
                    DoubleToString(result.currentPrice, 5),
                    DoubleToString(result.ema_short, 5),
                    DoubleToString(result.ema_medium, 5),
                    DoubleToString(result.ema_long, 5),
                    DoubleToString(result.volume, 2),
                    DoubleToString(result.avgVolume, 2),
                    EnumToString(ScanTimeframe)
                );
                FileFlush(csvHandle);
            }
        }
    }

    string completionMessage = StringFormat(
        "Scan completed. Analyzed %d symbols, found %d patterns.",
        symbolCount,
        patternsFound
    );
    LogMessage("=== " + completionMessage + " ===", true);
    LogMessage("Results saved to CSV: " + files.csvFile, true);
    FileFlush(logHandle);

    if(logHandle != INVALID_HANDLE)
        FileClose(logHandle);
    if(csvHandle != INVALID_HANDLE)
        FileClose(csvHandle);
        
    Print("Scan complete. Check files: ", files.txtFile, " and ", files.csvFile);
}

//+------------------------------------------------------------------+
//| Analyze pattern for a single symbol                               |
//+------------------------------------------------------------------+
PatternResult AnalyzePattern(string symbol, ENUM_TIMEFRAMES timeframe)
{
    PatternResult result;
    result.pattern_type = "None";
    result.strength = 0;
    result.confidence = 0;

    MarketAnalysisData analysisData;
    MarketAnalysisParameters params;

    params.ema_period_short = EMA_PERIODS_SHORT;
    params.ema_period_medium = EMA_PERIODS_MEDIUM;
    params.ema_period_long = EMA_PERIODS_LONG;
    params.adx_period = 14;
    params.rsi_period = RSI_Period;
    params.trend_adx_threshold = ADX_THRESHOLD;
    params.rsi_upper_threshold = RSI_UPPER_THRESHOLD;
    params.rsi_lower_threshold = RSI_LOWER_THRESHOLD;

    if(!PopulateMarketData(symbol, timeframe, analysisData))
    {
        return result;
    }

    string reasonSummary = "";
    int patternSignal = IdentifyTrendPattern(analysisData, params, reasonSummary);
    int rsiMacdSignal = AnalyzeRSIMACD(analysisData);
    bool volumeConfirmed = USE_VOLUME_CONFIRMATION ? CheckVolumeConfirmation(analysisData) : true;

    if(patternSignal != 0 && rsiMacdSignal != 0 && volumeConfirmed)
    {
        // Combine patternSignal and rsiMacdSignal for final strength
        // Expecting both signals to be small integers, we simply average them
        // If needed, adjust scaling factors here.
        int combinedScore = (patternSignal + rsiMacdSignal) / 2;

        if(patternSignal > 0 && rsiMacdSignal > 0)
        {
            result.pattern_type = "Bullish";
            result.strength = combinedScore;
        }
        else if(patternSignal < 0 && rsiMacdSignal < 0)
        {
            result.pattern_type = "Bearish";
            result.strength = MathAbs(combinedScore);
        }

        result.confidence = CalculateConfidence(result.strength, volumeConfirmed);
        result.volume_confirmed = volumeConfirmed;
        result.rsi_value = analysisData.rsi;
        result.macd_value = analysisData.macdMain;
        result.adx_value = analysisData.adx;

        result.details = GenerateAnalysisDetails(analysisData, params);
        if(reasonSummary != "")
            result.details += "\n" + reasonSummary;
    }

    result.currentPrice = analysisData.currentPrice;
    result.ema_short = analysisData.ema_short;
    result.ema_medium = analysisData.ema_medium;
    result.ema_long = analysisData.ema_long;
    result.volume = analysisData.volume;
    result.avgVolume = analysisData.avgVolume;

    return result;
}

//+------------------------------------------------------------------+
//| Populate Market Data                                              |
//+------------------------------------------------------------------+
bool PopulateMarketData(string symbol, ENUM_TIMEFRAMES timeframe, MarketAnalysisData &data)
{
    data.currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    data.ema_short = CalculateEMA(symbol, timeframe, EMA_PERIODS_SHORT);
    data.ema_medium = CalculateEMA(symbol, timeframe, EMA_PERIODS_MEDIUM);
    data.ema_long = CalculateEMA(symbol, timeframe, EMA_PERIODS_LONG);
    
    CalculateADX(symbol, timeframe, 14, data.adx, data.plusDI, data.minusDI);
    data.rsi = CalculateRSI(symbol, timeframe, RSI_Period);
    CalculateMACD(symbol, timeframe, data.macdMain, data.macdSignal, data.macdHistogram);
    data.atr = CalculateATR(symbol, timeframe, 14);
    data.volume = iVolume(symbol, timeframe, 0);
    data.avgVolume = CalculateAverageVolume(symbol, timeframe, 20);
    
    data.bullishPattern = IsBullishCandlePattern(symbol, timeframe);
    data.bearishPattern = IsBearishCandlePattern(symbol, timeframe);
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Confidence Score                                        |
//+------------------------------------------------------------------+
double CalculateConfidence(int strength, bool volumeConfirmed)
{
    // Adjusted logic:
    // Assume strength goes up to around 10 max after adjustments.
    // Base confidence: strength * 7 (so max 70%)
    double confidence = strength * 7.0;
    
    // Volume confirmation adds up to 30 points, max 100%
    if(volumeConfirmed)
        confidence += 30.0;
    
    confidence = MathMin(confidence, 100.0);
    confidence = MathMax(confidence, 0.0);
    
    return NormalizeDouble(confidence, 2);
}

//+------------------------------------------------------------------+
//| Identify Trend Pattern                                            |
//+------------------------------------------------------------------+
int IdentifyTrendPattern(MarketAnalysisData &data, MarketAnalysisParameters &params, string &reasonSummary)
{
    struct TrendScore {
        double bullish;
        double bearish;
        string reasons[];
    } score;
    score.bullish = 0;
    score.bearish = 0;

    // 1. EMA Alignment Analysis
    if(data.ema_short > data.ema_medium && data.ema_medium > data.ema_long)
        AddScore(score.bullish, 2.5, "Bullish EMA alignment", score.reasons);
    else if(data.ema_short < data.ema_medium && data.ema_medium < data.ema_long)
        AddScore(score.bearish, 2.5, "Bearish EMA alignment", score.reasons);

    // 2. Cross Detection
    double cross_strength = MathAbs(data.ema_short - data.ema_long);
    // If EMAs differ by more than GOLDEN_CROSS_THRESHOLD, reward up to a limit
    if(cross_strength > GOLDEN_CROSS_THRESHOLD) {
        double factor = cross_strength / GOLDEN_CROSS_THRESHOLD;
        // Cap factor to avoid extreme values, for example factor = MathMin(factor, 3.0)
        factor = MathMin(factor, 3.0); 
        if(data.ema_short > data.ema_long)
            AddScore(score.bullish, 3.0 * factor, "Golden Cross", score.reasons);
        else
            AddScore(score.bearish, 3.0 * factor, "Death Cross", score.reasons);
    }

    // 3. Volume Analysis
    // Volume analysis can give a smaller boost, e.g., 1.5 max
    if(data.volume > data.avgVolume * VOLUME_THRESHOLD) {
        if(score.bullish > score.bearish)
            AddScore(score.bullish, 1.5, "High Volume Bullish Confirmation", score.reasons);
        else if(score.bearish > score.bullish)
            AddScore(score.bearish, 1.5, "High Volume Bearish Confirmation", score.reasons);
    }

    // 4. Additional Technical Indicators (ADX)
    if(data.adx > ADX_THRESHOLD) {
        if(data.plusDI > data.minusDI)
            AddScore(score.bullish, 1.5, "Strong ADX Bullish Momentum", score.reasons);
        else
            AddScore(score.bearish, 1.5, "Strong ADX Bearish Momentum", score.reasons);
    }

    // Build reasonSummary
    reasonSummary = "Pattern Reasons:\n";
    for(int i=0; i<ArraySize(score.reasons); i++)
    {
        reasonSummary += " - " + score.reasons[i] + "\n";
    }

    const double MIN_SCORE_THRESHOLD = 5.0;
    const double SCORE_DIFFERENCE_THRESHOLD = 2.0;

    if(score.bullish >= MIN_SCORE_THRESHOLD &&
       (score.bullish - score.bearish) >= SCORE_DIFFERENCE_THRESHOLD)
        return (int)MathRound(score.bullish);
    else if(score.bearish >= MIN_SCORE_THRESHOLD &&
            (score.bearish - score.bullish) >= SCORE_DIFFERENCE_THRESHOLD)
        return -(int)MathRound(score.bearish);

    return 0;
}

//+------------------------------------------------------------------+
//| Analyze RSI and MACD Combination                                  |
//+------------------------------------------------------------------+
int AnalyzeRSIMACD(MarketAnalysisData &data)
{
    bool rsiOversold = data.rsi < RSI_LOWER_THRESHOLD;
    bool rsiOverbought = data.rsi > RSI_UPPER_THRESHOLD;
    bool rsiTrendUp = data.rsi > RSI_Neutral && data.rsi < RSI_UPPER_THRESHOLD;
    bool rsiTrendDown = data.rsi < RSI_Neutral && data.rsi > RSI_LOWER_THRESHOLD;
    
    bool macdBullish = data.macdMain > data.macdSignal && data.macdHistogram > 0;
    bool macdBearish = data.macdMain < data.macdSignal && data.macdHistogram < 0;
    
    if((rsiOversold || rsiTrendUp) && macdBullish)
        return 1;  // Bullish signal
    else if((rsiOverbought || rsiTrendDown) && macdBearish)
        return -1; // Bearish signal
    
    return 0;  // No clear signal
}

//+------------------------------------------------------------------+
//| Check Volume Confirmation                                         |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation(MarketAnalysisData &data)
{
    if(!USE_VOLUME_CONFIRMATION)
        return true;
        
    return (data.volume > data.avgVolume * VOLUME_THRESHOLD);
}

//+------------------------------------------------------------------+
//| Generate Analysis Details                                         |
//+------------------------------------------------------------------+
string GenerateAnalysisDetails(MarketAnalysisData &data, MarketAnalysisParameters &params)
{
    string details = "";
    
    // Trend Analysis
    details += "Trend Analysis:\n";
    if(data.ema_short > data.ema_medium && data.ema_medium > data.ema_long)
        details += "Strong Bullish Trend - All EMAs aligned upward\n";
    else if(data.ema_short < data.ema_medium && data.ema_medium < data.ema_long)
        details += "Strong Bearish Trend - All EMAs aligned downward\n";
    else
        details += "Mixed Trend - No clear EMA alignment\n";
    
    // Momentum Analysis
    details += "\nMomentum Analysis:\n";
    if(data.adx > ADX_THRESHOLD) {
        details += "Strong Trend (ADX > " + DoubleToString(ADX_THRESHOLD, 1) + "): ";
        if(data.plusDI > data.minusDI)
            details += "Bullish momentum\n";
        else
            details += "Bearish momentum\n";
    } else {
        details += "Weak trend - Consider ranging market conditions\n";
    }
    
    // RSI Conditions
    details += "\nOverbought/Oversold:\n";
    if(data.rsi > RSI_UPPER_THRESHOLD)
        details += "Overbought conditions - Potential reversal point\n";
    else if(data.rsi < RSI_LOWER_THRESHOLD)
        details += "Oversold conditions - Potential reversal point\n";
    else
        details += "Normal RSI range - No extreme conditions\n";
    
    // Volume Analysis
    details += "\nVolume Analysis:\n";
    double volRatio = data.volume/data.avgVolume;
    if(volRatio > VOLUME_THRESHOLD)
        details += "High volume confirmation (" + DoubleToString(volRatio, 1) + "x average)\n";
    else
        details += "Below average volume - Weak confirmation\n";
    
    return details;
}

//+------------------------------------------------------------------+
//| Calculate Average Volume                                          |
//+------------------------------------------------------------------+
double CalculateAverageVolume(string symbol, ENUM_TIMEFRAMES timeframe, int periods)
{
    double totalVolume = 0;
    for(int i = 1; i <= periods; i++)
    {
        totalVolume += iVolume(symbol, timeframe, i);
    }
    return totalVolume / periods;
}

//+------------------------------------------------------------------+
//| Calculate EMA                                                     |
//+------------------------------------------------------------------+
double CalculateEMA(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 0)
{
    double ema[];
    ArraySetAsSeries(ema, true);
    
    int handle = iMA(symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
    if(handle == INVALID_HANDLE)
    {
        Print("Error creating EMA indicator handle");
        return 0;
    }
    
    if(CopyBuffer(handle, 0, shift, 1, ema) != 1)
    {
        Print("Error copying EMA data");
        return 0;
    }
    
    IndicatorRelease(handle);
    return ema[0];
}

//+------------------------------------------------------------------+
//| Calculate ADX                                                     |
//+------------------------------------------------------------------+
void CalculateADX(string symbol, ENUM_TIMEFRAMES timeframe, int period, 
                 double &adx, double &plusDI, double &minusDI)
{
    double adxBuffer[];
    double plusBuffer[];
    double minusBuffer[];
    ArraySetAsSeries(adxBuffer, true);
    ArraySetAsSeries(plusBuffer, true);
    ArraySetAsSeries(minusBuffer, true);
    
    int handle = iADX(symbol, timeframe, period);
    if(handle == INVALID_HANDLE)
    {
        Print("Error creating ADX indicator handle");
        return;
    }
    
    if(CopyBuffer(handle, 0, 0, 1, adxBuffer) != 1 ||
       CopyBuffer(handle, 1, 0, 1, plusBuffer) != 1 ||
       CopyBuffer(handle, 2, 0, 1, minusBuffer) != 1)
    {
        Print("Error copying ADX data");
        return;
    }
    
    adx = adxBuffer[0];
    plusDI = plusBuffer[0];
    minusDI = minusBuffer[0];
    
    IndicatorRelease(handle);
}

//+------------------------------------------------------------------+
//| Calculate RSI                                                     |
//+------------------------------------------------------------------+
double CalculateRSI(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 0)
{
    double rsi[];
    ArraySetAsSeries(rsi, true);
    
    int handle = iRSI(symbol, timeframe, period, PRICE_CLOSE);
    if(handle == INVALID_HANDLE)
    {
        Print("Error creating RSI indicator handle");
        return 0;
    }
    
    if(CopyBuffer(handle, 0, shift, 1, rsi) != 1)
    {
        Print("Error copying RSI data");
        return 0;
    }
    
    IndicatorRelease(handle);
    return rsi[0];
}

//+------------------------------------------------------------------+
//| Calculate MACD                                                    |
//+------------------------------------------------------------------+
void CalculateMACD(string symbol, ENUM_TIMEFRAMES timeframe, 
                  double &macdMain, double &macdSignal, double &macdHistogram)
{
    double macdBuffer[];
    double signalBuffer[];
    ArraySetAsSeries(macdBuffer, true);
    ArraySetAsSeries(signalBuffer, true);
    
    int handle = iMACD(symbol, timeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    if(handle == INVALID_HANDLE)
    {
        Print("Error creating MACD indicator handle");
        return;
    }
    
    if(CopyBuffer(handle, 0, 0, 1, macdBuffer) != 1 ||
       CopyBuffer(handle, 1, 0, 1, signalBuffer) != 1)
    {
        Print("Error copying MACD data");
        return;
    }
    
    macdMain = macdBuffer[0];
    macdSignal = signalBuffer[0];
    macdHistogram = macdMain - macdSignal;
    
    IndicatorRelease(handle);
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                     |
//+------------------------------------------------------------------+
double CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 0)
{
    double atr[];
    ArraySetAsSeries(atr, true);
    
    int handle = iATR(symbol, timeframe, period);
    if(handle == INVALID_HANDLE)
    {
        Print("Error creating ATR indicator handle");
        return 0;
    }
    
    if(CopyBuffer(handle, 0, shift, 1, atr) != 1)
    {
        Print("Error copying ATR data");
        return 0;
    }
    
    IndicatorRelease(handle);
    return atr[0];
}

//+------------------------------------------------------------------+
//| Get Tradeable Symbols                                            |
//+------------------------------------------------------------------+
int GetTradeableSymbols(string &symbols[])
{
    int total = SymbolsTotal(true);
    ArrayResize(symbols, total);
    int count = 0;
    
    for(int i = 0; i < total; i++)
    {
        string symbol = SymbolName(i, true);
        if(SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL)
        {
            symbols[count++] = symbol;
        }
    }
    
    ArrayResize(symbols, count);
    return count;
}

//+------------------------------------------------------------------+
//| Log Message with Timestamp                                        |
//+------------------------------------------------------------------+
void LogMessage(string message, bool showInTerminal = false)
{
    if(SaveToFile && logHandle != INVALID_HANDLE)
    {
        string timestampedMessage = TimeToString(TimeCurrent()) + ": " + message;
        FileWriteString(logHandle, timestampedMessage + "\n");
        FileFlush(logHandle);
    }
    if(showInTerminal)
        Print(message);
}

//+------------------------------------------------------------------+
//| Format Pattern Result                                             |
//+------------------------------------------------------------------+
string FormatPatternResult(string symbol, PatternResult &result)
{
    string analysis = StringFormat(
        "%s: %s Pattern Detected\n" +
        "Strength: %d/10\n" +
        "Confidence: %.1f%%\n" +
        "Volume Confirmation: %s\n",
        symbol,
        result.pattern_type,
        result.strength,
        result.confidence,
        result.volume_confirmed ? "Confirmed" : "Weak"
    );
    
    if(result.pattern_type == "Bullish")
        analysis += "Potential upward movement expected\n";
    else if(result.pattern_type == "Bearish")
        analysis += "Potential downward movement expected\n";
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Check for Bullish Candlestick Pattern                            |
//+------------------------------------------------------------------+
bool IsBullishCandlePattern(string symbol, ENUM_TIMEFRAMES timeframe)
{
    double open[3], high[3], low[3], close[3];
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyOpen(symbol, timeframe, 0, 3, open) != 3 ||
       CopyHigh(symbol, timeframe, 0, 3, high) != 3 ||
       CopyLow(symbol, timeframe, 0, 3, low) != 3 ||
       CopyClose(symbol, timeframe, 0, 3, close) != 3)
    {
        Print("Error copying price data");
        return false;
    }
    
    double avgCandleSize = 0;
    for(int i = 0; i < 3; i++)
    {
        avgCandleSize += (high[i] - low[i]);
    }
    avgCandleSize /= 3;
    
    double currentBody = close[0] - open[0];
    double currentUpperWick = high[0] - MathMax(open[0], close[0]);
    double currentLowerWick = MathMin(open[0], close[0]) - low[0];
    double previousBody = close[1] - open[1];
    
    bool isBullishEngulfing = 
        currentBody > 0 &&
        previousBody < 0 &&
        open[0] < close[1] &&
        close[0] > open[1];
        
    bool isHammer = 
        currentBody > 0 &&
        currentLowerWick > currentBody * 2 &&
        currentUpperWick < currentBody * 0.5;
        
    bool isMorningStar = 
        close[2] < open[2] &&
        MathAbs(open[1] - close[1]) < avgCandleSize * 0.3 &&
        close[0] > open[0] &&
        close[0] > (open[2] + close[2]) / 2;
        
    return isBullishEngulfing || isHammer || isMorningStar;
}

//+------------------------------------------------------------------+
//| Check for Bearish Candlestick Pattern                            |
//+------------------------------------------------------------------+
bool IsBearishCandlePattern(string symbol, ENUM_TIMEFRAMES timeframe)
{
    double open[3], high[3], low[3], close[3];
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyOpen(symbol, timeframe, 0, 3, open) != 3 ||
       CopyHigh(symbol, timeframe, 0, 3, high) != 3 ||
       CopyLow(symbol, timeframe, 0, 3, low) != 3 ||
       CopyClose(symbol, timeframe, 0, 3, close) != 3)
    {
        Print("Error copying price data");
        return false;
    }
    
    double avgCandleSize = 0;
    for(int i = 0; i < 3; i++)
    {
        avgCandleSize += (high[i] - low[i]);
    }
    avgCandleSize /= 3;
    
    double currentBody = close[0] - open[0];
    double currentUpperWick = high[0] - MathMax(open[0], close[0]);
    double currentLowerWick = MathMin(open[0], close[0]) - low[0];
    double previousBody = close[1] - open[1];
    
    bool isBearishEngulfing = 
        currentBody < 0 &&
        previousBody > 0 &&
        open[0] > close[1] &&
        close[0] < open[1];
        
    bool isShootingStar = 
        currentBody < 0 &&
        currentUpperWick > MathAbs(currentBody) * 2 &&
        currentLowerWick < MathAbs(currentBody) * 0.5;
        
    bool isEveningStar = 
        close[2] > open[2] &&
        MathAbs(open[1] - close[1]) < avgCandleSize * 0.3 &&
        close[0] < open[0] &&
        close[0] < (open[2] + close[2]) / 2;
        
    return isBearishEngulfing || isShootingStar || isEveningStar;
}
