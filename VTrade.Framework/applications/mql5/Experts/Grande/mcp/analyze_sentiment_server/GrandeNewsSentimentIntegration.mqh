//+------------------------------------------------------------------+
//| GrandeNewsSentimentIntegration.mqh                               |
//| Integration with Grande Sentiment Server for MQL5               |
//| Copyright 2025, Grande Trading System                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Grande Trading System"
#property link      ""
#property version   "1.00"
#property strict


// DLL import for launching external process (enable "Allow DLL imports" in EA settings)
#import "shell32.dll"
int ShellExecuteW(int hwnd, string Operation, string File, string Parameters, string Directory, int ShowCmd);
#import



//+------------------------------------------------------------------+
//| News Sentiment Integration Class                                |
//+------------------------------------------------------------------+
class CNewsSentimentIntegration
{
private:
    string            m_sentiment_server_url;
    string            m_news_analysis_file;
    string            m_calendar_analysis_file;
    datetime          m_last_analysis_time;
    int               m_analysis_interval; // seconds
    
    // News sentiment data structure
    struct NewsSentimentData
    {
        string        signal;           // BUY, SELL, NEUTRAL, STRONG_BUY, STRONG_SELL
        double        strength;         // 0.0 to 1.0
        double        confidence;       // 0.0 to 1.0
        string        reasoning;        // Human readable reasoning
        int           article_count;    // Number of articles analyzed
        string        sources[];        // News sources
        double        avg_sentiment;    // Average sentiment score
        datetime      timestamp;        // Analysis timestamp
    };
    
    struct CalendarSentimentData
    {
        string        signal;           // STRONG_BUY/BUY/NEUTRAL/SELL/STRONG_SELL
        double        score;            // -1..1
        double        confidence;       // 0..1
        string        reasoning;        // Explanation
        int           event_count;      // Events analyzed
        datetime      timestamp;        // Analysis time
        
        // Enhanced metrics from research validation
        double        surprise_accuracy;     // 0..1
        double        signal_consistency;    // 0..1
        double        processing_time_ms;    // Processing time
        int           high_confidence_count; // High confidence predictions
        double        average_confidence;    // Average confidence across events
    };
    
    NewsSentimentData m_current_sentiment;
    CalendarSentimentData m_calendar_sentiment;
    
public:
    CNewsSentimentIntegration();
    ~CNewsSentimentIntegration();
    
    // Initialization
    bool              Initialize(string server_url = "http://localhost:8000");
    void              SetAnalysisInterval(int seconds) { m_analysis_interval = seconds; }
    
    // News analysis
    bool              RunNewsAnalysis();
    bool              LoadLatestAnalysis();
    bool              IsAnalysisFresh();
    
    // Calendar analysis
    bool              RunCalendarAnalysis();
    bool              LoadLatestCalendarAnalysis();
    
    // Sentiment data access
    string            GetCurrentSignal() { return m_current_sentiment.signal; }
    double            GetCurrentStrength() { return m_current_sentiment.strength; }
    double            GetCurrentConfidence() { return m_current_sentiment.confidence; }
    string            GetCurrentReasoning() { return m_current_sentiment.reasoning; }
    int               GetArticleCount() { return m_current_sentiment.article_count; }
    double            GetAverageSentiment() { return m_current_sentiment.avg_sentiment; }
    
    // Calendar data access
    string            GetCalendarSignal() { return m_calendar_sentiment.signal; }
    double            GetCalendarScore() { return m_calendar_sentiment.score; }
    double            GetCalendarConfidence() { return m_calendar_sentiment.confidence; }
    string            GetCalendarReasoning() { return m_calendar_sentiment.reasoning; }
    int               GetEventCount() { return m_calendar_sentiment.event_count; }
    
    // Enhanced metrics access
    double            GetSurpriseAccuracy() { return m_calendar_sentiment.surprise_accuracy; }
    double            GetSignalConsistency() { return m_calendar_sentiment.signal_consistency; }
    double            GetProcessingTime() { return m_calendar_sentiment.processing_time_ms; }
    int               GetHighConfidenceCount() { return m_calendar_sentiment.high_confidence_count; }
    
