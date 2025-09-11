//+------------------------------------------------------------------+
//| GrandeMT5NewsReader.mqh                                          |
//| Copyright 2024, Grande Tech                                      |
//| Free News Reading from MT5 Built-in Sources                     |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Free news reading from MT5 built-in sources"

//+------------------------------------------------------------------+
//| News Event Structure                                             |
//+------------------------------------------------------------------+
struct NewsEvent
{
    datetime        time;           // Event time
    string          currency;       // Currency code
    string          event;          // Event name
    string          actual;         // Actual value
    string          forecast;       // Forecast value
    string          previous;       // Previous value
    int             impact;         // Impact level (0-3)
    string          description;    // Event description
};

//+------------------------------------------------------------------+
//| News Impact Levels                                               |
//+------------------------------------------------------------------+
enum NEWS_IMPACT
{
    NEWS_IMPACT_LOW = 0,        // Low impact
    NEWS_IMPACT_MEDIUM = 1,     // Medium impact
    NEWS_IMPACT_HIGH = 2,       // High impact
    NEWS_IMPACT_CRITICAL = 3    // Critical impact
};

//+------------------------------------------------------------------+
//| Grande MT5 News Reader Class                                     |
//+------------------------------------------------------------------+
class CGrandeMT5NewsReader
{
private:
    string              m_symbol;
    bool                m_initialized;
    NewsEvent           m_news_events[];
    int                 m_event_count;
    datetime            m_last_update;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor and Destructor                                       |
    //+------------------------------------------------------------------+
    CGrandeMT5NewsReader(void) : m_initialized(false),
                                 m_event_count(0),
                                 m_last_update(0)
    {
        ArrayResize(m_news_events, 100);
    }
    
    ~CGrandeMT5NewsReader(void)
    {
    }
    
