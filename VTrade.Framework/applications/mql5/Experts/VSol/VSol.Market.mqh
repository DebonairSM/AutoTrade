//+------------------------------------------------------------------+
//|                                               VSol.Market.mqh      |
//|         Base Market Data Analysis Module for all instruments       |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.0.3"  // Aligned with main EA version
#property strict

#ifndef __VSOL_MARKET_MQH__
#define __VSOL_MARKET_MQH__

//--- Version Info
#define VSOL_MARKET_VERSION      "1.0.3"
#define VSOL_MARKET_BUILD_DATE   "2024-03-19"
#define VSOL_MARKET_DESCRIPTION  "Added version tracking and improved crypto visualization"

//+------------------------------------------------------------------+
//| Key Level and Touch Structures                                     |
//+------------------------------------------------------------------+
struct STouch
{
    datetime time;       // Time of the touch
    double   price;     // Price at touch
    double   strength;  // Touch strength (0.0-1.0)
    bool     isValid;   // Touch validation flag
    bool     isTest;    // True if testing the level
    bool     isBreak;   // True if breaking the level
    
    void Reset()
    {
        time = 0;
        price = 0.0;
        strength = 0.0;
        isValid = false;
        isTest = false;
        isBreak = false;
    }
};

struct SKeyLevel
{
    double    price;           // Level price
    bool      isResistance;    // True for resistance, false for support
    datetime  firstTouch;      // Time of first touch
    datetime  lastTouch;       // Time of last touch
    int       touchCount;      // Number of valid touches
    double    strength;        // Level strength (0.0-1.0)
    bool      volumeConfirmed; // Volume confirmation flag
    double    volumeRatio;     // Ratio of level volume to average volume
    STouch    touches[];      // Array of touches
    
    void Reset()
    {
        price = 0.0;
        isResistance = false;
        firstTouch = 0;
        lastTouch = 0;
        touchCount = 0;
        strength = 0.0;
        volumeConfirmed = false;
        volumeRatio = 1.0;
        ArrayResize(touches, 0);
    }
};

//+------------------------------------------------------------------+
//| Market Type Definitions                                            |
//+------------------------------------------------------------------+
enum ENUM_MARKET_TYPE
{
    MARKET_TYPE_UNKNOWN = -1,    // Unknown market type
    MARKET_TYPE_FOREX,           // Forex market
    MARKET_TYPE_INDEX_US500,     // US500/SPX market
    MARKET_TYPE_CRYPTO           // Cryptocurrency market
};

//+------------------------------------------------------------------+
//| Market Category Configuration                                      |
//+------------------------------------------------------------------+
struct SMarketConfig
{
    double touchZone;        // Touch zone size (pips/points)
    double bounceMinSize;    // Minimum bounce size
    double minStrength;      // Minimum level strength
    int    minTouches;      // Minimum touches required
    int    lookbackPeriod;  // Analysis lookback period
    
    void Reset()
    {
        touchZone = 0.0;
        bounceMinSize = 0.0;
        minStrength = 0.0;
        minTouches = 0;
        lookbackPeriod = 0;
    }
};

//+------------------------------------------------------------------+
//| Market Configuration Manager                                       |
//+------------------------------------------------------------------+
class CVSolMarketConfig
{
private:
    ENUM_MARKET_TYPE m_marketType;  // Current market type
    string          m_symbol;       // Current symbol
    SMarketConfig   m_config;       // Market configuration
    
public:
    void Configure(const string symbol, const ENUM_MARKET_TYPE type,
                  const double touchZone, const double bounceSize,
                  const double minStrength, const int minTouches,
                  const int lookback)
    {
        m_symbol = symbol;
        m_marketType = type;
        
        m_config.Reset();
        m_config.touchZone = touchZone;
        m_config.bounceMinSize = bounceSize;
        m_config.minStrength = minStrength;
        m_config.minTouches = minTouches;
        m_config.lookbackPeriod = lookback;
    }
    
    ENUM_MARKET_TYPE GetMarketType() const { return m_marketType; }
    string GetSymbol() const { return m_symbol; }
    
