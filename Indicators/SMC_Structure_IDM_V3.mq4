//+------------------------------------------------------------------+
//|                                     SMC_Structure_IDM_V3.mq4     |
//|                                  Copyright 2024, CD_SMC_Analysis |
//+------------------------------------------------------------------+
#property copyright "CD_SMC_Analysis"
#property strict
#property indicator_chart_window

//--- input parameters
input int      FractalLeft   = 5;    // 左侧K线数量
input int      FractalRight  = 2;    // 右侧K线数量
input color    ColorBOS      = clrLime; // BOS 颜色
input color    ColorCHOCH    = clrRed;  // CHoCH 颜色
input color    ColorIDM      = clrOrange; // IDM 颜色
input color    ColorStructure= clrGray; // 结构连线颜色

//--- buffers
double         HighBuffer[];
double         LowBuffer[];

//--- 内部存储结构
int fractalHighs_idx[2000];
double fractalHighs_price[2000];
int fractalLows_idx[2000];
double fractalLows_price[2000];
int hCount=0;
int lCount=0;

// >>>>>>>>>>>> [修改 1] 新增全局变量用于记录时间 <<<<<<<<<<<<<<
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorBuffers(2);
   SetIndexBuffer(0,HighBuffer);
   SetIndexBuffer(1,LowBuffer);
   SetIndexStyle(0,DRAW_NONE);
   SetIndexStyle(1,DRAW_NONE);
   return(INIT_SUCCEEDED);
  }
  
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "SMC_");
  }

//+------------------------------------------------------------------+
//| 绘图辅助函数                                                      |
//+------------------------------------------------------------------+
void DrawLine(string name, int idx1, double price1, int idx2, double price2, color clr, int style=STYLE_SOLID)
{
   if(idx1 < 0 || idx2 < 0) return;
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_TREND, 0, Time[idx1], price1, Time[idx2], price2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
}

