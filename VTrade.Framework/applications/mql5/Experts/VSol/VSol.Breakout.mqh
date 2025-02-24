//+------------------------------------------------------------------+
//|                                              VSol.Breakout.mqh    |
//|                        Breakout Strategy Implementation           |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include <Trade\Trade.mqh>
#include "VSol.Market.mqh"
#include "VSol.Utils.mqh"
#include "VSol.Risk.mqh"
#include "VSol.Validator.mqh"
#include "VSol.Filter.mqh"
#include "VSol.Visualizer.mqh"
#include "VSol.MultiTimeframe.mqh"

// Breakout detection constants
#define MIN_RANGE_SIZE_MULTIPLIER 1.5  // Minimum range size as multiple of ATR
#define VOLUME_CONFIRMATION_RATIO 1.5   // Required volume increase for breakout confirmation
#define MAX_SPREAD_MULTIPLIER    2.0    // Maximum allowed spread as multiple of average
#define TRAILING_ACTIVATION_PCT  0.5    // Percentage of TP to activate trailing (0.5 = 50%)

class CVSolBreakout : public CVSolMarketBase
{
private:
    // Configuration
    int m_rangeBars;
    double m_lotSize;
    int m_slippage;
    double m_stopLossPips;
    double m_takeProfitPips;
    bool m_requireRetest;
    
    // Volume analysis settings
    double m_volumeFactor;
    int m_volumeMA;
    bool m_useRelativeVolume;
    double m_minVolumeThreshold;
    
    // Risk management settings
    double m_riskPercent;
    bool m_useFixedLots;
    bool m_useTrailingStop;
    double m_trailingStart;
    double m_trailingStep;
    
    // Market state
    double m_resistanceLevel;
    double m_supportLevel;
    datetime m_lastUpdate;
    bool m_inPosition;
    ENUM_POSITION_TYPE m_positionType;
    CTrade m_trade;
    CVSolMultiTimeframe m_h1Analysis;
    
    // Position management
    bool m_isTrailing;
    double m_trailingStop;
    double m_initialStopLoss;
    double m_initialTarget;
    
    // Cached calculations
    double m_atr;
    double m_avgVolume;
    datetime m_lastH1Close;
    bool m_h1BreakoutConfirmed;
    
    // Utility functions
    double CalculateATR(int period)
    {
        if(CVSolMarketTestData::IsTestMode())  // Use public accessor
        {
            // Calculate ATR from test data
            double sum = 0;
            int count = 0;
            double prevClose = 0;
            
            for(int i = period; i > 0; i--)
            {
                double open, high, low, close;
                long volume;
                
                if(!GetMarketData(i, open, high, low, close, volume))
                    continue;
                    
                if(count > 0)
                {
                    double tr = MathMax(high - low, MathMax(MathAbs(high - prevClose), MathAbs(low - prevClose)));
                    sum += tr;
                }
                
                prevClose = close;
                count++;
            }
            
            return count > 0 ? sum / count : 0;
        }
        else
        {
            // Use standard ATR for live data
            double atr[];
            ArraySetAsSeries(atr, true);
            int handle = iATR(_Symbol, PERIOD_CURRENT, period);
            if(CopyBuffer(handle, 0, 0, 1, atr) > 0)
                return atr[0];
        }
        return 0;
    }
    
    double CalculateAverageVolume(int period)
    {
        double sum = 0;
        int count = 0;
        
        for(int i = 1; i <= period; i++)
        {
            double open, high, low, close;
            long volume;
            
            if(!GetMarketData(i, open, high, low, close, volume))
                continue;
                
            sum += (double)volume;
            count++;
        }
        
        return count > 0 ? sum / count : 0;
    }
    
    bool IsRangeValid()
    {
        double rangeSize = m_resistanceLevel - m_supportLevel;
        return (rangeSize >= m_atr * MIN_RANGE_SIZE_MULTIPLIER);
    }
    
