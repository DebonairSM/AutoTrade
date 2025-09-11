//+------------------------------------------------------------------+
//| GrandeFreeNewsDemo.mq5                                           |
//| Copyright 2024, Grande Tech                                      |
//| Free News Sources Demo - No API Keys Required!                  |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Free news sources demo - no API keys required"

#include "GrandeMT5NewsReader.mqh"
#include "GrandeForexComNews.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Free News Sources ==="
input bool InpUseMT5Calendar = true;           // Use MT5 Economic Calendar
input bool InpUseForexComNews = true;          // Use Forex.com News
input bool InpUseSimulatedNews = true;         // Use Simulated News Data
input int InpNewsUpdateMinutes = 15;           // News Update Interval (minutes)

input group "=== Signal Settings ==="
input double InpMinSentimentScore = 0.3;       // Minimum Sentiment Score
input double InpMinRelevanceScore = 70;        // Minimum Relevance Score
input bool InpShowDetailedLogs = true;         // Show Detailed Logs
input bool InpAutoGenerateSignals = true;      // Auto Generate Signals

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CGrandeMT5NewsReader g_mt5_news;
CGrandeForexComNews g_forexcom_news;
datetime g_last_news_update;
int g_signals_generated;
int g_successful_signals;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Grande Free News Demo Starting ===");
    Print("No API keys required - using free sources!");
    
    // Initialize news readers
    if(!g_mt5_news.Initialize(Symbol()))
    {
        Print("ERROR: Failed to initialize MT5 news reader");
        return INIT_FAILED;
    }
    
    if(!g_forexcom_news.Initialize(Symbol()))
    {
        Print("ERROR: Failed to initialize Forex.com news reader");
        return INIT_FAILED;
    }
    
    // Initialize variables
    g_last_news_update = 0;
    g_signals_generated = 0;
    g_successful_signals = 0;
    
    Print("=== Free News Demo Initialized Successfully ===");
    Print("Symbol: ", Symbol());
    Print("Update Interval: ", InpNewsUpdateMinutes, " minutes");
    Print("Sources: MT5 Calendar=", InpUseMT5Calendar, " Forex.com=", InpUseForexComNews, " Simulated=", InpUseSimulatedNews);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Grande Free News Demo Stopping ===");
    Print("Total Signals Generated: ", g_signals_generated);
    Print("Successful Signals: ", g_successful_signals);
    if(g_signals_generated > 0)
    {
        Print("Success Rate: ", (double)g_successful_signals / g_signals_generated * 100.0, "%");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if it's time to update news
    if(!IsTimeToUpdateNews())
        return;
    
    // Update news and generate signals
    if(InpAutoGenerateSignals)
    {
        UpdateNewsAndGenerateSignals();
    }
    
    // Update last update time
    g_last_news_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Chart event function                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_KEYDOWN)
    {
        if(sparam == "N" || sparam == "n") // Press 'N' for news update
        {
            UpdateNewsAndGenerateSignals();
        }
        else if(sparam == "S" || sparam == "s") // Press 'S' for status
        {
            ShowSystemStatus();
        }
        else if(sparam == "T" || sparam == "t") // Press 'T' for test
        {
            TestAllNewsSources();
        }
    }
}

//+------------------------------------------------------------------+
//| Check if it's time to update news                                |
//+------------------------------------------------------------------+
bool IsTimeToUpdateNews()
{
    if(g_last_news_update == 0)
        return true;
    
    int minutes_since_update = (int)((TimeCurrent() - g_last_news_update) / 60);
    return minutes_since_update >= InpNewsUpdateMinutes;
}

//+------------------------------------------------------------------+
//| Update news and generate signals                                 |
//+------------------------------------------------------------------+
void UpdateNewsAndGenerateSignals()
{
    Print("=== Updating News from Free Sources ===");
    
    double total_sentiment = 0.0;
    int total_articles = 0;
    int valid_sources = 0;
    
    // Get MT5 Economic Calendar events
    if(InpUseMT5Calendar)
    {
        if(g_mt5_news.GetEconomicCalendarEvents(24))
        {
            double mt5_sentiment = g_mt5_news.AnalyzeNewsSentiment();
            int mt5_events = g_mt5_news.GetEventCount();
            
            if(mt5_events > 0)
            {
                total_sentiment += mt5_sentiment * mt5_events;
                total_articles += mt5_events;
                valid_sources++;
                
                if(InpShowDetailedLogs)
                {
                    Print("MT5 Calendar: ", mt5_events, " events, sentiment: ", DoubleToString(mt5_sentiment, 3));
                    g_mt5_news.PrintNewsSummary();
                }
            }
        }
    }
    
    // Get Forex.com news
    if(InpUseForexComNews)
    {
        if(g_forexcom_news.GetLatestNews())
        {
            double forexcom_sentiment = g_forexcom_news.AnalyzeNewsSentiment();
            int forexcom_articles = g_forexcom_news.GetArticleCount();
            
            if(forexcom_articles > 0)
            {
                total_sentiment += forexcom_sentiment * forexcom_articles;
                total_articles += forexcom_articles;
                valid_sources++;
                
                if(InpShowDetailedLogs)
                {
                    Print("Forex.com: ", forexcom_articles, " articles, sentiment: ", DoubleToString(forexcom_sentiment, 3));
                    g_forexcom_news.PrintNewsSummary();
                }
            }
        }
    }
    
    // Use simulated news if no real sources available
    if(InpUseSimulatedNews && valid_sources == 0)
    {
        total_sentiment = GenerateSimulatedSentiment();
        total_articles = 5;
        valid_sources = 1;
        
        if(InpShowDetailedLogs)
        {
            Print("Simulated News: 5 articles, sentiment: ", DoubleToString(total_sentiment, 3));
        }
    }
    
    // Calculate overall sentiment
    double overall_sentiment = 0.0;
    if(total_articles > 0)
    {
        overall_sentiment = total_sentiment / total_articles;
    }
    
    // Generate trading signal
    if(valid_sources > 0 && MathAbs(overall_sentiment) >= InpMinSentimentScore)
    {
        GenerateTradingSignal(overall_sentiment, total_articles, valid_sources);
    }
    else
    {
        Print("No valid news sources or sentiment too weak");
    }
    
    Print("=== News Update Complete ===");
}

