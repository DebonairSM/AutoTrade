//+------------------------------------------------------------------+
//|                                             VSol.Validator.mqh    |
//|                        Trade Validation Implementation             |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include "VSol.Market.mqh"
#include "VSol.Utils.mqh"

class CVSolValidator : public CVSolMarketBase
{
private:
    double m_minDistance;
    double m_maxSpread;
    bool m_checkMarketOpen;
    bool m_checkSpreadLevels;
    
public:
    bool Init(double minDistance, double maxSpread, bool checkMarketOpen = true, bool checkSpreadLevels = true)
    {
        m_minDistance = minDistance;
        m_maxSpread = maxSpread;
        m_checkMarketOpen = checkMarketOpen;
        m_checkSpreadLevels = checkSpreadLevels;
        return true;
    }
    
    bool ValidateEntry(double entryPrice, double stopLoss, double takeProfit)
    {
        if(m_checkMarketOpen && !IsMarketOpen())
            return false;
            
        if(m_checkSpreadLevels && !IsSpreadAcceptable())
            return false;
            
        // Check minimum distance for SL/TP
        double minDistancePoints = m_minDistance * _Point;
        if(MathAbs(entryPrice - stopLoss) < minDistancePoints ||
           MathAbs(entryPrice - takeProfit) < minDistancePoints)
            return false;
            
        return true;
    }
    
    bool IsMarketOpen()
    {
        datetime serverTime = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(serverTime, dt);
        
        // Check if weekend
        if(dt.day_of_week == 0 || dt.day_of_week == 6)
            return false;
            
        return true;
    }
    
    bool IsSpreadAcceptable()
    {
        double currentSpread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
        return (currentSpread <= m_maxSpread * _Point);
    }
}; 