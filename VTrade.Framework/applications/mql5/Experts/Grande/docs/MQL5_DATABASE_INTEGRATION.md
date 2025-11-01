# Grande Trading System - MQL5 Database Integration Guide

## Overview
This document provides MQL5 code examples for integrating the Grande EA with the GrandeTradingData.db SQLite database. The integration captures comprehensive trade data before execution and logs outcomes for performance analysis.

## Database Helper Class

Create a new file: `GrandeTradingSystem_Database.mqh`

```mql5
//+------------------------------------------------------------------+
//|                              GrandeTradingSystem_Database.mqh     |
//|                        Database helper for Grande Trading System  |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Database Helper Class                                             |
//+------------------------------------------------------------------+
class CGrandeTradingDatabase
{
private:
    int      m_db;
    string   m_dbPath;
    bool     m_isConnected;
    
public:
    //--- Constructor
    CGrandeTradingDatabase()
    {
        m_db = INVALID_HANDLE;
        m_isConnected = false;
        m_dbPath = "GrandeTradingData.db";
    }
    
    //--- Destructor
    ~CGrandeTradingDatabase()
    {
        Close();
    }
    
    //--- Open database connection
    bool Open()
    {
        if(m_isConnected)
            return true;
            
        m_db = DatabaseOpen(m_dbPath, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
        
        if(m_db == INVALID_HANDLE)
        {
            Print("DB ERROR: Failed to open database: ", m_dbPath, ", Error: ", GetLastError());
            return false;
        }
        
        m_isConnected = true;
        Print("DB: Connected to ", m_dbPath);
        return true;
    }
    
    //--- Close database connection
    void Close()
    {
        if(m_isConnected && m_db != INVALID_HANDLE)
        {
            DatabaseClose(m_db);
            m_isConnected = false;
            Print("DB: Connection closed");
        }
    }
    
    //--- Execute SQL command (INSERT, UPDATE, DELETE)
    bool ExecuteCommand(string sql)
    {
        if(!m_isConnected)
        {
            Print("DB ERROR: Not connected");
            return false;
        }
        
        if(!DatabaseExecute(m_db, sql))
        {
            Print("DB ERROR: Failed to execute command");
            Print("SQL: ", sql);
            Print("Error: ", GetLastError());
            return false;
        }
        
        return true;
    }
    
    //--- Log trade before execution
    int LogTradeDecision(
        string symbol,
        string signalType,
        string direction,
        double entryPrice,
        double stopLoss,
        double takeProfit,
        double lotSize,
        double riskRewardRatio,
        double riskPercent,
        double accountEquity
    )
    {
        if(!m_isConnected && !Open())
            return -1;
            
        datetime now = TimeCurrent();
        string timestamp = TimeToString(now, TIME_DATE|TIME_SECONDS);
        timestamp = StringReplace(timestamp, ".", "-");
        
        string sql = StringFormat(
            "INSERT INTO trades (timestamp, symbol, signal_type, direction, entry_price, stop_loss, take_profit, lot_size, risk_reward_ratio, risk_percent, outcome, account_equity_at_open) " +
            "VALUES ('%s', '%s', '%s', '%s', %.5f, %.5f, %.5f, %.2f, %.2f, %.2f, 'PENDING', %.2f);",
            timestamp, symbol, signalType, direction, entryPrice, stopLoss, takeProfit, lotSize, riskRewardRatio, riskPercent, accountEquity
        );
        
        if(!ExecuteCommand(sql))
            return -1;
            
        // Get the last inserted trade_id
        int request = DatabasePrepare(m_db, "SELECT last_insert_rowid() as id;");
        if(request == INVALID_HANDLE)
            return -1;
            
        int trade_id = -1;
        if(DatabaseRead(request))
        {
            trade_id = (int)DatabaseColumnLong(request, 0);
        }
        DatabaseFinalize(request);
        
        Print("DB: Trade logged with ID: ", trade_id);
        return trade_id;
    }
    
    //--- Update trade with ticket number after OrderSend
    bool UpdateTradeTicket(int trade_id, ulong ticket)
    {
        if(!m_isConnected)
            return false;
            
        string sql = StringFormat(
            "UPDATE trades SET ticket_number = %I64u WHERE trade_id = %d;",
            ticket, trade_id
        );
        
        return ExecuteCommand(sql);
    }
    
    //--- Log market conditions
    bool LogMarketConditions(
        int trade_id,
        string symbol,
        string regime,
        double regimeConfidence,
        double atr,
        double spread,
        double volumeRatio,
        double priceAtDecision,
        double resistanceLevel,
        double supportLevel
    )
    {
        if(!m_isConnected)
            return false;
            
        datetime now = TimeCurrent();
        string timestamp = TimeToString(now, TIME_DATE|TIME_SECONDS);
        timestamp = StringReplace(timestamp, ".", "-");
        
        string sql = StringFormat(
            "INSERT INTO market_conditions (trade_id, timestamp, symbol, regime, regime_confidence, atr, spread, volume_ratio, price_at_decision, resistance_level, support_level) " +
            "VALUES (%d, '%s', '%s', '%s', %.3f, %.5f, %.5f, %.2f, %.5f, %.5f, %.5f);",
            trade_id, timestamp, symbol, regime, regimeConfidence, atr, spread, volumeRatio, priceAtDecision, resistanceLevel, supportLevel
        );
        
        return ExecuteCommand(sql);
    }
    
    //--- Log indicator values
    bool LogIndicators(
        int trade_id,
        string symbol,
        double rsi_current,
        double rsi_h4,
        double rsi_d1,
        double rsi_previous,
        string rsi_direction,
        double adx_h1,
        double adx_h4,
        double adx_d1,
        double ema20_h4,
        double ema20_distance,
        double ema20_distance_pips,
        double base_atr_limit,
        double adjusted_atr_limit,
        double finbert_multiplier,
        bool pullback_valid,
        double trend_follower_strength,
        bool trend_follower_aligned
    )
    {
        if(!m_isConnected)
            return false;
            
        datetime now = TimeCurrent();
        string timestamp = TimeToString(now, TIME_DATE|TIME_SECONDS);
        timestamp = StringReplace(timestamp, ".", "-");
        
        int pullback_int = pullback_valid ? 1 : 0;
        int aligned_int = trend_follower_aligned ? 1 : 0;
        
        string sql = StringFormat(
            "INSERT INTO indicators (trade_id, timestamp, symbol, rsi_current, rsi_h4, rsi_d1, rsi_previous, rsi_direction, " +
            "adx_h1, adx_h4, adx_d1, ema20_h4, ema20_distance, ema20_distance_pips, base_atr_limit, adjusted_atr_limit, " +
            "finbert_multiplier, pullback_valid, trend_follower_strength, trend_follower_aligned) " +
            "VALUES (%d, '%s', '%s', %.2f, %.2f, %.2f, %.2f, '%s', %.2f, %.2f, %.2f, %.5f, %.5f, %.2f, %.5f, %.5f, %.2f, %d, %.2f, %d);",
            trade_id, timestamp, symbol, rsi_current, rsi_h4, rsi_d1, rsi_previous, rsi_direction,
            adx_h1, adx_h4, adx_d1, ema20_h4, ema20_distance, ema20_distance_pips, base_atr_limit, adjusted_atr_limit,
            finbert_multiplier, pullback_int, trend_follower_strength, aligned_int
        );
        
        return ExecuteCommand(sql);
    }
    
    //--- Log trade decision (for rejected trades)
    bool LogDecision(
        string symbol,
        string signalType,
        string direction,
        string decision,
        string rejectionReason,
        string rejectionCategory,
        double accountEquity,
        int openPositions,
        double marginLevelCurrent = 0,
        double marginLevelAfterTrade = 0
    )
    {
        if(!m_isConnected && !Open())
            return false;
            
        datetime now = TimeCurrent();
        string timestamp = TimeToString(now, TIME_DATE|TIME_SECONDS);
        timestamp = StringReplace(timestamp, ".", "-");
        
        // Escape single quotes in rejection reason
        string safeReason = rejectionReason;
        StringReplace(safeReason, "'", "''");
        
        string sql = StringFormat(
            "INSERT INTO decisions (timestamp, symbol, signal_type, direction, decision, rejection_reason, rejection_category, " +
            "account_equity, open_positions, margin_level_current, margin_level_after_trade) " +
            "VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', %.2f, %d, %.2f, %.2f);",
            timestamp, symbol, signalType, direction, decision, safeReason, rejectionCategory,
            accountEquity, openPositions, marginLevelCurrent, marginLevelAfterTrade
        );
        
        return ExecuteCommand(sql);
    }
    
    //--- Update trade outcome when position closes
    bool UpdateTradeOutcome(
        ulong ticket,
        string outcome,
        double closePrice,
        double profitLoss,
        double pipsGained
    )
    {
        if(!m_isConnected)
            return false;
            
        datetime now = TimeCurrent();
        string timestamp = TimeToString(now, TIME_DATE|TIME_SECONDS);
        timestamp = StringReplace(timestamp, ".", "-");
        
        string sql = StringFormat(
            "UPDATE trades SET outcome = '%s', close_price = %.5f, close_timestamp = '%s', " +
            "profit_loss = %.2f, pips_gained = %.2f, " +
            "duration_minutes = CAST((julianday(close_timestamp) - julianday(timestamp)) * 24 * 60 AS INTEGER), " +
            "updated_at = '%s' " +
            "WHERE ticket_number = %I64u;",
            outcome, closePrice, timestamp, profitLoss, pipsGained, timestamp, ticket
        );
        
        return ExecuteCommand(sql);
    }
};
```

