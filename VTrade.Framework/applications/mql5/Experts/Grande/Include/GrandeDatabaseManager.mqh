//+------------------------------------------------------------------+
//| GrandeDatabaseManager.mqh                                        |
//| Database management for Grande Trading System                    |
//| Copyright 2025, Grande Tech                                     |
//+------------------------------------------------------------------+
//
// PURPOSE:
//   Manage SQLite database for storing trading data, decisions, and analysis.
//   Provides structured storage for AI-driven analysis and performance tracking.
//
// RESPONSIBILITIES:
//   - Create and manage database schema
//   - Insert market data (OHLCV, indicators)
//   - Insert regime detection data
//   - Insert key level detections
//   - Insert trade decisions and outcomes
//   - Insert sentiment analysis data
//   - Insert economic calendar events
//   - Insert performance metrics
//   - Create database indexes for performance
//   - Backup and optimize database
//
// DEPENDENCIES:
//   - None (standalone component)
//   - Uses MT5 database functions: DatabaseOpen, DatabaseExecute, DatabasePrepare
//
// STATE MANAGED:
//   - Database connection handle
//   - Database file path
//   - Connection status
//   - Debug logging flag
//
// PUBLIC INTERFACE:
//   bool Initialize(dbPath, showDebug) - Initialize database
//   bool Close() - Close database connection
//   bool CreateTables() - Create schema
//   bool InsertMarketData(...) - Insert market data
//   bool InsertRegimeData(...) - Insert regime data
//   bool InsertKeyLevel(...) - Insert key level
//   bool InsertTradeDecision(...) - Insert trade decision
//   bool InsertSentimentData(...) - Insert sentiment data
//   bool InsertEconomicEvent(...) - Insert economic event
//   bool BackupDatabase(path) - Backup database
//   bool OptimizeDatabase() - Optimize database
//
// DATABASE SCHEMA:
//   - market_data: OHLCV and technical indicators
//   - market_regimes: Regime detection history
//   - key_levels: Support/resistance levels
//   - trade_decisions: All trading decisions
//   - sentiment_data: FinBERT sentiment analysis
//   - economic_events: Economic calendar events
//   - performance_metrics: System performance data
//   - config_snapshots: Configuration history
//
// IMPLEMENTATION NOTES:
//   - Uses SQLite via MT5 database API
//   - Implements SQL injection protection (string escaping)
//   - Creates indexes for query performance
//   - Supports database backup and optimization
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestDatabaseManager.mqh
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
    
    // Historical data backfill methods
    bool              BackfillHistoricalData(const string symbol, const int timeframe,
                                            const datetime startDate, const datetime endDate);
    bool              BackfillRecentHistory(const string symbol, const int timeframe, const int days = 30);
    bool              HasHistoricalData(const string symbol, const datetime checkDate);
    bool              BarExists(const string symbol, const int timeframe, const datetime barTime);
    datetime          GetOldestDataTimestamp(const string symbol);
    datetime          GetNewestDataTimestamp(const string symbol);
    bool              PurgeDataOlderThan(const datetime cutoffDate);
    string            GetDataCoverageStats(const string symbol);
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

