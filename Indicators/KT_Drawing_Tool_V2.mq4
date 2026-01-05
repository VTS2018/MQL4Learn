//+------------------------------------------------------------------+
//|                                           KT_Drawing_Tool.mq4    |
//|                                  Copyright 2024, CD_SMC_Analysis |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "CD_SMC_Analysis"
#property strict
#property indicator_chart_window

//--- 参数设置
input color ColorHLine = clrRed;        // 水平线颜色
input color ColorRay   = clrDeepSkyBlue;// 射线(趋势水平线)颜色
input int   LineWidth  = 2;             // 线条宽度

//--- [新增] 周期专属颜色设置 (针对浅色背景 229,230,250 优化)
input color Color_H1   = clrBlue;         // H1 周期颜色
input color Color_H4   = clrDarkOrange;   // H4 周期颜色
input color Color_D1   = clrRed;          // D1 周期颜色
input color Color_W1   = clrDarkGreen;    // W1 周期颜色
input color Color_MN1  = clrDarkViolet;   // MN1 周期颜色

//--- 内部变量
int drawingState = 0; // 0=无, 1=准备画水平线, 2=准备画射线
string btnName1 = "Btn_Draw_HLine";
string btnName2 = "Btn_Draw_Ray";

// [全局变量] 记录最后一次点击按钮的时间 (用于防误触)
uint lastBtnClickTime = 0; 

//+------------------------------------------------------------------+
//| 初始化函数
//+------------------------------------------------------------------+
int OnInit()
  {
   // 创建UI按钮
   CreateButton(btnName1, "画水平线 (H)", 100, 20, 80, 25, clrGray, clrWhite);
   CreateButton(btnName2, "画射线 (R)",   190, 20, 80, 25, clrGray, clrWhite);

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true); // 开启鼠标捕捉
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| 反初始化函数
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, btnName1);
   ObjectDelete(0, btnName2);
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
            
            // 1. 获取该K线的四个价格
            double high  = iHigh(NULL, 0, barIndex);
            double low   = iLow(NULL, 0, barIndex);
            double open  = iOpen(NULL, 0, barIndex);
            double close = iClose(NULL, 0, barIndex);
            
            // 2. 计算鼠标点击位置与这四个价格的距离
            double distH = MathAbs(price - high);
            double distL = MathAbs(price - low);
            double distO = MathAbs(price - open);
            double distC = MathAbs(price - close);
            
            // 3. 找出距离最近的那个价格
            double finalPrice = high;      // 默认先假设 High 最近
            double minDist    = distH;     // 记录最小距离
            
            if(distL < minDist) { minDist = distL; finalPrice = low;   }
            if(distO < minDist) { minDist = distO; finalPrice = open;  }
            if(distC < minDist) { minDist = distC; finalPrice = close; }
            
            // -------------------------------------------------------------
            // 执行画图
            // -------------------------------------------------------------
            string tfStr = GetPeriodName(Period());
            string objName = "Draw_" + tfStr + "_" + IntegerToString(GetTickCount());
            // string objName = "Draw_" + IntegerToString(GetTickCount());

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
               ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
               
               // [新增功能] 在磁吸的K线上绘制Check标记
               bool isBullish = (close > open); // 判断阳线/阴线
               double markPrice = isBullish ? (high + 5 * Point) : (low - 5 * Point); // 阳线标记在最高价上方，阴线在最低价下方
               datetime time1 = iTime(NULL, 0, barIndex);
               string markName = "Mark_" + tfStr + "_" + IntegerToString(GetTickCount());
               
               ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, time1, markPrice);
               ObjectSetInteger(0, markName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
               ObjectSetInteger(0, markName, OBJPROP_ANCHOR, isBullish ? ANCHOR_BOTTOM : ANCHOR_TOP); // 阳线锚点在下，阴线锚点在上
               ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, true);
              }
            else if(drawingState == 2) // 画射线
              {
               datetime time1 = iTime(NULL, 0, barIndex);
               ObjectCreate(0, objName, OBJ_TREND, 0, time1, finalPrice, Time[0], finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
               
               // [新增功能] 在图表右侧价格轴显示射线价格标签
               string priceLabelName = "PriceLabel_" + tfStr + "_" + IntegerToString(GetTickCount());
               datetime currentTime = Time[0]; // 当前K线时间
               ObjectCreate(0, priceLabelName, OBJ_ARROW_RIGHT_PRICE, 0, currentTime, finalPrice);
               ObjectSetInteger(0, priceLabelName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, priceLabelName, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, priceLabelName, OBJPROP_SELECTABLE, false); // 不可选中，避免干扰
               ObjectSetInteger(0, priceLabelName, OBJPROP_HIDDEN, true); // 在对象列表中隐藏
               
               // [新增功能] 在磁吸的K线上绘制Check标记
               bool isBullish = (close > open); // 判断阳线/阴线
               double markPrice = isBullish ? (high + 5 * Point) : (low - 5 * Point); // 阳线标记在最高价上方，阴线在最低价下方
               string markName = "Mark_" + tfStr + "_" + IntegerToString(GetTickCount());
               
               ObjectCreate(0, markName, OBJ_ARROW_CHECK, 0, time1, markPrice);
               ObjectSetInteger(0, markName, OBJPROP_COLOR, finalColor);
               ObjectSetInteger(0, markName, OBJPROP_WIDTH, 2);
               ObjectSetInteger(0, markName, OBJPROP_ANCHOR, isBullish ? ANCHOR_BOTTOM : ANCHOR_TOP); // 阳线锚点在下，阴线锚点在上
               ObjectSetInteger(0, markName, OBJPROP_SELECTABLE, true);
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