## Integration into Main EA

### 1. Add to EA Header Section

```mql5
//+------------------------------------------------------------------+
//|                                       GrandeTradingSystem.mq5    |
//+------------------------------------------------------------------+
#include "GrandeTradingSystem_Database.mqh"

// Global database instance
CGrandeTradingDatabase g_database;
```

### 2. Initialize in OnInit()

```mql5
//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    // ... existing initialization code ...
    
    // Initialize database
    if(!g_database.Open())
    {
        Print("WARNING: Database connection failed. Trade logging disabled.");
        // Continue execution - EA can still trade without database
    }
    else
    {
        Print("Database initialized successfully");
    }
    
    return(INIT_SUCCEEDED);
}
```

### 3. Close Database in OnDeinit()

```mql5
//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Close database connection
    g_database.Close();
    
    // ... existing cleanup code ...
}
```

### 4. Log Trade BEFORE OrderSend()

Insert this code RIGHT BEFORE calling `OrderSend()`:

```mql5
//+------------------------------------------------------------------+
//| Execute Trade with Database Logging                               |
//+------------------------------------------------------------------+
bool ExecuteTrade(
    string symbol,
    string signalType,
    int orderType,
    double entryPrice,
    double stopLoss,
    double takeProfit,
    double lotSize,
    double riskRewardRatio,
    double riskPercent,
    // Market conditions
    string regime,
    double regimeConfidence,
    double atr,
    double spread,
    double volumeRatio,
    double resistanceLevel,
    double supportLevel,
    // Indicators
    double rsi_current,
    double rsi_h4,
    double rsi_d1,
    double rsi_previous,
    string rsi_direction,
    double adx_h1,
    double adx_h4,
    double adx_d1,
    double ema20_h4,
    double ema20_distance,
    double ema20_distance_pips,
    double base_atr_limit,
    double adjusted_atr_limit,
    double finbert_multiplier,
    bool pullback_valid,
    double trend_follower_strength,
    bool trend_follower_aligned
)
{
    string direction = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Log trade decision to database BEFORE execution
    int trade_id = g_database.LogTradeDecision(
        symbol,
        signalType,
        direction,
        entryPrice,
        stopLoss,
        takeProfit,
        lotSize,
        riskRewardRatio,
        riskPercent,
        accountEquity
    );
    
    if(trade_id > 0)
    {
        // Log market conditions
        g_database.LogMarketConditions(
            trade_id,
            symbol,
            regime,
            regimeConfidence,
            atr,
            spread,
            volumeRatio,
            entryPrice,
            resistanceLevel,
            supportLevel
        );
        
        // Log indicators
        g_database.LogIndicators(
            trade_id,
            symbol,
            rsi_current,
            rsi_h4,
            rsi_d1,
            rsi_previous,
            rsi_direction,
            adx_h1,
            adx_h4,
            adx_d1,
            ema20_h4,
            ema20_distance,
            ema20_distance_pips,
            base_atr_limit,
            adjusted_atr_limit,
            finbert_multiplier,
            pullback_valid,
            trend_follower_strength,
            trend_follower_aligned
        );
    }
    
    // Now execute the actual trade
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lotSize;
    request.type = orderType;
    request.price = entryPrice;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = 5;
    request.magic = GRANDE_MAGIC_NUMBER;
    request.comment = "[GRANDE] " + signalType + "-" + direction;
    
    if(!OrderSend(request, result))
    {
        Print("OrderSend failed, error: ", GetLastError());
        Print("Return code: ", result.retcode);
        return false;
    }
    
    if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
    {
        Print("[", signalType, "] FILLED ", direction, " @", entryPrice, 
              " SL=", stopLoss, " TP=", takeProfit, 
              " lot=", lotSize, " rr=", riskRewardRatio);
        
        // Update database with ticket number
        if(trade_id > 0)
        {
            g_database.UpdateTradeTicket(trade_id, result.order);
        }
        
        return true;
    }
    
    return false;
}
```

