using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using VTrade.Framework.Backtesting.Models;

namespace VTrade.Framework.LiveTrading.Brokers
{
    /// <summary>
    /// Interface for broker implementations
    /// </summary>
    public interface IBroker
    {
        /// <summary>
        /// Connect to the broker
        /// </summary>
        Task Connect(BrokerConfig config);

        /// <summary>
        /// Disconnect from the broker
        /// </summary>
        Task Disconnect();

        /// <summary>
        /// Subscribe to market data updates
        /// </summary>
        Task<bool> SubscribeToMarketData(string symbol, string timeframe);

        /// <summary>
        /// Place a new order
        /// </summary>
        Task<OrderResponse> PlaceOrder(OrderRequest request);

        /// <summary>
        /// Modify an existing order
        /// </summary>
        Task<bool> ModifyOrder(string orderId, OrderModifyRequest request);

        /// <summary>
        /// Cancel an order
        /// </summary>
        Task<bool> CancelOrder(string orderId);

        /// <summary>
        /// Get current positions
        /// </summary>
        Task<IEnumerable<PositionInfo>> GetPositions();

        /// <summary>
        /// Get account information
        /// </summary>
        Task<AccountInfo> GetAccountInfo();

        /// <summary>
        /// Event raised when market data is updated
        /// </summary>
        event Action<MarketData> OnMarketDataUpdate;

        /// <summary>
        /// Event raised when a trade is executed
        /// </summary>
        event Action<TradeInfo> OnTradeExecuted;
    }

    public class BrokerConfig
    {
        public string ApiKey { get; set; }
        public string SecretKey { get; set; }
        public string AccountId { get; set; }
        public bool IsDemoAccount { get; set; }
        public string ServerAddress { get; set; }
        public int ServerPort { get; set; }
        public Dictionary<string, object> CustomSettings { get; set; }
    }

    public class OrderRequest
    {
        public string Symbol { get; set; }
        public string OrderType { get; set; }
        public decimal Volume { get; set; }
        public decimal? Price { get; set; }
        public decimal? StopLoss { get; set; }
        public decimal? TakeProfit { get; set; }
        public string Direction { get; set; }
        public Dictionary<string, object> CustomParameters { get; set; }
    }

    public class OrderResponse
    {
        public string OrderId { get; set; }
        public string Status { get; set; }
        public string Message { get; set; }
        public decimal ExecutedPrice { get; set; }
        public decimal ExecutedVolume { get; set; }
    }

    public class OrderModifyRequest
    {
        public decimal? NewPrice { get; set; }
        public decimal? NewStopLoss { get; set; }
        public decimal? NewTakeProfit { get; set; }
        public decimal? NewVolume { get; set; }
    }

    public class PositionInfo
    {
        public string Symbol { get; set; }
        public string Direction { get; set; }
        public decimal Volume { get; set; }
        public decimal EntryPrice { get; set; }
        public decimal CurrentPrice { get; set; }
        public decimal ProfitLoss { get; set; }
        public decimal? StopLoss { get; set; }
        public decimal? TakeProfit { get; set; }
    }

    public class AccountInfo
    {
        public string AccountId { get; set; }
        public decimal Balance { get; set; }
        public decimal Equity { get; set; }
        public decimal MarginUsed { get; set; }
        public decimal FreeMargin { get; set; }
        public decimal ProfitLoss { get; set; }
        public string Currency { get; set; }
    }
} 