# Grande Trading System - Data Sources

## Overview

Historical market data sources for backtesting. The Grande Trading System uses MT5's built-in historical data as primary source, with external APIs available as alternatives.

## Primary Source: MT5 Built-in Data ✅

**Status:** ✅ Already integrated in `GrandeDatabaseManager.mqh`

**How it works:**
- Uses MT5's `CopyRates()` function
- No API key required
- Free and unlimited (limited by broker's data availability)
- Works with any symbol available in MT5

**Usage:**
```mql5
// Already implemented - just run the EA or use BackfillHistoricalData.mq5 script
g_databaseManager.BackfillHistoricalData(symbol, PERIOD_H1, startDate, endDate);
```

**Limitations:**
- Depends on broker's historical data availability
- May have gaps for older data
- Limited to symbols your broker provides

**To backfill years of data:**
1. Run `Testing/BackfillHistoricalData.mq5` script
2. Set `InpBackfillYears = 5` (or more)
3. Enable `InpBackfillMultipleTimeframes = true` for H1/H4/D1

## Alternative Data Sources

### Alpha Vantage (FREE - API Key Required)

**Website:** https://www.alphavantage.co/

**Free Tier:**
- 5 API calls per minute
- 500 calls per day
- Real-time and historical data
- Forex, stocks, crypto

**API Key:** Free registration required

**Example Endpoint:**
```
https://www.alphavantage.co/query?function=FX_INTRADAY&from_symbol=EUR&to_symbol=USD&interval=60min&apikey=YOUR_API_KEY
```

**Best For:** Additional data validation, alternative data source

### Twelve Data (FREE - API Key Required)

**Website:** https://twelvedata.com/

**Free Tier:**
- 800 API calls per day
- Real-time and historical data
- Forex, stocks, indices, crypto
- 1-minute to monthly timeframes

**Example Endpoint:**
```
https://api.twelvedata.com/time_series?symbol=EUR/USD&interval=1h&apikey=YOUR_API_KEY
```

**Best For:** High-frequency data, multiple symbols

### OANDA API (FREE - Account Required)

**Website:** https://developer.oanda.com/

**Free Tier:**
- Free with OANDA account
- Real-time and historical data
- Forex only
- 20+ years of historical data

**Example Endpoint:**
```
https://api-fxtrade.oanda.com/v3/instruments/EUR_USD/candles?granularity=H1&from=2023-01-01T00:00:00Z&to=2023-12-31T23:59:59Z
```

**Best For:** Professional forex data, high quality

### Other Sources

- **Polygon.io** - 5 calls/min, historical data, stocks/forex/crypto
- **Finnhub** - 60 calls/min, real-time and historical, includes news/sentiment
- **IEX Cloud** - 50,000 messages/month, 15+ years historical, stocks/forex

## Integration Guide

### Option 1: Use MT5 Built-in Data (Recommended)

**Already implemented!** Just run:

```mql5
// In your EA or script
g_databaseManager.BackfillHistoricalData(_Symbol, PERIOD_H1, startDate, endDate);
```

Or use the provided script:
```
Testing/BackfillHistoricalData.mq5
```

### Option 2: Integrate External API (Advanced)

To integrate an external API, you would need to:

1. **Create API Client Class:**
```mql5
// Include/GrandeExternalDataProvider.mqh
class CGrandeExternalDataProvider
{
private:
    string m_apiKey;
    string m_baseUrl;
    
public:
    bool FetchHistoricalData(string symbol, datetime startDate, datetime endDate, MqlRates &rates[]);
    // Implementation using WebRequest()
};
```

2. **Add to Database Manager:**
```mql5
// In GrandeDatabaseManager.mqh
bool BackfillFromExternalAPI(string symbol, datetime startDate, datetime endDate)
{
    // Fetch from external API
    // Insert into database
}
```

3. **Handle Rate Limits:**
- Implement request throttling
- Cache responses
- Handle API errors gracefully

## Recommended Approach

### For Most Users:
✅ **Use MT5's built-in data** (already implemented)
- Free, unlimited (within broker limits)
- No API keys needed
- Already integrated
- Run `BackfillHistoricalData.mq5` script

### For Advanced Users:
1. **Primary:** MT5 built-in data
2. **Secondary:** Alpha Vantage or Twelve Data for validation
3. **Tertiary:** OANDA for professional forex data

## Quick Start: Backfill Years of Data

1. **Open MT5 Terminal**
2. **Navigate to:** `Scripts/Testing/BackfillHistoricalData.mq5`
3. **Set Parameters:**
   - `InpBackfillYears = 5` (or more)
   - `InpSymbol = "EURUSD"` (or your symbol)
   - `InpTimeframe = PERIOD_H1`
   - `InpBackfillMultipleTimeframes = true` (for H1/H4/D1)
4. **Run Script**
5. **Wait for completion** (may take several minutes for years of data)
6. **Check database:** Run `scripts/CheckBacktestData.ps1`

## Data Quality Comparison

| Source | Quality | Coverage | Ease of Use | Rate Limits |
|--------|---------|----------|-------------|-------------|
| MT5 Built-in | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | None |
| OANDA | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | None (with account) |
| Alpha Vantage | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 5/min, 500/day |
| Twelve Data | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 800/day |
| Polygon.io | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | 5/min |
| Finnhub | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 60/min |

## Notes

- **MT5 data is usually sufficient** for most backtesting needs
- **External APIs** are useful for:
  - Data validation
  - Additional symbols not available from broker
  - Alternative data sources
  - Long-term historical data (10+ years)
- **Rate limits** apply to free tiers - implement throttling
- **API keys** are free but require registration
- **Terms of service** vary - check each provider's TOS

---

**Related:** [BACKTESTING.md](BACKTESTING.md)