### 5. Log Rejected Trades

When a signal is rejected, log the decision:

```mql5
//+------------------------------------------------------------------+
//| Log Rejected Signal                                               |
//+------------------------------------------------------------------+
void LogRejectedSignal(
    string symbol,
    string signalType,
    string direction,
    string rejectionReason,
    string rejectionCategory
)
{
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    int openPositions = PositionsTotal();
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    
    g_database.LogDecision(
        symbol,
        signalType,
        direction,
        "REJECTED",
        rejectionReason,
        rejectionCategory,
        accountEquity,
        openPositions,
        marginLevel,
        0.0  // margin level after trade (not applicable for rejected)
    );
}

// Example usage:
if(marginLevel < InpMinMarginLevel)
{
    LogRejectedSignal(
        Symbol(),
        "TREND",
        "SELL",
        "Margin level too low: " + DoubleToString(marginLevel, 2) + "%",
        "MARGIN_LOW"
    );
    return; // Don't execute trade
}
```

### 6. Update Outcomes in OnTrade()

```mql5
//+------------------------------------------------------------------+
//| Trade event handler                                               |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Check if any positions were closed
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) != GRANDE_MAGIC_NUMBER)
            continue;
            
        // Position still open - skip
    }
    
    // Check deal history for recently closed positions
    HistorySelect(TimeCurrent() - 60, TimeCurrent()); // Last minute
    
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong deal_ticket = HistoryDealGetTicket(i);
        if(deal_ticket <= 0) continue;
        
        long deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
        if(deal_magic != GRANDE_MAGIC_NUMBER) continue;
        
        long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
        if(deal_entry != DEAL_ENTRY_OUT) continue; // Only process exit deals
        
        ulong position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
        string symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
        double closePrice = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
        double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
        
        // Determine outcome (TP vs SL)
        string outcome = "MANUAL_CLOSE";
        string comment = HistoryDealGetString(deal_ticket, DEAL_COMMENT);
        
        if(StringFind(comment, "tp") >= 0 || StringFind(comment, "take profit") >= 0)
            outcome = "TP_HIT";
        else if(StringFind(comment, "sl") >= 0 || StringFind(comment, "stop loss") >= 0)
            outcome = "SL_HIT";
            
        // Calculate pips
        double pipsGained = 0.0;
        // Get original position data from database or calculate from closePrice vs entry
        
        // Update database
        g_database.UpdateTradeOutcome(
            position_id,
            outcome,
            closePrice,
            profit,
            pipsGained
        );
        
        Print("DB: Updated trade #", position_id, " outcome: ", outcome, " P/L: ", profit);
    }
}
```