    double GetTouchZone() const { return m_config.touchZone; }
    double GetBounceMinSize() const { return m_config.bounceMinSize; }
    double GetMinStrength() const { return m_config.minStrength; }
    int GetMinTouches() const { return m_config.minTouches; }
    int GetLookbackPeriod() const { return m_config.lookbackPeriod; }
    
    string GetUnits() const
    {
        switch(m_marketType)
        {
            case MARKET_TYPE_FOREX:
                return "pips";
            case MARKET_TYPE_CRYPTO:
                return "USD";
            default:
                return "points";
        }
    }
};

//+------------------------------------------------------------------+
//| Market Scaling Functions                                           |
//+------------------------------------------------------------------+
class CVSolMarketScaling
{
public:
    static double GetScaledTouchZone(const double baseZone, const double currentPrice, const ENUM_MARKET_TYPE marketType)
    {
        switch(marketType)
        {
            case MARKET_TYPE_CRYPTO:
                return MathMax(baseZone, currentPrice * 0.005); // 0.5% of price
            
            case MARKET_TYPE_FOREX:
            case MARKET_TYPE_INDEX_US500:
            default:
                return baseZone;
        }
    }
    
    static double GetScaledBounceSize(const double baseBounce, const double currentPrice, const ENUM_MARKET_TYPE marketType)
    {
        switch(marketType)
        {
            case MARKET_TYPE_CRYPTO:
                return MathMax(baseBounce, currentPrice * 0.0025); // 0.25% of price
            
            case MARKET_TYPE_FOREX:
            case MARKET_TYPE_INDEX_US500:
            default:
                return baseBounce;
        }
    }
    
    static double GetScaledVisualizationOffset(const double baseOffset, const double currentPrice, const ENUM_MARKET_TYPE marketType)
    {
        switch(marketType)
        {
            case MARKET_TYPE_CRYPTO:
                return MathMax(baseOffset, currentPrice * 0.01); // 1% of price
            
            case MARKET_TYPE_FOREX:
            case MARKET_TYPE_INDEX_US500:
            default:
                return baseOffset;
        }
    }
};

//+------------------------------------------------------------------+
//| Base Market Data Analysis Class                                    |
//+------------------------------------------------------------------+
class CVSolMarketBase
{
protected:
    //--- Common Settings
    static int      m_lookbackPeriod;    // Bars to look back
    static double   m_minStrength;       // Minimum strength threshold
    static double   m_touchZone;         // Zone size for touch detection
    static int      m_minTouches;        // Minimum touches required
    static double   m_touchWeight;       // Weight for touch score
    static double   m_recencyWeight;     // Weight for recency score
    static double   m_durationWeight;    // Weight for duration score
    static int      m_minDurationHours;  // Minimum duration in hours
    
    //--- Volume Analysis
    static double   m_volumeMultiplier;  // Volume spike threshold
    static int      m_volumeType;        // Type of volume to analyze
    
    //--- Debug Settings
    static bool     m_showDebugPrints;   // Debug mode flag
    
    /**
     * @brief Calculate average volume over a range of bars.
     */
    static double GetAverageVolume(const long &volumes[], int startIndex, int barsToAverage)
    {
        if(startIndex < 0 || startIndex >= ArraySize(volumes))
            return 0.0;
            
        double avgVolume = 0;
        int count = 0;
        
        for(int i = startIndex; i < MathMin(startIndex + barsToAverage, ArraySize(volumes)); i++)
        {
            avgVolume += (double)volumes[i];
            count++;
        }
        
        return (count > 0) ? avgVolume / count : 0.0;
    }
    
    /**
     * @brief Validate if a price movement is a valid bounce.
     */
    static bool ValidateBounce(const double &prices[], const double price, const double level, const double minBounceSize)
    {
        if(ArraySize(prices) < 2)
            return false;
            
        double bounceSize = MathAbs(prices[0] - level);
        
        // For crypto, adjust bounce size based on price scale
        double effectiveBounceSize = minBounceSize;
        if(price > 10000)  // High-value coins like BTC
        {
            // Use percentage-based bounce (0.25% of price)
            effectiveBounceSize = MathMax(minBounceSize, price * 0.0025);
        }
        
        return bounceSize >= effectiveBounceSize;
    }
    
