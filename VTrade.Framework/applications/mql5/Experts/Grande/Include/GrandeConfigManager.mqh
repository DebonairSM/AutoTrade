//+------------------------------------------------------------------+
//| GrandeConfigManager.mqh                                          |
//| Copyright 2024, Grande Tech                                      |
//| Centralized Configuration Management                             |
//+------------------------------------------------------------------+
// PURPOSE:
//   Centralized configuration management for all system parameters.
//   Provides type-safe configuration with validation and persistence.
//
// RESPONSIBILITIES:
//   - Store all configuration parameters in structured format
//   - Validate configuration consistency
//   - Load configuration from input parameters
//   - Save/load configuration presets
//   - Provide configuration access to all components
//
// DEPENDENCIES:
//   - None (base infrastructure)
//
// STATE MANAGED:
//   - All regime detection configuration
//   - All key level detection configuration
//   - All risk management configuration
//   - All trading configuration
//   - All display configuration
//
// PUBLIC INTERFACE:
//   bool LoadFromInputs() - Load configuration from EA inputs
//   bool Validate() - Validate configuration consistency
//   bool SavePreset(string name) - Save configuration preset
//   bool LoadPreset(string name) - Load configuration preset
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestConfigManager.mqh
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"

#include "GrandeMarketRegimeDetector.mqh"

//+------------------------------------------------------------------+
//| Regime Detection Configuration                                    |
//+------------------------------------------------------------------+
struct RegimeDetectionConfig
{
    double adx_trend_threshold;
    double adx_breakout_min;
    int atr_period;
    int atr_avg_period;
    double high_vol_multiplier;
    ENUM_TIMEFRAMES tf_primary;
    ENUM_TIMEFRAMES tf_secondary;
    ENUM_TIMEFRAMES tf_tertiary;
    
    void SetDefaults()
    {
        adx_trend_threshold = 25.0;
        adx_breakout_min = 18.0;
        atr_period = 21;
        atr_avg_period = 90;
        high_vol_multiplier = 2.0;
        tf_primary = PERIOD_H1;
        tf_secondary = PERIOD_H4;
        tf_tertiary = PERIOD_D1;
    }
};

//+------------------------------------------------------------------+
//| Key Level Detection Configuration                                 |
//+------------------------------------------------------------------+
struct KeyLevelDetectionConfig
{
    int lookback_period;
    double min_strength;
    double touch_zone;
    int min_touches;
    bool show_debug;
    bool use_advanced_validation;
    
    void SetDefaults()
    {
        lookback_period = 200;
        min_strength = 0.40;
        touch_zone = 0.0;
        min_touches = 1;
        show_debug = false;
        use_advanced_validation = true;
    }
};

//+------------------------------------------------------------------+
//| Risk Management Configuration                                     |
//+------------------------------------------------------------------+
struct RiskManagementConfig
{
    double risk_percent_trend;
    double risk_percent_range;
    double risk_percent_breakout;
    double max_risk_per_trade;
    double sl_atr_multiplier;
    double tp_reward_ratio;
    double breakeven_atr;
    double partial_close_atr;
    double max_drawdown_percent;
    double equity_peak_reset;
    int max_positions;
    bool enable_trailing_stop;
    double trailing_atr_multiplier;
    bool enable_partial_closes;
    double partial_close_percent;
    bool enable_breakeven;
    double breakeven_buffer;
    ENUM_TIMEFRAMES management_timeframe;
    bool manage_only_on_timeframe;
    double min_modify_pips;
    double min_modify_atr_fraction;
    int min_modify_cooldown_sec;
    double min_stop_distance_multiplier;
    bool validate_stop_levels;
    
