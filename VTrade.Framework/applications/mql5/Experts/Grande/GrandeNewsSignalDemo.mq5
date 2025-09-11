//+------------------------------------------------------------------+
//| GrandeNewsSignalDemo.mq5                                         |
//| Copyright 2024, Grande Tech                                      |
//| Demonstration of News-to-Signal Pipeline                         |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor event handlers and indicator patterns

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Demonstration of complete news-to-signal pipeline"

#include "GrandeNewsSignalGenerator.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== News Signal Configuration ==="
input string InpSymbol = "EURUSD";                    // Trading Symbol
input bool InpEnableMarketAux = false;                // Enable MarketAux API
input string InpMarketAuxKey = "";                    // MarketAux API Key
input bool InpEnableAlphaVantage = false;             // Enable Alpha Vantage API
input string InpAlphaVantageKey = "";                 // Alpha Vantage API Key
input bool InpEnableNewsAPI = false;                  // Enable NewsAPI
input string InpNewsAPIKey = "";                      // NewsAPI Key
input bool InpUseTechnicalConfirmation = true;        // Use Technical Confirmation
input bool InpUseRiskManagement = true;               // Use Risk Management

input group "=== Signal Generation Settings ==="
input double InpMinSignalStrength = 0.6;              // Minimum Signal Strength
input double InpMinSignalConfidence = 0.5;            // Minimum Signal Confidence
input int InpSignalValidityHours = 4;                 // Signal Validity (hours)
input double InpRiskPerTrade = 2.0;                   // Risk Per Trade (%)
input double InpMaxPositionSize = 0.1;                // Max Position Size

input group "=== Demo Settings ==="
input int InpUpdateIntervalMinutes = 5;               // Update Interval (minutes)
input bool InpShowDetailedLogs = true;                // Show Detailed Logs
input bool InpAutoGenerateSignals = true;             // Auto Generate Signals

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CGrandeNewsSignalGenerator g_news_signal_generator;
NewsSignalConfig g_config;
datetime g_last_update;
int g_demo_signals_generated;
int g_demo_signals_successful;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Grande News Signal Demo Starting ===");
    
    // Configure news signal system
    if(!ConfigureNewsSignalSystem())
    {
        Print("ERROR: Failed to configure news signal system");
        return INIT_FAILED;
    }
    
    // Initialize the news signal generator
    if(!g_news_signal_generator.Initialize(InpSymbol, g_config))
    {
        Print("ERROR: Failed to initialize news signal generator");
        return INIT_FAILED;
    }
    
    // Initialize demo variables
    g_last_update = 0;
    g_demo_signals_generated = 0;
    g_demo_signals_successful = 0;
    
    Print("=== Grande News Signal Demo Initialized Successfully ===");
    Print("Symbol: ", InpSymbol);
    Print("Update Interval: ", InpUpdateIntervalMinutes, " minutes");
    Print("Auto Generate: ", InpAutoGenerateSignals ? "Enabled" : "Disabled");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Grande News Signal Demo Stopping ===");
    Print("Total Signals Generated: ", g_demo_signals_generated);
    Print("Successful Signals: ", g_demo_signals_successful);
    if(g_demo_signals_generated > 0)
    {
        Print("Success Rate: ", (double)g_demo_signals_successful / g_demo_signals_generated * 100.0, "%");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if it's time to update
    if(!IsTimeToUpdate())
        return;
    
    // Generate trading signal
    if(InpAutoGenerateSignals)
    {
        GenerateAndDisplaySignal();
    }
    
    // Update last update time
    g_last_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Alternative update method using timer
    if(InpAutoGenerateSignals)
    {
        GenerateAndDisplaySignal();
    }
}

//+------------------------------------------------------------------+
//| Chart event function                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Handle chart events if needed
    if(id == CHARTEVENT_KEYDOWN)
    {
        // Manual signal generation on key press
        if(sparam == "G" || sparam == "g") // Press 'G' to generate signal
        {
            GenerateAndDisplaySignal();
        }
        else if(sparam == "S" || sparam == "s") // Press 'S' to show status
        {
            ShowSystemStatus();
        }
    }
}

