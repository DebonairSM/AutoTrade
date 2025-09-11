//+------------------------------------------------------------------+
//| GrandeNewsSignalGenerator.mqh                                    |
//| Copyright 2024, Grande Tech                                      |
//| Complete News-to-Signal Pipeline for Trading System              |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor event handlers and indicator patterns

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Complete news-to-signal pipeline for trading decisions"

#include "GrandeNewsFetcher.mqh"
#include "GrandeNewsSentimentAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Trading Signal Structure                                          |
//+------------------------------------------------------------------+
struct TradingSignal
{
    NEWS_SENTIMENT_SIGNAL sentiment_signal;  // Sentiment-based signal
    double                 strength;          // Signal strength (0-1)
    double                 confidence;        // Signal confidence (0-1)
    string                 reasoning;         // Signal reasoning
    datetime               timestamp;         // Signal generation time
    string                 symbol;            // Trading symbol
    double                 entry_price;       // Suggested entry price
    double                 stop_loss;         // Suggested stop loss
    double                 take_profit;       // Suggested take profit
    int                    priority;          // Signal priority (1-5)
    bool                   is_valid;          // Whether signal is valid
};

//+------------------------------------------------------------------+
//| News Signal Configuration                                         |
//+------------------------------------------------------------------+
struct NewsSignalConfig
{
    // News fetching settings
    NewsFetchConfig         fetch_config;
    
    // Sentiment analysis settings
    SentimentConfig         sentiment_config;
    
    // Signal generation settings
    double                  min_signal_strength;      // Minimum signal strength
    double                  min_signal_confidence;    // Minimum signal confidence
    int                     signal_validity_hours;    // How long signal is valid
    bool                    use_technical_confirmation; // Use technical analysis
    bool                    use_risk_management;      // Apply risk management
    
    // Risk management settings
    double                  risk_per_trade;           // Risk per trade (%)
    double                  max_position_size;        // Maximum position size
    double                  atr_multiplier_sl;        // ATR multiplier for SL
    double                  atr_multiplier_tp;        // ATR multiplier for TP
    
    // Constructor with defaults
    NewsSignalConfig()
    {
        min_signal_strength = 0.6;
        min_signal_confidence = 0.5;
        signal_validity_hours = 4;
        use_technical_confirmation = true;
        use_risk_management = true;
        risk_per_trade = 2.0;
        max_position_size = 0.1;
        atr_multiplier_sl = 2.0;
        atr_multiplier_tp = 3.0;
    }
};

//+------------------------------------------------------------------+
//| Grande News Signal Generator Class                               |
//+------------------------------------------------------------------+
class CGrandeNewsSignalGenerator
{
private:
    // Configuration
    NewsSignalConfig        m_config;
    string                  m_symbol;
    bool                    m_initialized;
    
    // Component modules
    CGrandeNewsFetcher      m_news_fetcher;
    CGrandeNewsSentimentAnalyzer m_sentiment_analyzer;
    
    // State tracking
    TradingSignal           m_last_signal;
    datetime                m_last_news_fetch;
    int                     m_signal_count;
    int                     m_successful_signals;
    
    // Technical analysis integration
    int                     m_atr_handle;
    double                  m_current_atr;
    
public:
    //+------------------------------------------------------------------+
    //| Constructor and Destructor                                       |
    //+------------------------------------------------------------------+
    CGrandeNewsSignalGenerator(void) : m_initialized(false),
                                       m_last_news_fetch(0),
                                       m_signal_count(0),
                                       m_successful_signals(0),
                                       m_atr_handle(INVALID_HANDLE),
                                       m_current_atr(0.0)
    {
        // Initialize last signal
        m_last_signal.sentiment_signal = NEWS_SIGNAL_NO_SIGNAL;
        m_last_signal.strength = 0.0;
        m_last_signal.confidence = 0.0;
        m_last_signal.reasoning = "";
        m_last_signal.timestamp = 0;
        m_last_signal.symbol = "";
        m_last_signal.entry_price = 0.0;
        m_last_signal.stop_loss = 0.0;
        m_last_signal.take_profit = 0.0;
        m_last_signal.priority = 0;
        m_last_signal.is_valid = false;
    }
    
    ~CGrandeNewsSignalGenerator(void)
    {
        if(m_atr_handle != INVALID_HANDLE)
            IndicatorRelease(m_atr_handle);
    }
    
