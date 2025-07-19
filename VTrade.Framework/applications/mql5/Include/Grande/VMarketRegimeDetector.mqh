//+------------------------------------------------------------------+
//| VMarketRegimeDetector.mqh                                        |
//| Copyright 2024, Grande Tech                                      |
//| Market Regime Detection Module - Foundation for Trading System   |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor event handlers and indicator patterns

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com"
#property version   "1.00"

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
//| Market Regime Detector Class                                     |
//+------------------------------------------------------------------+
class CMarketRegimeDetector
{
private:
    // Configuration
    RegimeConfig    m_config;
    string          m_symbol;
    
    // Indicator Handles
    int             m_adx_h1_handle;
    int             m_adx_h4_handle;
    int             m_adx_d1_handle;
    int             m_atr_handle;
    int             m_atr_avg_handle;
    
    // Current regime state
    RegimeSnapshot  m_current_regime;
    datetime        m_last_update;
    
    // Indicator value buffers
    double          m_adx_buffer[];
    double          m_plus_di_buffer[];
    double          m_minus_di_buffer[];
    double          m_atr_buffer[];
    double          m_atr_avg_buffer[];

public:
    // Constructor & Destructor
                    CMarketRegimeDetector(void);
                   ~CMarketRegimeDetector(void);
    
    // Initialization
    bool            Initialize(const string symbol, const RegimeConfig &config);
    void            Deinitialize(void);
    
    // Core Detection Methods
    RegimeSnapshot  DetectCurrentRegime(void);
    bool            UpdateRegime(void);
    
    // Regime Query Methods
    MARKET_REGIME   GetCurrentRegime(void) const { return m_current_regime.regime; }
    double          GetConfidence(void) const { return m_current_regime.confidence; }
    bool            IsTrendingBull(void) const { return m_current_regime.regime == REGIME_TREND_BULL; }
    bool            IsTrendingBear(void) const { return m_current_regime.regime == REGIME_TREND_BEAR; }
    bool            IsRanging(void) const { return m_current_regime.regime == REGIME_RANGING; }
    bool            IsBreakoutSetup(void) const { return m_current_regime.regime == REGIME_BREAKOUT_SETUP; }
    bool            IsHighVolatility(void) const { return m_current_regime.regime == REGIME_HIGH_VOLATILITY; }
    bool            IsTrending(void) const { return IsTrendingBull() || IsTrendingBear(); }
    
    // Data Access
    RegimeSnapshot  GetLastSnapshot(void) const { return m_current_regime; }
    string          RegimeToString(MARKET_REGIME regime) const;
    
    // Configuration
    void            SetConfig(const RegimeConfig &config) { m_config = config; }
    RegimeConfig    GetConfig(void) const { return m_config; }

private:
    // Internal calculation methods
    bool            CreateIndicatorHandles(void);
    bool            GetIndicatorValues(void);
    MARKET_REGIME   AnalyzeRegime(double adx_h1, double adx_h4, double adx_d1, 
                                double plus_di, double minus_di, double atr_ratio);
    double          CalculateConfidence(MARKET_REGIME regime, double adx_primary, 
                                      double atr_ratio, double di_diff);
    bool            IsValidIndicatorData(void);
    void            LogRegimeChange(MARKET_REGIME old_regime, MARKET_REGIME new_regime);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketRegimeDetector::CMarketRegimeDetector(void) : 
    m_symbol(""),
    m_adx_h1_handle(INVALID_HANDLE),
    m_adx_h4_handle(INVALID_HANDLE), 
    m_adx_d1_handle(INVALID_HANDLE),
    m_atr_handle(INVALID_HANDLE),
    m_atr_avg_handle(INVALID_HANDLE),
    m_last_update(0)
{
    // Initialize current regime
    m_current_regime.regime = REGIME_RANGING;
    m_current_regime.confidence = 0.0;
    m_current_regime.timestamp = 0;
    
    // Set array properties
    ArraySetAsSeries(m_adx_buffer, true);
    ArraySetAsSeries(m_plus_di_buffer, true);
    ArraySetAsSeries(m_minus_di_buffer, true);
    ArraySetAsSeries(m_atr_buffer, true);
    ArraySetAsSeries(m_atr_avg_buffer, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                      |
//+------------------------------------------------------------------+
CMarketRegimeDetector::~CMarketRegimeDetector(void)
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize the detector                                          |
//+------------------------------------------------------------------+
bool CMarketRegimeDetector::Initialize(const string symbol, const RegimeConfig &config)
{
    m_symbol = symbol;
    m_config = config;
    
    if(!CreateIndicatorHandles())
    {
        Print("ERROR: Failed to create indicator handles for symbol: ", symbol);
        return false;
    }
    
    Print("Market Regime Detector initialized successfully for ", symbol);
    return true;
}

//+------------------------------------------------------------------+
//| Clean up resources                                              |
//+------------------------------------------------------------------+
void CMarketRegimeDetector::Deinitialize(void)
{
    if(m_adx_h1_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_adx_h1_handle);
        m_adx_h1_handle = INVALID_HANDLE;
    }
    if(m_adx_h4_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_adx_h4_handle);
        m_adx_h4_handle = INVALID_HANDLE;
    }
    if(m_adx_d1_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_adx_d1_handle);
        m_adx_d1_handle = INVALID_HANDLE;
    }
    if(m_atr_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_atr_handle);
        m_atr_handle = INVALID_HANDLE;
    }
    if(m_atr_avg_handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_atr_avg_handle);
        m_atr_avg_handle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Create indicator handles                                         |
