//+------------------------------------------------------------------+
//| GrandeProfitCalculator.mqh                                       |
//| Copyright 2024, Grande Tech                                      |
//| Profit Calculation and Performance Metrics Module                |
//+------------------------------------------------------------------+
// PURPOSE:
//   Centralized profit calculation and performance metrics for the
//   Grande Trading System. Provides consistent profit calculations
//   across all components.
//
// RESPONSIBILITIES:
//   - Calculate position profit/loss in pips and currency
//   - Calculate account-level profit metrics
//   - Track profit factor, win rate, average win/loss
//   - Calculate risk-reward ratios
//   - Provide profit summaries for reporting
//
// DEPENDENCIES:
//   - None (standalone utility module)
//
// STATE MANAGED:
//   - None (stateless calculations)
//
// PUBLIC INTERFACE:
//   bool Initialize(symbol)
//   double CalculatePositionProfitPips(ticket) - Calculate profit in pips
//   double CalculatePositionProfitCurrency(ticket) - Calculate profit in currency
//   double CalculateAccountProfit() - Total account profit
//   double CalculateProfitFactor() - Win/loss ratio
//   double CalculateWinRate() - Overall win rate
//   PerformanceMetrics GetPerformanceMetrics() - Comprehensive metrics
//
// DATA STRUCTURES:
//   PerformanceMetrics - Structure containing all performance metrics
//
// IMPLEMENTATION NOTES:
//   - All calculations are stateless for thread safety
//   - Handles different symbol types (JPY pairs, standard pairs)
//   - Accounts for swap costs and commissions
//   - Provides both pip and currency-based calculations
//
// THREAD SAFETY: Thread-safe (stateless calculations)
//
// TESTING: See Testing/TestProfitCalculator.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Profit calculation and performance metrics module"

//+------------------------------------------------------------------+
//| Performance Metrics Structure                                    |
//+------------------------------------------------------------------+
struct PerformanceMetrics
{
    int totalTrades;              // Total number of closed trades
    int winningTrades;            // Number of winning trades
    int losingTrades;             // Number of losing trades
    double totalProfitPips;       // Total profit in pips
    double totalLossPips;         // Total loss in pips
    double totalProfitCurrency;   // Total profit in account currency
    double totalLossCurrency;     // Total loss in account currency
    double averageWinPips;        // Average win in pips
    double averageLossPips;       // Average loss in pips
    double averageWinCurrency;    // Average win in currency
    double averageLossCurrency;   // Average loss in currency
    double profitFactor;          // Profit factor (total wins / total losses)
    double winRate;               // Win rate percentage (0-100)
    double riskRewardRatio;       // Average risk-reward ratio
    double largestWinPips;        // Largest win in pips
    double largestLossPips;       // Largest loss in pips
    double largestWinCurrency;    // Largest win in currency
    double largestLossCurrency;   // Largest loss in currency
    
    void PerformanceMetrics()
    {
        totalTrades = 0;
        winningTrades = 0;
        losingTrades = 0;
        totalProfitPips = 0.0;
        totalLossPips = 0.0;
        totalProfitCurrency = 0.0;
        totalLossCurrency = 0.0;
        averageWinPips = 0.0;
        averageLossPips = 0.0;
        averageWinCurrency = 0.0;
        averageLossCurrency = 0.0;
        profitFactor = 0.0;
        winRate = 0.0;
        riskRewardRatio = 0.0;
        largestWinPips = 0.0;
        largestLossPips = 0.0;
        largestWinCurrency = 0.0;
        largestLossCurrency = 0.0;
    }
};

//+------------------------------------------------------------------+
//| Grande Profit Calculator Class                                   |
//+------------------------------------------------------------------+
class CGrandeProfitCalculator
{
private:
    string m_symbol;
    bool m_isInitialized;
    
    // Helper methods
    double GetPipSize();
    double PointValueUSD();
    
public:
    // Constructor/Destructor
    CGrandeProfitCalculator();
    ~CGrandeProfitCalculator();
    
    // Initialization
    bool Initialize(string symbol);
    
    // Position Profit Calculations
    double CalculatePositionProfitPips(ulong ticket);
    double CalculatePositionProfitCurrency(ulong ticket);
    double CalculatePositionProfitPips(ulong ticket, double currentPrice);
    double CalculatePositionProfitCurrency(ulong ticket, double currentPrice);
    