    // Trading signal integration
    bool              ShouldEnterLong();
    bool              ShouldEnterShort();
    bool              ShouldExitPosition();
    double            GetSentimentWeight();
    
    // Utility functions
    string            GetSentimentDescription();
    void              PrintSentimentInfo();
    void              PrintEnhancedMetrics();
    bool              IsSentimentServerRunning();
    
private:
    bool              ParseSentimentData(string json_data);
    bool              ParseCalendarSentimentData(string json_data);
    bool              AnalyzeCalendarInline();
    string            ExecutePythonScript(string script_path);
    bool              ValidateSentimentData();
    
    // File-based analysis methods  
    bool              LoadEconomicEventsFromFile(string &events_json);
    bool              RunCalendarAnalysisFileBased();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CNewsSentimentIntegration::CNewsSentimentIntegration()
{
    m_sentiment_server_url = "http://localhost:8000";
    m_news_analysis_file = "integrated_news_analysis.json";
    m_calendar_analysis_file = "integrated_calendar_analysis.json";
    m_last_analysis_time = 0;
    m_analysis_interval = 300; // 5 minutes default
    
    // Initialize sentiment data
    m_current_sentiment.signal = "NEUTRAL";
    m_current_sentiment.strength = 0.0;
    m_current_sentiment.confidence = 0.0;
    m_current_sentiment.reasoning = "No analysis available";
    m_current_sentiment.article_count = 0;
    m_current_sentiment.avg_sentiment = 0.0;
    m_current_sentiment.timestamp = 0;

    // Initialize calendar data
    m_calendar_sentiment.signal = "NEUTRAL";
    m_calendar_sentiment.score = 0.0;
    m_calendar_sentiment.confidence = 0.0;
    m_calendar_sentiment.reasoning = "No calendar analysis available";
    m_calendar_sentiment.event_count = 0;
    m_calendar_sentiment.timestamp = 0;
    m_calendar_sentiment.surprise_accuracy = 0.0;
    m_calendar_sentiment.signal_consistency = 0.0;
    m_calendar_sentiment.processing_time_ms = 0.0;
    m_calendar_sentiment.high_confidence_count = 0;
    m_calendar_sentiment.average_confidence = 0.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CNewsSentimentIntegration::~CNewsSentimentIntegration()
{
    // Cleanup if needed
}

//+------------------------------------------------------------------+
//| Initialize the news sentiment integration                        |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::Initialize(string server_url = "http://localhost:8000")
{
    m_sentiment_server_url = server_url;
    
    Print("Grande News Sentiment Integration: Initializing...");
    
    // Check if sentiment server is running
    if (!IsSentimentServerRunning())
    {
        Print("ERROR: Sentiment server is not running!");
        Print("Please start it with: docker compose up -d");
        return false;
    }
    
    // Load latest analysis if available
    LoadLatestAnalysis();
    
    Print("Grande News Sentiment Integration: Initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Run news analysis using the integrated system                    |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::RunNewsAnalysis()
{
    // News analysis completely disabled - using stale data was causing 0% success rate
    Print("Grande News Sentiment: News analysis DISABLED - stale data removed for system reliability.");
    return false;
}

//+------------------------------------------------------------------+
//| Load the latest news analysis results                            |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::LoadLatestAnalysis()
{
    // News analysis disabled - no longer loading stale data
    Print("Grande News Sentiment: News analysis DISABLED - not loading stale data.");
    
    // Reset sentiment data to neutral
    m_current_sentiment.signal = "NEUTRAL";
    m_current_sentiment.strength = 0.0;
    m_current_sentiment.confidence = 0.0;
    m_current_sentiment.reasoning = "News analysis disabled - stale data removed";
    m_current_sentiment.article_count = 0;
    m_current_sentiment.avg_sentiment = 0.0;
    m_current_sentiment.timestamp = TimeCurrent();
    
    return true;
}

//+------------------------------------------------------------------+
//| Run calendar analysis using file-based FinBERT analyzer        |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::RunCalendarAnalysis()
{
    return RunCalendarAnalysisFileBased();
}

//+------------------------------------------------------------------+
//| Load the latest calendar analysis results                        |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::LoadLatestCalendarAnalysis()
{
    // Try Common then Local
    string file_path = m_calendar_analysis_file;
    int fh = FileOpen(file_path, FILE_READ|FILE_TXT|FILE_COMMON);
    if(fh == INVALID_HANDLE)
        fh = FileOpen(file_path, FILE_READ|FILE_TXT);
    if(fh == INVALID_HANDLE)
        return false;
    string json_data = "";
    while(!FileIsEnding(fh))
        json_data += FileReadString(fh);
    FileClose(fh);
    return ParseCalendarSentimentData(json_data);
}

//+------------------------------------------------------------------+
//| Check if analysis is fresh (within interval)                    |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::IsAnalysisFresh()
{
    if (m_last_analysis_time == 0)
        return false;
    
    return (TimeCurrent() - m_last_analysis_time) < m_analysis_interval;
}

//+------------------------------------------------------------------+
//| Determine if should enter long position based on sentiment       |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::ShouldEnterLong()
{
    // News analysis disabled - always return false to prevent bad decisions
    Print("Grande News Sentiment: ShouldEnterLong() DISABLED - news analysis removed");
    return false;
}

//+------------------------------------------------------------------+
//| Determine if should enter short position based on sentiment      |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::ShouldEnterShort()
{
    // News analysis disabled - always return false to prevent bad decisions
    Print("Grande News Sentiment: ShouldEnterShort() DISABLED - news analysis removed");
    return false;
}

//+------------------------------------------------------------------+
//| Determine if should exit current position                        |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::ShouldExitPosition()
{
    // News analysis disabled - always return false to prevent bad decisions
    Print("Grande News Sentiment: ShouldExitPosition() DISABLED - news analysis removed");
    return false;
}

//+------------------------------------------------------------------+
//| Get sentiment weight for position sizing                         |
//+------------------------------------------------------------------+
double CNewsSentimentIntegration::GetSentimentWeight()
{
    if (!ValidateSentimentData())
        return 0.0;
    
    // Calculate weight based on strength and confidence
    double weight = m_current_sentiment.strength * m_current_sentiment.confidence;
    
    // Normalize to 0.0 - 1.0 range
    return MathMax(0.0, MathMin(1.0, weight));
}

//+------------------------------------------------------------------+
//| Get human readable sentiment description                         |
//+------------------------------------------------------------------+
string CNewsSentimentIntegration::GetSentimentDescription()
{
    if (!ValidateSentimentData())
        return "No sentiment data available";
    
    string description = StringFormat("Signal: %s | Strength: %.3f | Confidence: %.3f | Articles: %d",
        m_current_sentiment.signal,
        m_current_sentiment.strength,
        m_current_sentiment.confidence,
        m_current_sentiment.article_count);
    
    return description;
}

//+------------------------------------------------------------------+
//| Print sentiment information to log                               |
//+------------------------------------------------------------------+
void CNewsSentimentIntegration::PrintSentimentInfo()
{
    Print("=== GRANDE NEWS SENTIMENT ANALYSIS ===");
    Print("Signal: ", m_current_sentiment.signal);
    Print("Strength: ", DoubleToString(m_current_sentiment.strength, 3));
    Print("Confidence: ", DoubleToString(m_current_sentiment.confidence, 3));
    Print("Average Sentiment: ", DoubleToString(m_current_sentiment.avg_sentiment, 3));
    Print("Articles Analyzed: ", m_current_sentiment.article_count);
    Print("Reasoning: ", m_current_sentiment.reasoning);
    Print("=====================================");
}

//+------------------------------------------------------------------+
//| Print enhanced research metrics                                  |
//+------------------------------------------------------------------+
void CNewsSentimentIntegration::PrintEnhancedMetrics()
{
    Print("=== GRANDE ENHANCED FINBERT METRICS ===");
    Print("Signal: ", m_calendar_sentiment.signal);
    Print("Score: ", DoubleToString(m_calendar_sentiment.score, 3));
    Print("Confidence: ", DoubleToString(m_calendar_sentiment.confidence, 3));
    Print("Events Analyzed: ", m_calendar_sentiment.event_count);
    Print("High Confidence Predictions: ", m_calendar_sentiment.high_confidence_count, "/", m_calendar_sentiment.event_count);
    Print("Surprise Accuracy: ", DoubleToString(m_calendar_sentiment.surprise_accuracy, 3));
    Print("Signal Consistency: ", DoubleToString(m_calendar_sentiment.signal_consistency, 3));
    Print("Processing Time: ", DoubleToString(m_calendar_sentiment.processing_time_ms, 1), "ms");
    Print("Average Confidence: ", DoubleToString(m_calendar_sentiment.average_confidence, 3));
    Print("Reasoning: ", m_calendar_sentiment.reasoning);
    Print("=========================================");
}

//+------------------------------------------------------------------+
//| Check if sentiment server is running                            |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::IsSentimentServerRunning()
{
    // File-based analysis is always available if Python script exists
    return true;
}

//+------------------------------------------------------------------+
//| Parse sentiment data from JSON string                            |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::ParseSentimentData(string json_data)
{
    // Simple JSON parsing for MQL5 (in production, use a proper JSON library)
    // This is a simplified version - in practice, you'd use a JSON parsing library
    
    // Extract signal (string)
    string pattern_signal = "\"signal\": \"";
    int signal_start = StringFind(json_data, pattern_signal);
    if (signal_start >= 0)
    {
        signal_start += StringLen(pattern_signal);
        int signal_end = StringFind(json_data, "\"", signal_start);
        if (signal_end > signal_start)
        {
            m_current_sentiment.signal = StringSubstr(json_data, signal_start, signal_end - signal_start);
        }
    }
    
    // Helper lambda-like pattern: find end at comma, otherwise closing brace
    // Note: MQL5 doesn't support lambdas; we inline logic per field
    
    // Extract strength (number)
    string pattern_strength = "\"strength\": ";
    int strength_start = StringFind(json_data, pattern_strength);
    if (strength_start >= 0)
    {
        strength_start += StringLen(pattern_strength);
        int strength_end = StringFind(json_data, ",", strength_start);
        if (strength_end < 0)
            strength_end = StringFind(json_data, "}", strength_start);
        if (strength_end < 0)
            strength_end = StringLen(json_data);
        if (strength_end > strength_start)
        {
            string strength_str = StringSubstr(json_data, strength_start, strength_end - strength_start);
            m_current_sentiment.strength = StringToDouble(strength_str);
        }
    }
    
    // Extract confidence (number)
    string pattern_confidence = "\"confidence\": ";
    int confidence_start = StringFind(json_data, pattern_confidence);
    if (confidence_start >= 0)
    {
        confidence_start += StringLen(pattern_confidence);
        int confidence_end = StringFind(json_data, ",", confidence_start);
        if (confidence_end < 0)
            confidence_end = StringFind(json_data, "}", confidence_start);
        if (confidence_end < 0)
            confidence_end = StringLen(json_data);
        if (confidence_end > confidence_start)
        {
            string confidence_str = StringSubstr(json_data, confidence_start, confidence_end - confidence_start);
            m_current_sentiment.confidence = StringToDouble(confidence_str);
        }
    }
    
    // Extract article count (number)
    string pattern_article = "\"article_count\": ";
    int article_start = StringFind(json_data, pattern_article);
    if (article_start >= 0)
    {
        article_start += StringLen(pattern_article);
        int article_end = StringFind(json_data, ",", article_start);
        if (article_end < 0)
            article_end = StringFind(json_data, "}", article_start);
        if (article_end < 0)
            article_end = StringLen(json_data);
        if (article_end > article_start)
        {
            string article_str = StringSubstr(json_data, article_start, article_end - article_start);
            m_current_sentiment.article_count = (int)StringToInteger(article_str);
        }
    }
    
    // Extract average sentiment (number)
    string pattern_avg = "\"avg_sentiment\": ";
    int avg_start = StringFind(json_data, pattern_avg);
    if (avg_start >= 0)
    {
        avg_start += StringLen(pattern_avg);
        int avg_end = StringFind(json_data, ",", avg_start);
        if (avg_end < 0)
            avg_end = StringFind(json_data, "}", avg_start);
        if (avg_end < 0)
            avg_end = StringLen(json_data);
        if (avg_end > avg_start)
        {
            string avg_str = StringSubstr(json_data, avg_start, avg_end - avg_start);
            m_current_sentiment.avg_sentiment = StringToDouble(avg_str);
        }
    }
    
    // Extract reasoning (string)
    string pattern_reasoning = "\"reasoning\": \"";
    int reasoning_start = StringFind(json_data, pattern_reasoning);
    if (reasoning_start >= 0)
    {
        reasoning_start += StringLen(pattern_reasoning);
        int reasoning_end = StringFind(json_data, "\"", reasoning_start);
        if (reasoning_end > reasoning_start)
        {
            m_current_sentiment.reasoning = StringSubstr(json_data, reasoning_start, reasoning_end - reasoning_start);
        }
    }
    
    // Basic validation: require at least one article parsed
    return (m_current_sentiment.article_count > 0 && m_current_sentiment.signal != "");
}

//+------------------------------------------------------------------+
//| Parse calendar sentiment data from JSON string                   |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::ParseCalendarSentimentData(string json_data)
{
    // signal
    string patt_sig = "\"signal\": \"";
    int p = StringFind(json_data, patt_sig);
    if(p >= 0)
    {
        p += StringLen(patt_sig);
        int q = StringFind(json_data, "\"", p);
        if(q > p) m_calendar_sentiment.signal = StringSubstr(json_data, p, q - p);
    }
    // score
    string patt_score = "\"score\": ";
    p = StringFind(json_data, patt_score);
    if(p >= 0)
    {
        p += StringLen(patt_score);
        int q = StringFind(json_data, ",", p);
        if(q < 0) q = StringFind(json_data, "}", p);
        if(q < 0) q = StringLen(json_data);
        string s = StringSubstr(json_data, p, q - p);
        m_calendar_sentiment.score = StringToDouble(s);
    }
    // confidence
    string patt_conf = "\"confidence\": ";
    p = StringFind(json_data, patt_conf);
    if(p >= 0)
    {
        p += StringLen(patt_conf);
        int q = StringFind(json_data, ",", p);
        if(q < 0) q = StringFind(json_data, "}", p);
        if(q < 0) q = StringLen(json_data);
        string s = StringSubstr(json_data, p, q - p);
        m_calendar_sentiment.confidence = StringToDouble(s);
    }
    // event_count
    string patt_cnt = "\"event_count\": ";
    p = StringFind(json_data, patt_cnt);
    if(p >= 0)
    {
        p += StringLen(patt_cnt);
        int q = StringFind(json_data, ",", p);
        if(q < 0) q = StringFind(json_data, "}", p);
        if(q < 0) q = StringLen(json_data);
        string s = StringSubstr(json_data, p, q - p);
        m_calendar_sentiment.event_count = (int)StringToInteger(s);
    }
    // reasoning
    string patt_reas = "\"reasoning\": \"";
    p = StringFind(json_data, patt_reas);
    if(p >= 0)
    {
        p += StringLen(patt_reas);
        int q = StringFind(json_data, "\"", p);
        if(q > p) m_calendar_sentiment.reasoning = StringSubstr(json_data, p, q - p);
    }
    m_calendar_sentiment.timestamp = TimeCurrent();
    
    // Parse enhanced metrics if available
    string patt_surprise = "\"surprise_accuracy\": ";
    p = StringFind(json_data, patt_surprise);
    if(p >= 0)
    {
        p += StringLen(patt_surprise);
        int q = StringFind(json_data, ",", p);
        if(q < 0) q = StringFind(json_data, "}", p);
        if(q < 0) q = StringLen(json_data);
        string s = StringSubstr(json_data, p, q - p);
        m_calendar_sentiment.surprise_accuracy = StringToDouble(s);
    }
    
    string patt_consistency = "\"signal_consistency\": ";
    p = StringFind(json_data, patt_consistency);
    if(p >= 0)
    {
        p += StringLen(patt_consistency);
        int q = StringFind(json_data, ",", p);
        if(q < 0) q = StringFind(json_data, "}", p);
        if(q < 0) q = StringLen(json_data);
        string s = StringSubstr(json_data, p, q - p);
        m_calendar_sentiment.signal_consistency = StringToDouble(s);
    }
    
    string patt_time = "\"processing_time_ms\": ";
    p = StringFind(json_data, patt_time);
    if(p >= 0)
    {
        p += StringLen(patt_time);
        int q = StringFind(json_data, ",", p);
        if(q < 0) q = StringFind(json_data, "}", p);
        if(q < 0) q = StringLen(json_data);
        string s = StringSubstr(json_data, p, q - p);
        m_calendar_sentiment.processing_time_ms = StringToDouble(s);
    }
    
    string patt_high_conf = "\"high_confidence_predictions\": ";
    p = StringFind(json_data, patt_high_conf);
    if(p >= 0)
    {
        p += StringLen(patt_high_conf);
        int q = StringFind(json_data, ",", p);
        if(q < 0) q = StringFind(json_data, "}", p);
        if(q < 0) q = StringLen(json_data);
        string s = StringSubstr(json_data, p, q - p);
        m_calendar_sentiment.high_confidence_count = (int)StringToInteger(s);
    }
    
    string patt_avg_conf = "\"average_confidence\": ";
    p = StringFind(json_data, patt_avg_conf);
    if(p >= 0)
    {
        p += StringLen(patt_avg_conf);
        int q = StringFind(json_data, ",", p);
        if(q < 0) q = StringFind(json_data, "}", p);
        if(q < 0) q = StringLen(json_data);
        string s = StringSubstr(json_data, p, q - p);
        m_calendar_sentiment.average_confidence = StringToDouble(s);
    }
    
    return m_calendar_sentiment.event_count > 0 && m_calendar_sentiment.signal != "";
}

//+------------------------------------------------------------------+
//| Inline calendar analysis fallback (no external MCP)              |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::AnalyzeCalendarInline()
{
    // Read events JSON and compute a simple weighted signal
    int fh = FileOpen("economic_events.json", FILE_READ|FILE_TXT|FILE_COMMON);
    if(fh == INVALID_HANDLE)
        fh = FileOpen("economic_events.json", FILE_READ|FILE_TXT);
    if(fh == INVALID_HANDLE)
        return false;
    string data = "";
    while(!FileIsEnding(fh))
        data += FileReadString(fh);
    FileClose(fh);
    
    // Count events and produce neutral fallback
    int cnt = 0;
    int pos = 0;
    while(true)
    {
        int at = StringFind(data, "\"impact\":", pos);
        if(at < 0) break;
        cnt++;
        pos = at + 9;
    }
    m_calendar_sentiment.signal = "NEUTRAL";
    m_calendar_sentiment.score = 0.0;
    m_calendar_sentiment.confidence = (cnt > 0 ? 0.30 : 0.10);
    m_calendar_sentiment.reasoning = (cnt > 0 ? "Inline fallback computed neutral signal" : "No events for inline analysis");
    m_calendar_sentiment.event_count = cnt;
    m_calendar_sentiment.timestamp = TimeCurrent();
    return true;
}

//+------------------------------------------------------------------+
//| Execute Python script                                            |
//+------------------------------------------------------------------+
string CNewsSentimentIntegration::ExecutePythonScript(string script_path)
{
    // Attempt to launch Python to run the analyzer script.
    // Primary: cmd /C python "<script_path>"
    string working_dir = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Experts\\Grande";
    string args_primary = StringFormat("/C python \"%s\"", script_path);
    int rc = ShellExecuteW(0, "open", "cmd.exe", args_primary, working_dir, 0);
    if(rc > 32)
        return "success";
    
    // Fallback: use py launcher
    string args_fallback = StringFormat("/C py -3 \"%s\"", script_path);
    rc = ShellExecuteW(0, "open", "cmd.exe", args_fallback, working_dir, 0);
    if(rc > 32)
        return "success";
    
    // Final fallback: try invoking python directly without cmd wrapper
    rc = ShellExecuteW(0, "open", "python", StringFormat("\"%s\"", script_path), working_dir, 0);
    if(rc > 32)
        return "success";
    
    return "";
}

//+------------------------------------------------------------------+
//| Validate sentiment data                                          |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::ValidateSentimentData()
{
    if (m_current_sentiment.signal == "")
        return false;
    
    if (m_current_sentiment.article_count == 0)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Example usage in Expert Advisor                                  |
//+------------------------------------------------------------------+
/*
// In your Expert Advisor's OnInit() function:
CNewsSentimentIntegration news_sentiment;

if (!news_sentiment.Initialize())
{
    Print("ERROR: Failed to initialize news sentiment integration");
    return INIT_FAILED;
}

// In your Expert Advisor's OnTick() function:
if (!news_sentiment.IsAnalysisFresh())
{
    if (news_sentiment.RunNewsAnalysis())
    {
        // Analysis completed successfully
        news_sentiment.PrintSentimentInfo();
    }
}

// Use sentiment for trading decisions:
if (news_sentiment.ShouldEnterLong())
{
    // Enter long position
    double weight = news_sentiment.GetSentimentWeight();
    // Adjust position size based on sentiment weight
}

if (news_sentiment.ShouldEnterShort())
{
    // Enter short position
    double weight = news_sentiment.GetSentimentWeight();
    // Adjust position size based on sentiment weight
}

if (news_sentiment.ShouldExitPosition())
{
    // Exit current position
}
*/

//+------------------------------------------------------------------+
//| Fallback: Run calendar analysis using file-based method         |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::RunCalendarAnalysisFileBased()
{
    Print("Grande Calendar Sentiment: Running file-based analysis...");
    string script_path = "mcp/analyze_sentiment_server/finbert_calendar_analyzer.py";
    string result = ExecutePythonScript(script_path);
    if(result == "")
    {
        Print("ERROR: Failed to execute calendar analysis script");
        if(AnalyzeCalendarInline())
            return true;
        return false;
    }
    
    // Wait briefly for the analyzer to produce output in Common\Files
    bool loaded = false;
    for(int attempt = 0; attempt < 20; ++attempt)
    {
        if(LoadLatestCalendarAnalysis())
        {
            loaded = true;
            break;
        }
        Sleep(500);
    }
    if(!loaded)
    {
        return AnalyzeCalendarInline();
    }
    return true;
}


//+------------------------------------------------------------------+
//| Load economic events from JSON file                             |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::LoadEconomicEventsFromFile(string &events_json)
{
    string file_path = "economic_events.json";
    int fh = FileOpen(file_path, FILE_READ|FILE_TXT|FILE_COMMON);
    if(fh == INVALID_HANDLE)
        fh = FileOpen(file_path, FILE_READ|FILE_TXT);
    if(fh == INVALID_HANDLE)
        return false;
    
    events_json = "";
    while(!FileIsEnding(fh))
        events_json += FileReadString(fh);
    FileClose(fh);
    return true;
}


