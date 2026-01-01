//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| EX5 imports
//| 收集 过滤 合并 业务逻辑的 开始部分 很重要
//| 此部分代码 是整个 信号检查 最最开始的部分 就是“线头”
//| 有了这个线头，后面的逻辑 就开始建立起来了
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| L0: 信号收集器 (CollectAllSignals)                               |
//| 职责：从指标缓冲区全量收集信号，并执行最高效的价格区位过滤。       |
//| V2.0 优化：确保 K[1] 信号不被价格区位过滤错误剔除。               |
//| 收集 过滤 合并 检查 四位一体
//+------------------------------------------------------------------+
void CollectAllSignals(FilteredSignal &bullish_list[], FilteredSignal &bearish_list[])
{
   // 1. 清空数组，准备重新收集 (数组将按 shift 从小到大填充，即从最新到最旧)
   ArrayResize(bullish_list, 0);
   ArrayResize(bearish_list, 0);

   // 🚨 核心修正 1：获取现价基准 (使用当前 K 线的收盘价 Close[0])
   double current_price = Close[0];

   // 2. 开始扫描：从 K[1] (shift=1) 往历史左侧扫描
   for (int shift = 1; shift <= Indi_LastScan_Range; shift++)
   {
      // A. 批量读取所有缓冲区数据 (假设 GetIndicatorBarData 可用)
      KBarSignal data = GetIndicatorBarData(shift);

      // =============================================================
      // 🚨 核心修正 2：K[1] 信号的无条件通行权
      // 确保 K[1] 不被 K[0] 的跳空低开/高开错误过滤
      // =============================================================
      bool is_valid_price_zone = false;

      if (shift == 1)
      {
         // K[1] (最新信号) 具有最高优先级，无条件通过价格区位检查
         is_valid_price_zone = true;
      }
      else // K[2] 及更老的信号，必须进行价格区位检查
      {
         // --- 看涨信号的价格区位检查 (必须低于现价) ---
         if (data.BullishReferencePrice != (double)EMPTY_VALUE && data.BullishReferencePrice != 0.0)
         {
            if (Close[shift] < current_price)
               is_valid_price_zone = true;
         }
         // --- 看跌信号的价格区位检查 (必须高于现价) ---
         else if (data.BearishReferencePrice != (double)EMPTY_VALUE && data.BearishReferencePrice != 0.0)
         {
            if (Close[shift] > current_price)
               is_valid_price_zone = true;
         }
      }

      // ---------------------------------------------
      // B. 检查并添加看涨信号 (OP_BUY)
      // ---------------------------------------------
      if (data.BullishReferencePrice != (double)EMPTY_VALUE &&
          (int)data.BullishReferencePrice >= Min_Signal_Quality && // 信号质量检查
          data.BullishStopLossPrice != (double)EMPTY_VALUE && data.BullishStopLossPrice != 0.0)
      {
         // 🚨 引入价格区位检查
         if (is_valid_price_zone)
         {
            int current_size = ArraySize(bullish_list);
            ArrayResize(bullish_list, current_size + 1);

            // Print("BullishReferencePrice--DoubleToString：",DoubleToString(data.BullishReferencePrice), " Int:", IntegerToString((int)data.BullishReferencePrice));
            bullish_list[current_size].shift = shift;
            bullish_list[current_size].signal_time = data.OpenTime;
            bullish_list[current_size].confirmation_close = Close[shift];
            bullish_list[current_size].stop_loss = data.BullishStopLossPrice;
            bullish_list[current_size].type = OP_BUY;
         }
      }

      // ---------------------------------------------
      // C. 检查并添加看跌信号 (OP_SELL)
      // ---------------------------------------------
      if (data.BearishReferencePrice != (double)EMPTY_VALUE &&
          (int)data.BearishReferencePrice >= Min_Signal_Quality && // 信号质量检查
          data.BearishStopLossPrice != (double)EMPTY_VALUE && data.BearishStopLossPrice != 0.0)
      {
         // 🚨 引入价格区位检查
         if (is_valid_price_zone)
         {
            int current_size = ArraySize(bearish_list);
            ArrayResize(bearish_list, current_size + 1);

            // Print("BearishReferencePrice--DoubleToString：",DoubleToString(data.BearishReferencePrice), " Int:", IntegerToString((int)data.BearishReferencePrice));
            bearish_list[current_size].shift = shift;
            bearish_list[current_size].signal_time = data.OpenTime;
            bearish_list[current_size].confirmation_close = Close[shift];
            bearish_list[current_size].stop_loss = data.BearishStopLossPrice;
            bearish_list[current_size].type = OP_SELL;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 信号弱势过滤 (看涨 - 新低优胜逻辑)                              |
//| 逻辑：从最新信号开始往历史回溯。                                 |
//|      如果 Newer.Close < Older.SL，则 Older 无效 (被击穿)。       |
//|      如果 Newer.Close >= Older.SL，则 Older 有效 (支撑有效)。    |
//+------------------------------------------------------------------+
int FilterWeakBullishSignals(FilteredSignal &source_signals[], FilteredSignal &filtered_list[])
{
    // 1. 初始化
    ArrayResize(filtered_list, 0);
    int total = ArraySize(source_signals);
    
    if (total == 0) return 0;

    // 2. 总是保留最新的信号 (索引 0，即 shift 最小的信号)
    // 因为它是离现价最近的市场事实，无论它长什么样，它都是最新的参考点
    ArrayResize(filtered_list, 1);
    filtered_list[0] = source_signals[0];

    // 3. 设定初始比较基准：使用最新信号的【收盘价】
    double threshold_close = source_signals[0].stop_loss;

    // 4. 向历史方向遍历 (从索引 1 开始，即次新的信号)
    for (int i = 1; i < total; i++)
    {
        FilteredSignal older_signal = source_signals[i];
        
        // -------------------------------------------------------------
        // 🚨 核心逻辑：新低优胜 🚨
        // 比较：最新有效信号的 Close vs 历史信号的 SL
        // -------------------------------------------------------------
        
        // 情况 A: 击穿 (Invalidation)
        // 如果较新的 Close 价格 低于 历史信号的 SL (最低价)
        // 说明最新的价格已经打破了该历史信号的结构，该历史信号失效。
        if (threshold_close < older_signal.stop_loss)
        {
            // Print("❌ 过滤 (看涨): 历史信号 K[", older_signal.shift, "] SL:", older_signal.stop_loss, 
            //       " 被较新信号 Close:", threshold_close, " 击穿。排除。");
            
            // 排除该信号，继续循环。
            // 阈值 threshold_close 保持不变 (继续用较新的这个低价去检验更老的信号)
            continue;
        }

        // 情况 B: 支撑有效 (Validation)
        // 如果较新的 Close 价格 高于或等于 历史信号的 SL
        // 说明虽然可能有回调，但没有打穿该历史信号的底，该历史信号依然作为阶梯存在。
        
        // 加入有效列表
        int new_index = ArraySize(filtered_list);
        ArrayResize(filtered_list, new_index + 1);
        filtered_list[new_index] = older_signal;

        // 🚨 关键更新：既然这个历史信号有效，它就成为更早信号的验证者 🚨
        // 我们更新阈值为这个历史信号的 Close
        threshold_close = older_signal.stop_loss;
    }

    // 这里的 filtered_list 顺序已经是：最新 -> 较新 -> 老 -> 最老
    // 符合您 K[1] 往左寻找的直觉，不需要 ArrayReverse。
    
    return ArraySize(filtered_list);
}
//+------------------------------------------------------------------+
//| 信号弱势过滤 (看跌 - 新高优胜逻辑)                              |
//| 逻辑：Newer.Close > Older.SL，则 Older 无效 (被涨破)。           |
//+------------------------------------------------------------------+
int FilterWeakBearishSignals(FilteredSignal &source_signals[], FilteredSignal &filtered_list[])
{
    ArrayResize(filtered_list, 0);
    int total = ArraySize(source_signals);
    
    if (total == 0) return 0;

    // 1. 保留最新信号
    ArrayResize(filtered_list, 1);
    filtered_list[0] = source_signals[0];

    // 2. 设定初始比较基准：使用最新信号的【收盘价】
    double threshold_close = source_signals[0].stop_loss;

    // 3. 向历史方向遍历
    for (int i = 1; i < total; i++)
    {
        FilteredSignal older_signal = source_signals[i];
        
        // -------------------------------------------------------------
        // 🚨 核心逻辑：新高优胜 🚨
        // 看跌信号的 SL 是最高价 (压力位)
        // -------------------------------------------------------------
        
        // 情况 A: 涨破 (Invalidation)
        // 如果较新的 Close 价格 高于 历史信号的 SL (最高价)
        // 说明最新的价格已经反向突破了该历史信号的压力位，该历史信号失效。
        if (threshold_close > older_signal.stop_loss)
        {
            // Print("❌ 过滤 (看跌): 历史信号 K[", older_signal.shift, "] SL:", older_signal.stop_loss, 
            //       " 被较新信号 Close:", threshold_close, " 涨破。排除。");
            continue;
        }

        // 情况 B: 压力有效 (Validation)
        // 较新的 Close 依然在 历史信号 SL 之下
        int new_index = ArraySize(filtered_list);
        ArrayResize(filtered_list, new_index + 1);
        filtered_list[new_index] = older_signal;

        // 更新阈值
        threshold_close = older_signal.stop_loss;
    }

    return ArraySize(filtered_list);
}

//+------------------------------------------------------------------+
//| 辅助函数：合并看涨和看跌列表，并按 shift 从小到大 (由新到旧) 排序  |
//+------------------------------------------------------------------+
void MergeAndSortSignals(FilteredSignal &bulls[], FilteredSignal &bears[], FilteredSignal &result_list[])
{
   int size_bull = ArraySize(bulls);
   int size_bear = ArraySize(bears);
   int total_size = size_bull + size_bear;

   // 1. 重置结果数组大小
   ArrayResize(result_list, total_size);

   // 2. 合并数据
   int index = 0;
   // 先放入看涨信号
   for (int i = 0; i < size_bull; i++)
   {
      result_list[index] = bulls[i];
      index++;
   }
   // 再放入看跌信号
   for (int i = 0; i < size_bear; i++)
   {
      result_list[index] = bears[i];
      index++;
   }

   // 3. 排序 (冒泡排序 Bubble Sort)
   // 目标：按 shift 值从小到大排序 (shift 1 是最新，shift 100 是较旧)
   // 这样循环时，我们总是先处理离现价最近的有效信号
   if (total_size > 1)
   {
      for (int i = 0; i < total_size - 1; i++)
      {
         for (int j = 0; j < total_size - i - 1; j++)
         {
            // 如果前一个信号的 shift 比后一个大 (说明前一个更旧)，则交换
            if (result_list[j].shift > result_list[j + 1].shift)
            {
               FilteredSignal temp = result_list[j];
               result_list[j] = result_list[j + 1];
               result_list[j + 1] = temp;
            }
         }
      }
   }
}