# Grande Trading System - Features Documentation

## System Overview
Grande Trading System is an MQL5 Expert Advisor that combines technical analysis with AI-powered economic calendar analysis using FinBERT sentiment models.

## Core Features

### 1. Multi-Timeframe Market Analysis

**Technical Indicators**
- ADX-based trend strength measurement across H1, H4, and D1 timeframes
- RSI momentum analysis with trend-aware logic
- ATR volatility tracking
- Support/resistance level detection (11-15 levels per analysis)

**Market Regime Detection**
- Identifies four market states: BULL TREND, BEAR TREND, RANGING, TRANSITION
- Confidence scoring for regime classification
- Multi-timeframe regime alignment checking

### 2. AI-Powered Economic Calendar Analysis

**FinBERT Integration Status** (Last Updated: 2025-10-09)
- **Active Functions**: 1 of 3 data feeds operational
- **Status**: PARTIALLY FUNCTIONAL
- File-based analysis mode (no Docker required)
- Python scripts: finbert_calendar_analyzer.py (ACTIVE), enhanced_finbert_analyzer.py (INACTIVE)

**Function 1: Economic Calendar Feed** (ACTIVE)
- Processes economic events from MT5 calendar every 15 minutes
- Generates sentiment-based trading signals (STRONG_BUY/BUY/NEUTRAL/SELL/STRONG_SELL)
- Provides confidence scores (0.0-1.0) for each prediction
- Impact weighting: Critical=1.0, High=0.8, Medium=0.4, Low=0.2
- Calculates normalized surprise: (actual - forecast) / baseline
- Output: integrated_calendar_analysis.json

**Function 2: Comprehensive Market Context Feed** (INACTIVE)
- Code exists but NOT INTEGRATED into main EA loop
- Would provide 6-factor multi-modal analysis:
  - Technical Trend (25%)
  - Market Regime (20%)
  - Key Levels (20%)
  - Economic Sentiment (15%)
  - Risk Assessment (10%)
  - FinBERT Sentiment (10%)
- Missing: SaveMarketContextToFile() not called, market_context_*.json not generated
- Enhanced analyzer ready but receives no data

**Function 3: Inline Fallback Analysis** (ACTIVE)
- Pure MQL5 keyword-based sentiment (no FinBERT model)
- Activates when Python scripts fail
- Basic signal/score/confidence generation

**Calendar Processing**
- 24-hour lookahead window for upcoming events
- Automatic refresh every 15 minutes (first run: 10 seconds after EA start)
- Exports to Common\Files\economic_events.json
- Smart currency filtering based on traded symbols

### 3. Triangle Pattern Detection

**Pattern Recognition**
- Ascending, descending, and symmetrical triangles
- Breakout confirmation logic
- Pattern validation across timeframes

### 4. Risk Management

**Position Management**
- Maximum 5% risk per trade
- Up to 7 concurrent positions allowed
- Automatic position sizing based on account equity
- Error 4203 handling with proper counter resets

**Trade Validation**
- Multi-layer signal validation
- Trend confirmation requirements with local override capability
- Volume and volatility checks
- Position blocking to prevent overtrading

### 5. Intelligent Trend Following

**Adaptive Logic**
- Local trend override: Strong H4 ADX (>35) or H1 ADX (>40) allows trades even without perfect multi-timeframe alignment
- RSI trend-aware filtering:
  - SHORT trades: Allowed when RSI > 20 and falling
  - LONG trades: Allowed when RSI < 80 and rising
- Prevents extreme counter-trend entries

### 6. Data Management & Export

**SQLite Database**
- Records all trading decisions and market conditions
- Stores historical analysis results
- Enables performance backtesting

**CSV Export**
- Daily trading logs per symbol (FinBERT_Data_SYMBOL_YYYY.MM.DD.csv)
- Includes technical indicators, regime data, and FinBERT signals
- Timestamped decision records

**Hourly Reports**
- Text-based summary reports (GrandeReport_SYMBOL_YYYYMMDD.txt)
- Market condition snapshots
- Position status and performance metrics

