//+------------------------------------------------------------------+
//| GrandeIntelligentReporter.mqh                                    |
//| Intelligent Hourly Reporting System for Grande Trading           |
//| Tracks all trading decisions and provides detailed analysis      |
//+------------------------------------------------------------------+
//
// PURPOSE:
//   Track and report all trading decisions with comprehensive analysis.
//   Provides hourly reports and FinBERT-compatible dataset generation.
//
// RESPONSIBILITIES:
//   - Record all trading decisions (executed, rejected, blocked)
//   - Generate hourly intelligence reports
//   - Export data in FinBERT-compatible format
//   - Analyze rejection patterns
//   - Track signal success rates
//   - Provide decision statistics
//
// DEPENDENCIES:
//   - Files\FileTxt.mqh (for file operations)
//
// STATE MANAGED:
//   - Array of trade decisions
//   - Decision statistics (accepted, rejected, blocked counts)
//   - Last report generation time
//   - Reporting interval configuration
//
// PUBLIC INTERFACE:
//   bool Initialize(symbol, intervalMinutes)
//   void RecordDecision(STradeDecision decision) - Record decision
//   void GenerateHourlyReport() - Generate report
//   void GenerateFinBERTDataset() - Export for FinBERT analysis
//   bool IsReportDue() - Check if report should be generated
//   string GetDecisionStatistics() - Get statistics
//
// DATA STRUCTURES:
//   STradeDecision - Comprehensive decision tracking structure
//
// IMPLEMENTATION NOTES:
//   - Maintains in-memory decision history
//   - Generates timestamped report files
//   - Exports CSV format for FinBERT integration
//   - Provides detailed rejection reason analysis
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestIntelligentReporter.mqh
//+------------------------------------------------------------------+

#property copyright "Grande Tech"
#property version   "1.00"
#property description "Intelligent reporting system for tracking trading decisions"

#include <Files\FileTxt.mqh>

//+------------------------------------------------------------------+
//| Decision tracking structure                                      |
//+------------------------------------------------------------------+
struct STradeDecision
{
    datetime        timestamp;
    string          signal_type;      // TREND_BULL, TREND_BEAR, BREAKOUT, RANGE, TRIANGLE
    string          decision;         // REJECTED, BLOCKED, EXECUTED, SKIPPED
    string          rejection_reason; // Detailed reason for rejection
    double          price;
    double          atr;
    double          adx_h1;
    double          adx_h4;
    double          adx_d1;
    string          regime;
    double          regime_confidence;
    int             key_levels_count;
    double          nearest_resistance;
    double          nearest_support;
    double          rsi_current;
    double          rsi_h4;
    double          rsi_d1;
    double          volume_ratio;
    double          risk_percent;
    double          calculated_lot;
    bool            risk_check_passed;
    bool            drawdown_check_passed;
    int             open_positions;
    double          account_equity;
    string          calendar_signal;
    double          calendar_confidence;
    string          additional_notes;
};

//+------------------------------------------------------------------+
//| Intelligent Reporter Class                                        |
//+------------------------------------------------------------------+
class CGrandeIntelligentReporter
{
private:
    string              m_symbol;
    STradeDecision      m_decisions[];
    int                 m_decision_count;
    datetime            m_last_report_time;
    datetime            m_session_start;
    int                 m_report_interval_seconds;
    string              m_report_filename;
    
    // Statistics
    int                 m_total_signals;
    int                 m_signals_rejected;
    int                 m_signals_executed;
    int                 m_trend_signals;
    int                 m_breakout_signals;
    int                 m_range_signals;
    int                 m_triangle_signals;
    
    // Rejection reasons tracking
    int                 m_reject_ema_alignment;
    int                 m_reject_pullback;
    int                 m_reject_rsi;
    int                 m_reject_volume;
    int                 m_reject_key_levels;
    int                 m_reject_risk;
    int                 m_reject_drawdown;
    int                 m_reject_max_positions;
    int                 m_reject_trend_follower;
    int                 m_reject_pattern;
    int                 m_reject_other;
    
public:
    CGrandeIntelligentReporter();
    ~CGrandeIntelligentReporter();
    
    bool Initialize(const string symbol, int report_interval_minutes = 60);
    void RecordDecision(const STradeDecision &decision);
    void RecordSignalEvaluation(const string signal_type, const string rejection_reason,
                                const double price, const double atr, 
                                const double adx_h1, const double adx_h4, const double adx_d1,
                                const string regime, const double regime_confidence,
                                const double rsi_current, const double rsi_h4, const double rsi_d1,
                                const double volume_ratio, const double risk_percent,
                                const string additional_notes = "");
    
