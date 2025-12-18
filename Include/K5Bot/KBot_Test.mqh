//+------------------------------------------------------------------+
//|                                                    KBot_Test.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 09.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 测试 FilterWeakBullishSignals 函数的主入口点                     |
//+------------------------------------------------------------------+
void Test_FilterWeakBullish_And_BearishSignals(FilteredSignal &raw_bullish_list[], FilteredSignal &raw_bearish_list[], FilteredSignal &clean_bullish_list[], FilteredSignal &clean_bearish_list[])
{
   if (!Debug_Print_Valid_List)
   {
      return;
   }
   
   Print("=================================================");
   Print(">>> 单元测试：FilterWeakBullishSignals 开始 <<<");

   // 1. 构造模拟数据
   int original_size = ArraySize(raw_bullish_list);

   // 打印输入数据
   Print("\n--- 输入信号列表 (从 K[1] 往历史排序) ---");
   Print("原始【看涨】信号数量: ", original_size);
   for (int i = 0; i < original_size; i++)
   {
      Print("输入 #", i + 1, " | K[", raw_bullish_list[i].shift, "] | SL: ", DoubleToString(raw_bullish_list[i].stop_loss, _Digits));
   }

   // 2. 执行过滤函数
   int final_count = ArraySize(clean_bullish_list);

   // 3. 打印输出结果
   Print("\n--- 输出信号列表 (过滤后) ---");
   Print("最终【看涨】有效信号数量: ", final_count);

   for (int i = 0; i < final_count; i++)
   {
      Print("输出 #", i + 1, " | K[", clean_bullish_list[i].shift, "] | SL: ", DoubleToString(clean_bullish_list[i].stop_loss, _Digits));
   }

   Print(">>> 单元测试：FilterWeakBullishSignals 结束 <<<");
   Print("=================================================");

   Print("===========================================看涨和看跌的分割线便于查看===========================================");
   
   Print("=================================================");
   Print(">>> 单元测试：FilterWeakBearishSignals 开始 <<<");

   // 1. 构造模拟数据
   int original_size_1 = ArraySize(raw_bearish_list);

   // 打印输入数据
   Print("\n--- 输入信号列表 (从 K[1] 往历史排序) ---");
   Print("原始【看跌】信号数量: ", original_size_1);
   for (int i = 0; i < original_size_1; i++)
   {
      Print("输入 #", i + 1, " | K[", raw_bearish_list[i].shift, "] | SL: ", DoubleToString(raw_bearish_list[i].stop_loss, _Digits));
   }

   // 2. 执行过滤函数
   int final_count_1 = ArraySize(clean_bearish_list);

   // 3. 打印输出结果
   Print("\n--- 输出信号列表 (过滤后) ---");
   Print("最终【看跌】有效信号数量: ", final_count_1);

   for (int i = 0; i < final_count_1; i++)
   {
      Print("输出 #", i + 1, " | K[", clean_bearish_list[i].shift, "] | SL: ", DoubleToString(clean_bearish_list[i].stop_loss, _Digits));
   }

   Print(">>> 单元测试：FilterWeakBearishSignals 结束 <<<");
   Print("=================================================");

}

void Test_MergeAndSortSignals(FilteredSignal &merge_list[])
{
   if (!Debug_Print_Valid_List)
   {
      return;
   }
   Print("=================================================");
   Print(">>> 单元测试：合并以后的看涨和看跌信号列表 开始 <<<");

   // 1. 构造模拟数据
   int original_size = ArraySize(merge_list);

   // 打印输入数据
   Print("\n--- 输入信号列表 (从 K[1] 往历史排序) ---");
   Print("【合并以后】信号数量: ", original_size);
   for (int i = 0; i < original_size; i++)
   {
      Print("输入 #", i + 1, " | K[", merge_list[i].shift, "] | SL: ", DoubleToString(merge_list[i].stop_loss, _Digits));
   }

   Print(">>> 单元测试：合并以后的看涨和看跌信号列表 结束 <<<");
   Print("=================================================");
}