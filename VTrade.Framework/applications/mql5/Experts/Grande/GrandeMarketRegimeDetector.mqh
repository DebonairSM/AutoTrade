//+------------------------------------------------------------------+
//| GrandeMarketRegimeDetector.mqh                                   |
//| Copyright 2024, Grande Tech                                      |
//| Market Regime Detection Module - Foundation for Trading System   |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor event handlers and indicator patterns

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Advanced market regime detection system for intelligent trading"

//+------------------------------------------------------------------+
//| Market Regime Enumeration                                        |
//+------------------------------------------------------------------+
enum MARKET_REGIME
{
    REGIME_TREND_BULL,      // Strong bullish trend
    REGIME_TREND_BEAR,      // Strong bearish trend  
    REGIME_BREAKOUT_SETUP,  // Breakout potential detected
    REGIME_RANGING,         // Sideways/ranging market
    REGIME_HIGH_VOLATILITY  // High volatility period
};

//+------------------------------------------------------------------+
//| Regime Snapshot Structure                                        |
//+------------------------------------------------------------------+
struct RegimeSnapshot
{
    MARKET_REGIME   regime;         // Current detected regime
    double          confidence;     // Confidence level 0.0-1.0
    datetime        timestamp;      // Detection timestamp
    double          adx_h1;         // ADX value on H1
    double          adx_h4;         // ADX value on H4
    double          adx_d1;         // ADX value on D1
    double          atr_current;    // Current ATR
    double          atr_avg;        // Average ATR (90-day)
    double          plus_di;        // +DI value
    double          minus_di;       // -DI value
};

//+------------------------------------------------------------------+
//| Market Regime Detection Configuration                            |
//+------------------------------------------------------------------+
struct RegimeConfig
{
    // ADX Thresholds
    double          adx_trend_threshold;        // ADX >= 25 for trending
    double          adx_breakout_min;          // ADX 20-25 for breakout setup
    double          adx_ranging_threshold;     // ADX < 20 for ranging
    
    // ATR Volatility Settings
    int             atr_period;                // ATR calculation period (14)
    int             atr_avg_period;           // ATR average period (90)
    double          high_vol_multiplier;      // 2x for high volatility
    
    // Timeframe Settings
    ENUM_TIMEFRAMES tf_primary;              // H1 primary
    ENUM_TIMEFRAMES tf_secondary;            // H4 secondary  
    ENUM_TIMEFRAMES tf_tertiary;             // D1 tertiary
    
    // Constructor with defaults
    RegimeConfig()
    {
        adx_trend_threshold = 25.0;
        adx_breakout_min = 20.0;
        adx_ranging_threshold = 20.0;
        atr_period = 14;
        atr_avg_period = 90;
        high_vol_multiplier = 2.0;
        tf_primary = PERIOD_H1;
        tf_secondary = PERIOD_H4;
        tf_tertiary = PERIOD_D1;
    }
};

//+------------------------------------------------------------------+
//| Grande Market Regime Detector Class                             |
//+------------------------------------------------------------------+
class CGrandeMarketRegimeDetector
{
private:
    // Configuration
    RegimeConfig        m_config;
    string              m_symbol;
    bool                m_initialized;
    
    // Current regime state
    RegimeSnapshot      m_lastSnapshot;
    datetime            m_lastUpdate;
    
    // Indicator handles
    int                 m_adx_h1_handle;
    int                 m_adx_h4_handle;
    int                 m_adx_d1_handle;
    int                 m_atr_handle;
    
    // ATR Handle Management
    bool                EnsureATRHandle(int maxRetries, int delayMs);
    
