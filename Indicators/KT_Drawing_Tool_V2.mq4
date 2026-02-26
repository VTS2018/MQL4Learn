//+------------------------------------------------------------------+
//|                                           KT_Drawing_Tool.mq4    |
//|                                  Copyright 2024, CD_SMC_Analysis |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, KT Expert."
#property link      "https://www.mql5.com/zh/users/lovellcecil" // 换成你的主页链接
#property version   "2.00" // 初始版本
#property description "KT Drawing Tool - Professional SMC & PA Drawing Assistant"
#property description " "
#property description "Key Features:"
#property description "1. OHLC Magnetic Adsorption: Automatically snaps to Key Prices."
#property description "2. Multi-Timeframe Color Mapping: Auto-color based on H1/H4/D1."
#property description "3. One-Click Ray & Level Drawing."
#property description "4. Visual confirmations with checkmarks."
// #property icon      "Images\\KT_Logo.ico" // (可选) 如果你有做ICON的话

#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| 枚举：周期可见性模式
//+------------------------------------------------------------------+
enum ENUM_VISIBILITY_MODE
{
   VISIBILITY_ALL = 0,        // All Timeframes
   VISIBILITY_CURRENT = 1,    // Current Only
   VISIBILITY_LOWER = 2,      // Current & Lower TFs
   VISIBILITY_HIGHER = 3      // Current & Higher TFs
};

//--- 参数设置
// input color ColorHLine = clrRed;        // 水平线颜色
// input color ColorRay   = clrDeepSkyBlue;// 射线(趋势水平线)颜色
// input int   LineWidth  = 2;             // 线条宽度

input color ColorHLine = clrRed;          // Horizontal Line Color
input color ColorRay   = clrDeepSkyBlue;  // Ray Color (Segment)
input int   LineWidth  = 2;               // Line Width

//--- [新增] 周期可见性控制
input ENUM_VISIBILITY_MODE VisibilityMode = VISIBILITY_ALL; // Timeframe Visibility Mode

input color BtnBgColor  = clrGray;        // Button Background Color
input color BtnTxtColor = clrWhite;       // Button Text Color

//--- [新增] 周期专属颜色设置 (针对浅色背景 229,230,250 优化)
// input color Color_H1   = clrBlue;         // H1 周期颜色
// input color Color_H4   = clrDarkOrange;   // H4 周期颜色
// input color Color_D1   = clrRed;          // D1 周期颜色
// input color Color_W1   = clrDarkGreen;    // W1 周期颜色
// input color Color_MN1  = clrDarkViolet;   // MN1 周期颜色

input color Color_H1   = clrBlue;         // H1 Timeframe Color
input color Color_H4   = clrDarkOrange;   // H4 Timeframe Color
input color Color_D1   = clrRed;          // D1 Timeframe Color
input color Color_W1   = clrDarkGreen;    // W1 Timeframe Color
input color Color_MN1  = clrDarkViolet;   // MN1 Timeframe Color

//--- [新增] 关口线功能设置
input string Sep_Round = "======= Round Number Lines ======="; // ----
input bool   Enable_Round_100  = false;         // Enable 100 Round Lines
input bool   Enable_Round_50   = false;         // Enable 50 Round Lines
input bool   Enable_Round_10   = false;         // Enable 10 Round Lines
input bool   Enable_Round_5    = false;         // Enable 5 Round Lines
// [已废弃] input int Round_Lines_Range = 500;  // 现在自动使用图表可见范围

input color  Color_Round_100   = clrDarkSlateGray;  // 100 Round Line Color
input color  Color_Round_50    = clrGray;           // 50 Round Line Color
input color  Color_Round_10    = clrLightGray;      // 10 Round Line Color
input color  Color_Round_5     = clrSilver;         // 5 Round Line Color

input int    Width_Round_100   = 2;             // 100 Round Line Width
input int    Width_Round_50    = 2;             // 50 Round Line Width
input int    Width_Round_10    = 1;             // 10 Round Line Width
input int    Width_Round_5     = 1;             // 5 Round Line Width

input ENUM_LINE_STYLE Style_Round_Key    = STYLE_SOLID;  // Key Round Lines Style (100/50)
input ENUM_LINE_STYLE Style_Round_Normal = STYLE_DOT;    // Normal Round Lines Style (10/5)

//--- 内部变量
int drawingState = 0; // 0=无, 1=准备画水平线, 2=准备画射线
string btnName_MainMenu = "Btn_MainMenu";  // [新增] 主控菜单按钮
string btnName1 = "Btn_Draw_HLine";
string btnName2 = "Btn_Draw_Ray";
string btnName3 = "Btn_Clean_Current";
string btnName4 = "Btn_Clean_All";
string btnName5 = "Btn_Deselect_All";
string btnName6 = "Btn_Toggle_Mode";
string btnName7 = "Btn_Toggle_Magnet";
string btnName8 = "Btn_Stop_Mode";  // 新增：Stop模式按钮
string btnName9 = "Btn_Pinbar_Mode"; // [新增] Pinbar标注按钮
string btnName10 = "Btn_Force_Clear"; // [新增] 强制清除按钮
string btnName11 = "Btn_Lock_Lines";  // [新增] 锁定线条按钮

// [新增] 菜单折叠状态
bool isMenuExpanded = false;  // false=折叠, true=展开

// [全局变量] 记录最后一次点击按钮的时间 (用于防误触)
uint lastBtnClickTime = 0;

// [新增] 绘图模式控制
bool isPermanentMode = true;   // false=临时模式(Draw_), true=保持模式(Keep_) [默认Keep模式]
bool isMagneticMode = true;    // true=启用磁吸, false=禁用磁吸（直接使用点击价格）
int stopOrderMode = 0;         // 0=关闭, 1=BUY stop, 2=SELL stop
bool isPinbarMode = false;     // [新增] Pinbar标注模式
bool isLinesLocked = false;    // [新增] 线条锁定状态: false=解锁（可选择）, true=锁定（不可选择）

// [新增] 清除全部按钮的确认状态
bool cleanAllConfirmed = false;
uint cleanAllConfirmTime = 0;
const uint CONFIRM_TIMEOUT = 10000; // 10秒超时

// [新增] 存储对象对关系：记录每个画线对象及其关联的标记对象
string g_drawnObjects[][2];  // [][0]=线对象名, [][1]=标记对象名 

// [新增] 关口线管理变量
uint lastRoundLinesUpdate = 0;          // 上次更新关口线的时间
const uint ROUND_UPDATE_INTERVAL = 60000; // 关口线更新间隔（60秒） 

