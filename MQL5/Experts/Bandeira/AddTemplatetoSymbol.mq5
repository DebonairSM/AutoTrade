#property strict
#property copyright "VSol Software"
#property link      "http://www.vsol.software"
#property version   "1.01"
#property script_show_inputs

// -----------------------------------------------------------------------------
// User-Configurable Parameters
// -----------------------------------------------------------------------------
input string TemplateName = "quantum_trends_ea.tpl";  // EA template filename

// -----------------------------------------------------------------------------
// OnStart: Script execution entry point
// -----------------------------------------------------------------------------
void OnStart()
{
   // Get current chart symbol and timeframe
   string currentSymbol = Symbol();
   ENUM_TIMEFRAMES currentTimeframe = Period();
   
   Print("Applying template to current chart: ", currentSymbol);

   // Check if the template file is accessible and apply it
   string templatePath = TemplateFilePath(TemplateName);
   if(!ChartApplyTemplate(0, templatePath))
   {
      PrintFormat("Failed to apply template '%s' to the current chart. Error: %d", TemplateName, GetLastError());
      PrintFormat("Please verify that '%s' exists in MQL5\\Profiles\\Templates\\ and is accessible.", TemplateName);
      Print("Try manually applying the template to confirm it works.");
      return;
   }

   PrintFormat("Successfully applied template to %s chart.", currentSymbol);
   Print("Script execution completed.");
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