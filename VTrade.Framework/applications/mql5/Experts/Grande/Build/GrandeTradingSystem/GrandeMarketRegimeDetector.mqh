//+------------------------------------------------------------------+
//| GrandeMarketRegimeDetector.mqh                                   |
//| Copyright 2024, Grande Tech                                      |
//| Market Regime Detection Module - Foundation for Trading System   |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor event handlers and indicator patterns
//
// PURPOSE:
//   Detect and classify current market regime to guide trading decisions.
//   Provides multi-timeframe regime analysis using ADX and ATR indicators.
//
// RESPONSIBILITIES:
//   - Detect market regime (trending, ranging, breakout, high volatility)
//   - Calculate regime confidence level
//   - Monitor ADX across multiple timeframes (H1, H4, D1)
//   - Monitor ATR for volatility analysis
//   - Provide regime classification queries
//
// DEPENDENCIES:
//   - None (standalone component)
//   - Uses MT5 built-in indicators: iADX, iATR
//
// STATE MANAGED:
//   - Current regime snapshot (RegimeSnapshot structure)
//   - ADX indicator handles for multiple timeframes
//   - ATR indicator handle
//   - Last update timestamp
//   - Internal indicator buffers
//
// PUBLIC INTERFACE:
//   bool Initialize(string symbol, RegimeConfig config, bool debug)
//   RegimeSnapshot DetectCurrentRegime() - Main analysis method
//   void UpdateRegime() - Lightweight update
//   RegimeSnapshot GetLastSnapshot() - Get cached result
//   bool IsTrending(), IsTrendingBull(), IsTrendingBear() - Regime queries
//   bool IsRanging(), IsBreakoutSetup(), IsHighVolatility() - More queries
//   string RegimeToString(MARKET_REGIME) - Convert regime to string
//
// IMPLEMENTATION NOTES:
//   - Uses adaptive thresholds based on timeframe
//   - Implements fallback ATR calculation if indicator fails
//   - Handles indicator initialization delays gracefully
//   - Logs throttled to prevent spam (error 4806 expected during startup)
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestRegimeDetection.mqh
//+------------------------------------------------------------------+

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
    ENUM_TIMEFRAMES     m_atr_timeframe;
    ulong               m_lastAtrWaitLogTick;
    bool                m_atr_ready_logged;
    bool                m_atr_wait_logged;
    ulong               m_lastAtrEnsureTick;
    ulong               m_lastAtrErrorTick;
    
    // ATR Handle Management
    bool                EnsureATRHandle(int maxRetries, int delayMs);
    bool                EnsureHistoryReady(ENUM_TIMEFRAMES timeframe, int minBars, int retries, int delayMs);
    bool                TryComputeATRSimple(int period, double &outAtr);
    bool                TryComputeTRAverage(int barsCount, double &outAvgTR);
    
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
                                        m_atr_handle(INVALID_HANDLE),
                                        m_atr_timeframe(PERIOD_CURRENT),
                                        m_lastAtrWaitLogTick(0),
                                        m_atr_ready_logged(false)
                                        ,m_atr_wait_logged(false)
                                        ,m_lastAtrEnsureTick(0)
                                        ,m_lastAtrErrorTick(0)
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
        m_atr_timeframe = currentTF;
        m_atr_handle = iATR(m_symbol, currentTF, m_config.atr_period);
        m_atr_ready_logged = false;
        m_atr_wait_logged = false;
        
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
    
    //+------------------------------------------------------------------+
    //| Phase 2: Regime-Aware Limit Order Validation                     |
    //+------------------------------------------------------------------+
    // Check if a price level aligns with current regime for limit order placement
    // PURPOSE: Filter limit orders to only place at levels that align with regime direction
    // PARAMETERS:
    //   price - The limit order price level to validate
    //   isBuy - true for buy limit orders, false for sell limit orders
    //   currentPrice - Current market price for comparison
    // RETURNS: true if price level is valid for regime, false otherwise
    //+------------------------------------------------------------------+
    bool IsPriceLevelValidForRegime(double price, bool isBuy, double currentPrice)
    {
        RegimeSnapshot snapshot = GetLastSnapshot();
        
        if(snapshot.regime == REGIME_TREND_BULL)
        {
            // For buys in bullish trend, price must be below current (pullback)
            return isBuy ? (price < currentPrice) : false;
        }
        else if(snapshot.regime == REGIME_TREND_BEAR)
        {
            // For sells in bearish trend, price must be above current (pullback)
            return isBuy ? false : (price > currentPrice);
        }
        else if(snapshot.regime == REGIME_RANGING)
        {
            // In ranging, can use both directions at range boundaries
            return true; // Further validation by key levels
        }
        else if(snapshot.regime == REGIME_BREAKOUT_SETUP)
        {
            // For breakouts, buys above resistance, sells below support
            // This is handled by breakout-specific logic
            return true;
        }
        else if(snapshot.regime == REGIME_HIGH_VOLATILITY)
        {
            // Avoid limit orders in high volatility
            return false;
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Get regime alignment score for limit order placement             |
    //+------------------------------------------------------------------+
    // PURPOSE: Calculate how well a limit order price aligns with current regime
    // PARAMETERS:
    //   isBuy - true for buy limit orders, false for sell limit orders
    //   price - The limit order price level
    //   currentPrice - Current market price for comparison
    // RETURNS: Alignment score from 0.0 (no alignment) to 1.0 (perfect alignment)
    //+------------------------------------------------------------------+
    double GetRegimeAlignmentScore(bool isBuy, double price, double currentPrice)
    {
        RegimeSnapshot snapshot = GetLastSnapshot();
        double alignment = 0.0;
        
        if(snapshot.regime == REGIME_TREND_BULL && isBuy && price < currentPrice)
            alignment = snapshot.confidence;
        else if(snapshot.regime == REGIME_TREND_BEAR && !isBuy && price > currentPrice)
            alignment = snapshot.confidence;
        else if(snapshot.regime == REGIME_RANGING)
            alignment = snapshot.confidence * 0.7; // Slightly lower for ranging
        else if(snapshot.regime == REGIME_BREAKOUT_SETUP)
            alignment = snapshot.confidence * 0.8; // Moderate for breakouts
        
        return alignment;
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
        
        // Check if indicator data is ready before attempting to copy
        if(BarsCalculated(handle) <= 0)
            return 0.0;
            
        ResetLastError();
        int copied = CopyBuffer(handle, 0, 0, 1, m_adx_buffer);
        if(copied <= 0)
        {
            int error = GetLastError();
            if(error != 0 && error != 4806) // Don't log 4806 as it's expected during startup
            {
                ulong nowTick = GetTickCount();
                if(m_lastAtrErrorTick == 0 || (nowTick - m_lastAtrErrorTick) >= 10000)
                {
                    Print("[GrandeRegime] ADX data copy failed for tf=", (int)timeframe, " Err=", error);
                    m_lastAtrErrorTick = nowTick;
                }
            }
            return 0.0;
        }
            
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
        
        // Check if indicator data is ready before attempting to copy
        if(BarsCalculated(handle) <= 0)
            return 0.0;
            
        ResetLastError();
        int copied = CopyBuffer(handle, 1, 0, 1, m_plus_di_buffer);
        if(copied <= 0)
        {
            int error = GetLastError();
            if(error != 0 && error != 4806) // Don't log 4806 as it's expected during startup
            {
                ulong nowTick = GetTickCount();
                if(m_lastAtrErrorTick == 0 || (nowTick - m_lastAtrErrorTick) >= 10000)
                {
                    Print("[GrandeRegime] PlusDI data copy failed for tf=", (int)timeframe, " Err=", error);
                    m_lastAtrErrorTick = nowTick;
                }
            }
            return 0.0;
        }
            
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
        
        // Check if indicator data is ready before attempting to copy
        if(BarsCalculated(handle) <= 0)
            return 0.0;
            
        ResetLastError();
        int copied = CopyBuffer(handle, 2, 0, 1, m_minus_di_buffer);
        if(copied <= 0)
        {
            int error = GetLastError();
            if(error != 0 && error != 4806) // Don't log 4806 as it's expected during startup
            {
                ulong nowTick = GetTickCount();
                if(m_lastAtrErrorTick == 0 || (nowTick - m_lastAtrErrorTick) >= 10000)
                {
                    Print("[GrandeRegime] MinusDI data copy failed for tf=", (int)timeframe, " Err=", error);
                    m_lastAtrErrorTick = nowTick;
                }
            }
            return 0.0;
        }
            
        return m_minus_di_buffer[0];
    }
    
    double GetATRValue()
    {
        double atr;
        if(TryComputeATRSimple(m_config.atr_period, atr))
            return atr;
        ulong nowErr = GetTickCount();
        if(m_lastAtrErrorTick == 0 || (nowErr - m_lastAtrErrorTick) >= 10000)
        {
            Print("[GrandeRegime] ATR data unavailable");
            m_lastAtrErrorTick = nowErr;
        }
        return 0.0;
    }
    
    double GetATRAverage()
    {
        double avg;
        if(TryComputeTRAverage(m_config.atr_avg_period, avg))
            return avg;
        ulong nowErr2 = GetTickCount();
        if(m_lastAtrErrorTick == 0 || (nowErr2 - m_lastAtrErrorTick) >= 10000)
        {
            Print("[GrandeRegime] ATR average data unavailable");
            m_lastAtrErrorTick = nowErr2;
        }
        return 0.0;
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
    ENUM_TIMEFRAMES currentTF = Period();
    
    if(m_atr_handle == INVALID_HANDLE || m_atr_timeframe != currentTF)
    {
        if(m_atr_handle != INVALID_HANDLE)
        {
            IndicatorRelease(m_atr_handle);
            m_atr_handle = INVALID_HANDLE;
        }
        
        if(!SymbolSelect(m_symbol, true))
        {
            Print("[GrandeRegime] ERROR: Symbol not available: ", m_symbol);
            return false;
        }
        
        ResetLastError();
        m_atr_handle = iATR(m_symbol, currentTF, m_config.atr_period);
        int error = GetLastError();
        m_atr_timeframe = currentTF;
        m_atr_ready_logged = false;
        m_atr_wait_logged = false;
        
        if(m_atr_handle == INVALID_HANDLE)
        {
            Print("[GrandeRegime] ERROR: Failed to create ATR handle. Error: ", error, ", Symbol: ", m_symbol);
            return false;
        }
    }
    
    // Preload history to avoid BarsCalculated = -1
    EnsureHistoryReady(currentTF, MathMax(10, m_config.atr_period), 3, delayMs);
    
    for(int i = 0; i < maxRetries; i++)
    {
        int bars = BarsCalculated(m_atr_handle);
        if(bars > 0)
        {
            ArraySetAsSeries(m_atr_buffer, true);
            if(!m_atr_ready_logged)
            {
                Print("[GrandeRegime] ATR handle ready. Calculated bars: ", bars, ", Symbol: ", m_symbol);
                m_atr_ready_logged = true;
            }
            m_atr_wait_logged = false;
            return true;
        }
        
        if(bars < 0)
        {
            // Handle invalid — recreate and retry immediately
            IndicatorRelease(m_atr_handle);
            m_atr_handle = INVALID_HANDLE;
            ResetLastError();
            m_atr_handle = iATR(m_symbol, currentTF, m_config.atr_period);
            int recreateErr = GetLastError();
            if(m_atr_handle == INVALID_HANDLE)
            {
                ulong nowErrRe = GetTickCount();
                if(m_lastAtrErrorTick == 0 || (nowErrRe - m_lastAtrErrorTick) >= 10000)
                {
                    Print("[GrandeRegime] ERROR: Recreate ATR failed. Error: ", recreateErr, ", Symbol: ", m_symbol);
                    m_lastAtrErrorTick = nowErrRe;
                }
                Sleep(delayMs);
                continue;
            }
            m_atr_ready_logged = false;
            m_atr_wait_logged = false;
            bars = BarsCalculated(m_atr_handle);
            if(bars > 0)
            {
                ArraySetAsSeries(m_atr_buffer, true);
                Print("[GrandeRegime] ATR handle ready. Calculated bars: ", bars, ", Symbol: ", m_symbol);
                m_atr_ready_logged = true;
                return true;
            }
        }
        
        ulong nowTick = GetTickCount();
        const ulong minWaitLogMs = 5000;
        if(!m_atr_wait_logged && (m_lastAtrWaitLogTick == 0 || (nowTick - m_lastAtrWaitLogTick) >= minWaitLogMs))
        {
            Print("[GrandeRegime] Waiting for ATR to calculate. Attempt ", (i+1), "/", maxRetries, ", Bars: ", bars);
            m_lastAtrWaitLogTick = nowTick;
            m_atr_wait_logged = true;
        }
        Sleep(delayMs);
    }
    
    ulong nowErr = GetTickCount();
    if(m_lastAtrErrorTick == 0 || (nowErr - m_lastAtrErrorTick) >= 10000)
    {
        Print("[GrandeRegime] ERROR: ATR handle not ready after ", maxRetries, " retries. Symbol: ", m_symbol);
        m_lastAtrErrorTick = nowErr;
    }
    return false;
}

bool CGrandeMarketRegimeDetector::EnsureHistoryReady(ENUM_TIMEFRAMES timeframe, int minBars, int retries, int delayMs)
{
    MqlRates rates[];
    for(int i = 0; i < retries; i++)
    {
        ResetLastError();
        int copied = CopyRates(m_symbol, timeframe, 0, minBars, rates);
        int err = GetLastError();
        if(copied >= MathMin(minBars, 2) && err == 0)
            return true;
        Sleep(delayMs);
    }
    return false;
}

bool CGrandeMarketRegimeDetector::TryComputeATRSimple(int period, double &outAtr)
{
    if(period <= 0) return false;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int need = period + 1;
    ResetLastError();
    int copied = CopyRates(m_symbol, Period(), 0, need, rates);
    if(copied < need || GetLastError() != 0)
        return false;
    double sumTR = 0.0;
    for(int i = 0; i < period; i++)
    {
        double high = rates[i].high;
        double low = rates[i].low;
        double prevClose = rates[i+1].close;
        double tr1 = high - low;
        double tr2 = MathAbs(high - prevClose);
        double tr3 = MathAbs(low - prevClose);
        double tr = MathMax(tr1, MathMax(tr2, tr3));
        sumTR += tr;
    }
    outAtr = sumTR / period;
    return true;
}

bool CGrandeMarketRegimeDetector::TryComputeTRAverage(int barsCount, double &outAvgTR)
{
    if(barsCount <= 1) return false;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int need = barsCount + 1;
    ResetLastError();
    int copied = CopyRates(m_symbol, Period(), 0, need, rates);
    if(copied < need || GetLastError() != 0)
        return false;
    double sumTR = 0.0;
    for(int i = 0; i < barsCount; i++)
    {
        double high = rates[i].high;
        double low = rates[i].low;
        double prevClose = rates[i+1].close;
        double tr1 = high - low;
        double tr2 = MathAbs(high - prevClose);
        double tr3 = MathAbs(low - prevClose);
        double tr = MathMax(tr1, MathMax(tr2, tr3));
        sumTR += tr;
    }
    outAvgTR = sumTR / barsCount;
    return true;
}