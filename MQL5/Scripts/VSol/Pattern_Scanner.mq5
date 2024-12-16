//+------------------------------------------------------------------+
//| Pattern Scanner                                                    |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.14"
#property strict

// Input parameters
input ENUM_TIMEFRAMES ScanTimeframe = PERIOD_H1;     // Timeframe to scan
input int EMA_PERIODS_SHORT = 20;                    // Short EMA period
input int EMA_PERIODS_MEDIUM = 50;                   // Medium EMA period
input int EMA_PERIODS_LONG = 200;                    // Long EMA period
input int PATTERN_LOOKBACK = 5;                      // Pattern lookback periods
input double GOLDEN_CROSS_THRESHOLD = 0.001;         // Golden cross threshold
input bool SaveToFile = true;                        // Save results to file

// Enhanced Analysis Parameters
input double ADX_THRESHOLD = 20.0;                   // ADX threshold
input double RSI_UPPER_THRESHOLD = 70.0;             // RSI upper threshold
input double RSI_LOWER_THRESHOLD = 30.0;             // RSI lower threshold
input double DI_DIFFERENCE_THRESHOLD = 2.0;          // DI difference threshold
input int RSI_Period = 14;                           // RSI period
input int MACD_Fast = 12;                           // MACD fast period
input int MACD_Slow = 26;                           // MACD slow period
input int MACD_Signal = 9;                          // MACD signal period
input double RSI_Neutral = 50.0;                    // RSI neutral level

// Volume Analysis Parameters
input double VOLUME_THRESHOLD = 1.5;                // Volume threshold multiplier
input bool USE_VOLUME_CONFIRMATION = true;          // Use volume confirmation

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

//+------------------------------------------------------------------+
//| Create unique filenames for this scan                              |
//+------------------------------------------------------------------+
struct ScanFiles {
    string txtFile;
    string csvFile;
};

ScanFiles CreateUniqueFileNames()
{
    ScanFiles files;
    string baseFileName = "PatternScan_" + TimeToString(TimeCurrent(), TIME_DATE);
    string timeStamp = "_" + TimeToString(TimeCurrent(), TIME_MINUTES);
    timeStamp = StringReplace(timeStamp, ":", "-");
    
    files.txtFile = baseFileName + timeStamp + ".txt";
    files.csvFile = baseFileName + timeStamp + ".csv";
    
    return files;
}

