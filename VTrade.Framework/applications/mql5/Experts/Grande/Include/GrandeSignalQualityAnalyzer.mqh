//+------------------------------------------------------------------+
//| GrandeSignalQualityAnalyzer.mqh                                  |
//| Copyright 2024, Grande Tech                                      |
//| Signal Quality Scoring and Validation Module                     |
//+------------------------------------------------------------------+
// PURPOSE:
//   Score signal quality and validate signal conditions for the
//   Grande Trading System. Filters low-quality signals before execution.
//
// RESPONSIBILITIES:
//   - Score signal quality/confidence
//   - Validate signal conditions
//   - Track signal success rates
//   - Identify high-quality signal patterns
//   - Filter low-quality signals
//
// DEPENDENCIES:
//   - GrandeStateManager.mqh - For signal history tracking
//   - GrandeEventBus.mqh - For signal quality events
//
// STATE MANAGED:
//   - Signal quality metrics
//   - Signal success rate history
//   - Quality thresholds
//
// PUBLIC INTERFACE:
//   bool Initialize(symbol, stateManager, eventBus)
//   double ScoreSignalQuality(signalType, regime, confidence, confluence) - Calculate quality score
//   bool ValidateSignalConditions(signalType, regime) - Check prerequisites
//   double GetSignalSuccessRate(signalType) - Historical success rate
//   bool FilterLowQualitySignals(qualityScore, threshold) - Reject weak signals
//   double GetOptimalSignalThreshold() - Dynamic threshold adjustment
//
// DATA STRUCTURES:
//   SignalQualityScore - Structure containing quality metrics
//
// IMPLEMENTATION NOTES:
//   - Quality scoring based on multiple factors (regime confidence, confluence, RSI, etc.)
//   - Dynamic threshold adjustment based on historical performance
//   - Integrates with State Manager for signal history
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestSignalQualityAnalyzer.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Signal quality scoring and validation module"

#include "GrandeStateManager.mqh"
#include "GrandeEventBus.mqh"

//+------------------------------------------------------------------+
//| Signal Quality Score Structure                                   |
//+------------------------------------------------------------------+
struct SignalQualityScore
{
    double overallScore;           // Overall quality score (0.0-1.0)
    double regimeConfidence;       // Regime confidence component
    double confluenceScore;        // Confluence factors component
    double technicalScore;         // Technical indicators component
    double sentimentScore;         // Sentiment analysis component
    bool isValid;                  // Whether signal passes validation
    string rejectionReason;        // Reason for rejection (if invalid)
    
    void SignalQualityScore()
    {
        overallScore = 0.0;
        regimeConfidence = 0.0;
        confluenceScore = 0.0;
        technicalScore = 0.0;
        sentimentScore = 0.0;
        isValid = false;
        rejectionReason = "";
    }
};

//+------------------------------------------------------------------+
//| Grande Signal Quality Analyzer Class                             |
//+------------------------------------------------------------------+
class CGrandeSignalQualityAnalyzer
{
private:
    string m_symbol;
    bool m_isInitialized;
    CGrandeStateManager* m_stateManager;
    CGrandeEventBus* m_eventBus;
    
    // Quality thresholds
    double m_minQualityThreshold;  // Minimum quality score to accept signal
    double m_highQualityThreshold; // High quality threshold
    bool m_enableDynamicThreshold; // Enable dynamic threshold adjustment
    
    // Signal history tracking
    struct SignalHistory
    {
        string signalType;
        double qualityScore;
        bool wasSuccessful;
        datetime timestamp;
    };
    
    SignalHistory m_signalHistory[];
    int m_historyCount;
    int m_maxHistorySize;
    
    // Helper methods
    double CalculateRegimeComponent(double regimeConfidence);
    double CalculateConfluenceComponent(int confluenceScore);
    double CalculateTechnicalComponent(double rsi, double adx);
    double CalculateSentimentComponent(double sentimentConfidence);
    
public:
    // Constructor/Destructor
    CGrandeSignalQualityAnalyzer();
    ~CGrandeSignalQualityAnalyzer();
    
    // Initialization
    bool Initialize(string symbol, CGrandeStateManager* stateManager, CGrandeEventBus* eventBus);
    
