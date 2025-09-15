//+------------------------------------------------------------------+
//| GrandeTrianglePatternDetector.mqh                                |
//| Copyright 2024, Grande Tech                                      |
//| Advanced Triangle Pattern Detection Module                       |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor pattern recognition and chart analysis

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Advanced triangle pattern detection with multi-timeframe analysis"

//+------------------------------------------------------------------+
//| Triangle Pattern Types                                           |
//+------------------------------------------------------------------+
enum TRIANGLE_TYPE
{
    TRIANGLE_NONE,           // No triangle detected
    TRIANGLE_ASCENDING,      // Ascending triangle (horizontal resistance, rising support)
    TRIANGLE_DESCENDING,     // Descending triangle (horizontal support, falling resistance)
    TRIANGLE_SYMMETRICAL,    // Symmetrical triangle (both lines converging)
    TRIANGLE_WEDGE_RISING,   // Rising wedge (both lines rising, resistance steeper)
    TRIANGLE_WEDGE_FALLING   // Falling wedge (both lines falling, support steeper)
};

//+------------------------------------------------------------------+
//| Triangle Pattern Structure                                       |
//+------------------------------------------------------------------+
struct STrianglePattern
{
    TRIANGLE_TYPE        type;               // Triangle type detected
    double               resistanceLevel;    // Resistance level price
    double               supportLevel;       // Current support level price
    double               slopeResistance;    // Resistance line slope
    double               slopeSupport;       // Support line slope
    int                  touchCountRes;      // Number of resistance touches
    int                  touchCountSup;      // Number of support touches
    datetime             formationStart;     // When pattern started forming
    datetime             lastUpdate;         // Last pattern update
    double               confidence;         // Pattern confidence (0.0-1.0)
    double               breakoutProbability; // Probability of upward breakout
    double               targetPrice;        // Calculated target price
    double               stopLossPrice;      // Calculated stop loss
    bool                 volumeConfirmed;    // Volume pattern confirmation
    double               volumeRatio;        // Volume ratio during formation
    bool                 isActive;           // Is pattern still active
    ENUM_TIMEFRAMES      timeframe;          // Timeframe where detected
};

//+------------------------------------------------------------------+
//| Swing Point Structure                                            |
//+------------------------------------------------------------------+
struct SSwingPoint
{
    double               price;              // Swing point price
    datetime             time;               // Swing point time
    int                  barIndex;           // Bar index
    bool                 isHigh;             // true = swing high, false = swing low
    double               strength;           // Swing point strength
    double               volume;             // Volume at swing point
};

//+------------------------------------------------------------------+
//| Trend Line Structure                                             |
//+------------------------------------------------------------------+
struct STrendLine
{
    double               startPrice;         // Starting price
    double               endPrice;           // Ending price
    datetime             startTime;          // Starting time
    datetime             endTime;            // Ending time
    double               slope;              // Line slope
    int                  touchCount;         // Number of touches
    double               rSquared;           // Line fit quality (0.0-1.0)
    bool                 isHorizontal;       // Is line horizontal
    double               levelPrice;         // Price level (for horizontal lines)
};

//+------------------------------------------------------------------+
//| Triangle Detection Configuration                                  |
//+------------------------------------------------------------------+
struct TriangleConfig
{
    // Pattern Requirements
    int                  minTouchesResistance;   // Minimum resistance touches (3)
    int                  minTouchesSupport;      // Minimum support touches (3)
    int                  minFormationBars;       // Minimum bars for formation (20)
    int                  maxFormationBars;       // Maximum bars for formation (100)
    
    // Slope Tolerance
    double               horizontalTolerance;    // Slope tolerance for horizontal (0.001)
    double               risingSlopeMin;         // Minimum rising slope (0.0001)
    double               fallingSlopeMax;        // Maximum falling slope (-0.0001)
    
    // Volume Requirements
    double               volumeDecreaseRatio;    // Volume decrease ratio (0.7)
    int                  volumeLookbackBars;     // Volume lookback period (20)
    
    // Confidence Calculation
    double               touchWeight;            // Weight for touch count (0.3)
    double               slopeWeight;            // Weight for slope consistency (0.2)
    double               volumeWeight;           // Weight for volume pattern (0.2)
    double               timeWeight;             // Weight for formation time (0.1)
    double               strengthWeight;         // Weight for swing strength (0.2)
    