    /**
     * @brief Validate if a price point is a valid touch of a level.
     */
    static bool IsTouchValid(const double price, const double level, const double touchZone)
    {
        // For crypto, we use direct price differences
        double effectiveZone = touchZone;
        if(price > 10000)  // High-value coins like BTC
        {
            // Use percentage-based zone (0.5% of price)
            effectiveZone = MathMax(touchZone, price * 0.005);
        }
        
        double priceDiff = MathAbs(price - level);
        return priceDiff <= effectiveZone;
    }
    
public:
    /**
     * @brief Common initialization method for all market data modules.
     * @param showDebugPrints Enables debug prints when set to true.
     */
    static void Init(bool showDebugPrints=false)
    {
        m_showDebugPrints = showDebugPrints;
        if(m_showDebugPrints)
            Print("Initializing Market Data Base");
    }
    
    /**
     * @brief Configure the level detection settings.
     */
    static void ConfigureLevelDetection(
        int lookback,
        double minStrength,
        double touchZone,
        int minTouches,
        double touchWeight,
        double recencyWeight,
        double durationWeight,
        int minDurationHours)
    {
        m_lookbackPeriod = lookback;
        m_minStrength = minStrength;
        m_touchZone = touchZone;
        m_minTouches = minTouches;
        m_touchWeight = touchWeight;
        m_recencyWeight = recencyWeight;
        m_durationWeight = durationWeight;
        m_minDurationHours = minDurationHours;
        
        if(m_showDebugPrints)
            Print("Level detection configured with lookback=", lookback,
                  ", minStrength=", minStrength,
                  ", touchZone=", touchZone);
    }
    
    /**
     * @brief Configure the volume analysis settings.
     */
    static void ConfigureVolumeAnalysis(double multiplier, int volumeType)
    {
        m_volumeMultiplier = multiplier;
        m_volumeType = volumeType;
        
        if(m_showDebugPrints)
            Print("Volume analysis configured with multiplier=", multiplier);
    }
    
    /**
     * @brief Check if there is a volume spike at the given bar.
     */
    static bool IsVolumeSpike(const long &volumes[], const int index, const int barsToAverage=10, const double multiplier=1.5)
    {
        if(index < 0 || index >= ArraySize(volumes))
            return false;
            
        double avgVolume = GetAverageVolume(volumes, index + 1, barsToAverage);
        if(avgVolume <= 0)
            return false;
            
        // For crypto, we use a more sensitive volume spike detection
        double effectiveMultiplier = multiplier;
        if(SymbolInfoDouble(Symbol(), SYMBOL_BID) > 10000)  // High-value coins like BTC
        {
            effectiveMultiplier = 1.25;  // More sensitive for crypto
        }
            
        double volumeRatio = (double)volumes[index] / avgVolume;
        return volumeRatio >= effectiveMultiplier;
    }
    
    /**
     * @brief Get volume-based strength bonus for a level.
     */
    static double GetVolumeStrengthBonus(const long &volumes[], const int index, const int barsToAverage=10)
    {
        double avgVolume = GetAverageVolume(volumes, index + 1, barsToAverage);
        if(avgVolume <= 0)
            return 0.0;
            
        double volumeRatio = (double)volumes[index] / avgVolume;
        
        // Cap the bonus at 0.15 (15% strength increase)
        return MathMin((volumeRatio - 1.0) * 0.05, 0.15);
    }
    
    /**
     * @brief Get volume data for analysis.
     */
    static bool GetVolumeData(string symbol, long &volumes[], int bars)
    {
        if(m_volumeType == VOLUME_TICK)
            return CopyTickVolume(symbol, Period(), 0, bars, volumes) == bars;
        else
            return CopyRealVolume(symbol, Period(), 0, bars, volumes) == bars;
    }
    