    //+------------------------------------------------------------------+
    //| Initialization Method                                            |
    //+------------------------------------------------------------------+
    bool Initialize(string symbol, const NewsSignalConfig &config)
    {
        m_symbol = symbol;
        m_config = config;
        
        // Initialize news fetcher
        if(!m_news_fetcher.Initialize(symbol, m_config.fetch_config))
        {
            Print("[GrandeNewsSignal] ERROR: Failed to initialize news fetcher");
            return false;
        }
        
        // Initialize sentiment analyzer
        if(!m_sentiment_analyzer.Initialize(symbol, m_config.sentiment_config))
        {
            Print("[GrandeNewsSignal] ERROR: Failed to initialize sentiment analyzer");
            return false;
        }
        
        // Initialize technical analysis
        if(m_config.use_technical_confirmation)
        {
            m_atr_handle = iATR(symbol, PERIOD_CURRENT, 14);
            if(m_atr_handle == INVALID_HANDLE)
            {
                Print("[GrandeNewsSignal] WARNING: Failed to create ATR indicator");
            }
        }
        
        m_initialized = true;
        Print("[GrandeNewsSignal] News Signal Generator initialized for ", m_symbol);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Main Signal Generation Method                                    |
    //+------------------------------------------------------------------+
    TradingSignal GenerateTradingSignal()
    {
        TradingSignal signal;
        InitializeSignal(signal);
        
        if(!m_initialized)
        {
            signal.reasoning = "Generator not initialized";
            return signal;
        }
        
        // Step 1: Fetch latest news
        if(!FetchAndAnalyzeNews())
        {
            signal.reasoning = "Failed to fetch or analyze news";
            return signal;
        }
        
        // Step 2: Generate sentiment-based signal
        SentimentAnalysisResult sentiment_result = m_sentiment_analyzer.AnalyzeNewsSentiment("");
        if(sentiment_result.signal == NEWS_SIGNAL_NO_SIGNAL)
        {
            signal.reasoning = "No clear sentiment signal";
            return signal;
        }
        
        // Step 3: Apply technical confirmation if enabled
        if(m_config.use_technical_confirmation)
        {
            if(!ApplyTechnicalConfirmation(sentiment_result, signal))
            {
                signal.reasoning = "Technical analysis contradicts sentiment signal";
                return signal;
            }
        }
        
        // Step 4: Generate final trading signal
        signal = CreateTradingSignal(sentiment_result);
        
        // Step 5: Apply risk management if enabled
        if(m_config.use_risk_management)
        {
            ApplyRiskManagement(signal);
        }
        
        // Step 6: Validate signal
        if(ValidateSignal(signal))
        {
            m_last_signal = signal;
            m_signal_count++;
            Print("[GrandeNewsSignal] Generated signal: ", m_sentiment_analyzer.SignalToString(signal.sentiment_signal));
        }
        
        return signal;
    }
    
    //+------------------------------------------------------------------+
    //| Public Access Methods                                            |
    //+------------------------------------------------------------------+
    TradingSignal GetLastSignal() const { return m_last_signal; }
    int GetSignalCount() const { return m_signal_count; }
    int GetSuccessfulSignals() const { return m_successful_signals; }
    double GetSuccessRate() const 
    { 
        return m_signal_count > 0 ? (double)m_successful_signals / m_signal_count * 100.0 : 0.0; 
    }
    
    bool IsSignalValid()
    {
        if(!m_last_signal.is_valid)
            return false;
        
        datetime signal_age = TimeCurrent() - m_last_signal.timestamp;
        return signal_age < (m_config.signal_validity_hours * 3600);
    }
    
    void UpdateSignalSuccess(bool was_successful)
    {
        if(was_successful)
            m_successful_signals++;
    }
    
    string GetSignalSummary()
    {
        if(!m_last_signal.is_valid)
            return "No valid signal";
        
        return StringFormat("Signal: %s | Strength: %.2f | Confidence: %.2f | Priority: %d | Age: %d min",
                          m_sentiment_analyzer.SignalToString(m_last_signal.sentiment_signal),
                          m_last_signal.strength,
                          m_last_signal.confidence,
                          m_last_signal.priority,
                          (int)((TimeCurrent() - m_last_signal.timestamp) / 60));
    }
    
private:
    //+------------------------------------------------------------------+
    //| Private Helper Methods                                           |
    //+------------------------------------------------------------------+
    void InitializeSignal(TradingSignal &signal)
    {
        signal.sentiment_signal = NEWS_SIGNAL_NO_SIGNAL;
        signal.strength = 0.0;
        signal.confidence = 0.0;
        signal.reasoning = "";
        signal.timestamp = TimeCurrent();
        signal.symbol = m_symbol;
        signal.entry_price = 0.0;
        signal.stop_loss = 0.0;
        signal.take_profit = 0.0;
        signal.priority = 0;
        signal.is_valid = false;
    }
    
    bool FetchAndAnalyzeNews()
    {
        // Check if it's time to fetch news
        if(!m_news_fetcher.IsTimeToFetch())
            return true; // Use existing data
        
        // Fetch latest news
        NewsFetchResult fetch_result = m_news_fetcher.FetchLatestNews();
        if(!fetch_result.success)
        {
            Print("[GrandeNewsSignal] WARNING: Failed to fetch news: ", fetch_result.error_message);
            return false;
        }
        
        m_last_news_fetch = TimeCurrent();
        Print("[GrandeNewsSignal] Fetched ", fetch_result.article_count, " articles from ", fetch_result.source);
        
        // Analyze the fetched news
        SentimentAnalysisResult analysis_result = m_sentiment_analyzer.AnalyzeNewsSentiment(fetch_result.raw_data);
        
        return analysis_result.signal != NEWS_SIGNAL_NO_SIGNAL;
    }
    
    bool ApplyTechnicalConfirmation(const SentimentAnalysisResult &sentiment_result, TradingSignal &signal)
    {
        // Get current ATR for volatility assessment
        if(m_atr_handle != INVALID_HANDLE)
        {
            double atr_buffer[];
            ArraySetAsSeries(atr_buffer, true);
            if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) > 0)
            {
                m_current_atr = atr_buffer[0];
            }
        }
        