//+------------------------------------------------------------------+
//| 初始化函数
//+------------------------------------------------------------------+
int OnInit()
  {
   // [新增] 创建主控菜单按钮 (折叠时仅显示此按钮)
   CreateButton(btnName_MainMenu, "Menu", 150, 20, 80, 25, clrDodgerBlue, BtnTxtColor);
   
   // 创建UI按钮 (垂直排列，初始隐藏在屏幕外)
   CreateButton(btnName4, "Clean All", 150, -1000, 80, 25, clrMaroon,    BtnTxtColor); // 深红色警告
   CreateButton(btnName3, "Clean",     150, -1000, 80, 25, clrDarkOrange, BtnTxtColor); // 橙色提示
   CreateButton(btnName1, "Line (H)",  150, -1000, 80, 25, BtnBgColor,    BtnTxtColor); // 灰色常规
   CreateButton(btnName2, "Ray (R)",   150, -1000, 80, 25, BtnBgColor,    BtnTxtColor); // 灰色常规
   CreateButton(btnName5, "Unselect",  150, -1000, 80, 25, clrDarkSlateGray, BtnTxtColor); // 深灰色辅助
   CreateButton(btnName6, "Keep",      150, -1000, 80, 25, clrDarkGreen, BtnTxtColor); // 模式切换（默认Keep）
   CreateButton(btnName7, "Magnet",    150, -1000, 80, 25, clrGreen,     BtnTxtColor); // 磁吸切换
   CreateButton(btnName8, "Normal",    150, -1000, 80, 25, clrGray,      BtnTxtColor); // Stop模式
   CreateButton(btnName9, "Pinbar",    150, -1000, 80, 25, clrGray,      BtnTxtColor); // Pinbar标注
   CreateButton(btnName10, "Force Clear", 150, -1000, 80, 25, clrCrimson, BtnTxtColor); // 强制清除
   CreateButton(btnName11, "Unlock",     150, -1000, 80, 25, clrGray,    BtnTxtColor); // 锁定/解锁线条

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); // 开启鼠标捕捉
   
   // [新增] 启动定时器，每1秒检查一次对象是否被删除
   EventSetTimer(1);
   
   // [修复] 重启后重建对象关联关系
   RebuildObjectPairs();
   
   // [新增] 更新所有射线的终点到最新K线，防止射线"变短"
   UpdateRayEndpoints();
   
   // [新增] 绘制关口线
   DrawRoundNumberLines();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| 反初始化函数
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();  // 关闭定时器
   
   // [新增] 删除所有关口线
   DeleteRoundNumberLines();
   
   ObjectDelete(0, btnName_MainMenu);  // [新增] 删除主控按钮
   ObjectDelete(0, btnName1);
   ObjectDelete(0, btnName2);
   ObjectDelete(0, btnName3);
   ObjectDelete(0, btnName4);
   ObjectDelete(0, btnName5);
   ObjectDelete(0, btnName6);
   ObjectDelete(0, btnName7);
   ObjectDelete(0, btnName8);  // 删除Stop模式按钮
   ObjectDelete(0, btnName9);  // 删除Pinbar按钮
   ObjectDelete(0, btnName10); // 删除强制清除按钮
   ObjectDelete(0, btnName11); // 删除锁定线条按钮
   // Comment("");
  }

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| 图表事件处理函数 (核心逻辑)
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   // =================================================================
   // 1. 监听按钮点击事件
   // =================================================================
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // [新增] 处理主控菜单按钮点击
      if(sparam == btnName_MainMenu)
        {
         ObjectSetInteger(0, btnName_MainMenu, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 切换菜单展开状态
         isMenuExpanded = !isMenuExpanded;
         
         if(isMenuExpanded)
         {
            // 展开菜单：显示所有功能按钮
            ObjectSetString(0, btnName_MainMenu, OBJPROP_TEXT, "Menu [^]");
            ObjectSetInteger(0, btnName_MainMenu, OBJPROP_BGCOLOR, clrDarkOrange);
            SetButtonVisibility(btnName4, true, 50);   // Clean All
            SetButtonVisibility(btnName3, true, 80);   // Clean
            SetButtonVisibility(btnName1, true, 110);  // Line (H)
            SetButtonVisibility(btnName2, true, 140);  // Ray (R)
            SetButtonVisibility(btnName5, true, 170);  // Unselect
            SetButtonVisibility(btnName6, true, 200);  // KeyLevel
            SetButtonVisibility(btnName7, true, 230);  // Magnet
            SetButtonVisibility(btnName8, true, 260);  // Normal
            SetButtonVisibility(btnName9, true, 290);  // Pinbar
            SetButtonVisibility(btnName10, true, 320); // Force Clear
            SetButtonVisibility(btnName11, true, 350); // Lock/Unlock
         }
         else
         {
            // 折叠菜单：隐藏所有功能按钮
            ObjectSetString(0, btnName_MainMenu, OBJPROP_TEXT, "Menu");
            ObjectSetInteger(0, btnName_MainMenu, OBJPROP_BGCOLOR, clrDodgerBlue);
            SetButtonVisibility(btnName4, false, 0);
            SetButtonVisibility(btnName3, false, 0);
            SetButtonVisibility(btnName1, false, 0);
            SetButtonVisibility(btnName2, false, 0);
            SetButtonVisibility(btnName5, false, 0);
            SetButtonVisibility(btnName6, false, 0);
            SetButtonVisibility(btnName7, false, 0);
            SetButtonVisibility(btnName8, false, 0);
            SetButtonVisibility(btnName9, false, 0);
            SetButtonVisibility(btnName10, false, 0);
            SetButtonVisibility(btnName11, false, 0);
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      if(sparam == btnName1 || sparam == btnName2)
        {
         // [UI优化] 让按钮立刻“弹起”，取消按下的凹陷效果。修改以后一点按下去的效果都没了

         // ObjectSetInteger(0, sparam, OBJPROP_STATE, false); 
         // [交互优化] 这里不要强制弹起！让它保持按下状态，直到画图结束。
         
         // 互斥逻辑：如果点了按钮1，就把按钮2弹起来；反之亦然。
         if(sparam == btnName1) {
            drawingState = 1;
            ObjectSetInteger(0, btnName2, OBJPROP_STATE, false); // 确保另一个按钮是弹起的
         }
         if(sparam == btnName2) {
            drawingState = 2;
            ObjectSetInteger(0, btnName1, OBJPROP_STATE, false); // 确保另一个按钮是弹起的
         }

         // 设置状态
         // if(sparam == btnName1) drawingState = 1;
         // if(sparam == btnName2) drawingState = 2;
         
         // [核心修复] 记录点击时间，防止穿透
         lastBtnClickTime = GetTickCount(); 
         
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
         // Comment("【进入画图模式】\n请点击K线，将自动吸附 开/高/低/收 价格...");
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理清理按钮点击
      if(sparam == btnName3)
        {
         ObjectSetInteger(0, btnName3, OBJPROP_STATE, false); // 立即弹起按钮
         CleanCurrentPeriodObjects(); // 执行清理
         PlaySound("ok.wav");
         ChartRedraw();
        }
      
      // [新增] 处理清除全部按钮点击
      if(sparam == btnName4)
        {
         ObjectSetInteger(0, btnName4, OBJPROP_STATE, false); // 立即弹起按钮
         
         uint currentTime = GetTickCount();
         
         // 检查是否在确认时间窗口内
         if(cleanAllConfirmed && (currentTime - cleanAllConfirmTime < CONFIRM_TIMEOUT))
         {
            // 第二次点击，执行删除
            CleanAllObjects();
            cleanAllConfirmed = false; // 重置确认状态
            // 恢复按钮颜色为深红色
            ObjectSetInteger(0, btnName4, OBJPROP_BGCOLOR, clrMaroon);
            ChartRedraw();
         }
         else
         {
            // 第一次点击，要求确认
            cleanAllConfirmed = true;
            cleanAllConfirmTime = currentTime;
            
            // 改变按钮颜色为红色警告
            ObjectSetInteger(0, btnName4, OBJPROP_BGCOLOR, clrCrimson);
            
            Alert(" 警告：将删除所有画线！\n\n请再次点击 [Clean All] 按钮以确认删除\n(", CONFIRM_TIMEOUT/1000, "秒内有效)");
            PlaySound("alert.wav");
            ChartRedraw();
         }
        }
      
      // [新增] 处理取消选中按钮点击
      if(sparam == btnName5)
        {
         ObjectSetInteger(0, btnName5, OBJPROP_STATE, false); // 立即弹起按钮
         DeselectAllLines(); // 执行取消选中
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理模式切换按钮点击
      if(sparam == btnName6)
        {
         ObjectSetInteger(0, btnName6, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 切换模式
         isPermanentMode = !isPermanentMode;
         
         if(isPermanentMode)
         {
            // 切换到保持模式
            ObjectSetString(0, btnName6, OBJPROP_TEXT, "Keep");
            ObjectSetInteger(0, btnName6, OBJPROP_BGCOLOR, clrDarkGreen);
            Alert(" 已切换到【保持模式】\n画线将永久保留，不会被工具清理");
         }
         else
         {
            // 切换回关键位模式
            ObjectSetString(0, btnName6, OBJPROP_TEXT, "KeyLevel");
            ObjectSetInteger(0, btnName6, OBJPROP_BGCOLOR, clrGray);
            Alert(" 已切换到【关键位模式】\n画线可被工具按钮清理");
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理磁吸切换按钮点击
      if(sparam == btnName7)
        {
         ObjectSetInteger(0, btnName7, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 切换磁吸模式
         isMagneticMode = !isMagneticMode;
         
         if(isMagneticMode)
         {
            // 启用磁吸
            ObjectSetString(0, btnName7, OBJPROP_TEXT, "Magnet");
            ObjectSetInteger(0, btnName7, OBJPROP_BGCOLOR, clrGreen);
            Alert(" 磁吸功能已开启\n画线将自动吸附到最近的OHLC价格");
         }
         else
         {
            // 禁用磁吸
            ObjectSetString(0, btnName7, OBJPROP_TEXT, "Direct");
            ObjectSetInteger(0, btnName7, OBJPROP_BGCOLOR, clrGray);
            Alert(" 磁吸功能已关闭\n画线将直接使用鼠标点击价格");
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理Stop模式按钮点击
      if(sparam == btnName8)
        {
         ObjectSetInteger(0, btnName8, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 循环切换模式：Normal → BUY stop → SELL stop → Normal
         stopOrderMode = (stopOrderMode + 1) % 3;
         
         switch(stopOrderMode)
         {
            case 0:  // Normal模式
               ObjectSetString(0, btnName8, OBJPROP_TEXT, "Normal");
               ObjectSetInteger(0, btnName8, OBJPROP_BGCOLOR, clrGray);
               Alert(" 已切换到【普通模式】\n画线不带止损挂单标记");
               break;
            case 1:  // BUY stop模式
               ObjectSetString(0, btnName8, OBJPROP_TEXT, "BUY↑");
               ObjectSetInteger(0, btnName8, OBJPROP_BGCOLOR, clrGreen);
               Alert(" 已切换到【BUY stop模式】\n画线将自动标记为 [BUY stop]\n价格回调到此位置时做多");
               break;
            case 2:  // SELL stop模式
               ObjectSetString(0, btnName8, OBJPROP_TEXT, "SELL↓");
               ObjectSetInteger(0, btnName8, OBJPROP_BGCOLOR, clrRed);
               Alert(" 已切换到【SELL stop模式】\n画线将自动标记为 [SELL stop]\n价格回调到此位置时做空");
               break;
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理Pinbar模式按钮点击
      if(sparam == btnName9)
        {
         ObjectSetInteger(0, btnName9, OBJPROP_STATE, false); // 立即弹起按钮
         
         // 切换Pinbar模式
         isPinbarMode = !isPinbarMode;
         
         if(isPinbarMode)
         {
            // 启用Pinbar模式
            ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar [ON]");
            ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrDarkViolet);
            //Alert(" Pinbar标注模式已开启\n点击K线将自动识别Pinbar并画0.5/0.618位");
         }
         else
         {
            // 关闭Pinbar模式
            ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar");
            ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrGray);
            //Alert(" Pinbar标注模式已关闭");
         }
         
         PlaySound("tick.wav");
         ChartRedraw();
        }
      
      // [新增] 处理强制清除按钮点击
      if(sparam == btnName10)
        {
         ObjectSetInteger(0, btnName10, OBJPROP_STATE, false); // 立即弹起按钮
         ForceCleanAllObjects(); // 强制清除所有对象
         PlaySound("ok.wav");
         ChartRedraw();
        }
      
      // [新增] 处理锁定/解锁按钮点击
      if(sparam == btnName11)
        {
         ObjectSetInteger(0, btnName11, OBJPROP_STATE, false); // 立即弹起按钮
         ToggleLinesLock(); // 切换锁定状态
         PlaySound("tick.wav");
         ChartRedraw();
        }
     }

   // =================================================================
   // 2. 监听图表点击事件 (画图动作)
   // =================================================================
   if(id == CHARTEVENT_CLICK)
     {
      // [核心防御] 如果距离上次点按钮不到 500ms，忽略这次点击
      if (GetTickCount() - lastBtnClickTime < 500) return;

      if(drawingState != 0)
        {
         datetime dt = 0;
         double price = 0;
         int window = 0;
         
         if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, window, dt, price))
           {
            // -------------------------------------------------------------
            // 核心功能升级：全能磁吸逻辑 (OHLC Adsorption)
            // -------------------------------------------------------------
            int barIndex = iBarShift(NULL, 0, dt); // 找到点击位置对应的K线索引
            double finalPrice;
            
            // 获取K线的OHLC数据（用于磁吸计算和Check标记判断）
            double high  = iHigh(NULL, 0, barIndex);
            double low   = iLow(NULL, 0, barIndex);
            double open  = iOpen(NULL, 0, barIndex);
            double close = iClose(NULL, 0, barIndex);
            
            if(isMagneticMode) // 启用磁吸
            {
               // 计算鼠标点击位置与这四个价格的距离
               double distH = MathAbs(price - high);
               double distL = MathAbs(price - low);
               double distO = MathAbs(price - open);
               double distC = MathAbs(price - close);
               
               // 找出距离最近的那个价格
               finalPrice = high;      // 默认先假设 High 最近
               double minDist = distH; // 记录最小距离
               
               if(distL < minDist) { minDist = distL; finalPrice = low;   }
               if(distO < minDist) { minDist = distO; finalPrice = open;  }
               if(distC < minDist) { minDist = distC; finalPrice = close; }
            }
            else // 禁用磁吸，直接使用鼠标点击价格
            {
               finalPrice = price; // 直接使用鼠标点击位置的价格
            }
            
            // -------------------------------------------------------------
            // [新增] Pinbar模式检测与处理
            // -------------------------------------------------------------
            if(isPinbarMode)
            {
               // 递进检测：先尝试严格标准，再尝试宽松标准
               int pinbarType = IsPinbar(barIndex);
               if(pinbarType == 0)  // 严格检测失败，尝试宽松检测
               {
                  pinbarType = IsPinbarV2(barIndex);
               }
               
               if(pinbarType == 0)
               {
                  // 不是Pinbar，提示并退出
                  Alert(" 这不是一个标准Pinbar！\n请选择具有明显长影线的K线");
                  PlaySound("timeout.wav");
                  // 重置状态
                  drawingState = 0;
                  ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
                  ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
                  ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
                  ChartRedraw();
                  return;
               }
               
               // 是Pinbar，计算0.5和0.618位置
               double level50, level618;
               string pinbarTypeStr;
               
               if(pinbarType == 1)  // 看涨Pinbar（长下影线，从高到低回撤）
               {
                  double range = high - low;
                  // 斐波0%=最高价, 100%=最低价
                  level50  = high - range * 0.5;    // 50%回撤（在上方）
                  level618 = high - range * 0.618;  // 61.8%回撤（在下方）
                  pinbarTypeStr = "[Bull Pin]";
               }
               else  // 看跌Pinbar (pinbarType == 2)（长上影线，从低到高回撤）
               {
                  double range = high - low;
                  // 斐波0%=最低价, 100%=最高价
                  level50  = low + range * 0.5;     // 50%回撤（在下方）
                  level618 = low + range * 0.618;   // 61.8%回撤（在上方）
                  pinbarTypeStr = "[Bear Pin]";
               }
               
               // [新增] 自动匹配周期颜色（与常规模式保持一致）
               color levelColor;
               int p = Period();
               
               if      (p == PERIOD_H1)  levelColor = Color_H1;
               else if (p == PERIOD_H4)  levelColor = Color_H4;
               else if (p == PERIOD_D1)  levelColor = Color_D1;
               else if (p == PERIOD_W1)  levelColor = Color_W1;
               else if (p == PERIOD_MN1) levelColor = Color_MN1;
               else
               {
                  // 如果不是特定周期，使用默认设置 (区分水平线和射线)
                  levelColor = (drawingState == 1) ? ColorHLine : ColorRay;
               }
               
               // 画两条线（0.5和0.618）
               string tfStr = GetPeriodName(Period());
               string uniqueID = IntegerToString(GetTickCount());
               string prefix = isPermanentMode ? "Keep_" : "Draw_";
               
               // 第一条线：0.5位
               string objName50 = prefix + tfStr + "_Pin50_" + uniqueID;
               // 第二条线：0.618位
               string objName618 = prefix + tfStr + "_Pin618_" + uniqueID;
               
               // 应用周期可见性设置
               int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
               
               if(drawingState == 1)  // 画水平线
               {
                  // 创建0.5线
                  ObjectCreate(0, objName50, OBJ_HLINE, 0, 0, level50);
                  ObjectSetInteger(0, objName50, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, objName50, OBJPROP_WIDTH, LineWidth);
                  ObjectSetInteger(0, objName50, OBJPROP_STYLE, STYLE_DOT);  // 虚线
                  ObjectSetString(0, objName50, OBJPROP_TEXT, pinbarTypeStr + " 0.5 @" + DoubleToString(level50, Digits));
                  ObjectSetInteger(0, objName50, OBJPROP_SELECTABLE, !isLinesLocked);
                  ObjectSetInteger(0, objName50, OBJPROP_TIMEFRAMES, visibilityFlags);
                  
                  // 创建0.618线
                  ObjectCreate(0, objName618, OBJ_HLINE, 0, 0, level618);
                  ObjectSetInteger(0, objName618, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, objName618, OBJPROP_WIDTH, LineWidth);
                  ObjectSetString(0, objName618, OBJPROP_TEXT, pinbarTypeStr + " 0.618 @" + DoubleToString(level618, Digits));
                  ObjectSetInteger(0, objName618, OBJPROP_SELECTABLE, !isLinesLocked);
                  ObjectSetInteger(0, objName618, OBJPROP_TIMEFRAMES, visibilityFlags);
               }
               else if(drawingState == 2)  // 画射线
               {
                  datetime time1 = iTime(NULL, 0, barIndex);
                  datetime currentTime = iTime(Symbol(), Period(), 0);
                  
                  // 创建0.5射线
                  ObjectCreate(0, objName50, OBJ_TREND, 0, time1, level50, currentTime, level50);
                  ObjectSetInteger(0, objName50, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, objName50, OBJPROP_WIDTH, LineWidth);
                  ObjectSetInteger(0, objName50, OBJPROP_STYLE, STYLE_DOT);
                  ObjectSetInteger(0, objName50, OBJPROP_RAY_RIGHT, false);
                  ObjectSetString(0, objName50, OBJPROP_TEXT, pinbarTypeStr + " 0.5 @" + DoubleToString(level50, Digits));
                  ObjectSetInteger(0, objName50, OBJPROP_SELECTABLE, !isLinesLocked);
                  ObjectSetInteger(0, objName50, OBJPROP_TIMEFRAMES, visibilityFlags);
                  
                  // 创建0.618射线
                  ObjectCreate(0, objName618, OBJ_TREND, 0, time1, level618, currentTime, level618);
                  ObjectSetInteger(0, objName618, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, objName618, OBJPROP_WIDTH, LineWidth);
                  ObjectSetInteger(0, objName618, OBJPROP_RAY_RIGHT, false);
                  ObjectSetString(0, objName618, OBJPROP_TEXT, pinbarTypeStr + " 0.618 @" + DoubleToString(level618, Digits));
                  ObjectSetInteger(0, objName618, OBJPROP_SELECTABLE, !isLinesLocked);
                  ObjectSetInteger(0, objName618, OBJPROP_TIMEFRAMES, visibilityFlags);
                  
                  // 创建价格标签
                  string labelPrefix = isPermanentMode ? "KeepLabel_" : "PriceLabel_";
                  string priceLabel50 = labelPrefix + tfStr + "_Pin50_" + uniqueID;
                  string priceLabel618 = labelPrefix + tfStr + "_Pin618_" + uniqueID;
                  
                  ObjectCreate(0, priceLabel50, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, level50);
                  ObjectSetInteger(0, priceLabel50, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, priceLabel50, OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0, priceLabel50, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, priceLabel50, OBJPROP_HIDDEN, true);
                  RecordObjectPair(objName50, priceLabel50);
                  
                  ObjectCreate(0, priceLabel618, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, level618);
                  ObjectSetInteger(0, priceLabel618, OBJPROP_COLOR, levelColor);
                  ObjectSetInteger(0, priceLabel618, OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0, priceLabel618, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, priceLabel618, OBJPROP_HIDDEN, true);
                  RecordObjectPair(objName618, priceLabel618);
               }
               /*
               // 在Pinbar的尾部画标记（长影线端）
               datetime time1 = iTime(NULL, 0, barIndex);
               double markPrice = (pinbarType == 1) ? low : high;
               
               string markPrefix = isPermanentMode ? "KeepMark_" : "Mark_";
               string markName = markPrefix + tfStr + "_PinMark_" + uniqueID;
               
               int arrowCode = (pinbarType == 1) ? 233 : 234;  // 233=向上箭头, 234=向下箭头
               ObjectCreate(0, markName, OBJ_ARROW, 0, time1, markPrice);
               ObjectSetInteger(0, markName, OBJPROP_ARROWCODE, arrowCode);
               ObjectSetInteger(0, markName, OBJPROP_COLOR, levelColor);
               ObjectSetInteger(0, markName, OBJPROP_WIDTH, 3);
               ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, markName, OBJPROP_HIDDEN, true);
               RecordObjectPair(objName50, markName);
               */
               PlaySound("ok.wav");
               //Alert(" Pinbar识别成功！\n类型：", pinbarTypeStr, "\n已画0.5和0.618位");
               
               // 重置状态
               isPinbarMode = false;  // 自动关闭Pinbar模式
               ObjectSetString(0, btnName9, OBJPROP_TEXT, "Pinbar");
               ObjectSetInteger(0, btnName9, OBJPROP_BGCOLOR, clrGray);
               
               drawingState = 0;
               ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
               ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
               ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
               ChartRedraw();
               return;  // 跳过常规画线逻辑
            }
            
            // -------------------------------------------------------------
            // 执行画图（常规模式）
            // -------------------------------------------------------------
            string tfStr = GetPeriodName(Period());
            // [修改] 生成唯一ID，用于关联线条和标记
            string uniqueID = IntegerToString(GetTickCount());
            // [新增] 根据模式动态生成对象前缀
            string prefix = isPermanentMode ? "Keep_" : "Draw_";
            string objName = prefix + tfStr + "_" + uniqueID;

            // --- [新增] 自动匹配周期颜色 ---
            color finalColor;
            int p = Period();

            if      (p == PERIOD_H1)  finalColor = Color_H1;
            else if (p == PERIOD_H4)  finalColor = Color_H4;
            else if (p == PERIOD_D1)  finalColor = Color_D1;
            else if (p == PERIOD_W1)  finalColor = Color_W1;
            else if (p == PERIOD_MN1) finalColor = Color_MN1;
            else
            {
               // 如果不是特定周期，使用默认设置 (区分水平线和射线)
               finalColor = (drawingState == 1) ? ColorHLine : ColorRay;
            }
            // ------------------------------

            if(drawingState == 1) // 画水平线
              {
               ObjectCreate(0, objName, OBJ_HLINE, 0, 0, finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, !isLinesLocked);
               
               // [新增] 应用周期可见性设置
               int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
               ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, visibilityFlags);
               
               // ⭐[新增] 根据Stop模式自动设置画线描述
               if(stopOrderMode == 1)
                  ObjectSetString(0, objName, OBJPROP_TEXT, "[BUY stop]");
               else if(stopOrderMode == 2)
                  ObjectSetString(0, objName, OBJPROP_TEXT, "[SELL stop]");
               
               // [新增功能] 在磁吸的K线上绘制Check标记（仅在磁吸模式下）
               if(isMagneticMode)
               {
                  bool isBullish = (close > open); // 判断阳线/阴线
                  double markPrice = isBullish ? (high + 5 * Point) : (low - 5 * Point); // 阳线标记在最高价上方，阴线在最低价下方
                  datetime time1 = iTime(NULL, 0, barIndex);
                  // [修改] 使用相同的uniqueID，建立名称关联，根据模式使用不同前缀
                  string markPrefix = isPermanentMode ? "KeepMark_" : "Mark_";
                  string markName = markPrefix + tfStr + "_" + uniqueID;
                  
                  ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, time1, markPrice);
                  ObjectSetInteger(0, markName, OBJPROP_COLOR, finalColor);
                  ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, markName, OBJPROP_ANCHOR, isBullish ? ANCHOR_BOTTOM : ANCHOR_TOP); // 阳线锚点在下，阴线锚点在上
                  ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, markName, OBJPROP_HIDDEN, true);
                  // [新增] 记录对象对关系
                  RecordObjectPair(objName, markName);
               }
              }
            else if(drawingState == 2) // 画射线
              {
               datetime time1 = iTime(NULL, 0, barIndex);
               // [修夏] 使用 iTime 获取当前K线时间
               datetime currentTime = iTime(Symbol(), Period(), 0);
               ObjectCreate(0, objName, OBJ_TREND, 0, time1, finalPrice, currentTime, finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, !isLinesLocked);
               
               // [新增] 应用周期可见性设置
               int visibilityFlags = CalculateVisibilityFlags(Period(), VisibilityMode);
               ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, visibilityFlags);
               
               // ⭐[新增] 根据Stop模式自动设置画线描述
               if(stopOrderMode == 1)
                  ObjectSetString(0, objName, OBJPROP_TEXT, "[BUY stop]");
               else if(stopOrderMode == 2)
                  ObjectSetString(0, objName, OBJPROP_TEXT, "[SELL stop]");
               
               // [新增功能] 在图表右侧价格轴显示射线价格标签
               // [修改] 使用uniqueID建立关联，根据模式使用不同前缀
               string labelPrefix = isPermanentMode ? "KeepLabel_" : "PriceLabel_";
               string priceLabelName = labelPrefix + tfStr + "_" + uniqueID;
               ObjectCreate(0, priceLabelName, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, finalPrice);
               ObjectSetInteger(0, priceLabelName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, priceLabelName, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, priceLabelName, OBJPROP_SELECTABLE, false); // 不可选中，避免干扰
               ObjectSetInteger(0, priceLabelName, OBJPROP_HIDDEN, true); // 在对象列表中隐藏
               // 价格标签关联到射线
               RecordObjectPair(objName, priceLabelName);
               
               // [新增功能] 在磁吸的K线上绘制Check标记（仅在磁吸模式下）
               if(isMagneticMode)
               {
                  bool isBullish = (close > open); // 判断阳线/阴线
                  double markPrice = isBullish ? (high + 5 * Point) : (low - 5 * Point); // 阳线标记在最高价上方，阴线在最低价下方
                  // [修改] 使用相同的uniqueID，根据模式使用不同前缀
                  string markPrefix = isPermanentMode ? "KeepMark_" : "Mark_";
                  string markName = markPrefix + tfStr + "_" + uniqueID;
                  
                  ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, time1, markPrice);
                  ObjectSetInteger(0, markName, OBJPROP_COLOR, finalColor);
                  ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
                  ObjectSetInteger(0, markName, OBJPROP_ANCHOR, isBullish ? ANCHOR_BOTTOM : ANCHOR_TOP); // 阳线锚点在下，阴线锚点在上
                  ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, markName, OBJPROP_HIDDEN, true);
                  // [新增] 记录对象对关系
                  RecordObjectPair(objName, markName);
               }
              }
            
            ChartRedraw();
            PlaySound("ok.wav");
           }
         
         // [交互优化] 画完图了！现在才把按钮弹起来，表示“任务结束”
         ObjectSetInteger(0, btnName1, OBJPROP_STATE, false);
         ObjectSetInteger(0, btnName2, OBJPROP_STATE, false);
           
         // 3. 重置状态
         drawingState = 0;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true); 
         // Comment("");
         ChartRedraw(); // 强制刷新界面状态
        }
     }
   
   // =================================================================
   // 3. 监听图表变化事件（缩放、滚动）
   // =================================================================
   if(id == CHARTEVENT_CHART_CHANGE)
     {
      // 当图表缩放或滚动时，更新关口线
      UpdateRoundNumberLines();
     }
  }

