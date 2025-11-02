//+------------------------------------------------------------------+
//| GrandeDatabaseManager.mqh                                        |
//| Database management for Grande Trading System                    |
//| Copyright 2025, Grande Tech                                     |
//+------------------------------------------------------------------+

#property copyright "Grande Tech"
#property version   "1.00"
#property description "Database management for Grande Trading System"

//+------------------------------------------------------------------+
//| Database Manager Class                                           |
//+------------------------------------------------------------------+
class CGrandeDatabaseManager
{
private:
    int               m_dbHandle;
    string            m_dbPath;
    bool              m_isConnected;
    bool              m_showDebugPrints;
    
    // Helper functions
    bool              ExecuteSQL(const string sql);
    bool              CreateIndexes();
    string            EscapeString(const string inputStr);
    
public:
    CGrandeDatabaseManager();
    ~CGrandeDatabaseManager();
    
    // Core database operations
    bool              Initialize(const string dbPath, const bool showDebug);
    bool              Initialize(const string dbPath);
    bool              Initialize();
    bool              Close();
    bool              IsConnected() const { return m_isConnected; }
    
    // Table creation
    bool              CreateTables();
    bool              BackupDatabase(const string backupPath);
    bool              OptimizeDatabase();
    
    // Market data operations
    bool              InsertMarketData(const string symbol, const int timeframe, 
                                      const datetime timestamp, const double open, 
                                      const double high, const double low, 
                                      const double close, const double volume,
                                      const double atr, const double adx_h1,
                                      const double adx_h4, const double adx_d1,
                                      const double rsi_current, const double rsi_h4,
                                      const double rsi_d1, const double ema_20,
                                      const double ema_50, const double ema_200,
                                      const double stoch_k, const double stoch_d);
    
    // Regime data operations
    bool              InsertRegimeData(const string symbol, const datetime timestamp,
                                      const string regime, const double confidence,
                                      const double adx_h1, const double adx_h4,
                                      const double adx_d1, const double atr_current,
                                      const string volatility_level);
    
    // Key level operations
    bool              InsertKeyLevel(const string symbol, const datetime timestamp,
                                    const double price, const string level_type,
                                    const int strength, const int touches,
                                    const double touch_zone);
    
    bool              UpdateKeyLevelStatus(const int levelId, const bool isActive);
    
    // Trade decision operations
    bool              InsertTradeDecision(const string symbol, const datetime timestamp,
                                         const string signal_type, const string decision,
                                         const string rejection_reason, const double entry_price,
                                         const double stop_loss, const double take_profit,
                                         const double lot_size, const double risk_percent,
                                         const string regime_at_entry, const double rsi_at_entry,
                                         const double adx_at_entry, const double key_level_distance,
                                         const double volume_ratio);
    
    bool              UpdateTradeOutcome(const int decisionId, const string outcome,
                                       const double pnl, const int duration_minutes);
    
    // Sentiment data operations
    bool              InsertSentimentData(const string symbol, const datetime timestamp,
                                         const string sentiment_type, const string signal,
                                         const double score, const double confidence,
                                         const string reasoning, const int article_count,
                                         const int event_count, const double surprise_magnitude,
                                         const string economic_significance, const double market_impact_score);
    
    // Economic events operations
    bool              InsertEconomicEvent(const datetime timestamp, const string currency,
                                         const string event_name, const double actual_value,
                                         const double forecast_value, const double previous_value,
                                         const string impact_level, const double surprise_score,
                                         const string finbert_signal, const double finbert_confidence);
    
    // Performance metrics operations
    bool              InsertPerformanceMetric(const string symbol, const datetime timestamp,
                                            const string metric_type, const double value,
                                            const datetime period_start, const datetime period_end);
    
    // Configuration snapshots
    bool              InsertConfigSnapshot(const datetime timestamp, const string config_type,
                                         const string config_data);
    
