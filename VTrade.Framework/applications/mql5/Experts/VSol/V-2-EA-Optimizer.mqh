//+------------------------------------------------------------------+
//|                                          V-2-EA-Optimizer.mqh |
//|                                   Optimization Implementation |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"

//--- Include required base classes and utilities
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//--- Optimization Constants
#define OPT_MIN_TRADES           50     // Minimum trades for optimization
#define OPT_MIN_MONTHS           6      // Minimum months of data
#define OPT_MAX_PARAMETERS      20     // Maximum parameters to optimize
#define OPT_MAX_ITERATIONS      1000   // Maximum optimization iterations
#define OPT_MIN_IMPROVEMENT     0.01   // Minimum improvement threshold
#define OPT_CONFIDENCE_LEVEL    95.0   // Statistical confidence level
#define OPT_MAX_CORRELATION     0.7    // Maximum parameter correlation
#define OPT_MIN_PROFIT_FACTOR   1.3    // Minimum profit factor threshold

//--- Optimization Method Types
enum ENUM_OPTIMIZATION_METHOD
{
    OPT_METHOD_NONE = 0,        // No optimization
    OPT_METHOD_GRID,            // Grid search
    OPT_METHOD_GENETIC,         // Genetic algorithm
    OPT_METHOD_MONTECARLO,      // Monte Carlo simulation
    OPT_METHOD_WALK_FORWARD,    // Walk-forward analysis
    OPT_METHOD_HYBRID          // Hybrid approach
};

//--- Parameter Types
enum ENUM_PARAMETER_TYPE
{
    PARAM_TYPE_NONE = 0,        // No specific type
    PARAM_TYPE_INTEGER,         // Integer parameter
    PARAM_TYPE_DOUBLE,          // Double parameter
    PARAM_TYPE_BOOLEAN,         // Boolean parameter
    PARAM_TYPE_ENUM            // Enumeration parameter
};

//--- Parameter Structure
struct SParameter
{
    string            name;              // Parameter name
    ENUM_PARAMETER_TYPE type;           // Parameter type
    double            currentValue;      // Current value
    double            minValue;         // Minimum value
    double            maxValue;         // Maximum value
    double            step;             // Step size
    bool              isEnabled;        // Optimization enabled
    double            optimalValue;     // Optimal value found
    double            sensitivity;      // Parameter sensitivity
    
    void Reset()
    {
        name = "";
        type = PARAM_TYPE_NONE;
        currentValue = 0.0;
        minValue = 0.0;
        maxValue = 0.0;
        step = 0.0;
        isEnabled = false;
        optimalValue = 0.0;
        sensitivity = 0.0;
    }
};

//--- Optimization Result Structure
struct SOptimizationResult
{
    double            netProfit;         // Net profit
    double            profitFactor;      // Profit factor
    double            maxDrawdown;       // Maximum drawdown
    double            recoveryFactor;    // Recovery factor
    double            sharpeRatio;       // Sharpe ratio
    double            winRate;           // Win rate
    int               totalTrades;       // Total trades
    double            expectancy;        // System expectancy
    double            zScore;           // Statistical z-score
    string            comments;         // Additional comments
    
    void Reset()
    {
        netProfit = 0.0;
        profitFactor = 0.0;
        maxDrawdown = 0.0;
        recoveryFactor = 0.0;
        sharpeRatio = 0.0;
        winRate = 0.0;
        totalTrades = 0;
        expectancy = 0.0;
        zScore = 0.0;
        comments = "";
    }
};

//--- Optimization State Structure
struct SOptimizationState
{
    bool              isRunning;          // Optimization in progress
    int               currentIteration;   // Current iteration
    int               totalIterations;    // Total iterations
    double            bestFitness;       // Best fitness value
    double            currentFitness;    // Current fitness value
    datetime          startTime;         // Start time
    datetime          endTime;           // End time
    string            currentPhase;      // Current optimization phase
    string            lastError;         // Last error message
    
