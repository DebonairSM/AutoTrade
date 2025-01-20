using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using VTrade.Framework.Backtesting.Models;
using VTrade.Framework.LiveTrading.Brokers;

namespace VTrade.Framework.RiskManagement
{
    /// <summary>
    /// Interface for risk management components
    /// </summary>
    public interface IRiskManager
    {
        /// <summary>
        /// Validate a potential trade against risk rules
        /// </summary>
        Task<RiskValidationResult> ValidateTrade(TradeRequest request);

        /// <summary>
        /// Calculate position size based on risk parameters
        /// </summary>
        Task<PositionSizeResult> CalculatePositionSize(PositionSizeRequest request);

        /// <summary>
        /// Monitor and adjust stop loss levels
        /// </summary>
        Task<StopLossAdjustment> UpdateStopLoss(string symbol, string positionId);

        /// <summary>
        /// Get current risk exposure
        /// </summary>
        Task<RiskExposure> GetCurrentExposure();
    }

    public class TradeRequest
    {
        public string Symbol { get; set; }
        public string Direction { get; set; }
        public decimal EntryPrice { get; set; }
        public decimal StopLoss { get; set; }
        public decimal TakeProfit { get; set; }
        public decimal RequestedVolume { get; set; }
        public Dictionary<string, object> AdditionalParams { get; set; }
    }

    public class RiskValidationResult
    {
        public bool IsValid { get; set; }
        public List<string> ValidationMessages { get; set; }
        public decimal AdjustedVolume { get; set; }
        public decimal AdjustedStopLoss { get; set; }
        public decimal MaxAllowedRisk { get; set; }
        public Dictionary<string, object> AdditionalInfo { get; set; }
    }

    public class PositionSizeRequest
    {
        public string Symbol { get; set; }
        public decimal AccountBalance { get; set; }
        public decimal RiskPercent { get; set; }
        public decimal EntryPrice { get; set; }
        public decimal StopLoss { get; set; }
        public Dictionary<string, decimal> ExistingExposures { get; set; }
    }

    public class PositionSizeResult
    {
        public decimal Volume { get; set; }
        public decimal RiskAmount { get; set; }
        public decimal MarginRequired { get; set; }
        public bool ExceedsMaxRisk { get; set; }
        public Dictionary<string, decimal> Metrics { get; set; }
    }

    public class StopLossAdjustment
    {
        public string PositionId { get; set; }
        public decimal CurrentStopLoss { get; set; }
        public decimal NewStopLoss { get; set; }
        public decimal LockedProfit { get; set; }
        public string AdjustmentReason { get; set; }
    }

    public class RiskExposure
    {
        public decimal TotalRiskPercent { get; set; }
        public decimal LargestSingleExposure { get; set; }
        public Dictionary<string, decimal> ExposureBySymbol { get; set; }
        public Dictionary<string, decimal> ExposureByDirection { get; set; }
        public decimal DrawdownPercent { get; set; }
        public decimal MarginUtilization { get; set; }
    }
} 