        // Get current price
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(current_price == 0.0)
        {
            Print("[GrandeNewsSignal] WARNING: Unable to get current price");
            return true; // Don't block signal due to price issues
        }
        
        // Simple technical confirmation logic
        // In a real implementation, this would be more sophisticated
        
        // Check if market is too volatile (ATR-based)
        if(m_current_atr > 0 && m_current_atr > current_price * 0.02) // 2% ATR threshold
        {
            Print("[GrandeNewsSignal] Market too volatile for signal confirmation");
            return false;
        }
        
        // Check if we're in a trending market (simplified)
        // This would typically use ADX or other trend indicators
        
        return true;
    }
    
    TradingSignal CreateTradingSignal(const SentimentAnalysisResult &sentiment_result)
    {
        TradingSignal signal;
        InitializeSignal(signal);
        
        signal.sentiment_signal = sentiment_result.signal;
        signal.strength = MathAbs(sentiment_result.score);
        signal.confidence = sentiment_result.confidence;
        signal.reasoning = sentiment_result.summary;
        signal.entry_price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        
        // Calculate priority based on strength and confidence
        signal.priority = CalculateSignalPriority(signal.strength, signal.confidence);
        
        // Set signal validity
        signal.is_valid = (signal.strength >= m_config.min_signal_strength && 
                          signal.confidence >= m_config.min_signal_confidence);
        
        return signal;
    }
    
    int CalculateSignalPriority(double strength, double confidence)
    {
        // Priority scale: 1 (lowest) to 5 (highest)
        double combined_score = (strength * 0.6) + (confidence * 0.4);
        
        if(combined_score >= 0.9) return 5;
        if(combined_score >= 0.8) return 4;
        if(combined_score >= 0.7) return 3;
        if(combined_score >= 0.6) return 2;
        return 1;
    }
    
    void ApplyRiskManagement(TradingSignal &signal)
    {
        if(signal.entry_price == 0.0)
            return;
        
        // Calculate position size based on risk per trade
        double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double risk_amount = account_balance * (m_config.risk_per_trade / 100.0);
        
        // Calculate stop loss and take profit based on ATR
        if(m_current_atr > 0)
        {
            double atr_sl = m_current_atr * m_config.atr_multiplier_sl;
            double atr_tp = m_current_atr * m_config.atr_multiplier_tp;
            
            if(signal.sentiment_signal == NEWS_SIGNAL_BUY || signal.sentiment_signal == NEWS_SIGNAL_STRONG_BUY)
            {
                signal.stop_loss = signal.entry_price - atr_sl;
                signal.take_profit = signal.entry_price + atr_tp;
            }
            else if(signal.sentiment_signal == NEWS_SIGNAL_SELL || signal.sentiment_signal == NEWS_SIGNAL_STRONG_SELL)
            {
                signal.stop_loss = signal.entry_price + atr_sl;
                signal.take_profit = signal.entry_price - atr_tp;
            }
        }
        else
        {
            // Fallback to percentage-based levels
            double percentage_sl = 0.01; // 1%
            double percentage_tp = 0.02; // 2%
            
            if(signal.sentiment_signal == NEWS_SIGNAL_BUY || signal.sentiment_signal == NEWS_SIGNAL_STRONG_BUY)
            {
                signal.stop_loss = signal.entry_price * (1.0 - percentage_sl);
                signal.take_profit = signal.entry_price * (1.0 + percentage_tp);
            }
            else if(signal.sentiment_signal == NEWS_SIGNAL_SELL || signal.sentiment_signal == NEWS_SIGNAL_STRONG_SELL)
            {
                signal.stop_loss = signal.entry_price * (1.0 + percentage_sl);
                signal.take_profit = signal.entry_price * (1.0 - percentage_tp);
            }
        }
        
        // Apply maximum position size limit
        double max_position_value = account_balance * m_config.max_position_size;
        // Position sizing would be calculated here based on stop loss distance
        
        signal.reasoning += StringFormat(" | Risk: %.1f%% | SL: %.5f | TP: %.5f", 
                                       m_config.risk_per_trade, signal.stop_loss, signal.take_profit);
    }
    
    bool ValidateSignal(TradingSignal &signal)
    {
        // Check minimum requirements
        if(signal.strength < m_config.min_signal_strength)
        {
            signal.reasoning += " | Strength too low";
            return false;
        }
        
        if(signal.confidence < m_config.min_signal_confidence)
        {
            signal.reasoning += " | Confidence too low";
            return false;
        }
        
        // Check if signal is too old
        if(IsSignalValid() && (TimeCurrent() - m_last_signal.timestamp) < 300) // 5 minutes
        {
            signal.reasoning += " | Signal too recent";
            return false;
        }
        
        // Check market hours (optional)
        if(!IsMarketOpen())
        {
            signal.reasoning += " | Market closed";
            return false;
        }
        
        return true;
    }
    
    bool IsMarketOpen()
    {
        // Simple market hours check
        // In a real implementation, this would check actual market hours
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        
        // Basic check: avoid weekends
        if(dt.day_of_week == 0 || dt.day_of_week == 6)
            return false;
        
        // Basic check: avoid very early/late hours (simplified)
        if(dt.hour < 6 || dt.hour > 22)
            return false;
        
        return true;
    }
};