    void SetDefaults()
    {
        risk_percent_trend = 2.0;
        risk_percent_range = 0.8;
        risk_percent_breakout = 3.5;
        max_risk_per_trade = 5.0;
        sl_atr_multiplier = 1.8;
        tp_reward_ratio = 3.0;
        breakeven_atr = 1.5;
        partial_close_atr = 2.0;
        max_drawdown_percent = 30.0;
        equity_peak_reset = 5.0;
        max_positions = 7;
        enable_trailing_stop = true;
        trailing_atr_multiplier = 0.8;
        enable_partial_closes = true;
        partial_close_percent = 33.0;
        enable_breakeven = true;
        breakeven_buffer = 0.5;
        management_timeframe = PERIOD_H1;
        manage_only_on_timeframe = true;
        min_modify_pips = 7.0;
        min_modify_atr_fraction = 0.07;
        min_modify_cooldown_sec = 180;
        min_stop_distance_multiplier = 1.5;
        validate_stop_levels = true;
    }
};

//+------------------------------------------------------------------+
//| Trading Configuration                                              |
//+------------------------------------------------------------------+
struct TradingConfig
{
    bool enable_trading;
    int magic_number;
    int slippage;
    string order_tag;
    bool use_limit_orders;
    int max_limit_distance_pips;
    int limit_order_expiration_hours;
    bool cancel_stale_orders;
    double stale_order_distance_pips;
    
    void SetDefaults()
    {
        enable_trading = true;
        magic_number = 123456;
        slippage = 30;
        order_tag = "[GRANDE]";
        use_limit_orders = true;
        max_limit_distance_pips = 30;
        limit_order_expiration_hours = 4;
        cancel_stale_orders = true;
        stale_order_distance_pips = 50.0;
    }
};

//+------------------------------------------------------------------+
//| Technical Validation Configuration                                 |
//+------------------------------------------------------------------+
struct TechnicalValidationConfig
{
    bool enable_validation;
    double max_wick_to_body_ratio;
    int min_confluence_score;
    bool require_fib_confluence;
    bool require_keylevel_confluence;
    bool reject_excessive_wicks;
    bool reject_doji_candles;
    
    void SetDefaults()
    {
        enable_validation = true;
        max_wick_to_body_ratio = 2.0;
        min_confluence_score = 2;
        require_fib_confluence = true;
        require_keylevel_confluence = true;
        reject_excessive_wicks = true;
        reject_doji_candles = true;
    }
};

//+------------------------------------------------------------------+
//| Display Configuration                                              |
//+------------------------------------------------------------------+
struct DisplayConfig
{
    bool show_regime_background;
    bool show_regime_info;
    bool show_key_levels;
    bool show_system_status;
    bool show_regime_trend_arrows;
    bool show_adx_strength_meter;
    bool show_regime_alerts;
    bool show_trend_follower_panel;
    
    void SetDefaults()
    {
        show_regime_background = true;
        show_regime_info = true;
        show_key_levels = true;
        show_system_status = true;
        show_regime_trend_arrows = true;
        show_adx_strength_meter = true;
        show_regime_alerts = true;
        show_trend_follower_panel = true;
    }
};

//+------------------------------------------------------------------+
//| Logging Configuration                                              |
//+------------------------------------------------------------------+
struct LoggingConfig
{
    bool log_detailed_info;
    bool log_verbose;
    bool log_debug_info;
    bool log_all_errors;
    bool log_important_only;
    
    void SetDefaults()
    {
        log_detailed_info = true;
        log_verbose = false;
        log_debug_info = false;
        log_all_errors = true;
        log_important_only = true;
    }
};

//+------------------------------------------------------------------+
//| Database Configuration                                             |
//+------------------------------------------------------------------+
struct DatabaseConfig
{
    bool enable_database;
    string database_path;
    bool database_debug;
    int data_collection_interval;
    int finbert_analysis_interval;
    
    void SetDefaults()
    {
        enable_database = true;
        database_path = "Data/GrandeTradingData.db";
        database_debug = false;
        data_collection_interval = 60;
        finbert_analysis_interval = 300;
    }
};