//+------------------------------------------------------------------+
//| Historical Data Backfill Methods                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Backfill historical data for specified period                    |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::BackfillHistoricalData(const string symbol, 
                                                     const int timeframe,
                                                     const datetime startDate, 
                                                     const datetime endDate)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
    {
        Print("[GrandeDB] ERROR: Database not connected for backfill");
        return false;
    }
    
    Print("[GrandeDB] Starting historical data backfill for ", symbol);
    Print("[GrandeDB] Period: ", TimeToString(startDate, TIME_DATE), " to ", TimeToString(endDate, TIME_DATE));
    Print("[GrandeDB] Timeframe: ", timeframe);
    
    // Fetch historical data using CopyRates
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    int copied = CopyRates(symbol, (ENUM_TIMEFRAMES)timeframe, startDate, endDate, rates);
    if(copied <= 0)
    {
        Print("[GrandeDB] ERROR: Failed to copy historical data. Error: ", GetLastError());
        return false;
    }
    
    Print("[GrandeDB] Retrieved ", copied, " bars - starting batch insert");
    
    // Start database transaction for performance
    DatabaseTransactionBegin(m_dbHandle);
    
    int inserted = 0;
    int skipped = 0;
    int batchSize = 1000;
    
    for(int i = 0; i < copied; i++)
    {
        // Check if bar already exists to avoid duplicates
        if(BarExists(symbol, timeframe, rates[i].time))
        {
            skipped++;
            continue;
        }
        
        // Insert bar data (with 0 for indicators - can be calculated later if needed)
        if(InsertMarketData(symbol, timeframe, rates[i].time,
                           rates[i].open, rates[i].high, rates[i].low, rates[i].close,
                           (double)rates[i].tick_volume,
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        {
            inserted++;
        }
        
        // Commit batch and start new transaction every 1000 bars
        if((i + 1) % batchSize == 0)
        {
            DatabaseTransactionCommit(m_dbHandle);
            Print("[GrandeDB] Progress: ", inserted, "/", copied, " bars inserted");
            DatabaseTransactionBegin(m_dbHandle);
        }
    }
    
    // Commit final batch
    DatabaseTransactionCommit(m_dbHandle);
    
    Print("[GrandeDB] Backfill complete: ", inserted, " bars inserted, ", skipped, " skipped (duplicates)");
    
    // Optimize database after large insert
    if(inserted > 1000)
    {
        Print("[GrandeDB] Optimizing database after backfill...");
        OptimizeDatabase();
    }
    
    return inserted > 0;
}

//+------------------------------------------------------------------+
//| Backfill recent history (last N days)                            |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::BackfillRecentHistory(const string symbol, 
                                                    const int timeframe,
                                                    const int days)
{
    datetime endDate = TimeCurrent();
    datetime startDate = endDate - (days * 24 * 3600);
    
    Print("[GrandeDB] Quick backfill: last ", days, " days");
    
    return BackfillHistoricalData(symbol, timeframe, startDate, endDate);
}

//+------------------------------------------------------------------+
//| Check if historical data exists for symbol on date               |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::HasHistoricalData(const string symbol, const datetime checkDate)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
        return false;
    
    string sql = StringFormat(
        "SELECT COUNT(*) FROM market_data WHERE symbol='%s' AND timestamp >= '%s' LIMIT 1",
        EscapeString(symbol),
        TimeToString(checkDate, TIME_DATE|TIME_SECONDS)
    );
    
    int stmt = DatabasePrepare(m_dbHandle, sql);
    if(stmt == INVALID_HANDLE)
        return false;
    
    int count = 0;
    if(DatabaseRead(stmt))
    {
        DatabaseColumnInteger(stmt, 0, count);
    }
    
    DatabaseFinalize(stmt);
    return count > 0;
}

//+------------------------------------------------------------------+
//| Check if specific bar exists in database                         |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::BarExists(const string symbol, const int timeframe, const datetime barTime)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
        return false;
    
    string sql = StringFormat(
        "SELECT COUNT(*) FROM market_data WHERE symbol='%s' AND timeframe=%d AND timestamp='%s' LIMIT 1",
        EscapeString(symbol),
        timeframe,
        TimeToString(barTime, TIME_DATE|TIME_SECONDS)
    );
    
    int stmt = DatabasePrepare(m_dbHandle, sql);
    if(stmt == INVALID_HANDLE)
        return false;
    
    int count = 0;
    if(DatabaseRead(stmt))
    {
        DatabaseColumnInteger(stmt, 0, count);
    }
    
    DatabaseFinalize(stmt);
    return count > 0;
}

//+------------------------------------------------------------------+
//| Get oldest data timestamp for symbol                             |
//+------------------------------------------------------------------+
datetime CGrandeDatabaseManager::GetOldestDataTimestamp(const string symbol)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
        return 0;
    
    string sql = StringFormat(
        "SELECT MIN(timestamp) FROM market_data WHERE symbol='%s'",
        EscapeString(symbol)
    );
    
    int stmt = DatabasePrepare(m_dbHandle, sql);
    if(stmt == INVALID_HANDLE)
        return 0;
    
    string timeStr = "";
    if(DatabaseRead(stmt))
    {
        DatabaseColumnText(stmt, 0, timeStr);
    }
    
    DatabaseFinalize(stmt);
    
    if(timeStr == "" || timeStr == "NULL")
        return 0;
    
    return StringToTime(timeStr);
}

