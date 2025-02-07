#property strict
#property copyright "VSol Software"
#property link      "http://www.vsol.software"
#property version   "1.01"
#property script_show_inputs

// -----------------------------------------------------------------------------
// User-Configurable Parameters
// -----------------------------------------------------------------------------
input string TemplateName      = "quantum_trends_ea.tpl";  // EA template filename
input ENUM_TIMEFRAMES TimeFrame = PERIOD_H4;               // Desired timeframe

// Method of selecting symbols:
// - UseMarketWatchSymbols = true: load all symbols currently in Market Watch
// - UseMarketWatchSymbols = false: use the static symbols listed below
input bool UseMarketWatchSymbols = false;
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
         Print("No symbols found in Market Watch. Please ensure symbols are visible.");
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

      ArrayResize(symbols, ArraySize(CustomSymbols));
      ArrayCopy(symbols, CustomSymbols);
   }

   // Print out the symbols we are about to process
   Print("Symbols to process:");
   for(int i=0; i<ArraySize(symbols); i++)
      Print(" - ", symbols[i]);

   // Check if the template file is accessible by attempting to apply it to the current chart
   string templatePath = TemplateFilePath(TemplateName);
   if(!ChartApplyTemplate(0, templatePath))
   {
      PrintFormat("Failed to apply template '%s' even on the current chart. Error: %d", TemplateName, GetLastError());
      PrintFormat("Please verify that '%s' exists in MQL5\\Profiles\\Templates\\ and is accessible.", TemplateName);
      Print("Try manually applying the template to an open chart to confirm it works.");
      return;
   }

   // Now iterate over each symbol
   for(int i=0; i<ArraySize(symbols); i++)
   {
      string sym = symbols[i];
      
      // Verify the symbol can be selected and is visible in Market Watch
      if(!SymbolSelect(sym, true))
      {
         PrintFormat("Could not select symbol %s in Market Watch. Error: %d", sym, GetLastError());
         continue;
      }

      // Check if the symbol has valid market data
      MqlTick tick;
      if(!SymbolInfoTick(sym, tick))
      {
         PrintFormat("No market data available for symbol: %s. Cannot open chart.", sym);
         continue;
      }

      // Add a delay to ensure the platform has processed symbol selection
      Sleep(2000); // Increased delay to 2 seconds

      // Attempt to open a chart for the symbol
      long chart_id = ChartOpen(sym, TimeFrame);
      if(chart_id <= 0)
      {
         int error = GetLastError();
         PrintFormat("Failed to open chart for symbol: %s (Error: %d).", sym, error);
         Print("Check if this symbol is offered by your broker and can be opened manually.");
         continue;
      }

      // Give some additional time for the chart to initialize
      ChartRedraw(chart_id);
      Sleep(1000); // Increased delay to 1 second

      // Attempt to apply the template
      bool result = ChartApplyTemplate(chart_id, TemplateName);
      if(!result)
      {
         int tmplError = GetLastError();
         PrintFormat("Failed to apply template '%s' to chart of symbol: %s (Error: %d).",
                     TemplateName, sym, tmplError);
         Print("Ensure the template is valid and the EA can run on this symbol.");
         ChartClose(chart_id);
      }
      else
      {
         PrintFormat("Successfully opened and configured EA on %s chart.", sym);
      }
   }

   Print("Script execution completed. Check opened charts for EA configuration.");
}

// -----------------------------------------------------------------------------
// Utility: Construct full path to template file and test accessibility
// -----------------------------------------------------------------------------
string TemplateFilePath(string template_name)
{
   // First try with the direct name
   if(ChartApplyTemplate(0, template_name))
   {
      PrintFormat("Successfully applied template using direct name: %s", template_name);
      return template_name;
   }

   // Then try with relative path
   string relative_path = "\\Profiles\\Templates\\" + template_name;
   if(ChartApplyTemplate(0, relative_path))
   {
      PrintFormat("Successfully applied template using relative path: %s", relative_path);
      return relative_path;
   }

   // Finally, try with the full path
   string full_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Profiles\\Templates\\" + template_name;
   PrintFormat("Attempting template application with full path: %s", full_path);

   return full_path;
}