//+------------------------------------------------------------------+
bool CMarketRegimeDetector::CreateIndicatorHandles(void)
{
    // Create ADX handles for multiple timeframes
    m_adx_h1_handle = iADX(m_symbol, m_config.tf_primary, 14);
    m_adx_h4_handle = iADX(m_symbol, m_config.tf_secondary, 14);
    m_adx_d1_handle = iADX(m_symbol, m_config.tf_tertiary, 14);
    
    // Create ATR handles
    m_atr_handle = iATR(m_symbol, m_config.tf_tertiary, m_config.atr_period);
    m_atr_avg_handle = iMA(m_symbol, m_config.tf_tertiary, m_config.atr_avg_period, 0, MODE_SMA, PRICE_TYPICAL);
    
    // Validate handles
    if(m_adx_h1_handle == INVALID_HANDLE || m_adx_h4_handle == INVALID_HANDLE || 
       m_adx_d1_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE || 
       m_atr_avg_handle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create one or more indicator handles");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get current indicator values                                     |
//+------------------------------------------------------------------+
bool CMarketRegimeDetector::GetIndicatorValues(void)
{
    // Copy ADX data from H1
    if(CopyBuffer(m_adx_h1_handle, 0, 0, 3, m_adx_buffer) <= 0 ||
       CopyBuffer(m_adx_h1_handle, 1, 0, 3, m_plus_di_buffer) <= 0 ||
       CopyBuffer(m_adx_h1_handle, 2, 0, 3, m_minus_di_buffer) <= 0)
    {
        Print("ERROR: Failed to copy ADX H1 data");
        return false;
    }
    
    // Copy ATR data
    if(CopyBuffer(m_atr_handle, 0, 0, 2, m_atr_buffer) <= 0)
    {
        Print("ERROR: Failed to copy ATR data");
        return false;
    }
    
    // Copy ATR average data (for volatility comparison)
    if(CopyBuffer(m_atr_avg_handle, 0, 0, 2, m_atr_avg_buffer) <= 0)
    {
        Print("ERROR: Failed to copy ATR average data");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update regime detection                                          |
//+------------------------------------------------------------------+
bool CMarketRegimeDetector::UpdateRegime(void)
{
    datetime current_time = TimeCurrent();
    
    // Update only once per bar
    if(current_time == m_last_update)
        return true;
        
    if(!GetIndicatorValues())
        return false;
        
    if(!IsValidIndicatorData())
        return false;
    
    MARKET_REGIME old_regime = m_current_regime.regime;
    
    // Get ADX values from different timeframes
    double adx_h1_values[], adx_h4_values[], adx_d1_values[];
    ArraySetAsSeries(adx_h1_values, true);
    ArraySetAsSeries(adx_h4_values, true);
    ArraySetAsSeries(adx_d1_values, true);
    
    CopyBuffer(m_adx_h1_handle, 0, 0, 2, adx_h1_values);
    CopyBuffer(m_adx_h4_handle, 0, 0, 2, adx_h4_values);
    CopyBuffer(m_adx_d1_handle, 0, 0, 2, adx_d1_values);
    
    // Calculate ATR ratio for volatility assessment
    double atr_ratio = (m_atr_avg_buffer[0] > 0) ? m_atr_buffer[0] / m_atr_avg_buffer[0] : 1.0;
    
    // Analyze regime
    MARKET_REGIME new_regime = AnalyzeRegime(
        adx_h1_values[0], adx_h4_values[0], adx_d1_values[0],
        m_plus_di_buffer[0], m_minus_di_buffer[0], atr_ratio
    );
    
    // Update regime snapshot
    m_current_regime.regime = new_regime;
    m_current_regime.confidence = CalculateConfidence(new_regime, adx_h1_values[0], atr_ratio, 
                                                     MathAbs(m_plus_di_buffer[0] - m_minus_di_buffer[0]));
    m_current_regime.timestamp = current_time;
    m_current_regime.adx_h1 = adx_h1_values[0];
    m_current_regime.adx_h4 = adx_h4_values[0];
    m_current_regime.adx_d1 = adx_d1_values[0];
    m_current_regime.atr_current = m_atr_buffer[0];
    m_current_regime.atr_avg = m_atr_avg_buffer[0];
    m_current_regime.plus_di = m_plus_di_buffer[0];
    m_current_regime.minus_di = m_minus_di_buffer[0];
    
    // Log regime changes
    if(old_regime != new_regime)
        LogRegimeChange(old_regime, new_regime);
    
    m_last_update = current_time;
    return true;
}

//+------------------------------------------------------------------+
//| Analyze market regime based on indicators                       |
//+------------------------------------------------------------------+
MARKET_REGIME CMarketRegimeDetector::AnalyzeRegime(double adx_h1, double adx_h4, double adx_d1,
                                                   double plus_di, double minus_di, double atr_ratio)
{
    // High volatility check (takes priority)
    if(atr_ratio >= m_config.high_vol_multiplier)
        return REGIME_HIGH_VOLATILITY;
    
    // Primary ADX analysis (H1 timeframe)
    if(adx_h1 >= m_config.adx_trend_threshold)
    {
        // Strong trend detected
        if(plus_di > minus_di)
            return REGIME_TREND_BULL;
        else
            return REGIME_TREND_BEAR;
    }
    else if(adx_h1 >= m_config.adx_breakout_min && adx_h1 < m_config.adx_trend_threshold)
    {
        // Check if ATR is rising (breakout potential)
        if(atr_ratio > 1.1) // 10% above average
            return REGIME_BREAKOUT_SETUP;
    }
    
    // Default to ranging if no clear trend or breakout
    return REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| Calculate confidence level for regime detection                  |
//+------------------------------------------------------------------+
double CMarketRegimeDetector::CalculateConfidence(MARKET_REGIME regime, double adx_primary, 
                                                 double atr_ratio, double di_diff)
{
    double confidence = 0.5; // Base confidence
    
    switch(regime)
    {
        case REGIME_TREND_BULL:
        case REGIME_TREND_BEAR:
            // Higher ADX = higher confidence
            confidence = MathMin(1.0, (adx_primary / 50.0) + 0.3);
            // Larger DI difference = higher confidence
            confidence += MathMin(0.2, di_diff / 100.0);
            break;
            
        case REGIME_BREAKOUT_SETUP:
            // Moderate confidence for breakout setups
            confidence = 0.6 + MathMin(0.3, (atr_ratio - 1.0));
            break;
            
        case REGIME_HIGH_VOLATILITY:
            // High confidence when volatility is extreme
            confidence = MathMin(1.0, 0.7 + (atr_ratio - 2.0) * 0.15);
            break;
            
        case REGIME_RANGING:
            // Lower confidence, inverse relationship with ADX
            confidence = MathMax(0.3, 0.8 - (adx_primary / 30.0));
            break;
    }
    
    return MathMax(0.0, MathMin(1.0, confidence));
}

//+------------------------------------------------------------------+
//| Validate indicator data                                          |
//+------------------------------------------------------------------+
bool CMarketRegimeDetector::IsValidIndicatorData(void)
{
    return (ArraySize(m_adx_buffer) > 0 && 
            ArraySize(m_plus_di_buffer) > 0 && 
            ArraySize(m_minus_di_buffer) > 0 &&
            ArraySize(m_atr_buffer) > 0 && 
            ArraySize(m_atr_avg_buffer) > 0 &&
            m_adx_buffer[0] != EMPTY_VALUE &&
            m_atr_buffer[0] != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Detect current regime (public interface)                        |
//+------------------------------------------------------------------+
RegimeSnapshot CMarketRegimeDetector::DetectCurrentRegime(void)
{
    UpdateRegime();
    return m_current_regime;
}

//+------------------------------------------------------------------+
//| Convert regime enum to string                                    |
//+------------------------------------------------------------------+
string CMarketRegimeDetector::RegimeToString(MARKET_REGIME regime) const
{
    switch(regime)
    {
        case REGIME_TREND_BULL:      return "TREND_BULL";
        case REGIME_TREND_BEAR:      return "TREND_BEAR";
        case REGIME_BREAKOUT_SETUP:  return "BREAKOUT_SETUP";
        case REGIME_RANGING:         return "RANGING";
        case REGIME_HIGH_VOLATILITY: return "HIGH_VOLATILITY";
        default:                     return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Log regime changes                                               |
//+------------------------------------------------------------------+
void CMarketRegimeDetector::LogRegimeChange(MARKET_REGIME old_regime, MARKET_REGIME new_regime)
{
    Print("REGIME CHANGE [", m_symbol, "]: ", 
          RegimeToString(old_regime), " -> ", RegimeToString(new_regime),
          " | Confidence: ", DoubleToString(m_current_regime.confidence, 2),
          " | ADX H1: ", DoubleToString(m_current_regime.adx_h1, 1),
          " | ATR Ratio: ", DoubleToString(m_current_regime.atr_current/m_current_regime.atr_avg, 2));
} 