//+------------------------------------------------------------------+
//| Get newest data timestamp for symbol                             |
//+------------------------------------------------------------------+
datetime CGrandeDatabaseManager::GetNewestDataTimestamp(const string symbol)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
        return 0;
    
    string sql = StringFormat(
        "SELECT MAX(timestamp) FROM market_data WHERE symbol='%s'",
        EscapeString(symbol)
    );
    
    int stmt = DatabasePrepare(m_dbHandle, sql);
    if(stmt == INVALID_HANDLE)
        return 0;
    
    string timeStr = "";
    if(DatabaseRead(stmt))
    {
        DatabaseColumnText(stmt, 0, timeStr);
    }
    
    DatabaseFinalize(stmt);
    
    if(timeStr == "" || timeStr == "NULL")
        return 0;
    
    return StringToTime(timeStr);
}

//+------------------------------------------------------------------+
//| Purge data older than specified date                             |
//+------------------------------------------------------------------+
bool CGrandeDatabaseManager::PurgeDataOlderThan(const datetime cutoffDate)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
    {
        Print("[GrandeDB] ERROR: Database not connected for purge");
        return false;
    }
    
    Print("[GrandeDB] Purging data older than ", TimeToString(cutoffDate, TIME_DATE));
    
    // Count records to be purged
    string countSql = StringFormat(
        "SELECT COUNT(*) FROM market_data WHERE timestamp < '%s'",
        TimeToString(cutoffDate, TIME_DATE|TIME_SECONDS)
    );
    
    int stmt = DatabasePrepare(m_dbHandle, countSql);
    int recordsToPurge = 0;
    if(stmt != INVALID_HANDLE)
    {
        if(DatabaseRead(stmt))
        {
            DatabaseColumnInteger(stmt, 0, recordsToPurge);
        }
        DatabaseFinalize(stmt);
    }
    
    if(recordsToPurge == 0)
    {
        Print("[GrandeDB] No old data to purge");
        return true;
    }
    
    Print("[GrandeDB] Purging ", recordsToPurge, " old records...");
    
    // Purge market data
    string sql = StringFormat(
        "DELETE FROM market_data WHERE timestamp < '%s'",
        TimeToString(cutoffDate, TIME_DATE|TIME_SECONDS)
    );
    
    bool result = ExecuteSQL(sql);
    
    if(result)
    {
        Print("[GrandeDB] Purged ", recordsToPurge, " records - optimizing database...");
        OptimizeDatabase();
        Print("[GrandeDB] Purge completed successfully");
    }
    else
    {
        Print("[GrandeDB] ERROR: Purge failed");
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Get data coverage statistics                                     |
//+------------------------------------------------------------------+
string CGrandeDatabaseManager::GetDataCoverageStats(const string symbol)
{
    if(!m_isConnected || m_dbHandle == INVALID_HANDLE)
        return "Database not connected";
    
    datetime oldest = GetOldestDataTimestamp(symbol);
    datetime newest = GetNewestDataTimestamp(symbol);
    int totalRecords = GetRecordCount("market_data");
    
    string stats = "\n=== DATA COVERAGE STATISTICS ===\n";
    stats += StringFormat("Symbol: %s\n", symbol);
    
    if(oldest > 0)
    {
        stats += StringFormat("Oldest Data: %s\n", TimeToString(oldest, TIME_DATE|TIME_MINUTES));
        stats += StringFormat("Newest Data: %s\n", TimeToString(newest, TIME_DATE|TIME_MINUTES));
        
        int daysCoverage = (int)((newest - oldest) / 86400);
        stats += StringFormat("Coverage Period: %d days\n", daysCoverage);
    }
    else
    {
        stats += "No historical data found\n";
    }
    
    stats += StringFormat("Total Records: %d\n", totalRecords);
    stats += "===============================\n";
    
    return stats;
}
