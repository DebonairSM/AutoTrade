//+------------------------------------------------------------------+
//|                                            VSol.Visualizer.mqh    |
//|                        Chart Visualization Implementation          |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include "VSol.Market.mqh"
#include "VSol.Utils.mqh"

// Visualization constants
#define LINE_STYLE_SUPPORT    STYLE_SOLID
#define LINE_STYLE_RESISTANCE STYLE_SOLID
#define LINE_WIDTH_ACTIVE     2
#define LINE_WIDTH_INACTIVE   1
#define LABEL_CORNER         CORNER_RIGHT_UPPER
#define LABEL_DISTANCE_X     10
#define LABEL_DISTANCE_Y     20

class CVSolVisualizer : public CVSolMarketBase
{
private:
    color m_supportColor;
    color m_resistanceColor;
    color m_textColor;
    bool m_showLabels;

public:
    bool Init(color supportColor = clrGreen, color resistanceColor = clrRed, 
             color textColor = clrWhite, bool showLabels = true)
    {
        m_supportColor = supportColor;
        m_resistanceColor = resistanceColor;
        m_textColor = textColor;
        m_showLabels = showLabels;
        return true;
    }
    
    void DrawLevel(const string name, const double price, const bool isResistance,
                  const datetime time1, const datetime time2)
    {
        color lineColor = isResistance ? m_resistanceColor : m_supportColor;
        ENUM_LINE_STYLE style = isResistance ? LINE_STYLE_RESISTANCE : LINE_STYLE_SUPPORT;
        
        ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, LINE_WIDTH_ACTIVE);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
        
        if(m_showLabels)
        {
            string labelName = name + "_label";
            string labelText = StringFormat("%s %.5f", 
                isResistance ? "R" : "S", price);
                
            ObjectCreate(0, labelName, OBJ_TEXT, 0, time2, price);
            ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, m_textColor);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        }
    }
    
    void DrawTrendLabel(const string text, const color labelColor = clrWhite)
    {
        string labelName = "Trend_Label";
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, labelName, OBJPROP_TEXT, text);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, LABEL_CORNER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, LABEL_DISTANCE_X);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, LABEL_DISTANCE_Y);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
    }
    
    void ClearObjects(const string prefix = "")
    {
        ObjectsDeleteAll(0, prefix);
    }
}; 