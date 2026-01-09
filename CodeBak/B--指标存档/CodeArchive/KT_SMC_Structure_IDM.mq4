//+------------------------------------------------------------------+
//|                                            SMC_Structure_IDM.mq4 |
//|                                  Copyright 2024, CD_SMC_Analysis |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "CD_SMC_Analysis"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

//--- input parameters
input int      FractalLeft   = 5;    // 左侧K线数量 (识别高低点灵敏度)
input int      FractalRight  = 2;    // 右侧K线数量
input color    ColorBOS      = clrLime; // BOS 颜色
input color    ColorCHOCH    = clrRed;  // CHoCH 颜色
input color    ColorIDM      = clrOrange; // IDM 颜色
input color    ColorStructure= clrGray; // 结构连线颜色

//--- buffers (不直接绘图，主要用于计算逻辑，绘图用Objects)
double         HighBuffer[];
double         LowBuffer[];

//--- 结构变量
struct StructurePoint {
   int index;
   double price;
   bool isHigh;
   bool isConfirmed; // 是否被IDM确认
};

// 简单的数组来存储分形点
int fractalHighs_idx[1000];
double fractalHighs_price[1000];
int fractalLows_idx[1000];
double fractalLows_price[1000];
int hCount=0;
int lCount=0;

// 全局状态
int lastStructureHighIndex = -1;
int lastStructureLowIndex = -1;
int trendDirection = 0; // 1: Bullish, -1: Bearish

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
//| 绘制直线函数                                                      |
//+------------------------------------------------------------------+
void DrawLine(string name, int idx1, double price1, int idx2, double price2, color clr, int style=STYLE_SOLID, int width=1)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_TREND, 0, Time[idx1], price1, Time[idx2], price2);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   }
}