void DrawText(string name, int idx, double price, string text, color clr, int anchor)
{
   if(idx < 0) return;
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_TEXT, 0, Time[idx], price);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
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
   // 设置序列模式，防止越界
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   if(rates_total < 100) return(0);

   // =========================================================================
   // >>>>>>>>>>>> [修改 2] 核心性能优化：新K线检测逻辑 <<<<<<<<<<<<<<
   // =========================================================================
   
   // 如果不是第一次运行(prev_calculated != 0)，且当前K线时间等于上次记录的时间
   // 说明还在同一根K线内，不需要重新扫描几千根历史数据
   if(prev_calculated > 0 && time[0] == lastBarTime) {
       return(rates_total); // 直接退出函数，不消耗CPU
   }
   
   // 如果代码能运行到这里，说明是新的一根K线开始了（或者指标刚加载）
   // 更新记录的时间
   lastBarTime = time[0]; 
   
   // =========================================================================
   // >>>>>>>>>>>> [修改结束] 下面是繁重的计算任务，现在只在整点运行 <<<<<<
   // =========================================================================

   ObjectsDeleteAll(0, "SMC_");
   hCount = 0;
   lCount = 0;
   
   // 1. 识别分形 (Highs 和 Lows)
   for(int i = FractalRight; i < rates_total - FractalLeft; i++) {
      if(hCount >= 1999 || lCount >= 1999) break;

      bool isHigh = true;
      bool isLow = true;
      
      for(int j=1; j<=FractalLeft; j++) {
         if(high[i] <= high[i+j]) isHigh = false;
         if(low[i] >= low[i+j]) isLow = false;
      }
      for(int j=1; j<=FractalRight; j++) {
         if(high[i] <= high[i-j]) isHigh = false;
         if(low[i] >= low[i-j]) isLow = false;
      }
      
      if(isHigh) {
         fractalHighs_idx[hCount] = i;
         fractalHighs_price[hCount] = high[i];
         hCount++;
      }
      if(isLow) {
         fractalLows_idx[lCount] = i;
         fractalLows_price[lCount] = low[i];
         lCount++;
      }
   }

   // =========================================================================
   // >>>>>>>>>>>> [修改开始] 新增调试报告打印模块 <<<<<<<<<<<<<<
   // =========================================================================
   
   // 只有在指标初始化或重新编译的第一次运行时打印，防止日志刷屏
   if(prev_calculated == 0) {
       Print("============== SMC 结构识别深度报告 ==============");
       PrintFormat("本次扫描共发现: 高点(Highs)=%d 个, 低点(Lows)=%d 个", hCount, lCount);
       
       // 打印最近的 5 个高点详情
       Print("--- [最近 5 个高点详情 (由近及远)] ---");
       int printLimitH = MathMin(5, hCount); // 防止数量不足5个时报错
       for(int k=0; k<printLimitH; k++) {
           int idx = fractalHighs_idx[k];
           // Time[idx] 在指标里通常用 time[idx]
           PrintFormat("High[%d]: 索引(Index)=%d | 价格=%.5f | 时间=%s", 
                       k, idx, fractalHighs_price[k], TimeToString(time[idx]));
       }

       // 打印最近的 5 个低点详情
       Print("--- [最近 5 个低点详情 (由近及远)] ---");
       int printLimitL = MathMin(5, lCount);
       for(int k=0; k<printLimitL; k++) {
           int idx = fractalLows_idx[k];
           PrintFormat("Low[%d]:  索引(Index)=%d | 价格=%.5f | 时间=%s", 
                       k, idx, fractalLows_price[k], TimeToString(time[idx]));
       }
       
       Print("============== 报告结束 ==============");
   }
   
   // =========================================================================
   // >>>>>>>>>>>> [修改结束] 报告模块结束 <<<<<<<<<<<<<<
   // =========================================================================

   // 2. 绘制 ZigZag 结构连线 (最近20笔)
   int ch = 0; int cl = 0;
   int leg_count = 0;
   while(ch < hCount && cl < lCount && leg_count < 30) {
      int hIdx = fractalHighs_idx[ch];
      int lIdx = fractalLows_idx[cl];
      
      if(hIdx < lIdx) { 
         DrawLine("SMC_Leg_"+(string)leg_count, lIdx, fractalLows_price[cl], hIdx, fractalHighs_price[ch], ColorStructure);
         ch++; 
      } else { 
         DrawLine("SMC_Leg_"+(string)leg_count, hIdx, fractalHighs_price[ch], lIdx, fractalLows_price[cl], ColorStructure);
         cl++;
      }
      leg_count++;
   }

   // -------------------------------------------------------------
   // 3. 核心修复部分：完整的双向 BOS 和 CHoCH 逻辑
   // -------------------------------------------------------------
   
   // --- A. 牛市逻辑 (Bullish) ---
   if(hCount >= 2 && lCount >= 1) {
       // Bullish BOS: 新高点(0) 高于 旧高点(1)
       if(fractalHighs_price[0] > fractalHighs_price[1]) {
           DrawLine("SMC_BOS_Bull", fractalHighs_idx[1], fractalHighs_price[1], fractalHighs_idx[0], fractalHighs_price[1], ColorBOS);
           DrawText("SMC_BOS_Bull_Txt", fractalHighs_idx[0], fractalHighs_price[1], "BOS", ColorBOS, ANCHOR_LEFT_LOWER);
       }
       
       // Bullish CHoCH: 价格向上突破了最近的“强高点”
       // 如果现在的收盘价 > 最近的高点，且最近的走势看起来像是刚结束下跌
       if(close[1] > fractalHighs_price[0]) {
           // 这是一个潜在的趋势反转向上
           DrawLine("SMC_CHoCH_Bull", fractalHighs_idx[0], fractalHighs_price[0], 0, fractalHighs_price[0], ColorCHOCH);
           DrawText("SMC_CHoCH_Bull_Txt", 0, fractalHighs_price[0], "CHoCH", ColorCHOCH, ANCHOR_LEFT_LOWER);
       }
   }
   
   // --- B. 熊市逻辑 (Bearish) - 之前缺失的部分 ---
   if(lCount >= 2 && hCount >= 1) {
       // Bearish BOS: 新低点(0) 低于 旧低点(1)
       // 逻辑：如果最近的低点比上一个低点更低，说明下跌趋势延续
       if(fractalLows_price[0] < fractalLows_price[1]) {
           // 在旧低点(1)的位置画线延伸到新低点(0)的时间
           DrawLine("SMC_BOS_Bear", fractalLows_idx[1], fractalLows_price[1], fractalLows_idx[0], fractalLows_price[1], ColorBOS);
           DrawText("SMC_BOS_Bear_Txt", fractalLows_idx[0], fractalLows_price[1], "BOS", ColorBOS, ANCHOR_LEFT_UPPER);
       }
       
       // Bearish CHoCH: 价格向下跌破了最近的“强低点”
       if(close[1] < fractalLows_price[0]) {
           DrawLine("SMC_CHoCH_Bear", fractalLows_idx[0], fractalLows_price[0], 0, fractalLows_price[0], ColorCHOCH);
           DrawText("SMC_CHoCH_Bear_Txt", 0, fractalLows_price[0], "CHoCH", ColorCHOCH, ANCHOR_LEFT_UPPER);
       }
   }

   // --- C. IDM (诱导点) 双向逻辑 ---
   // 寻找做空的 IDM (Bearish IDM): 最近 Low 上方的第一个 High (反弹诱多)
   // 寻找做多的 IDM (Bullish IDM): 最近 High 下方的第一个 Low (回调诱空)
   
   // 简单起见，我们只标注最近结构产生的那个 IDM
   if(hCount > 0 && lCount > 0) {
       int lastH = fractalHighs_idx[0];
       int lastL = fractalLows_idx[0];
       
       // 如果最近形成的是 High (High 比 Low 新, index更小) -> 可能是下跌回调或者上涨冲高
       // 这是一个简化判断，SMC其实更复杂。这里为了直观：
       
       // 如果当前是上涨趋势(最近两个High抬高)，找最近High左侧的Low作为IDM
       if(hCount>=2 && fractalHighs_price[0] > fractalHighs_price[1]) {
           int idmIdx = -1; double idmPrice = 0;
           for(int m=0; m<lCount; m++) {
               if(fractalLows_idx[m] > fractalHighs_idx[0]) {
                   idmIdx = fractalLows_idx[m]; idmPrice = fractalLows_price[m]; break;
               }
           }
           if(idmIdx!=-1) DrawText("SMC_IDM_Bull", idmIdx, idmPrice, "IDM", ColorIDM, ANCHOR_TOP);
       }
       
       // 如果当前是下跌趋势(最近两个Low降低)，找最近Low左侧的High作为IDM
       if(lCount>=2 && fractalLows_price[0] < fractalLows_price[1]) {
           int idmIdx = -1; double idmPrice = 0;
           for(int m=0; m<hCount; m++) {
               if(fractalHighs_idx[m] > fractalLows_idx[0]) {
                   idmIdx = fractalHighs_idx[m]; idmPrice = fractalHighs_price[m]; break;
               }
           }
           if(idmIdx!=-1) DrawText("SMC_IDM_Bear", idmIdx, idmPrice, "IDM", ColorIDM, ANCHOR_BOTTOM);
       }
   }

   return(rates_total);
  }
//+------------------------------------------------------------------+