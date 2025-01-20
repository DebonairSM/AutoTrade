using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using VTrade.Framework.Backtesting.Models;

namespace VTrade.Framework.Patterns
{
    /// <summary>
    /// Interface for pattern recognition components
    /// </summary>
    public interface IPatternRecognizer
    {
        /// <summary>
        /// Detect patterns in market data
        /// </summary>
        Task<List<PatternMatch>> DetectPatterns(List<MarketData> data);

        /// <summary>
        /// Get pattern statistics for a symbol
        /// </summary>
        Task<PatternStatistics> GetPatternStatistics(string symbol, string timeframe);

        /// <summary>
        /// Validate a potential pattern
        /// </summary>
        Task<bool> ValidatePattern(PatternMatch pattern, List<MarketData> data);

        /// <summary>
        /// Get pattern completion targets
        /// </summary>
        Task<PatternTargets> GetPatternTargets(PatternMatch pattern);
    }

    public class PatternMatch
    {
        public string PatternType { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public decimal Reliability { get; set; }
        public string Direction { get; set; }
        public List<PricePoint> PivotPoints { get; set; }
        public Dictionary<string, object> Parameters { get; set; }
    }

    public class PricePoint
    {
        public DateTime Time { get; set; }
        public decimal Price { get; set; }
        public string Type { get; set; }
        public decimal Volume { get; set; }
    }

    public class PatternStatistics
    {
        public string PatternType { get; set; }
        public int TotalOccurrences { get; set; }
        public decimal SuccessRate { get; set; }
        public decimal AverageProfitPips { get; set; }
        public decimal AverageLossPips { get; set; }
        public TimeSpan AverageDuration { get; set; }
        public Dictionary<string, decimal> AdditionalMetrics { get; set; }
    }

    public class PatternTargets
    {
        public decimal EntryPrice { get; set; }
        public decimal StopLoss { get; set; }
        public List<PriceTarget> Targets { get; set; }
        public decimal RiskRewardRatio { get; set; }
        public decimal CompletionProbability { get; set; }
    }

    public class PriceTarget
    {
        public decimal Price { get; set; }
        public decimal Probability { get; set; }
        public TimeSpan ExpectedDuration { get; set; }
    }
} 