    // Internal buffers
    double              m_adx_buffer[];
    double              m_plus_di_buffer[];
    double              m_minus_di_buffer[];
    double              m_atr_buffer[];
    
public:
    //+------------------------------------------------------------------+
    //| Constructor and Destructor                                       |
    //+------------------------------------------------------------------+
    CGrandeMarketRegimeDetector(void) : m_initialized(false),
                                        m_lastUpdate(0),
                                        m_adx_h1_handle(INVALID_HANDLE),
                                        m_adx_h4_handle(INVALID_HANDLE),
                                        m_adx_d1_handle(INVALID_HANDLE),
                                        m_atr_handle(INVALID_HANDLE)
    {
        ArraySetAsSeries(m_adx_buffer, true);
        ArraySetAsSeries(m_plus_di_buffer, true);
        ArraySetAsSeries(m_minus_di_buffer, true);
        ArraySetAsSeries(m_atr_buffer, true);
        
        // Initialize last snapshot
        m_lastSnapshot.regime = REGIME_RANGING;
        m_lastSnapshot.confidence = 0.0;
        m_lastSnapshot.timestamp = 0;
    }
    
    ~CGrandeMarketRegimeDetector(void)
    {
        // Release indicator handles
        if(m_adx_h1_handle != INVALID_HANDLE)
            IndicatorRelease(m_adx_h1_handle);
        if(m_adx_h4_handle != INVALID_HANDLE)
            IndicatorRelease(m_adx_h4_handle);
        if(m_adx_d1_handle != INVALID_HANDLE)
            IndicatorRelease(m_adx_d1_handle);
        if(m_atr_handle != INVALID_HANDLE)
            IndicatorRelease(m_atr_handle);
    }
    
