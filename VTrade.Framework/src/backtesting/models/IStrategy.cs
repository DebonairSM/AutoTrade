using System;
using System.Threading.Tasks;

namespace VTrade.Framework.Backtesting.Models
{
    /// <summary>
    /// Defines the core interface for all trading strategies
    /// </summary>
    public interface IStrategy
    {
        /// <summary>
        /// Called when new market data is available
        /// </summary>
        Task OnDataUpdate(MarketData data);

        /// <summary>
        /// Called when a trade is executed
        /// </summary>
        Task OnTradeExecuted(TradeInfo trade);

        /// <summary>
        /// Called to initialize the strategy with configuration
        /// </summary>
        Task Initialize(StrategyConfig config);

        /// <summary>
        /// Called before strategy shutdown
        /// </summary>
        Task Shutdown();
    }

    public class MarketData
    {
        public string Symbol { get; set; }
        public DateTime Timestamp { get; set; }
        public decimal Open { get; set; }
        public decimal High { get; set; }
        public decimal Low { get; set; }
        public decimal Close { get; set; }
        public decimal Volume { get; set; }
        public string Timeframe { get; set; }
    }

    public class TradeInfo
    {
        public string Symbol { get; set; }
        public DateTime Timestamp { get; set; }
        public decimal Price { get; set; }
        public decimal Volume { get; set; }
        public string OrderType { get; set; }
        public decimal ProfitLoss { get; set; }
        public string Direction { get; set; }
    }

    public class StrategyConfig
    {
        public decimal RiskPerTrade { get; set; }
        public int MaxPositions { get; set; }
        public decimal MaxDrawdown { get; set; }
        public string[] AllowedSymbols { get; set; }
        public Dictionary<string, object> Parameters { get; set; }
    }
} 