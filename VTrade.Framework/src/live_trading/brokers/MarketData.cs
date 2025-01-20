using System;

namespace VTrade.Framework.LiveTrading.Brokers
{
    public class MarketData
    {
        public string Symbol { get; set; }
        public string Timeframe { get; set; }
        public decimal Open { get; set; }
        public decimal High { get; set; }
        public decimal Low { get; set; }
        public decimal Close { get; set; }
        public long Volume { get; set; }
        public DateTime Timestamp { get; set; }
    }
} 