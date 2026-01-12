//+------------------------------------------------------------------+
//|                                          KT_Pinbar_Detector.mq4 |
//|                                  Copyright 2026, KT Expert Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, KT Expert Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "KT Pinbar Detector - Professional Price Action Scanner"
#property description "Detects Bullish & Bearish Pinbar patterns with smart alerts."
// 调整参数以创建 v2 版本，放宽识别条件
#property strict
#property indicator_chart_window
#property indicator_buffers 2

//--- 指标缓冲区
double BullishPinBuffer[];  // 看涨 Pinbar 箭头
double BearishPinBuffer[];  // 看跌 Pinbar 箭头

//--- 输入参数
input string   __Pattern_Settings__ = "=== Pattern Recognition ===";
input double   PinRatio = 1.5;          // Main Shadow/Body Ratio (>=1.5)
input double   NoseRatio = 0.5;         // Opposite Shadow/Body Ratio (<=0.5)
input double   BodyRatio = 0.4;         // Body/Total Range Ratio (<=0.4)
input int      LookbackBars = 1000;     // Historical Scan Range

input string   __Alert_Settings__ = "=== Alert Settings ===";
input bool     EnableAlerts = true;     // Enable Sound Alerts
input double   AlertRatio = 2.5;        // Alert Quality Threshold (>=2.5)
input int      AlertCooldown = 60;      // Alert Cooldown (Minutes)

input string   __Display_Settings__ = "=== Display Settings ===";
input color    BullishColor = clrLimeGreen;  // Bullish Pinbar Color
input color    BearishColor = clrRed;        // Bearish Pinbar Color
input int      ArrowSize = 2;                // Arrow Width

input string   __Fibonacci_Settings__ = "=== Fibonacci Retracement ===";
input bool     DrawFibo = true;              // Draw Fibonacci Levels
input int      FiboExtension = 15;           // Fibo Line Extension (Bars)
input bool     ShowFibo050 = true;           // Show 0.5 Level
input bool     ShowFibo618 = true;           // Show 0.618 Level

//--- 全局变量
datetime g_lastBarTime = 0;           // 记录上一根 K 线时间
datetime g_lastBullishAlert = 0;      // 上次看涨提醒时间
datetime g_lastBearishAlert = 0;      // 上次看跌提醒时间
string   g_prefix = "KT_Pin_";        // 对象名前缀
bool     g_firstRun = true;           // 首次运行标志

//+------------------------------------------------------------------+
//| 初始化函数
//+------------------------------------------------------------------+
int OnInit()
{
   // 设置缓冲区
   SetIndexBuffer(0, BullishPinBuffer);
   SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, ArrowSize, BullishColor);
   SetIndexArrow(0, 233); // 上箭头
   SetIndexLabel(0, "Bullish Pinbar");
   
   SetIndexBuffer(1, BearishPinBuffer);
   SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, ArrowSize, BearishColor);
   SetIndexArrow(1, 234); // 下箭头
   SetIndexLabel(1, "Bearish Pinbar");
   
   // 初始化缓冲区
   ArraySetAsSeries(BullishPinBuffer, true);
   ArraySetAsSeries(BearishPinBuffer, true);
   
   Print("KT Pinbar Detector initialized. Waiting for data...");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 反初始化函数
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 可选：清理所有对象（如果使用对象标注的话）
   // Comment("");
}