## Rejection Categories Mapping

Map rejection reasons to categories for analysis:

```mql5
//+------------------------------------------------------------------+
//| Get rejection category from reason                                |
//+------------------------------------------------------------------+
string GetRejectionCategory(string reason)
{
    if(StringFind(reason, "margin") >= 0 || StringFind(reason, "Margin") >= 0)
        return "MARGIN_LOW";
    
    if(StringFind(reason, "RSI") >= 0 || StringFind(reason, "oversold") >= 0 || StringFind(reason, "overbought") >= 0)
        return "RSI_EXTREME";
    
    if(StringFind(reason, "pullback") >= 0 || StringFind(reason, "Pullback") >= 0 || StringFind(reason, "EMA20") >= 0)
        return "PULLBACK_TOO_FAR";
    
    if(StringFind(reason, "EMA") >= 0 || StringFind(reason, "alignment") >= 0)
        return "EMA_MISALIGNED";
    
    if(StringFind(reason, "pattern") >= 0 || StringFind(reason, "Pattern") >= 0)
        return "PATTERN_INVALID";
    
    if(StringFind(reason, "cool") >= 0 || StringFind(reason, "Cool") >= 0)
        return "COOL_OFF_ACTIVE";
    
    if(StringFind(reason, "volatility") >= 0 || StringFind(reason, "ATR") >= 0)
        return "VOLATILITY_HIGH";
    
    if(StringFind(reason, "signal") >= 0)
        return "NO_SIGNAL";
    
    return "OTHER";
}
```

