//+------------------------------------------------------------------+
//| EconomicCalendar.mqh                                              |
//| VSol Software                                                      |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property version   "1.00"

#include <Bandeira/JAson.mqh>  // Required for JSON handling
#include <Bandeira/Utility.mqh>

// Structure to hold calendar event data
struct CalendarEvent
{
    string symbol;
    string instrumentType;
    datetime eventTime;
    string eventDescription;
    string impact;
    double expectedValue;
    double actualValue;
    string market;
    bool isProcessed;
    datetime createdAt;
};

// Structure to match API response
struct TradingSignal
{
    int id;
    string symbol;
    string instrumentType;
    string signal;
    string reason;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    string timeFrame;
    datetime generatedAt;
};

//+------------------------------------------------------------------+
//| Economic Calendar Class                                            |
//+------------------------------------------------------------------+
class CEconomicCalendar
{
private:
    string m_apiUrl;
    int m_retryAttempts;
    int m_retryDelay;
    
    // Helper method to convert impact level
    string ConvertImpactToString(ENUM_CALENDAR_EVENT_IMPORTANCE impact)
    {
        switch(impact)
        {
            case CALENDAR_IMPORTANCE_NONE:      return "None";
            case CALENDAR_IMPORTANCE_LOW:       return "Low";
            case CALENDAR_IMPORTANCE_MODERATE:  return "Moderate";
            case CALENDAR_IMPORTANCE_HIGH:      return "High";
            default:                           return "Unknown";
        }
    }
    
    // Create JSON payload for API
    string CreateJsonPayload(CalendarEvent& event)
    {
        CJAVal json;
        
        // Convert calendar event to trading signal
        json["symbol"] = event.symbol;
        json["instrumentType"] = event.instrumentType;
        json["signal"] = DetermineSignal(event);  // New helper method
        json["reason"] = StringFormat("Economic Calendar Event: %s (Impact: %s)", 
                                    event.eventDescription, 
                                    event.impact);
        json["entryPrice"] = SymbolInfoDouble(event.symbol, SYMBOL_BID);  // Current market price
        
        // Calculate potential SL/TP based on volatility or fixed values
        double atr = CalculateATR(14, PERIOD_H1);
        json["stopLoss"] = json["entryPrice"].ToDbl() - (atr * 1.5);
        json["takeProfit"] = json["entryPrice"].ToDbl() + (atr * 2.0);
        
        json["timeFrame"] = "H1";  // Default timeframe
        json["generatedAt"] = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
        
        return json.Serialize();
    }
    
    // Send data to API
    bool SendToApi(string jsonPayload)
    {
        string headers = "Content-Type: application/json\r\n";
        char post[], result[];
        string result_headers;
        
        StringToCharArray(jsonPayload, post, 0, StringLen(jsonPayload));
        
        int res = WebRequest(
            "POST",              // HTTP method
            m_apiUrl,           // URL
            headers,            // Headers
            5000,               // Timeout
            post,               // POST data
            result,             // Server response
            result_headers      // Response headers
        );
        
        if(res == -1)
        {
            int error = GetLastError();
            Print("Error in WebRequest. Error code = ", error);
            return false;
        }
        
        return (res == 200 || res == 201);  // Success if 200 OK or 201 Created
    }

public:
    // Constructor
    CEconomicCalendar(string apiUrl = "https://localhost:7244/api/TradingSignal/process")
    {
        m_apiUrl = apiUrl;
        m_retryAttempts = 3;
        m_retryDelay = 1000; // 1 second
    }
    
    // Process calendar events
    bool ProcessCalendarEvents()
    {
        MqlCalendarValue values[];
        MqlCalendarEvent events[];
        
        // Get current time
        datetime now = TimeCurrent();
        datetime from = now - PeriodSeconds(PERIOD_D1);
        datetime to = now + PeriodSeconds(PERIOD_D1);
        
        // Get calendar events
        if(CalendarValueHistory(values, from, to))
        {
            for(int i = 0; i < ArraySize(values); i++)
            {
                // Get event details
                if(CalendarEventById(values[i].event_id, events))
                {
                    CalendarEvent event;
                    
                    // Fill event data using the correct field names from MqlCalendarEvent and MqlCalendarValue
                    event.symbol = events.currency;  // MqlCalendarEvent.currency
                    event.instrumentType = "Forex";
                    event.eventTime = values[i].time;
                    event.eventDescription = events.event_name;  // MqlCalendarEvent.event_name
                    event.impact = ConvertImpactToString(events.importance);
                    event.expectedValue = values[i].prev_value;  // MqlCalendarValue.prev_value
                    event.actualValue = values[i].actual_value;  // MqlCalendarValue.actual_value
                    event.market = EnumToString(events.sector);
                    event.isProcessed = false;
                    event.createdAt = TimeCurrent();
                    
                    // Create JSON and send to API
                    string jsonPayload = CreateJsonPayload(event);
                    
                    // Attempt to send with retries
                    bool sent = false;
                    for(int attempt = 0; attempt < m_retryAttempts && !sent; attempt++)
                    {
                        if(attempt > 0)
                        {
                            Sleep(m_retryDelay);  // Wait before retry
                        }
                        
                        sent = SendToApi(jsonPayload);
                        
                        if(sent)
                        {
                            Print("Successfully sent calendar event: ", event.eventDescription);
                        }
                        else if(attempt == m_retryAttempts - 1)
                        {
                            Print("Failed to send calendar event after ", m_retryAttempts, " attempts: ", event.eventDescription);
                            return false;
                        }
                    }
                }
            }
            return true;
        }
        
        Print("Failed to get calendar values");
        return false;
    }
    
    // Set API URL
    void SetApiUrl(string url)
    {
        m_apiUrl = url;
    }
    
    // Set retry parameters
    void SetRetryParameters(int attempts, int delayMs)
    {
        m_retryAttempts = attempts;
        m_retryDelay = delayMs;
    }
    
    // Add helper method to determine signal direction
    string DetermineSignal(CalendarEvent& event)
    {
        if(event.actualValue > event.expectedValue)
        {
            if(event.impact == "High" || event.impact == "Moderate")
                return "BUY";
        }
        else if(event.actualValue < event.expectedValue)
        {
            if(event.impact == "High" || event.impact == "Moderate")
                return "SELL";
        }
        
        return "NEUTRAL";
    }
}; 