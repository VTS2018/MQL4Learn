//+------------------------------------------------------------------+
//|                                       KT_Break_of_Structure.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property indicator_chart_window
#property strict

// from https://www.mql5.com/en/articles/15017
// 原始文件 Break_of_Structure_jBoSc_EA.mq5
// Modified: Added historical BOS detection on initialization
// Converted to MQL4

// 输入参数
input int    InpLength = 20;          // 摆动点验证长度
input int    InpScanLimit = 20;       // 实时扫描位置
input int    InpHistoryBars = 1000;   // 历史回溯K线数
input bool   InpShowHistory = true;   // 显示历史BOS标记
input int    InpBreakScanLimit = 0;   // 突破扫描范围(0=扫描到最新K线)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // 清理旧的图表对象（包括箭头、箭头线和文本）
   DeleteObjectsByPrefix("BOS_");
   DeleteObjectsByPrefix("BREAK_");
   
   if(InpShowHistory)
   {
      Print("开始扫描历史BOS... 扫描范围: ", InpHistoryBars, " 根K线");
      ScanHistoricalBOS();
      Print("历史BOS扫描完成!");
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 删除指定前缀的所有对象                                              |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(name);
      }
   }
}

//+------------------------------------------------------------------+
//| 扫描历史BOS                                                       |
//+------------------------------------------------------------------+
void ScanHistoricalBOS()
{
   int totalBars = Bars;
   int startBar = MathMin(InpHistoryBars, totalBars - InpLength - 1);
   
   // 计算历史扫描的终止位置：确保不与实时扫描位置重叠
   // 历史扫描应停止在 InpScanLimit + 1 之前，避免重复检测
   int endBar = MathMax(InpLength + 1, InpScanLimit + 1);
   
   // 从旧到新扫描（避免最近的K线数据不完整）
   for(int curr_bar = startBar; curr_bar >= endBar; curr_bar--)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      // 验证左右各length根K线
      for(int j = 1; j <= InpLength; j++)
      {
         int right_index = curr_bar - j;  // 左侧K线（更早）
         int left_index = curr_bar + j;   // 右侧K线（更近）
         
         // 摆动高点验证
         if((High[curr_bar] <= High[right_index]) || (High[curr_bar] < High[left_index]))
         {
            isSwingHigh = false;
         }
         
         // 摆动低点验证
         if((Low[curr_bar] >= Low[right_index]) || (Low[curr_bar] > Low[left_index]))
         {
            isSwingLow = false;
         }
      }
      
      // 记录摆动高点
      if(isSwingHigh)
      {
         string objName = "BOS_H_" + TimeToString(Time[curr_bar], TIME_DATE|TIME_SECONDS);
         drawSwingPoint(objName, Time[curr_bar], High[curr_bar], 77, clrBlue, -1);
         
         // 检测突破（向后扫描）
         CheckHistoricalBreak(curr_bar, High[curr_bar], true);
      }
      
      // 记录摆动低点
      if(isSwingLow)
      {
         string objName = "BOS_L_" + TimeToString(Time[curr_bar], TIME_DATE|TIME_SECONDS);
         drawSwingPoint(objName, Time[curr_bar], Low[curr_bar], 77, clrRed, 1);
         
         // 检测突破（向后扫描）
         CheckHistoricalBreak(curr_bar, Low[curr_bar], false);
      }
   }
   
   WindowRedraw();
}

