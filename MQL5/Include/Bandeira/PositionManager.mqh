// PositionManager.mqh
#include "Utility.mqh"

class PositionManager {
private:
    CTrade trade;
    double MinPriceChangeThreshold;

public:
    PositionManager() : MinPriceChangeThreshold(10) {}
    
    void ApplyTrailingStop(ulong ticket, int type, double open_price, double stop_loss);
    void ApplyBreakeven(ulong ticket, int type, double open_price, double stop_loss);
    bool ManagePositions(int checkType = -1);
    void ProcessBuySignal(double lotSize, double stopLoss, double takeProfit);
    void ProcessSellSignal(double lotSize, double stopLoss, double takeProfit);
};