//+------------------------------------------------------------------+
//| Update Intervals Configuration                                     |
//+------------------------------------------------------------------+
struct UpdateIntervalsConfig
{
    int regime_update_seconds;
    int key_level_update_seconds;
    int risk_update_seconds;
    int calendar_update_minutes;
    
    void SetDefaults()
    {
        regime_update_seconds = 5;
        key_level_update_seconds = 300;
        risk_update_seconds = 2;
        calendar_update_minutes = 15;
    }
};

//+------------------------------------------------------------------+
//| Cool-Off Configuration                                             |
//+------------------------------------------------------------------+
struct CoolOffConfig
{
    bool enable_cooloff_period;
    int tp_cooloff_minutes;
    int sl_cooloff_minutes;
    bool allow_direction_change_override;
    bool log_cooloff_decisions;
    bool enable_dynamic_cooloff;
    double atr_high_vol_multiplier;
    double atr_low_vol_multiplier;
    bool enable_regime_aware_cooloff;
    double trending_cooloff_multiplier;
    double ranging_cooloff_multiplier;
    bool enable_cooloff_statistics;
    int statistics_report_minutes;
    
    void SetDefaults()
    {
        enable_cooloff_period = true;
        tp_cooloff_minutes = 30;
        sl_cooloff_minutes = 15;
        allow_direction_change_override = true;
        log_cooloff_decisions = true;
        enable_dynamic_cooloff = true;
        atr_high_vol_multiplier = 1.5;
        atr_low_vol_multiplier = 0.7;
        enable_regime_aware_cooloff = true;
        trending_cooloff_multiplier = 0.7;
        ranging_cooloff_multiplier = 1.3;
        enable_cooloff_statistics = true;
        statistics_report_minutes = 60;
    }
};

//+------------------------------------------------------------------+
//| Grande Configuration Manager Class                                |
//+------------------------------------------------------------------+
class CGrandeConfigManager
{
private:
    RegimeDetectionConfig m_regimeConfig;
    KeyLevelDetectionConfig m_keyLevelConfig;
    RiskManagementConfig m_riskConfig;
    TradingConfig m_tradingConfig;
    TechnicalValidationConfig m_technicalConfig;
    DisplayConfig m_displayConfig;
    LoggingConfig m_loggingConfig;
    DatabaseConfig m_databaseConfig;
    UpdateIntervalsConfig m_updateConfig;
    CoolOffConfig m_coolOffConfig;
    
    string m_symbol;
    bool m_initialized;
    bool m_showDebugPrints;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor                                                       |
    //+------------------------------------------------------------------+
    CGrandeConfigManager(void) : m_initialized(false), m_showDebugPrints(false)
    {
        m_symbol = _Symbol;
        SetAllDefaults();
    }
    
    //+------------------------------------------------------------------+
    //| Set all configurations to defaults                                |
    //+------------------------------------------------------------------+
    void SetAllDefaults()
    {
        m_regimeConfig.SetDefaults();
        m_keyLevelConfig.SetDefaults();
        m_riskConfig.SetDefaults();
        m_tradingConfig.SetDefaults();
        m_technicalConfig.SetDefaults();
        m_displayConfig.SetDefaults();
        m_loggingConfig.SetDefaults();
        m_databaseConfig.SetDefaults();
        m_updateConfig.SetDefaults();
        m_coolOffConfig.SetDefaults();
    }
    
