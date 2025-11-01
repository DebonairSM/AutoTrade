# Grande Trading System Database Schema

## Overview
This database captures comprehensive trade data for performance analysis and optimization. It replaces log file parsing with structured SQLite storage for 10-100x faster queries and persistent historical data.

## Schema Design

### 1. trades Table
Primary trade execution records with complete position details.

```sql
CREATE TABLE IF NOT EXISTS trades (
    trade_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_number INTEGER UNIQUE,
    timestamp DATETIME NOT NULL,
    symbol TEXT NOT NULL,
    signal_type TEXT NOT NULL CHECK(signal_type IN ('TREND', 'BREAKOUT', 'RANGE', 'TRIANGLE')),
    direction TEXT NOT NULL CHECK(direction IN ('BUY', 'SELL')),
    entry_price REAL NOT NULL,
    stop_loss REAL NOT NULL,
    take_profit REAL NOT NULL,
    lot_size REAL NOT NULL,
    risk_reward_ratio REAL NOT NULL,
    risk_percent REAL NOT NULL,
    outcome TEXT CHECK(outcome IN ('PENDING', 'TP_HIT', 'SL_HIT', 'MANUAL_CLOSE', 'PARTIAL_CLOSE')) DEFAULT 'PENDING',
    close_price REAL,
    close_timestamp DATETIME,
    profit_loss REAL,
    pips_gained REAL,
    duration_minutes INTEGER,
    execution_slippage REAL DEFAULT 0.0,
    account_equity_at_open REAL,
    account_equity_at_close REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_trades_timestamp ON trades(timestamp);
CREATE INDEX idx_trades_symbol ON trades(symbol);
CREATE INDEX idx_trades_signal_type ON trades(signal_type);
CREATE INDEX idx_trades_outcome ON trades(outcome);
CREATE INDEX idx_trades_ticket ON trades(ticket_number);
```

### 2. market_conditions Table
Market state at the time of each trade decision.

```sql
CREATE TABLE IF NOT EXISTS market_conditions (
    condition_id INTEGER PRIMARY KEY AUTOINCREMENT,
    trade_id INTEGER,
    timestamp DATETIME NOT NULL,
    symbol TEXT NOT NULL,
    regime TEXT NOT NULL,
    regime_confidence REAL,
    atr REAL NOT NULL,
    spread REAL,
    volume_ratio REAL,
    price_at_decision REAL NOT NULL,
    resistance_level REAL,
    support_level REAL,
    distance_to_resistance REAL,
    distance_to_support REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (trade_id) REFERENCES trades(trade_id) ON DELETE CASCADE
);

CREATE INDEX idx_market_conditions_trade_id ON market_conditions(trade_id);
CREATE INDEX idx_market_conditions_regime ON market_conditions(regime);
CREATE INDEX idx_market_conditions_timestamp ON market_conditions(timestamp);
```

### 3. indicators Table
Technical indicator values at trade decision time.

```sql
CREATE TABLE IF NOT EXISTS indicators (
    indicator_id INTEGER PRIMARY KEY AUTOINCREMENT,
    trade_id INTEGER,
    timestamp DATETIME NOT NULL,
    symbol TEXT NOT NULL,
    -- RSI Values
    rsi_current REAL,
    rsi_h4 REAL,
    rsi_d1 REAL,
    rsi_previous REAL,
    rsi_direction TEXT CHECK(rsi_direction IN ('RISING', 'FALLING', 'NEUTRAL')),
    -- ADX Values
    adx_h1 REAL,
    adx_h4 REAL,
    adx_d1 REAL,
    -- EMA Values
    ema20_h4 REAL,
    ema20_distance REAL,
    ema20_distance_pips REAL,
    -- Pullback Analysis
    base_atr_limit REAL,
    adjusted_atr_limit REAL,
    finbert_multiplier REAL DEFAULT 1.0,
    pullback_valid BOOLEAN,
    -- Stochastic (for Range trading)
    stochastic_current REAL,
    stochastic_previous REAL,
    -- Additional
    trend_follower_strength REAL,
    trend_follower_aligned BOOLEAN,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (trade_id) REFERENCES trades(trade_id) ON DELETE CASCADE
);

CREATE INDEX idx_indicators_trade_id ON indicators(trade_id);
CREATE INDEX idx_indicators_timestamp ON indicators(timestamp);
```