    bool IsSpreadAcceptable()
    {
        if(CVSolMarketTestData::IsTestMode())
            return true;  // Skip spread check in test mode
            
        double currentSpread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
        return (currentSpread <= m_atr * MAX_SPREAD_MULTIPLIER);
    }
    
    bool CheckRetest(bool isLong)
    {
        if(!m_requireRetest)
            return true;
            
        double level = isLong ? m_resistanceLevel : m_supportLevel;
        double close = iClose(_Symbol, PERIOD_CURRENT, 1);
        double open = iOpen(_Symbol, PERIOD_CURRENT, 1);
        
        // Check if previous candle tested the level
        if(isLong)
        {
            return (close > level && MathMin(open, close) <= level + m_atr * 0.2);
        }
        else
        {
            return (close < level && MathMax(open, close) >= level - m_atr * 0.2);
        }
    }
    
    void UpdateTrailingStop()
    {
        if(!m_inPosition || !m_isTrailing)
            return;
            
        double currentPrice = m_positionType == POSITION_TYPE_BUY ? 
            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
        // Calculate new trailing stop based on H1 ATR
        double atrStop = m_positionType == POSITION_TYPE_BUY ?
            currentPrice - m_h1Analysis.GetH1ATR() * 1.5 :
            currentPrice + m_h1Analysis.GetH1ATR() * 1.5;
            
        // Only move stop if it would move in our favor
        if(m_positionType == POSITION_TYPE_BUY && atrStop > m_trailingStop)
        {
            m_trailingStop = atrStop;
            m_trade.PositionModify(_Symbol, m_trailingStop, 0);  // Remove TP when trailing
        }
        else if(m_positionType == POSITION_TYPE_SELL && atrStop < m_trailingStop)
        {
            m_trailingStop = atrStop;
            m_trade.PositionModify(_Symbol, m_trailingStop, 0);  // Remove TP when trailing
        }
    }
    
    //+------------------------------------------------------------------+
    //| Get market data with test data support                             |
    //+------------------------------------------------------------------+
    bool GetMarketData(int shift, double &open, double &high, double &low, 
                      double &close, long &volume)
    {
        if(CVSolMarketTestData::IsTestMode())
        {
            MqlRates candle;
            // Only return test data if within bounds of our test array
            if(CVSolMarketTestData::GetTestCandle(shift, candle))
            {
                open = candle.open;
                high = candle.high;
                low = candle.low;
                close = candle.close;
                volume = candle.tick_volume;
                return true;
            }
            // Return false if beyond test data bounds
            return false;
        }
        
        // Fall back to real market data only if not in test mode
        open = iOpen(_Symbol, Period(), shift);
        high = iHigh(_Symbol, Period(), shift);
        low = iLow(_Symbol, Period(), shift);
        close = iClose(_Symbol, Period(), shift);
        volume = iVolume(_Symbol, Period(), shift);
        
        return true;
    }
    
public:
    bool Init(int rangeBars, double lotSize, int slippage, double stopLossPips, double takeProfitPips, bool requireRetest = false)
    {
        // Store parameters
        m_rangeBars = rangeBars;
        m_lotSize = lotSize;
        m_slippage = slippage;
        m_stopLossPips = stopLossPips;
        m_takeProfitPips = takeProfitPips;
        m_requireRetest = requireRetest;
        
        // Initialize trade object
        m_trade.SetDeviationInPoints(m_slippage);
        m_trade.SetExpertMagicNumber(123456); // Use unique magic number
        
        // Reset state
        m_resistanceLevel = 0;
        m_supportLevel = 0;
        m_lastUpdate = 0;
        m_inPosition = false;
        m_isTrailing = false;
        m_h1BreakoutConfirmed = false;
        
        // Initialize volume analysis settings with defaults
        m_volumeFactor = 1.5;
        m_volumeMA = 20;
        m_useRelativeVolume = true;
        m_minVolumeThreshold = 1000;
        
        // Initialize risk management settings with defaults
        m_riskPercent = 2.0;
        m_useFixedLots = false;
        m_useTrailingStop = false;
        m_trailingStart = 20;
        m_trailingStep = 5;
        
        return true;
    }
    
