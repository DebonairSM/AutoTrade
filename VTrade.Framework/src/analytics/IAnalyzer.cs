using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using VTrade.Framework.Backtesting.Models;

namespace VTrade.Framework.Analytics
{
    /// <summary>
    /// Interface for market analysis components
    /// </summary>
    public interface IAnalyzer
    {
        /// <summary>
        /// Analyze market data for signals
        /// </summary>
        Task<AnalysisResult> Analyze(MarketData data);

        /// <summary>
        /// Get current market conditions
        /// </summary>
        Task<MarketCondition> GetMarketCondition(string symbol, string timeframe);

        /// <summary>
        /// Calculate technical indicators
        /// </summary>
        Task<Dictionary<string, decimal>> CalculateIndicators(string symbol, string timeframe);

        /// <summary>
        /// Detect market regime (trending, ranging, etc.)
        /// </summary>
        Task<MarketRegime> DetectRegime(string symbol, string timeframe);
    }

    public class AnalysisResult
    {
        public string Symbol { get; set; }
        public DateTime Timestamp { get; set; }
        public List<Signal> Signals { get; set; }
        public MarketRegime Regime { get; set; }
        public Dictionary<string, decimal> Indicators { get; set; }
        public decimal TrendStrength { get; set; }
        public decimal Volatility { get; set; }
    }

    public class Signal
    {
        public string Type { get; set; }
        public string Direction { get; set; }
        public decimal Strength { get; set; }
        public decimal TargetPrice { get; set; }
        public decimal StopLoss { get; set; }
        public Dictionary<string, object> Parameters { get; set; }
    }

    public class MarketCondition
    {
        public decimal Volatility { get; set; }
        public decimal Volume { get; set; }
        public decimal Spread { get; set; }
        public decimal TrendStrength { get; set; }
        public decimal SupportLevel { get; set; }
        public decimal ResistanceLevel { get; set; }
        public Dictionary<string, decimal> CustomMetrics { get; set; }
    }

    public enum MarketRegime
    {
        Trending,
        Ranging,
        Volatile,
        Breakout,
        Unknown
    }
} 