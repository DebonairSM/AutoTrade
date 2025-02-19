//+------------------------------------------------------------------+
//|                                               MarketHours.mqh    |
//|                   Example: Market Hours Conversion Class         |
//+------------------------------------------------------------------+
#ifndef __MARKETHOURS_MQH__
#define __MARKETHOURS_MQH__

class CMarketHours
  {
public:
    // Market session times defined in EST.
    int m_openHourEST;   // Market opens at this hour in EST.
    int m_closeHourEST;  // Market closes at this hour in EST.
    
    // The offset in hours between server time and EST.
    // Example: If server time is 17:00 when it is 10:00 EST, then the offset is 7.
    int m_serverToESTOffset;

    // Constructor: Initialize with session start, end and offset.
    CMarketHours(int openHourEST = 10, int closeHourEST = 17, int offset = 7)
      {
         m_openHourEST     = openHourEST;
         m_closeHourEST    = closeHourEST;
         m_serverToESTOffset = offset;
      }

    // Returns true if the current time (converted to EST) is within the market session.
    bool IsMarketOpen()
      {
         // Obtain the current server time.
         datetime serverTime = TimeCurrent();
         MqlDateTime dt;
         TimeToStruct(serverTime, dt);

         // Convert server time to EST using the fixed offset.
         int hourEST = dt.hour - m_serverToESTOffset;
         if (hourEST < 0)
            hourEST += 24;

         // Debug output (optional).
         PrintFormat("MarketHours: Server Time: %02d:%02d, EST Time: %02d:%02d", dt.hour, dt.min, hourEST, dt.min);

         // Check if the converted hour is within the session range.
         if (hourEST >= m_openHourEST && hourEST < m_closeHourEST)
            return true;
         return false;
      }
  };

#endif // __MARKETHOURS_MQH__ 