//+------------------------------------------------------------------+
//| Configure News Signal System                                      |
//+------------------------------------------------------------------+
bool ConfigureNewsSignalSystem()
{
    // Configure news fetching
    g_config.fetch_config.marketaux.enabled = InpEnableMarketAux;
    g_config.fetch_config.marketaux.api_key = InpMarketAuxKey;
    g_config.fetch_config.marketaux.symbols[0] = InpSymbol;
    
    g_config.fetch_config.alpha_vantage.enabled = InpEnableAlphaVantage;
    g_config.fetch_config.alpha_vantage.api_key = InpAlphaVantageKey;
    g_config.fetch_config.alpha_vantage.symbols[0] = InpSymbol;
    
    g_config.fetch_config.newsapi.enabled = InpEnableNewsAPI;
    g_config.fetch_config.newsapi.api_key = InpNewsAPIKey;
    g_config.fetch_config.newsapi.symbols[0] = InpSymbol;
    
    // Configure signal generation
    g_config.min_signal_strength = InpMinSignalStrength;
    g_config.min_signal_confidence = InpMinSignalConfidence;
    g_config.signal_validity_hours = InpSignalValidityHours;
    g_config.use_technical_confirmation = InpUseTechnicalConfirmation;
    g_config.use_risk_management = InpUseRiskManagement;
    g_config.risk_per_trade = InpRiskPerTrade;
    g_config.max_position_size = InpMaxPositionSize;
    
    // Configure sentiment analysis
    g_config.sentiment_config.strong_positive_threshold = 0.6;
    g_config.sentiment_config.positive_threshold = 0.2;
    g_config.sentiment_config.negative_threshold = -0.2;
    g_config.sentiment_config.strong_negative_threshold = -0.6;
    g_config.sentiment_config.min_confidence = 0.3;
    g_config.sentiment_config.high_confidence = 0.7;
    g_config.sentiment_config.min_articles_for_signal = 3;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if it's time to update                                      |
//+------------------------------------------------------------------+
bool IsTimeToUpdate()
{
    if(g_last_update == 0)
        return true;
    
    int minutes_since_update = (int)((TimeCurrent() - g_last_update) / 60);
    return minutes_since_update >= InpUpdateIntervalMinutes;
}

//+------------------------------------------------------------------+
//| Generate and Display Signal                                       |
//+------------------------------------------------------------------+
void GenerateAndDisplaySignal()
{
    Print("=== Generating News-Based Trading Signal ===");
    
    // Generate signal
    TradingSignal signal = g_news_signal_generator.GenerateTradingSignal();
    
    // Display signal
    if(signal.is_valid)
    {
        g_demo_signals_generated++;
        
        Print("=== NEW TRADING SIGNAL GENERATED ===");
        Print(FormatSignalForDisplay(signal));
        
        // Simulate signal success (in real trading, this would be based on actual results)
        bool signal_success = SimulateSignalSuccess(signal);
        g_news_signal_generator.UpdateSignalSuccess(signal_success);
        
        if(signal_success)
        {
            g_demo_signals_successful++;
            Print("Signal marked as SUCCESSFUL");
        }
        else
        {
            Print("Signal marked as UNSUCCESSFUL");
        }
        
        // Show system statistics
        if(InpShowDetailedLogs)
        {
            ShowSystemStatus();
        }
    }
    else
    {
        Print("No valid signal generated: ", signal.reasoning);
    }
    
    Print("=== Signal Generation Complete ===");
}

//+------------------------------------------------------------------+
//| Simulate Signal Success (for demo purposes)                      |
//+------------------------------------------------------------------+
bool SimulateSignalSuccess(const TradingSignal &signal)
{
    // Simple simulation based on signal strength and confidence
    double success_probability = (signal.strength + signal.confidence) / 2.0;
    
    // Add some randomness
    double random_factor = (MathRand() / 32767.0);
    
    return random_factor < success_probability;
}

//+------------------------------------------------------------------+
//| Show System Status                                                |
//+------------------------------------------------------------------+
void ShowSystemStatus()
{
    Print("=== GRANDE NEWS SIGNAL SYSTEM STATUS ===");
    Print("Symbol: ", InpSymbol);
    Print("Last Update: ", TimeToString(g_last_update, TIME_DATE|TIME_SECONDS));
    Print("Signals Generated: ", g_news_signal_generator.GetSignalCount());
    Print("Successful Signals: ", g_news_signal_generator.GetSuccessfulSignals());
    Print("Success Rate: ", DoubleToString(g_news_signal_generator.GetSuccessRate(), 2), "%");
    Print("Last Signal Valid: ", g_news_signal_generator.IsSignalValid() ? "Yes" : "No");
    
    if(g_news_signal_generator.GetSignalCount() > 0)
    {
        TradingSignal last_signal = g_news_signal_generator.GetLastSignal();
        Print("Last Signal Summary: ", g_news_signal_generator.GetSignalSummary());
    }
    
    Print("=== END STATUS ===");
}

//+------------------------------------------------------------------+
//| Manual Signal Generation (for testing)                           |
//+------------------------------------------------------------------+
void GenerateManualSignal()
{
    Print("=== MANUAL SIGNAL GENERATION ===");
    
    // Create a mock news text for testing
    string mock_news = "EUR/USD shows strong bullish momentum as European Central Bank signals potential rate hikes. " +
                      "Economic indicators point to continued recovery in the Eurozone. " +
                      "Traders are optimistic about the currency pair's prospects. " +
                      "Technical analysis confirms the upward trend with strong support levels.";
    
    // Generate signal based on mock news
    TradingSignal signal = g_news_signal_generator.GenerateTradingSignal();
    
    if(signal.is_valid)
    {
        Print("Manual signal generated successfully:");
        Print(FormatSignalForDisplay(signal));
    }
    else
    {
        Print("Manual signal generation failed: ", signal.reasoning);
    }
}

//+------------------------------------------------------------------+
//| Test News Sources                                                 |
//+------------------------------------------------------------------+
void TestNewsSources()
{
    Print("=== TESTING NEWS SOURCES ===");
    
    // Test each configured news source
    if(InpEnableMarketAux && InpMarketAuxKey != "")
    {
        Print("MarketAux: Configured with API key");
    }
    else
    {
        Print("MarketAux: Not configured or no API key");
    }
    
    if(InpEnableAlphaVantage && InpAlphaVantageKey != "")
    {
        Print("Alpha Vantage: Configured with API key");
    }
    else
    {
        Print("Alpha Vantage: Not configured or no API key");
    }
    
    if(InpEnableNewsAPI && InpNewsAPIKey != "")
    {
        Print("NewsAPI: Configured with API key");
    }
    else
    {
        Print("NewsAPI: Not configured or no API key");
    }
    
    Print("=== NEWS SOURCE TEST COMPLETE ===");
}

//+------------------------------------------------------------------+
//| Expert Advisor Functions (if needed)                             |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Handle trade events if needed
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    // Handle trade transactions if needed
}
