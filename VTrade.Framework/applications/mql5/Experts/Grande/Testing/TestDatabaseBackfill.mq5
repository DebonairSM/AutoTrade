//+------------------------------------------------------------------+
//| TestDatabaseBackfill.mq5                                         |
//| Copyright 2024, Grande Tech                                      |
//| Test Script for Database Historical Backfill Functionality      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property script_show_inputs

#include "..\Include\GrandeDatabaseManager.mqh"

input int InpBackfillDays = 30;  // Days to backfill
input bool InpShowProgress = true; // Show detailed progress

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("\n====================================");
    Print("DATABASE BACKFILL TEST");
    Print("====================================\n");
    
    // Create database manager
    CGrandeDatabaseManager* dbManager = new CGrandeDatabaseManager();
    
    if(dbManager == NULL)
    {
        Print("ERROR: Failed to create database manager");
        return;
    }
    
    // Initialize database
    if(!dbManager.Initialize("Data/GrandeTradingData.db", InpShowProgress))
    {
        Print("ERROR: Failed to initialize database");
        delete dbManager;
        return;
    }
    
    Print("[TEST] Database initialized successfully");
    
    // Get current data coverage
    string beforeStats = dbManager.GetDataCoverageStats(_Symbol);
    Print("\nBEFORE BACKFILL:");
    Print(beforeStats);
    
    // Check if recent data exists
    datetime yesterday = TimeCurrent() - (24 * 3600);
    bool hasRecentData = dbManager.HasHistoricalData(_Symbol, yesterday);
    
    Print("[TEST] Has data from yesterday: ", hasRecentData ? "YES" : "NO");
    
    // Perform backfill
    Print("\n[TEST] Starting backfill of last ", InpBackfillDays, " days...");
    
    uint startTime = GetTickCount();
    bool backfillResult = dbManager.BackfillRecentHistory(_Symbol, (int)Period(), InpBackfillDays);
    uint duration = GetTickCount() - startTime;
    
    if(backfillResult)
    {
        Print("[TEST] ✅ Backfill completed in ", duration, " ms");
        Print("[TEST] Note: 0 inserts with skipped duplicates means data already exists (success)");
    }
    else
    {
        Print("[TEST] ❌ Backfill failed - no data could be retrieved or processed");
    }
    
    // Get data coverage after backfill
    string afterStats = dbManager.GetDataCoverageStats(_Symbol);
    Print("\nAFTER BACKFILL:");
    Print(afterStats);
    
    // Verify data was actually inserted
    datetime cutoff = TimeCurrent() - (InpBackfillDays * 86400);
    bool hasHistoricalData = dbManager.HasHistoricalData(_Symbol, cutoff);
    
    Print("\n[TEST] Verification:");
    Print("[TEST] Has data from ", InpBackfillDays, " days ago: ", hasHistoricalData ? "YES ✅" : "NO ❌");
    
    // Test data retrieval
    int recordCount = dbManager.GetRecordCount("market_data");
    Print("[TEST] Total market_data records: ", recordCount);
    
    // Clean up
    dbManager.Close();
    delete dbManager;
    
    Print("\n====================================");
    Print("TEST COMPLETED");
    Print("====================================\n");
}

