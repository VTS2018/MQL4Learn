//+------------------------------------------------------------------+
//|                                         KT_Quick_Profit_Calc.mq4 |
//|                                Copyright 2023, Lovell Cecil.     |
//|                                            https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Lovell Cecil."
#property link      "https://www.mql5.com/zh/users/lovellcecil"
#property version   "1.00"
#property strict
#property indicator_chart_window

/*
我为您编写了一个名为 KT_Quick_Profit_Calc (KT 快速盈亏测算) 的指标。

指标功能特点：
左键拖拽测算：在图表任意位置按下鼠标左键并拖动，即可拉出一根测距线。

实时金额显示：鼠标旁边会跟随一个面板，实时显示 点数 (Points) 和 基于您设定手数的盈亏金额 (Money)。

自动清理：松开鼠标左键，测距线和数据显示自动消失，保持图表整洁。

配置灵活：可以在参数中修改默认手数（默认 0.01）、线条颜色等。
--------------------------------------------------------------------------------------
如何使用：
保存：将上面的代码复制，在 MT4 编辑器 (MetaEditor) 中新建一个指标，粘贴进去，保存为 KT_Quick_Profit_Calc.mq4，点击“编写 (Compile)”。

加载：回到 MT4 主图表，在“导航器” -> “指标”中找到它，拖拽到图表上。

设置：在弹出的参数窗口中，确认 InpDefaultLots 为 0.01 (或者改成你常用的 0.1, 1.0)。

操作：

在图表任意 K 线位置，按下鼠标左键不放。

拖动鼠标，你会看到一条金色的虚线，鼠标旁边会有一个黑色的小框。

框内会实时显示：如果你做 0.01 手，这段距离是多少点，价值多少美金（或其他账户货币）。

松开鼠标，所有绘图自动消失。

--------------------------------------------------------------------------------------
给编程人员的技术注解：
MarketInfo(Symbol(), MODE_TICKVALUE)：这是计算金额的核心。它会自动处理交叉盘、黄金、指数的汇率换算问题，返回的是“1手波动1个Point的本位币价值”。

ChartXYToTimePrice：这是将屏幕像素坐标 (X, Y) 转换为图表逻辑坐标 (Time, Price) 的关键函数。

OBJ_RECTANGLE_LABEL 和 OBJ_LABEL：我们使用这两种对象而不是 Comment()，因为它们可以精确定位在鼠标光标旁边，而不是固定在图表左上角，体验更接近 Ctrader。

*/

// >>> 新增这些描述 <<<
#property description "KT Quick Profit Calc (快速盈亏测算工具)"
#property description " "
#property description "功能特点："
#property description "1. 先点击MT4 十字光标。"
#property description "2. 按住 Ctrl + 鼠标左键拖拽，即可进行测距。"
#property description "3. 自动计算点数和对应的金额盈亏。"
#property description "4. 完美支持黄金、外汇、原油等所有品种。"

//--- 输入参数
// input double InpDefaultLots = 0.01;    // 测算手数 (默认 0.01)
// input color  InpLineColor   = clrBlack; // 测距线颜色
// input int    InpLineWidth   = 1;       // 测距线宽度
// input int    InpFontSize    = 10;      // 显示字体大小
// input color  InpTextColor   = clrWhite;// 字体颜色
// input color  InpBgColor     = clrBlack;// 提示框背景色

input double InpDefaultLots = 0.01;    // Calculation Lots (Default 0.01)
input color  InpLineColor   = clrBlack; // Measurement Line Color
input int    InpLineWidth   = 1;       // Line Width
input int    InpFontSize    = 10;      // Font Size
input color  InpTextColor   = clrWhite;// Text Color
input color  InpBgColor     = clrBlack;// Background Color

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