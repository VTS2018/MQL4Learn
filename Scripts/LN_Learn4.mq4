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
  /*
  datetime current_time = TimeCurrent();
  Print("-->[Console1.mq4:16]: current_time: ", current_time);

  //---
  datetime P1_time = Time[1];
  string time_id_str = TimeToString(P1_time, TIME_DATE | TIME_SECONDS);
  Print("-->[Console1.mq4:18]: time_id_str: ", time_id_str);

  string ids = StringFormat("_%d_", ChartID());
  Print("-->[Console1.mq4:21]: ChartID(): ", ChartID());
  Print("-->[Console1.mq4:21]: ids: ", ids);

  */

  int arr[3][4] = {
      {1, 2, 3, 4},
      {5, 6, 7, 8},
      {9, 10, 11, 12}}; // 静态初始化

  int rows = ArrayRange(arr,0); // 获取第一维（行）的大小
  // int rows = ArrayRange(arr, 0); // 另一种获取维数大小的方法

  Print("数组的行数: ", rows);

  double FiboExhaustionLevels[4][2] = {
      {1.618, 1.88},
      {2.618, 2.88},
      {4.236, 4.88},
      {6.000, 7.000} // 使用您最新的自定义级别
  };

  int zones_count = ArrayRange(FiboExhaustionLevels,0);
  // 调试打印：此时 zones_count 应该正确显示 4
  Print("---->[KTarget_FinderBot.mq4:1273]: zones_count: ", zones_count);
}
//+------------------------------------------------------------------+