//+------------------------------------------------------------------+
//| 辅助函数：创建按钮
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int w, int h, color bg, color txt)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, txt);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
     }
  }

//+------------------------------------------------------------------+
//| [新增] 辅助函数：获取周期短名称
//+------------------------------------------------------------------+
string GetPeriodName(int p)
{
   switch(p)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
   }
   return "Unknown";
}

//+------------------------------------------------------------------+
//| [新增] 辅助函数：计算周期可见性标志位
//+------------------------------------------------------------------+
int CalculateVisibilityFlags(int currentPeriod, ENUM_VISIBILITY_MODE mode)
{
   // 模式 A：全周期可见（默认）
   if(mode == VISIBILITY_ALL)
   {
      return OBJ_ALL_PERIODS; // 0x1FF
   }
   
   // 定义周期层级映射表（从小到大）
   int periods[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
   int flags[]   = {0x0001,    0x0002,    0x0004,     0x0008,     0x0010,    0x0020,    0x0040,    0x0080,    0x0100};
   
   int currentIndex = -1;
   int currentFlag = 0;
   
   // 找到当前周期在数组中的位置
   for(int i = 0; i < ArraySize(periods); i++)
   {
      if(periods[i] == currentPeriod)
      {
         currentIndex = i;
         currentFlag = flags[i];
         break;
      }
   }
   
   // 如果当前周期不在标准列表中，返回全周期可见
   if(currentIndex == -1) return OBJ_ALL_PERIODS;
   
   // 模式 B：仅当前周期
   if(mode == VISIBILITY_CURRENT)
   {
      return currentFlag;
   }
   
   // 模式 C：当前及更小周期
   if(mode == VISIBILITY_LOWER)
   {
      int result = 0;
      for(int i = 0; i <= currentIndex; i++)
      {
         result |= flags[i];
      }
      return result;
   }
   
   // 模式 D：当前及更大周期
   if(mode == VISIBILITY_HIGHER)
   {
      int result = 0;
      for(int i = currentIndex; i < ArraySize(periods); i++)
      {
         result |= flags[i];
      }
      return result;
   }
   
   // 默认返回全周期
   return OBJ_ALL_PERIODS;
}

//+------------------------------------------------------------------+
//| [新增] 定时器事件处理：检查并清理孤立的标记对象
//+------------------------------------------------------------------+
void OnTimer()
{
   CheckAndCleanOrphanedObjects();
   
   // [新增] 检查Clean All确认超时
   if(cleanAllConfirmed && (GetTickCount() - cleanAllConfirmTime >= CONFIRM_TIMEOUT))
   {
      cleanAllConfirmed = false;
      // 恢复按钮颜色为深红色
      ObjectSetInteger(0, btnName4, OBJPROP_BGCOLOR, clrMaroon);
      ChartRedraw();
   }
   
   // [新增] 定期更新关口线
   uint currentTime = GetTickCount();
   if(currentTime - lastRoundLinesUpdate >= ROUND_UPDATE_INTERVAL)
   {
      UpdateRoundNumberLines();
      lastRoundLinesUpdate = currentTime;
   }
}

//+------------------------------------------------------------------+
//| [新增] 记录对象对关系
//+------------------------------------------------------------------+
void RecordObjectPair(string mainObj, string associatedObj)
{
   int size = ArraySize(g_drawnObjects) / 2;
   ArrayResize(g_drawnObjects, size + 1);
   g_drawnObjects[size][0] = mainObj;
   g_drawnObjects[size][1] = associatedObj;
}

//+------------------------------------------------------------------+
//| [新增] 检查并清理孤立的标记对象
//+------------------------------------------------------------------+
void CheckAndCleanOrphanedObjects()
{
   int size = ArraySize(g_drawnObjects) / 2;
   
   for(int i = size - 1; i >= 0; i--)
   {
      string mainObj = g_drawnObjects[i][0];
      string assocObj = g_drawnObjects[i][1];
      
      // 如果主对象（线条）不存在了，删除关联对象（标记）
      if(ObjectFind(0, mainObj) == -1)
      {
         if(ObjectFind(0, assocObj) >= 0)
         {
            ObjectDelete(0, assocObj);
         }
         
         // 从数组中移除这一对
         RemoveObjectPair(i);
      }
   }
}

//+------------------------------------------------------------------+
//| [新增] 从数组中移除指定索引的对象对
//+------------------------------------------------------------------+
void RemoveObjectPair(int index)
{
   int size = ArraySize(g_drawnObjects) / 2;
   
   // 将后面的元素前移
   for(int i = index; i < size - 1; i++)
   {
      g_drawnObjects[i][0] = g_drawnObjects[i + 1][0];
      g_drawnObjects[i][1] = g_drawnObjects[i + 1][1];
   }
   
   // 缩小数组
   ArrayResize(g_drawnObjects, size - 1);
}

//+------------------------------------------------------------------+
//| [新增] 重启后重建对象对关系
//+------------------------------------------------------------------+
void RebuildObjectPairs()
{
   // 清空现有数组
   ArrayResize(g_drawnObjects, 0);
   
   int total = ObjectsTotal(0, 0, -1);
   int drawCount = 0;  // Draw对象计数
   int keepCount = 0;  // Keep对象计数
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检测对象前缀类型
      bool isDrawObject = (StringFind(objName, "Draw_") == 0);
      bool isKeepObject = (StringFind(objName, "Keep_") == 0);
      
      // 处理以 "Draw_" 或 "Keep_" 开头的线条对象
      if(isDrawObject || isKeepObject)
      {
         // 提取对象名称中的周期和uniqueID
         // 格式: "Draw_H1_1234567890" 或 "Keep_H1_1234567890"
         // Pinbar格式: "Keep_H1_Pin50_1234567890" 或 "Keep_H1_Pin618_1234567890"
         string parts[];
         int count = StringSplit(objName, '_', parts);
         
         if(count >= 3)
         {
            string prefix = parts[0];   // "Draw" 或 "Keep"
            string tfStr = parts[1];    // "H1"
            
            // 根据前缀确定关联对象的名称格式
            string markPrefix = (prefix == "Draw") ? "Mark_" : "KeepMark_";
            string labelPrefix = (prefix == "Draw") ? "PriceLabel_" : "KeepLabel_";
            
            // [修复] 检查是否为Pinbar对象（4段式命名）
            bool isPinbarObj = (count >= 4 && (parts[2] == "Pin50" || parts[2] == "Pin618"));
            
            string markName, priceLabelName;
            
            if(isPinbarObj)
            {
               // Pinbar对象：Keep_H1_Pin50_12345
               // 构建标签名：KeepLabel_H1_Pin50_12345
               string pinType = parts[2];  // "Pin50" 或 "Pin618"
               string uniqueID = parts[3]; // "12345"
               
               markName = markPrefix + tfStr + "_" + pinType + "_" + uniqueID;
               priceLabelName = labelPrefix + tfStr + "_" + pinType + "_" + uniqueID;
            }
            else
            {
               // 普通对象：Keep_H1_12345
               // 构建标签名：KeepLabel_H1_12345
               string uniqueID = parts[2]; // "12345"
               
               markName = markPrefix + tfStr + "_" + uniqueID;
               priceLabelName = labelPrefix + tfStr + "_" + uniqueID;
            }
            
            // 查找对应的标记对象
            if(ObjectFind(0, markName) >= 0)
            {
               RecordObjectPair(objName, markName);
            }
            
            // 查找对应的价格标签对象（如果是射线）
            if(ObjectFind(0, priceLabelName) >= 0)
            {
               RecordObjectPair(objName, priceLabelName);
            }
            
            // 统计计数
            if(isDrawObject) drawCount++;
            else keepCount++;
         }
      }
   }
   
   // 输出日志（可选，用于调试）
   int pairCount = ArraySize(g_drawnObjects) / 2;
   Print("重建对象关联: 找到 ", drawCount, " 个Draw对象, ", keepCount, " 个Keep对象, 共 ", pairCount, " 对关联");
}

