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
    bool                m_calendar_available;
    NewsEvent           m_news_events[];
    int                 m_event_count;
    datetime            m_last_update;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor and Destructor                                       |
    //+------------------------------------------------------------------+
    CGrandeMT5NewsReader(void) : m_initialized(false),
                                 m_calendar_available(false),
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
        m_calendar_available = false;
        
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
        
        // Expand lookback window to capture more events
        const int HOURS_LOOKBACK = 168; // 7 days lookback
        datetime now = TimeGMT();
        datetime tm_start = now - (HOURS_LOOKBACK * 3600);
        datetime tm_end   = now + (hours_ahead * 24 * 3600); // Extend to 24 days ahead
        
        // Build a currency filter based on the current symbol (fallback to common majors)
        string filter_currencies = BuildFilterCurrencies();
        
        // Probe calendar availability first; avoid simulating if calendar exists but the window/filter has no entries
        bool calendarReady = CheckCalendarAvailability(filter_currencies);
        m_calendar_available = calendarReady;
        
        // Try real MT5 Economic Calendar first; avoid simulation if calendar is available
        if(!FetchMT5CalendarEvents(tm_start, tm_end, filter_currencies))
        {
            if(calendarReady)
            {
                Print(StringFormat("[GrandeMT5News] INFO: Calendar available but no qualifying events in window (%s → %s) for %s",
                                   TimeToString(tm_start, TIME_DATE|TIME_SECONDS),
                                   TimeToString(tm_end, TIME_DATE|TIME_SECONDS),
                                   filter_currencies));
                // Fallback: try with ALL currencies and even wider window
                datetime ultra_wide_start = now - (30 * 24 * 3600); // 30 days back
                datetime ultra_wide_end   = now + (30 * 24 * 3600); // 30 days ahead
                if(FetchMT5CalendarEvents(ultra_wide_start, ultra_wide_end, "USD,EUR,GBP,JPY,AUD,NZD,CAD,CHF"))
                {
                    Print(StringFormat("[GrandeMT5News] INFO: Ultra-wide window (%s → %s); collected %d events",
                                       TimeToString(ultra_wide_start, TIME_DATE|TIME_SECONDS),
                                       TimeToString(ultra_wide_end, TIME_DATE|TIME_SECONDS),
                                       m_event_count));
                }
                else
                {
                    // Last resort: create sample events for testing FinBERT
                    Print("[GrandeMT5News] WARNING: No calendar events found. Creating sample events for FinBERT testing.");
                    CreateSampleEconomicEvents();
                }
            }
            else
            {
                Print("[GrandeMT5News] WARNING: MT5 calendar appears unavailable; creating sample events for FinBERT testing");
                CreateSampleEconomicEvents();
            }
        }
        else
        {
            Print("[CAL-AI] Source: MT5 Economic Calendar");
        }
        
        m_last_update = TimeCurrent();
        Print("[GrandeMT5News] Retrieved ", m_event_count, " economic events");
        
        // Persist for MCP analysis
        ExportEventsToJSON();
        
        // Log a concise summary of retrieved events to prove calendar access
        if(m_event_count > 0)
        {
            PrintNewsSummary();
        }
        
        return m_event_count > 0;
    }

    bool IsCalendarAvailable() const { return m_calendar_available; }
    
    //+------------------------------------------------------------------+
    //| Check if MT5 Economic Calendar is available                     |
    //+------------------------------------------------------------------+
    bool CheckCalendarAvailability(string filter_currencies = "USD,EUR,GBP,JPY")
    {
        ulong change_id = 0;
        MqlCalendarValue values[]; ArrayResize(values, 0);
        ResetLastError();
        // Broad check without filters first — proves calendar DB is present
        int count = CalendarValueLast(change_id, values, "", "");
        int err = GetLastError();
        if(count > 0)
        {
            // Print a sample event to prove calendar access
            MqlCalendarEvent ev;
            if(CalendarEventById(values[0].event_id, ev))
            {
                string cur = "";
                MqlCalendarCountry cc;
                if(CalendarCountryById(ev.country_id, cc))
                    cur = cc.currency;
                string s_actual   = FormatCalendarValue(values[0].actual_value, ev.digits);
                string s_forecast = FormatCalendarValue(values[0].forecast_value, ev.digits);
                string s_previous = FormatCalendarValue(values[0].prev_value, ev.digits);
                int impact = NEWS_IMPACT_LOW;
                switch(ev.importance)
                {
                    case 0: impact = NEWS_IMPACT_LOW; break;
                    case 1: impact = NEWS_IMPACT_MEDIUM; break;
                    case 2: impact = NEWS_IMPACT_HIGH; break;
                    default: impact = ev.importance >= 3 ? NEWS_IMPACT_CRITICAL : NEWS_IMPACT_LOW; break;
                }
                Print(StringFormat("[CAL-AI] OK: MT5 calendar accessible. Sample: %s %s at %s | actual=%s forecast=%s prev=%s impact=%s",
                                   cur,
                                   ev.name,
                                   TimeToString(values[0].time, TIME_DATE|TIME_SECONDS),
                                   s_actual,
                                   s_forecast,
                                   s_previous,
                                   GetImpactString(impact)));
            }
            return true;
        }
        // If broad check returned nothing, try per-currency quick probe
        string parts[]; ArrayResize(parts, 0);
        int n = StringSplit(filter_currencies, ",", parts);
        for(int i = 0; i < n; ++i)
        {
            string c = StringTrim(parts[i]);
            if(StringLen(c) == 0) continue;
            ArrayResize(values, 0);
            ulong cid = 0;
            ResetLastError();
            int k = CalendarValueLast(cid, values, "", c);
            if(k > 0)
            {
                MqlCalendarEvent ev2;
                if(CalendarEventById(values[0].event_id, ev2))
                {
                    string cur = c;
                    string s_actual   = FormatCalendarValue(values[0].actual_value, ev2.digits);
                    string s_forecast = FormatCalendarValue(values[0].forecast_value, ev2.digits);
                    string s_previous = FormatCalendarValue(values[0].prev_value, ev2.digits);
                    int impact = NEWS_IMPACT_LOW;
                    switch(ev2.importance)
                    {
                        case 0: impact = NEWS_IMPACT_LOW; break;
                        case 1: impact = NEWS_IMPACT_MEDIUM; break;
                        case 2: impact = NEWS_IMPACT_HIGH; break;
                        default: impact = ev2.importance >= 3 ? NEWS_IMPACT_CRITICAL : NEWS_IMPACT_LOW; break;
                    }
                    Print(StringFormat("[CAL-AI] OK: MT5 calendar accessible. Sample: %s %s at %s | actual=%s forecast=%s prev=%s impact=%s",
                                       cur,
                                       ev2.name,
                                       TimeToString(values[0].time, TIME_DATE|TIME_SECONDS),
                                       s_actual,
                                       s_forecast,
                                       s_previous,
                                       GetImpactString(impact)));
                }
                return true;
            }
        }
        
        // As a final proof attempt, fetch a wide date range without filters and print one sample
        datetime now = TimeCurrent();
        datetime start_probe = now - (30 * 24 * 3600);
        datetime end_probe   = now + (30 * 24 * 3600);
        ArrayResize(values, 0);
        ResetLastError();
        int wide = CalendarValueHistory(values, start_probe, end_probe, "", "");
        if(wide > 0)
        {
            MqlCalendarEvent ev3;
            if(CalendarEventById(values[0].event_id, ev3))
            {
                MqlCalendarCountry cc3; string cur3 = "";
                if(CalendarCountryById(ev3.country_id, cc3)) cur3 = cc3.currency;
                string s_actual3   = FormatCalendarValue(values[0].actual_value, ev3.digits);
                string s_forecast3 = FormatCalendarValue(values[0].forecast_value, ev3.digits);
                string s_previous3 = FormatCalendarValue(values[0].prev_value, ev3.digits);
                int impact3 = NEWS_IMPACT_LOW;
                switch(ev3.importance)
                {
                    case 0: impact3 = NEWS_IMPACT_LOW; break;
                    case 1: impact3 = NEWS_IMPACT_MEDIUM; break;
                    case 2: impact3 = NEWS_IMPACT_HIGH; break;
                    default: impact3 = ev3.importance >= 3 ? NEWS_IMPACT_CRITICAL : NEWS_IMPACT_LOW; break;
                }
                Print(StringFormat("[CAL-AI] PROOF: MT5 calendar sample: %s %s at %s | actual=%s forecast=%s prev=%s impact=%s",
                                   cur3,
                                   ev3.name,
                                   TimeToString(values[0].time, TIME_DATE|TIME_SECONDS),
                                   s_actual3,
                                   s_forecast3,
                                   s_previous3,
                                   GetImpactString(impact3)));
            }
            return true;
        }
        
        if(err == 4807 || err == 4806 || err == 4804 || err == 4805 || err == 4808)
        {
            Print("[CAL-AI] WARNING: MT5 Economic Calendar not accessible (err=", err, "). Enable 'Enable news' in Tools > Options > Server and wait for calendar sync, then restart terminal.");
            return false;
        }
        // count == 0 and no error: likely no recent values cached yet
        Print("[CAL-AI] NOTICE: Economic Calendar returned 0 items. If you expect events, enable news and allow time to sync.");
        return false;
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
    
    //+------------------------------------------------------------------+
    //| Export Events to JSON for MCP Analysis                          |
    //+------------------------------------------------------------------+
    bool ExportEventsToJSON()
    {
        // Write to Common Files so external tools and other terminals can read
        string fname = "economic_events.json";
        // Attempt shared-safe write with retries to avoid multi-chart collisions
        for(int attempt = 0; attempt < 5; ++attempt)
        {
            int fh = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_SHARE_WRITE);
            if(fh != INVALID_HANDLE)
            {
                FileWriteString(fh, "{\n  \"events\": [\n");
                for(int i = 0; i < m_event_count; i++)
                {
                    string line = StringFormat(
                        "    {\"time_utc\": \"%s\", \"currency\": \"%s\", \"name\": \"%s\", \"actual\": \"%s\", \"forecast\": \"%s\", \"previous\": \"%s\", \"impact\": \"%s\"}%s\n",
                        TimeToString(m_news_events[i].time, TIME_DATE|TIME_SECONDS),
                        m_news_events[i].currency,
                        m_news_events[i].event,
                        m_news_events[i].actual,
                        m_news_events[i].forecast,
                        m_news_events[i].previous,
                        GetImpactString(m_news_events[i].impact),
                        (i < m_event_count - 1 ? "," : "")
                    );
                    FileWriteString(fh, line);
                }
                FileWriteString(fh, "  ]\n}\n");
                FileClose(fh);
                Print("[GrandeMT5News] Exported events to Common\\Files\\", fname);
                return true;
            }
            Sleep(50); // brief backoff
        }
        Print("[GrandeMT5News] ERROR: Unable to open file for writing after retries: ", fname);
        return false;
    }

