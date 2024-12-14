#include "Utility.mqh"

class TrendFollowingStrategy {
private:
    // Strategy parameters
    double RiskPercent;
    double ATRMultiplier;
    int ADXPeriod;
    double TrendADXThreshold;
    double RSIUpperThreshold;
    double RSILowerThreshold;
    ENUM_TIMEFRAMES Timeframe;
    bool AllowShortTrades;
    
public:
    TrendFollowingStrategy(
        double riskPercent,
        double atrMultiplier,
        int adxPeriod,
        double trendAdxThreshold,
        double rsiUpperThreshold,
        double rsiLowerThreshold,
        ENUM_TIMEFRAMES timeframe,
        bool allowShortTrades
    ) {
        RiskPercent = riskPercent;
        ATRMultiplier = atrMultiplier;
        ADXPeriod = adxPeriod;
        TrendADXThreshold = trendAdxThreshold;
        RSIUpperThreshold = rsiUpperThreshold;
        RSILowerThreshold = rsiLowerThreshold;
        Timeframe = timeframe;
        AllowShortTrades = allowShortTrades;
    }

    int CheckTrendSignal() {
        double sma = CalculateSMA(100, Timeframe);
        double ema = CalculateEMA(20, Timeframe);
        double rsi = CalculateRSI(14, Timeframe);
        double atr = CalculateATR(14, Timeframe);
        
        double adx, plusDI, minusDI;
        CalculateADX(ADXPeriod, Timeframe, adx, plusDI, minusDI);
        
        if (ema > sma && rsi < RSIUpperThreshold && adx > TrendADXThreshold && plusDI > minusDI) {
            return 1;  // Buy signal
        }
        else if (AllowShortTrades && ema < sma && rsi > RSILowerThreshold && adx > TrendADXThreshold && minusDI > plusDI) {
            return -1; // Sell signal
        }
        
        return 0;  // No signal
    }
};
