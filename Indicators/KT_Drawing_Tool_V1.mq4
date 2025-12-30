//+------------------------------------------------------------------+
//|                                           K_Drawing_Tool.mq4     |
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

//--- 内部变量
int drawingState = 0; // 0=无, 1=准备画水平线, 2=准备画射线
string btnName1 = "Btn_Draw_HLine";
string btnName2 = "Btn_Draw_Ray";
uint lastBtnClickTime = 0; // [缺失] 用于记录点击时间

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
   Comment("");
  }

//+------------------------------------------------------------------+
//| 核心计算函数 (不使用，但必须保留)
//+------------------------------------------------------------------+
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
   // 1. 监听按钮点击事件
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == btnName1)
        {
         drawingState = 1;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false); // 暂时锁定图表滚动，防止误触
         Comment("【模式：画水平线】\n请点击图表上的一根K线，将自动吸附最高/最低价...");
         PlaySound("tick.wav");
        }
      if(sparam == btnName2)
        {
         drawingState = 2;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
         Comment("【模式：画结构射线】\n请点击结构起点K线，将自动吸附最高/最低价...");
         PlaySound("tick.wav");
        }
     }

   // 2. 监听图表点击事件 (画图动作)
   if(id == CHARTEVENT_CLICK)
     {
      // [缺失] 必须加上这行！如果距离上次点按钮不到 300毫秒，忽略这次点击
      if (GetTickCount() - lastBtnClickTime < 300) return;
      
      if(drawingState != 0)
        {
         // 获取点击坐标对应的时间和价格
         datetime dt = 0;
         double price = 0;
         int window = 0;
         
         if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, window, dt, price))
           {
            // --- 核心：磁吸逻辑 (Adsorption) ---
            int barIndex = iBarShift(NULL, 0, dt); // 找到点击位置对应的K线索引
            
            // 获取该K线的高低点
            double high = iHigh(NULL, 0, barIndex);
            double low  = iLow(NULL, 0, barIndex);
            
            // 判断离哪个更近
            double finalPrice = price;
            double distH = MathAbs(price - high);
            double distL = MathAbs(price - low);
            
            if(distH < distL) finalPrice = high; // 吸附到High
            else              finalPrice = low;  // 吸附到Low
            
            // --- 执行画图 ---
            string objName = "Draw_" + IntegerToString(GetTickCount()); // 生成唯一名称
            
            if(drawingState == 1) // 画水平线 (OBJ_HLINE)
              {
               ObjectCreate(0, objName, OBJ_HLINE, 0, 0, finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, ColorHLine);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
              }
            else if(drawingState == 2) // 画射线 (OBJ_TREND 水平)
              {
               datetime time1 = iTime(NULL, 0, barIndex);
               // 起点是K线时间，终点是当前时间(仅用于确定方向，射线会自动延伸)
               ObjectCreate(0, objName, OBJ_TREND, 0, time1, finalPrice, Time[0], finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, ColorRay);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true); // 开启右侧延伸
               ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
              }
            
            ChartRedraw();
            PlaySound("ok.wav");
           }
         
         // 3. 重置状态
         drawingState = 0;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true); // 恢复图表滚动
         Comment("");
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