//+------------------------------------------------------------------+
//| [新增] 更新所有射线的终点到最新K线
//+------------------------------------------------------------------+
void UpdateRayEndpoints()
{
   int total = ObjectsTotal(0, 0, -1);
   
   // [修复] 使用 iTime 代替 Time[0]，防止数组越界
   datetime currentTime = iTime(Symbol(), Period(), 0);
   
   // [保护] 如果时间为0，说明数据未加载完成
   if(currentTime == 0)
   {
      Print("跳过射线更新：数据未就绪");
      return;
   }
   
   int updateCount = 0;
   int drawCount = 0;  // Draw射线计数
   int keepCount = 0;  // Keep射线计数
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检测对象前缀类型
      bool isDrawObject = (StringFind(objName, "Draw_") == 0);
      bool isKeepObject = (StringFind(objName, "Keep_") == 0);
      
      // 处理射线对象（以 "Draw_" 或 "Keep_" 开头的 OBJ_TREND）
      if((isDrawObject || isKeepObject) && ObjectGetInteger(0, objName, OBJPROP_TYPE) == OBJ_TREND)
      {
         // 获取射线的价格
         double price = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
         
         // 更新射线的第二个时间点到当前K线
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, currentTime);
         ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price);
         updateCount++;
         
         // 统计计数
         if(isDrawObject) drawCount++;
         else keepCount++;
         
         // 同时更新对应的价格标签位置
         string parts[];
         int count = StringSplit(objName, '_', parts);
         if(count >= 3)
         {
            string prefix = parts[0];   // "Draw" 或 "Keep"
            string tfStr = parts[1];
            
            // 根据前缀确定价格标签名称
            string labelPrefix = (prefix == "Draw") ? "PriceLabel_" : "KeepLabel_";
            
            // [修复] 检查是否为Pinbar对象（4段式命名）
            bool isPinbarObj = (count >= 4 && (parts[2] == "Pin50" || parts[2] == "Pin618"));
            
            string priceLabelName;
            
            if(isPinbarObj)
            {
               // Pinbar对象：Keep_H1_Pin50_12345 → KeepLabel_H1_Pin50_12345
               string pinType = parts[2];  // "Pin50" 或 "Pin618"
               string uniqueID = parts[3]; // "12345"
               priceLabelName = labelPrefix + tfStr + "_" + pinType + "_" + uniqueID;
            }
            else
            {
               // 普通对象：Keep_H1_12345 → KeepLabel_H1_12345
               string uniqueID = parts[2]; // "12345"
               priceLabelName = labelPrefix + tfStr + "_" + uniqueID;
            }
            
            if(ObjectFind(0, priceLabelName) >= 0)
            {
               ObjectSetInteger(0, priceLabelName, OBJPROP_TIME, 0, currentTime);
               ObjectSetDouble(0, priceLabelName, OBJPROP_PRICE, 0, price);
            }
         }
      }
   }
   
   if(updateCount > 0)
   {
      Print("更新射线终点: 共更新 ", updateCount, " 条射线 (Draw:", drawCount, " Keep:", keepCount, ") 到最新K线");
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| [新增] 清理当前周期的水平线和射线对象
//+------------------------------------------------------------------+
void CleanCurrentPeriodObjects()
{
   string currentTF = GetPeriodName(Period());
   string prefix = "Draw_" + currentTF + "_";
   
   int total = ObjectsTotal(0, 0, -1);
   int deleteCount = 0;
   
   // 从后向前遍历，避免删除后索引变化
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是当前周期的绘图对象
      if(StringFind(objName, prefix) == 0)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         // 只删除水平线和射线（趋势线）
         if(objType == OBJ_HLINE || objType == OBJ_TREND)
         {
            // 提取uniqueID，删除关联的标记和价格标签
            string parts[];
            int count = StringSplit(objName, '_', parts);
            
            if(count >= 3)
            {
               string tfStr = parts[1];
               string uniqueID = parts[2];
               
               // 删除关联的标记对象
               string markName = "Mark_" + tfStr + "_" + uniqueID;
               if(ObjectFind(0, markName) >= 0)
               {
                  ObjectDelete(0, markName);
               }
               
               // 删除关联的价格标签（射线）
               string priceLabelName = "PriceLabel_" + tfStr + "_" + uniqueID;
               if(ObjectFind(0, priceLabelName) >= 0)
               {
                  ObjectDelete(0, priceLabelName);
               }
               
               // 从数组中移除关联记录
               int arraySize = ArraySize(g_drawnObjects) / 2;
               for(int j = arraySize - 1; j >= 0; j--)
               {
                  if(g_drawnObjects[j][0] == objName)
                  {
                     RemoveObjectPair(j);
                  }
               }
            }
            
            // 删除主对象
            ObjectDelete(0, objName);
            deleteCount++;
         }
      }
   }
   
   if(deleteCount > 0)
   {
      Print("已清理当前周期 [", currentTF, "] 的绘图对象: ", deleteCount, " 个");
   }
   else
   {
      Print("当前周期 [", currentTF, "] 没有可清理的对象");
   }
}

