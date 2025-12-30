//+------------------------------------------------------------------+
//|                                      SMC_Structure_IDM_Fix.mq4   |
//|                                  Copyright 2024, CD_SMC_Analysis |
//+------------------------------------------------------------------+
#property copyright "CD_SMC_Analysis"
#property strict
#property indicator_chart_window

//--- input parameters
input int      FractalLeft   = 5;    // 左侧K线数量 (分形强度)
input int      FractalRight  = 2;    // 右侧K线数量
input color    ColorBOS      = clrLime; // BOS 颜色
input color    ColorCHOCH    = clrRed;  // CHoCH 颜色
input color    ColorIDM      = clrOrange; // IDM 颜色
input color    ColorStructure= clrGray; // 结构连线颜色

//--- buffers
double         HighBuffer[];
double         LowBuffer[];

//--- 内部存储结构 (增加到 2000 以防溢出)
int fractalHighs_idx[2000];
double fractalHighs_price[2000];
int fractalLows_idx[2000];
double fractalLows_price[2000];
int hCount=0;
int lCount=0;

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
   if(idx1 < 0 || idx2 < 0) return; // 安全检查
   
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
   if(idx < 0) return; // 安全检查
   
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
   // 1. 关键修复：将数组设置为序列模式 (0 = 最新K线)
   // 这样 high[0] 就是当前K线，与 Time[0] 对应，防止越界
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   if(rates_total < 100) return(0); // 数据太少不计算

   // 每次重绘 (为了逻辑简单，实际生产环境可优化)
   ObjectsDeleteAll(0, "SMC_");
   hCount = 0;
   lCount = 0;
   
   // 2. 识别分形 (注意循环边界)
   // i 从 FractalRight 开始，到 rates_total - FractalLeft 结束
   for(int i = FractalRight; i < rates_total - FractalLeft; i++) {
      
      // 防止数组写满
      if(hCount >= 1999 || lCount >= 1999) break;

      bool isHigh = true;
      bool isLow = true;
      
      // 检查左侧
      for(int j=1; j<=FractalLeft; j++) {
         if(high[i] <= high[i+j]) isHigh = false;
         if(low[i] >= low[i+j]) isLow = false;
      }
      // 检查右侧
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

   // 3. 寻找 IDM (诱导点)
   if(hCount > 2 && lCount > 2) {
      // 假设我们要找最近一个 High 的 IDM
      // 逻辑：最近 High 左侧的第一个 Low
      int lastHighIdx = fractalHighs_idx[0]; // 最近的分形高点
      // double lastHighPrice = fractalHighs_price[0]; 
      
      int idmIdx = -1;
      double idmPrice = 0;
      
      for(int m=0; m<lCount; m++) {
         // 因为是 Series 数组，Index 越大代表越旧 (越靠左)
         if(fractalLows_idx[m] > lastHighIdx) {
            idmIdx = fractalLows_idx[m];
            idmPrice = fractalLows_price[m];
            break; // 找到第一个就停止
         }
      }
      
      if(idmIdx != -1) {
         DrawText("SMC_IDM", idmIdx, idmPrice, "IDM", ColorIDM, ANCHOR_TOP);
         DrawLine("SMC_IDM_Line", idmIdx, idmPrice, lastHighIdx, idmPrice, ColorIDM, STYLE_DOT);
      }
      
      // 4. 简单的 ZigZag 结构连线 (只画最近20笔)
      int ch = 0; 
      int cl = 0;
      int max_legs = 20;
      int leg_count = 0;
      
      while(ch < hCount && cl < lCount && leg_count < max_legs) {
         int hIdx = fractalHighs_idx[ch];
         int lIdx = fractalLows_idx[cl];
         
         // 哪个索引小，哪个就是更新发生的 (因为 0 是最新)
         if(hIdx < lIdx) { // 高点比低点新 -> 连线从低点到高点
            DrawLine("SMC_Leg_"+(string)leg_count, lIdx, fractalLows_price[cl], hIdx, fractalHighs_price[ch], ColorStructure);
            ch++; 
         } else { // 低点比高点新 -> 连线从高点到低点
            DrawLine("SMC_Leg_"+(string)leg_count, hIdx, fractalHighs_price[ch], lIdx, fractalLows_price[cl], ColorStructure);
            cl++;
         }
         leg_count++;
      }
      
      // 5. 标注 BOS (结构突破)
      // 如果最近的 High[0] 高于 High[1]，且 High[0] 还没有被 High[1] 之后的 Low 跌破太多(简化逻辑)
      if(fractalHighs_price[0] > fractalHighs_price[1]) {
         // 在 High[1] 的水平画线延伸到 High[0] 的时间
         DrawLine("SMC_BOS_Bull", fractalHighs_idx[1], fractalHighs_price[1], fractalHighs_idx[0], fractalHighs_price[1], ColorBOS);
         DrawText("SMC_BOS_Txt", fractalHighs_idx[0], fractalHighs_price[1], "BOS", ColorBOS, ANCHOR_LEFT_LOWER);
      }
      
      // 6. 标注 CHoCH (角色互换)
      // 如果现价 (close[0]) 跌破了最近的一个主要分形低点
      if(close[0] < fractalLows_price[0]) {
          DrawLine("SMC_CHoCH_Bear", fractalLows_idx[0], fractalLows_price[0], 0, fractalLows_price[0], ColorCHOCH);
          DrawText("SMC_CHoCH_Txt", 0, fractalLows_price[0], "CHoCH", ColorCHOCH, ANCHOR_LEFT_UPPER);
      }
   }

   return(rates_total);
  }
//+------------------------------------------------------------------+