    // Constructor with defaults
    TriangleConfig()
    {
        minTouchesResistance = 3;
        minTouchesSupport = 3;
        minFormationBars = 20;
        maxFormationBars = 100;
        horizontalTolerance = 0.001;
        risingSlopeMin = 0.0001;
        fallingSlopeMax = -0.0001;
        volumeDecreaseRatio = 0.7;
        volumeLookbackBars = 20;
        touchWeight = 0.3;
        slopeWeight = 0.2;
        volumeWeight = 0.2;
        timeWeight = 0.1;
        strengthWeight = 0.2;
    }
};

//+------------------------------------------------------------------+
//| Grande Triangle Pattern Detector Class                          |
//+------------------------------------------------------------------+
class CGrandeTrianglePatternDetector
{
private:
    // Configuration
    TriangleConfig       m_config;
    string              m_symbol;
    bool                m_initialized;
    
    // Current patterns
    STrianglePattern    m_currentPattern;
    SSwingPoint         m_swingPoints[];
    STrendLine          m_resistanceLine;
    STrendLine          m_supportLine;
    
    // Analysis buffers
    double              m_highs[];
    double              m_lows[];
    double              m_volumes[];
    datetime            m_times[];
    
    // Helper methods
    bool                DetectSwingPoints(int lookback);
    bool                ValidateTriangleFormation();
    bool                CalculateTrendLines();
    double              CalculateLineSlope(const SSwingPoint &points[], bool isHigh);
    bool                IsHorizontalLine(double slope);
    bool                IsRisingLine(double slope);
    bool                IsFallingLine(double slope);
    double              CalculatePatternConfidence();
    double              CalculateBreakoutProbability();
    bool                ValidateVolumePattern();
    TRIANGLE_TYPE       DetermineTriangleType();
    void                UpdatePatternTargets();
    
public:
    // Constructor/Destructor
    CGrandeTrianglePatternDetector();
    ~CGrandeTrianglePatternDetector();
    
    // Initialization
    bool                Initialize(string symbol, const TriangleConfig &config);
    void                Deinitialize();
    
    // Pattern Detection
    bool                DetectTrianglePattern(int lookback = 100);
    STrianglePattern    GetCurrentPattern() const { return m_currentPattern; }
    
    // Pattern Analysis
    bool                IsPatternActive() const { return m_currentPattern.isActive; }
    double              GetBreakoutProbability() const { return m_currentPattern.breakoutProbability; }
    double              GetTargetPrice() const { return m_currentPattern.targetPrice; }
    double              GetStopLossPrice() const { return m_currentPattern.stopLossPrice; }
    
    // Pattern Information
    TRIANGLE_TYPE       GetPatternType() const { return m_currentPattern.type; }
    double              GetConfidence() const { return m_currentPattern.confidence; }
    string              GetPatternTypeString() const;
    