//+------------------------------------------------------------------+
//| [新增] 清除所有由本工具创建的对象
//+------------------------------------------------------------------+
void CleanAllObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   int deleteCount = 0;
   
   // 从后向前遍历，避免删除后索引变化
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是由本工具创建的对象（以 "Draw_" 开头）
      if(StringFind(objName, "Draw_") == 0)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         // 只删除水平线和射线
         if(objType == OBJ_HLINE || objType == OBJ_TREND)
         {
            // 提取uniqueID，删除关联的标记和价格标签
            string parts[];
            int count = StringSplit(objName, '_', parts);
            
            if(count >= 3)
            {
               string tfStr = parts[1];
               string uniqueID = parts[2];
               
               // 删除关联的标记对象
               string markName = "Mark_" + tfStr + "_" + uniqueID;
               if(ObjectFind(0, markName) >= 0)
               {
                  ObjectDelete(0, markName);
               }
               
               // 删除关联的价格标签（射线）
               string priceLabelName = "PriceLabel_" + tfStr + "_" + uniqueID;
               if(ObjectFind(0, priceLabelName) >= 0)
               {
                  ObjectDelete(0, priceLabelName);
               }
            }
            
            // 删除主对象
            ObjectDelete(0, objName);
            deleteCount++;
         }
      }
   }
   
   // 清空关联数组
   ArrayResize(g_drawnObjects, 0);
   
   if(deleteCount > 0)
   {
      Print("已清除所有画线对象: ", deleteCount, " 个");
      PlaySound("ok.wav");
      ChartRedraw();
   }
   else
   {
      Print("没有可清除的对象");
   }
}