    // Signal Quality Scoring
    SignalQualityScore ScoreSignalQuality(string signalType, double regimeConfidence, 
                                          int confluenceScore, double rsi, double adx, 
                                          double sentimentConfidence);
    
    // Signal Validation
    bool ValidateSignalConditions(string signalType, double regimeConfidence, 
                                  int confluenceScore, double rsi);
    
    // Signal Filtering
    bool FilterLowQualitySignals(double qualityScore, double threshold = -1.0);
    
    // Performance Tracking
    double GetSignalSuccessRate(string signalType);
    void RecordSignalOutcome(string signalType, double qualityScore, bool wasSuccessful);
    
    // Threshold Management
    double GetOptimalSignalThreshold();
    void SetMinQualityThreshold(double threshold);
    double GetMinQualityThreshold() const { return m_minQualityThreshold; }
    
    // Utility Methods
    string GetQualityDescription(double qualityScore);
    bool IsHighQualitySignal(double qualityScore);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandeSignalQualityAnalyzer::CGrandeSignalQualityAnalyzer()
{
    m_symbol = "";
    m_isInitialized = false;
    m_stateManager = NULL;
    m_eventBus = NULL;
    m_minQualityThreshold = 0.6;  // Default: 60% quality required
    m_highQualityThreshold = 0.8; // Default: 80% for high quality
    m_enableDynamicThreshold = true;
    m_historyCount = 0;
    m_maxHistorySize = 1000;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CGrandeSignalQualityAnalyzer::~CGrandeSignalQualityAnalyzer()
{
}

//+------------------------------------------------------------------+
//| Initialize Signal Quality Analyzer                               |
//+------------------------------------------------------------------+
bool CGrandeSignalQualityAnalyzer::Initialize(string symbol, CGrandeStateManager* stateManager, CGrandeEventBus* eventBus)
{
    if(symbol == "")
    {
        Print("[GrandeSignalQuality] ERROR: Invalid symbol");
        return false;
    }
    
    m_symbol = symbol;
    m_stateManager = stateManager;
    m_eventBus = eventBus;
    m_isInitialized = true;
    
    return true;
}

//+------------------------------------------------------------------+
//| Score Signal Quality                                              |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate overall signal quality score based on multiple factors.
//
// PARAMETERS:
//   signalType (string) - Signal type (TREND, BREAKOUT, RANGE)
//   regimeConfidence (double) - Regime confidence (0.0-1.0)
//   confluenceScore (int) - Confluence factors count
//   rsi (double) - RSI value
//   adx (double) - ADX value
//   sentimentConfidence (double) - Sentiment confidence (0.0-1.0)
//
// RETURNS:
//   (SignalQualityScore) - Complete quality score structure
//
// NOTES:
//   - Overall score is weighted average of components
//   - Weights: Regime 40%, Confluence 25%, Technical 20%, Sentiment 15%
//+------------------------------------------------------------------+
SignalQualityScore CGrandeSignalQualityAnalyzer::ScoreSignalQuality(string signalType, double regimeConfidence, 
                                                                     int confluenceScore, double rsi, double adx, 
                                                                     double sentimentConfidence)
{
    SignalQualityScore score;
    
    if(!m_isInitialized)
    {
        score.rejectionReason = "Signal quality analyzer not initialized";
        return score;
    }
    
    // Calculate component scores
    score.regimeConfidence = CalculateRegimeComponent(regimeConfidence);
    score.confluenceScore = CalculateConfluenceComponent(confluenceScore);
    score.technicalScore = CalculateTechnicalComponent(rsi, adx);
    score.sentimentScore = CalculateSentimentComponent(sentimentConfidence);
    
    // Calculate weighted overall score
    score.overallScore = (score.regimeConfidence * 0.40) +
                        (score.confluenceScore * 0.25) +
                        (score.technicalScore * 0.20) +
                        (score.sentimentScore * 0.15);
    
    // Validate signal
    score.isValid = ValidateSignalConditions(signalType, regimeConfidence, confluenceScore, rsi);
    
    if(!score.isValid)
        score.rejectionReason = "Signal conditions not met";
    
    return score;
}

//+------------------------------------------------------------------+
//| Calculate Regime Component                                        |
//+------------------------------------------------------------------+
double CGrandeSignalQualityAnalyzer::CalculateRegimeComponent(double regimeConfidence)
{
    // Regime confidence directly contributes to quality
    // Higher confidence = higher quality
    return MathMax(0.0, MathMin(1.0, regimeConfidence));
}

//+------------------------------------------------------------------+
//| Calculate Confluence Component                                    |
//+------------------------------------------------------------------+
double CGrandeSignalQualityAnalyzer::CalculateConfluenceComponent(int confluenceScore)
{
    // Confluence score normalized to 0-1 range
    // Assuming max confluence score of 5
    return MathMax(0.0, MathMin(1.0, (double)confluenceScore / 5.0));
}

//+------------------------------------------------------------------+
//| Calculate Technical Component                                     |
//+------------------------------------------------------------------+
double CGrandeSignalQualityAnalyzer::CalculateTechnicalComponent(double rsi, double adx)
{
    // Combine RSI and ADX into technical score
    // RSI: Prefer values not in extreme overbought/oversold (30-70 range)
    double rsiScore = 1.0;
    if(rsi > 70 || rsi < 30)
        rsiScore = 0.5; // Reduced score for extreme RSI
    else if(rsi > 60 || rsi < 40)
        rsiScore = 0.8; // Slightly reduced for approaching extremes
    
    // ADX: Higher ADX = stronger trend = better quality
    double adxScore = MathMin(1.0, adx / 50.0); // Normalize to 0-1 (50 ADX = 1.0)
    
    // Average of RSI and ADX scores
    return (rsiScore + adxScore) / 2.0;
}

//+------------------------------------------------------------------+
//| Calculate Sentiment Component                                     |
//+------------------------------------------------------------------+
double CGrandeSignalQualityAnalyzer::CalculateSentimentComponent(double sentimentConfidence)
{
    // Sentiment confidence directly contributes
    return MathMax(0.0, MathMin(1.0, sentimentConfidence));
}

//+------------------------------------------------------------------+
//| Validate Signal Conditions                                        |
//+------------------------------------------------------------------+
// PURPOSE:
//   Check if signal meets minimum prerequisites for execution.
//
// PARAMETERS:
//   signalType (string) - Signal type
//   regimeConfidence (double) - Regime confidence
//   confluenceScore (int) - Confluence factors
//   rsi (double) - RSI value
//
// RETURNS:
//   (bool) - true if conditions met, false otherwise
//+------------------------------------------------------------------+
bool CGrandeSignalQualityAnalyzer::ValidateSignalConditions(string signalType, double regimeConfidence, 
                                                             int confluenceScore, double rsi)
{
    // Minimum regime confidence required
    if(regimeConfidence < 0.5)
        return false;
    
    // Minimum confluence factors required
    if(confluenceScore < 2)
        return false;
    
    // RSI should not be in extreme territory
    if(rsi > 80 || rsi < 20)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Filter Low Quality Signals                                        |
//+------------------------------------------------------------------+
// PURPOSE:
//   Determine if signal should be rejected based on quality score.
//
// PARAMETERS:
//   qualityScore (double) - Signal quality score (0.0-1.0)
//   threshold (double) - Quality threshold (-1.0 to use default)
//
// RETURNS:
//   (bool) - true if signal should be rejected, false if accepted
//+------------------------------------------------------------------+
bool CGrandeSignalQualityAnalyzer::FilterLowQualitySignals(double qualityScore, double threshold = -1.0)
{
    double useThreshold = (threshold >= 0.0) ? threshold : m_minQualityThreshold;
    
    if(m_enableDynamicThreshold)
        useThreshold = GetOptimalSignalThreshold();
    
    return qualityScore < useThreshold;
}

//+------------------------------------------------------------------+
//| Get Signal Success Rate                                           |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate historical success rate for a signal type.
//
// PARAMETERS:
//   signalType (string) - Signal type to analyze
//
// RETURNS:
//   (double) - Success rate percentage (0-100)
//
// NOTES:
//   - Requires signal history to be populated
//   - Returns 0.0 if no history available
//+------------------------------------------------------------------+
double CGrandeSignalQualityAnalyzer::GetSignalSuccessRate(string signalType)
{
    if(m_historyCount == 0)
        return 0.0;
    
    int totalSignals = 0;
    int successfulSignals = 0;
    
    for(int i = 0; i < m_historyCount; i++)
    {
        if(m_signalHistory[i].signalType == signalType)
        {
            totalSignals++;
            if(m_signalHistory[i].wasSuccessful)
                successfulSignals++;
        }
    }
    
    if(totalSignals == 0)
        return 0.0;
    
    return (double)successfulSignals / totalSignals * 100.0;
}

//+------------------------------------------------------------------+
//| Record Signal Outcome                                             |
//+------------------------------------------------------------------+
// PURPOSE:
//   Record signal outcome for success rate tracking.
//
// PARAMETERS:
//   signalType (string) - Signal type
//   qualityScore (double) - Quality score of the signal
//   wasSuccessful (bool) - Whether signal resulted in profitable trade
//
// SIDE EFFECTS:
//   - Adds to signal history
//   - Updates success rate calculations
//+------------------------------------------------------------------+
void CGrandeSignalQualityAnalyzer::RecordSignalOutcome(string signalType, double qualityScore, bool wasSuccessful)
{
    if(m_historyCount >= m_maxHistorySize)
    {
        // Remove oldest entry (simple FIFO)
        for(int i = 0; i < m_historyCount - 1; i++)
            m_signalHistory[i] = m_signalHistory[i + 1];
        m_historyCount--;
    }
    
    SignalHistory history;
    history.signalType = signalType;
    history.qualityScore = qualityScore;
    history.wasSuccessful = wasSuccessful;
    history.timestamp = TimeCurrent();
    
    ArrayResize(m_signalHistory, m_historyCount + 1);
    m_signalHistory[m_historyCount] = history;
    m_historyCount++;
}

//+------------------------------------------------------------------+
//| Get Optimal Signal Threshold                                      |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate optimal quality threshold based on historical performance.
//
// RETURNS:
//   (double) - Optimal threshold value (0.0-1.0)
//
// NOTES:
//   - Adjusts threshold based on recent signal success rates
//   - Returns default threshold if insufficient data
//+------------------------------------------------------------------+
double CGrandeSignalQualityAnalyzer::GetOptimalSignalThreshold()
{
    if(m_historyCount < 50) // Need at least 50 signals for dynamic adjustment
        return m_minQualityThreshold;
    
    // Calculate average success rate for recent signals
    int recentCount = MathMin(100, m_historyCount);
    int successful = 0;
    
    for(int i = m_historyCount - recentCount; i < m_historyCount; i++)
    {
        if(m_signalHistory[i].wasSuccessful)
            successful++;
    }
    
    double successRate = (double)successful / recentCount;
    
    // Adjust threshold based on success rate
    // If success rate is high, can lower threshold slightly
    // If success rate is low, raise threshold
    if(successRate > 0.7)
        return MathMax(0.5, m_minQualityThreshold - 0.1);
    else if(successRate < 0.5)
        return MathMin(0.8, m_minQualityThreshold + 0.1);
    
    return m_minQualityThreshold;
}

//+------------------------------------------------------------------+
//| Set Minimum Quality Threshold                                     |
//+------------------------------------------------------------------+
void CGrandeSignalQualityAnalyzer::SetMinQualityThreshold(double threshold)
{
    m_minQualityThreshold = MathMax(0.0, MathMin(1.0, threshold));
}

//+------------------------------------------------------------------+
//| Get Quality Description                                           |
//+------------------------------------------------------------------+
string CGrandeSignalQualityAnalyzer::GetQualityDescription(double qualityScore)
{
    if(qualityScore >= 0.8)
        return "HIGH";
    else if(qualityScore >= 0.6)
        return "MEDIUM";
    else if(qualityScore >= 0.4)
        return "LOW";
    else
        return "VERY_LOW";
}

//+------------------------------------------------------------------+
//| Check if High Quality Signal                                      |
//+------------------------------------------------------------------+
bool CGrandeSignalQualityAnalyzer::IsHighQualitySignal(double qualityScore)
{
    return qualityScore >= m_highQualityThreshold;
}

//+------------------------------------------------------------------+

