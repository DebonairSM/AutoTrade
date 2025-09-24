#!/usr/bin/env python3
"""
Grande Trading System - AI Data Export Scripts
Exports data from SQLite database for machine learning analysis
"""

import sqlite3
import pandas as pd
import numpy as np
import json
from datetime import datetime, timedelta
import os
import argparse
from typing import Dict, List, Optional, Tuple
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class GrandeDataExporter:
    """Main class for exporting Grande Trading System data for AI analysis"""
    
    def __init__(self, db_path: str):
        """
        Initialize the data exporter
        
        Args:
            db_path: Path to the SQLite database file
        """
        self.db_path = db_path
        self.conn = None
        self._connect()
    
    def _connect(self):
        """Connect to the database"""
        try:
            self.conn = sqlite3.connect(self.db_path)
            self.conn.row_factory = sqlite3.Row  # Enable column access by name
            logger.info(f"Connected to database: {self.db_path}")
        except sqlite3.Error as e:
            logger.error(f"Error connecting to database: {e}")
            raise
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")
    
    def export_training_data(self, symbol: str, days_back: int = 30) -> pd.DataFrame:
        """
        Export comprehensive training data for ML models
        
        Args:
            symbol: Trading symbol (e.g., 'EURUSD')
            days_back: Number of days to look back
            
        Returns:
            DataFrame with market data, indicators, and trade outcomes
        """
        query = """
        SELECT 
            md.*,
            td.decision,
            td.outcome,
            td.pnl,
            td.duration_minutes,
            td.signal_type,
            td.rejection_reason,
            sr.signal as sentiment_signal,
            sr.score as sentiment_score,
            sr.confidence as sentiment_confidence,
            mr.regime,
            mr.confidence as regime_confidence,
            mr.volatility_level
        FROM market_data md
        LEFT JOIN trade_decisions td ON md.symbol = td.symbol 
            AND ABS(julianday(md.timestamp) - julianday(td.timestamp)) < 0.001
        LEFT JOIN sentiment_data sr ON md.symbol = sr.symbol 
            AND ABS(julianday(md.timestamp) - julianday(sr.timestamp)) < 0.001
        LEFT JOIN market_regimes mr ON md.symbol = mr.symbol 
            AND ABS(julianday(md.timestamp) - julianday(mr.timestamp)) < 0.001
        WHERE md.symbol = ? 
            AND md.timestamp >= datetime('now', '-{} days')
        ORDER BY md.timestamp
        """.format(days_back)
        
        try:
            df = pd.read_sql_query(query, self.conn, params=(symbol,))
            logger.info(f"Exported {len(df)} records for training data")
            return df
        except Exception as e:
            logger.error(f"Error exporting training data: {e}")
            return pd.DataFrame()
    
    def export_performance_analysis(self, symbol: str) -> pd.DataFrame:
        """
        Export trade performance data for analysis
        
        Args:
            symbol: Trading symbol
            
        Returns:
            DataFrame with trade performance metrics
        """
        query = """
        SELECT 
            *,
            CASE 
                WHEN outcome = 'PROFIT' THEN 1
                WHEN outcome = 'LOSS' THEN 0
                ELSE NULL
            END as is_profitable,
            CASE 
                WHEN pnl > 0 THEN 1
                WHEN pnl < 0 THEN 0
                ELSE NULL
            END as is_positive_pnl
        FROM trade_decisions 
        WHERE symbol = ? 
            AND outcome IS NOT NULL
            AND pnl IS NOT NULL
        ORDER BY timestamp
        """
        
        try:
            df = pd.read_sql_query(query, self.conn, params=(symbol,))
            logger.info(f"Exported {len(df)} trade records for performance analysis")
            return df
        except Exception as e:
            logger.error(f"Error exporting performance data: {e}")
            return pd.DataFrame()
    
    def export_regime_analysis(self, symbol: str) -> pd.DataFrame:
        """
        Export market regime data for pattern analysis
        
        Args:
            symbol: Trading symbol
            
        Returns:
            DataFrame with regime detection data
        """
        query = """
        SELECT 
            *,
            LAG(regime) OVER (ORDER BY timestamp) as previous_regime,
            LAG(confidence) OVER (ORDER BY timestamp) as previous_confidence,
            julianday(timestamp) - julianday(LAG(timestamp) OVER (ORDER BY timestamp)) as regime_duration_days
        FROM market_regimes 
        WHERE symbol = ? 
        ORDER BY timestamp
        """
        
        try:
            df = pd.read_sql_query(query, self.conn, params=(symbol,))
            logger.info(f"Exported {len(df)} regime records for analysis")
            return df
        except Exception as e:
            logger.error(f"Error exporting regime data: {e}")
            return pd.DataFrame()
    
    def export_key_level_analysis(self, symbol: str) -> pd.DataFrame:
        """
        Export key level data for effectiveness analysis
        
        Args:
            symbol: Trading symbol
            
        Returns:
            DataFrame with key level data
        """
        query = """
        SELECT 
            *,
            CASE 
                WHEN level_type = 'SUPPORT' THEN 1
                WHEN level_type = 'RESISTANCE' THEN -1
                ELSE 0
            END as level_direction
        FROM key_levels 
        WHERE symbol = ? 
        ORDER BY timestamp
        """
        
        try:
            df = pd.read_sql_query(query, self.conn, params=(symbol,))
            logger.info(f"Exported {len(df)} key level records for analysis")
            return df
        except Exception as e:
            logger.error(f"Error exporting key level data: {e}")
            return pd.DataFrame()
    
    def export_sentiment_analysis(self, symbol: str) -> pd.DataFrame:
        """
        Export sentiment data for correlation analysis
        
        Args:
            symbol: Trading symbol
            
        Returns:
            DataFrame with sentiment data
        """
        query = """
        SELECT 
            *,
            CASE 
                WHEN signal = 'STRONG_BUY' THEN 1.0
                WHEN signal = 'BUY' THEN 0.5
                WHEN signal = 'NEUTRAL' THEN 0.0
                WHEN signal = 'SELL' THEN -0.5
                WHEN signal = 'STRONG_SELL' THEN -1.0
                ELSE 0.0
            END as signal_numeric
        FROM sentiment_data 
        WHERE symbol = ? 
        ORDER BY timestamp
        """
        
        try:
            df = pd.read_sql_query(query, self.conn, params=(symbol,))
            logger.info(f"Exported {len(df)} sentiment records for analysis")
            return df
        except Exception as e:
            logger.error(f"Error exporting sentiment data: {e}")
            return pd.DataFrame()
    
    def export_economic_events(self, days_back: int = 30) -> pd.DataFrame:
        """
        Export economic calendar events
        
        Args:
            days_back: Number of days to look back
            
        Returns:
            DataFrame with economic events
        """
        query = """
        SELECT 
            *,
            CASE 
                WHEN actual_value > forecast_value THEN 1
                WHEN actual_value < forecast_value THEN -1
                ELSE 0
            END as surprise_direction,
            ABS(actual_value - forecast_value) / NULLIF(ABS(forecast_value), 0) as surprise_magnitude_pct
        FROM economic_events 
        WHERE timestamp >= datetime('now', '-{} days')
        ORDER BY timestamp
        """.format(days_back)
        
        try:
            df = pd.read_sql_query(query, self.conn)
            logger.info(f"Exported {len(df)} economic events for analysis")
            return df
        except Exception as e:
            logger.error(f"Error exporting economic events: {e}")
            return pd.DataFrame()
    
    def export_performance_metrics(self, symbol: str) -> pd.DataFrame:
        """
        Export performance metrics
        
        Args:
            symbol: Trading symbol
            
        Returns:
            DataFrame with performance metrics
        """
        query = """
        SELECT * FROM performance_metrics 
        WHERE symbol = ? 
        ORDER BY timestamp
        """
        
        try:
            df = pd.read_sql_query(query, self.conn, params=(symbol,))
            logger.info(f"Exported {len(df)} performance metric records")
            return df
        except Exception as e:
            logger.error(f"Error exporting performance metrics: {e}")
            return pd.DataFrame()
    
    def get_database_summary(self) -> Dict:
        """
        Get summary statistics of the database
        
        Returns:
            Dictionary with database summary
        """
        tables = [
            'market_data', 'market_regimes', 'key_levels', 'trade_decisions',
            'sentiment_data', 'economic_events', 'performance_metrics', 'config_snapshots'
        ]
        
        summary = {}
        for table in tables:
            try:
                query = f"SELECT COUNT(*) as count FROM {table}"
                result = self.conn.execute(query).fetchone()
                summary[table] = result['count'] if result else 0
            except sqlite3.Error:
                summary[table] = 0
        
        # Get date range
        try:
            query = "SELECT MIN(timestamp) as min_date, MAX(timestamp) as max_date FROM market_data"
            result = self.conn.execute(query).fetchone()
            summary['date_range'] = {
                'start': result['min_date'] if result['min_date'] else None,
                'end': result['max_date'] if result['max_date'] else None
            }
        except sqlite3.Error:
            summary['date_range'] = {'start': None, 'end': None}
        
        return summary
    
    def export_all_data(self, symbol: str, output_dir: str = "ai_data_export") -> Dict[str, str]:
        """
        Export all data types to CSV files
        
        Args:
            symbol: Trading symbol
            output_dir: Output directory for CSV files
            
        Returns:
            Dictionary mapping data type to file path
        """
        os.makedirs(output_dir, exist_ok=True)
        
        exports = {}
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Export different data types
        data_exporters = [
            ('training_data', lambda: self.export_training_data(symbol)),
            ('performance_analysis', lambda: self.export_performance_analysis(symbol)),
            ('regime_analysis', lambda: self.export_regime_analysis(symbol)),
            ('key_level_analysis', lambda: self.export_key_level_analysis(symbol)),
            ('sentiment_analysis', lambda: self.export_sentiment_analysis(symbol)),
            ('economic_events', lambda: self.export_economic_events()),
            ('performance_metrics', lambda: self.export_performance_metrics(symbol))
        ]
        
        for data_type, exporter_func in data_exporters:
            try:
                df = exporter_func()
                if not df.empty:
                    filename = f"{symbol}_{data_type}_{timestamp}.csv"
                    filepath = os.path.join(output_dir, filename)
                    df.to_csv(filepath, index=False)
                    exports[data_type] = filepath
                    logger.info(f"Exported {data_type} to {filepath}")
                else:
                    logger.warning(f"No data found for {data_type}")
            except Exception as e:
                logger.error(f"Error exporting {data_type}: {e}")
        
        # Export database summary
        summary = self.get_database_summary()
        summary_file = os.path.join(output_dir, f"{symbol}_database_summary_{timestamp}.json")
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2, default=str)
        exports['database_summary'] = summary_file
        
        return exports