    /**
     * @brief Count touches with enhanced validation.
     */
    static bool CountTouchesEnhanced(
        string symbol,
        const double &highs[],
        const double &lows[],
        const datetime &times[],
        const double level,
        SKeyLevel &outLevel)
    {
        outLevel.Reset();
        outLevel.price = level;
        
        int touchCount = 0;
        ArrayResize(outLevel.touches, 0);
        
        for(int i = 0; i < ArraySize(highs); i++)
        {
            if(IsTouchValid(highs[i], level, m_touchZone) ||
               IsTouchValid(lows[i], level, m_touchZone))
            {
                // Add touch to the array
                int size = ArraySize(outLevel.touches);
                ArrayResize(outLevel.touches, size + 1);
                
                outLevel.touches[size].time = times[i];
                outLevel.touches[size].price = (highs[i] + lows[i]) / 2;
                outLevel.touches[size].isValid = true;
                
                // Update level information
                if(touchCount == 0)
                    outLevel.firstTouch = times[i];
                outLevel.lastTouch = times[i];
                touchCount++;
            }
        }
        
        outLevel.touchCount = touchCount;
        
        return touchCount >= m_minTouches;
    }
    
    /**
     * @brief Detect the market type based on symbol characteristics
     */
    static ENUM_MARKET_TYPE GetMarketType(const string symbol)
    {
        // Get symbol properties
        ENUM_SYMBOL_CALC_MODE calc_mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
        
        // Check for crypto pairs (BTC, ETH, etc.)
        if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0 ||
           StringFind(symbol, "XRP") >= 0 || StringFind(symbol, "DOGE") >= 0)
        {
            return MARKET_TYPE_CRYPTO;
        }
        
        // Check for US500
        if(StringFind(symbol, "US500") >= 0 || StringFind(symbol, "SPX") >= 0)
        {
            return MARKET_TYPE_INDEX_US500;
        }
        
        // Check for Forex
        if(calc_mode == SYMBOL_CALC_MODE_FOREX)
        {
            return MARKET_TYPE_FOREX;
        }
        
        return MARKET_TYPE_UNKNOWN;
    }
    
    /**
     * @brief Get the calculation mode description for the current symbol
     */
    static string GetCalcModeDescription(const string symbol)
    {
        ENUM_SYMBOL_CALC_MODE calc_mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
        string desc = "SYMBOL_CALC_MODE_";
        
        switch(calc_mode)
        {
            case SYMBOL_CALC_MODE_FOREX: return "SYMBOL_CALC_MODE_FOREX";
            case SYMBOL_CALC_MODE_CFD: return "SYMBOL_CALC_MODE_CFD";
            case SYMBOL_CALC_MODE_FUTURES: return "SYMBOL_CALC_MODE_FUTURES";
            case SYMBOL_CALC_MODE_CFDINDEX: return "SYMBOL_CALC_MODE_CFDINDEX";
            case SYMBOL_CALC_MODE_CFDLEVERAGE: return "SYMBOL_CALC_MODE_CFDLEVERAGE";
            case SYMBOL_CALC_MODE_EXCH_STOCKS: return "SYMBOL_CALC_MODE_EXCH_STOCKS";
            case SYMBOL_CALC_MODE_EXCH_FUTURES: return "SYMBOL_CALC_MODE_EXCH_FUTURES";
            case SYMBOL_CALC_MODE_EXCH_OPTIONS: return "SYMBOL_CALC_MODE_EXCH_OPTIONS";
            default: return desc + IntegerToString(calc_mode);
        }
    }
    
    //--- Virtual Interface Methods
    virtual double CalculateStrength(const SKeyLevel &level, const STouch &touches[]) { return 0.0; }
    virtual bool ValidateLevel(const double price, const double level, ENUM_TIMEFRAMES timeframe) { return IsTouchValid(price, level, m_touchZone); }
    virtual bool FindKeyLevels(string symbol, SKeyLevel &outStrongestLevel) { return false; }
    virtual double GetSessionFactor() { return 1.0; }
    
    virtual ~CVSolMarketBase() {}  // Virtual destructor for proper cleanup
};

// Initialize static members
int      CVSolMarketBase::m_lookbackPeriod;
double   CVSolMarketBase::m_minStrength;
double   CVSolMarketBase::m_touchZone;
int      CVSolMarketBase::m_minTouches;
double   CVSolMarketBase::m_touchWeight;
double   CVSolMarketBase::m_recencyWeight;
double   CVSolMarketBase::m_durationWeight;
int      CVSolMarketBase::m_minDurationHours;
double   CVSolMarketBase::m_volumeMultiplier;
int      CVSolMarketBase::m_volumeType;
bool     CVSolMarketBase::m_showDebugPrints;

#endif // __VSOL_MARKET_MQH__