### 7. News Sentiment Integration

**File-Based Analysis**
- Reads from integrated_calendar_analysis.json
- Automatic loading of latest analysis during signal processing
- Fallback logic if analysis file is unavailable

**Economic Event Tracking**
- Event impact classification
- Timing-based signal weighting
- Historical event data for context

## Technical Architecture

### Analysis Pipeline

**Current Active Pipeline:**
```
MT5 Calendar (every 15 min)
         ↓
  economic_events.json
         ↓
  finbert_calendar_analyzer.py (Python)
         ↓
  integrated_calendar_analysis.json
         ↓
  MT5 Trading Engine
         ↓
  Trading Decisions + CSV/DB Logs
```

**Inactive Pipeline (Code Exists, Not Integrated):**
```
MT5 Technical Data
         ↓
  CreateComprehensiveMarketContext()
         ↓
  market_context_[timestamp].json (NOT GENERATED)
         ↓
  enhanced_finbert_analyzer.py (Python) (NOT RECEIVING DATA)
         ↓
  enhanced_finbert_analysis.json (NOT CREATED)
         ↓
  Enhanced Multi-Modal Trading Decisions (UNAVAILABLE)
```

### Key Components

**GrandeTradingSystem.mq5**
Main Expert Advisor that orchestrates all components

**GrandeMarketRegimeDetector.mqh**
Market state classification engine

**GrandeKeyLevelDetector.mqh**
Support and resistance level identification

**GrandeMT5CalendarReader.mqh**
Economic calendar data extraction from MT5

**GrandeNewsSentimentIntegration.mqh**
FinBERT analysis integration layer

**GrandeIntelligentReporter.mqh**
Data export and reporting system

**GrandeTrianglePatternDetector.mqh**
Triangle pattern recognition module

**GrandeTriangleTradingRules.mqh**
Pattern-based trade execution rules

**GrandeDatabaseManager.mqh**
SQLite database operations

## File Locations

### Analysis Input/Output
```
%APPDATA%\MetaQuotes\Terminal\Common\Files\
├── economic_events.json                    # Calendar data from MT5 (ACTIVE)
├── integrated_calendar_analysis.json       # FinBERT analysis results (ACTIVE)
├── market_context_[timestamp].json         # Market context data (NOT GENERATED)
├── enhanced_finbert_analysis.json          # Enhanced analysis results (NOT CREATED)
└── integrated_news_analysis.json           # News sentiment data (DISABLED)
```

### Trading Data
```
%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Files\
├── FinBERT_Data_EURUSD!_YYYY.MM.DD.csv    # Daily trading logs
├── GrandeReport_EURUSD!_YYYYMMDD.txt      # Hourly reports
└── GrandeTradingData.db                    # SQLite database
```

### Source Files
```
Grande/
├── GrandeTradingSystem.mq5                 # Main EA
├── GrandeMT5CalendarReader.mqh            # Calendar reader
├── GrandeNewsSentimentIntegration.mqh      # FinBERT integration
├── GrandeIntelligentReporter.mqh          # Reporting system
├── GrandeMarketRegimeDetector.mqh         # Regime detection
├── GrandeKeyLevelDetector.mqh             # Level detection
├── GrandeTrianglePatternDetector.mqh      # Pattern detection
├── GrandeTriangleTradingRules.mqh         # Pattern trading rules
└── GrandeDatabaseManager.mqh              # Database management
```

### Python Analysis
```
mcp/analyze_sentiment_server/
├── finbert_calendar_analyzer.py           # FinBERT calendar processor (ACTIVE)
├── enhanced_finbert_analyzer.py           # Multi-modal analyzer (READY, NO DATA)
└── GrandeNewsSentimentIntegration.mqh     # MQL5 integration layer
```

**FinBERT Data Feeds:**
1. **Economic Calendar Feed** (OPERATIONAL)
   - Input: economic_events.json
   - Output: integrated_calendar_analysis.json
   - Status: Fully functional, updates every 15 minutes