    void ConfigureVolumeAnalysis(double volumeFactor, int volumeMA)
    {
        m_volumeFactor = volumeFactor;
        m_volumeMA = volumeMA;
    }
    
    void ConfigureRiskManagement(double riskPercent, bool useFixedLots, bool useTrailingStop, double trailingStart, double trailingStep)
    {
        m_riskPercent = riskPercent;
        m_useFixedLots = useFixedLots;
        m_useTrailingStop = useTrailingStop;
        m_trailingStart = trailingStart;
        m_trailingStep = trailingStep;
    }
    
    //+------------------------------------------------------------------+
    //| Update breakout levels using current market data                   |
    //+------------------------------------------------------------------+
    void UpdateLevels()
    {
        // Update H1 analysis first
        m_h1Analysis.UpdateH1Analysis();
        
        // Get current candle data
        double open, high, low, close;
        long volume;
        
        if(!GetMarketData(0, open, high, low, close, volume))
            return;
            
        // Initialize range boundaries with current candle
        double rangeHigh = high;
        double rangeLow = low;
        
        Print("Calculating range over ", m_rangeBars, " bars");
        int validBars = 0;  // Track number of valid bars
        
        // Calculate range over specified bars
        for(int i = 0; i < m_rangeBars; i++)
        {
            if(!GetMarketData(i, open, high, low, close, volume))
                break;  // Stop if we run out of test data
            
            rangeHigh = MathMax(rangeHigh, high);
            rangeLow = MathMin(rangeLow, low);
            validBars++;
            
            Print("Bar ", i, " - High: ", DoubleToString(high, 5), " Low: ", DoubleToString(low, 5));
        }
        
        if(validBars < m_rangeBars / 2)  // Require at least half the requested bars
        {
            Print("❌ Insufficient data for range calculation");
            return;
        }
        
        m_resistanceLevel = rangeHigh;
        m_supportLevel = rangeLow;
        
        Print("Final Range - Resistance: ", DoubleToString(m_resistanceLevel, 5), " Support: ", DoubleToString(m_supportLevel, 5));
        
        // Update market conditions using only valid bars
        m_atr = CalculateATR(validBars);
        m_avgVolume = CalculateAverageVolume(validBars);
        m_lastUpdate = TimeCurrent();
        
        // Check for H1 candle close
        datetime currentH1Time = iTime(_Symbol, PERIOD_H1, 0);
        if(currentH1Time != m_lastH1Close)
        {
            m_lastH1Close = currentH1Time;
            m_h1BreakoutConfirmed = false;  // Reset on new H1 candle
        }
    }
    