    //+------------------------------------------------------------------+
    //| Initialization Method                                            |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, const RegimeConfig &config, bool debugMode = false)
    {
        m_symbol = symbol;
        m_config = config;
        
        // Create ADX indicators for the CURRENT timeframe and multi-timeframe analysis
        ENUM_TIMEFRAMES currentTF = Period();
        
        // Primary timeframe (current chart timeframe)
        m_adx_h1_handle = iADX(m_symbol, currentTF, 14);
        
        // Secondary timeframes for multi-timeframe analysis
        m_adx_h4_handle = iADX(m_symbol, PERIOD_H4, 14);
        m_adx_d1_handle = iADX(m_symbol, PERIOD_D1, 14);
        
        // Create ATR indicator for current timeframe
        m_atr_handle = iATR(m_symbol, currentTF, m_config.atr_period);
        
        // Check if all indicators were created successfully
        if(m_adx_h1_handle == INVALID_HANDLE ||
           m_adx_h4_handle == INVALID_HANDLE ||
           m_adx_d1_handle == INVALID_HANDLE ||
           m_atr_handle == INVALID_HANDLE)
        {
            Print("[Grande] ERROR: Failed to create indicators for regime detection");
            return false;
        }
        
        // Pattern from: MQL5 Official Documentation
        // Reference: Proper indicator initialization and readiness validation
        
        // Ensure ATR buffer is properly sized
        ArrayResize(m_atr_buffer, 100);
        ArraySetAsSeries(m_atr_buffer, true);
        
        // Wait for all indicators to be ready with proper validation
        int attempts = 0;
        const int maxAttempts = 100;
        
        while(attempts < maxAttempts)
        {
            bool allReady = true;
            
            // Check if all indicators have calculated data
            if(BarsCalculated(m_adx_h1_handle) <= 0) allReady = false;
            if(BarsCalculated(m_adx_h4_handle) <= 0) allReady = false;
            if(BarsCalculated(m_adx_d1_handle) <= 0) allReady = false;
            if(BarsCalculated(m_atr_handle) <= 0) allReady = false;
            
            if(allReady)
            {
                // Test ATR buffer copying to ensure it works
                ResetLastError();
                if(CopyBuffer(m_atr_handle, 0, 0, 1, m_atr_buffer) > 0 && GetLastError() == 0)
                {
                    break; // All indicators ready and working
                }
            }
            
            attempts++;
            Sleep(50);
        }
        
        if(attempts >= maxAttempts)
        {
            Print("[Grande] WARNING: Some indicators may not be fully ready after initialization");
        }
        
        m_initialized = true;
        
        // Only show success message in debug mode
        if(debugMode)
        {
            Print("[Grande] Market Regime Detector initialized successfully for ", m_symbol);
            Print("[Grande] ADX H1 calculated: ", BarsCalculated(m_adx_h1_handle));
            Print("[Grande] ADX H4 calculated: ", BarsCalculated(m_adx_h4_handle));
            Print("[Grande] ADX D1 calculated: ", BarsCalculated(m_adx_d1_handle));
            Print("[Grande] ATR calculated: ", BarsCalculated(m_atr_handle));
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Main Detection Methods                                           |
    //+------------------------------------------------------------------+
    RegimeSnapshot DetectCurrentRegime()
    {
        if(!m_initialized)
        {
            Print("[Grande] ERROR: Regime detector not initialized");
            return m_lastSnapshot;
        }
        
        // Get current market data using current timeframe for primary analysis
        ENUM_TIMEFRAMES currentTF = Period();
        double adx_current = GetADXValue(currentTF);
        double adx_h4 = GetADXValue(PERIOD_H4);
        double adx_d1 = GetADXValue(PERIOD_D1);
        
        double plus_di = GetPlusDI(currentTF);
        double minus_di = GetMinusDI(currentTF);
        
        double atr_current = GetATRValue();
        double atr_avg = GetATRAverage();
        
        // Create new snapshot
        RegimeSnapshot snapshot;
        snapshot.timestamp = TimeCurrent();
        snapshot.adx_h1 = adx_current;  // Store current timeframe ADX in h1 field
        snapshot.adx_h4 = adx_h4;
        snapshot.adx_d1 = adx_d1;
        snapshot.atr_current = atr_current;
        snapshot.atr_avg = atr_avg;
        snapshot.plus_di = plus_di;
        snapshot.minus_di = minus_di;
        
        // Determine regime
        snapshot.regime = DetermineRegime(snapshot);
        snapshot.confidence = CalculateConfidence(snapshot);
        
        m_lastSnapshot = snapshot;
        m_lastUpdate = TimeCurrent();
        
        return snapshot;
    }
    
    void UpdateRegime()
    {
        // Lightweight update - just refresh the detection
        DetectCurrentRegime();
    }
    
    //+------------------------------------------------------------------+
    //| Public Access Methods                                            |
    //+------------------------------------------------------------------+
    RegimeSnapshot GetLastSnapshot() const { return m_lastSnapshot; }
    
    bool IsTrending() const
    {
        return (m_lastSnapshot.regime == REGIME_TREND_BULL || 
                m_lastSnapshot.regime == REGIME_TREND_BEAR);
    }
    
    bool IsTrendingBull() const
    {
        return m_lastSnapshot.regime == REGIME_TREND_BULL;
    }
    
    bool IsTrendingBear() const
    {
        return m_lastSnapshot.regime == REGIME_TREND_BEAR;
    }
    
    bool IsRanging() const
    {
        return m_lastSnapshot.regime == REGIME_RANGING;
    }
    
    bool IsBreakoutSetup() const
    {
        return m_lastSnapshot.regime == REGIME_BREAKOUT_SETUP;
    }
    
    bool IsHighVolatility() const
    {
        return m_lastSnapshot.regime == REGIME_HIGH_VOLATILITY;
    }
    
    string RegimeToString(MARKET_REGIME regime) const
    {
        switch(regime)
        {
            case REGIME_TREND_BULL:      return " BULL TREND ";
            case REGIME_TREND_BEAR:      return " BEAR TREND ";
            case REGIME_BREAKOUT_SETUP:  return " BREAKOUT SETUP ";
            case REGIME_RANGING:         return " RANGING ";
            case REGIME_HIGH_VOLATILITY: return " HIGH VOLATILITY ";
            default:                     return " UNKNOWN ";
        }
    }
    
private:
    //+------------------------------------------------------------------+
    //| Private Helper Methods                                           |
    //+------------------------------------------------------------------+
    double GetADXValue(ENUM_TIMEFRAMES timeframe)
    {
        int handle = INVALID_HANDLE;
        
        // Use current chart timeframe for primary analysis
        if(timeframe == Period())
            handle = m_adx_h1_handle;
        else if(timeframe == PERIOD_H4)
            handle = m_adx_h4_handle;
        else if(timeframe == PERIOD_D1)
            handle = m_adx_d1_handle;
        else
            handle = m_adx_h1_handle; // Fallback to current timeframe handle
        
        if(handle == INVALID_HANDLE) return 0.0;
        
        if(CopyBuffer(handle, 0, 0, 1, m_adx_buffer) <= 0)
            return 0.0;
            
        return m_adx_buffer[0];
    }
    
    double GetPlusDI(ENUM_TIMEFRAMES timeframe)
    {
        int handle = INVALID_HANDLE;
        
        // Use current chart timeframe for primary analysis
        if(timeframe == Period())
            handle = m_adx_h1_handle;
        else if(timeframe == PERIOD_H4)
            handle = m_adx_h4_handle;
        else if(timeframe == PERIOD_D1)
            handle = m_adx_d1_handle;
        else
            handle = m_adx_h1_handle; // Fallback to current timeframe handle
            
        if(handle == INVALID_HANDLE) return 0.0;
        
        if(CopyBuffer(handle, 1, 0, 1, m_plus_di_buffer) <= 0)
            return 0.0;
            
        return m_plus_di_buffer[0];
    }
    
    double GetMinusDI(ENUM_TIMEFRAMES timeframe)
    {
        int handle = INVALID_HANDLE;
        
        // Use current chart timeframe for primary analysis
        if(timeframe == Period())
            handle = m_adx_h1_handle;
        else if(timeframe == PERIOD_H4)
            handle = m_adx_h4_handle;
        else if(timeframe == PERIOD_D1)
            handle = m_adx_d1_handle;
        else
            handle = m_adx_h1_handle; // Fallback to current timeframe handle
            
        if(handle == INVALID_HANDLE) return 0.0;
        
        if(CopyBuffer(handle, 2, 0, 1, m_minus_di_buffer) <= 0)
            return 0.0;
            
        return m_minus_di_buffer[0];
    }
    
    double GetATRValue()
    {
        // Pattern from: MetaQuotes Official Documentation
        // Reference: Ensure handle is ready before using CopyBuffer
        
        if(!EnsureATRHandle(5, 100))
        {
            Print("[GrandeRegime] ATR handle not available");
            return 0.0;
        }
        
        // Now the handle is guaranteed to be ready, safe to call CopyBuffer
        ResetLastError();
        int copied = CopyBuffer(m_atr_handle, 0, 0, 1, m_atr_buffer);
        int error = GetLastError();
        
        if(copied <= 0 || error != 0)
        {
            Print("[GrandeRegime] Failed to copy ATR buffer. Error: ", error, ", Copied: ", copied);
            return 0.0;
        }
            
        return m_atr_buffer[0];
    }
    
    double GetATRAverage()
    {
        // Pattern from: MetaQuotes Official Documentation
        // Reference: Ensure handle is ready before using CopyBuffer
        
        if(!EnsureATRHandle(5, 100))
        {
            Print("[GrandeRegime] ATR handle not available for average calculation");
            return 0.0;
        }
        
        // Check if we have enough calculated bars
        int calculated = BarsCalculated(m_atr_handle);
        if(calculated < m_config.atr_avg_period)
        {
            Print("[GrandeRegime] Insufficient ATR data. Calculated: ", calculated, ", Required: ", m_config.atr_avg_period);
            return 0.0;
        }
        
        double atr_values[];
        ArrayResize(atr_values, m_config.atr_avg_period);
        ArraySetAsSeries(atr_values, true);
        
        ResetLastError();
        int copied = CopyBuffer(m_atr_handle, 0, 0, m_config.atr_avg_period, atr_values);
        int error = GetLastError();
        
        if(copied < m_config.atr_avg_period || error != 0)
        {
            Print("[GrandeRegime] Failed to copy ATR average data. Error: ", error, ", Copied: ", copied, ", Required: ", m_config.atr_avg_period);
            return 0.0;
        }
        
        double sum = 0.0;
        for(int i = 0; i < m_config.atr_avg_period; i++)
        {
            sum += atr_values[i];
        }
        
        return sum / m_config.atr_avg_period;
    }
    
    MARKET_REGIME DetermineRegime(const RegimeSnapshot &snapshot)
    {
        // High volatility check first
        if(snapshot.atr_avg > 0 && 
           snapshot.atr_current >= snapshot.atr_avg * m_config.high_vol_multiplier)
        {
            return REGIME_HIGH_VOLATILITY;
        }
        
        // Get current timeframe for threshold adjustment
        ENUM_TIMEFRAMES currentTF = Period();
        double adx_threshold = m_config.adx_trend_threshold;
        double breakout_min = m_config.adx_breakout_min;
        
        // Adjust thresholds based on timeframe (longer timeframes need higher thresholds)
        switch(currentTF)
        {
            case PERIOD_MN1: 
                adx_threshold = 30.0; 
                breakout_min = 25.0; 
                break;
            case PERIOD_W1:  
                adx_threshold = 28.0; 
                breakout_min = 23.0; 
                break;
            case PERIOD_D1:  
                adx_threshold = 26.0; 
                breakout_min = 21.0; 
                break;
            case PERIOD_H4:  
                adx_threshold = 25.0; 
                breakout_min = 20.0; 
                break;
            case PERIOD_H1:  
                adx_threshold = 25.0; 
                breakout_min = 20.0; 
                break;
            case PERIOD_M30: 
                adx_threshold = 24.0; 
                breakout_min = 19.0; 
                break;
            case PERIOD_M15: 
                adx_threshold = 23.0; 
                breakout_min = 18.0; 
                break;
            case PERIOD_M5:  
                adx_threshold = 22.0; 
                breakout_min = 17.0; 
                break;
            case PERIOD_M1:  
                adx_threshold = 21.0; 
                breakout_min = 16.0; 
                break;
            default:         
                adx_threshold = 25.0; 
                breakout_min = 20.0; 
                break;
        }
        
        // Trending regime detection using current timeframe ADX
        if(snapshot.adx_h1 >= adx_threshold)
        {
            // Determine trend direction
            if(snapshot.plus_di > snapshot.minus_di)
                return REGIME_TREND_BULL;
            else
                return REGIME_TREND_BEAR;
        }
        
        // Breakout setup detection
        if(snapshot.adx_h1 >= breakout_min && 
           snapshot.adx_h1 < adx_threshold)
        {
            return REGIME_BREAKOUT_SETUP;
        }
        
        // Default to ranging
        return REGIME_RANGING;
    }
    
    double CalculateConfidence(const RegimeSnapshot &snapshot)
    {
        double confidence = 0.5; // Base confidence
        
        // Get current timeframe for confidence adjustment
        ENUM_TIMEFRAMES currentTF = Period();
        
        // ADX strength contributes to confidence (use current timeframe ADX)
        double adx_strength = snapshot.adx_h1 / 50.0; // Normalize to 0-1
        adx_strength = MathMin(adx_strength, 1.0);
        
        // Multi-timeframe confirmation (adjusted for current timeframe)
        double tf_alignment = 0.0;
        
        // For longer timeframes, give more weight to multi-timeframe alignment
        if(currentTF >= PERIOD_D1)
        {
            if(snapshot.adx_h1 > 20 && snapshot.adx_h4 > 20)
                tf_alignment += 0.20;
            if(snapshot.adx_h4 > 20 && snapshot.adx_d1 > 20)
                tf_alignment += 0.20;
        }
        else
        {
            if(snapshot.adx_h1 > 20 && snapshot.adx_h4 > 20)
                tf_alignment += 0.15;
            if(snapshot.adx_h4 > 20 && snapshot.adx_d1 > 20)
                tf_alignment += 0.15;
        }
        
        // DI separation for trending confidence
        double di_separation = 0.0;
        if(snapshot.regime == REGIME_TREND_BULL || snapshot.regime == REGIME_TREND_BEAR)
        {
            di_separation = MathAbs(snapshot.plus_di - snapshot.minus_di) / 50.0;
            di_separation = MathMin(di_separation, 0.2);
        }
        
        // Timeframe-specific confidence boost
        double tf_boost = 0.0;
        switch(currentTF)
        {
            case PERIOD_MN1: tf_boost = 0.05; break; // Longer timeframes get slight boost
            case PERIOD_W1:  tf_boost = 0.03; break;
            case PERIOD_D1:  tf_boost = 0.02; break;
            case PERIOD_H4:  tf_boost = 0.01; break;
            case PERIOD_H1:  tf_boost = 0.00; break;
            case PERIOD_M30: tf_boost = -0.01; break; // Shorter timeframes get slight penalty
            case PERIOD_M15: tf_boost = -0.02; break;
            case PERIOD_M5:  tf_boost = -0.03; break;
            case PERIOD_M1:  tf_boost = -0.05; break;
            default:         tf_boost = 0.00; break;
        }
        
        confidence = 0.4 + (adx_strength * 0.4) + tf_alignment + di_separation + tf_boost;
        
        return MathMin(MathMax(confidence, 0.0), 1.0);
    }
    
}; 

//+------------------------------------------------------------------+
//| Ensure ATR Handle is Ready (MetaQuotes Pattern)                 |
//+------------------------------------------------------------------+
bool CGrandeMarketRegimeDetector::EnsureATRHandle(int maxRetries, int delayMs)
{
    // Pattern from: MetaQuotes Official Documentation
    // Reference: Proper indicator handle creation and validation
    
    // If no handle yet, or BarsCalculated shows it's invalid, create a new one
    if(m_atr_handle == INVALID_HANDLE || BarsCalculated(m_atr_handle) <= 0)
    {
        // Release any existing handle
        if(m_atr_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_atr_handle);
            m_atr_handle = INVALID_HANDLE;
        }
        
        // Validate symbol
        if(!SymbolSelect(m_symbol, true))
        {
            Print("[GrandeRegime] ERROR: Symbol not available: ", m_symbol);
            return false;
        }
        
        // Create new ATR handle
        ResetLastError();
        m_atr_handle = iATR(m_symbol, Period(), m_config.atr_period);
        int error = GetLastError();
        
        if(m_atr_handle == INVALID_HANDLE)
        {
            Print("[GrandeRegime] ERROR: Failed to create ATR handle. Error: ", error, ", Symbol: ", m_symbol);
            return false;
        }
        
        // Wait until the indicator has calculated bars
        for(int i = 0; i < maxRetries; i++)
        {
            int bars = BarsCalculated(m_atr_handle);
            if(bars > 0)
            {
                ArraySetAsSeries(m_atr_buffer, true);
                Print("[GrandeRegime] ATR handle ready. Calculated bars: ", bars, ", Symbol: ", m_symbol);
                return true;
            }
            
            Print("[GrandeRegime] Waiting for ATR to calculate. Attempt ", (i+1), "/", maxRetries, ", Bars: ", bars);
            Sleep(delayMs);
        }
        
        // Still not ready; release and mark invalid
        Print("[GrandeRegime] ERROR: ATR handle invalid after ", maxRetries, " retries. Symbol: ", m_symbol);
        IndicatorRelease(m_atr_handle);
        m_atr_handle = INVALID_HANDLE;
        return false;
    }
    
    return true; // Handle already exists and is valid
}