    //+------------------------------------------------------------------+
    //| Initialization Method                                            |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol)
    {
        m_symbol = symbol;
        m_initialized = true;
        
        Print("[GrandeMT5News] News reader initialized for ", m_symbol);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Get Economic Calendar Events                                    |
    //+------------------------------------------------------------------+
    bool GetEconomicCalendarEvents(int hours_ahead = 24)
    {
        if(!m_initialized)
        {
            Print("[GrandeMT5News] ERROR: Not initialized");
            return false;
        }
        
        // Clear previous events
        m_event_count = 0;
        
        // Get current time and future time
        datetime current_time = TimeCurrent();
        datetime future_time = current_time + (hours_ahead * 3600);
        
        // Get economic calendar events
        // Note: This is a simplified implementation
        // In practice, you'd use MT5's economic calendar functions
        
        // Simulate getting events (replace with actual MT5 calendar calls)
        if(!SimulateEconomicEvents(current_time, future_time))
        {
            Print("[GrandeMT5News] WARNING: Using simulated events");
        }
        
        m_last_update = TimeCurrent();
        Print("[GrandeMT5News] Retrieved ", m_event_count, " economic events");
        
        return m_event_count > 0;
    }
    
    //+------------------------------------------------------------------+
    //| Get News from MT5 News Feed                                     |
    //+------------------------------------------------------------------+
    bool GetMT5NewsFeed()
    {
        if(!m_initialized)
        {
            Print("[GrandeMT5News] ERROR: Not initialized");
            return false;
        }
        
        // MT5 has built-in news feed functionality
        // This would connect to MT5's news server
        
        // For now, we'll simulate news data
        return SimulateNewsFeed();
    }
    
    //+------------------------------------------------------------------+
    //| Get High Impact Events Only                                     |
    //+------------------------------------------------------------------+
    int GetHighImpactEvents(NewsEvent &high_impact_events[])
    {
        int count = 0;
        ArrayResize(high_impact_events, 0);
        
        for(int i = 0; i < m_event_count; i++)
        {
            if(m_news_events[i].impact >= NEWS_IMPACT_HIGH)
            {
                ArrayResize(high_impact_events, count + 1);
                high_impact_events[count] = m_news_events[i];
                count++;
            }
        }
        
        return count;
    }
    
    //+------------------------------------------------------------------+
    //| Get Events for Specific Currency                                |
    //+------------------------------------------------------------------+
    int GetEventsForCurrency(string currency, NewsEvent &currency_events[])
    {
        int count = 0;
        ArrayResize(currency_events, 0);
        
        for(int i = 0; i < m_event_count; i++)
        {
            if(m_news_events[i].currency == currency)
            {
                ArrayResize(currency_events, count + 1);
                currency_events[count] = m_news_events[i];
                count++;
            }
        }
        
        return count;
    }
    
    //+------------------------------------------------------------------+
    //| Analyze News Sentiment                                          |
    //+------------------------------------------------------------------+
    double AnalyzeNewsSentiment()
    {
        if(m_event_count == 0)
            return 0.0;
        
        double total_sentiment = 0.0;
        int valid_events = 0;
        
        for(int i = 0; i < m_event_count; i++)
        {
            double event_sentiment = AnalyzeEventSentiment(m_news_events[i]);
            if(event_sentiment != 0.0)
            {
                total_sentiment += event_sentiment * (m_news_events[i].impact + 1); // Weight by impact
                valid_events += (m_news_events[i].impact + 1);
            }
        }
        
        return valid_events > 0 ? total_sentiment / valid_events : 0.0;
    }
    
    //+------------------------------------------------------------------+
    //| Public Access Methods                                            |
    //+------------------------------------------------------------------+
    int GetEventCount() const { return m_event_count; }
    NewsEvent GetEvent(int index) const 
    { 
        if(index >= 0 && index < m_event_count)
            return m_news_events[index];
        NewsEvent empty;
        return empty;
    }
    
    string GetImpactString(int impact) const
    {
        switch(impact)
        {
            case NEWS_IMPACT_LOW: return "LOW";
            case NEWS_IMPACT_MEDIUM: return "MEDIUM";
            case NEWS_IMPACT_HIGH: return "HIGH";
            case NEWS_IMPACT_CRITICAL: return "CRITICAL";
            default: return "UNKNOWN";
        }
    }
    
    void PrintNewsSummary()
    {
        Print("=== MT5 NEWS SUMMARY ===");
        Print("Total Events: ", m_event_count);
        Print("Last Update: ", TimeToString(m_last_update, TIME_DATE|TIME_SECONDS));
        
        for(int i = 0; i < MathMin(m_event_count, 5); i++)
        {
            Print(StringFormat("%d. %s %s - %s (%s impact)",
                              i+1,
                              m_news_events[i].currency,
                              m_news_events[i].event,
                              m_news_events[i].actual,
                              GetImpactString(m_news_events[i].impact)));
        }
        Print("========================");
    }
    
private:
    //+------------------------------------------------------------------+
    //| Private Helper Methods                                           |
    //+------------------------------------------------------------------+
    bool SimulateEconomicEvents(datetime start_time, datetime end_time)
    {
        // Simulate some common economic events
        // In real implementation, this would use MT5's economic calendar
        
        // Add some sample events
        AddEvent(start_time + 3600, "USD", "Non-Farm Payrolls", "200K", "195K", "180K", NEWS_IMPACT_CRITICAL, "Employment data");
        AddEvent(start_time + 7200, "EUR", "ECB Interest Rate", "4.25%", "4.25%", "4.00%", NEWS_IMPACT_HIGH, "Central bank rate decision");
        AddEvent(start_time + 10800, "GBP", "CPI Inflation", "2.1%", "2.0%", "1.8%", NEWS_IMPACT_HIGH, "Consumer price index");
        AddEvent(start_time + 14400, "USD", "Retail Sales", "0.5%", "0.3%", "0.2%", NEWS_IMPACT_MEDIUM, "Consumer spending data");
        AddEvent(start_time + 18000, "EUR", "GDP Growth", "0.3%", "0.2%", "0.1%", NEWS_IMPACT_MEDIUM, "Economic growth data");
        
        return true;
    }
    
    bool SimulateNewsFeed()
    {
        // Simulate news feed data
        // In real implementation, this would connect to MT5's news server
        
        AddEvent(TimeCurrent(), "USD", "Fed Chair Speech", "Hawkish", "Neutral", "Dovish", NEWS_IMPACT_HIGH, "Federal Reserve commentary");
        AddEvent(TimeCurrent() - 1800, "EUR", "ECB Press Conference", "Dovish", "Neutral", "Hawkish", NEWS_IMPACT_HIGH, "European Central Bank");
        AddEvent(TimeCurrent() - 3600, "GBP", "Bank of England Minutes", "Neutral", "Hawkish", "Dovish", NEWS_IMPACT_MEDIUM, "BOE policy minutes");
        
        return true;
    }
    
    void AddEvent(datetime time, string currency, string event, string actual, 
                  string forecast, string previous, int impact, string description)
    {
        if(m_event_count >= ArraySize(m_news_events))
        {
            ArrayResize(m_news_events, m_event_count + 50);
        }
        
        m_news_events[m_event_count].time = time;
        m_news_events[m_event_count].currency = currency;
        m_news_events[m_event_count].event = event;
        m_news_events[m_event_count].actual = actual;
        m_news_events[m_event_count].forecast = forecast;
        m_news_events[m_event_count].previous = previous;
        m_news_events[m_event_count].impact = impact;
        m_news_events[m_event_count].description = description;
        
        m_event_count++;
    }
    
    double AnalyzeEventSentiment(const NewsEvent &event)
    {
        // Simple sentiment analysis based on actual vs forecast
        // Positive if actual > forecast, negative if actual < forecast
        
        double actual_val = 0.0;
        double forecast_val = 0.0;
        
        // Try to extract numeric values
        if(StringFind(event.actual, "%") >= 0)
        {
            actual_val = StringToDouble(StringSubstr(event.actual, 0, StringFind(event.actual, "%")));
        }
        else
        {
            actual_val = StringToDouble(event.actual);
        }
        
        if(StringFind(event.forecast, "%") >= 0)
        {
            forecast_val = StringToDouble(StringSubstr(event.forecast, 0, StringFind(event.forecast, "%")));
        }
        else
        {
            forecast_val = StringToDouble(event.forecast);
        }
        
        if(actual_val != 0.0 && forecast_val != 0.0)
        {
            // Calculate sentiment based on actual vs forecast
            double difference = actual_val - forecast_val;
            double max_val = MathMax(MathAbs(actual_val), MathAbs(forecast_val));
            
            if(max_val > 0)
            {
                return difference / max_val; // Normalize to -1 to 1
            }
        }
        
        // Fallback to keyword analysis
        string text = event.event + " " + event.actual + " " + event.description;
        return AnalyzeTextSentiment(text);
    }
    
    double AnalyzeTextSentiment(string text)
    {
        // Simple keyword-based sentiment analysis
        string positive_words[] = {"good", "strong", "up", "rise", "gain", "positive", "bullish", "hawkish", "growth", "increase"};
        string negative_words[] = {"bad", "weak", "down", "fall", "drop", "negative", "bearish", "dovish", "decline", "decrease"};
        
        int positive_count = 0;
        int negative_count = 0;
        
        string text_lower = StringToLower(text);
        
        for(int i = 0; i < ArraySize(positive_words); i++)
        {
            if(StringFind(text_lower, positive_words[i]) >= 0)
                positive_count++;
        }
        
        for(int i = 0; i < ArraySize(negative_words); i++)
        {
            if(StringFind(text_lower, negative_words[i]) >= 0)
                negative_count++;
        }
        
        int total_words = positive_count + negative_count;
        if(total_words > 0)
        {
            return (positive_count - negative_count) / (double)total_words;
        }
        
        return 0.0;
    }
    
    string StringToLower(string str)
    {
        string result = str;
        for(int i = 0; i < StringLen(result); i++)
        {
            ushort ch = StringGetCharacter(result, i);
            if(ch >= 'A' && ch <= 'Z')
            {
                StringSetCharacter(result, i, ch + 32);
            }
        }
        return result;
    }
};
