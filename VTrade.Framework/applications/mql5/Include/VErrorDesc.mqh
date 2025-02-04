//+------------------------------------------------------------------+
//|                                                   VErrorDesc.mqh |
//|                                  Custom Error Description Handler |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Returns description of an MQL5 error code                          |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code)
{
    switch(error_code)
    {
        // Common Trading Errors
        case 4756: return "Invalid trade volume or broker restrictions";
        case 4752: return "Requote - requested price is no longer valid";
        case 4753: return "Invalid trade request";
        case 4754: return "Trade request sent too frequently";
        case 4755: return "Invalid trade parameters";
        case 4758: return "Connection with trading server lost";
        case 4759: return "Trade operation not allowed";
        case 4760: return "Too many trade requests";
        
        // Order Errors
        case 4751: return "Invalid order type";
        case 4750: return "Invalid order filling type";
        case 4757: return "Position already exists";
        case 4761: return "Limit orders not allowed";
        case 4762: return "Stop orders not allowed";
        case 4763: return "Position not found";
        case 4764: return "Order not found";
        case 4765: return "Trade function is locked";
        case 4766: return "Not enough money for trade operation";
        
        // Chart Object Errors
        case 4200: return "Object already exists";
        case 4201: return "Unknown object property";
        case 4202: return "Object does not exist";
        case 4203: return "Unknown object type";
        case 4204: return "No object name";
        case 4205: return "Object coordinates error";
        case 4206: return "No specified subwindow";
        case 4207: return "Graphical object error";
        
        // Custom Indicator Errors
        case 4301: return "Invalid number of indicator buffers";
        case 4302: return "Invalid indicator handle";
        case 4303: return "Custom indicator error";
        
        // Array Errors
        case 4001: return "Array index out of range";
        case 4002: return "Array size too small";
        case 4003: return "No memory for array";
        case 4004: return "Invalid array size";
        case 4005: return "String size must be specified";
        case 4006: return "Array dimension mismatch";
        case 4007: return "Invalid datetime";
        
        // File Operation Errors
        case 5001: return "Too many opened files";
        case 5002: return "Invalid file name";
        case 5003: return "Too long file name";
        case 5004: return "Cannot open file";
        case 5005: return "Text file buffer allocation error";
        case 5006: return "Cannot delete file";
        case 5007: return "Invalid file handle";
        case 5008: return "File must be opened with FILE_WRITE flag";
        case 5009: return "File must be opened with FILE_READ flag";
        case 5010: return "File must be opened with FILE_BIN flag";
        case 5011: return "File must be opened with FILE_TXT flag";
        
        // String Conversion Errors
        case 4104: return "String size must be specified";
        case 4105: return "String contains invalid characters";
        case 4106: return "String conversion error";
        case 4107: return "String structure error";
        
        // Common Runtime Errors
        case 4101: return "Invalid function parameter";
        case 4102: return "Invalid command";
        case 4103: return "Not enough memory";
        case 4108: return "Not initialized variable";
        case 4109: return "Not initialized structure";
        case 4110: return "No active functions";
        case 4111: return "Invalid parameter count";
        case 4112: return "Parameter invalid type";
        case 4113: return "Function not allowed";
        case 4114: return "String parameter expected";
        case 4115: return "Integer parameter expected";
        case 4116: return "Double parameter expected";
        case 4117: return "Array as parameter expected";
        case 4118: return "Requested history data in updating state";
        case 4119: return "Trade error";
        
        // Market Info Errors
        case 4501: return "Unknown symbol";
        case 4502: return "Invalid price";
        case 4503: return "Invalid ticket";
        case 4504: return "Trade is not allowed";
        case 4505: return "Market is closed";
        case 4506: return "No connection with trade server";
        case 4507: return "Not enough rights";
        case 4508: return "Too frequent requests";
        case 4509: return "Malfunctional trade operation";
        case 4510: return "Only close allowed";
        case 4511: return "Limit orders not allowed";
        case 4512: return "Stop orders not allowed";
        
        // Default Case
        default: return StringFormat("Unknown error (%d)", error_code);
    }
} 