//+------------------------------------------------------------------+
//| 检测历史突破                                                      |
//+------------------------------------------------------------------+
void CheckHistoricalBreak(int swing_bar, double swing_price, bool isHigh)
{
   // 计算扫描终点：0=扫描到bar[1]（最新收盘K线），>0=限制扫描范围
   int endBar = (InpBreakScanLimit <= 0) ? 1 : MathMax(1, swing_bar - InpBreakScanLimit);
   
   // 从摆动点后一根K线扫描到最新收盘K线
   for(int i = swing_bar - 1; i >= endBar; i--)
   {
      if(isHigh)
      {
         // 向上突破检测
         if(Close[i] > swing_price && Low[i] < swing_price)
         {
            string objName = "BREAK_H_" + TimeToString(Time[swing_bar], TIME_DATE|TIME_SECONDS);
            drawBreakLevel(objName, Time[swing_bar], swing_price, 
                          Time[i], swing_price, clrBlue, -1);
            break;  // 找到第一个突破即停止
         }
      }
      else
      {
         // 向下突破检测
         if(Close[i] < swing_price && High[i] > swing_price)
         {
            string objName = "BREAK_L_" + TimeToString(Time[swing_bar], TIME_DATE|TIME_SECONDS);
            drawBreakLevel(objName, Time[swing_bar], swing_price, 
                          Time[i], swing_price, clrRed, 1);
            break;  // 找到第一个突破即停止
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 移除指标时清理所有对象
   if(reason == REASON_REMOVE)
   {
      DeleteObjectsByPrefix("BOS_");
      DeleteObjectsByPrefix("BREAK_");
      Print("已清理所有BOS标记对象");
   }
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
   // 检测新K线
   static int prev_bars = 0;
   int curr_bars = Bars;
   
   if(prev_bars == curr_bars)
   {
      return(rates_total);  // 不是新K线，直接返回
   }
   prev_bars = curr_bars;
   
   // 实时摆动点检测变量
   static double swing_H = -1.0, swing_L = -1.0;
   static int swing_H_bar = -1, swing_L_bar = -1;
   int curr_bar = InpScanLimit;
   
   // 摆动点检测逻辑
   bool isSwingHigh = true, isSwingLow = true;
   
   for(int j = 1; j <= InpLength; j++)
   {
      int right_index = curr_bar - j;
      int left_index = curr_bar + j;
      
      if((High[curr_bar] <= High[right_index]) || (High[curr_bar] < High[left_index]))
      {
         isSwingHigh = false;
      }
      if((Low[curr_bar] >= Low[right_index]) || (Low[curr_bar] > Low[left_index]))
      {
         isSwingLow = false;
      }
   }
   
   // 摆动高点处理
   if(isSwingHigh)
   {
      swing_H = High[curr_bar];
      swing_H_bar = curr_bar;
      string objName = "BOS_H_" + TimeToString(Time[curr_bar], TIME_DATE|TIME_SECONDS);
      
      if(ObjectFind(objName) < 0)
      {
         Print("实时摆动高点 @ BAR ", curr_bar, " Price: ", swing_H);
         drawSwingPoint(objName, Time[curr_bar], swing_H, 77, clrBlue, -1);
      }
   }
   
   // 摆动低点处理
   if(isSwingLow)
   {
      swing_L = Low[curr_bar];
      swing_L_bar = curr_bar;
      string objName = "BOS_L_" + TimeToString(Time[curr_bar], TIME_DATE|TIME_SECONDS);
      
      if(ObjectFind(objName) < 0)
      {
         Print("实时摆动低点 @ BAR ", curr_bar, " Price: ", swing_L);
         drawSwingPoint(objName, Time[curr_bar], swing_L, 77, clrRed, 1);
      }
   }
   
   // 突破检测（使用Close[1]而非实时价格）
   if(swing_H > 0 && Close[1] > swing_H)
   {
      Print("实时向上突破 @ ", TimeToString(Time[0], TIME_DATE|TIME_SECONDS));
      string objName = "BREAK_H_" + TimeToString(Time[swing_H_bar], TIME_DATE|TIME_SECONDS);
      drawBreakLevel(objName, Time[swing_H_bar], swing_H, 
                    Time[1], swing_H, clrBlue, -1);
      swing_H = -1.0;
   }
   
   if(swing_L > 0 && Close[1] < swing_L)
   {
      Print("实时向下突破 @ ", TimeToString(Time[0], TIME_DATE|TIME_SECONDS));
      string objName = "BREAK_L_" + TimeToString(Time[swing_L_bar], TIME_DATE|TIME_SECONDS);
      drawBreakLevel(objName, Time[swing_L_bar], swing_L, 
                    Time[1], swing_L, clrRed, 1);
      swing_L = -1.0;
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 绘制摆动点标记                                                     |
//+------------------------------------------------------------------+
void drawSwingPoint(string objName, datetime time, double price, int arrCode,
                   color clr, int direction)
{
   if(ObjectFind(objName) < 0)
   {
      ObjectCreate(objName, OBJ_ARROW, 0, time, price);
      ObjectSet(objName, OBJPROP_ARROWCODE, arrCode);
      ObjectSet(objName, OBJPROP_COLOR, clr);
      ObjectSet(objName, OBJPROP_WIDTH, 1);
      if(direction > 0) ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0) ObjectSet(objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      
      string txt = " BoS";
      string objNameDescr = objName + txt;
      ObjectCreate(objNameDescr, OBJ_TEXT, 0, time, price);
      ObjectSetText(objNameDescr, " " + txt, 10, "Arial", clr);
      if(direction > 0)
      {
         ObjectSet(objNameDescr, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      }
      if(direction < 0)
      {
         ObjectSet(objNameDescr, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      }
   }
}

//+------------------------------------------------------------------+
//| 绘制突破线                                                         |
//+------------------------------------------------------------------+
void drawBreakLevel(string objName, datetime time1, double price1,
                   datetime time2, double price2, color clr, int direction)
{
   if(ObjectFind(objName) < 0)
   {
      ObjectCreate(objName, OBJ_TREND, 0, time1, price1, time2, price2);
      ObjectSet(objName, OBJPROP_TIME1, time1);
      ObjectSet(objName, OBJPROP_PRICE1, price1);
      ObjectSet(objName, OBJPROP_TIME2, time2);
      ObjectSet(objName, OBJPROP_PRICE2, price2);
      ObjectSet(objName, OBJPROP_COLOR, clr);
      ObjectSet(objName, OBJPROP_WIDTH, 2);
      ObjectSet(objName, OBJPROP_RAY_RIGHT, false);
      
      string txt = " Break   ";
      string objNameDescr = objName + txt;
      ObjectCreate(objNameDescr, OBJ_TEXT, 0, time2, price2);
      ObjectSetText(objNameDescr, " " + txt, 10, "Arial", clr);
      if(direction > 0)
      {
         ObjectSet(objNameDescr, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      }
      if(direction < 0)
      {
         ObjectSet(objNameDescr, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      }
   }
}
//+------------------------------------------------------------------+
