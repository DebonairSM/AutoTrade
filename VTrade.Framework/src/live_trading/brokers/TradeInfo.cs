using System;

namespace VTrade.Framework.LiveTrading.Brokers
{
    public class TradeInfo
    {
        public string Symbol { get; set; }
        public string OrderType { get; set; }
        public decimal Volume { get; set; }
        public decimal Price { get; set; }
        public decimal ProfitLoss { get; set; }
        public string Direction { get; set; }
        public DateTime ExecutionTime { get; set; }
        public string OrderId { get; set; }
        public decimal? StopLoss { get; set; }
        public decimal? TakeProfit { get; set; }
        public string Comment { get; set; }
    }
} 