//+------------------------------------------------------------------+
//| Utility Functions                                                 |
//+------------------------------------------------------------------+
string FormatSignalForDisplay(const TradingSignal &signal)
{
    if(!signal.is_valid)
        return "No valid signal";
    
    string result = StringFormat("=== TRADING SIGNAL ===\n");
    result += StringFormat("Symbol: %s\n", signal.symbol);
    result += StringFormat("Signal: %s\n", GetSignalTypeString(signal.sentiment_signal));
    result += StringFormat("Strength: %.2f\n", signal.strength);
    result += StringFormat("Confidence: %.2f\n", signal.confidence);
    result += StringFormat("Priority: %d/5\n", signal.priority);
    result += StringFormat("Entry: %.5f\n", signal.entry_price);
    result += StringFormat("Stop Loss: %.5f\n", signal.stop_loss);
    result += StringFormat("Take Profit: %.5f\n", signal.take_profit);
    result += StringFormat("Reasoning: %s\n", signal.reasoning);
    result += StringFormat("Generated: %s\n", TimeToString(signal.timestamp, TIME_DATE|TIME_SECONDS));
    result += "=====================";
    
    return result;
}

string GetSignalTypeString(NEWS_SENTIMENT_SIGNAL signal)
{
    switch(signal)
    {
        case NEWS_SIGNAL_STRONG_BUY:  return "STRONG BUY";
        case NEWS_SIGNAL_BUY:         return "BUY";
        case NEWS_SIGNAL_NEUTRAL:     return "NEUTRAL";
        case NEWS_SIGNAL_SELL:        return "SELL";
        case NEWS_SIGNAL_STRONG_SELL: return "STRONG SELL";
        case NEWS_SIGNAL_NO_SIGNAL:   return "NO SIGNAL";
        default:                      return "UNKNOWN";
    }
}