### 4. decisions Table
All trading decisions including rejected/blocked trades for analysis.

```sql
CREATE TABLE IF NOT EXISTS decisions (
    decision_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    symbol TEXT NOT NULL,
    signal_type TEXT NOT NULL CHECK(signal_type IN ('TREND', 'BREAKOUT', 'RANGE', 'TRIANGLE')),
    direction TEXT CHECK(direction IN ('BUY', 'SELL')),
    decision TEXT NOT NULL CHECK(decision IN ('EXECUTED', 'REJECTED', 'BLOCKED')),
    rejection_reason TEXT,
    rejection_category TEXT CHECK(rejection_category IN (
        'MARGIN_LOW', 'RSI_EXTREME', 'PULLBACK_TOO_FAR', 'EMA_MISALIGNED',
        'PATTERN_INVALID', 'COOL_OFF_ACTIVE', 'VOLATILITY_HIGH', 'NO_SIGNAL', 'OTHER'
    )),
    -- Pre-decision calculations
    calculated_lot_size REAL,
    calculated_sl REAL,
    calculated_tp REAL,
    calculated_rr REAL,
    -- Account state
    margin_level_current REAL,
    margin_level_after_trade REAL,
    margin_required_percent REAL,
    account_equity REAL NOT NULL,
    open_positions INTEGER DEFAULT 0,
    -- Calendar/Sentiment
    calendar_signal TEXT,
    calendar_confidence REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_decisions_timestamp ON decisions(timestamp);
CREATE INDEX idx_decisions_symbol ON decisions(symbol);
CREATE INDEX idx_decisions_decision ON decisions(decision);
CREATE INDEX idx_decisions_rejection_category ON decisions(rejection_category);
```

### 5. signal_analysis Table
Detailed signal validation criteria for understanding rejections.

```sql
CREATE TABLE IF NOT EXISTS signal_analysis (
    analysis_id INTEGER PRIMARY KEY AUTOINCREMENT,
    decision_id INTEGER NOT NULL,
    timestamp DATETIME NOT NULL,
    symbol TEXT NOT NULL,
    -- Criteria Results
    trend_follower_check BOOLEAN,
    ema_alignment_check BOOLEAN,
    pullback_check BOOLEAN,
    rsi_multi_tf_check BOOLEAN,
    rsi_momentum_check BOOLEAN,
    pattern_check BOOLEAN,
    volatility_check BOOLEAN,
    -- Additional Details
    criteria_passed INTEGER,
    criteria_failed INTEGER,
    failure_reasons TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (decision_id) REFERENCES decisions(decision_id) ON DELETE CASCADE
);

CREATE INDEX idx_signal_analysis_decision_id ON signal_analysis(decision_id);
```

### 6. optimization_history Table
Track parameter changes and their performance impact.

```sql
CREATE TABLE IF NOT EXISTS optimization_history (
    optimization_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    parameter_name TEXT NOT NULL,
    old_value REAL,
    new_value REAL,
    change_reason TEXT,
    trades_analyzed INTEGER,
    win_rate_before REAL,
    win_rate_after REAL,
    profit_factor_before REAL,
    profit_factor_after REAL,
    applied_by TEXT DEFAULT 'SYSTEM',
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_optimization_timestamp ON optimization_history(timestamp);
CREATE INDEX idx_optimization_parameter ON optimization_history(parameter_name);
```

### 7. performance_metrics Table
Daily/weekly performance snapshots for trend analysis.