//+------------------------------------------------------------------+
//| [新增] 取消所有水平线和射线的选中状态
//+------------------------------------------------------------------+
void DeselectAllLines()
{
   int total = ObjectsTotal(0, 0, -1);
   int deselectCount = 0;
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是由本工具创建的对象（以 "Draw_" 或 "Keep_" 开头）
      bool isDrawObject = (StringFind(objName, "Draw_") == 0);
      bool isKeepObject = (StringFind(objName, "Keep_") == 0);
      
      if(isDrawObject || isKeepObject)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         // 只处理水平线和射线
         if(objType == OBJ_HLINE || objType == OBJ_TREND)
         {
            // 检查是否处于选中状态
            bool isSelected = (bool)ObjectGetInteger(0, objName, OBJPROP_SELECTED);
            
            if(isSelected)
            {
               // 取消选中
               ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
               deselectCount++;
            }
         }
      }
   }
   
   if(deselectCount > 0)
   {
      Print("已取消选中 ", deselectCount, " 个对象");
   }
   else
   {
      Print("没有处于选中状态的对象");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| [新增] 切换线条锁定状态（防止误操作）
//+------------------------------------------------------------------+
void ToggleLinesLock()
{
   // 切换锁定状态
   isLinesLocked = !isLinesLocked;
   
   // 遍历所有对象
   int total = ObjectsTotal(0, 0, -1);
   int affectedCount = 0;
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是工具创建的线条对象
      bool isDrawObject = (StringFind(objName, "Draw_") == 0);
      bool isKeepObject = (StringFind(objName, "Keep_") == 0);
      
      if(isDrawObject || isKeepObject)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         // 只处理水平线和射线（不包括辅助标记）
         if(objType == OBJ_HLINE || objType == OBJ_TREND)
         {
            // 设置可选状态（锁定时=false，解锁时=true）
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, !isLinesLocked);
            affectedCount++;
         }
      }
   }
   
   // 更新按钮样式和提示
   if(isLinesLocked)
   {
      ObjectSetString(0, btnName11, OBJPROP_TEXT, "Locked");
      ObjectSetInteger(0, btnName11, OBJPROP_BGCOLOR, clrGoldenrod);
      //Alert(" 线条已锁定\n所有射线和水平线无法选择，防止误操作");
   }
   else
   {
      ObjectSetString(0, btnName11, OBJPROP_TEXT, "Unlock");
      ObjectSetInteger(0, btnName11, OBJPROP_BGCOLOR, clrGray);
      //Alert(" 线条已解锁\n可以正常选择和移动线条");
   }
   
   Print("锁定状态切换: ", (isLinesLocked ? "已锁定" : "已解锁"), ", 影响 ", affectedCount, " 个对象");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| [新增] 辅助函数：显示/隐藏按钮