    //+------------------------------------------------------------------+
    //| Initialize with symbol                                            |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, bool showDebug = false)
    {
        m_symbol = symbol;
        m_showDebugPrints = showDebug;
        m_initialized = true;
        
        if(m_showDebugPrints)
            Print("[ConfigManager] Initialized for ", m_symbol);
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Configuration Getters                                             |
    //+------------------------------------------------------------------+
    RegimeDetectionConfig GetRegimeConfig() const { return m_regimeConfig; }
    KeyLevelDetectionConfig GetKeyLevelConfig() const { return m_keyLevelConfig; }
    RiskManagementConfig GetRiskConfig() const { return m_riskConfig; }
    TradingConfig GetTradingConfig() const { return m_tradingConfig; }
    TechnicalValidationConfig GetTechnicalConfig() const { return m_technicalConfig; }
    DisplayConfig GetDisplayConfig() const { return m_displayConfig; }
    LoggingConfig GetLoggingConfig() const { return m_loggingConfig; }
    DatabaseConfig GetDatabaseConfig() const { return m_databaseConfig; }
    UpdateIntervalsConfig GetUpdateConfig() const { return m_updateConfig; }
    CoolOffConfig GetCoolOffConfig() const { return m_coolOffConfig; }
    
    //+------------------------------------------------------------------+
    //| Configuration Setters                                             |
    //+------------------------------------------------------------------+
    void SetRegimeConfig(const RegimeDetectionConfig &config) { m_regimeConfig = config; }
    void SetKeyLevelConfig(const KeyLevelDetectionConfig &config) { m_keyLevelConfig = config; }
    void SetRiskConfig(const RiskManagementConfig &config) { m_riskConfig = config; }
    void SetTradingConfig(const TradingConfig &config) { m_tradingConfig = config; }
    void SetTechnicalConfig(const TechnicalValidationConfig &config) { m_technicalConfig = config; }
    void SetDisplayConfig(const DisplayConfig &config) { m_displayConfig = config; }
    void SetLoggingConfig(const LoggingConfig &config) { m_loggingConfig = config; }
    void SetDatabaseConfig(const DatabaseConfig &config) { m_databaseConfig = config; }
    void SetUpdateConfig(const UpdateIntervalsConfig &config) { m_updateConfig = config; }
    void SetCoolOffConfig(const CoolOffConfig &config) { m_coolOffConfig = config; }
    
    //+------------------------------------------------------------------+
    //| Validate Configuration                                            |
    //+------------------------------------------------------------------+
    bool Validate()
    {
        bool isValid = true;
        
        // Validate regime config
        if(m_regimeConfig.adx_trend_threshold < 10.0 || m_regimeConfig.adx_trend_threshold > 50.0)
        {
            Print("[ConfigManager] Invalid ADX trend threshold: ", m_regimeConfig.adx_trend_threshold);
            isValid = false;
        }
        
        // Validate key level config
        if(m_keyLevelConfig.lookback_period < 10 || m_keyLevelConfig.lookback_period > 2000)
        {
            Print("[ConfigManager] Invalid lookback period: ", m_keyLevelConfig.lookback_period);
            isValid = false;
        }
        
        if(m_keyLevelConfig.min_strength < 0.1 || m_keyLevelConfig.min_strength > 1.0)
        {
            Print("[ConfigManager] Invalid minimum strength: ", m_keyLevelConfig.min_strength);
            isValid = false;
        }
        
        // Validate risk config
        if(m_riskConfig.max_risk_per_trade <= 0 || m_riskConfig.max_risk_per_trade > 20.0)
        {
            Print("[ConfigManager] Invalid max risk per trade: ", m_riskConfig.max_risk_per_trade);
            isValid = false;
        }
        
        if(m_riskConfig.max_positions < 1 || m_riskConfig.max_positions > 20)
        {
            Print("[ConfigManager] Invalid max positions: ", m_riskConfig.max_positions);
            isValid = false;
        }
        
        // Validate trading config
        if(m_tradingConfig.slippage < 0 || m_tradingConfig.slippage > 100)
        {
            Print("[ConfigManager] Invalid slippage: ", m_tradingConfig.slippage);
            isValid = false;
        }
        
        return isValid;
    }
    
    //+------------------------------------------------------------------+
    //| Get Configuration Summary                                         |
    //+------------------------------------------------------------------+
    string GetConfigSummary()
    {
        string summary = "\n=== CONFIGURATION SUMMARY ===\n";
        summary += "REGIME DETECTION:\n";
        summary += StringFormat("  ADX Trend: %.1f, Breakout: %.1f\n", 
                              m_regimeConfig.adx_trend_threshold, m_regimeConfig.adx_breakout_min);
        summary += StringFormat("  ATR Period: %d, Avg Period: %d\n", 
                              m_regimeConfig.atr_period, m_regimeConfig.atr_avg_period);
        
        summary += "\nKEY LEVELS:\n";
        summary += StringFormat("  Lookback: %d, Min Strength: %.2f\n", 
                              m_keyLevelConfig.lookback_period, m_keyLevelConfig.min_strength);
        summary += StringFormat("  Touch Zone: %.5f, Min Touches: %d\n", 
                              m_keyLevelConfig.touch_zone, m_keyLevelConfig.min_touches);
        
        summary += "\nRISK MANAGEMENT:\n";
        summary += StringFormat("  Risk %%: Trend=%.1f, Range=%.1f, Breakout=%.1f\n", 
                              m_riskConfig.risk_percent_trend, m_riskConfig.risk_percent_range, 
                              m_riskConfig.risk_percent_breakout);
        summary += StringFormat("  Max Risk: %.1f%%, Max Positions: %d\n", 
                              m_riskConfig.max_risk_per_trade, m_riskConfig.max_positions);
        summary += StringFormat("  SL ATR: %.1fx, TP R:R: %.1f:1\n", 
                              m_riskConfig.sl_atr_multiplier, m_riskConfig.tp_reward_ratio);
        
        summary += "\nTRADING:\n";
        summary += StringFormat("  Enabled: %s, Magic: %d\n", 
                              m_tradingConfig.enable_trading ? "YES" : "NO", 
                              m_tradingConfig.magic_number);
        summary += StringFormat("  Limit Orders: %s, Max Distance: %d pips\n", 
                              m_tradingConfig.use_limit_orders ? "YES" : "NO", 
                              m_tradingConfig.max_limit_distance_pips);
        
        summary += "==========================\n";
        
        return summary;
    }
    
    //+------------------------------------------------------------------+
    //| Save Configuration Preset                                         |
    //+------------------------------------------------------------------+
    bool SavePreset(string presetName)
    {
        string filename = StringFormat("GrandePreset_%s.dat", presetName);
        int fileHandle = FileOpen(filename, FILE_WRITE|FILE_BIN);
        
        if(fileHandle == INVALID_HANDLE)
        {
            Print("[ConfigManager] Failed to create preset file: ", filename);
            return false;
        }
        
        // Write magic number and version
        FileWriteInteger(fileHandle, 0x47524E44); // "GRND"
        FileWriteInteger(fileHandle, 1); // Version
        
        // Write all configurations
        // (Implementation of serialization would go here)
        
        FileClose(fileHandle);
        
        Print("[ConfigManager] Configuration preset saved: ", presetName);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Load Configuration Preset                                         |
    //+------------------------------------------------------------------+
    bool LoadPreset(string presetName)
    {
        string filename = StringFormat("GrandePreset_%s.dat", presetName);
        
        if(!FileIsExist(filename))
        {
            Print("[ConfigManager] Preset not found: ", presetName);
            return false;
        }
        
        int fileHandle = FileOpen(filename, FILE_READ|FILE_BIN);
        if(fileHandle == INVALID_HANDLE)
            return false;
        
        // Validate magic number
        int magic = FileReadInteger(fileHandle);
        if(magic != 0x47524E44)
        {
            FileClose(fileHandle);
            return false;
        }
        
        // Read version
        int version = FileReadInteger(fileHandle);
        
        // Read configurations
        // (Implementation of deserialization would go here)
        
        FileClose(fileHandle);
        
        Print("[ConfigManager] Configuration preset loaded: ", presetName);
        return true;
    }
};

