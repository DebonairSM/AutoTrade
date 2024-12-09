#property strict
#property copyright "VSol Software"
#property link      "http://www.vsol.software"
#property version   "1.00"
#property script_show_inputs

// -----------------------------------------------------------------------------
// User-Configurable Parameters
// -----------------------------------------------------------------------------

// Name of the template file (without path) stored in MQL5\Profiles\Templates.
// This template should already have your EA attached and configured.
input string TemplateName = "quantum_trends_ea.tpl";

// Desired timeframe for the new charts
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H4;

// Method of selecting symbols:
// - Set UseMarketWatchSymbols to "true" to load all symbols currently in Market Watch
// - Set UseMarketWatchSymbols to "false" to use the static symbols listed in the CustomSymbols array below
input bool UseMarketWatchSymbols = true;

// Define a custom list of symbols if not using Market Watch
string CustomSymbols[] = {"EURUSD","GBPUSD","USDJPY","XAUUSD"};

// -----------------------------------------------------------------------------
// OnStart: Script execution entry point
// -----------------------------------------------------------------------------
void OnStart()
{
   // Determine which symbols to use
   string symbols[];
   if(UseMarketWatchSymbols)
   {
      int total = SymbolsTotal(true);
      if(total <= 0)
      {
         Print("No symbols found in Market Watch.");
         return;
      }
      ArrayResize(symbols, total);
      for(int i=0; i<total; i++)
         symbols[i] = SymbolName(i, true);
   }
   else
   {
      if(ArraySize(CustomSymbols) == 0)
      {
         Print("No symbols provided in CustomSymbols array.");
         return;
      }
      symbols = CustomSymbols;
   }
   
   // Check if the template file is accessible
   if(!FileIsExist(TemplateFilePath(TemplateName)))
   {
      PrintFormat("Template file '%s' not found in Profiles\\Templates folder.", TemplateName);
      return;
   }

   // Iterate over symbols and create charts
   for(int i=0; i<ArraySize(symbols); i++)
   {
      string sym = symbols[i];
      
      // Attempt to open a chart for the symbol
      long chart_id = ChartOpen(sym, TimeFrame);
      if(chart_id <= 0)
      {
         PrintFormat("Failed to open chart for symbol: %s", sym);
         continue;
      }

      // Attempt to apply the template with the EA
      bool result = ChartApplyTemplate(chart_id, TemplateName);
      if(!result)
      {
         PrintFormat("Failed to apply template '%s' to chart of symbol: %s", TemplateName, sym);
      }
      else
      {
         PrintFormat("Successfully opened and configured EA on %s chart.", sym);
      }

      // Optionally, you can adjust the chart window properties:
      // For example, switch to another timeframe or shift chart:
      // ChartSetSymbolPeriod(chart_id, sym, TimeFrame);
   }

   Print("Script execution completed. Check opened charts for EA configuration.");
}

// -----------------------------------------------------------------------------
// Utility: Construct full path to template file
// -----------------------------------------------------------------------------
string TemplateFilePath(string template_name)
{
   // Construct full path to the template file in the Templates folder
   return TerminalInfoString(TERMINAL_DATA_PATH) + "\\Profiles\\Templates\\" + template_name;
}