//+------------------------------------------------------------------+
//| 绘制文本函数                                                      |
//+------------------------------------------------------------------+
void DrawText(string name, int idx, double price, string text, color clr, int anchor)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_TEXT, 0, Time[idx], price);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
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
   int limit = rates_total - prev_calculated;
   if(prev_calculated == 0) limit = rates_total - FractalLeft - FractalRight - 1;
   if(limit < 1) return(rates_total);

   // 1. 重新扫描所有分形 (简化逻辑，实际运行建议优化为只扫描新增K线，这里为了重绘正确每次全扫)
   ObjectsDeleteAll(0, "SMC_");
   hCount = 0;
   lCount = 0;
   
   // 识别分形点
   for(int i = rates_total - FractalLeft - FractalRight; i >= 0; i--) {
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
         if(hCount >= 1000) hCount = 999;
      }
      if(isLow) {
         fractalLows_idx[lCount] = i;
         fractalLows_price[lCount] = low[i];
         lCount++;
         if(lCount >= 1000) lCount = 999;
      }
   }

   // 2. SMC 逻辑核心处理
   // 假设初始趋势根据最近的高低点判断
   int currentStructureHigh_idx = -1;
   double currentStructureHigh_price = 0;
   int currentStructureLow_idx = -1;
   double currentStructureLow_price = 0;
   
   // 从左向右遍历历史数据构建结构
   // 这里做一个简化的状态机模拟
   
   // 我们倒序遍历分形数组（从旧到新）
   // 这里的数组存储是倒序的（0是最新），所以我们需要反向读取
   // 为了简单，我们只处理最近的波段逻辑，或者使用ZigZag逻辑连接
   
   // --- 简化版逻辑：标注最近的 IDM 和 BOS ---
   
   // 寻找当前的 Swing High (未被突破的最高点)
   // 实际上 SMC 需要复杂的逐K线回放逻辑。这里用更直观的方式：
   // 1. 找到最近的一个有效高点和低点
   // 2. 标记其内部的 IDM
   
   // 遍历最近的 Swing Points
   int lastH = -1;
   int lastL = -1;
   
   // 找到最新的分形
   if(hCount > 0) lastH = fractalHighs_idx[0];
   if(lCount > 0) lastL = fractalLows_idx[0];
   
   // 简单的 IDM 标记逻辑：
   // 如果当前是上涨趋势（高点抬高），最新的高点左侧的第一个低点就是 IDM
   // 如果价格跌破这个 IDM，则该高点确认为 Structure High
   
   for(int k=hCount-1; k>=0; k--) { // 从旧到新
       int idx = fractalHighs_idx[k];
       double px = fractalHighs_price[k];
       // 绘制小点辅助观察
       // DrawText("H_"+(string)idx, idx, px, ".", ColorStructure, ANCHOR_BOTTOM);
   }
   
   // --- 核心 SMC 逻辑模拟 (从右向左寻找最近结构) ---
   // 1. 寻找最近的一个 BOS
   // 假设我们看最近的 100 根K线
   
   // 标记 IDM (Inducement)
   // 逻辑：在当前价格下，上方最近的 Swing High 左侧的 Swing Low 是潜在 IDM (对于空头)
   // 逻辑：在当前价格上，下方最近的 Swing Low 左侧的 Swing High 是潜在 IDM (对于多头)
   
   // 自动标注最近的一个 IDM
   if(hCount > 1 && lCount > 1) {
      // 假设当前局部上涨，看最新的高点
      int recentHighIdx = fractalHighs_idx[0];
      double recentHighPrice = fractalHighs_price[0];
      
      // 寻找该高点左侧最近的低点 (IDM)
      // 在 fractalLows 里面找 index > recentHighIdx 的最小 index (因为index越大越靠左)
      int idmIdx = -1;
      double idmPrice = 0;
      
      for(int m=0; m<lCount; m++) {
         if(fractalLows_idx[m] > recentHighIdx) { // 在高点左侧
             // 找到第一个即停止
             idmIdx = fractalLows_idx[m];
             idmPrice = fractalLows_price[m];
             break;
         }
      }
      
      if(idmIdx != -1) {
         DrawText("SMC_IDM_Bear", idmIdx, idmPrice, "IDM", ColorIDM, ANCHOR_TOP);
         DrawLine("SMC_IDM_Line", idmIdx, idmPrice, recentHighIdx, idmPrice, ColorIDM, STYLE_DOT);
      }
   }
   
   // 标注 BOS/CHoCH
   // 简易算法：如果当前价格突破了前一个 Swing High，标 BOS
   // 我们只标最近发生的
   
   // 寻找最近的向上突破
   for(int i=rates_total-2; i>0; i--) {
      // 简单的突破判断
      if(high[i] > high[i+1] && high[i-1] <= high[i]) { // 局部峰值
          // 这里的逻辑比较复杂，需要完整的Zigzag结构
          // 为了不写几千行代码，我们用简化方式：
          // 比较相邻两个分形高点
      }
   }
   
   // --- 用 ZigZag 连线重构结构 ---
   // 连接相邻的高低点
   int ch = 0; int cl = 0;
   while(ch < hCount && cl < lCount) {
      int hIdx = fractalHighs_idx[ch];
      int lIdx = fractalLows_idx[cl];
      
      // 简单的连接逻辑，实际需要按时间排序
      if(hIdx < lIdx) { // 高点在右边（更晚发生）
          DrawLine("SMC_Leg_"+(string)hIdx, lIdx, fractalLows_price[cl], hIdx, fractalHighs_price[ch], ColorStructure);
          ch++;
      } else {
          DrawLine("SMC_Leg_"+(string)lIdx, hIdx, fractalHighs_price[ch], lIdx, fractalLows_price[cl], ColorStructure);
          cl++;
      }
      
      if(ch > 20 || cl > 20) break; // 只画最近的
   }
   
   // 重点：标注最近的 BOS
   // 如果最新的 High 高于 上一个 High -> Bullish BOS
   if(hCount >= 2) {
      if(fractalHighs_price[0] > fractalHighs_price[1]) {
          // 这是一个潜在的 BOS
          // 只有当价格突破 fractalHighs_price[1] 那一刻才是 BOS
          DrawLine("SMC_BOS_Bull", fractalHighs_idx[1], fractalHighs_price[1], 0, fractalHighs_price[1], ColorBOS);
          DrawText("SMC_BOS_Txt", 0, fractalHighs_price[1], "BOS", ColorBOS, ANCHOR_LEFT_LOWER);
      }
   }
   
   // 重点：标注 CHoCH
   // 如果价格跌破了制造出新高的那个低点 (Strong Low)
   // 这里的 Strong Low 简化为最近的 Swing Low
   if(lCount >= 1) {
       double lastLow = fractalLows_price[0];
       if(close[0] < lastLow) { // 现价跌破前低
           DrawLine("SMC_CHoCH_Bear", fractalLows_idx[0], lastLow, 0, lastLow, ColorCHOCH);
           DrawText("SMC_CHoCH_Txt", 0, lastLow, "CHoCH", ColorCHOCH, ANCHOR_LEFT_UPPER);
       }
   }

   return(rates_total);
  }
//+------------------------------------------------------------------+