```sql
CREATE TABLE IF NOT EXISTS performance_metrics (
    metric_id INTEGER PRIMARY KEY AUTOINCREMENT,
    period_start DATETIME NOT NULL,
    period_end DATETIME NOT NULL,
    period_type TEXT CHECK(period_type IN ('DAILY', 'WEEKLY', 'MONTHLY')) NOT NULL,
    total_trades INTEGER DEFAULT 0,
    winning_trades INTEGER DEFAULT 0,
    losing_trades INTEGER DEFAULT 0,
    win_rate REAL,
    profit_factor REAL,
    total_profit_loss REAL,
    max_drawdown REAL,
    average_win REAL,
    average_loss REAL,
    largest_win REAL,
    largest_loss REAL,
    -- By Signal Type
    trend_trades INTEGER DEFAULT 0,
    trend_win_rate REAL,
    breakout_trades INTEGER DEFAULT 0,
    breakout_win_rate REAL,
    range_trades INTEGER DEFAULT 0,
    range_win_rate REAL,
    triangle_trades INTEGER DEFAULT 0,
    triangle_win_rate REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(period_start, period_end, period_type)
);

CREATE INDEX idx_performance_period ON performance_metrics(period_start, period_end);
```

## Key Relationships

```
trades (1) ←→ (1) market_conditions
trades (1) ←→ (1) indicators
decisions (1) ←→ (0..1) trades (if EXECUTED)
decisions (1) ←→ (1) signal_analysis
```

## Data Retention Policy

- **trades, market_conditions, indicators**: Keep indefinitely (core historical data)
- **decisions**: Keep 90 days of rejected trades, indefinitely for executed
- **signal_analysis**: Keep 90 days
- **performance_metrics**: Keep indefinitely (small size)
- **optimization_history**: Keep indefinitely (audit trail)

## Example Queries

### 1. Signal Type Performance
```sql
SELECT 
    signal_type,
    COUNT(*) as total_trades,
    SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) as wins,
    SUM(CASE WHEN outcome = 'SL_HIT' THEN 1 ELSE 0 END) as losses,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(CASE WHEN outcome = 'TP_HIT' THEN pips_gained ELSE 0 END), 2) as avg_win_pips,
    ROUND(AVG(CASE WHEN outcome = 'SL_HIT' THEN pips_gained ELSE 0 END), 2) as avg_loss_pips,
    ROUND(SUM(profit_loss), 2) as total_pl
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT')
GROUP BY signal_type
ORDER BY win_rate DESC;
```

### 2. Regime-Specific Win Rates
```sql
SELECT 
    mc.regime,
    t.signal_type,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN t.outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(i.adx_h4), 2) as avg_adx,
    ROUND(AVG(i.rsi_h4), 2) as avg_rsi
FROM trades t
JOIN market_conditions mc ON t.trade_id = mc.trade_id
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome IN ('TP_HIT', 'SL_HIT')
GROUP BY mc.regime, t.signal_type
HAVING COUNT(*) >= 5
ORDER BY win_rate DESC;
```

### 3. Optimal RSI Thresholds
```sql
WITH rsi_buckets AS (
    SELECT 
        t.outcome,
        t.signal_type,
        t.direction,
        i.rsi_h4,
        CASE 
            WHEN i.rsi_h4 < 30 THEN '0-30'
            WHEN i.rsi_h4 < 40 THEN '30-40'
            WHEN i.rsi_h4 < 50 THEN '40-50'
            WHEN i.rsi_h4 < 60 THEN '50-60'
            WHEN i.rsi_h4 < 70 THEN '60-70'
            ELSE '70-100'
        END as rsi_bucket
    FROM trades t
    JOIN indicators i ON t.trade_id = i.trade_id
    WHERE t.outcome IN ('TP_HIT', 'SL_HIT')
)
SELECT 
    signal_type,
    direction,
    rsi_bucket,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate
FROM rsi_buckets
GROUP BY signal_type, direction, rsi_bucket
HAVING COUNT(*) >= 3
ORDER BY signal_type, direction, win_rate DESC;
```

### 4. Time-of-Day Performance
```sql
SELECT 
    strftime('%H', timestamp) as hour,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(profit_loss), 2) as avg_pl
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT')
GROUP BY hour
ORDER BY hour;
```