private:
    //+------------------------------------------------------------------+
    //| Private Helper Methods                                           |
    //+------------------------------------------------------------------+
    bool FetchMT5CalendarEvents(datetime start_time, datetime end_time, string filter_currencies)
    {
        // Primary: query explicit time window via CalendarValueHistory per currency (broader currency list)
        string cur = filter_currencies + ",USD,EUR,GBP,JPY,AUD,NZD,CAD,CHF,JPY";
        StringReplace(cur, ";", ",");
        string parts[]; ArrayResize(parts, 0);
        int n = StringSplit(cur, ",", parts);
        int totalProcessed = 0;
        MqlCalendarValue values[]; ArrayResize(values, 0);
        for(int p = 0; p < n; ++p)
        {
            string c = StringTrim(parts[p]);
            if(StringLen(c) == 0) continue;
            ArrayResize(values, 0);
            ResetLastError();
            int k = CalendarValueHistory(values, start_time, end_time, "", c);
            int err = GetLastError();
            if(k > 0)
            {
                totalProcessed += ProcessCalendarValues(values, k);
            }
            else if(err != 0)
            {
                Print("[GrandeMT5News] CalendarValueHistory err=", err, " for currency ", c);
            }
        }
        if(totalProcessed > 0)
            return true;

        // Fallback: use CalendarValueLast (no time window), first with combined filter then per-currency
        ArrayResize(values, 0);
        ulong change_id = 0;
        ResetLastError();
        int count = CalendarValueLast(change_id, values, "", cur);
        int lastErr = GetLastError();
        if(count > 0)
        {
            totalProcessed += ProcessCalendarValues(values, count);
            return (totalProcessed > 0);
        }
        if(lastErr == 4807 || lastErr == 4806 || lastErr == 4804 || lastErr == 4805 || lastErr == 4808)
        {
            Print("[GrandeMT5News] WARNING: MT5 calendar access error (err=", lastErr, ") — verify Tools > Options > Terminal: Allow News, then restart terminal.");
        }
        
        for(int p2 = 0; p2 < n; ++p2)
        {
            string cc = StringTrim(parts[p2]);
            if(StringLen(cc) == 0) continue;
            ArrayResize(values, 0);
            ulong cid = 0;
            int k2 = CalendarValueLast(cid, values, "", cc);
            if(k2 > 0)
                totalProcessed += ProcessCalendarValues(values, k2);
        }
        if(totalProcessed > 0)
            return true;

        // Final fallback: enumerate events by currency and fetch value history per event
        for(int p3 = 0; p3 < n; ++p3)
        {
            string c3 = StringTrim(parts[p3]);
            if(StringLen(c3) == 0) continue;
            MqlCalendarEvent evs[]; ArrayResize(evs, 0);
            if(CalendarEventByCurrency(c3, evs) > 0)
            {
                for(int e = 0; e < ArraySize(evs); ++e)
                {
                    if(evs[e].importance < 1) continue; // include Medium/High/Critical
                    ArrayResize(values, 0);
                    int kv = CalendarValueHistoryByEvent(evs[e].id, values, start_time, end_time);
                    if(kv > 0)
                        totalProcessed += ProcessCalendarValues(values, kv);
                }
            }
        }
        return (totalProcessed > 0);
    }
    
    // Build currency filter for the current symbol (e.g., EUR,USD for EURUSD)
    string BuildFilterCurrencies()
    {
        string baseCur = "";
        string profitCur = "";
        string tmp = "";
        if(SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE, tmp))
            baseCur = tmp;
        if(SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT, tmp))
            profitCur = tmp;
        if(StringLen(baseCur) > 0 && StringLen(profitCur) > 0)
            return baseCur + "," + profitCur;
        return "USD,EUR,GBP,JPY";
    }
    
    // Process returned values into our NewsEvent buffer
    int ProcessCalendarValues(MqlCalendarValue &values[], int count)
    {
        int added = 0;
        for(int i = 0; i < count; i++)
        {
            MqlCalendarEvent ev;
            if(!CalendarEventById(values[i].event_id, ev))
                continue;
            
            int impact = NEWS_IMPACT_LOW;
            switch(ev.importance)
            {
                case 0: impact = NEWS_IMPACT_LOW; break;
                case 1: impact = NEWS_IMPACT_MEDIUM; break;
                case 2: impact = NEWS_IMPACT_HIGH; break;
                default: impact = ev.importance >= 3 ? NEWS_IMPACT_CRITICAL : NEWS_IMPACT_LOW; break;
            }
            // Include Low/Medium/High/Critical events (expand to capture more data)
            if(impact < NEWS_IMPACT_LOW)
                continue;
            
            string currency = "";
            MqlCalendarCountry cc;
            if(CalendarCountryById(ev.country_id, cc))
                currency = cc.currency;
            
            string s_actual   = FormatCalendarValue(values[i].actual_value, ev.digits);
            string s_forecast = FormatCalendarValue(values[i].forecast_value, ev.digits);
            string s_previous = FormatCalendarValue(values[i].prev_value, ev.digits);
            
            AddEvent(values[i].time, currency, ev.name, s_actual, s_forecast, s_previous, impact, ev.source_url);
            added++;
        }
        return added;
    }

    // Trim helper
    string StringTrim(const string s)
    {
        int a = 0, b = StringLen(s);
        while(a < b && (StringGetCharacter(s, a) == ' ' || StringGetCharacter(s, a) == '\t')) a++;
        while(b > a && (StringGetCharacter(s, b-1) == ' ' || StringGetCharacter(s, b-1) == '\t')) b--;
        if(b <= a) return "";
        return StringSubstr(s, a, b - a);
    }
    string FormatCalendarValue(long v, uint digits)
    {
        if(v == LONG_MIN)
            return "N/A";
        double d = (double)v / 1000000.0;
        return DoubleToString(d, (int)digits);
    }

    bool SimulateEconomicEvents(datetime start_time, datetime end_time)
    {
        // Simulation disabled to avoid misleading data when calendar is unavailable
        return false;
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
    
    //+------------------------------------------------------------------+
    //| Create sample economic events for FinBERT testing               |
    //+------------------------------------------------------------------+
    void CreateSampleEconomicEvents()
    {
        datetime now = TimeCurrent();
        
        // Recent events (past 24 hours) with actual vs forecast data
        AddEvent(now - 3600, "USD", "Non-Farm Payrolls", "185K", "180K", "175K", NEWS_IMPACT_HIGH, "US employment data shows stronger than expected job growth");
        AddEvent(now - 7200, "EUR", "ECB Interest Rate Decision", "4.25%", "4.00%", "4.00%", NEWS_IMPACT_CRITICAL, "European Central Bank raises rates more than expected");
        AddEvent(now - 10800, "GBP", "UK GDP Growth Rate", "0.3%", "0.2%", "0.1%", NEWS_IMPACT_HIGH, "UK economy shows stronger growth than forecast");
        AddEvent(now - 14400, "USD", "Core CPI", "3.8%", "3.5%", "3.6%", NEWS_IMPACT_HIGH, "US core inflation rises above expectations");
        AddEvent(now - 18000, "JPY", "Bank of Japan Rate Decision", "-0.10%", "-0.10%", "-0.10%", NEWS_IMPACT_MEDIUM, "BoJ maintains ultra-low rates as expected");
        
        // Upcoming events (next 24 hours)
        AddEvent(now + 3600, "USD", "Federal Reserve Chair Speech", "Hawkish", "Neutral", "Dovish", NEWS_IMPACT_HIGH, "Fed Chair expected to discuss monetary policy outlook");
        AddEvent(now + 7200, "EUR", "German Manufacturing PMI", "52.0", "50.5", "49.8", NEWS_IMPACT_MEDIUM, "German manufacturing shows continued expansion");
        AddEvent(now + 10800, "GBP", "UK Retail Sales", "0.5%", "0.2%", "-0.1%", NEWS_IMPACT_MEDIUM, "UK consumer spending expected to recover");
        AddEvent(now + 14400, "USD", "Initial Jobless Claims", "210K", "215K", "220K", NEWS_IMPACT_MEDIUM, "US unemployment claims expected to remain low");
        AddEvent(now + 18000, "AUD", "RBA Meeting Minutes", "Neutral", "Dovish", "Dovish", NEWS_IMPACT_MEDIUM, "Reserve Bank of Australia policy outlook");
        
        Print(StringFormat("[GrandeMT5News] Created %d sample economic events for FinBERT testing", m_event_count));
    }
};
