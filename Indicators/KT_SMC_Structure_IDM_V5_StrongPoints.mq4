//+------------------------------------------------------------------+
//|                          SMC_Structure_IDM_V5_StrongPoints.mq4   |
//|                                  Copyright 2024, CD_SMC_Analysis |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "CD_SMC_Analysis"
#property link      "https://www.mql5.com"
#property version   "5.00"
#property strict
#property indicator_chart_window

//--- input parameters
input int      FractalLeft   = 5;    // 左侧K线数量
input int      FractalRight  = 2;    // 右侧K线数量
input color    ColorBOS      = clrLime; // BOS 颜色
input color    ColorCHOCH    = clrRed;  // CHoCH 颜色
input color    ColorIDM      = clrOrange; // IDM 颜色
input color    ColorStructure= clrGray; // 结构连线颜色

// >>> [V5 新增] 强结构点参数设置 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
input color    ColorStrongLow = clrDeepSkyBlue; // 强低点颜色 (多头大哥)
input color    ColorStrongHigh= clrMagenta;     // 强高点颜色 (空头大哥)
input int      StrongPointSize= 3;              // 结构点圆点大小
// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

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

// 全局变量 (来自 V4 的优化逻辑)
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
  
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "SMC_");
  }

//+------------------------------------------------------------------+
//| 绘图辅助函数                                                      |
//+------------------------------------------------------------------+
void DrawLine(string name, int idx1, double price1, int idx2, double price2, color clr, int style=STYLE_SOLID, int width=1)
{
   if(idx1 < 0 || idx2 < 0) return;
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_TREND, 0, Time[idx1], price1, Time[idx2], price2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
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

// >>> [V5 新增] 绘制实心圆点函数 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
void DrawDot(string name, int idx, double price, color clr)
{
   if(idx < 0) return;
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_ARROW, 0, Time[idx], price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159); // 159 是实心圆点
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, StrongPointSize);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
}
// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

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
   // 基础设置：序列化数组
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   if(rates_total < 100) return(0);

   // --- [V4 逻辑] 性能优化：仅在新K线计算 ---
   if(prev_calculated > 0 && time[0] == lastBarTime) {
       return(rates_total); 
   }
   lastBarTime = time[0]; 
   // ---------------------------------------

   ObjectsDeleteAll(0, "SMC_");
   hCount = 0;
   lCount = 0;
   
   // 1. 扫描分形 (保持不变)
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

   // 2. 绘制 ZigZag 结构连线 (保持不变)
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

   // =================================================================
   // >>> [V5 修改] 核心逻辑：BOS 判定 + 强结构点搜索 (Strong Points) <<<
   // =================================================================
   
   // --- A. 牛市逻辑 (Bullish) ---
   if(hCount >= 2 && lCount >= 1) {
       // 如果发生了 BOS (新高 > 旧高)
       if(fractalHighs_price[0] > fractalHighs_price[1]) {
           
           // 1. 画 BOS 线
           DrawLine("SMC_BOS_Bull", fractalHighs_idx[1], fractalHighs_price[1], fractalHighs_idx[0], fractalHighs_price[1], ColorBOS, STYLE_SOLID, 2);
           DrawText("SMC_BOS_Bull_Txt", fractalHighs_idx[0], fractalHighs_price[1], "BOS", ColorBOS, ANCHOR_LEFT_LOWER);
           
           // >>> [V5 新增] 寻找干掉旧高的那个低点 (Strong Low) >>>
           int startIdx = fractalHighs_idx[1]; // 旧高点位置
           int endIdx = fractalHighs_idx[0];   // 新高点位置
           
           int strongLowIdx = -1;
           double minPrice = 999999;
           
           // 遍历所有低点，找到在 startIdx 和 endIdx 之间的最低点
           for(int m=0; m<lCount; m++) {
               int currIdx = fractalLows_idx[m];
               // 只有位置在两个高点之间的低点才算数 (index 介于两者之间)
               if(currIdx < startIdx && currIdx > endIdx) {
                   if(fractalLows_price[m] < minPrice) {
                       minPrice = fractalLows_price[m];
                       strongLowIdx = currIdx;
                   }
               }
           }
           
           // 标记找到的强低点
           if(strongLowIdx != -1) {
               DrawDot("SMC_StrongLow", strongLowIdx, minPrice, ColorStrongLow);
               DrawText("SMC_StrongLow_Txt", strongLowIdx, minPrice, "Strong Low", ColorStrongLow, ANCHOR_TOP);
           }
           // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
       }
       
       // Bullish CHoCH Check
       if(close[0] > fractalHighs_price[0]) {
           DrawLine("SMC_CHoCH_Bull", fractalHighs_idx[0], fractalHighs_price[0], 0, fractalHighs_price[0], ColorCHOCH);
           DrawText("SMC_CHoCH_Bull_Txt", 0, fractalHighs_price[0], "CHoCH", ColorCHOCH, ANCHOR_LEFT_LOWER);
       }
   }
   
   // --- B. 熊市逻辑 (Bearish) ---
   if(lCount >= 2 && hCount >= 1) {
       // 如果发生了 BOS (新低 < 旧低)
       if(fractalLows_price[0] < fractalLows_price[1]) {
           
           // 1. 画 BOS 线
           DrawLine("SMC_BOS_Bear", fractalLows_idx[1], fractalLows_price[1], fractalLows_idx[0], fractalLows_price[1], ColorBOS, STYLE_SOLID, 2);
           DrawText("SMC_BOS_Bear_Txt", fractalLows_idx[0], fractalLows_price[1], "BOS", ColorBOS, ANCHOR_LEFT_UPPER);
           
           // >>> [V5 新增] 寻找干掉旧低的那个高点 (Strong High) >>>
           int startIdx = fractalLows_idx[1]; // 旧低点
           int endIdx = fractalLows_idx[0];   // 新低点
           
           int strongHighIdx = -1;
           double maxPrice = 0;
           
           // 遍历所有高点，找到在 startIdx 和 endIdx 之间的最高点
           for(int m=0; m<hCount; m++) {
               int currIdx = fractalHighs_idx[m];
               if(currIdx < startIdx && currIdx > endIdx) {
                   if(fractalHighs_price[m] > maxPrice) {
                       maxPrice = fractalHighs_price[m];
                       strongHighIdx = currIdx;
                   }
               }
           }
           
           // 标记找到的强高点
           if(strongHighIdx != -1) {
               DrawDot("SMC_StrongHigh", strongHighIdx, maxPrice, ColorStrongHigh);
               DrawText("SMC_StrongHigh_Txt", strongHighIdx, maxPrice, "Strong High", ColorStrongHigh, ANCHOR_BOTTOM);
           }
           // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
       }
       
       // Bearish CHoCH Check
       if(close[0] < fractalLows_price[0]) {
           DrawLine("SMC_CHoCH_Bear", fractalLows_idx[0], fractalLows_price[0], 0, fractalLows_price[0], ColorCHOCH);
           DrawText("SMC_CHoCH_Bear_Txt", 0, fractalLows_price[0], "CHoCH", ColorCHOCH, ANCHOR_LEFT_UPPER);
       }
   }
   
   // --- IDM Logic (保持 V4 原样) ---
   if(hCount > 0 && lCount > 0) {
       // 上涨趋势找最近高点左侧的低点
       if(hCount>=2 && fractalHighs_price[0] > fractalHighs_price[1]) {
           int idmIdx = -1; double idmPrice = 0;
           for(int m=0; m<lCount; m++) {
               if(fractalLows_idx[m] > fractalHighs_idx[0]) {
                   idmIdx = fractalLows_idx[m]; idmPrice = fractalLows_price[m]; break;
               }
           }
           if(idmIdx!=-1) DrawText("SMC_IDM_Bull", idmIdx, idmPrice, "IDM", ColorIDM, ANCHOR_TOP);
       }
       
       // 下跌趋势找最近低点左侧的高点
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