    // Query operations for AI analysis
    bool              GetMarketDataRange(const string symbol, const datetime start_time,
                                        const datetime end_time, const int timeframe,
                                        double &data[]);
    
    bool              GetTradeDecisionsByRegime(const string regime, const datetime start_time,
                                               const datetime end_time);
    
    bool              GetPerformanceMetrics(const string symbol, const datetime start_time,
                                          const datetime end_time);
    
    // Utility functions
    int               GetRecordCount(const string tableName);
    bool              TableExists(const string tableName);
    string            GetDatabasePath() const { return m_dbPath; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CGrandeDatabaseManager::CGrandeDatabaseManager()
{
    m_dbHandle = INVALID_HANDLE;
    m_dbPath = "";
    m_isConnected = false;
    m_showDebugPrints = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGrandeDatabaseManager::~CGrandeDatabaseManager()
{
    Close();
}

//+------------------------------------------------------------------+
//| Initialize database connection                                   |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::Initialize(const string dbPath, const bool showDebug)
{
    m_showDebugPrints = showDebug;
    m_dbPath = dbPath;
    
    if(m_showDebugPrints)
        Print("[GrandeDB] Initializing database: ", m_dbPath);
    
    // Open database connection
    m_dbHandle = DatabaseOpen(m_dbPath, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);
    if(m_dbHandle == INVALID_HANDLE)
    {
        Print("[GrandeDB] ERROR: Failed to open database: ", m_dbPath);
        return false;
    }
    
    m_isConnected = true;
    
    // Create tables if they don't exist
    if(!CreateTables())
    {
        Print("[GrandeDB] ERROR: Failed to create database tables");
        Close();
        return false;
    }
    
    // Create indexes for performance
    if(!CreateIndexes())
    {
        Print("[GrandeDB] WARNING: Failed to create some indexes");
    }
    
    if(m_showDebugPrints)
        Print("[GrandeDB] Database initialized successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize database connection (with default path)              |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::Initialize(const string dbPath)
{
    return Initialize(dbPath, false);
}

//+------------------------------------------------------------------+
//| Initialize database connection (with default path and debug)     |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::Initialize()
{
    return Initialize("GrandeTradingData.db", false);
}

//+------------------------------------------------------------------+
//| Close database connection                                        |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::Close()
{
    if(m_isConnected && m_dbHandle != INVALID_HANDLE)
    {
        if(m_showDebugPrints)
            Print("[GrandeDB] Closing database connection");
        
        DatabaseClose(m_dbHandle);
        m_dbHandle = INVALID_HANDLE;
        m_isConnected = false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Execute SQL statement                                           |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::ExecuteSQL(const string sql)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
    {
        Print("[GrandeDB] ERROR: Database not connected");
        return false;
    }
    
    if(m_showDebugPrints)
        Print("[GrandeDB] Executing SQL: ", sql);
    
    bool result = DatabaseExecute(m_dbHandle, sql);
    if(!result)
    {
        Print("[GrandeDB] ERROR: SQL execution failed: ", sql);
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Escape string for SQL                                           |
//+------------------------------------------------------------------+
string CGrandeDatabaseManager::EscapeString(const string inputStr)
{
    string result = "";
    int len = StringLen(inputStr);
    
    for(int i = 0; i < len; i++)
    {
        string currentChar = StringSubstr(inputStr, i, 1);
        if(currentChar == "'")
        {
            result += "''";
        }
        else
        {
            result += currentChar;
        }
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Create database tables                                           |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::CreateTables()
{
    if(m_showDebugPrints)
        Print("[GrandeDB] Creating database tables...");
    
    // Core market data table
    string sql = "CREATE TABLE IF NOT EXISTS market_data ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "symbol TEXT NOT NULL, "
                "timeframe INTEGER NOT NULL, "
                "timestamp DATETIME NOT NULL, "
                "open_price REAL NOT NULL, "
                "high_price REAL NOT NULL, "
                "low_price REAL NOT NULL, "
                "close_price REAL NOT NULL, "
                "volume REAL, "
                "atr REAL, "
                "adx_h1 REAL, "
                "adx_h4 REAL, "
                "adx_d1 REAL, "
                "rsi_current REAL, "
                "rsi_h4 REAL, "
                "rsi_d1 REAL, "
                "ema_20 REAL, "
                "ema_50 REAL, "
                "ema_200 REAL, "
                "stoch_k REAL, "
                "stoch_d REAL, "
                "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";
    
    if(!ExecuteSQL(sql)) return false;
    
    // Market regime detection table
    sql = "CREATE TABLE IF NOT EXISTS market_regimes ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "symbol TEXT NOT NULL, "
          "timestamp DATETIME NOT NULL, "
          "regime TEXT NOT NULL, "
          "confidence REAL NOT NULL, "
          "adx_h1 REAL, "
          "adx_h4 REAL, "
          "adx_d1 REAL, "
          "atr_current REAL, "
          "volatility_level TEXT, "
          "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";
    
    if(!ExecuteSQL(sql)) return false;
    
    // Key level detection table
    sql = "CREATE TABLE IF NOT EXISTS key_levels ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "symbol TEXT NOT NULL, "
          "timestamp DATETIME NOT NULL, "
          "price REAL NOT NULL, "
          "level_type TEXT NOT NULL, "
          "strength INTEGER NOT NULL, "
          "touches INTEGER NOT NULL, "
          "touch_zone REAL NOT NULL, "
          "is_active BOOLEAN DEFAULT 1, "
          "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";
    
    if(!ExecuteSQL(sql)) return false;
    
    // Trade decisions table
    sql = "CREATE TABLE IF NOT EXISTS trade_decisions ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "symbol TEXT NOT NULL, "
          "timestamp DATETIME NOT NULL, "
          "signal_type TEXT NOT NULL, "
          "decision TEXT NOT NULL, "
          "rejection_reason TEXT, "
          "entry_price REAL, "
          "stop_loss REAL, "
          "take_profit REAL, "
          "lot_size REAL, "
          "risk_percent REAL, "
          "regime_at_entry TEXT, "
          "rsi_at_entry REAL, "
          "adx_at_entry REAL, "
          "key_level_distance REAL, "
          "volume_ratio REAL, "
          "outcome TEXT, "
          "pnl REAL, "
          "duration_minutes INTEGER, "
          "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";
    
    if(!ExecuteSQL(sql)) return false;
    
    // Sentiment analysis data table
    sql = "CREATE TABLE IF NOT EXISTS sentiment_data ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "symbol TEXT NOT NULL, "
          "timestamp DATETIME NOT NULL, "
          "sentiment_type TEXT NOT NULL, "
          "signal TEXT NOT NULL, "
          "score REAL NOT NULL, "
          "confidence REAL NOT NULL, "
          "reasoning TEXT, "
          "article_count INTEGER, "
          "event_count INTEGER, "
          "surprise_magnitude REAL, "
          "economic_significance TEXT, "
          "market_impact_score REAL, "
          "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";
    
    if(!ExecuteSQL(sql)) return false;
    
    // Economic calendar events table
    sql = "CREATE TABLE IF NOT EXISTS economic_events ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "timestamp DATETIME NOT NULL, "
          "currency TEXT NOT NULL, "
          "event_name TEXT NOT NULL, "
          "actual_value REAL, "
          "forecast_value REAL, "
          "previous_value REAL, "
          "impact_level TEXT NOT NULL, "
          "surprise_score REAL, "
          "finbert_signal TEXT, "
          "finbert_confidence REAL, "
          "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";
    
    if(!ExecuteSQL(sql)) return false;
    
    // Performance metrics table
    sql = "CREATE TABLE IF NOT EXISTS performance_metrics ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "symbol TEXT NOT NULL, "
          "timestamp DATETIME NOT NULL, "
          "metric_type TEXT NOT NULL, "
          "value REAL NOT NULL, "
          "period_start DATETIME, "
          "period_end DATETIME, "
          "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";
    
    if(!ExecuteSQL(sql)) return false;
    
    // System configuration snapshots table
    sql = "CREATE TABLE IF NOT EXISTS config_snapshots ("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "timestamp DATETIME NOT NULL, "
          "config_type TEXT NOT NULL, "
          "config_data TEXT NOT NULL, "
          "created_at DATETIME DEFAULT CURRENT_TIMESTAMP)";
    
    if(!ExecuteSQL(sql)) return false;
    
    if(m_showDebugPrints)
        Print("[GrandeDB] All tables created successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Create database indexes for performance                          |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::CreateIndexes()
{
    if(m_showDebugPrints)
        Print("[GrandeDB] Creating database indexes...");
    
    // Market data indexes
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_market_data_symbol_time ON market_data(symbol, timestamp)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_market_data_timeframe ON market_data(timeframe)");
    
    // Regime indexes
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_regimes_symbol_time ON market_regimes(symbol, timestamp)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_regimes_regime ON market_regimes(regime)");
    
    // Key level indexes
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_key_levels_symbol_time ON key_levels(symbol, timestamp)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_key_levels_type ON key_levels(level_type)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_key_levels_active ON key_levels(is_active)");
    
    // Trade decision indexes
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_trade_decisions_symbol_time ON trade_decisions(symbol, timestamp)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_trade_decisions_signal ON trade_decisions(signal_type)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_trade_decisions_decision ON trade_decisions(decision)");
    
    // Sentiment indexes
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_sentiment_symbol_time ON sentiment_data(symbol, timestamp)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_sentiment_type ON sentiment_data(sentiment_type)");
    
    // Economic events indexes
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_economic_events_time ON economic_events(timestamp)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_economic_events_currency ON economic_events(currency)");
    
    // Performance metrics indexes
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_performance_symbol_time ON performance_metrics(symbol, timestamp)");
    ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_performance_type ON performance_metrics(metric_type)");
    
    if(m_showDebugPrints)
        Print("[GrandeDB] Indexes created successfully");
    
    return true;
}

//+------------------------------------------------------------------+
//| Insert market data                                               |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::InsertMarketData(const string symbol, const int timeframe, 
                                              const datetime timestamp, const double open, 
                                              const double high, const double low, 
                                              const double close, const double volume,
                                              const double atr, const double adx_h1,
                                              const double adx_h4, const double adx_d1,
                                              const double rsi_current, const double rsi_h4,
                                              const double rsi_d1, const double ema_20,
                                              const double ema_50, const double ema_200,
                                              const double stoch_k, const double stoch_d)
{
    string sql = StringFormat("INSERT INTO market_data (symbol, timeframe, timestamp, open_price, high_price, low_price, close_price, volume, atr, adx_h1, adx_h4, adx_d1, rsi_current, rsi_h4, rsi_d1, ema_20, ema_50, ema_200, stoch_k, stoch_d) VALUES ('%s', %d, '%s', %.5f, %.5f, %.5f, %.5f, %.2f, %.5f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.5f, %.5f, %.5f, %.2f, %.2f)",
                              EscapeString(symbol), timeframe, TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
                              open, high, low, close, volume, atr, adx_h1, adx_h4, adx_d1,
                              rsi_current, rsi_h4, rsi_d1, ema_20, ema_50, ema_200, stoch_k, stoch_d);
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Insert regime data                                               |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::InsertRegimeData(const string symbol, const datetime timestamp,
                                              const string regime, const double confidence,
                                              const double adx_h1, const double adx_h4,
                                              const double adx_d1, const double atr_current,
                                              const string volatility_level)
{
    string sql = StringFormat("INSERT INTO market_regimes (symbol, timestamp, regime, confidence, adx_h1, adx_h4, adx_d1, atr_current, volatility_level) VALUES ('%s', '%s', '%s', %.3f, %.2f, %.2f, %.2f, %.5f, '%s')",
                              EscapeString(symbol), TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
                              EscapeString(regime), confidence, adx_h1, adx_h4, adx_d1, atr_current,
                              EscapeString(volatility_level));
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Insert key level                                                 |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::InsertKeyLevel(const string symbol, const datetime timestamp,
                                            const double price, const string level_type,
                                            const int strength, const int touches,
                                            const double touch_zone)
{
    string sql = StringFormat("INSERT INTO key_levels (symbol, timestamp, price, level_type, strength, touches, touch_zone) VALUES ('%s', '%s', %.5f, '%s', %d, %d, %.5f)",
                              EscapeString(symbol), TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
                              price, EscapeString(level_type), strength, touches, touch_zone);
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Update key level status                                          |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::UpdateKeyLevelStatus(const int levelId, const bool isActive)
{
    string sql = StringFormat("UPDATE key_levels SET is_active = %d WHERE id = %d", isActive ? 1 : 0, levelId);
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Insert trade decision                                            |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::InsertTradeDecision(const string symbol, const datetime timestamp,
                                                 const string signal_type, const string decision,
                                                 const string rejection_reason, const double entry_price,
                                                 const double stop_loss, const double take_profit,
                                                 const double lot_size, const double risk_percent,
                                                 const string regime_at_entry, const double rsi_at_entry,
                                                 const double adx_at_entry, const double key_level_distance,
                                                 const double volume_ratio)
{
    string sql = StringFormat("INSERT INTO trade_decisions (symbol, timestamp, signal_type, decision, rejection_reason, entry_price, stop_loss, take_profit, lot_size, risk_percent, regime_at_entry, rsi_at_entry, adx_at_entry, key_level_distance, volume_ratio) VALUES ('%s', '%s', '%s', '%s', '%s', %.5f, %.5f, %.5f, %.2f, %.2f, '%s', %.2f, %.2f, %.5f, %.2f)",
                              EscapeString(symbol), TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
                              EscapeString(signal_type), EscapeString(decision), EscapeString(rejection_reason),
                              entry_price, stop_loss, take_profit, lot_size, risk_percent,
                              EscapeString(regime_at_entry), rsi_at_entry, adx_at_entry, key_level_distance, volume_ratio);
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Update trade outcome                                             |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::UpdateTradeOutcome(const int decisionId, const string outcome,
                                                 const double pnl, const int duration_minutes)
{
    string sql = StringFormat("UPDATE trade_decisions SET outcome = '%s', pnl = %.2f, duration_minutes = %d WHERE id = %d",
                              EscapeString(outcome), pnl, duration_minutes, decisionId);
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Insert sentiment data                                            |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::InsertSentimentData(const string symbol, const datetime timestamp,
                                                 const string sentiment_type, const string signal,
                                                 const double score, const double confidence,
                                                 const string reasoning, const int article_count,
                                                 const int event_count, const double surprise_magnitude,
                                                 const string economic_significance, const double market_impact_score)
{
    string sql = StringFormat("INSERT INTO sentiment_data (symbol, timestamp, sentiment_type, signal, score, confidence, reasoning, article_count, event_count, surprise_magnitude, economic_significance, market_impact_score) VALUES ('%s', '%s', '%s', '%s', %.3f, %.3f, '%s', %d, %d, %.3f, '%s', %.3f)",
                              EscapeString(symbol), TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
                              EscapeString(sentiment_type), EscapeString(signal), score, confidence,
                              EscapeString(reasoning), article_count, event_count, surprise_magnitude,
                              EscapeString(economic_significance), market_impact_score);
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Insert economic event                                            |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::InsertEconomicEvent(const datetime timestamp, const string currency,
                                                 const string event_name, const double actual_value,
                                                 const double forecast_value, const double previous_value,
                                                 const string impact_level, const double surprise_score,
                                                 const string finbert_signal, const double finbert_confidence)
{
    string sql = StringFormat("INSERT INTO economic_events (timestamp, currency, event_name, actual_value, forecast_value, previous_value, impact_level, surprise_score, finbert_signal, finbert_confidence) VALUES ('%s', '%s', '%s', %.5f, %.5f, %.5f, '%s', %.3f, '%s', %.3f)",
                              TimeToString(timestamp, TIME_DATE|TIME_SECONDS), EscapeString(currency),
                              EscapeString(event_name), actual_value, forecast_value, previous_value,
                              EscapeString(impact_level), surprise_score, EscapeString(finbert_signal), finbert_confidence);
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Insert performance metric                                        |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::InsertPerformanceMetric(const string symbol, const datetime timestamp,
                                                     const string metric_type, const double value,
                                                     const datetime period_start, const datetime period_end)
{
    string periodStartStr = (period_start > 0) ? TimeToString(period_start, TIME_DATE|TIME_SECONDS) : "NULL";
    string periodEndStr = (period_end > 0) ? TimeToString(period_end, TIME_DATE|TIME_SECONDS) : "NULL";
    
    string sql = StringFormat("INSERT INTO performance_metrics (symbol, timestamp, metric_type, value, period_start, period_end) VALUES ('%s', '%s', '%s', %.5f, %s, %s)",
                              EscapeString(symbol), TimeToString(timestamp, TIME_DATE|TIME_SECONDS),
                              EscapeString(metric_type), value, periodStartStr, periodEndStr);
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Insert configuration snapshot                                    |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::InsertConfigSnapshot(const datetime timestamp, const string config_type,
                                                   const string config_data)
{
    string sql = StringFormat("INSERT INTO config_snapshots (timestamp, config_type, config_data) VALUES ('%s', '%s', '%s')",
                              TimeToString(timestamp, TIME_DATE|TIME_SECONDS), EscapeString(config_type),
                              EscapeString(config_data));
    
    return ExecuteSQL(sql);
}

//+------------------------------------------------------------------+
//| Get record count for table                                      |
//+------------------------------------------------------------------+
int CGrandeDatabaseManager::GetRecordCount(const string tableName)
{
    string sql = StringFormat("SELECT COUNT(*) FROM %s", EscapeString(tableName));
    
    int stmt = DatabasePrepare(m_dbHandle, sql);
    if(stmt == INVALID_HANDLE)
    {
        Print("[GrandeDB] ERROR: Failed to prepare count query for table: ", tableName);
        return -1;
    }
    
    int count = 0;
    if(DatabaseRead(stmt))
    {
        DatabaseColumnInteger(stmt, 0, count);
    }
    
    DatabaseFinalize(stmt);
    return count;
}

//+------------------------------------------------------------------+
//| Check if table exists                                            |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::TableExists(const string tableName)
{
    return DatabaseTableExists(m_dbHandle, tableName);
}

//+------------------------------------------------------------------+
//| Backup database                                                  |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::BackupDatabase(const string backupPath)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
    {
        Print("[GrandeDB] ERROR: Database not connected for backup");
        return false;
    }
    
    // Close current connection
    Close();
    
    // Copy database file
    if(!FileCopy(m_dbPath, 0, backupPath, FILE_REWRITE))
    {
        Print("[GrandeDB] ERROR: Failed to backup database to: ", backupPath);
        return false;
    }
    
    // Reopen connection
    return Initialize(m_dbPath, m_showDebugPrints);
}

//+------------------------------------------------------------------+
//| Optimize database                                                |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::OptimizeDatabase()
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
    {
        Print("[GrandeDB] ERROR: Database not connected for optimization");
        return false;
    }
    
    if(m_showDebugPrints)
        Print("[GrandeDB] Optimizing database...");
    
    // Run VACUUM to optimize database
    bool result = ExecuteSQL("VACUUM");
    
    if(m_showDebugPrints)
        Print("[GrandeDB] Database optimization completed: ", result ? "SUCCESS" : "FAILED");
    
    return result;
}
