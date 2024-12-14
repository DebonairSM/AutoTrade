#include <Trade/Trade.mqh>
#include "Utility.mqh"
#include "TrendFollowingStrategy.mqh"

class TradingCore {
private:
    CTrade trade;
    double starting_balance;
    double LastModificationPrice;
    TrendFollowingStrategy* strategy;
    
    // Core trading methods
    int TrendFollowingCore() {
        return strategy.CheckTrendSignal();
    }
    
    void ExecuteTradingLogic() {
        // Check if within trading hours first
        if (!IsWithinTradingHours(TradingStartTime, TradingEndTime))
            return;

        // Check drawdown before proceeding
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        if (CheckDrawdown(MaxDrawdownPercent, accountBalance, accountEquity))
            return;

        int signal = TrendFollowingCore();
        if (signal != 0) {
            // Process the signal
            double stopLoss, takeProfit;
            CalculateDynamicSLTP(stopLoss, takeProfit, ATRMultiplier, Timeframe, fixedStopLossPips);
            
            if (signal > 0) {
                ProcessBuySignal(lotSize, stopLoss, takeProfit);
            }
            else if (signal < 0) {
                ProcessSellSignal(lotSize, stopLoss, takeProfit);
            }
        }
    }
    
public:
    TradingCore(
        double riskPercent,
        double atrMultiplier,
        int adxPeriod,
        double trendAdxThreshold,
        double rsiUpperThreshold,
        double rsiLowerThreshold,
        ENUM_TIMEFRAMES timeframe,
        bool allowShortTrades
    ) {
        starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        LastModificationPrice = 0;
        
        strategy = new TrendFollowingStrategy(
            riskPercent,
            atrMultiplier,
            adxPeriod,
            trendAdxThreshold,
            rsiUpperThreshold,
            rsiLowerThreshold,
            timeframe,
            allowShortTrades
        );
    }
    
    ~TradingCore() {
        if (strategy != NULL) {
            delete strategy;
            strategy = NULL;
        }
    }
    
    void OnTick() {
        ExecuteTradingLogic();
    }
    
    bool Initialize() {
        return true;
    }
    
    void Deinitialize() {
        // Cleanup code here
    }
};
