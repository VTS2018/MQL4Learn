//+------------------------------------------------------------------+
//|                                                    EasyTrend.mq4 |
//|                                      Visual Enhanced by Gemini   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, 环球外汇网友交流群@Aother"
#property link      "https://www.mql5.com"
#property version   "1.02"
#property strict
#property indicator_chart_window

// --- 1. 定义绘图属性 ---
#property indicator_buffers 2    // 缓冲区数量：2个
#property indicator_plots   2    // 绘图数量：2条线

// 设定第1条线：慢速均线 (H4)
#property indicator_label1  "H4 Slow MA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrHotPink
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// 设定第2条线：快速均线 (H4)
#property indicator_label2  "H4 Fast MA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

// --- 输入参数 ---
input int MaSlwPeriod   = 100; // 慢速均线周期 (H4)
input int MaFstPeriod   = 60;  // 快速均线周期 (H4)

// --- 缓冲区数组 ---
double ExtMaSlwBuffer[];
double ExtMaFstBuffer[];

// --- 全局变量 ---
string Prefix = "EasyTrend_"; 

//+------------------------------------------------------------------+
//| 指标初始化
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. 绑定缓冲区 (让数组对应图表上的线)
   SetIndexBuffer(0, ExtMaSlwBuffer);
   SetIndexBuffer(1, ExtMaFstBuffer);
   
   // 2. 设置无效值 (不画线的地方)
   SetIndexEmptyValue(0, 0.0);
   SetIndexEmptyValue(1, 0.0);

   // 3. 创建面板对象
   CreateLabel("lblMaBig",     "4H慢均线",               clrHotPink, CORNER_RIGHT_UPPER, 200, 80);
   CreateLabel("lblMaSmall",   "4H快均线",               clrBlue,    CORNER_RIGHT_UPPER, 200, 100);
   CreateLabel("lblConclusion","趋势感知",               clrLime,    CORNER_RIGHT_UPPER, 200, 120);
   CreateLabel("lblAuthor",    "作者：K-target", clrGray,    CORNER_RIGHT_UPPER, 200, 140);
   CreateLabel("lblAdvice",    "操作建议：无",            clrRed,     CORNER_RIGHT_LOWER, 450, 20);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 指标卸载
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{   
   // 清理对象
   ObjectDelete(0, "lblMaBig");
   ObjectDelete(0, "lblMaSmall");
   ObjectDelete(0, "lblAuthor");
   ObjectDelete(0, "lblConclusion");
   ObjectDelete(0, "lblAdvice");
   // 增强版清理：如果有前缀匹配的也删除(兼容旧版)
   ObjectsDeleteAll(0, Prefix);
}

//+------------------------------------------------------------------+
//| 主计算函数
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
   // --- A. 绘图逻辑 (画出 H4 均线) ---
   
   // 确定计算范围
   int limit = rates_total - prev_calculated;
   if (limit > 0) limit = rates_total - 1; // 首次或数据更新时重算
   
   // 遍历 K 线
   for (int i = limit; i >= 0; i--)
   {
      // 1. 核心难点：找到当前 K 线时间对应的 H4 K 线位置
      // 这里的 time[i] 是当前图表某根 K 线的时间
      // iBarShift 帮我们找到这个时间在 H4 周期是第几根 K 线
      int shift_h4 = iBarShift(NULL, PERIOD_H4, time[i]);
      
      // 2. 计算 H4 均线数值
      // 注意：ma_shift=1 (原代码逻辑)
      ExtMaSlwBuffer[i] = iMA(NULL, PERIOD_H4, MaSlwPeriod, 1, MODE_SMA, PRICE_CLOSE, shift_h4);
      ExtMaFstBuffer[i] = iMA(NULL, PERIOD_H4, MaFstPeriod, 1, MODE_SMA, PRICE_CLOSE, shift_h4);
   }

   // --- B. 面板更新逻辑 (仅更新最新一根) ---
   
   // 获取最新的 H4 均线值 (对应 i=0 的位置)
   double maSlw = ExtMaSlwBuffer[0]; 
   double maFst = ExtMaFstBuffer[0];
   
   // 获取当前价格
   double price = (MarketInfo(_Symbol, MODE_BID) + MarketInfo(_Symbol, MODE_ASK)) / 2.0;

   // 更新文字显示
   int digits = (int)MarketInfo(_Symbol, MODE_DIGITS);
   string fmt = "%." + IntegerToString(digits-1) + "f";
   
   ObjectSetString(0,"lblMaBig",OBJPROP_TEXT,"4H慢均线：" + StringFormat(fmt,maSlw));
   ObjectSetString(0,"lblMaSmall",OBJPROP_TEXT,"4H快均线：" + StringFormat(fmt,maFst));
   
   // 趋势判断逻辑
   string conclusion = "趋势感知：无";
   string advice = "操作建议：无";
   color  conColor = clrBlack;
   
   if(price > maSlw && price > maFst && maFst > maSlw)
   {
      conclusion = "趋势感知：强势多头↑↑↑";
      advice     = "操作建议：打死坚决不做空";
      conColor   = clrLime;
   }
   else if(price < maSlw && price < maFst && maFst < maSlw)
   {   
      conclusion = "趋势感知：强势空头↓↓↓";
      advice     = "操作建议：打死坚决不做多";
      conColor   = clrHotPink;
   }
   
   ObjectSetString(0,"lblConclusion",OBJPROP_TEXT, conclusion);
   ObjectSetInteger(0,"lblConclusion",OBJPROP_COLOR, conColor);
   
   ObjectSetString(0,"lblAdvice",OBJPROP_TEXT, advice);
   ObjectSetInteger(0,"lblAdvice",OBJPROP_XDISTANCE, 16*StringLen(advice) + 16); 
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 辅助函数：创建标签
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, color clr, int corner, int x, int y)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Microsoft YaHei");
}