    // Utility Methods
    void                ResetPattern();
    bool                UpdatePattern();
    void                LogPatternInfo();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGrandeTrianglePatternDetector::CGrandeTrianglePatternDetector()
{
    m_initialized = false;
    m_symbol = "";
    ZeroMemory(m_currentPattern);
    m_currentPattern.isActive = false;
    m_currentPattern.type = TRIANGLE_NONE;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGrandeTrianglePatternDetector::~CGrandeTrianglePatternDetector()
{
    Deinitialize();
}

//+------------------------------------------------------------------+
//| Initialize Triangle Pattern Detector                            |
//+------------------------------------------------------------------+
bool CGrandeTrianglePatternDetector::Initialize(string symbol, const TriangleConfig &config)
{
    if(symbol == "" || SymbolSelect(symbol, true) == false)
    {
        Print("❌ GrandeTrianglePatternDetector: Invalid symbol ", symbol);
        return false;
    }
    
    m_symbol = symbol;
    m_config = config;
    m_initialized = true;
    
    // Initialize arrays
    ArrayResize(m_highs, 0);
    ArrayResize(m_lows, 0);
    ArrayResize(m_volumes, 0);
    ArrayResize(m_times, 0);
    ArrayResize(m_swingPoints, 0);
    
    // Prevent duplicate init logs across multiple detector instances
    static bool s_initLogPrinted = false;
    if(!s_initLogPrinted)
    {
        Print("✅ GrandeTrianglePatternDetector initialized for ", m_symbol);
        s_initLogPrinted = true;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                     |
//+------------------------------------------------------------------+
void CGrandeTrianglePatternDetector::Deinitialize()
{
    m_initialized = false;
    ResetPattern();
    ArrayFree(m_highs);
    ArrayFree(m_lows);
    ArrayFree(m_volumes);
    ArrayFree(m_times);
    ArrayFree(m_swingPoints);
}

//+------------------------------------------------------------------+
//| Main Triangle Pattern Detection Method                          |
//+------------------------------------------------------------------+
bool CGrandeTrianglePatternDetector::DetectTrianglePattern(int lookback)
{
    if(!m_initialized)
    {
        Print("❌ GrandeTrianglePatternDetector not initialized");
        return false;
    }
    
    // Copy price data
    ArrayResize(m_highs, lookback);
    ArrayResize(m_lows, lookback);
    ArrayResize(m_volumes, lookback);
    ArrayResize(m_times, lookback);
    
    long volumes[];
    ArrayResize(volumes, lookback);
    
    if(CopyHigh(m_symbol, Period(), 0, lookback, m_highs) != lookback ||
       CopyLow(m_symbol, Period(), 0, lookback, m_lows) != lookback ||
       CopyTickVolume(m_symbol, Period(), 0, lookback, volumes) != lookback ||
       CopyTime(m_symbol, Period(), 0, lookback, m_times) != lookback)
    {
        Print("❌ Failed to copy price data for triangle detection");
        return false;
    }
    
    // Copy volume data to double array
    for(int i = 0; i < lookback; i++)
    {
        m_volumes[i] = (double)volumes[i];
    }
    
    // Set arrays as series (newest first)
    ArraySetAsSeries(m_highs, true);
    ArraySetAsSeries(m_lows, true);
    ArraySetAsSeries(m_volumes, true);
    ArraySetAsSeries(m_times, true);
    
    // Step 1: Detect swing points
    if(!DetectSwingPoints(lookback))
    {
        // Print("🔍 No valid swing points detected");
        return false;
    }
    
    // Step 2: Calculate trend lines
    if(!CalculateTrendLines())
    {
        // Print("🔍 No valid trend lines calculated");
        return false;
    }
    
    // Step 3: Validate triangle formation
    if(!ValidateTriangleFormation())
    {
        // Print("🔍 Triangle formation validation failed");
        return false;
    }
    
    // Step 4: Determine triangle type
    m_currentPattern.type = DetermineTriangleType();
    
    // Step 5: Calculate confidence and probabilities
    m_currentPattern.confidence = CalculatePatternConfidence();
    m_currentPattern.breakoutProbability = CalculateBreakoutProbability();
    
    // Step 6: Update targets
    UpdatePatternTargets();
    
    // Step 7: Validate volume pattern
    m_currentPattern.volumeConfirmed = ValidateVolumePattern();
    
    // Set pattern as active
    m_currentPattern.isActive = true;
    m_currentPattern.lastUpdate = TimeCurrent();
    m_currentPattern.timeframe = Period();
    
    // Log successful detection
    LogPatternInfo();
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect Swing Points using Grande's Enhanced Algorithm           |
//+------------------------------------------------------------------+
bool CGrandeTrianglePatternDetector::DetectSwingPoints(int lookback)
{
    ArrayResize(m_swingPoints, 0);
    
    // Use enhanced swing detection (similar to GrandeKeyLevelDetector)
    for(int i = 3; i < lookback - 3; i++)
    {
        // Check for swing high
        bool isSwingHigh = m_highs[i] > m_highs[i-1] && 
                          m_highs[i] > m_highs[i-2] &&
                          m_highs[i] > m_highs[i-3] &&
                          m_highs[i] > m_highs[i+1] && 
                          m_highs[i] > m_highs[i+2] &&
                          m_highs[i] > m_highs[i+3];
        
        // Check for swing low
        bool isSwingLow = m_lows[i] < m_lows[i-1] && 
                         m_lows[i] < m_lows[i-2] &&
                         m_lows[i] < m_lows[i-3] &&
                         m_lows[i] < m_lows[i+1] && 
                         m_lows[i] < m_lows[i+2] &&
                         m_lows[i] < m_lows[i+3];
        
        if(isSwingHigh)
        {
            SSwingPoint swing;
            swing.price = m_highs[i];
            swing.time = m_times[i];
            swing.barIndex = i;
            swing.isHigh = true;
            swing.strength = m_highs[i] - MathMin(MathMin(m_highs[i-1], m_highs[i-2]), MathMin(m_highs[i+1], m_highs[i+2]));
            swing.volume = m_volumes[i];
            ArrayResize(m_swingPoints, ArraySize(m_swingPoints) + 1);
            m_swingPoints[ArraySize(m_swingPoints) - 1] = swing;
        }
        
        if(isSwingLow)
        {
            SSwingPoint swing;
            swing.price = m_lows[i];
            swing.time = m_times[i];
            swing.barIndex = i;
            swing.isHigh = false;
            swing.strength = MathMax(MathMax(m_lows[i-1], m_lows[i-2]), MathMax(m_lows[i+1], m_lows[i+2])) - m_lows[i];
            swing.volume = m_volumes[i];
            ArrayResize(m_swingPoints, ArraySize(m_swingPoints) + 1);
            m_swingPoints[ArraySize(m_swingPoints) - 1] = swing;
        }
    }
    
    // Sort swing points by time (newest first)
    for(int i = 0; i < ArraySize(m_swingPoints) - 1; i++)
    {
        for(int j = i + 1; j < ArraySize(m_swingPoints); j++)
        {
            if(m_swingPoints[i].time < m_swingPoints[j].time)
            {
                SSwingPoint temp = m_swingPoints[i];
                m_swingPoints[i] = m_swingPoints[j];
                m_swingPoints[j] = temp;
            }
        }
    }
    
    return (ArraySize(m_swingPoints) >= 6); // Need at least 6 swing points for triangle
}

//+------------------------------------------------------------------+
//| Calculate Trend Lines from Swing Points                         |
//+------------------------------------------------------------------+
bool CGrandeTrianglePatternDetector::CalculateTrendLines()
{
    // Separate swing highs and lows
    SSwingPoint swingHighs[];
    SSwingPoint swingLows[];
    
    for(int i = 0; i < ArraySize(m_swingPoints); i++)
    {
        if(m_swingPoints[i].isHigh)
        {
            ArrayResize(swingHighs, ArraySize(swingHighs) + 1);
            swingHighs[ArraySize(swingHighs) - 1] = m_swingPoints[i];
        }
        else
        {
            ArrayResize(swingLows, ArraySize(swingLows) + 1);
            swingLows[ArraySize(swingLows) - 1] = m_swingPoints[i];
        }
    }
    
    if(ArraySize(swingHighs) < m_config.minTouchesResistance || 
       ArraySize(swingLows) < m_config.minTouchesSupport)
    {
        return false;
    }
    
    // Calculate resistance line (from swing highs)
    m_resistanceLine.slope = CalculateLineSlope(swingHighs, true);
    m_resistanceLine.touchCount = ArraySize(swingHighs);
    m_resistanceLine.startTime = swingHighs[ArraySize(swingHighs) - 1].time;
    m_resistanceLine.endTime = swingHighs[0].time;
    m_resistanceLine.startPrice = swingHighs[ArraySize(swingHighs) - 1].price;
    m_resistanceLine.endPrice = swingHighs[0].price;
    m_resistanceLine.isHorizontal = IsHorizontalLine(m_resistanceLine.slope);
    m_resistanceLine.levelPrice = (m_resistanceLine.startPrice + m_resistanceLine.endPrice) / 2.0;
    
    // Calculate support line (from swing lows)
    m_supportLine.slope = CalculateLineSlope(swingLows, false);
    m_supportLine.touchCount = ArraySize(swingLows);
    m_supportLine.startTime = swingLows[ArraySize(swingLows) - 1].time;
    m_supportLine.endTime = swingLows[0].time;
    m_supportLine.startPrice = swingLows[ArraySize(swingLows) - 1].price;
    m_supportLine.endPrice = swingLows[0].price;
    m_supportLine.isHorizontal = IsHorizontalLine(m_supportLine.slope);
    m_supportLine.levelPrice = (m_supportLine.startPrice + m_supportLine.endPrice) / 2.0;
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Line Slope using Linear Regression                    |
//+------------------------------------------------------------------+
double CGrandeTrianglePatternDetector::CalculateLineSlope(const SSwingPoint &points[], bool isHigh)
{
    if(ArraySize(points) < 2) return 0.0;
    
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    int n = ArraySize(points);
    
    for(int i = 0; i < n; i++)
    {
        double x = (double)(points[i].time - points[n-1].time) / 86400.0; // Convert to days
        double y = points[i].price;
        
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumXX += x * x;
    }
    
    double slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    return slope;
}

//+------------------------------------------------------------------+
//| Validate Triangle Formation                                      |
//+------------------------------------------------------------------+
bool CGrandeTrianglePatternDetector::ValidateTriangleFormation()
{
    // Check minimum touches
    if(m_resistanceLine.touchCount < m_config.minTouchesResistance ||
       m_supportLine.touchCount < m_config.minTouchesSupport)
    {
        return false;
    }
    
    // Check formation time
    double formationDays = (double)(m_resistanceLine.endTime - m_resistanceLine.startTime) / 86400.0;
    double formationBars = (double)ArraySize(m_highs) - (double)(m_resistanceLine.endTime - TimeCurrent()) / (double)PeriodSeconds(Period());
    
    if(formationBars < m_config.minFormationBars || formationBars > m_config.maxFormationBars)
    {
        return false;
    }
    
    // Check that lines are converging (for symmetrical triangles)
    if(!m_resistanceLine.isHorizontal && !m_supportLine.isHorizontal)
    {
        // Both lines have slope - check if they're converging
        if(MathAbs(m_resistanceLine.slope) < MathAbs(m_supportLine.slope))
        {
            // Resistance line is flatter - should be falling for convergence
            if(m_resistanceLine.slope > 0) return false;
        }
        else
        {
            // Support line is flatter - should be rising for convergence
            if(m_supportLine.slope < 0) return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Determine Triangle Type Based on Line Slopes                   |
//+------------------------------------------------------------------+
TRIANGLE_TYPE CGrandeTrianglePatternDetector::DetermineTriangleType()
{
    bool resHorizontal = IsHorizontalLine(m_resistanceLine.slope);
    bool supHorizontal = IsHorizontalLine(m_supportLine.slope);
    bool resRising = IsRisingLine(m_resistanceLine.slope);
    bool resFalling = IsFallingLine(m_resistanceLine.slope);
    bool supRising = IsRisingLine(m_supportLine.slope);
    bool supFalling = IsFallingLine(m_supportLine.slope);
    
    if(resHorizontal && supRising)
    {
        return TRIANGLE_ASCENDING;
    }
    else if(supHorizontal && resFalling)
    {
        return TRIANGLE_DESCENDING;
    }
    else if(resFalling && supRising)
    {
        // Check which line is steeper for wedge determination
        if(MathAbs(m_resistanceLine.slope) > MathAbs(m_supportLine.slope))
        {
            return TRIANGLE_WEDGE_FALLING;
        }
        else
        {
            return TRIANGLE_SYMMETRICAL;
        }
    }
    else if(resRising && supRising)
    {
        if(MathAbs(m_resistanceLine.slope) > MathAbs(m_supportLine.slope))
        {
            return TRIANGLE_WEDGE_RISING;
        }
        else
        {
            return TRIANGLE_SYMMETRICAL;
        }
    }
    else if(resFalling && supFalling)
    {
        if(MathAbs(m_supportLine.slope) > MathAbs(m_resistanceLine.slope))
        {
            return TRIANGLE_WEDGE_FALLING;
        }
        else
        {
            return TRIANGLE_SYMMETRICAL;
        }
    }
    
    return TRIANGLE_SYMMETRICAL; // Default fallback
}

//+------------------------------------------------------------------+
//| Calculate Pattern Confidence                                     |
//+------------------------------------------------------------------+
double CGrandeTrianglePatternDetector::CalculatePatternConfidence()
{
    double confidence = 0.0;
    
    // Touch count factor
    double touchScore = MathMin(1.0, 
        (m_resistanceLine.touchCount + m_supportLine.touchCount) / 10.0);
    confidence += touchScore * m_config.touchWeight;
    
    // Slope consistency factor
    double slopeScore = 0.0;
    if(m_currentPattern.type == TRIANGLE_ASCENDING)
    {
        // For ascending triangle, resistance should be horizontal
        slopeScore = IsHorizontalLine(m_resistanceLine.slope) ? 1.0 : 0.5;
    }
    else if(m_currentPattern.type == TRIANGLE_DESCENDING)
    {
        // For descending triangle, support should be horizontal
        slopeScore = IsHorizontalLine(m_supportLine.slope) ? 1.0 : 0.5;
    }
    else
    {
        // For symmetrical triangles, both lines should have opposite slopes
        slopeScore = (m_resistanceLine.slope * m_supportLine.slope < 0) ? 1.0 : 0.5;
    }
    confidence += slopeScore * m_config.slopeWeight;
    
    // Volume pattern factor
    double volumeScore = ValidateVolumePattern() ? 1.0 : 0.0;
    confidence += volumeScore * m_config.volumeWeight;
    
    // Formation time factor
    double formationBars = ArraySize(m_highs);
    double timeScore = MathMin(1.0, formationBars / 50.0); // Optimal around 50 bars
    confidence += timeScore * m_config.timeWeight;
    
    // Swing strength factor
    double avgStrength = 0.0;
    for(int i = 0; i < ArraySize(m_swingPoints); i++)
    {
        avgStrength += m_swingPoints[i].strength;
    }
    avgStrength /= ArraySize(m_swingPoints);
    double strengthScore = MathMin(1.0, avgStrength / (SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 100));
    confidence += strengthScore * m_config.strengthWeight;
    
    return MathMin(1.0, confidence);
}

//+------------------------------------------------------------------+
//| Calculate Breakout Probability                                   |
//+------------------------------------------------------------------+
double CGrandeTrianglePatternDetector::CalculateBreakoutProbability()
{
    double probability = 0.5; // Base probability
    
    // Triangle type affects probability
    switch(m_currentPattern.type)
    {
        case TRIANGLE_ASCENDING:
            probability = 0.75; // Higher probability of upward breakout
            break;
        case TRIANGLE_DESCENDING:
            probability = 0.25; // Higher probability of downward breakout
            break;
        case TRIANGLE_SYMMETRICAL:
            probability = 0.55; // Slight upward bias
            break;
        case TRIANGLE_WEDGE_RISING:
            probability = 0.35; // Bearish bias
            break;
        case TRIANGLE_WEDGE_FALLING:
            probability = 0.65; // Bullish bias
            break;
        default:
            probability = 0.5;
            break;
    }
    
    // Adjust based on confidence
    probability += (m_currentPattern.confidence - 0.5) * 0.2;
    
    // Adjust based on volume pattern
    if(m_currentPattern.volumeConfirmed)
    {
        probability += 0.1;
    }
    
    return MathMax(0.0, MathMin(1.0, probability));
}

//+------------------------------------------------------------------+
//| Validate Volume Pattern                                          |
//+------------------------------------------------------------------+
bool CGrandeTrianglePatternDetector::ValidateVolumePattern()
{
    if(ArraySize(m_volumes) < m_config.volumeLookbackBars)
        return false;
    
    // Calculate average volume during formation vs recent volume
    double formationVolume = 0.0;
    double recentVolume = 0.0;
    
    int formationBars = ArraySize(m_volumes) - 10; // Exclude last 10 bars
    for(int i = 10; i < formationBars; i++)
    {
        formationVolume += m_volumes[i];
    }
    formationVolume /= (formationBars - 10);
    
    for(int i = 0; i < 10; i++)
    {
        recentVolume += m_volumes[i];
    }
    recentVolume /= 10.0;
    
    // Volume should be decreasing during formation
    return (recentVolume < formationVolume * m_config.volumeDecreaseRatio);
}

//+------------------------------------------------------------------+
//| Update Pattern Targets                                           |
//+------------------------------------------------------------------+
void CGrandeTrianglePatternDetector::UpdatePatternTargets()
{
    // Calculate triangle height
    double triangleHeight = MathAbs(m_resistanceLine.levelPrice - m_supportLine.levelPrice);
    
    // Set resistance and support levels
    m_currentPattern.resistanceLevel = m_resistanceLine.levelPrice;
    m_currentPattern.supportLevel = m_supportLine.levelPrice;
    
    // Calculate targets based on triangle type
    switch(m_currentPattern.type)
    {
        case TRIANGLE_ASCENDING:
            // Target: triangle height projected upward from resistance
            m_currentPattern.targetPrice = m_currentPattern.resistanceLevel + triangleHeight;
            m_currentPattern.stopLossPrice = m_currentPattern.supportLevel - (triangleHeight * 0.5);
            break;
            
        case TRIANGLE_DESCENDING:
            // Target: triangle height projected downward from support
            m_currentPattern.targetPrice = m_currentPattern.supportLevel - triangleHeight;
            m_currentPattern.stopLossPrice = m_currentPattern.resistanceLevel + (triangleHeight * 0.5);
            break;
            
        default:
            // Symmetrical triangle - use triangle height
            m_currentPattern.targetPrice = m_currentPattern.resistanceLevel + triangleHeight;
            m_currentPattern.stopLossPrice = m_currentPattern.supportLevel - triangleHeight;
            break;
    }
}

//+------------------------------------------------------------------+
//| Helper Methods                                                   |
//+------------------------------------------------------------------+
bool CGrandeTrianglePatternDetector::IsHorizontalLine(double slope)
{
    return MathAbs(slope) < m_config.horizontalTolerance;
}

bool CGrandeTrianglePatternDetector::IsRisingLine(double slope)
{
    return slope > m_config.risingSlopeMin;
}

bool CGrandeTrianglePatternDetector::IsFallingLine(double slope)
{
    return slope < m_config.fallingSlopeMax;
}

//+------------------------------------------------------------------+
//| Public Methods                                                   |
//+------------------------------------------------------------------+
void CGrandeTrianglePatternDetector::ResetPattern()
{
    ZeroMemory(m_currentPattern);
    m_currentPattern.isActive = false;
    m_currentPattern.type = TRIANGLE_NONE;
    ZeroMemory(m_resistanceLine);
    ZeroMemory(m_supportLine);
    ArrayResize(m_swingPoints, 0);
}

bool CGrandeTrianglePatternDetector::UpdatePattern()
{
    if(!m_initialized) return false;
    
    // Re-detect pattern with current data
    return DetectTrianglePattern(100);
}

string CGrandeTrianglePatternDetector::GetPatternTypeString() const
{
    switch(m_currentPattern.type)
    {
        case TRIANGLE_ASCENDING:    return "ASCENDING";
        case TRIANGLE_DESCENDING:   return "DESCENDING";
        case TRIANGLE_SYMMETRICAL:  return "SYMMETRICAL";
        case TRIANGLE_WEDGE_RISING: return "RISING_WEDGE";
        case TRIANGLE_WEDGE_FALLING: return "FALLING_WEDGE";
        default:                    return "NONE";
    }
}

void CGrandeTrianglePatternDetector::LogPatternInfo()
{
    if(!m_currentPattern.isActive) return;
    
    Print("🔺 TRIANGLE PATTERN DETECTED:");
    Print("   Type: ", GetPatternTypeString());
    Print("   Confidence: ", DoubleToString(m_currentPattern.confidence * 100, 1), "%");
    Print("   Breakout Probability: ", DoubleToString(m_currentPattern.breakoutProbability * 100, 1), "%");
    Print("   Resistance: ", DoubleToString(m_currentPattern.resistanceLevel, _Digits));
    Print("   Support: ", DoubleToString(m_currentPattern.supportLevel, _Digits));
    Print("   Target: ", DoubleToString(m_currentPattern.targetPrice, _Digits));
    Print("   Stop Loss: ", DoubleToString(m_currentPattern.stopLossPrice, _Digits));
    Print("   Volume Confirmed: ", m_currentPattern.volumeConfirmed ? "YES" : "NO");
    Print("   Touches - Resistance: ", m_resistanceLine.touchCount, ", Support: ", m_supportLine.touchCount);
}