//+------------------------------------------------------------------+
void SetButtonVisibility(string btnName, bool visible, int yPos)
{
   if(visible)
   {
      // 显示按钮：恢复到指定的Y坐标位置
      ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, yPos);
   }
   else
   {
      // 隐藏按钮：移动到屏幕外
      ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, -1000);
   }
}

//+------------------------------------------------------------------+
//| [新增] 判断K线是否为Pinbar，返回类型：0=不是, 1=看涨, 2=看跌
//+------------------------------------------------------------------+
int IsPinbar(int barIndex)
{
   double high  = iHigh(NULL, 0, barIndex);
   double low   = iLow(NULL, 0, barIndex);
   double open  = iOpen(NULL, 0, barIndex);
   double close = iClose(NULL, 0, barIndex);
   
   // 计算K线各部分尺寸
   double totalRange = high - low;
   if(totalRange == 0) return 0;  // 防止除零
   
   double bodyHigh = MathMax(open, close);
   double bodyLow  = MathMin(open, close);
   double bodySize = bodyHigh - bodyLow;
   
   double upperWick = high - bodyHigh;  // 上影线
   double lowerWick = bodyLow - low;    // 下影线
   
   // 计算比例
   double bodyPercent = bodySize / totalRange * 100;
   double upperWickPercent = upperWick / totalRange * 100;
   double lowerWickPercent = lowerWick / totalRange * 100;
   
   // 判断看涨Pinbar（长下影线）
   if(lowerWickPercent >= 60 &&          // 下影线至少60%
      bodyPercent <= 30 &&                // 实体小于30%
      upperWickPercent <= 20 &&           // 上影线小于20%
      bodyLow >= low + totalRange * 0.7)  // 实体在上端
   {
      return 1;  // 看涨Pinbar
   }
   
   // 判断看跌Pinbar（长上影线）
   if(upperWickPercent >= 60 &&          // 上影线至少60%
      bodyPercent <= 30 &&                // 实体小于30%
      lowerWickPercent <= 20 &&           // 下影线小于20%
      bodyHigh <= high - totalRange * 0.7) // 实体在下端
   {
      return 2;  // 看跌Pinbar
   }
   
   return 0;  // 不是Pinbar
}

