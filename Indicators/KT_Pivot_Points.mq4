//+------------------------------------------------------------------+
//|                                            KT_Pivot_Points.mq4   |
//|                                Copyright 2026, KT Expert.        |
//|                                   https://www.mql5.com           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, KT Expert."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property description "日内枢轴点指标 - 专为XAUUSD优化"
#property description "显示 PP、R1-R3、S1-S3 支撑阻力位"

//+------------------------------------------------------------------+
//| 枚举定义
//+------------------------------------------------------------------+
enum ENUM_PIVOT_TYPE
{
   PIVOT_CLASSIC,      // 标准枢轴点 (Classic)
   PIVOT_FIBONACCI,    // 斐波那契枢轴 (Fibonacci)
   PIVOT_WOODIE,       // Woodie's 枢轴
   PIVOT_CAMARILLA     // Camarilla 枢轴
};

//+------------------------------------------------------------------+
//| 输入参数
//+------------------------------------------------------------------+
input string   __Calculation__ = "=== Calculation Settings ===";
input ENUM_PIVOT_TYPE InpPivotType = PIVOT_CLASSIC;  // 枢轴点类型 (Pivot Type)
input bool     InpShowR3 = true;     // 显示 R3/S3 (Show R3/S3)
input bool     InpShowR2 = true;     // 显示 R2/S2 (Show R2/S2)
input bool     InpShowR1 = true;     // 显示 R1/S1 (Show R1/S1)

input string   __Display__ = "=== Display Settings ===";
input color    InpColorPP = clrYellow;      // PP 颜色 (PP Color)
input color    InpColorResistance = clrRed; // 阻力位颜色 (Resistance Color)
input color    InpColorSupport = clrDodgerBlue; // 支撑位颜色 (Support Color)
input int      InpLineWidth = 1;            // 线宽 (Line Width)
input ENUM_LINE_STYLE InpLineStyle = STYLE_SOLID; // 线型 (Line Style)
input bool     InpShowLabels = true;        // 显示标签 (Show Labels)
input int      InpLabelFontSize = 9;        // 标签字体大小 (Label Font Size)