//+------------------------------------------------------------------+
//| 计算函数（每个 Tick 调用）
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
   // 设置数组为时间序列模式
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   // 首次运行：扫描历史 K 线
   if(g_firstRun && rates_total > 10)
   {
      g_firstRun = false;
      ScanHistoricalBars();
      Print("Historical scan completed: ", LookbackBars, " bars analyzed.");
   }
   
   // 检测新 K 线形成
   if(time[0] != g_lastBarTime)
   {
      g_lastBarTime = time[0];
      
      // 检测 bar[1]（刚收盘的 K 线）
      CheckNewBar();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 扫描历史 K 线
//+------------------------------------------------------------------+
void ScanHistoricalBars()
{
   int limit = MathMin(LookbackBars, Bars - 1);
   
   for(int i = 1; i <= limit; i++)
   {
      // 检测看涨 Pinbar
      if(IsBullishPinbar(i))
      {
         BullishPinBuffer[i] = Low[i] - GetArrowOffset(i);
         DrawFibonacciLevels(i, true);  // 绘制斐波那契
      }
      else
      {
         BullishPinBuffer[i] = EMPTY_VALUE;
      }
      
      // 检测看跌 Pinbar
      if(IsBearishPinbar(i))
      {
         BearishPinBuffer[i] = High[i] + GetArrowOffset(i);
         DrawFibonacciLevels(i, false);  // 绘制斐波那契
      }
      else
      {
         BearishPinBuffer[i] = EMPTY_VALUE;
      }
   }
}

//+------------------------------------------------------------------+
//| 检测新 K 线（bar[1]）
//+------------------------------------------------------------------+
void CheckNewBar()
{
   bool isBullish = IsBullishPinbar(1);
   bool isBearish = IsBearishPinbar(1);
   
   // 标注箭头
   if(isBullish)
   {
      BullishPinBuffer[1] = Low[1] - GetArrowOffset(1);
      DrawFibonacciLevels(1, true);  // 绘制斐波那契
      
      // 检查是否需要提醒
      if(ShouldAlert(true))
      {
         SendPinbarAlert("Bullish Pinbar", true);
         g_lastBullishAlert = TimeCurrent();
      }
   }
   
   if(isBearish)
   {
      BearishPinBuffer[1] = High[1] + GetArrowOffset(1);
      DrawFibonacciLevels(1, false);  // 绘制斐波那契
      
      // 检查是否需要提醒
      if(ShouldAlert(false))
      {
         SendPinbarAlert("Bearish Pinbar", false);
         g_lastBearishAlert = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| 检测看涨 Pinbar（Hammer）
//+------------------------------------------------------------------+
bool IsBullishPinbar(int index)
{
   if(index < 0 || index >= Bars) return false;
   
   double h = High[index];
   double l = Low[index];
   double o = Open[index];
   double c = Close[index];
   
   // 计算关键尺寸
   double totalRange = h - l;
   if(totalRange <= 0) return false;
   
   double body = MathAbs(c - o);
   double upperShadow = h - MathMax(o, c);
   double lowerShadow = MathMin(o, c) - l;
   
   // 避免除以零
   if(body <= 0) body = Point * 0.1;
   
   // 条件 1：下影线足够长（主影线）
   bool longLowerShadow = (lowerShadow / body) >= PinRatio;
   
   // 条件 2：上影线很短（副影线）
   bool shortUpperShadow = (upperShadow / body) <= NoseRatio;
   
   // 条件 3：实体很小（占总范围的比例）
   bool smallBody = (body / totalRange) <= BodyRatio;
   
   // 条件 4：实体位于上方 1/2 区域（放宽标准）
   double bodyPosition = (MathMin(o, c) - l) / totalRange;
   bool bodyAtTop = bodyPosition >= 0.5; // 实体在上方 50% 以上
   
   return (longLowerShadow && shortUpperShadow && smallBody && bodyAtTop);
}

//+------------------------------------------------------------------+
//| 检测看跌 Pinbar（Shooting Star）
//+------------------------------------------------------------------+
bool IsBearishPinbar(int index)
{
   if(index < 0 || index >= Bars) return false;
   
   double h = High[index];
   double l = Low[index];
   double o = Open[index];
   double c = Close[index];
   
   // 计算关键尺寸
   double totalRange = h - l;
   if(totalRange <= 0) return false;
   
   double body = MathAbs(c - o);
   double upperShadow = h - MathMax(o, c);
   double lowerShadow = MathMin(o, c) - l;
   
   // 避免除以零
   if(body <= 0) body = Point * 0.1;
   
   // 条件 1：上影线足够长（主影线）
   bool longUpperShadow = (upperShadow / body) >= PinRatio;
   
   // 条件 2：下影线很短（副影线）
   bool shortLowerShadow = (lowerShadow / body) <= NoseRatio;
   
   // 条件 3：实体很小
   bool smallBody = (body / totalRange) <= BodyRatio;
   
   // 条件 4：实体位于下方 1/2 区域（放宽标准）
   double bodyPosition = (h - MathMax(o, c)) / totalRange;
   bool bodyAtBottom = bodyPosition >= 0.5; // 实体在下方 50% 以上
   
   return (longUpperShadow && shortLowerShadow && smallBody && bodyAtBottom);
}

//+------------------------------------------------------------------+
//| 计算箭头偏移量（基于 ATR 或固定点数）
//+------------------------------------------------------------------+
double GetArrowOffset(int index)
{
   // 方法 1：使用 ATR（更智能）
   // double atr = iATR(Symbol(), Period(), 14, index);
   // return atr * 0.3;
   
   // 方法 2：固定点数（更简单）
   return 10 * Point;
}

//+------------------------------------------------------------------+
//| 计算斐波那契回撤级别价格
//+------------------------------------------------------------------+
double CalculateFiboLevel(double high, double low, double level, bool isBullish)
{
   double range = high - low;
   
   if(isBullish)
   {
      // 看涨：从低到高回撤（0在高，100在低）
      return low + range * level;
   }
   else
   {
      // 看跌：从高到低回撤（0在低，100在高）
      return high - range * level;
   }
}

//+------------------------------------------------------------------+
//| 绘制斐波那契回撤级别（0.5 和 0.618）
//+------------------------------------------------------------------+
void DrawFibonacciLevels(int index, bool isBullish)
{
   if(!DrawFibo) return;
   if(index < 0 || index >= Bars) return;
   
   double h = High[index];
   double l = Low[index];
   datetime barTime = Time[index];
   
   // 计算终点时间（向右延伸）
   int endIndex = index - FiboExtension;
   if(endIndex < 0) endIndex = 0;
   datetime endTime = Time[endIndex];
   
   // 生成唯一时间戳ID
   string timeID = IntegerToString((long)barTime);
   string dirStr = isBullish ? "B" : "S";
   color lineColor = isBullish ? BullishColor : BearishColor;
   
   // 绘制 0.5 级别
   if(ShowFibo050)
   {
      double price050 = CalculateFiboLevel(h, l, 0.5, isBullish);
      string lineName050 = g_prefix + "Fibo_" + dirStr + "_050_" + timeID;
      string labelName050 = g_prefix + "FiboLabel_" + dirStr + "_050_" + timeID;
      
      // 绘制水平趋势线
      if(ObjectFind(0, lineName050) == -1)
      {
         ObjectCreate(0, lineName050, OBJ_TREND, 0, barTime, price050, endTime, price050);
         ObjectSetInteger(0, lineName050, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lineName050, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName050, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName050, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName050, OBJPROP_BACK, true);
         ObjectSetInteger(0, lineName050, OBJPROP_SELECTABLE, false);
         ObjectSetString(0, lineName050, OBJPROP_TEXT, "Fibo 0.5");
      }
      
      // 绘制价格标签
      if(ObjectFind(0, labelName050) == -1)
      {
         ObjectCreate(0, labelName050, OBJ_ARROW_RIGHT_PRICE, 0, endTime, price050);
         ObjectSetInteger(0, labelName050, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, labelName050, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, labelName050, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, labelName050, OBJPROP_HIDDEN, true);
      }
   }
   
   // 绘制 0.618 级别
   if(ShowFibo618)
   {
      double price618 = CalculateFiboLevel(h, l, 0.618, isBullish);
      string lineName618 = g_prefix + "Fibo_" + dirStr + "_618_" + timeID;
      string labelName618 = g_prefix + "FiboLabel_" + dirStr + "_618_" + timeID;
      
      // 绘制水平趋势线
      if(ObjectFind(0, lineName618) == -1)
      {
         ObjectCreate(0, lineName618, OBJ_TREND, 0, barTime, price618, endTime, price618);
         ObjectSetInteger(0, lineName618, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lineName618, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName618, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName618, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName618, OBJPROP_BACK, true);
         ObjectSetInteger(0, lineName618, OBJPROP_SELECTABLE, false);
         ObjectSetString(0, lineName618, OBJPROP_TEXT, "Fibo 0.618");
      }
      
      // 绘制价格标签
      if(ObjectFind(0, labelName618) == -1)
      {
         ObjectCreate(0, labelName618, OBJ_ARROW_RIGHT_PRICE, 0, endTime, price618);
         ObjectSetInteger(0, labelName618, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, labelName618, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, labelName618, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, labelName618, OBJPROP_HIDDEN, true);
      }
   }
}

//+------------------------------------------------------------------+
//| 判断是否应该发送提醒
//+------------------------------------------------------------------+
bool ShouldAlert(bool isBullish)
{
   if(!EnableAlerts) return false;
   
   // 检查冷却时间
   datetime lastAlert = isBullish ? g_lastBullishAlert : g_lastBearishAlert;
   int secondsPassed = (int)(TimeCurrent() - lastAlert);
   
   if(secondsPassed < AlertCooldown * 60) return false;
   
   // 检查质量阈值（更严格的标准）
   int index = 1;
   double h = High[index];
   double l = Low[index];
   double o = Open[index];
   double c = Close[index];
   
   double body = MathAbs(c - o);
   if(body <= 0) body = Point * 0.1;
   
   if(isBullish)
   {
      double lowerShadow = MathMin(o, c) - l;
      double ratio = lowerShadow / body;
      return (ratio >= AlertRatio);
   }
   else
   {
      double upperShadow = h - MathMax(o, c);
      double ratio = upperShadow / body;
      return (ratio >= AlertRatio);
   }
}

//+------------------------------------------------------------------+
//| 发送 Pinbar 提醒
//+------------------------------------------------------------------+
void SendPinbarAlert(string pinType, bool isBullish)
{
   string symbol = Symbol();
   string timeframe = GetTimeframeName(Period());
   double price = isBullish ? Low[1] : High[1];
   
   string message = StringFormat(
      "%s detected on %s %s at %.5f",
      pinType,
      symbol,
      timeframe,
      price
   );
   
   Alert(message);
   
   // 可选：播放声音
   if(isBullish)
   {
      PlaySound("alert.wav");
   }
   else
   {
      PlaySound("alert2.wav");
   }
   
   Print("ALERT: ", message);
}

//+------------------------------------------------------------------+
//| 获取周期名称
//+------------------------------------------------------------------+
string GetTimeframeName(int period)
{
   switch(period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "Unknown";
   }
}
