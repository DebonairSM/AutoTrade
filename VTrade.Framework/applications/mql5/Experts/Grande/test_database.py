#!/usr/bin/env python3
"""
Grande Trading System - Database Test Script
Test database functionality and data integrity
"""

import sqlite3
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import os

def test_database_connection(db_path: str):
    """Test basic database connection and table existence"""
    print(f"Testing database connection: {db_path}")
    
    if not os.path.exists(db_path):
        print(f"ERROR: Database file not found: {db_path}")
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if tables exist
        tables = [
            'market_data', 'market_regimes', 'key_levels', 'trade_decisions',
            'sentiment_data', 'economic_events', 'performance_metrics', 'config_snapshots'
        ]
        
        print("\nChecking table existence:")
        for table in tables:
            cursor.execute(f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table}'")
            exists = cursor.fetchone() is not None
            print(f"  {table}: {'✓' if exists else '✗'}")
        
        conn.close()
        return True
        
    except sqlite3.Error as e:
        print(f"ERROR: Database connection failed: {e}")
        return False

def test_data_integrity(db_path: str):
    """Test data integrity and basic queries"""
    print(f"\nTesting data integrity: {db_path}")
    
    try:
        conn = sqlite3.connect(db_path)
        
        # Test market data
        try:
            df = pd.read_sql_query("SELECT COUNT(*) as count FROM market_data", conn)
            market_count = df['count'].iloc[0]
            print(f"Market data records: {market_count}")
            
            if market_count > 0:
                # Check for recent data
                df = pd.read_sql_query("""
                    SELECT MAX(timestamp) as latest, MIN(timestamp) as earliest 
                    FROM market_data
                """, conn)
                print(f"  Date range: {df['earliest'].iloc[0]} to {df['latest'].iloc[0]}")
                
                # Check for valid price data
                df = pd.read_sql_query("""
                    SELECT COUNT(*) as invalid_prices 
                    FROM market_data 
                    WHERE open_price <= 0 OR high_price <= 0 OR low_price <= 0 OR close_price <= 0
                """, conn)
                invalid_prices = df['invalid_prices'].iloc[0]
                print(f"  Invalid price records: {invalid_prices}")
                
        except Exception as e:
            print(f"  Market data test failed: {e}")
        
        # Test trade decisions
        try:
            df = pd.read_sql_query("SELECT COUNT(*) as count FROM trade_decisions", conn)
            trade_count = df['count'].iloc[0]
            print(f"Trade decision records: {trade_count}")
            
            if trade_count > 0:
                # Check outcomes
                df = pd.read_sql_query("""
                    SELECT outcome, COUNT(*) as count 
                    FROM trade_decisions 
                    WHERE outcome IS NOT NULL 
                    GROUP BY outcome
                """, conn)
                print("  Trade outcomes:")
                for _, row in df.iterrows():
                    print(f"    {row['outcome']}: {row['count']}")
                    
        except Exception as e:
            print(f"  Trade decisions test failed: {e}")
        
        # Test regime data
        try:
            df = pd.read_sql_query("SELECT COUNT(*) as count FROM market_regimes", conn)
            regime_count = df['count'].iloc[0]
            print(f"Regime detection records: {regime_count}")
            
            if regime_count > 0:
                # Check regime distribution
                df = pd.read_sql_query("""
                    SELECT regime, COUNT(*) as count 
                    FROM market_regimes 
                    GROUP BY regime
                """, conn)
                print("  Regime distribution:")
                for _, row in df.iterrows():
                    print(f"    {row['regime']}: {row['count']}")
                    
        except Exception as e:
            print(f"  Regime data test failed: {e}")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"ERROR: Data integrity test failed: {e}")
        return False

def test_performance(db_path: str):
    """Test database performance with sample queries"""
    print(f"\nTesting database performance: {db_path}")
    
    try:
        conn = sqlite3.connect(db_path)
        
        # Test query performance
        queries = [
            ("Market data count", "SELECT COUNT(*) FROM market_data"),
            ("Recent trades", "SELECT COUNT(*) FROM trade_decisions WHERE timestamp >= datetime('now', '-7 days')"),
            ("Regime transitions", "SELECT COUNT(*) FROM market_regimes WHERE timestamp >= datetime('now', '-7 days')"),
            ("Complex join", """
                SELECT COUNT(*) FROM market_data md
                LEFT JOIN trade_decisions td ON md.symbol = td.symbol 
                    AND ABS(julianday(md.timestamp) - julianday(td.timestamp)) < 0.001
            """)
        ]
        
        for name, query in queries:
            start_time = datetime.now()
            try:
                df = pd.read_sql_query(query, conn)
                end_time = datetime.now()
                duration = (end_time - start_time).total_seconds()
                result = df.iloc[0, 0] if len(df) > 0 else 0
                print(f"  {name}: {result} records ({duration:.3f}s)")
            except Exception as e:
                print(f"  {name}: Query failed - {e}")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"ERROR: Performance test failed: {e}")
        return False

def generate_test_report(db_path: str):
    """Generate a comprehensive test report"""
    print("="*60)
    print("GRANDE TRADING SYSTEM - DATABASE TEST REPORT")
    print("="*60)
    print(f"Database: {db_path}")
    print(f"Test Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    # Run tests
    connection_ok = test_database_connection(db_path)
    integrity_ok = test_data_integrity(db_path) if connection_ok else False
    performance_ok = test_performance(db_path) if connection_ok else False
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    print(f"Database Connection: {'✓ PASS' if connection_ok else '✗ FAIL'}")
    print(f"Data Integrity: {'✓ PASS' if integrity_ok else '✗ FAIL'}")
    print(f"Performance: {'✓ PASS' if performance_ok else '✗ FAIL'}")
    
    overall_status = "✓ ALL TESTS PASSED" if all([connection_ok, integrity_ok, performance_ok]) else "✗ SOME TESTS FAILED"
    print(f"\nOverall Status: {overall_status}")
    
    # Recommendations
    print("\n" + "="*60)
    print("RECOMMENDATIONS")
    print("="*60)
    
    if not connection_ok:
        print("- Check database file path and permissions")
        print("- Ensure Grande Trading System is running with database enabled")
        print("- Verify SQLite is properly installed")
    
    if not integrity_ok:
        print("- Check data collection settings in EA parameters")
        print("- Verify market data is being collected")
        print("- Check for data validation errors")
    
    if not performance_ok:
        print("- Consider database optimization (VACUUM)")
        print("- Check for missing indexes")
        print("- Monitor database file size")
    
    if all([connection_ok, integrity_ok, performance_ok]):
        print("- Database is ready for AI analysis")
        print("- Consider running data export scripts")
        print("- Set up automated analysis workflows")

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Test Grande Trading System database')
    parser.add_argument('--db-path', default='GrandeTradingData.db', help='Path to database file')
    parser.add_argument('--quick', action='store_true', help='Run quick tests only')
    
    args = parser.parse_args()
    
    if args.quick:
        # Quick test - just connection
        test_database_connection(args.db_path)
    else:
        # Full test report
        generate_test_report(args.db_path)

if __name__ == "__main__":
    main()