//+------------------------------------------------------------------+
//| 全局变量
//+------------------------------------------------------------------+
datetime g_lastCalculatedDay = 0;    // 最后计算的日期
double g_PP = 0;                     // 主枢轴点
double g_R1 = 0, g_R2 = 0, g_R3 = 0; // 阻力位
double g_S1 = 0, g_S2 = 0, g_S3 = 0; // 支撑位

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // 品种检查（仅提示，不强制）
   if(StringFind(Symbol(), "XAU") < 0 && StringFind(Symbol(), "GOLD") < 0)
   {
      Print("⚠️ 警告：此指标专为黄金品种(XAUUSD)设计，当前品种: ", Symbol());
   }
   
   // 初始计算
   CalculatePivotPoints();
   DrawPivotLines();
   
   Print("=== KT Pivot Points 启动 ===");
   Print("枢轴点类型: ", GetPivotTypeName(InpPivotType));
   Print("PP: ", DoubleToString(g_PP, Digits));
   Print("R1:", DoubleToString(g_R1, Digits), " R2:", DoubleToString(g_R2, Digits), " R3:", DoubleToString(g_R3, Digits));
   Print("S1:", DoubleToString(g_S1, Digits), " S2:", DoubleToString(g_S2, Digits), " S3:", DoubleToString(g_S3, Digits));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 清理所有绘制的对象
   CleanupPivotObjects();
   Print("=== KT Pivot Points 停止 ===");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // 检查是否需要重新计算（新的一天）
   datetime currentDay = iTime(Symbol(), PERIOD_D1, 0);
   
   if(currentDay != g_lastCalculatedDay)
   {
      Print("【日期变化】重新计算枢轴点...");
      CalculatePivotPoints();
      DrawPivotLines();
      g_lastCalculatedDay = currentDay;
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 计算枢轴点
//+------------------------------------------------------------------+
void CalculatePivotPoints()
{
   // 获取前一日的 H、L、C
   double H = iHigh(Symbol(), PERIOD_D1, 1);
   double L = iLow(Symbol(), PERIOD_D1, 1);
   double C = iClose(Symbol(), PERIOD_D1, 1);
   
   // 数据验证
   if(H == 0 || L == 0 || C == 0)
   {
      Print("错误：无法获取前一日数据");
      return;
   }
   
   double range = H - L;  // 日内波动范围
   
   // 根据选择的类型计算
   switch(InpPivotType)
   {
      case PIVOT_CLASSIC:
         CalculateClassicPivot(H, L, C, range);
         break;
         
      case PIVOT_FIBONACCI:
         CalculateFibonacciPivot(H, L, C, range);
         break;
         
      case PIVOT_WOODIE:
         CalculateWoodiePivot(H, L, C, range);
         break;
         
      case PIVOT_CAMARILLA:
         CalculateCamarillaPivot(H, L, C, range);
         break;
   }
}

//+------------------------------------------------------------------+
//| 标准枢轴点计算
//+------------------------------------------------------------------+
void CalculateClassicPivot(double H, double L, double C, double range)
{
   g_PP = (H + L + C) / 3.0;
   
   g_R1 = 2.0 * g_PP - L;
   g_R2 = g_PP + range;
   g_R3 = g_R1 + range;
   
   g_S1 = 2.0 * g_PP - H;
   g_S2 = g_PP - range;
   g_S3 = g_S1 - range;
}

//+------------------------------------------------------------------+
//| 斐波那契枢轴点计算
//+------------------------------------------------------------------+
void CalculateFibonacciPivot(double H, double L, double C, double range)
{
   g_PP = (H + L + C) / 3.0;
   
   g_R1 = g_PP + 0.382 * range;
   g_R2 = g_PP + 0.618 * range;
   g_R3 = g_PP + 1.000 * range;
   
   g_S1 = g_PP - 0.382 * range;
   g_S2 = g_PP - 0.618 * range;
   g_S3 = g_PP - 1.000 * range;
}

//+------------------------------------------------------------------+
//| Woodie's 枢轴点计算
//+------------------------------------------------------------------+
void CalculateWoodiePivot(double H, double L, double C, double range)
{
   g_PP = (H + L + 2.0 * C) / 4.0;  // 更重视收盘价
   
   g_R1 = 2.0 * g_PP - L;
   g_R2 = g_PP + range;
   g_R3 = g_R1 + range;
   
   g_S1 = 2.0 * g_PP - H;
   g_S2 = g_PP - range;
   g_S3 = g_S1 - range;
}

//+------------------------------------------------------------------+
//| Camarilla 枢轴点计算
//+------------------------------------------------------------------+
void CalculateCamarillaPivot(double H, double L, double C, double range)
{
   g_PP = (H + L + C) / 3.0;
   
   double coef = 1.1 / 12.0;
   g_R1 = C + range * coef;
   g_R2 = C + range * coef * 2.0;
   g_R3 = C + range * coef * 3.0;
   
   g_S1 = C - range * coef;
   g_S2 = C - range * coef * 2.0;
   g_S3 = C - range * coef * 3.0;
}

//+------------------------------------------------------------------+
//| 绘制枢轴点线条
//+------------------------------------------------------------------+
void DrawPivotLines()
{
   // 清理旧对象
   CleanupPivotObjects();
   
   // 绘制主枢轴点 PP
   DrawHLine("KT_PP", g_PP, InpColorPP, InpLineWidth, InpLineStyle, "PP");
   
   // 绘制阻力位
   if(InpShowR1)
      DrawHLine("KT_R1", g_R1, InpColorResistance, InpLineWidth, InpLineStyle, "R1");
   if(InpShowR2)
      DrawHLine("KT_R2", g_R2, InpColorResistance, InpLineWidth, STYLE_DOT, "R2");
   if(InpShowR3)
      DrawHLine("KT_R3", g_R3, InpColorResistance, InpLineWidth, STYLE_DASH, "R3");
   
   // 绘制支撑位
   if(InpShowR1)
      DrawHLine("KT_S1", g_S1, InpColorSupport, InpLineWidth, InpLineStyle, "S1");
   if(InpShowR2)
      DrawHLine("KT_S2", g_S2, InpColorSupport, InpLineWidth, STYLE_DOT, "S2");
   if(InpShowR3)
      DrawHLine("KT_S3", g_S3, InpColorSupport, InpLineWidth, STYLE_DASH, "S3");
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 绘制水平线
//+------------------------------------------------------------------+
void DrawHLine(string name, double price, color clr, int width, int style, string label)
{
   // 创建水平线
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   }
   
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);  // 背景显示
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   
   // 添加文本标签
   if(InpShowLabels)
   {
      string labelName = name + "_Label";
      
      // 获取屏幕右侧位置
      int firstBar = WindowFirstVisibleBar();
      int barOffset = (int)(firstBar * 0.85);  // 屏幕右侧15%位置
      if(barOffset < 5) barOffset = 5;
      if(barOffset > firstBar - 5) barOffset = firstBar - 5;
      
      datetime labelTime = Time[barOffset];
      
      if(ObjectFind(0, labelName) < 0)
      {
         ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, price);
      }
      
      string labelText = label + ": " + DoubleToString(price, Digits);
      
      ObjectMove(0, labelName, 0, labelTime, price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, InpLabelFontSize);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| 清理枢轴点对象
//+------------------------------------------------------------------+
void CleanupPivotObjects()
{
   string prefix = "KT_";
   int total = ObjectsTotal(0, -1, -1);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| 获取枢轴点类型名称
//+------------------------------------------------------------------+
string GetPivotTypeName(ENUM_PIVOT_TYPE type)
{
   switch(type)
   {
      case PIVOT_CLASSIC:    return "Classic (标准)";
      case PIVOT_FIBONACCI:  return "Fibonacci (斐波那契)";
      case PIVOT_WOODIE:     return "Woodie's";
      case PIVOT_CAMARILLA:  return "Camarilla";
      default:               return "Unknown";
   }
}
