//+------------------------------------------------------------------+
//|                                                     Console1.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   datetime current_time = TimeCurrent(); 
   Print("-->[Console1.mq4:16]: current_time: ", current_time);

  //---
  datetime P1_time = Time[1];
  string time_id_str = TimeToString(P1_time, TIME_DATE | TIME_SECONDS);
  Print("-->[Console1.mq4:18]: time_id_str: ", time_id_str);

  string ids = StringFormat("_%d_", ChartID());
  Print("-->[Console1.mq4:21]: ChartID(): ", ChartID());
  Print("-->[Console1.mq4:21]: ids: ", ids);
}
//+------------------------------------------------------------------+