    void GenerateHourlyReport();
    void GenerateFinBERTDataset();
    void PrintReportToExperts();
    void SaveReportToFile(const string &report);
    
    string GetRejectionSummary();
    string GetMarketConditionsSummary();
    string GetOpportunityAnalysis();
    string GetFinBERTFormattedData();
    
    void ResetStatistics();
    void UpdateStatistics(const STradeDecision &decision);
    
    // Quick tracking methods
    void TrackTrendSignal(bool bullish, const string rejection_reason);
    void TrackBreakoutSignal(const string rejection_reason);
    void TrackRangeSignal(const string rejection_reason);
    void TrackTriangleSignal(const string rejection_reason);
    
    string GetPrimaryBlocker();  // Add declaration
    
    bool IsReportDue() { return (TimeCurrent() - m_last_report_time >= m_report_interval_seconds); }
    
private:
    void CategorizeRejection(const string &reason);
    string FormatTimeElapsed(int seconds);
    string GetRejectionCategory(const string &reason);
    double CalculateSuccessRate();
    string GenerateActionableInsights();
    string GenerateFinBERTPrompt();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandeIntelligentReporter::CGrandeIntelligentReporter()
{
    m_symbol = "";
    m_decision_count = 0;
    m_last_report_time = 0;
    m_session_start = TimeCurrent();
    m_report_interval_seconds = 3600; // Default 1 hour
    ResetStatistics();
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CGrandeIntelligentReporter::~CGrandeIntelligentReporter()
{
    // Generate final report before shutdown
    if(m_decision_count > 0)
    {
        GenerateHourlyReport();
    }
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CGrandeIntelligentReporter::Initialize(const string symbol, int report_interval_minutes = 60)
{
    m_symbol = symbol;
    m_report_interval_seconds = report_interval_minutes * 60;
    m_session_start = TimeCurrent();
    m_last_report_time = TimeCurrent();
    
    // Create report filename with date
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    m_report_filename = StringFormat("GrandeReport_%s_%04d%02d%02d.txt", 
                                    m_symbol, dt.year, dt.mon, dt.day);
    
    ArrayResize(m_decisions, 0);
    m_decision_count = 0;
    
    Print("[REPORTER] Initialized for ", m_symbol, " with ", report_interval_minutes, 
          " minute reporting interval");
    
    // Write header to file
    string header = StringFormat("=== GRANDE INTELLIGENT TRADING REPORTER ===\n" +
                                "Symbol: %s\n" +
                                "Session Start: %s\n" +
                                "Report Interval: %d minutes\n" +
                                "==========================================\n\n",
                                m_symbol,
                                TimeToString(m_session_start, TIME_DATE|TIME_MINUTES),
                                report_interval_minutes);
    SaveReportToFile(header);
    
    return true;
}

//+------------------------------------------------------------------+
//| Record a trading decision                                        |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::RecordDecision(const STradeDecision &decision)
{
    int new_size = ArrayResize(m_decisions, m_decision_count + 1);
    if(new_size > m_decision_count)
    {
        m_decisions[m_decision_count] = decision;
        m_decision_count++;
        UpdateStatistics(decision);
    }
}

//+------------------------------------------------------------------+
//| Record signal evaluation with detailed parameters                |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::RecordSignalEvaluation(
    const string signal_type, const string rejection_reason,
    const double price, const double atr, 
    const double adx_h1, const double adx_h4, const double adx_d1,
    const string regime, const double regime_confidence,
    const double rsi_current, const double rsi_h4, const double rsi_d1,
    const double volume_ratio, const double risk_percent,
    const string additional_notes)
{
    STradeDecision decision;
    decision.timestamp = TimeCurrent();
    decision.signal_type = signal_type;
    decision.decision = (rejection_reason == "" ? "EXECUTED" : "REJECTED");
    decision.rejection_reason = rejection_reason;
    decision.price = price;
    decision.atr = atr;
    decision.adx_h1 = adx_h1;
    decision.adx_h4 = adx_h4;
    decision.adx_d1 = adx_d1;
    decision.regime = regime;
    decision.regime_confidence = regime_confidence;
    decision.rsi_current = rsi_current;
    decision.rsi_h4 = rsi_h4;
    decision.rsi_d1 = rsi_d1;
    decision.volume_ratio = volume_ratio;
    decision.risk_percent = risk_percent;
    decision.additional_notes = additional_notes;
    decision.account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    decision.open_positions = PositionsTotal();
    
    RecordDecision(decision);
}

//+------------------------------------------------------------------+
//| Generate hourly report                                           |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::GenerateHourlyReport()
{
    string report = "";
    
    // Header - adjust title based on whether this is initial or regular report
    bool isInitial = (m_decision_count == 0 && (TimeCurrent() - m_session_start) < 60);
    string reportTitle = isInitial ? "INITIAL INTELLIGENCE REPORT" : "HOURLY INTELLIGENCE REPORT";
    
    report += "\n" + StringPadCenter(reportTitle, 60, "=") + "\n";
    report += StringFormat("Report Time: %s\n", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    report += StringFormat("Session Duration: %s\n", FormatTimeElapsed((int)(TimeCurrent() - m_session_start)));
    report += StringFormat("Symbol: %s | Account Equity: %.2f\n\n", m_symbol, AccountInfoDouble(ACCOUNT_EQUITY));
    
    // Executive Summary
    report += StringPadCenter(" EXECUTIVE SUMMARY ", 60, "-") + "\n";
    
    if(m_total_signals == 0)
    {
        report += "No trading signals evaluated yet.\n";
        report += "System is monitoring for opportunities...\n\n";
        report += "Initial market scan in progress.\n";
        report += "Reports will update hourly with trading decisions.\n\n";
    }
    else
    {
        report += StringFormat("Total Signals Evaluated: %d\n", m_total_signals);
        report += StringFormat("Signals Executed: %d (%.1f%%)\n", m_signals_executed, 
                              m_total_signals > 0 ? (double)m_signals_executed/m_total_signals*100 : 0);
        report += StringFormat("Signals Rejected: %d (%.1f%%)\n\n", m_signals_rejected,
                              m_total_signals > 0 ? (double)m_signals_rejected/m_total_signals*100 : 0);
    }
    
    // Signal Breakdown
    report += StringPadCenter(" SIGNAL TYPE BREAKDOWN ", 60, "-") + "\n";
    report += StringFormat("Trend Signals: %d\n", m_trend_signals);
    report += StringFormat("Breakout Signals: %d\n", m_breakout_signals);
    report += StringFormat("Range Signals: %d\n", m_range_signals);
    report += StringFormat("Triangle Signals: %d\n\n", m_triangle_signals);
    
    // Rejection Analysis
    report += StringPadCenter(" REJECTION ANALYSIS ", 60, "-") + "\n";
    report += GetRejectionSummary() + "\n";
    
    // Market Conditions
    report += StringPadCenter(" MARKET CONDITIONS ", 60, "-") + "\n";
    report += GetMarketConditionsSummary() + "\n";
    
    // Opportunity Analysis
    report += StringPadCenter(" OPPORTUNITY ANALYSIS ", 60, "-") + "\n";
    report += GetOpportunityAnalysis() + "\n";
    
    // Actionable Insights
    report += StringPadCenter(" ACTIONABLE INSIGHTS ", 60, "-") + "\n";
    report += GenerateActionableInsights() + "\n";
    
    // Recent Decisions Detail (last 5)
    report += StringPadCenter(" RECENT DECISION DETAILS ", 60, "-") + "\n";
    int start = MathMax(0, m_decision_count - 5);
    for(int i = start; i < m_decision_count; i++)
    {
        report += StringFormat("[%s] %s: %s\n", 
                              TimeToString(m_decisions[i].timestamp, TIME_MINUTES),
                              m_decisions[i].signal_type,
                              m_decisions[i].decision);
        if(m_decisions[i].decision == "REJECTED")
        {
            report += StringFormat("  Reason: %s\n", m_decisions[i].rejection_reason);
        }
        report += StringFormat("  Regime: %s (%.2f) | ADX: %.1f | RSI: %.1f\n",
                              m_decisions[i].regime, 
                              m_decisions[i].regime_confidence,
                              m_decisions[i].adx_h1,
                              m_decisions[i].rsi_current);
    }
    
    // Footer with recommendations
    report += "\n" + StringPadCenter(" RECOMMENDATIONS ", 60, "=") + "\n";
    report += GenerateFinBERTPrompt() + "\n";
    
    // Save and print
    SaveReportToFile(report);
    PrintReportToExperts();
    
    // Reset for next hour
    m_last_report_time = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get rejection summary                                            |
//+------------------------------------------------------------------+
string CGrandeIntelligentReporter::GetRejectionSummary(void)
{
    if(m_signals_rejected == 0)
        return "No signals rejected in this period.\n";
    
    string summary = "";
    
    if(m_reject_ema_alignment > 0)
        summary += StringFormat("EMA Alignment Failed: %d (%.1f%%)\n", 
                               m_reject_ema_alignment, 
                               (double)m_reject_ema_alignment/m_signals_rejected*100);
    
    if(m_reject_pullback > 0)
        summary += StringFormat("Pullback Too Far: %d (%.1f%%)\n", 
                               m_reject_pullback,
                               (double)m_reject_pullback/m_signals_rejected*100);
    
    if(m_reject_rsi > 0)
        summary += StringFormat("RSI Conditions Failed: %d (%.1f%%)\n", 
                               m_reject_rsi,
                               (double)m_reject_rsi/m_signals_rejected*100);
    
    if(m_reject_volume > 0)
        summary += StringFormat("Insufficient Volume: %d (%.1f%%)\n", 
                               m_reject_volume,
                               (double)m_reject_volume/m_signals_rejected*100);
    
    if(m_reject_key_levels > 0)
        summary += StringFormat("Key Level Issues: %d (%.1f%%)\n", 
                               m_reject_key_levels,
                               (double)m_reject_key_levels/m_signals_rejected*100);
    
    if(m_reject_risk > 0)
        summary += StringFormat("Risk Management Block: %d (%.1f%%)\n", 
                               m_reject_risk,
                               (double)m_reject_risk/m_signals_rejected*100);
    
    if(m_reject_drawdown > 0)
        summary += StringFormat("Drawdown Limit: %d (%.1f%%)\n", 
                               m_reject_drawdown,
                               (double)m_reject_drawdown/m_signals_rejected*100);
    
    if(m_reject_max_positions > 0)
        summary += StringFormat("Max Positions Reached: %d (%.1f%%)\n", 
                               m_reject_max_positions,
                               (double)m_reject_max_positions/m_signals_rejected*100);
    
    if(m_reject_trend_follower > 0)
        summary += StringFormat("Trend Follower Rejection: %d (%.1f%%)\n", 
                               m_reject_trend_follower,
                               (double)m_reject_trend_follower/m_signals_rejected*100);
    
    if(m_reject_pattern > 0)
        summary += StringFormat("Pattern Not Valid: %d (%.1f%%)\n", 
                               m_reject_pattern,
                               (double)m_reject_pattern/m_signals_rejected*100);
    
    return summary;
}

//+------------------------------------------------------------------+
//| Get market conditions summary                                    |
//+------------------------------------------------------------------+
string CGrandeIntelligentReporter::GetMarketConditionsSummary(void)
{
    if(m_decision_count == 0)
    {
        // Provide current market snapshot even without decisions
        string summary = "";
        double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        summary += StringFormat("Current Price: %.5f\n", currentPrice);
        summary += "Awaiting first signal evaluation for detailed analysis.\n";
        summary += "Market conditions will be tracked with each decision.\n";
        return summary;
    }
    
    // Get latest decision for current market state
    STradeDecision latest = m_decisions[m_decision_count - 1];  // Remove reference, copy instead
    
    string summary = "";
    summary += StringFormat("Current Price: %.5f\n", latest.price);
    summary += StringFormat("Current Regime: %s (Confidence: %.2f)\n", 
                           latest.regime, latest.regime_confidence);
    summary += StringFormat("ADX Values - H1: %.1f | H4: %.1f | D1: %.1f\n",
                           latest.adx_h1, latest.adx_h4, latest.adx_d1);
    summary += StringFormat("RSI Values - Current: %.1f | H4: %.1f | D1: %.1f\n",
                           latest.rsi_current, latest.rsi_h4, latest.rsi_d1);
    summary += StringFormat("ATR: %.5f\n", latest.atr);
    summary += StringFormat("Key Levels Detected: %d\n", latest.key_levels_count);
    
    if(latest.nearest_resistance > 0)
        summary += StringFormat("Nearest Resistance: %.5f (%.1f pips away)\n", 
                               latest.nearest_resistance,
                               (latest.nearest_resistance - latest.price) / _Point);
    
    if(latest.nearest_support > 0)
        summary += StringFormat("Nearest Support: %.5f (%.1f pips away)\n", 
                               latest.nearest_support,
                               (latest.price - latest.nearest_support) / _Point);
    
    return summary;
}

//+------------------------------------------------------------------+
//| Get opportunity analysis                                         |
//+------------------------------------------------------------------+
string CGrandeIntelligentReporter::GetOpportunityAnalysis(void)
{
    string analysis = "";
    
    // Analyze why opportunities are being missed
    if(m_signals_rejected > m_signals_executed * 3)
    {
        analysis += "🔴 HIGH REJECTION RATE: System is being too conservative.\n";
        
        // Identify primary blockers
        int max_reject = MathMax(m_reject_ema_alignment, 
                        MathMax(m_reject_pullback,
                        MathMax(m_reject_rsi,
                        MathMax(m_reject_volume,
                        MathMax(m_reject_risk, m_reject_drawdown)))));
        
        if(max_reject == m_reject_ema_alignment)
            analysis += "   Primary Issue: EMA alignment criteria too strict.\n";
        else if(max_reject == m_reject_pullback)
            analysis += "   Primary Issue: Pullback requirements too tight.\n";
        else if(max_reject == m_reject_rsi)
            analysis += "   Primary Issue: RSI conditions rarely met.\n";
        else if(max_reject == m_reject_volume)
            analysis += "   Primary Issue: Volume requirements too high.\n";
        else if(max_reject == m_reject_risk || max_reject == m_reject_drawdown)
            analysis += "   Primary Issue: Risk management too restrictive.\n";
    }
    else if(m_signals_executed == 0 && m_total_signals > 5)
    {
        analysis += "⚠️ NO TRADES EXECUTED: All signals filtered out.\n";
        analysis += "   Consider reviewing entry criteria or market conditions.\n";
    }
    else if(m_signals_executed > 0)
    {
        analysis += StringFormat("✅ TRADING ACTIVE: %d positions opened.\n", m_signals_executed);
    }
    else
    {
        analysis += "📊 WAITING: Market conditions not optimal for entry.\n";
    }
    
    // Add specific recommendations based on recent patterns
    if(m_decision_count > 0)
    {
        STradeDecision latest = m_decisions[m_decision_count - 1];  // Remove reference, copy instead
        
        if(latest.regime == "RANGING" && m_range_signals == 0)
            analysis += "💡 Range regime detected but no range trades attempted.\n";
        
        if(latest.regime == "TREND_BULL" || latest.regime == "TREND_BEAR")
        {
            if(m_trend_signals > 0 && m_reject_pullback > m_trend_signals * 0.5)
                analysis += "💡 Trend active but pullback criteria preventing entries.\n";
        }
        
        if(latest.adx_h1 < 20 && m_breakout_signals > 0)
            analysis += "💡 Low ADX but breakout signals attempted - market may be choppy.\n";
    }
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Generate actionable insights                                     |
//+------------------------------------------------------------------+
string CGrandeIntelligentReporter::GenerateActionableInsights(void)
{
    string insights = "";
    
    // Based on rejection patterns, provide specific recommendations
    if(m_reject_ema_alignment > m_signals_rejected * 0.3)
    {
        insights += "1. EMA ALIGNMENT: Consider reducing timeframe alignment requirements\n";
        insights += "   or waiting for clearer trend establishment.\n\n";
    }
    
    if(m_reject_pullback > m_signals_rejected * 0.3)
    {
        insights += "2. PULLBACK DISTANCE: Price frequently too far from EMAs.\n";
        insights += "   Consider: a) Increasing acceptable pullback range\n";
        insights += "            b) Using limit orders at optimal levels\n\n";
    }
    
    if(m_reject_rsi > m_signals_rejected * 0.3)
    {
        insights += "3. RSI CONDITIONS: RSI rarely in acceptable range (40-60).\n";
        insights += "   Market may be strongly trending - adjust RSI windows.\n\n";
    }
    
    if(m_reject_volume > m_signals_rejected * 0.2)
    {
        insights += "4. VOLUME: Low volume preventing breakout trades.\n";
        insights += "   Consider trading during more active sessions.\n\n";
    }
    
    if(m_reject_risk + m_reject_drawdown + m_reject_max_positions > m_signals_rejected * 0.2)
    {
        insights += "5. RISK MANAGEMENT: Conservative settings blocking trades.\n";
        insights += "   Review position sizing and drawdown limits.\n\n";
    }
    
    if(insights == "")
    {
        insights = "System operating within normal parameters.\n";
        insights += "Continue monitoring for optimal entry conditions.\n";
    }
    
    return insights;
}

//+------------------------------------------------------------------+
//| Generate FinBERT formatted prompt                                |
//+------------------------------------------------------------------+
string CGrandeIntelligentReporter::GenerateFinBERTPrompt(void)
{
    if(m_decision_count == 0)
        return "Insufficient data for FinBERT analysis.";
    
    STradeDecision latest = m_decisions[m_decision_count - 1];  // Remove reference, copy instead
    
    string prompt = "MARKET ANALYSIS REQUEST FOR AI:\n\n";
    
    prompt += "CONTEXT: Trading system evaluating " + m_symbol + " opportunities.\n";
    prompt += StringFormat("- Signals analyzed: %d\n", m_total_signals);
    prompt += StringFormat("- Execution rate: %.1f%%\n", CalculateSuccessRate());
    prompt += StringFormat("- Current regime: %s\n", latest.regime);
    prompt += StringFormat("- Trend strength (ADX): %.1f\n", latest.adx_h1);
    prompt += StringFormat("- Momentum (RSI): %.1f\n", latest.rsi_current);
    
    prompt += "\nKEY BLOCKING FACTORS:\n";
    
    // List top 3 rejection reasons
    int reasons[10];
    reasons[0] = m_reject_ema_alignment;
    reasons[1] = m_reject_pullback;
    reasons[2] = m_reject_rsi;
    reasons[3] = m_reject_volume;
    reasons[4] = m_reject_risk;
    
    for(int i = 0; i < 3; i++)
    {
        int max_idx = 0;
        int max_val = 0;
        for(int j = 0; j < 5; j++)
        {
            if(reasons[j] > max_val)
            {
                max_val = reasons[j];
                max_idx = j;
            }
        }
        
        if(max_val > 0)
        {
            string reason_name = "";
            switch(max_idx)
            {
                case 0: reason_name = "EMA Alignment"; break;
                case 1: reason_name = "Pullback Distance"; break;
                case 2: reason_name = "RSI Conditions"; break;
                case 3: reason_name = "Volume"; break;
                case 4: reason_name = "Risk Management"; break;
            }
            prompt += StringFormat("- %s: %d occurrences\n", reason_name, max_val);
            reasons[max_idx] = 0; // Clear for next iteration
        }
    }
    
    prompt += "\nQUESTION: Should trading criteria be adjusted or maintain current discipline?\n";
    prompt += "Consider: Market conditions, risk/reward, and signal quality.\n";
    
    return prompt;
}

//+------------------------------------------------------------------+
//| Print report to Experts tab                                      |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::PrintReportToExperts(void)
{
    Print("========================================");
    Print("📊 HOURLY INTELLIGENCE REPORT");
    Print("========================================");
    Print("Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    Print("Symbol: ", m_symbol);
    
    Print("--- PERFORMANCE SUMMARY ---");
    Print("Signals Evaluated: ", m_total_signals);
    Print("Executed: ", m_signals_executed, " (", 
          m_total_signals > 0 ? DoubleToString((double)m_signals_executed/m_total_signals*100, 1) : "0", "%)");
    Print("Rejected: ", m_signals_rejected, " (", 
          m_total_signals > 0 ? DoubleToString((double)m_signals_rejected/m_total_signals*100, 1) : "0", "%)");
    
    Print("--- TOP REJECTION REASONS ---");
    if(m_reject_ema_alignment > 0) Print("EMA Alignment: ", m_reject_ema_alignment);
    if(m_reject_pullback > 0) Print("Pullback Distance: ", m_reject_pullback);
    if(m_reject_rsi > 0) Print("RSI Conditions: ", m_reject_rsi);
    if(m_reject_volume > 0) Print("Volume: ", m_reject_volume);
    if(m_reject_risk > 0) Print("Risk Management: ", m_reject_risk);
    if(m_reject_trend_follower > 0) Print("Trend Follower: ", m_reject_trend_follower);
    if(m_reject_pattern > 0) Print("Pattern: ", m_reject_pattern);
    if(m_reject_key_levels > 0) Print("Key Levels: ", m_reject_key_levels);
    if(m_reject_other > 0) Print("Other: ", m_reject_other);
    
    if(m_decision_count > 0)
    {
        STradeDecision latest = m_decisions[m_decision_count - 1];  // Remove reference, copy instead
        Print("--- CURRENT MARKET STATE ---");
        Print("Regime: ", latest.regime, " (", DoubleToString(latest.regime_confidence, 2), ")");
        Print("ADX H1: ", DoubleToString(latest.adx_h1, 1));
        Print("RSI: ", DoubleToString(latest.rsi_current, 1));
    }
    
    // Key insight
    if(m_signals_executed == 0 && m_total_signals > 5)
    {
        Print("⚠️ ALERT: No trades executed despite ", m_total_signals, " signals evaluated!");
        Print("Primary blocker: ", GetPrimaryBlocker());
    }
    
    Print("========================================");
    Print("Full report saved to: Files/", m_report_filename);
    Print("========================================");
}

//+------------------------------------------------------------------+
//| Save report to file                                              |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::SaveReportToFile(const string &report)
{
    int handle = FileOpen(m_report_filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI, ";");
    if(handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        FileWriteString(handle, report + "\n");
        FileClose(handle);
    }
}

//+------------------------------------------------------------------+
//| Generate FinBERT dataset                                         |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::GenerateFinBERTDataset(void)
{
    string filename = StringFormat("FinBERT_Data_%s_%s.csv", 
                                  m_symbol, 
                                  TimeToString(TimeCurrent(), TIME_DATE));
    
    int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to create FinBERT dataset file");
        return;
    }
    
    // Write CSV header
    FileWrite(handle, "timestamp", "signal_type", "decision", "rejection_reason",
              "price", "atr", "adx_h1", "adx_h4", "adx_d1", 
              "regime", "regime_confidence", "rsi_current", "rsi_h4", "rsi_d1",
              "volume_ratio", "risk_percent", "account_equity", "open_positions",
              "calendar_signal", "calendar_confidence");
    
    // Write all decisions
    for(int i = 0; i < m_decision_count; i++)
    {
        FileWrite(handle,
                 TimeToString(m_decisions[i].timestamp, TIME_DATE|TIME_SECONDS),
                 m_decisions[i].signal_type,
                 m_decisions[i].decision,
                 m_decisions[i].rejection_reason,
                 DoubleToString(m_decisions[i].price, 5),
                 DoubleToString(m_decisions[i].atr, 5),
                 DoubleToString(m_decisions[i].adx_h1, 1),
                 DoubleToString(m_decisions[i].adx_h4, 1),
                 DoubleToString(m_decisions[i].adx_d1, 1),
                 m_decisions[i].regime,
                 DoubleToString(m_decisions[i].regime_confidence, 3),
                 DoubleToString(m_decisions[i].rsi_current, 1),
                 DoubleToString(m_decisions[i].rsi_h4, 1),
                 DoubleToString(m_decisions[i].rsi_d1, 1),
                 DoubleToString(m_decisions[i].volume_ratio, 2),
                 DoubleToString(m_decisions[i].risk_percent, 2),
                 DoubleToString(m_decisions[i].account_equity, 2),
                 IntegerToString(m_decisions[i].open_positions),
                 m_decisions[i].calendar_signal,
                 DoubleToString(m_decisions[i].calendar_confidence, 3));
    }
    
    FileClose(handle);
    Print("FinBERT dataset saved to: Files/", filename);
}

//+------------------------------------------------------------------+
//| Update statistics                                                |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::UpdateStatistics(const STradeDecision &decision)
{
    m_total_signals++;
    
    if(decision.decision == "EXECUTED")
    {
        m_signals_executed++;
    }
    else if(decision.decision == "REJECTED")
    {
        m_signals_rejected++;
        CategorizeRejection(decision.rejection_reason);
    }
    else if(decision.decision == "PASSED")
    {
        // Handle PASSED signals (these are successful signal evaluations that passed all criteria)
    }
    
    // Count signal types
    if(StringFind(decision.signal_type, "TREND") >= 0)
    {
        m_trend_signals++;
    }
    else if(StringFind(decision.signal_type, "BREAKOUT") >= 0)
    {
        m_breakout_signals++;
    }
    else if(StringFind(decision.signal_type, "RANGE") >= 0)
    {
        m_range_signals++;
    }
    else if(StringFind(decision.signal_type, "TRIANGLE") >= 0)
    {
        m_triangle_signals++;
    }
}

//+------------------------------------------------------------------+
//| Categorize rejection reason                                      |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::CategorizeRejection(const string &reason)
{
    if(reason == "")
    {
        m_reject_other++;
        return;
    }
    
    string reason_lower = reason;
    StringToLower(reason_lower);
    
    if(StringFind(reason_lower, "ema") >= 0 || StringFind(reason_lower, "alignment") >= 0)
    {
        m_reject_ema_alignment++;
    }
    else if(StringFind(reason_lower, "pullback") >= 0 || StringFind(reason_lower, "distance") >= 0)
    {
        m_reject_pullback++;
    }
    else if(StringFind(reason_lower, "rsi") >= 0)
    {
        m_reject_rsi++;
    }
    else if(StringFind(reason_lower, "volume") >= 0)
    {
        m_reject_volume++;
    }
    else if(StringFind(reason_lower, "level") >= 0 || StringFind(reason_lower, "boundaries") >= 0)
    {
        m_reject_key_levels++;
    }
    else if(StringFind(reason_lower, "risk") >= 0)
    {
        m_reject_risk++;
    }
    else if(StringFind(reason_lower, "drawdown") >= 0)
    {
        m_reject_drawdown++;
    }
    else if(StringFind(reason_lower, "position") >= 0)
    {
        m_reject_max_positions++;
    }
    else if(StringFind(reason_lower, "trend follower") >= 0 || StringFind(reason_lower, "multi-timeframe") >= 0)
    {
        m_reject_trend_follower++;
    }
    else if(StringFind(reason_lower, "pattern") >= 0 || StringFind(reason_lower, "inside") >= 0)
    {
        m_reject_pattern++;
    }
    else if(StringFind(reason_lower, "narrow") >= 0 || StringFind(reason_lower, "trending") >= 0)
    {
        m_reject_other++;
    }
    else
    {
        m_reject_other++;
    }
}

//+------------------------------------------------------------------+
//| Reset statistics                                                 |
//+------------------------------------------------------------------+
void CGrandeIntelligentReporter::ResetStatistics(void)
{
    m_total_signals = 0;
    m_signals_rejected = 0;
    m_signals_executed = 0;
    m_trend_signals = 0;
    m_breakout_signals = 0;
    m_range_signals = 0;
    m_triangle_signals = 0;
    
    m_reject_ema_alignment = 0;
    m_reject_pullback = 0;
    m_reject_rsi = 0;
    m_reject_volume = 0;
    m_reject_key_levels = 0;
    m_reject_risk = 0;
    m_reject_drawdown = 0;
    m_reject_max_positions = 0;
    m_reject_trend_follower = 0;
    m_reject_pattern = 0;
    m_reject_other = 0;
}

//+------------------------------------------------------------------+
//| Format time elapsed                                              |
//+------------------------------------------------------------------+
string CGrandeIntelligentReporter::FormatTimeElapsed(int seconds)
{
    int hours = seconds / 3600;
    int minutes = (seconds % 3600) / 60;
    int secs = seconds % 60;
    
    return StringFormat("%02d:%02d:%02d", hours, minutes, secs);
}

//+------------------------------------------------------------------+
//| Calculate success rate                                           |
//+------------------------------------------------------------------+
double CGrandeIntelligentReporter::CalculateSuccessRate(void)
{
    if(m_total_signals == 0) return 0.0;
    return (double)m_signals_executed / m_total_signals * 100.0;
}

//+------------------------------------------------------------------+
//| Get primary blocker                                              |
//+------------------------------------------------------------------+
string CGrandeIntelligentReporter::GetPrimaryBlocker(void)
{
    int max_val = m_reject_ema_alignment;
    string blocker = "EMA Alignment";
    
    if(m_reject_pullback > max_val)
    {
        max_val = m_reject_pullback;
        blocker = "Pullback Distance";
    }
    if(m_reject_rsi > max_val)
    {
        max_val = m_reject_rsi;
        blocker = "RSI Conditions";
    }
    if(m_reject_volume > max_val)
    {
        max_val = m_reject_volume;
        blocker = "Volume Requirements";
    }
    if(m_reject_risk > max_val)
    {
        max_val = m_reject_risk;
        blocker = "Risk Management";
    }
    if(m_reject_drawdown > max_val)
    {
        max_val = m_reject_drawdown;
        blocker = "Drawdown Limits";
    }
    
    return blocker;
}

//+------------------------------------------------------------------+
//| String padding helper                                            |
//+------------------------------------------------------------------+
string StringPadCenter(const string text, const int width, const string pad = " ")
{
    int text_len = StringLen(text);
    if(text_len >= width) return text;
    
    int pad_left = (width - text_len) / 2;
    int pad_right = width - text_len - pad_left;
    
    string result = "";
    for(int i = 0; i < pad_left; i++) result += pad;
    result += text;
    for(int i = 0; i < pad_right; i++) result += pad;
    
    return result;
}

// Removed duplicate standalone function - now properly defined as member function
