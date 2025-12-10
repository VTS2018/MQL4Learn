//+------------------------------------------------------------------+
//|                                                         demo.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
#property indicator_chart_window
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
  //--- indicator buffers mapping
  // 先测试一下 这个文件能否diff出来差异
  //---

  long cid = ChartID();
  Print("-->[KTarget_Finder5.mq4:152]: cid: ", cid);
  // 2025.12.11 05:05:16.910	Learn1 ETHUSD,M5: -->[KTarget_Finder5.mq4:152]: cid: 134098742989818281
  // 2025.12.11 05:04:31.074	Learn1 ETHUSD,M5: -->[KTarget_Finder5.mq4:152]: cid: 134098452417334326

  // 取模 1000，获取 ChartID 的后三位
  // 结果是一个 0 到 999 之间的 int 整数
  int short_id_prefix = (int)(cid % 1000000);
  Print("-->[Learn1.mq4:28]: short_id_prefix: ", short_id_prefix);

  return (INIT_SUCCEEDED);
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
  //---

  //--- return value of prev_calculated for next call
  return (rates_total);
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
  //---
}
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  //---
}
//+------------------------------------------------------------------+