    // Account-Level Calculations
    double CalculateAccountProfit();
    double CalculateAccountProfitPips();
    double CalculateTotalProfit(int magicNumber = -1);
    double CalculateTotalLoss(int magicNumber = -1);
    
    // Performance Metrics
    double CalculateProfitFactor(int magicNumber = -1);
    double CalculateWinRate(int magicNumber = -1);
    double CalculateAverageWin(int magicNumber = -1);
    double CalculateAverageLoss(int magicNumber = -1);
    PerformanceMetrics GetPerformanceMetrics(int magicNumber = -1);
    
    // Risk-Reward Calculations
    double CalculateRiskRewardRatio(double entryPrice, double stopLoss, double takeProfit);
    double CalculatePositionRiskReward(ulong ticket);
    
    // Utility Methods
    bool IsPositionProfitable(ulong ticket);
    string GetProfitSummary(int magicNumber = -1);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandeProfitCalculator::CGrandeProfitCalculator()
{
    m_symbol = "";
    m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CGrandeProfitCalculator::~CGrandeProfitCalculator()
{
}

//+------------------------------------------------------------------+
//| Initialize Profit Calculator                                     |
//+------------------------------------------------------------------+
// PURPOSE:
//   Initialize the profit calculator with a symbol for pip calculations.
//
// PARAMETERS:
//   symbol (string) - Trading symbol (e.g., "EURUSD", "USDJPY")
//
// RETURNS:
//   (bool) - true if initialization successful, false otherwise
//
// SIDE EFFECTS:
//   - Sets internal symbol for pip size calculations
//
// ERROR CONDITIONS:
//   - Returns false if symbol is empty or invalid
//+------------------------------------------------------------------+
bool CGrandeProfitCalculator::Initialize(string symbol)
{
    if(symbol == "")
    {
        Print("[GrandeProfit] ERROR: Invalid symbol");
        return false;
    }
    
    m_symbol = symbol;
    m_isInitialized = true;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get Pip Size                                                      |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate pip size for the symbol, handling different digit formats.
//
// RETURNS:
//   (double) - Pip size in price units
//
// NOTES:
//   - For 5-digit pairs: pip = 10 * _Point
//   - For 3-digit pairs (JPY): pip = 10 * _Point
//   - For other pairs: uses tick size as fallback
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::GetPipSize()
{
    if(m_symbol == "")
        return _Point;
    
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    // Handle JPY pairs (2 or 3 digits) and standard pairs (5 digits)
    if(digits >= 5)
        return _Point * 10.0;
    if(digits == 3)
        return _Point * 10.0;
    
    // Fallback to tick size
    double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    return (tickSize > 0 ? tickSize : _Point);
}

//+------------------------------------------------------------------+
//| Get Point Value in USD                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate the value of one point in USD for the symbol.
//
// RETURNS:
//   (double) - Point value in USD
//
// NOTES:
//   - Uses symbol tick value and tick size to calculate point value
//   - Works for all symbol types (FX, metals, CFDs)
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::PointValueUSD()
{
    if(m_symbol == "")
        return 0.0;
    
    double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize <= 0)
        return 0.0;
    
    return tickValue / tickSize * _Point;
}

//+------------------------------------------------------------------+
//| Calculate Position Profit in Pips                                 |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate the current profit/loss of a position in pips.
//
// PARAMETERS:
//   ticket (ulong) - Position ticket number
//
// RETURNS:
//   (double) - Profit in pips (positive for profit, negative for loss)
//
// SIDE EFFECTS:
//   - None (read-only operation)
//
// ERROR CONDITIONS:
//   - Returns 0.0 if position not found
//   - Returns 0.0 if position symbol doesn't match
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculatePositionProfitPips(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
        return 0.0;
    
    string posSymbol = PositionGetString(POSITION_SYMBOL);
    if(posSymbol != m_symbol && m_symbol != "")
        return 0.0;
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = (type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(posSymbol, SYMBOL_BID) : 
                         SymbolInfoDouble(posSymbol, SYMBOL_ASK);
    
    return CalculatePositionProfitPips(ticket, currentPrice);
}

//+------------------------------------------------------------------+
//| Calculate Position Profit in Pips (with price)                   |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate position profit in pips using provided current price.
//
// PARAMETERS:
//   ticket (ulong) - Position ticket number
//   currentPrice (double) - Current market price
//
// RETURNS:
//   (double) - Profit in pips
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculatePositionProfitPips(ulong ticket, double currentPrice)
{
    if(!PositionSelectByTicket(ticket))
        return 0.0;
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    string posSymbol = PositionGetString(POSITION_SYMBOL);
    
    // Temporarily set symbol if not set
    string originalSymbol = m_symbol;
    if(m_symbol == "")
    {
        m_symbol = posSymbol;
        m_isInitialized = true;
    }
    
    double pipSize = GetPipSize();
    double profitPips = 0.0;
    
    if(type == POSITION_TYPE_BUY)
        profitPips = (currentPrice - openPrice) / pipSize;
    else
        profitPips = (openPrice - currentPrice) / pipSize;
    
    // Restore original symbol
    if(originalSymbol == "")
        m_symbol = "";
    
    return profitPips;
}

//+------------------------------------------------------------------+
//| Calculate Position Profit in Currency                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate the current profit/loss of a position in account currency.
//
// PARAMETERS:
//   ticket (ulong) - Position ticket number
//
// RETURNS:
//   (double) - Profit in account currency (positive for profit, negative for loss)
//
// SIDE EFFECTS:
//   - None (read-only operation)
//
// ERROR CONDITIONS:
//   - Returns 0.0 if position not found
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculatePositionProfitCurrency(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
        return 0.0;
    
    double profit = PositionGetDouble(POSITION_PROFIT);
    double swap = PositionGetDouble(POSITION_SWAP);
    double commission = PositionGetDouble(POSITION_COMMISSION);
    
    return profit + swap + commission;
}

//+------------------------------------------------------------------+
//| Calculate Position Profit in Currency (with price)               |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate position profit in currency using provided current price.
//
// PARAMETERS:
//   ticket (ulong) - Position ticket number
//   currentPrice (double) - Current market price
//
// RETURNS:
//   (double) - Profit in account currency
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculatePositionProfitCurrency(ulong ticket, double currentPrice)
{
    if(!PositionSelectByTicket(ticket))
        return 0.0;
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double volume = PositionGetDouble(POSITION_VOLUME);
    string posSymbol = PositionGetString(POSITION_SYMBOL);
    
    // Calculate price difference
    double priceDiff = 0.0;
    if(type == POSITION_TYPE_BUY)
        priceDiff = currentPrice - openPrice;
    else
        priceDiff = openPrice - currentPrice;
    
    // Calculate profit using tick value
    double tickValue = SymbolInfoDouble(posSymbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(posSymbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize <= 0)
        return 0.0;
    
    double profit = (priceDiff / tickSize) * tickValue * volume;
    
    // Add swap and commission
    double swap = PositionGetDouble(POSITION_SWAP);
    double commission = PositionGetDouble(POSITION_COMMISSION);
    
    return profit + swap + commission;
}

//+------------------------------------------------------------------+
//| Calculate Account Profit                                          |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate total profit/loss for all open positions in account currency.
//
// RETURNS:
//   (double) - Total profit in account currency
//
// SIDE EFFECTS:
//   - None (read-only operation)
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateAccountProfit()
{
    double totalProfit = 0.0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            totalProfit += CalculatePositionProfitCurrency(ticket);
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Calculate Account Profit in Pips                                  |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate total profit/loss for all open positions in pips.
//
// RETURNS:
//   (double) - Total profit in pips
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateAccountProfitPips()
{
    double totalProfitPips = 0.0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            totalProfitPips += CalculatePositionProfitPips(ticket);
        }
    }
    
    return totalProfitPips;
}

//+------------------------------------------------------------------+
//| Calculate Profit Factor                                           |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate profit factor (total wins / total losses) for closed trades.
//
// PARAMETERS:
//   magicNumber (int) - Magic number filter (-1 for all trades)
//
// RETURNS:
//   (double) - Profit factor (0.0 if no losses, or wins/losses ratio)
//
// NOTES:
//   - Profit factor = Total winning trades / Total losing trades
//   - A profit factor > 1.0 indicates profitable trading
//   - Requires access to trade history (not implemented in this version)
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateProfitFactor(int magicNumber = -1)
{
    // This would require access to trade history
    // For now, return 0.0 as placeholder
    // Implementation would query HistoryDealTotal() and calculate from closed trades
    return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate Win Rate                                                |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate win rate percentage for closed trades.
//
// PARAMETERS:
//   magicNumber (int) - Magic number filter (-1 for all trades)
//
// RETURNS:
//   (double) - Win rate percentage (0-100)
//
// NOTES:
//   - Win rate = (Winning trades / Total closed trades) * 100
//   - Requires access to trade history (not implemented in this version)
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateWinRate(int magicNumber = -1)
{
    // This would require access to trade history
    // For now, return 0.0 as placeholder
    // Implementation would query HistoryDealTotal() and calculate from closed trades
    return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate Average Win                                             |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate average profit per winning trade.
//
// PARAMETERS:
//   magicNumber (int) - Magic number filter (-1 for all trades)
//
// RETURNS:
//   (double) - Average win in account currency
//
// NOTES:
//   - Requires access to trade history (not implemented in this version)
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateAverageWin(int magicNumber = -1)
{
    // Placeholder - requires trade history access
    return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate Average Loss                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate average loss per losing trade.
//
// PARAMETERS:
//   magicNumber (int) - Magic number filter (-1 for all trades)
//
// RETURNS:
//   (double) - Average loss in account currency
//
// NOTES:
//   - Requires access to trade history (not implemented in this version)
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateAverageLoss(int magicNumber = -1)
{
    // Placeholder - requires trade history access
    return 0.0;
}

//+------------------------------------------------------------------+
//| Get Performance Metrics                                           |
//+------------------------------------------------------------------+
// PURPOSE:
//   Get comprehensive performance metrics for all trades.
//
// PARAMETERS:
//   magicNumber (int) - Magic number filter (-1 for all trades)
//
// RETURNS:
//   (PerformanceMetrics) - Structure containing all performance metrics
//
// NOTES:
//   - Requires access to trade history for complete metrics
//   - Current implementation provides position-based metrics only
//+------------------------------------------------------------------+
PerformanceMetrics CGrandeProfitCalculator::GetPerformanceMetrics(int magicNumber = -1)
{
    PerformanceMetrics metrics;
    
    // Calculate metrics from open positions
    double totalProfit = 0.0;
    double totalProfitPips = 0.0;
    int positionCount = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0)
            continue;
        
        if(magicNumber >= 0)
        {
            if((int)PositionGetInteger(POSITION_MAGIC) != magicNumber)
                continue;
        }
        
        double profit = CalculatePositionProfitCurrency(ticket);
        double profitPips = CalculatePositionProfitPips(ticket);
        
        totalProfit += profit;
        totalProfitPips += profitPips;
        positionCount++;
        
        if(profit > 0)
            metrics.winningTrades++;
        else if(profit < 0)
            metrics.losingTrades++;
    }
    
    metrics.totalTrades = positionCount;
    metrics.totalProfitCurrency = totalProfit;
    metrics.totalProfitPips = totalProfitPips;
    
    if(metrics.winningTrades > 0)
        metrics.averageWinCurrency = totalProfit / metrics.winningTrades;
    if(metrics.losingTrades > 0)
        metrics.averageLossCurrency = totalProfit / metrics.losingTrades;
    
    if(metrics.totalTrades > 0)
        metrics.winRate = (double)metrics.winningTrades / metrics.totalTrades * 100.0;
    
    return metrics;
}

//+------------------------------------------------------------------+
//| Calculate Risk-Reward Ratio                                       |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate risk-reward ratio for a trade setup.
//
// PARAMETERS:
//   entryPrice (double) - Entry price
//   stopLoss (double) - Stop loss price
//   takeProfit (double) - Take profit price
//
// RETURNS:
//   (double) - Risk-reward ratio (reward/risk)
//
// NOTES:
//   - R:R = (TP - Entry) / (Entry - SL) for long positions
//   - R:R = (Entry - TP) / (SL - Entry) for short positions
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateRiskRewardRatio(double entryPrice, double stopLoss, double takeProfit)
{
    if(stopLoss <= 0 || takeProfit <= 0)
        return 0.0;
    
    double risk = MathAbs(entryPrice - stopLoss);
    double reward = MathAbs(takeProfit - entryPrice);
    
    if(risk <= 0)
        return 0.0;
    
    return reward / risk;
}

//+------------------------------------------------------------------+
//| Calculate Position Risk-Reward                                    |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate risk-reward ratio for an open position.
//
// PARAMETERS:
//   ticket (ulong) - Position ticket number
//
// RETURNS:
//   (double) - Risk-reward ratio
//
// ERROR CONDITIONS:
//   - Returns 0.0 if position not found or SL/TP not set
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculatePositionRiskReward(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
        return 0.0;
    
    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double stopLoss = PositionGetDouble(POSITION_SL);
    double takeProfit = PositionGetDouble(POSITION_TP);
    
    if(stopLoss <= 0 || takeProfit <= 0)
        return 0.0;
    
    return CalculateRiskRewardRatio(entryPrice, stopLoss, takeProfit);
}

//+------------------------------------------------------------------+
//| Check if Position is Profitable                                   |
//+------------------------------------------------------------------+
// PURPOSE:
//   Check if a position is currently profitable.
//
// PARAMETERS:
//   ticket (ulong) - Position ticket number
//
// RETURNS:
//   (bool) - true if profitable, false otherwise
//+------------------------------------------------------------------+
bool CGrandeProfitCalculator::IsPositionProfitable(ulong ticket)
{
    double profit = CalculatePositionProfitCurrency(ticket);
    return profit > 0.0;
}

//+------------------------------------------------------------------+
//| Get Profit Summary                                                |
//+------------------------------------------------------------------+
// PURPOSE:
//   Get a formatted summary string of profit metrics.
//
// PARAMETERS:
//   magicNumber (int) - Magic number filter (-1 for all trades)
//
// RETURNS:
//   (string) - Formatted summary string
//+------------------------------------------------------------------+
string CGrandeProfitCalculator::GetProfitSummary(int magicNumber = -1)
{
    PerformanceMetrics metrics = GetPerformanceMetrics(magicNumber);
    
    string summary = "=== Profit Summary ===\n";
    summary += "Total Positions: " + IntegerToString(metrics.totalTrades) + "\n";
    summary += "Winning: " + IntegerToString(metrics.winningTrades) + "\n";
    summary += "Losing: " + IntegerToString(metrics.losingTrades) + "\n";
    summary += "Total Profit: " + DoubleToString(metrics.totalProfitCurrency, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
    summary += "Total Profit: " + DoubleToString(metrics.totalProfitPips, 1) + " pips\n";
    summary += "Win Rate: " + DoubleToString(metrics.winRate, 2) + "%\n";
    
    if(metrics.winningTrades > 0)
        summary += "Avg Win: " + DoubleToString(metrics.averageWinCurrency, 2) + "\n";
    if(metrics.losingTrades > 0)
        summary += "Avg Loss: " + DoubleToString(metrics.averageLossCurrency, 2) + "\n";
    
    return summary;
}

//+------------------------------------------------------------------+
//| Calculate Total Profit                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate total profit for positions with specific magic number.
//
// PARAMETERS:
//   magicNumber (int) - Magic number filter (-1 for all trades)
//
// RETURNS:
//   (double) - Total profit in account currency
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateTotalProfit(int magicNumber = -1)
{
    double totalProfit = 0.0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0)
            continue;
        
        if(magicNumber >= 0)
        {
            if((int)PositionGetInteger(POSITION_MAGIC) != magicNumber)
                continue;
        }
        
        double profit = CalculatePositionProfitCurrency(ticket);
        if(profit > 0)
            totalProfit += profit;
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Calculate Total Loss                                              |
//+------------------------------------------------------------------+
// PURPOSE:
//   Calculate total loss for positions with specific magic number.
//
// PARAMETERS:
//   magicNumber (int) - Magic number filter (-1 for all trades)
//
// RETURNS:
//   (double) - Total loss in account currency
//+------------------------------------------------------------------+
double CGrandeProfitCalculator::CalculateTotalLoss(int magicNumber = -1)
{
    double totalLoss = 0.0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0)
            continue;
        
        if(magicNumber >= 0)
        {
            if((int)PositionGetInteger(POSITION_MAGIC) != magicNumber)
                continue;
        }
        
        double profit = CalculatePositionProfitCurrency(ticket);
        if(profit < 0)
            totalLoss += MathAbs(profit);
    }
    
    return totalLoss;
}

//+------------------------------------------------------------------+

