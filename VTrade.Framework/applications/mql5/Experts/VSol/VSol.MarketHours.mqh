//+------------------------------------------------------------------+
//|                                           VSol.MarketHours.mqh   |
//|                   Market Hours Utility Class for VSol            |
//+------------------------------------------------------------------+
#ifndef __VSOL_MARKETHOURS_MQH__
#define __VSOL_MARKETHOURS_MQH__

#include "VSol.Market.mqh"  // Include for ENUM_MARKET_TYPE definition

class CVSolMarketHours
  {
private:
   // The offset in hours between the broker's server time and Eastern Time (ET).
   // Example: When it's 7:00 ET (Florida), server shows 14:00, so offset = 7
   // This means server time is 7 hours ahead of ET
   static const int s_serverToETOffset;

public:
   /**
    * @brief Returns the current hour in Eastern Time (ET) based on the server time.
    * 
    * @return int Current hour in ET (Eastern Time, Florida) (0-23)
    */
   static int GetCurrentHourET(void)
     {
        datetime now = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(now, dt);
        
        // Convert server time to ET using the fixed offset
        int hourET = dt.hour - s_serverToETOffset;
        if(hourET < 0)
           hourET += 24;
           
        return hourET;
     }

   /**
    * @brief Logs current time conversion details (for initialization)
    */
   static void LogTimeConversion(void)
     {
        if(!MQLInfoInteger(MQL_DEBUG)) return;
        
        datetime now = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(now, dt);
        
        int hourET = dt.hour - s_serverToETOffset;
        if(hourET < 0)
           hourET += 24;
           
        PrintFormat(
           "Time Conversion Setup:\n" +
           "Server Time: %02d:%02d\n" +
           "ET (Florida): %02d:%02d\n" +
           "Server is %d hours ahead of ET",
           dt.hour, dt.min,
           hourET, dt.min,
           s_serverToETOffset
        );
     }

   /**
    * @brief Checks if a given hour falls within a specified session range.
    * 
    * @param hour The current hour (in ET)
    * @param startHour Session start hour (inclusive)
    * @param endHour Session end hour (exclusive)
    * @return true if the hour is within the range, false otherwise
    */
   static bool IsWithinSession(const int hour, const int startHour, const int endHour)
     {
        return (hour >= startHour && hour < endHour);
     }

   /**
    * @brief Determines the session volume factor based on current session overlaps.
    * 
    * For example:
    * - London & New York overlap returns 1.3
    * - Asian & London overlap returns 1.2
    * - Otherwise, returns 1.0
    * 
    * @return double The volume factor multiplier
    */
   static double GetSessionVolumeFactor()
     {
        int hourET = GetCurrentHourET();
        
        bool isAsianSession  = IsWithinSession(hourET, 0, 8);   // 00:00 - 08:00 ET
        bool isLondonSession = IsWithinSession(hourET, 3, 11);  // 03:00 - 11:00 ET
        bool isNYSession     = IsWithinSession(hourET, 8, 17);  // 08:00 - 17:00 ET
        
        if(isLondonSession && isNYSession)
           return 1.3;  // London-New York overlap
        if(isAsianSession && isLondonSession)
           return 1.2;  // Asian-London overlap
        
        return 1.0;
     }

   /**
    * @brief Checks if the market is open for trading based on the market type and trade permission.
    * 
    * Market Hours (ET):
    * - Forex: 24/5 (Sun 5PM - Fri 5PM ET)
    * - Crypto: 24/7
    * - US Stocks/Indices: Mon-Fri 9:30 AM - 4:00 PM ET
    * 
    * @param marketType The type of market (e.g., FOREX, CRYPTO, STOCKS)
    * @param isTradeAllowed Flag indicating whether trading is allowed on the symbol
    * @return true if the market is open, false otherwise
    */
   static bool IsMarketOpen(const ENUM_MARKET_TYPE marketType, const bool isTradeAllowed)
     {
        // Get current time components
        datetime now = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(now, dt);
        int hourET = GetCurrentHourET();
        
        // For crypto markets, assume the market is always open
        if(marketType == MARKET_TYPE_CRYPTO)
           return isTradeAllowed;
           
        // Check if it's weekend (Saturday = 6, Sunday = 0)
        bool isWeekend = (dt.day_of_week == 0 || dt.day_of_week == 6);
        
        // Handle different market types
        switch(marketType)
        {
            case MARKET_TYPE_FOREX:
                {
                    // Forex trades 24/5 (Sun 5PM - Fri 5PM ET)
                    if(dt.day_of_week == 5 && hourET >= 17)  // Friday after 5PM ET
                        return false;
                    if(dt.day_of_week == 0 && hourET < 17)   // Sunday before 5PM ET
                        return false;
                    if(isWeekend)
                        return false;
                    return isTradeAllowed;
                }
                
            case MARKET_TYPE_INDEX_US500:
                {
                    // US Markets: Mon-Fri 9:30 AM - 4:00 PM ET
                    if(isWeekend)
                        return false;
                    bool isRegularSession = IsWithinSession(hourET, 9, 16) && 
                                          (hourET != 9 || dt.min >= 30);  // After 9:30 AM
                    return isRegularSession && isTradeAllowed;
                }
                
            default:
                return false;
        }
     }
  };

// Define the static member outside the class
const int CVSolMarketHours::s_serverToETOffset = 7;

#endif // __VSOL_MARKETHOURS_MQH__ 