## Testing Database Integration

### Test Script

Create `Scripts/TestDatabaseConnection.mq5`:

```mql5
//+------------------------------------------------------------------+
//|                                      TestDatabaseConnection.mq5   |
//+------------------------------------------------------------------+
#include "../Experts/Grande/GrandeTradingSystem_Database.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                     |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== Testing Database Connection ===");
    
    CGrandeTradingDatabase db;
    
    if(!db.Open())
    {
        Print("ERROR: Failed to open database");
        return;
    }
    
    Print("SUCCESS: Database opened");
    
    // Test logging a trade
    int trade_id = db.LogTradeDecision(
        "EURUSD",
        "TREND",
        "BUY",
        1.10000,
        1.09500,
        1.11500,
        0.10,
        3.0,
        2.0,
        1000.0
    );
    
    if(trade_id > 0)
    {
        Print("SUCCESS: Test trade logged with ID: ", trade_id);
        
        // Update with fake ticket
        if(db.UpdateTradeTicket(trade_id, 12345678))
            Print("SUCCESS: Ticket updated");
            
        // Log fake outcome
        if(db.UpdateTradeOutcome(12345678, "TP_HIT", 1.11500, 150.0, 150.0))
            Print("SUCCESS: Outcome updated");
    }
    else
    {
        Print("ERROR: Failed to log test trade");
    }
    
    db.Close();
    Print("=== Test Complete ===");
}
```

## Performance Considerations

1. **Database Connection**: Open once in `OnInit()`, close in `OnDeinit()`
2. **Batch Operations**: For multiple inserts, use transactions (not shown for simplicity)
3. **Error Handling**: EA continues trading even if database fails
4. **Disk I/O**: Minimal impact - writes are fast and asynchronous
5. **File Locking**: SQLite handles concurrent access automatically

## Next Steps

1. Add the database helper class to your EA
2. Integrate logging calls before OrderSend()
3. Add OnTrade() handler for outcomes
4. Test with Strategy Tester
5. Run SeedTradingDatabase.ps1 to import historical data
6. Run RunDailyAnalysis.ps1 for performance insights

## Troubleshooting

### Database Locked
- Close MT5 completely
- Ensure no other processes are accessing the database
- Check Windows file permissions

### Inserts Failing
- Check SQL syntax in Print statements
- Verify data types match schema
- Check for single quotes in strings (use `StringReplace()`)

### Performance Issues
- Database writes are async - no impact on trading speed
- If concerned, add a flag `input bool InpEnableDatabaseLogging = true;`

---

**Implementation Priority**: Add database logging incrementally - start with trade decisions, then add market conditions, then indicators.

