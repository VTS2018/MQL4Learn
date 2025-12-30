//+------------------------------------------------------------------+
//|                                                    EasyTrend.mq4 |
//|                                             修复版 by Gemini     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019"
#property strict
#property indicator_chart_window // ✅ 声明这是一个指标

input int MaSlwPeriod   = 100; // 慢速均线周期
input int MaFstPeriod   = 60;  // 快速均线周期

// 定义对象名称前缀，防止误删其他指标
string Prefix = "EasyTrend_"; 

//+------------------------------------------------------------------+
//| 指标初始化
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. 启动定时器，每秒刷新一次 (比 OnTick 更省资源，且在周末也能显示静态数据)
   EventSetTimer(1); 
   
   // 2. 创建对象 (封装为函数，代码更整洁)
   CreateLabel("lblMaBig",     "4H慢均线",               clrHotPink, CORNER_RIGHT_UPPER, 200, 80);
   CreateLabel("lblMaSmall",   "4H快均线",               clrBlue,    CORNER_RIGHT_UPPER, 200, 100);
   CreateLabel("lblConclusion","趋势感知",               clrLime,    CORNER_RIGHT_UPPER, 200, 120);
   CreateLabel("lblAuthor",    "作者：K-target", clrGray,    CORNER_RIGHT_UPPER, 200, 140);
   CreateLabel("lblAdvice",    "操作建议：无",            clrRed,     CORNER_RIGHT_LOWER, 450, 20);
   
   // 立即执行一次刷新
   OnTimer();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 指标卸载 (安全清理)
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   // ✅ 修复：只删除本指标创建的对象 (通过前缀匹配)
   ObjectsDeleteAll(0, Prefix); 
}

//+------------------------------------------------------------------+
//| 标准指标计算函数 (这里仅用于占位，实际逻辑由 Timer 驱动)
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
{
   // 为了兼容性保留，可以在这里也调用一次逻辑，但 Timer 已经足够
   return(rates_total);
}

//+------------------------------------------------------------------+
//| ✅ 定时刷新逻辑 (替代原本无效的 OnTick)
//+------------------------------------------------------------------+
void OnTimer()
{
   // 1. 获取 H4 均线数据
   double maSlw = iMA(NULL, PERIOD_H4, MaSlwPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double maFst = iMA(NULL, PERIOD_H4, MaFstPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   
   // 2. 获取当前价格 (Bid/Ask 平均)
   double price = (MarketInfo(Symbol(), MODE_BID) + MarketInfo(Symbol(), MODE_ASK)) / 2.0;
   
   // 3. 更新显示
   int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   string fmt = "%." + IntegerToString(digits) + "f"; // 修正精度显示逻辑
   
   ObjectSetString(0, Prefix + "lblMaBig", OBJPROP_TEXT, "4H慢均线：" + StringFormat(fmt, maSlw));
   ObjectSetString(0, Prefix + "lblMaSmall", OBJPROP_TEXT, "4H快均线：" + StringFormat(fmt, maFst));
   
   // 4. 核心趋势逻辑
   string conclusion = "趋势感知：无";
   string advice = "操作建议：无";
   color  conColor = clrBlack;
   
   // 强势多头
   if(price > maSlw && price > maFst && maFst > maSlw)
   {
      conclusion = "趋势感知：强势多头↑↑↑";
      advice     = "操作建议：打死坚决不做空";
      conColor   = clrLime;
   }
   // 强势空头
   else if(price < maSlw && price < maFst && maFst < maSlw)
   {
      conclusion = "趋势感知：强势空头↓↓↓";
      advice     = "操作建议：打死坚决不做多";
      conColor   = clrHotPink; // 原版用的颜色
   }
   
   // 5. 刷新标签内容
   ObjectSetString(0, Prefix + "lblConclusion", OBJPROP_TEXT, conclusion);
   ObjectSetInteger(0, Prefix + "lblConclusion", OBJPROP_COLOR, conColor);
   
   ObjectSetString(0, Prefix + "lblAdvice", OBJPROP_TEXT, advice);
   // 动态调整建议位置
   ObjectSetInteger(0, Prefix + "lblAdvice", OBJPROP_XDISTANCE, 16 * StringLen(advice) + 16);
}

//+------------------------------------------------------------------+
//| 辅助函数：创建标签
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, color clr, int corner, int x, int y)
{
   string finalName = Prefix + name; // 加上前缀
   if(ObjectFind(0, finalName) < 0)
      ObjectCreate(0, finalName, OBJ_LABEL, 0, 0, 0);
      
   ObjectSetString(0, finalName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, finalName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, finalName, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, finalName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, finalName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, finalName, OBJPROP_FONTSIZE, 10); // 建议设置字体大小
   ObjectSetString(0, finalName, OBJPROP_FONT, "Microsoft YaHei"); // 建议设置字体
}