### 5. Rejection Reason Analysis
```sql
SELECT 
    rejection_category,
    COUNT(*) as occurrences,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM decisions WHERE decision = 'REJECTED'), 2) as percentage,
    symbol,
    COUNT(*) as symbol_count
FROM decisions
WHERE decision = 'REJECTED'
  AND timestamp >= datetime('now', '-7 days')
GROUP BY rejection_category, symbol
ORDER BY occurrences DESC;
```

### 6. Pullback Tolerance Effectiveness
```sql
SELECT 
    CASE 
        WHEN i.ema20_distance_pips < i.base_atr_limit THEN 'Within Base ATR'
        WHEN i.ema20_distance_pips < i.adjusted_atr_limit THEN 'Within Adjusted ATR'
        ELSE 'Beyond Limits'
    END as pullback_category,
    COUNT(*) as trades,
    ROUND(100.0 * SUM(CASE WHEN t.outcome = 'TP_HIT' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
    ROUND(AVG(i.finbert_multiplier), 2) as avg_finbert_mult
FROM trades t
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome IN ('TP_HIT', 'SL_HIT')
  AND t.signal_type = 'TREND'
GROUP BY pullback_category;
```

### 7. Stop Loss Hit Pattern Analysis
```sql
SELECT 
    t.signal_type,
    mc.regime,
    ROUND(AVG(t.duration_minutes), 0) as avg_duration_mins,
    ROUND(AVG(i.adx_h4), 2) as avg_adx,
    ROUND(AVG(mc.atr), 5) as avg_atr,
    COUNT(*) as sl_hits,
    ROUND(AVG(t.pips_gained), 2) as avg_pips_lost
FROM trades t
JOIN market_conditions mc ON t.trade_id = mc.trade_id
JOIN indicators i ON t.trade_id = i.trade_id
WHERE t.outcome = 'SL_HIT'
GROUP BY t.signal_type, mc.regime
ORDER BY sl_hits DESC;
```

### 8. Risk/Reward Actual vs Expected
```sql
SELECT 
    signal_type,
    ROUND(AVG(risk_reward_ratio), 2) as expected_rr,
    ROUND(AVG(CASE 
        WHEN outcome = 'TP_HIT' THEN ABS(pips_gained)
        ELSE 0 
    END) / NULLIF(AVG(CASE 
        WHEN outcome = 'SL_HIT' THEN ABS(pips_gained)
        ELSE 0 
    END), 0), 2) as actual_rr,
    COUNT(*) as total_trades
FROM trades
WHERE outcome IN ('TP_HIT', 'SL_HIT')
GROUP BY signal_type;
```

### 9. Incremental Analysis (Since Last Check)
```sql
SELECT 
    signal_type,
    outcome,
    COUNT(*) as new_trades,
    ROUND(AVG(profit_loss), 2) as avg_pl,
    ROUND(AVG(pips_gained), 2) as avg_pips
FROM trades
WHERE timestamp > (
    SELECT MAX(period_end) 
    FROM performance_metrics 
    WHERE period_type = 'DAILY'
)
  AND outcome IN ('TP_HIT', 'SL_HIT')
GROUP BY signal_type, outcome;
```

### 10. Parameter Optimization Impact
```sql
SELECT 
    oh.parameter_name,
    oh.old_value,
    oh.new_value,
    oh.timestamp,
    oh.win_rate_before,
    oh.win_rate_after,
    ROUND(oh.win_rate_after - oh.win_rate_before, 2) as improvement,
    oh.trades_analyzed,
    oh.change_reason
FROM optimization_history oh
ORDER BY oh.timestamp DESC
LIMIT 10;
```

## Data Population Strategy

1. **Initial Seed**: Parse historical logs (Oct 24-31) to populate existing trades
2. **Ongoing Collection**: EA logs to database before each OrderSend()
3. **Outcome Updates**: EA updates trades table when positions close
4. **Daily Aggregation**: Compute performance_metrics at end of trading day
5. **Weekly Analysis**: Run optimization queries to identify improvements

## Database File Location

**Primary Database**: `C:\Users\romme\AppData\Roaming\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\GrandeTradingData.db`

**Backup Strategy**: Daily backup to `GrandeTradingData_YYYYMMDD.db`

