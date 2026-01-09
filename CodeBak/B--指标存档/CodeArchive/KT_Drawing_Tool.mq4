//+------------------------------------------------------------------+
//|                                     K_Drawing_Tool_Debug.mq4     |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window

//--- 参数设置
input color ColorHLine = clrRed;
input color ColorRay   = clrDeepSkyBlue;
input int   LineWidth  = 2;

//--- 内部变量
int drawingState = 0;
string btnName1 = "Btn_Draw_HLine";
string btnName2 = "Btn_Draw_Ray";

// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// [关键] 这个变量必须放在这里！(所有函数外面)
// 如果你把它放进 OnChartEvent 里，修复就会失效！
uint lastBtnClickTime = 0; 
// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

int OnInit()
  {
   CreateButton(btnName1, "画水平线 (H)", 100, 20, 80, 25, clrGray, clrWhite);
   CreateButton(btnName2, "画射线 (R)",   190, 20, 80, 25, clrGray, clrWhite);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectDelete(0, btnName1);
   ObjectDelete(0, btnName2);
  }

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
  {
   return(rates_total);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   // =================================================================
   // 1. 按钮点击逻辑
   // =================================================================
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == btnName1 || sparam == btnName2)
        {
         // >>> [核心修改] 让按钮立刻“弹起”，取消按下的凹陷效果 <<<
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false); 
         if(sparam == btnName1) drawingState = 1;
         if(sparam == btnName2) drawingState = 2;
         
         // 记录时间
         lastBtnClickTime = GetTickCount(); 
         
         // [调试打印]
         Print("1. 按钮被点击! 时间戳: ", lastBtnClickTime);
         
         ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
         // Comment("【进入画图模式】请点击K线...");
         PlaySound("tick.wav");
        }
     }

   // =================================================================
   // 2. 图表点击逻辑 (自动画线bug发生地)
   // =================================================================
   if(id == CHARTEVENT_CLICK)
     {
      uint currentTime = GetTickCount();
      uint timeDiff = currentTime - lastBtnClickTime;

      // [调试打印] 
      Print("2. 检测到图表点击! 当前时间: ", currentTime, " 上次按钮时间: ", lastBtnClickTime, " 间隔: ", timeDiff, "ms");

      // --- 核心防御 ---
      if (timeDiff < 500) 
      {
          Print(">>> [防御成功] 间隔小于500ms，判定为误触，忽略此次画图指令！");
          return; // 直接退出，不画线
      }

      if(drawingState != 0)
        {
         datetime dt = 0;
         double price = 0;
         int window = 0;
         
         if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, window, dt, price))
           {
            int barIndex = iBarShift(NULL, 0, dt);
            double high = iHigh(NULL, 0, barIndex);
            double low  = iLow(NULL, 0, barIndex);
            
            double finalPrice = price;
            if(MathAbs(price - high) < MathAbs(price - low)) finalPrice = high;
            else finalPrice = low;
            
            string objName = "Draw_" + IntegerToString(GetTickCount());
            
            Print("3. 执行画线! 价格: ", finalPrice); // [调试打印]

            if(drawingState == 1)
              {
               ObjectCreate(0, objName, OBJ_HLINE, 0, 0, finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, ColorHLine);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
              }
            else if(drawingState == 2)
              {
               datetime time1 = iTime(NULL, 0, barIndex);
               ObjectCreate(0, objName, OBJ_TREND, 0, time1, finalPrice, Time[0], finalPrice);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, ColorRay);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, LineWidth);
               ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
              }
            
            ChartRedraw();
            PlaySound("ok.wav");
           }
         
         // 重置状态
         drawingState = 0;
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true);
         // Comment("");
         Print("4. 退出画图模式");
        }
     }
  }

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