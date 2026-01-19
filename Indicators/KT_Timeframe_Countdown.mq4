//+------------------------------------------------------------------+
//|                                      KT_Timeframe_Countdown.mq4 |
//|                                Copyright 2026, KT Expert.        |
//|                                   https://www.mql5.com           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, KT Expert."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property description "多周期倒计时指标 - 显示M1/M5/M15/M30/H1/H4倒计时"

//+------------------------------------------------------------------+
//| 输入参数
//+------------------------------------------------------------------+
input int      InpPosX = 10;              // 显示位置 X (像素)
input int      InpPosY = 30;              // 显示位置 Y (像素)
input color    InpHeaderColor = clrWhite; // 表头颜色
input color    InpTextColor = clrLightGray; // 文本颜色
input color    InpWarningColor = clrOrange; // 警告颜色 (<10秒)
input color    InpNewBarColor = clrLime;  // 新K线颜色
input int      InpFontSize = 9;           // 字体大小
input bool     InpEnableAlert = false;     // 启用新K线提醒
input int      InpWarningSeconds = 10;    // 警告秒数阈值

//+------------------------------------------------------------------+
//| 时间框架信息结构
//+------------------------------------------------------------------+
struct TimeframeInfo
{
   int      period;          // 周期值
   string   name;            // 周期名称
   int      remainSeconds;   // 剩余秒数
   bool     isNewBar;        // 是否刚出现新K线
   datetime lastBarTime;     // 上一根K线时间
};

//+------------------------------------------------------------------+
//| 全局变量
//+------------------------------------------------------------------+
TimeframeInfo g_timeframes[6];  // 6个时间周期
string g_objectPrefix = "KT_TF_";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 初始化时间周期数组
   g_timeframes[0].period = PERIOD_M1;
   g_timeframes[0].name = "M1";
   
   g_timeframes[1].period = PERIOD_M5;
   g_timeframes[1].name = "M5";
   
   g_timeframes[2].period = PERIOD_M15;
   g_timeframes[2].name = "M15";
   
   g_timeframes[3].period = PERIOD_M30;
   g_timeframes[3].name = "M30";
   
   g_timeframes[4].period = PERIOD_H1;
   g_timeframes[4].name = "H1";
   
   g_timeframes[5].period = PERIOD_H4;
   g_timeframes[5].name = "H4";
   
   // 初始化每个周期的最后K线时间
   for(int i = 0; i < 6; i++)
   {
      g_timeframes[i].lastBarTime = iTime(Symbol(), g_timeframes[i].period, 0);
      g_timeframes[i].isNewBar = false;
      g_timeframes[i].remainSeconds = 0;
   }
   
   // 创建显示对象
   CreateDisplayObjects();
   
   // 启动1秒定时器（确保倒计时流畅更新）
   EventSetTimer(1);
   
   Print("=== KT 多周期倒计时指标启动 ===");
   Print("监控周期: M1, M5, M15, M30, H1, H4");
   Print("新K线提醒: ", (InpEnableAlert ? "已启用" : "未启用"));
   Print("定时器: 1秒刷新");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 停止定时器
   EventKillTimer();
   
   // 清理所有显示对象
   CleanupDisplayObjects();
   Print("=== KT 多周期倒计时指标停止 ===");
}

