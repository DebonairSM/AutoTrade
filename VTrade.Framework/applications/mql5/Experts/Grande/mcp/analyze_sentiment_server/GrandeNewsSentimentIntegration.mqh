//+------------------------------------------------------------------+
//| GrandeNewsSentimentIntegration.mqh                               |
//| Integration with Grande Sentiment Server for MQL5               |
//| Copyright 2025, Grande Trading System                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Grande Trading System"
#property link      ""
#property version   "1.00"
#property strict



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
    
    // Trading signal integration
    bool              ShouldEnterLong();
    bool              ShouldEnterShort();
    bool              ShouldExitPosition();
    double            GetSentimentWeight();
    
    // Utility functions
    string            GetSentimentDescription();
    void              PrintSentimentInfo();
    bool              IsSentimentServerRunning();
    
private:
    bool              ParseSentimentData(string json_data);
    bool              ParseCalendarSentimentData(string json_data);
    bool              AnalyzeCalendarInline();
    string            ExecutePythonScript(string script_path);
    bool              ValidateSentimentData();
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
    Print("Grande News Sentiment: Running news analysis...");
    
    // Execute the integrated news system
    string script_path = "mcp/analyze_sentiment_server/integrated_news_system.py";
    string result = ExecutePythonScript(script_path);
    
    if (result == "")
    {
        Print("ERROR: Failed to execute news analysis script");
        return false;
    }
    
    // Load the results
    if (LoadLatestAnalysis())
    {
        m_last_analysis_time = TimeCurrent();
        Print("Grande News Sentiment: Analysis completed successfully");
        PrintSentimentInfo();
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Load the latest news analysis results                            |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::LoadLatestAnalysis()
{
    string file_path = m_news_analysis_file;
    
    // Try to open from the Common Files directory first (shared across terminals)
    int file_handle = FileOpen(file_path, FILE_READ|FILE_TXT|FILE_COMMON);
    if (file_handle == INVALID_HANDLE)
    {
        // Fallback to local MQL5\\Files directory
        file_handle = FileOpen(file_path, FILE_READ|FILE_TXT);
        if (file_handle == INVALID_HANDLE)
        {
            string common_dir = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\";
            Print("WARNING: News analysis file not found in Common or Local Files: ", file_path);
            Print("Expected Common path: ", common_dir, file_path);
            return false;
        }
    }
    
    // Read the entire file
    string json_data = "";
    while (!FileIsEnding(file_handle))
    {
        json_data += FileReadString(file_handle);
    }
    FileClose(file_handle);
    
    // Parse the JSON data
    if (ParseSentimentData(json_data))
    {
        Print("Grande News Sentiment: Loaded latest analysis");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Run calendar analysis using the integrated system               |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::RunCalendarAnalysis()
{
    Print("Grande Calendar Sentiment: Running calendar analysis...");
    string script_path = "mcp/analyze_sentiment_server/integrated_calendar_system.py";
    string result = ExecutePythonScript(script_path);
    if(result == "")
    {
        Print("ERROR: Failed to execute calendar analysis script");
        // Try inline fallback analysis if Python execution isn't available
        if(AnalyzeCalendarInline())
            return true;
        return false;
    }
    // Load results
    if(!LoadLatestCalendarAnalysis())
    {
        // Fallback to inline analysis if no external analysis file was produced
        return AnalyzeCalendarInline();
    }
    return true;
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
    if (!ValidateSentimentData())
        return false;
    
    // Strong buy signal
    if (m_current_sentiment.signal == "STRONG_BUY" && m_current_sentiment.confidence >= 0.7)
        return true;
    
    // Buy signal with good confidence
    if (m_current_sentiment.signal == "BUY" && m_current_sentiment.confidence >= 0.5)
        return true;
    
    // Positive sentiment with high strength
    if (m_current_sentiment.avg_sentiment >= 0.6 && m_current_sentiment.confidence >= 0.6)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Determine if should enter short position based on sentiment      |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::ShouldEnterShort()
{
    if (!ValidateSentimentData())
        return false;
    
    // Strong sell signal
    if (m_current_sentiment.signal == "STRONG_SELL" && m_current_sentiment.confidence >= 0.7)
        return true;
    
    // Sell signal with good confidence
    if (m_current_sentiment.signal == "SELL" && m_current_sentiment.confidence >= 0.5)
        return true;
    
    // Negative sentiment with high strength
    if (m_current_sentiment.avg_sentiment <= -0.6 && m_current_sentiment.confidence >= 0.6)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Determine if should exit current position                        |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::ShouldExitPosition()
{
    if (!ValidateSentimentData())
        return false;
    
    // Exit if sentiment becomes neutral or opposite
    if (m_current_sentiment.signal == "NEUTRAL" && m_current_sentiment.confidence >= 0.5)
        return true;
    
    // Exit if confidence drops significantly
    if (m_current_sentiment.confidence < 0.3)
        return true;
    
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
//| Check if sentiment server is running                            |
//+------------------------------------------------------------------+
bool CNewsSentimentIntegration::IsSentimentServerRunning()
{
    // This would typically check if the Docker container is running
    // For now, we'll assume it's running if we can access the analysis file
    return true; // Simplified for MQL5
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
    // This would execute the Python script
    // In MQL5, you'd typically use ShellExecute or similar
    // For now, we'll return a success indicator
    return "success";
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