//+------------------------------------------------------------------+
//| Script program start function                                      |
//+------------------------------------------------------------------+
void OnStart()
{
    ScanFiles files = CreateUniqueFileNames();
    int csvHandle = INVALID_HANDLE;
    
    if(SaveToFile)
    {
        // Open TXT file for detailed logging (new file for each scan)
        logHandle = FileOpen(files.txtFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
        if(logHandle == INVALID_HANDLE)
        {
            Print("Failed to open log file");
            return;
        }
        
        // Always create a new CSV file
        csvHandle = FileOpen(files.csvFile, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON);
        if(csvHandle == INVALID_HANDLE)
        {
            Print("Failed to open CSV file");
            FileClose(logHandle);
            return;
        }
        
        // Write CSV headers
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
    }

    // Log scan start
    string scanStartTime = TimeToString(TimeCurrent());
    LogMessage("=== Pattern Scan Started at " + scanStartTime + " ===", true);
    LogMessage("Timeframe: " + EnumToString(ScanTimeframe));

    string symbols[];
    int symbolCount = GetTradeableSymbols(symbols);
    LogMessage("Found " + IntegerToString(symbolCount) + " tradeable symbols");
    
    int patternsFound = 0;
    
    // In OnStart(), add more detailed progress logging
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

    for(int i = 0; i < symbolCount; i++)
    {
        // Log progress every 10 symbols
        if(i % 5 == 0) // Every 5 symbols instead of 10
        {
            double progress = (double)i / symbolCount * 100;
            LogMessage(StringFormat("Progress: %.1f%% (%d/%d symbols)", 
                      progress, i, symbolCount), true);
        }
        
        PatternResult result = AnalyzePattern(symbols[i], ScanTimeframe);
        if(result.strength > 0)
        {
            patternsFound++;
            string message = FormatPatternResult(symbols[i], result);
            LogMessage("Pattern Found: " + symbols[i], true);
            LogMessage(message);
            
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

    // Log scan completion
    string completionMessage = StringFormat(
        "Scan completed. Analyzed %d symbols, found %d patterns.",
        symbolCount,
        patternsFound
    );
    LogMessage("=== " + completionMessage + " ===", false);
    LogMessage("Results saved to CSV: " + files.csvFile, false);

    // Close files
    if(SaveToFile)
    {
        if(logHandle != INVALID_HANDLE)
            FileClose(logHandle);
        if(csvHandle != INVALID_HANDLE)
            FileClose(csvHandle);
    }
}

//+------------------------------------------------------------------+
//| Analyze pattern for a single symbol                                |
//+------------------------------------------------------------------+
PatternResult AnalyzePattern(string symbol, ENUM_TIMEFRAMES timeframe)
{
    PatternResult result;
    result.pattern_type = "None";
    result.strength = 0;
    result.confidence = 0;
    
    // Initialize market analysis data
    MarketAnalysisData analysisData;
    MarketAnalysisParameters params;
    
    // Set parameters
    params.ema_period_short = EMA_PERIODS_SHORT;
    params.ema_period_medium = EMA_PERIODS_MEDIUM;
    params.ema_period_long = EMA_PERIODS_LONG;
    params.adx_period = 14;
    params.rsi_period = RSI_Period;
    params.trend_adx_threshold = ADX_THRESHOLD;
    params.rsi_upper_threshold = RSI_UPPER_THRESHOLD;
    params.rsi_lower_threshold = RSI_LOWER_THRESHOLD;

    // Get current market data
    if(!PopulateMarketData(symbol, timeframe, analysisData))
    {
        return result; // Return empty result if data collection fails
    }

    // Perform comprehensive analysis
    int patternSignal = IdentifyTrendPattern(analysisData, params);
    int rsiMacdSignal = AnalyzeRSIMACD(analysisData);
    bool volumeConfirmed = USE_VOLUME_CONFIRMATION ? 
        CheckVolumeConfirmation(analysisData) : true;

    // Calculate final strength and confidence
    if(patternSignal != 0 && rsiMacdSignal != 0 && volumeConfirmed)
    {
        if(patternSignal > 0 && rsiMacdSignal > 0)
        {
            result.pattern_type = "Bullish";
            result.strength = (patternSignal + rsiMacdSignal) / 2;
        }
        else if(patternSignal < 0 && rsiMacdSignal < 0)
        {
            result.pattern_type = "Bearish";
            result.strength = MathAbs((patternSignal + rsiMacdSignal) / 2);
        }

        result.confidence = CalculateConfidence(result.strength, volumeConfirmed);
        result.volume_confirmed = volumeConfirmed;
        result.rsi_value = analysisData.rsi;
        result.macd_value = analysisData.macdMain;
        result.adx_value = analysisData.adx;
        
        // Add detailed analysis
        result.details = GenerateAnalysisDetails(analysisData, params);
    }

    // Add new field assignments
    result.currentPrice = analysisData.currentPrice;
    result.ema_short = analysisData.ema_short;
    result.ema_medium = analysisData.ema_medium;
    result.ema_long = analysisData.ema_long;
    result.volume = analysisData.volume;
    result.avgVolume = analysisData.avgVolume;
    
    return result;
}

//+------------------------------------------------------------------+
//| Populate Market Data                                               |
//+------------------------------------------------------------------+
bool PopulateMarketData(string symbol, ENUM_TIMEFRAMES timeframe, MarketAnalysisData &data)
{
    data.currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    data.ema_short = CalculateEMA(symbol, timeframe, EMA_PERIODS_SHORT);
    data.ema_medium = CalculateEMA(symbol, timeframe, EMA_PERIODS_MEDIUM);
    data.ema_long = CalculateEMA(symbol, timeframe, EMA_PERIODS_LONG);
    
    // Calculate ADX
    CalculateADX(symbol, timeframe, 14, data.adx, data.plusDI, data.minusDI);
    
    // Calculate RSI
    data.rsi = CalculateRSI(symbol, timeframe, RSI_Period);
    
    // Calculate MACD
    CalculateMACD(symbol, timeframe, data.macdMain, data.macdSignal, data.macdHistogram);
    
    // Calculate ATR
    data.atr = CalculateATR(symbol, timeframe, 14);
    
    // Calculate Volume metrics
    data.volume = iVolume(symbol, timeframe, 0);
    data.avgVolume = CalculateAverageVolume(symbol, timeframe, 20);
    
    // Check for patterns
    data.bullishPattern = IsBullishCandlePattern(symbol, timeframe);
    data.bearishPattern = IsBearishCandlePattern(symbol, timeframe);
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Confidence Score                                         |
//+------------------------------------------------------------------+
double CalculateConfidence(int strength, bool volumeConfirmed)
{
    double confidence = strength * 10.0; // Base confidence from strength
    
    if(volumeConfirmed)
        confidence *= 1.2; // 20% boost for volume confirmation
        
    // Normalize to 0-100 range
    confidence = MathMin(confidence, 100.0);
    confidence = MathMax(confidence, 0.0);
    
    return NormalizeDouble(confidence, 2);
}

//+------------------------------------------------------------------+
//| Identify Trend Pattern                                             |
//+------------------------------------------------------------------+
int IdentifyTrendPattern(MarketAnalysisData &data, MarketAnalysisParameters &params)
{
    struct TrendScore {
        double bullish;
        double bearish;
        string reasons[];
    } score;
    score.bullish = 0;
    score.bearish = 0;
    
    // 1. EMA Alignment Analysis
    if(data.ema_short > data.ema_medium && data.ema_medium > data.ema_long) {
        score.bullish += 2.5;
        ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
        score.reasons[ArraySize(score.reasons)-1] = "Bullish EMA alignment";
    }
    else if(data.ema_short < data.ema_medium && data.ema_medium < data.ema_long) {
        score.bearish += 2.5;
        ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
        score.reasons[ArraySize(score.reasons)-1] = "Bearish EMA alignment";
    }

    // 2. Cross Detection
    double cross_strength = MathAbs(data.ema_short - data.ema_long) / _Point;
    if(cross_strength > GOLDEN_CROSS_THRESHOLD) {
        if(data.ema_short > data.ema_long) {
            score.bullish += 3.0 * (cross_strength / GOLDEN_CROSS_THRESHOLD);
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Golden Cross";
        }
        else {
            score.bearish += 3.0 * (cross_strength / GOLDEN_CROSS_THRESHOLD);
            ArrayResize(score.reasons, ArraySize(score.reasons) + 1);
            score.reasons[ArraySize(score.reasons)-1] = "Death Cross";
        }
    }

    // 3. Volume Analysis
    if(data.volume > data.avgVolume * VOLUME_THRESHOLD) {
        if(score.bullish > score.bearish)
            score.bullish += 1.5;
        else if(score.bearish > score.bullish)
            score.bearish += 1.5;
    }

    // 4. Additional Technical Indicators
    if(data.adx > ADX_THRESHOLD) {
        if(data.plusDI > data.minusDI)
            score.bullish += 1.5;
        else
            score.bearish += 1.5;
    }

    // Final Decision Making
    const double MIN_SCORE_THRESHOLD = 5.0;
    const double SCORE_DIFFERENCE_THRESHOLD = 2.0;
    
    if(score.bullish >= MIN_SCORE_THRESHOLD && 
       score.bullish - score.bearish >= SCORE_DIFFERENCE_THRESHOLD)
        return (int)MathRound(score.bullish);
    else if(score.bearish >= MIN_SCORE_THRESHOLD && 
            score.bearish - score.bullish >= SCORE_DIFFERENCE_THRESHOLD)
        return -(int)MathRound(score.bearish);
    
    return 0;
}

//+------------------------------------------------------------------+
//| Analyze RSI and MACD Combination                                   |
//+------------------------------------------------------------------+
int AnalyzeRSIMACD(MarketAnalysisData &data)
{
    // RSI Trend Analysis
    bool rsiOversold = data.rsi < RSI_LOWER_THRESHOLD;
    bool rsiOverbought = data.rsi > RSI_UPPER_THRESHOLD;
    bool rsiTrendUp = data.rsi > RSI_Neutral && data.rsi < RSI_UPPER_THRESHOLD;
    bool rsiTrendDown = data.rsi < RSI_Neutral && data.rsi > RSI_LOWER_THRESHOLD;
    
    // MACD Signal Analysis
    bool macdBullish = data.macdMain > data.macdSignal && data.macdHistogram > 0;
    bool macdBearish = data.macdMain < data.macdSignal && data.macdHistogram < 0;
    
    // Combined Signal Analysis
    if((rsiOversold || rsiTrendUp) && macdBullish)
    {
        return 1;  // Bullish signal
    }
    else if((rsiOverbought || rsiTrendDown) && macdBearish)
    {
        return -1; // Bearish signal
    }
    
    return 0;  // No clear signal
}

//+------------------------------------------------------------------+
//| Check Volume Confirmation                                          |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation(MarketAnalysisData &data)
{
    if(!USE_VOLUME_CONFIRMATION)
        return true;
        
    return (data.volume > data.avgVolume * VOLUME_THRESHOLD);
}

//+------------------------------------------------------------------+
//| Generate Analysis Details                                          |
//+------------------------------------------------------------------+
string GenerateAnalysisDetails(MarketAnalysisData &data, MarketAnalysisParameters &params)
{
    string details = "";
    
    // Add EMA Analysis
    details += "EMA Analysis:\n";
    details += "Short(" + IntegerToString(params.ema_period_short) + "): " + DoubleToString(data.ema_short, 5) + "\n";
    details += "Medium(" + IntegerToString(params.ema_period_medium) + "): " + DoubleToString(data.ema_medium, 5) + "\n";
    details += "Long(" + IntegerToString(params.ema_period_long) + "): " + DoubleToString(data.ema_long, 5) + "\n\n";
    
    // Add Indicator Analysis
    details += "Indicators:\n";
    details += "ADX: " + DoubleToString(data.adx, 2) + "\n";
    details += "DI+: " + DoubleToString(data.plusDI, 2) + "\n";
    details += "DI-: " + DoubleToString(data.minusDI, 2) + "\n";
    details += "RSI: " + DoubleToString(data.rsi, 2) + "\n";
    details += "MACD: " + DoubleToString(data.macdMain, 5) + "\n";
    details += "Signal: " + DoubleToString(data.macdSignal, 5) + "\n";
    details += "Histogram: " + DoubleToString(data.macdHistogram, 5) + "\n\n";
    
    // Add Volume Analysis
    details += "Volume Analysis:\n";
    details += "Current Volume: " + DoubleToString(data.volume, 2) + "\n";
    details += "Average Volume: " + DoubleToString(data.avgVolume, 2) + "\n";
    details += "Volume Ratio: " + DoubleToString(data.volume/data.avgVolume, 2) + "\n";
    
    return details;
}

//+------------------------------------------------------------------+
//| Calculate Average Volume                                           |
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
//| Calculate EMA                                                      |
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
//| Calculate ADX                                                      |
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
//| Calculate RSI                                                      |
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
//| Calculate MACD                                                     |
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
//| Calculate ATR                                                      |
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
//| Get Tradeable Symbols                                             |
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
//| Log Message with Timestamp                                         |
//+------------------------------------------------------------------+
void LogMessage(string message, bool showInTerminal = false)
{
    if(SaveToFile && logHandle != INVALID_HANDLE)
    {
        string timestampedMessage = TimeToString(TimeCurrent()) + ": " + message;
        FileWriteString(logHandle, timestampedMessage + "\n");
        FileFlush(logHandle);
    }
}

//+------------------------------------------------------------------+
//| Format Pattern Result                                             |
//+------------------------------------------------------------------+
string FormatPatternResult(string symbol, PatternResult &result)
{
    return StringFormat(
        "%s: %s pattern (Strength: %d, Conf: %.1f%%, Vol: %s)",
        symbol,
        result.pattern_type,
        result.strength,
        result.confidence,
        result.volume_confirmed ? "Yes" : "No"
    );
}

//+------------------------------------------------------------------+
//| Check for Bullish Candlestick Pattern                             |
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
    
    // Calculate average candle size for reference
    double avgCandleSize = 0;
    for(int i = 0; i < 3; i++)
    {
        avgCandleSize += (high[i] - low[i]);
    }
    avgCandleSize /= 3;
    
    // Current candle properties
    double currentBody = close[0] - open[0];
    double currentUpperWick = high[0] - MathMax(open[0], close[0]);
    double currentLowerWick = MathMin(open[0], close[0]) - low[0];
    
    // Previous candle properties
    double previousBody = close[1] - open[1];
    
    // Check for bullish engulfing
    bool isBullishEngulfing = 
        currentBody > 0 &&  // Current candle is bullish
        previousBody < 0 && // Previous candle is bearish
        open[0] < close[1] && // Opens below previous close
        close[0] > open[1];   // Closes above previous open
        
    // Check for hammer
    bool isHammer = 
        currentBody > 0 && // Bullish candle
        currentLowerWick > currentBody * 2 && // Long lower wick
        currentUpperWick < currentBody * 0.5; // Short upper wick
        
    // Check for morning star
    bool isMorningStar = 
        close[2] < open[2] && // First candle bearish
        MathAbs(open[1] - close[1]) < avgCandleSize * 0.3 && // Doji
        close[0] > open[0] && // Current candle bullish
        close[0] > (open[2] + close[2]) / 2; // Closes above midpoint of first candle
        
    return isBullishEngulfing || isHammer || isMorningStar;
}

//+------------------------------------------------------------------+
//| Check for Bearish Candlestick Pattern                             |
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
    
    // Calculate average candle size for reference
    double avgCandleSize = 0;
    for(int i = 0; i < 3; i++)
    {
        avgCandleSize += (high[i] - low[i]);
    }
    avgCandleSize /= 3;
    
    // Current candle properties
    double currentBody = close[0] - open[0];
    double currentUpperWick = high[0] - MathMax(open[0], close[0]);
    double currentLowerWick = MathMin(open[0], close[0]) - low[0];
    
    // Previous candle properties
    double previousBody = close[1] - open[1];
    
    // Check for bearish engulfing
    bool isBearishEngulfing = 
        currentBody < 0 &&  // Current candle is bearish
        previousBody > 0 && // Previous candle is bullish
        open[0] > close[1] && // Opens above previous close
        close[0] < open[1];   // Closes below previous open
        
    // Check for shooting star
    bool isShootingStar = 
        currentBody < 0 && // Bearish candle
        currentUpperWick > MathAbs(currentBody) * 2 && // Long upper wick
        currentLowerWick < MathAbs(currentBody) * 0.5; // Short lower wick
        
    // Check for evening star
    bool isEveningStar = 
        close[2] > open[2] && // First candle bullish
        MathAbs(open[1] - close[1]) < avgCandleSize * 0.3 && // Doji
        close[0] < open[0] && // Current candle bearish
        close[0] < (open[2] + close[2]) / 2; // Closes below midpoint of first candle
        
    return isBearishEngulfing || isShootingStar || isEveningStar;
}