    //+------------------------------------------------------------------+
    //| Check for valid breakout conditions                                |
    //+------------------------------------------------------------------+
    bool CheckBreakout(bool &isLong)
    {
        Print("\n=== Checking Breakout Conditions ===");
        
        if(!IsRangeValid())
        {
            Print("❌ Range not valid");
            return false;
        }
        
        if(!IsSpreadAcceptable())
        {
            Print("❌ Spread too high");
            return false;
        }
            
        // Get current candle data
        double open, high, low, close;
        long volume;
        
        if(!GetMarketData(0, open, high, low, close, volume))
        {
            Print("❌ Failed to get market data");
            return false;
        }
        
        Print("Current Candle - Close: ", DoubleToString(close, 5), ", Volume: ", volume);
        Print("Resistance Level: ", DoubleToString(m_resistanceLevel, 5));
        Print("Support Level: ", DoubleToString(m_supportLevel, 5));
            
        // Calculate average volume using m_avgVolume from UpdateLevels
        Print("Average Volume: ", m_avgVolume);
        Print("Required Volume: ", m_avgVolume * VOLUME_CONFIRMATION_RATIO);
        
        // First check H1 trend alignment
        ENUM_TREND_TYPE h1Trend = m_h1Analysis.GetH1Trend();
        Print("H1 Trend: ", h1Trend == TREND_BULLISH ? "BULLISH" : h1Trend == TREND_BEARISH ? "BEARISH" : "NEUTRAL");
        
        // Check for breakout with volume confirmation
        if(close > m_resistanceLevel)
        {
            Print("Price above resistance");
            if(volume > m_avgVolume * VOLUME_CONFIRMATION_RATIO)
            {
                Print("Volume confirmed");
                if(h1Trend == TREND_BULLISH)
                {
                    Print("H1 trend aligned");
                    if(m_h1Analysis.IsBreakoutValid(true, close, volume))
                    {
                        Print("H1 breakout valid");
                        if(CheckRetest(true))
                        {
                            Print("✓ Retest valid - BUY signal confirmed");
                            isLong = true;
                            return true;
                        }
                        else Print("❌ Retest not valid");
                    }
                    else Print("❌ H1 breakout not valid");
                }
                else Print("❌ H1 trend not aligned");
            }
            else Print("❌ Volume not confirmed");
        }
        
        if(close < m_supportLevel)
        {
            Print("Price below support");
            if(volume > m_avgVolume * VOLUME_CONFIRMATION_RATIO)
            {
                Print("Volume confirmed");
                if(h1Trend == TREND_BEARISH)
                {
                    Print("H1 trend aligned");
                    if(m_h1Analysis.IsBreakoutValid(false, close, volume))
                    {
                        Print("H1 breakout valid");
                        if(CheckRetest(false))
                        {
                            Print("✓ Retest valid - SELL signal confirmed");
                            isLong = false;
                            return true;
                        }
                        else Print("❌ Retest not valid");
                    }
                    else Print("❌ H1 breakout not valid");
                }
                else Print("❌ H1 trend not aligned");
            }
            else Print("❌ Volume not confirmed");
        }
        
        Print("❌ No breakout conditions met");
        return false;
    }
    
    bool ExecuteBreakoutTrade(bool isLong)
    {
        if(m_inPosition)
            return false;
            
        double entryPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        m_initialStopLoss = isLong ? 
            entryPrice - m_stopLossPips * _Point : 
            entryPrice + m_stopLossPips * _Point;
        m_initialTarget = isLong ? 
            entryPrice + m_takeProfitPips * _Point : 
            entryPrice - m_takeProfitPips * _Point;
            
        bool result = isLong ? 
            m_trade.Buy(m_lotSize, _Symbol, entryPrice, m_initialStopLoss, m_initialTarget, "Breakout Buy") :
            m_trade.Sell(m_lotSize, _Symbol, entryPrice, m_initialStopLoss, m_initialTarget, "Breakout Sell");
            
        if(result)
        {
            m_inPosition = true;
            m_positionType = isLong ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            m_isTrailing = false;
            m_trailingStop = m_initialStopLoss;
        }
        
        return result;
    }
    
    void CheckPositionClose()
    {
        if(!m_inPosition)
            return;
            
        if(!PositionSelect(_Symbol))
        {
            m_inPosition = false;
            m_isTrailing = false;
            return;
        }
        
        // Check if we should switch to trailing stop
        double currentPrice = m_positionType == POSITION_TYPE_BUY ? 
            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
        double profitTarget = MathAbs(m_initialTarget - PositionGetDouble(POSITION_PRICE_OPEN));
        double currentProfit = MathAbs(currentPrice - PositionGetDouble(POSITION_PRICE_OPEN));
        
        if(!m_isTrailing && currentProfit >= profitTarget * TRAILING_ACTIVATION_PCT)
        {
            m_isTrailing = true;
            m_trailingStop = m_initialStopLoss;  // Start trailing from initial stop
        }
        
        if(m_isTrailing)
        {
            UpdateTrailingStop();
        }
    }
    
    void DrawLevels()
    {
        m_h1Analysis.DrawH1Levels();
    }
};