//+------------------------------------------------------------------+
//| [新增] 判断K线是否为Pinbar（宽松版本），返回类型：0=不是, 1=看涨, 2=看跌
//+------------------------------------------------------------------+
int IsPinbarV2(int barIndex)
{
   double high  = iHigh(NULL, 0, barIndex);
   double low   = iLow(NULL, 0, barIndex);
   double open  = iOpen(NULL, 0, barIndex);
   double close = iClose(NULL, 0, barIndex);
   
   // 计算K线各部分尺寸
   double totalRange = high - low;
   if(totalRange == 0) return 0;  // 防止除零
   
   double bodyHigh = MathMax(open, close);
   double bodyLow  = MathMin(open, close);
   double bodySize = bodyHigh - bodyLow;
   
   double upperWick = high - bodyHigh;  // 上影线
   double lowerWick = bodyLow - low;    // 下影线
   
   // 计算比例
   double bodyPercent = bodySize / totalRange * 100;
   double upperWickPercent = upperWick / totalRange * 100;
   double lowerWickPercent = lowerWick / totalRange * 100;
   
   // 宽松标准：影线 > 55%, 实体 < 1/3 (33.3%)
   
   // 判断看涨Pinbar（长下影线）
   // 下影线超过整根K线的55%，且实体小于1/3
   if(lowerWickPercent > 55 && bodyPercent < 33.3)
   {
      return 1;  // 看涨Pinbar（宽松版）
   }
   
   // 判断看跌Pinbar（长上影线）
   // 上影线超过整根K线的55%，且实体小于1/3
   if(upperWickPercent > 55 && bodyPercent < 33.3)
   {
      return 2;  // 看跌Pinbar（宽松版）
   }
   
   return 0;  // 不是Pinbar
}

//+------------------------------------------------------------------+
//| [新增] 强制清除主图表所有绘图对象（无需确认）
//+------------------------------------------------------------------+
void ForceCleanAllObjects()
{
   // 删除主图表上所有绘图对象
   // chart_id = 0 (当前图表)
   // sub_window = -1 (所有窗口)
   // type = -1 (所有类型对象)
   int total_deleted = ObjectsDeleteAll(0, -1, -1);
   
   // 清空关联数组
   ArrayResize(g_drawnObjects, 0);
   
   // 强制刷新图表
   ChartRedraw(0);
   
   // 打印日志
   if(total_deleted > 0)
      Print("[强制清除] 成功删除 ", total_deleted, " 个绘图对象（包含所有类型）");
   else
      Print("[强制清除] 图表上没有可删除的对象");
}

//+------------------------------------------------------------------+
//| [新增] 绘制关口线（整数价位参考线）
//+------------------------------------------------------------------+
void DrawRoundNumberLines()
{
   // 检查是否所有开关都关闭
   if(!Enable_Round_100 && !Enable_Round_50 && !Enable_Round_10 && !Enable_Round_5)
      return;  // 全部关闭，不绘制
   
   // 获取图表可见范围的价格上下限
   double upperPrice = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double lowerPrice = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   
   // 检查数据有效性
   if(upperPrice == 0 || lowerPrice == 0 || upperPrice <= lowerPrice)
      return;  // 数据未就绪或无效
   
   // 根据Point大小确定合适的步长单位
   // XAUUSD: Point=0.01, 所以100美金 = 100/0.01 = 10000点
   double unit_100 = 100.0;
   double unit_50 = 50.0;
   double unit_10 = 10.0;
   double unit_5 = 5.0;
   
   // 绘制计数
   int count100 = 0, count50 = 0, count10 = 0, count5 = 0;
   
   // 从下限开始遍历到上限
   // 找到最小的起始价格（向下取整到最小单位）
   double minUnit = 1000.0;  // 默认最大单位
   if(Enable_Round_5) minUnit = unit_5;
   else if(Enable_Round_10) minUnit = unit_10;
   else if(Enable_Round_50) minUnit = unit_50;
   else if(Enable_Round_100) minUnit = unit_100;
   
   double startPrice = MathFloor(lowerPrice / minUnit) * minUnit;
   
   // 遍历价格范围
   for(double price = startPrice; price <= upperPrice; price += minUnit)
   {
      // 优先级覆盖策略：100 > 50 > 10 > 5
      // 如果某个价位同时满足多个条件，只绘制优先级最高的那条线
      
      if(Enable_Round_100 && MathAbs(MathMod(price, unit_100)) < 0.001)
      {
         // 绘制100关口线
         DrawSingleRoundLine(price, 100, Color_Round_100, Width_Round_100, Style_Round_Key);
         count100++;
      }
      else if(Enable_Round_50 && MathAbs(MathMod(price, unit_50)) < 0.001)
      {
         // 绘制50关口线
         DrawSingleRoundLine(price, 50, Color_Round_50, Width_Round_50, Style_Round_Key);
         count50++;
      }
      else if(Enable_Round_10 && MathAbs(MathMod(price, unit_10)) < 0.001)
      {
         // 绘制10关口线
         DrawSingleRoundLine(price, 10, Color_Round_10, Width_Round_10, Style_Round_Normal);
         count10++;
      }
      else if(Enable_Round_5 && MathAbs(MathMod(price, unit_5)) < 0.001)
      {
         // 绘制5关口线
         DrawSingleRoundLine(price, 5, Color_Round_5, Width_Round_5, Style_Round_Normal);
         count5++;
      }
   }
   
   // 打印日志
   int total = count100 + count50 + count10 + count5;
   if(total > 0)
   {
      Print("[关口线] 绘制完成: 100(", count100, ") 50(", count50, ") 10(", count10, ") 5(", count5, ") 共", total, "条");
   }
}

//+------------------------------------------------------------------+
//| [新增] 绘制单条关口线
//+------------------------------------------------------------------+
void DrawSingleRoundLine(double price, int interval, color lineColor, int lineWidth, ENUM_LINE_STYLE lineStyle)
{
   // 对象命名：Round_间隔_价格（去掉小数点）
   string priceSt = DoubleToString(price, 2);
   StringReplace(priceSt, ".", "");
   string objName = "Round_" + IntegerToString(interval) + "_" + priceSt;
   
   // 检查对象是否已存在
   if(ObjectFind(0, objName) >= 0)
      return;  // 已存在，跳过
   
   // 创建水平线
   ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);  // 不可选择
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);       // 对象列表隐藏
   // 注意：不设置OBJPROP_BACK，让线条在前景层，这样MT4会自动显示价格
   ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);  // 所有周期可见
   
   // 设置描述文字
   string desc = "";
   if(interval == 100 || interval == 50)
      desc = "[Key Round " + IntegerToString(interval) + "]";
   else
      desc = "[Round " + IntegerToString(interval) + "]";
   
   ObjectSetString(0, objName, OBJPROP_TEXT, desc);
}

//+------------------------------------------------------------------+
//| [新增] 更新关口线（价格范围变化时）
//+------------------------------------------------------------------+
void UpdateRoundNumberLines()
{
   // 检查是否所有开关都关闭
   if(!Enable_Round_100 && !Enable_Round_50 && !Enable_Round_10 && !Enable_Round_5)
      return;
   
   // 获取图表可见范围的价格上下限
   double upperPrice = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double lowerPrice = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   
   // 检查数据有效性
   if(upperPrice == 0 || lowerPrice == 0 || upperPrice <= lowerPrice)
      return;
   
   // 删除超出范围的关口线，创建新进入范围的关口线
   int total = ObjectsTotal(0, 0, -1);
   int deletedCount = 0;
   
   // 从后向前遍历，删除超出范围的线
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是关口线对象
      if(StringFind(objName, "Round_") == 0)
      {
         double linePrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
         
         // 如果超出当前价格范围，删除
         if(linePrice < lowerPrice || linePrice > upperPrice)
         {
            ObjectDelete(0, objName);
            deletedCount++;
         }
      }
   }
   
   // 重新绘制（只会创建不存在的线）
   DrawRoundNumberLines();
   
   if(deletedCount > 0)
   {
      Print("[关口线] 更新: 删除超出范围的 ", deletedCount, " 条线");
   }
}

//+------------------------------------------------------------------+
//| [新增] 删除所有关口线
//+------------------------------------------------------------------+
void DeleteRoundNumberLines()
{
   int total = ObjectsTotal(0, 0, -1);
   int deleteCount = 0;
   
   // 从后向前遍历，删除所有关口线
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是关口线对象（以 "Round_" 开头）
      if(StringFind(objName, "Round_") == 0)
      {
         ObjectDelete(0, objName);
         deleteCount++;
      }
   }
   
   if(deleteCount > 0)
   {
      Print("[关口线] 清理: 删除 ", deleteCount, " 条关口线");
   }
}