//+------------------------------------------------------------------+
//| Timer event (每秒触发)                                           |
//+------------------------------------------------------------------+
void OnTimer()
{
   // 更新所有周期的倒计时
   UpdateAllCountdowns();
   
   // 更新显示
   UpdateDisplay();
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
   // OnTimer负责更新，这里仅返回（满足指标系统要求）
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 创建显示对象
//+------------------------------------------------------------------+
void CreateDisplayObjects()
{
   int x = InpPosX;
   int y = InpPosY;
   int lineHeight = InpFontSize + 6;
   
   // 创建表头背景
   string bgName = g_objectPrefix + "Background";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 280);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, lineHeight * 7 + 10);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
   
   // 创建表头
   CreateLabel(g_objectPrefix + "Header", x + 5, y + 5, 
               "周期        剩余时间      状态", 
               InpHeaderColor, InpFontSize + 1, "Consolas");
   
   // 创建6个周期的显示行
   for(int i = 0; i < 6; i++)
   {
      int yPos = y + 5 + lineHeight * (i + 1);
      
      // 周期名称
      CreateLabel(g_objectPrefix + "TF_" + IntegerToString(i), 
                  x + 5, yPos, 
                  g_timeframes[i].name, 
                  InpTextColor, InpFontSize, "Consolas");
      
      // 倒计时
      CreateLabel(g_objectPrefix + "Time_" + IntegerToString(i), 
                  x + 80, yPos, 
                  "00:00", 
                  InpTextColor, InpFontSize, "Consolas");
      
      // 状态
      CreateLabel(g_objectPrefix + "Status_" + IntegerToString(i), 
                  x + 180, yPos, 
                  "等待中", 
                  InpTextColor, InpFontSize, "Consolas");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 创建标签对象
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int size, string font)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| 更新所有周期的倒计时
//+------------------------------------------------------------------+
void UpdateAllCountdowns()
{
   datetime currentTime = TimeCurrent();
   
   for(int i = 0; i < 6; i++)
   {
      int period = g_timeframes[i].period;
      
      // 获取当前K线的开始时间
      datetime barTime = iTime(Symbol(), period, 0);
      
      // 检测新K线
      if(barTime != g_timeframes[i].lastBarTime)
      {
         g_timeframes[i].isNewBar = true;
         g_timeframes[i].lastBarTime = barTime;
         
         // 新K线提醒
         if(InpEnableAlert)
         {
            string message = "【新K线】" + Symbol() + " " + g_timeframes[i].name;
            Alert(message);
            PlaySound("alert.wav");
         }
      }
      else
      {
         g_timeframes[i].isNewBar = false;
      }
      
      // 计算剩余秒数
      int periodSeconds = period * 60;  // 周期转换为秒数
      datetime nextBarTime = barTime + periodSeconds;
      int remainSeconds = (int)(nextBarTime - currentTime);
      
      // 防止负数（可能出现在周末或数据延迟时）
      if(remainSeconds < 0)
         remainSeconds = 0;
      
      g_timeframes[i].remainSeconds = remainSeconds;
   }
}

//+------------------------------------------------------------------+
//| 更新显示
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   for(int i = 0; i < 6; i++)
   {
      // 更新倒计时文本
      string timeText = FormatTime(g_timeframes[i].remainSeconds);
      string timeLabelName = g_objectPrefix + "Time_" + IntegerToString(i);
      ObjectSetString(0, timeLabelName, OBJPROP_TEXT, timeText);
      
      // 根据剩余时间设置颜色
      color timeColor;
      if(g_timeframes[i].isNewBar)
      {
         timeColor = InpNewBarColor;  // 新K线：绿色
      }
      else if(g_timeframes[i].remainSeconds <= InpWarningSeconds)
      {
         timeColor = InpWarningColor;  // 警告：橙色
      }
      else
      {
         timeColor = InpTextColor;  // 正常：灰色
      }
      ObjectSetInteger(0, timeLabelName, OBJPROP_COLOR, timeColor);
      
      // 更新状态文本
      string statusText;
      if(g_timeframes[i].isNewBar)
      {
         statusText = "新K线";
      }
      else if(g_timeframes[i].remainSeconds <= InpWarningSeconds)
      {
         statusText = "即将";
      }
      else
      {
         statusText = "运行中";
      }
      
      string statusLabelName = g_objectPrefix + "Status_" + IntegerToString(i);
      ObjectSetString(0, statusLabelName, OBJPROP_TEXT, statusText);
      ObjectSetInteger(0, statusLabelName, OBJPROP_COLOR, timeColor);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 格式化时间（秒数 → mm:ss 或 HH:mm:ss）
//+------------------------------------------------------------------+
string FormatTime(int seconds)
{
   if(seconds < 0)
      return "00:00";
   
   int hours = seconds / 3600;
   int minutes = (seconds % 3600) / 60;
   int secs = seconds % 60;
   
   string result;
   
   if(hours > 0)
   {
      // 显示为 HH:mm:ss
      result = StringFormat("%02d:%02d:%02d", hours, minutes, secs);
   }
   else
   {
      // 显示为 mm:ss
      result = StringFormat("%02d:%02d", minutes, secs);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| 清理显示对象
//+------------------------------------------------------------------+
void CleanupDisplayObjects()
{
   int total = ObjectsTotal(0, -1, -1);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, g_objectPrefix) == 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   ChartRedraw();
}
//+------------------------------------------------------------------+
