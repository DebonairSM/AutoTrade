using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using VTrade.Framework.Backtesting.Models;

namespace VTrade.Framework.Backtesting.DataProviders
{
    /// <summary>
    /// Interface for historical market data providers
    /// </summary>
    public interface IDataProvider
    {
        /// <summary>
        /// Get historical market data for a symbol and timeframe
        /// </summary>
        Task<IEnumerable<MarketData>> GetHistoricalData(
            string symbol,
            string timeframe,
            DateTime startDate,
            DateTime endDate
        );

        /// <summary>
        /// Get available symbols from the data provider
        /// </summary>
        Task<IEnumerable<string>> GetAvailableSymbols();

        /// <summary>
        /// Get available timeframes for a symbol
        /// </summary>
        Task<IEnumerable<string>> GetAvailableTimeframes(string symbol);

        /// <summary>
        /// Validate if data is available for the given parameters
        /// </summary>
        Task<bool> ValidateDataAvailability(
            string symbol,
            string timeframe,
            DateTime startDate,
            DateTime endDate
        );

        /// <summary>
        /// Initialize the data provider with configuration
        /// </summary>
        Task Initialize(DataProviderConfig config);
    }

    public class DataProviderConfig
    {
        public string ConnectionString { get; set; }
        public string DataDirectory { get; set; }
        public bool UseCache { get; set; }
        public TimeSpan CacheExpiration { get; set; }
        public Dictionary<string, object> CustomSettings { get; set; }
    }
} 