//+------------------------------------------------------------------+
//| Generate trading signal based on sentiment                       |
//+------------------------------------------------------------------+
void GenerateTradingSignal(double sentiment, int article_count, int source_count)
{
    g_signals_generated++;
    
    string signal_type = "";
    string signal_action = "";
    double signal_strength = MathAbs(sentiment);
    
    // Determine signal type
    if(sentiment >= 0.6)
    {
        signal_type = "STRONG BUY";
        signal_action = "Consider opening LONG position";
    }
    else if(sentiment >= 0.3)
    {
        signal_type = "BUY";
        signal_action = "Consider opening LONG position";
    }
    else if(sentiment <= -0.6)
    {
        signal_type = "STRONG SELL";
        signal_action = "Consider opening SHORT position";
    }
    else if(sentiment <= -0.3)
    {
        signal_type = "SELL";
        signal_action = "Consider opening SHORT position";
    }
    else
    {
        signal_type = "NEUTRAL";
        signal_action = "No clear signal";
    }
    
    // Display signal
    Print("=== TRADING SIGNAL GENERATED ===");
    Print("Signal Type: ", signal_type);
    Print("Sentiment Score: ", DoubleToString(sentiment, 3));
    Print("Signal Strength: ", DoubleToString(signal_strength, 3));
    Print("Articles Analyzed: ", article_count);
    Print("News Sources: ", source_count);
    Print("Action: ", signal_action);
    Print("Current Price: ", DoubleToString(SymbolInfoDouble(Symbol(), SYMBOL_BID), 5));
    Print("===============================");
    
    // Simulate signal success (for demo purposes)
    bool signal_success = SimulateSignalSuccess(signal_strength);
    if(signal_success)
    {
        g_successful_signals++;
        Print("Signal marked as SUCCESSFUL");
    }
    else
    {
        Print("Signal marked as UNSUCCESSFUL");
    }
}

//+------------------------------------------------------------------+
//| Simulate signal success (for demo purposes)                      |
//+------------------------------------------------------------------+
bool SimulateSignalSuccess(double signal_strength)
{
    // Simple simulation based on signal strength
    double success_probability = signal_strength * 0.8; // 80% of strength as success rate
    double random_factor = (MathRand() / 32767.0);
    
    return random_factor < success_probability;
}

//+------------------------------------------------------------------+
//| Generate simulated sentiment (fallback)                          |
//+------------------------------------------------------------------+
double GenerateSimulatedSentiment()
{
    // Generate random sentiment between -1 and 1
    return (MathRand() - 16383) / 16383.0;
}

//+------------------------------------------------------------------+
//| Show system status                                                |
//+------------------------------------------------------------------+
void ShowSystemStatus()
{
    Print("=== FREE NEWS SYSTEM STATUS ===");
    Print("Symbol: ", Symbol());
    Print("Last Update: ", TimeToString(g_last_news_update, TIME_DATE|TIME_SECONDS));
    Print("Signals Generated: ", g_signals_generated);
    Print("Successful Signals: ", g_successful_signals);
    if(g_signals_generated > 0)
    {
        Print("Success Rate: ", DoubleToString((double)g_successful_signals / g_signals_generated * 100.0, 2), "%");
    }
    Print("MT5 Calendar Events: ", g_mt5_news.GetEventCount());
    Print("Forex.com Articles: ", g_forexcom_news.GetArticleCount());
    Print("=== END STATUS ===");
}

//+------------------------------------------------------------------+
//| Test all news sources                                            |
//+------------------------------------------------------------------+
void TestAllNewsSources()
{
    Print("=== TESTING ALL NEWS SOURCES ===");
    
    // Test MT5 Calendar
    if(InpUseMT5Calendar)
    {
        Print("Testing MT5 Economic Calendar...");
        if(g_mt5_news.GetEconomicCalendarEvents(24))
        {
            Print("✓ MT5 Calendar: ", g_mt5_news.GetEventCount(), " events found");
        }
        else
        {
            Print("✗ MT5 Calendar: No events found");
        }
    }
    
    // Test Forex.com News
    if(InpUseForexComNews)
    {
        Print("Testing Forex.com News...");
        if(g_forexcom_news.GetLatestNews())
        {
            Print("✓ Forex.com: ", g_forexcom_news.GetArticleCount(), " articles found");
        }
        else
        {
            Print("✗ Forex.com: No articles found");
        }
    }
    
    // Test Simulated News
    if(InpUseSimulatedNews)
    {
        Print("Testing Simulated News...");
        double simulated_sentiment = GenerateSimulatedSentiment();
        Print("✓ Simulated: Sentiment = ", DoubleToString(simulated_sentiment, 3));
    }
    
    Print("=== NEWS SOURCE TEST COMPLETE ===");
}
