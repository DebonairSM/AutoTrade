// PatternAnalyzer.mqh
#include "Utility.mqh"

class PatternAnalyzer {
public:
    static bool IsBullishCandlePattern();
    static bool IsBearishCandlePattern();
    static int IdentifyTrendPattern();
    static bool CheckRSIDivergence(bool &bullish, bool &bearish, int lookback = 10);
    static void GetDynamicRSIThresholds(double &upper_threshold, double &lower_threshold);
};