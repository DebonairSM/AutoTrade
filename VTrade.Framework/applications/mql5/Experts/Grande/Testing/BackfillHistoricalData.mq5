//+------------------------------------------------------------------+
//| BackfillHistoricalData.mq5                                      |
//| Copyright 2025, Grande Tech                                     |
//| Purpose: Backfill years of historical data for backtesting      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Grande Tech"
#property link      ""
#property version   "1.00"
#property script_show_inputs

#include "..\..\Experts\Grande\Include\GrandeDatabaseManager.mqh"

//--- Input parameters
input group "=== Backfill Configuration ==="
input int    InpBackfillYears = 5;           // Years of historical data to backfill
input string InpSymbol = "";                 // Symbol (empty = current chart symbol)
input int    InpTimeframe = PERIOD_H1;       // Timeframe to backfill
input bool   InpShowProgress = true;         // Show progress updates
input bool   InpBackfillMultipleTimeframes = false; // Backfill H1, H4, D1
input bool   InpCreateBackup = true;         // Create backup before backfill

//--- Global variables
CGrandeDatabaseManager* g_dbManager = NULL;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("\n====================================");
    Print("HISTORICAL DATA BACKFILL");
    Print("====================================\n");
    
    string symbol = (InpSymbol == "") ? _Symbol : InpSymbol;
    
    Print("[BACKFILL] Symbol: ", symbol);
    Print("[BACKFILL] Timeframe: ", EnumToString((ENUM_TIMEFRAMES)InpTimeframe));
    Print("[BACKFILL] Years: ", InpBackfillYears);
    Print("");
    
    // Database path
    string dbPath = "Data/GrandeTradingData.db";
    
    // Check if database file exists and is accessible
    if(FileIsExist(dbPath))
    {
        Print("[BACKFILL] Database file exists: ", dbPath);
        
        // Try to open database to check if it's locked
        int testHandle = DatabaseOpen(dbPath, DATABASE_OPEN_READONLY);
        if(testHandle == INVALID_HANDLE)
        {
            Print("[BACKFILL] ERROR: Database is locked or inaccessible. Please close any other applications using the database.");
            Print("[BACKFILL] Error code: ", GetLastError());
            return;
        }
        DatabaseClose(testHandle);
        Print("[BACKFILL] Database is accessible (not locked)");
    }
    else
    {
        Print("[BACKFILL] Database file does not exist - will be created: ", dbPath);
    }
    
    // Create backup if requested and database exists
    if(InpCreateBackup && FileIsExist(dbPath))
    {
        Print("\n[BACKFILL] Creating database backup...");
        
        // Generate backup filename with timestamp
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        string backupPath = StringFormat("Data/GrandeTradingData_backup_%04d%02d%02d_%02d%02d%02d.db",
                                         dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
        
        // Create database manager temporarily for backup
        CGrandeDatabaseManager* tempManager = new CGrandeDatabaseManager();
        if(tempManager != NULL)
        {
            if(tempManager.Initialize(dbPath, false))
            {
                if(tempManager.BackupDatabase(backupPath))
                {
                    Print("[BACKFILL] ✅ Backup created: ", backupPath);
                }
                else
                {
                    Print("[BACKFILL] ⚠️  WARNING: Backup failed, but continuing with backfill");
                }
                delete tempManager;
            }
            else
            {
                Print("[BACKFILL] ⚠️  WARNING: Could not initialize database for backup, but continuing");
                delete tempManager;
            }
        }
        Print("");
    }
    
    // Create database manager
    g_dbManager = new CGrandeDatabaseManager();
    if(g_dbManager == NULL)
    {
        Print("ERROR: Failed to create database manager");
        return;
    }
    
    // Initialize database
    if(!g_dbManager.Initialize(dbPath, InpShowProgress))
    {
        Print("ERROR: Failed to initialize database");
        delete g_dbManager;
        return;
    }
    
    Print("[BACKFILL] Database initialized: ", dbPath);
    
    // Calculate date range
    datetime endDate = TimeCurrent();
    datetime startDate = endDate - (InpBackfillYears * 365 * 24 * 3600);
    
    Print("[BACKFILL] Date range: ", TimeToString(startDate, TIME_DATE), " to ", TimeToString(endDate, TIME_DATE));
    Print("");
    
    // Backfill data
    if(InpBackfillMultipleTimeframes)
    {
        // Backfill multiple timeframes
        int timeframes[] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
        string tfNames[] = {"H1", "H4", "D1"};
        
        for(int i = 0; i < ArraySize(timeframes); i++)
        {
            Print("[BACKFILL] ========================================");
            Print("[BACKFILL] Backfilling ", tfNames[i], " data...");
            Print("[BACKFILL] ========================================");
            
            uint startTime = GetTickCount();
            bool result = g_dbManager.BackfillHistoricalData(symbol, timeframes[i], startDate, endDate);
            uint duration = GetTickCount() - startTime;
            
            if(result)
            {
                Print("[BACKFILL] ✅ ", tfNames[i], " backfill completed in ", duration, " ms");
            }
            else
            {
                Print("[BACKFILL] ❌ ", tfNames[i], " backfill failed");
            }
            Print("");
        }
    }
    else
    {
        // Backfill single timeframe
        Print("[BACKFILL] Starting backfill...");
        uint startTime = GetTickCount();
        bool result = g_dbManager.BackfillHistoricalData(symbol, InpTimeframe, startDate, endDate);
        uint duration = GetTickCount() - startTime;
        
        if(result)
        {
            Print("[BACKFILL] ✅ Backfill completed in ", duration, " ms");
        }
        else
        {
            Print("[BACKFILL] ❌ Backfill failed");
        }
    }
    
    // Show data coverage stats
    Print("\n[BACKFILL] ========================================");
    Print("[BACKFILL] DATA COVERAGE STATISTICS");
    Print("[BACKFILL] ========================================");
    string stats = g_dbManager.GetDataCoverageStats(symbol);
    Print(stats);
    
    // Cleanup
    delete g_dbManager;
    
    Print("\n[BACKFILL] ========================================");
    Print("[BACKFILL] BACKFILL COMPLETE");
    Print("[BACKFILL] ========================================");
}

//+------------------------------------------------------------------+

