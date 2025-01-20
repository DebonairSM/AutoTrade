using System;
using System.IO;

namespace VTrade.Framework.Logging
{
    public static class VTradeLogger
    {
        private static string _logPath;
        private static readonly object _lockObj = new object();
        
        static VTradeLogger()
        {
            // Use the path from your mt5.config.json
            string terminalPath = @"C:\Users\Usuario\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075";
            string logsFolder = Path.Combine(terminalPath, "MQL5", "Files", "VTrade");
            
            Directory.CreateDirectory(logsFolder);
            _logPath = Path.Combine(logsFolder, $"vtrade_{DateTime.Now:yyyy-MM-dd}.log");
        }

        public static void LogInfo(string symbol, string message)
        {
            WriteLog("INFO", symbol, message);
        }

        public static void LogError(string symbol, string message, Exception? ex = null)
        {
            WriteLog("ERROR", symbol, message);
            if (ex != null)
            {
                WriteLog("ERROR", symbol, $"Exception: {ex.Message}");
                WriteLog("ERROR", symbol, $"Stack Trace: {ex.StackTrace}");
            }
        }

        public static void LogTrade(string symbol, string action, double price, double volume, double sl = 0, double tp = 0)
        {
            string message = $"TRADE [{action}] Price: {price:F5}, Volume: {volume:F2}";
            if (sl > 0) message += $", SL: {sl:F5}";
            if (tp > 0) message += $", TP: {tp:F5}";
            WriteLog("TRADE", symbol, message);
        }

        private static void WriteLog(string level, string symbol, string message)
        {
            try
            {
                lock (_lockObj)
                {
                    string logMessage = $"{DateTime.Now:yyyy.MM.dd HH:mm:ss.fff} | {level} | {symbol} | {message}";
                    File.AppendAllText(_logPath, logMessage + Environment.NewLine);
                }
            }
            catch
            {
                // Fallback to console if file write fails
                Console.WriteLine($"Failed to write to log file: {message}");
            }
        }
    }
} 