void ClosePartialPositions()
{
    int closedCount = 0;
    int total = PositionsTotal();
    
    for(int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket != 0 && PositionSelectByTicket(ticket))
        {
            // Check if the position is ours (using MagicNumber)
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(magic == MagicNumber)
            {
                // Close only two positions
                if(closedCount < 2)
                {
                    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                    string symbol = PositionGetString(POSITION_SYMBOL);
                    
                    if(trade.PositionClose(ticket))
                    {
                        Print("Closed position #", ticket, " successfully.");
                        closedCount++;
                    }
                    else
                    {
                        Print("Failed to close position #", ticket, ". Error: ", GetLastError());
                    }
                }
                else
                {
                    // Leave the third position open
                    break;
                }
            }
        }
    }
    
    if(closedCount == 2)
        Print("Successfully closed two positions.");
    else
        Print("Could not close two positions. Closed ", closedCount, " positions.");
}

//+------------------------------------------------------------------+
//| Close all open positions of a specific type                      |
//+------------------------------------------------------------------+
bool CloseAllPositions(ENUM_ORDER_TYPE orderType)
{
    bool allClosed = true;
    int total = PositionsTotal();
    
    for(int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket != 0 && PositionSelectByTicket(ticket))
        {
            // Check if the position is ours (using MagicNumber)
            long magic = PositionGetInteger(POSITION_MAGIC);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Convert ORDER_TYPE to POSITION_TYPE for comparison
            ENUM_POSITION_TYPE compareType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            
            if(magic == MagicNumber && posType == compareType)
            {
                if(trade.PositionClose(ticket))
                {
                    Print("Closed position #", ticket, " successfully.");
                }
                else
                {
                    Print("Failed to close position #", ticket, ". Error: ", GetLastError());
                    allClosed = false;
                }
            }
        }
    }
    return allClosed;
}

//+------------------------------------------------------------------+
//| Check if there are any open positions of a specific type         |
//+------------------------------------------------------------------+
bool HasOpenPositions(ENUM_ORDER_TYPE orderType)
{
    int total = PositionsTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket != 0 && PositionSelectByTicket(ticket))
        {
            long magic = PositionGetInteger(POSITION_MAGIC);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Convert ORDER_TYPE to POSITION_TYPE for comparison
            ENUM_POSITION_TYPE compareType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            
            if(magic == MagicNumber && posType == compareType)
                return true;
        }
    }
    return false;
} 