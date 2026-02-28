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
// [新增] 自适应宽度设置
input int      InpPaddingLeft = 8;        // 左内边距
input int      InpPaddingRight = 8;       // 右内边距
input int      InpPaddingTop = 5;         // 上内边距
input int      InpPaddingBottom = 5;      // 下内边距
input int      InpColumnSpacing = 15;     // 列间距

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

// 布局计算变量
int g_col1X, g_col2X, g_col3X;  // 三列的X位置
int g_panelWidth;                // 面板总宽度

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
//| 估算文本宽度（像素）
//+------------------------------------------------------------------+
int CalculateTextWidth(string text, int fontSize)
{
   // 根据字体大小和字符类型估算宽度
   // Consolas 是等宽字体，但中文字符宽度约为英文的2倍
   int width = 0;
   int len = StringLen(text);
   
   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(text, i);
      
      // 判断是否为中文字符（简单判断）
      if(ch > 0x4E00 && ch < 0x9FA5)  // 中文常用字范围
      {
         width += fontSize + 4;  // 中文字符宽度（增加系数）
      }
      else
      {
         width += (int)(fontSize * 0.65);  // 英文/数字宽度（略微增加）
      }
   }
   
   return width;
}

//+------------------------------------------------------------------+
//| 创建显示对象
//+------------------------------------------------------------------+
void CreateDisplayObjects()
{
   int x = InpPosX;
   int y = InpPosY;
   int lineHeight = InpFontSize + 6;
   
   // ========== 计算自适应宽度 ==========
   
   // 计算每列标题的宽度
   int col1TitleWidth = CalculateTextWidth("周期", InpFontSize + 1);
   int col2TitleWidth = CalculateTextWidth("剩余时间", InpFontSize + 1);
   int col3TitleWidth = CalculateTextWidth("状态", InpFontSize + 1);
   
   // 计算每列数据的最大宽度
   int col1DataWidth = CalculateTextWidth("M30", InpFontSize);  // 最长的周期名称
   int col2DataWidth = CalculateTextWidth("00:00:00", InpFontSize);  // 最长的时间格式
   int col3DataWidth = CalculateTextWidth("运行中", InpFontSize);  // 最长的状态文本
   
   // 每列取标题和数据中的最大宽度，并添加额外余量（文本渲染需要额外空间）
   int col1Width = MathMax(col1TitleWidth, col1DataWidth) + 3;
   int col2Width = MathMax(col2TitleWidth, col2DataWidth) + 3;
   int col3Width = MathMax(col3TitleWidth, col3DataWidth) + 3;  // 统一余量，保持视觉平衡
   
   // === 调试信息：打印宽度计算结果 ===
   Print("=== 列宽度计算调试 ===");
   Print("第1列(周期) - 标题宽度:", col1TitleWidth, " 数据宽度:", col1DataWidth, " 最终宽度:", col1Width);
   Print("第2列(剩余时间) - 标题宽度:", col2TitleWidth, " 数据宽度:", col2DataWidth, " 最终宽度:", col2Width);
   Print("第3列(状态) - 标题宽度:", col3TitleWidth, " 数据宽度:", col3DataWidth, " 最终宽度:", col3Width);
   Print("面板总宽度:", g_panelWidth, " (将在下方计算)");
   
   // 计算每列的X位置
   g_col1X = x + InpPaddingLeft;
   g_col2X = g_col1X + col1Width + InpColumnSpacing;
   g_col3X = g_col2X + col2Width + InpColumnSpacing;
   
   // 计算面板总宽度
   g_panelWidth = InpPaddingLeft + col1Width + InpColumnSpacing + 
                  col2Width + InpColumnSpacing + col3Width + InpPaddingRight;
   
   // 计算面板总高度
   int panelHeight = InpPaddingTop + lineHeight * 7 + InpPaddingBottom;
   
   // === 调试信息：打印布局计算结果 ===
   Print("列位置 - 第1列X:", g_col1X, " 第2列X:", g_col2X, " 第3列X:", g_col3X);
   Print("面板尺寸 - 宽度:", g_panelWidth, " 高度:", panelHeight);
   Print("内边距 - 左:", InpPaddingLeft, " 右:", InpPaddingRight, " 上:", InpPaddingTop, " 下:", InpPaddingBottom);
   Print("列间距:", InpColumnSpacing);
   Print("==================");
   
   // 创建表头背景
   string bgName = g_objectPrefix + "Background";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, g_panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   
   // 创建表头（三列分别对齐）
   CreateLabel(g_objectPrefix + "Header_TF", g_col1X, y + InpPaddingTop, 
               "周期", 
               InpHeaderColor, InpFontSize + 1, "Consolas");
   
   CreateLabel(g_objectPrefix + "Header_Time", g_col2X, y + InpPaddingTop, 
               "剩余时间", 
               InpHeaderColor, InpFontSize + 1, "Consolas");
   
   CreateLabel(g_objectPrefix + "Header_Status", g_col3X, y + InpPaddingTop, 
               "状态", 
               InpHeaderColor, InpFontSize + 1, "Consolas");
   
   // 创建6个周期的显示行
   for(int i = 0; i < 6; i++)
   {
      int yPos = y + InpPaddingTop + lineHeight * (i + 1);
      
      // 周期名称
      CreateLabel(g_objectPrefix + "TF_" + IntegerToString(i), 
                  g_col1X, yPos, 
                  g_timeframes[i].name, 
                  InpTextColor, InpFontSize, "Consolas");
      
      // 倒计时
      CreateLabel(g_objectPrefix + "Time_" + IntegerToString(i), 
                  g_col2X, yPos, 
                  "00:00", 
                  InpTextColor, InpFontSize, "Consolas");
      
      // 状态
      CreateLabel(g_objectPrefix + "Status_" + IntegerToString(i), 
                  g_col3X, yPos, 
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