2. **Market Context Feed** (NOT INTEGRATED)
   - Input: market_context_[timestamp].json (not created)
   - Output: enhanced_finbert_analysis.json (not created)
   - Status: Code exists in GrandeTradingSystem.mq5 (lines 6382-6575) but SaveMarketContextToFile() not called

3. **Inline Fallback** (OPERATIONAL)
   - Pure MQL5 keyword analysis when Python fails
   - No FinBERT model, basic sentiment only

## Configuration

### Input Parameters

**Trading Settings**
- Symbol selection
- Timeframe selection (H1/H4/D1)
- Position size and risk limits
- Maximum concurrent positions

**Analysis Settings**
- ADX threshold levels
- RSI ranges for trend following
- Volatility multipliers
- Key level sensitivity

**FinBERT Settings**
- Confidence threshold for signal acceptance
- Event count for analysis
- Signal weighting factors

**Reporting Settings**
- Verbose logging toggle
- Report generation frequency
- CSV export options

## Build System

**GrandeBuild.ps1**
Automated build script that:
- Compiles MQL5 files
- Deploys to MT5 directories
- Creates Build folder with dependencies
- Handles multi-file compilation

**Usage**
```powershell
powershell -ExecutionPolicy Bypass -File "GrandeBuild.ps1"
```

## Data Outputs

### CSV Format
Each decision record includes:
- Timestamp
- Decision stage (PRE_SIGNAL_CHECK, EXECUTION, etc.)
- Action taken (BLOCKED, TRADE_ATTEMPT, etc.)
- Price and technical indicators
- Market regime and confidence
- ADX values across timeframes
- Volume and volatility metrics
- Key levels count
- FinBERT signal and confidence

### Report Format
Hourly summaries containing:
- Current market conditions
- Active positions
- Recent trading decisions
- System performance metrics
- FinBERT analysis status

### Database Schema
Tables for:
- Trading decisions
- Market regimes
- Economic events
- Position history
- Performance metrics

## Operating Modes

### Analysis Mode
- Monitors market conditions
- Logs decisions without trading
- Validates signals against all criteria
- Provides blocking reasons when trades rejected

### Live Trading Mode
- Full automated trading
- Real-time signal execution
- Position management
- Risk enforcement

### Report Generation
- Runs on timer (hourly)
- Exports current analysis state
- Updates CSV logs
- Database commits

## Signal Generation Process

1. **Market Analysis**: Collect H1/H4/D1 technical data
2. **Regime Detection**: Classify market state with confidence
3. **Level Detection**: Identify support/resistance zones
4. **Calendar Analysis**: Load FinBERT sentiment signal
5. **Pattern Detection**: Check for triangle formations
6. **Signal Validation**: Apply all trading rules
7. **Risk Check**: Verify position limits and exposure
8. **Execution Decision**: TRADE or BLOCK with reason
9. **Logging**: Record to CSV, database, and logs

## Integration Points

### MT5 Integration
- Native MQL5 calendar access
- Technical indicator calculations
- Position management functions
- File I/O for analysis data

### Python Integration
- File-based communication (JSON)
- No runtime dependencies on Python processes
- Async analysis updates via ShellExecuteW
- Cached results used until refresh
- Python execution: cmd /C python script.py
- Result polling: 20-30 attempts with 500ms sleep intervals

**Integration Status:**
- Calendar Analysis: ACTIVE (finbert_calendar_analyzer.py receives data)
- Enhanced Analysis: INACTIVE (enhanced_finbert_analyzer.py ready but no data feed)

**Missing Integration:**
- CollectEnhancedMarketDataForFinBERT() exists but may not be triggered
- SaveMarketContextToFile() defined but never called in main loop
- market_context_*.json files not generated
- 6-factor multi-modal analysis unavailable

### External Data
- Economic calendar from MT5 servers
- Price data from broker feed
- No external API dependencies
- FinBERT model: ProsusAI/finbert (local execution)