    void Reset()
    {
        isRunning = false;
        currentIteration = 0;
        totalIterations = 0;
        bestFitness = 0.0;
        currentFitness = 0.0;
        startTime = 0;
        endTime = 0;
        currentPhase = "";
        lastError = "";
    }
};

//+------------------------------------------------------------------+
//| Main Optimizer Class                                               |
//+------------------------------------------------------------------+
class CV2EABreakoutOptimizer : public CV2EAMarketDataBase
{
private:
    //--- State Management
    SOptimizationState  m_state;          // Optimization state
    SParameter          m_parameters[];    // Parameter array
    SOptimizationResult m_bestResult;     // Best result found
    
    //--- Configuration
    ENUM_OPTIMIZATION_METHOD m_method;     // Optimization method
    int                m_minTrades;        // Minimum trades required
    int                m_minMonths;        // Minimum months of data
    int                m_maxIterations;    // Maximum iterations
    double             m_minImprovement;   // Minimum improvement
    double             m_confidenceLevel;  // Confidence level
    double             m_maxCorrelation;   // Maximum correlation
    
    //--- Private Methods
    bool               ValidateParameters();
    double             CalculateFitness(const SOptimizationResult &result);
    bool               UpdateParameters(const double fitness);
    void               AnalyzeResults();
    bool               CheckStatisticalSignificance();
    double             CalculateParameterCorrelation();
    void               UpdateOptimizationMetrics();
    
protected:
    //--- Protected utility methods
    virtual bool       IsOptimizationValid();
    virtual bool       ShouldContinueOptimization();
    virtual bool       ValidateResult(const SOptimizationResult &result);
    virtual double     GetOptimizationProgress();

public:
    //--- Constructor and Destructor
    CV2EABreakoutOptimizer(void);
    ~CV2EABreakoutOptimizer(void);
    
    //--- Initialization and Configuration
    virtual bool       Initialize(void);
    virtual void       ConfigureOptimizer(
                           const ENUM_OPTIMIZATION_METHOD method,
                           const int minTrades,
                           const int maxIter,
                           const double minImpr
                       );
    
    //--- Parameter Management Methods
    virtual bool       AddParameter(
                           const string name,
                           const ENUM_PARAMETER_TYPE type,
                           const double minValue,
                           const double maxValue,
                           const double step
                       );
    virtual bool       RemoveParameter(const string name);
    virtual bool       EnableParameter(const string name, const bool enable);
    virtual bool       SetParameterValue(const string name, const double value);
    
    //--- Optimization Methods
    virtual bool       StartOptimization();
    virtual bool       StopOptimization();
    virtual bool       PauseOptimization();
    virtual bool       ResumeOptimization();
    virtual bool       ResetOptimization();
    
    //--- Analysis Methods
    virtual bool       AnalyzeParameter(const string name);
    virtual bool       PerformSensitivityAnalysis();
    virtual bool       ValidateOptimizationResults();
    virtual bool       PerformWalkForwardAnalysis();
    virtual bool       AnalyzeParameterCorrelations();
    
    //--- Result Management Methods
    virtual bool       SaveResults(const string filename);
    virtual bool       LoadResults(const string filename);
    virtual bool       ExportResults(const string filename);
    virtual bool       GenerateReport(const string filename);
    
    //--- Utility Methods
    virtual void       GetOptimizationState(SOptimizationState &state) const;
    virtual void       GetBestResult(SOptimizationResult &result) const;
    virtual bool       GetParameterInfo(const string name, SParameter &param) const;
    virtual string     GetLastError() const;
    virtual double     GetOptimizationQuality() const;
    
    //--- Event Handlers
    virtual void       OnIterationComplete();
    virtual void       OnNewBestResult();
    virtual void       OnOptimizationComplete();
    virtual void       OnOptimizationError(const string error);
}; 