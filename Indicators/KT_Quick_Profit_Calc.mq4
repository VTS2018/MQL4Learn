//+------------------------------------------------------------------+
//|                                         KT_Quick_Profit_Calc.mq4 |
//|                                Copyright 2023, Professional Dev. |
//|                                            https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Professional Dev."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

//--- 输入参数
input double InpDefaultLots = 0.01;    // 测算手数 (默认 0.01)
input color  InpLineColor   = clrBlack; // 测距线颜色
input int    InpLineWidth   = 1;       // 测距线宽度
input int    InpFontSize    = 10;      // 显示字体大小
input color  InpTextColor   = clrWhite;// 字体颜色
input color  InpBgColor     = clrBlack;// 提示框背景色

//--- 全局变量
string LineObjName = "KT_Calc_Line";
string RectObjName = "KT_Calc_Rect";
string TextObjName = "KT_Calc_Text";
bool   IsDragging = false;
int    Start_X = 0;
int    Start_Y = 0;
double Start_Price = 0;
datetime Start_Time = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // 开启鼠标移动事件检测
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   
   // 设置指标简称
   IndicatorShortName("KT Quick Profit Calc");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 清理图表上的对象
   DeleteObjects();
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
   // 指标不需要画线，只需要处理事件
   return(rates_total);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // 仅处理鼠标移动事件
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      // 🚨 核心修正：正确解析鼠标状态和修饰键 🚨
      // sparam 在 CHARTEVENT_MOUSE_MOVE 中是一个字符串，需要转换为整数
      // 位标志含义：
      // 1 = 左键按下
      // 2 = 右键按下
      // 4 = Shift 键按下
      // 8 = Ctrl 键按下
      // 16 = 中键按下
      
      int mouse_state = (int)StringToInteger(sparam);
      int curr_x = (int)lparam;
      int curr_y = (int)dparam;
      
      // 检测是否同时按下 Ctrl 键 + 鼠标左键
      bool ctrl_pressed = (mouse_state & 8) != 0;   // Ctrl 键
      bool left_pressed = (mouse_state & 1) != 0;   // 左键
      
      // 🚨 新增限制：必须同时按下 Ctrl + 左键才能启动计算功能 🚨
      // 这样可以避免误触发，用户需要主动按 Ctrl 键才能使用
      
      // 状态 1: Ctrl + 鼠标左键同时按下 (开始或正在拖拽)
      if(ctrl_pressed && left_pressed)
      {
         // 获取当前鼠标位置对应的价格和时间
         double curr_price;
         datetime curr_time;
         int sub_window;
         
         if(ChartXYToTimePrice(0, curr_x, curr_y, sub_window, curr_time, curr_price))
         {
            // 如果之前没有在拖拽，说明是刚按下的第一刻 (记录起点)
            if(!IsDragging)
            {
               IsDragging = true;
               Start_X = curr_x;
               Start_Y = curr_y;
               Start_Price = curr_price;
               Start_Time = curr_time;
               
               // 创建测距线对象
               CreateLineObject();
               // 创建显示文本对象
               CreateLabelObjects();
               ChartRedraw(0);
            }
            else
            {
               // 正在拖拽中，更新终点和数据
               UpdateCalculation(curr_time, curr_price, curr_x, curr_y);
            }
         }
      }
      // 状态 0: Ctrl 键或左键松开
      else
      {
         // 如果之前在拖拽，现在松开了，清理现场
         if(IsDragging)
         {
            IsDragging = false;
            DeleteObjects();
            ChartRedraw(0);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 核心逻辑：更新计算和显示                                         |
//+------------------------------------------------------------------+
void UpdateCalculation(datetime end_time, double end_price, int x, int y)
{
   // 1. 更新线条位置
   // ObjectSetDouble(0, LineObjName, OBJPROP_TIME, 1, end_time);
   ObjectSetInteger(0, LineObjName, OBJPROP_TIME, 1, end_time); // 正确：时间要用 SetInteger
   ObjectSetDouble(0, LineObjName, OBJPROP_PRICE, 1, end_price);
   
   // 2. 计算数据
   double distance_price = MathAbs(end_price - Start_Price);
   double points = distance_price / Point; // 距离点数
   
   // 获取当前品种 1手跳动1个Point的价值 (这是核心，自动适配所有品种)
   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   
   // 盈亏金额 = 点数 * 单点价值 * 手数
   double profit_money = points * tick_value * InpDefaultLots;
   
   // 3. 格式化显示文本
   string text = "";
   text += "手数: " + DoubleToString(InpDefaultLots, 2) + "\n";
   text += "点数: " + DoubleToString(points, 0) + " pts\n";
   text += "盈亏: " + DoubleToString(profit_money, 2) + " " + AccountCurrency();
   
   // 4. 更新文本标签位置 (跟随鼠标)
   // 我们稍微偏移一点坐标，避免挡住鼠标指针
   int offset_x = 15;
   int offset_y = 15;
   
   // 更新背景框位置
   ObjectSetInteger(0, RectObjName, OBJPROP_XDISTANCE, x + offset_x);
   ObjectSetInteger(0, RectObjName, OBJPROP_YDISTANCE, y + offset_y);
   
   // 更新文字位置
   ObjectSetString(0, TextObjName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, TextObjName, OBJPROP_XDISTANCE, x + offset_x + 5);
   ObjectSetInteger(0, TextObjName, OBJPROP_YDISTANCE, y + offset_y + 5);
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 辅助函数：创建线条                                               |
//+------------------------------------------------------------------+
void CreateLineObject()
{
   if(ObjectFind(0, LineObjName) < 0)
   {
      ObjectCreate(0, LineObjName, OBJ_TREND, 0, Start_Time, Start_Price, Start_Time, Start_Price);
      ObjectSetInteger(0, LineObjName, OBJPROP_COLOR, InpLineColor);
      ObjectSetInteger(0, LineObjName, OBJPROP_WIDTH, InpLineWidth);
      ObjectSetInteger(0, LineObjName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, LineObjName, OBJPROP_RAY, false); // 不射线
      ObjectSetInteger(0, LineObjName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, LineObjName, OBJPROP_HIDDEN, true); // 脚本列表中隐藏
   }
}

//+------------------------------------------------------------------+
//| 辅助函数：创建文本标签                                           |
//+------------------------------------------------------------------+
void CreateLabelObjects()
{
   // 创建背景框 (使用 Label 或 RectangleLabel)
   if(ObjectFind(0, RectObjName) < 0)
   {
      ObjectCreate(0, RectObjName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, RectObjName, OBJPROP_XSIZE, 300); // 宽
      ObjectSetInteger(0, RectObjName, OBJPROP_YSIZE, 60);  // 高
      ObjectSetInteger(0, RectObjName, OBJPROP_BGCOLOR, InpBgColor);
      ObjectSetInteger(0, RectObjName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, RectObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, RectObjName, OBJPROP_BACK, false);
      ObjectSetInteger(0, RectObjName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, RectObjName, OBJPROP_HIDDEN, true);
   }
   
   // 创建文字
   if(ObjectFind(0, TextObjName) < 0)
   {
      ObjectCreate(0, TextObjName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, TextObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, TextObjName, OBJPROP_COLOR, InpTextColor);
      ObjectSetInteger(0, TextObjName, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetInteger(0, TextObjName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, TextObjName, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| 辅助函数：清理对象                                               |
//+------------------------------------------------------------------+
void DeleteObjects()
{
   ObjectDelete(0, LineObjName);
   ObjectDelete(0, RectObjName);
   ObjectDelete(0, TextObjName);
}
//+------------------------------------------------------------------+