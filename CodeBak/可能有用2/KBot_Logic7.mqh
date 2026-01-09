//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ScanForTradeSignal_v3 (结构性止损修复版)
//| 功能：v3 引擎的信号扫描器 (适配器模式)
//| 修复：止损不再取锚点极值，而是搜索结构内的绝对极值 (Absolute High/Low)
//+------------------------------------------------------------------+
void ScanForTradeSignal_v3()
{
    // 1. 始终只扫描刚刚收盘的 K 线 (Shift 1)
    int shift = 1;
    
    // 假设向前回溯 60 根 K 线寻找结构
    int search_depth = 60; 

    // =============================================================
    // A. 扫描做多信号 (Bullish)
    // =============================================================
    for (int i = shift + 1; i < shift + search_depth; i++)
    {
        // 1. 调用主文件的找底函数
        if (CheckKTargetBottomCondition(i, Bars)) 
        {
            double p1 = Open[i];
            
            // 2. 简单的 P2 查找
            double p2 = 0;
            for(int k=1; k<50; k++) { if(Close[i+k] > Open[i+k]) { p2=Close[i+k]; break; } }
            if(p2==0) p2 = p1 * 1.001; 
            
            // 🚨 [修复] 寻找结构性止损 (Structural Stop Loss)
            // 范围：从 (锚点 - 前瞻) 到 (锚点 + 回溯)
            // 注意 MT4 索引：值越小越新。起始点应该是最右边(最新)的索引。
            int search_start = MathMax(0, i - Lookahead_Bottom);
            int search_end   = i + Lookback_Bottom;
            int count        = search_end - search_start + 1;
            
            // 在范围内搜索绝对最低点
            int sl_index = iLowest(NULL, 0, MODE_LOW, count, search_start);
            
            // 兜底：如果搜索失败(极少见)，回退使用锚点 Low
            if (sl_index < 0) sl_index = i;
            
            double sl = Low[sl_index]; 

            // 3. 检查 shift=1 是否触发了突破
            bool is_breakout = (Close[shift] > p1); 

            if (is_breakout)
            {
                // 4. 调用 v3 内核评分 (传入修正后的 sl)
                SignalQuality sq = EvaluateSignal(Symbol(), Period(), i, shift, p1, p2, sl, true);
                
                // 5. 决策
                if (sq.grade >= Min_Trade_Grade && sq.space_factor >= Min_Space_Factor)
                {
                    KBarSignal adapter_data;
                    adapter_data.OpenTime = Time[shift];
                    adapter_data.BullishStopLossPrice = sl; // 使用结构性止损
                    adapter_data.BullishReferencePrice = (double)sq.grade; 
                    adapter_data.BearishStopLossPrice = 0;
                    adapter_data.BearishReferencePrice = 0;

                    Print(" v3 触发做多! 评级:", sq.description, " 结构SL:", sl, " (Index:", sl_index, ")");
                    CalculateTradeAndExecute_V2(adapter_data, OP_BUY);
                    return; 
                }
            }
        }
    }

    // =============================================================
    // B. 扫描做空信号 (Bearish)
    // =============================================================
    for (int i = shift + 1; i < shift + search_depth; i++)
    {
        if (CheckKTargetTopCondition(i, Bars)) 
        {
            double p1 = Open[i];
            double p2 = 0;
            for(int k=1; k<50; k++) { if(Close[i+k] < Open[i+k]) { p2=Close[i+k]; break; } }
            if(p2==0) p2 = p1 * 0.999;
            
            // 🚨 [修复] 寻找结构性止损 (Structural Stop Loss)
            int search_start = MathMax(0, i - Lookahead_Top);
            int search_end   = i + Lookback_Top;
            int count        = search_end - search_start + 1;
            
            // 在范围内搜索绝对最高点
            int sl_index = iHighest(NULL, 0, MODE_HIGH, count, search_start);
            
            if (sl_index < 0) sl_index = i;

            double sl = High[sl_index];
            
            if (Close[shift] < p1) 
            {
                SignalQuality sq = EvaluateSignal(Symbol(), Period(), i, shift, p1, p2, sl, false);
                
                if (sq.grade >= Min_Trade_Grade && sq.space_factor >= Min_Space_Factor)
                {
                    KBarSignal adapter_data;
                    adapter_data.OpenTime = Time[shift];
                    adapter_data.BearishStopLossPrice = sl; // 使用结构性止损
                    adapter_data.BearishReferencePrice = (double)sq.grade;
                    adapter_data.BullishStopLossPrice = 0;
                    adapter_data.BullishReferencePrice = 0;

                    Print(" v3 触发做空! 评级:", sq.description, " 结构SL:", sl, " (Index:", sl_index, ")");
                    CalculateTradeAndExecute_V2(adapter_data, OP_SELL);
                    return;
                }
            }
        }
    }
}