def main():
    """Main function for command-line usage"""
    parser = argparse.ArgumentParser(description='Export Grande Trading System data for AI analysis')
    parser.add_argument('--db-path', default='GrandeTradingData.db', help='Path to SQLite database')
    parser.add_argument('--symbol', default='EURUSD', help='Trading symbol to analyze')
    parser.add_argument('--days-back', type=int, default=30, help='Days to look back')
    parser.add_argument('--output-dir', default='ai_data_export', help='Output directory')
    parser.add_argument('--data-type', choices=[
        'training', 'performance', 'regime', 'key_levels', 'sentiment', 
        'economic', 'metrics', 'all'
    ], default='all', help='Type of data to export')
    
    args = parser.parse_args()
    
    # Initialize exporter
    exporter = GrandeDataExporter(args.db_path)
    
    try:
        if args.data_type == 'all':
            # Export all data types
            exports = exporter.export_all_data(args.symbol, args.output_dir)
            print(f"Exported {len(exports)} data files:")
            for data_type, filepath in exports.items():
                print(f"  {data_type}: {filepath}")
        else:
            # Export specific data type
            if args.data_type == 'training':
                df = exporter.export_training_data(args.symbol, args.days_back)
            elif args.data_type == 'performance':
                df = exporter.export_performance_analysis(args.symbol)
            elif args.data_type == 'regime':
                df = exporter.export_regime_analysis(args.symbol)
            elif args.data_type == 'key_levels':
                df = exporter.export_key_level_analysis(args.symbol)
            elif args.data_type == 'sentiment':
                df = exporter.export_sentiment_analysis(args.symbol)
            elif args.data_type == 'economic':
                df = exporter.export_economic_events(args.days_back)
            elif args.data_type == 'metrics':
                df = exporter.export_performance_metrics(args.symbol)
            
            if not df.empty:
                filename = f"{args.symbol}_{args.data_type}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
                filepath = os.path.join(args.output_dir, filename)
                os.makedirs(args.output_dir, exist_ok=True)
                df.to_csv(filepath, index=False)
                print(f"Exported {len(df)} records to {filepath}")
            else:
                print(f"No data found for {args.data_type}")
    
    finally:
        exporter.close()

if __name__ == "__main__":
    main()
