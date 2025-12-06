//+------------------------------------------------------------------+
//|                                                     Test_Fun.mq4 |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 06.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link "https://mql5.com"
#property version "1.00"
#property strict
#include <K_Data.mqh>

// 这是一个非常有效果的 链式 有效信号测试通过的 算法

void Test_FilterWeakBullishSignals();
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+

void OnStart()
{
   //--- 此番测试 是我们实现 信号上下文关系的关键所在  只有有效信号编织
   //编织的网才能确定信号的位置关系
   Test_FilterWeakBullishSignals();
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 模拟数据生成函数：创建具有已知 SL 序列的看涨信号列表             |
//+------------------------------------------------------------------+
int CreateMockBullishSignalsForTest(FilteredSignal &mock_signals[])
{
   // M1: 侦测到看涨信号 @ K[42] | 收盘价: 89173.99 | 止损价: 88911.11
   // M1: 侦测到看跌信号 @ K[86] | 收盘价: 89374.5 | 止损价: 89493.5
   // M1: 侦测到看涨信号 @ K[130] | 收盘价: 89309.5 | 止损价: 89204.0 X
   // M1: 侦测到看跌信号 @ K[172] | 收盘价: 89509.0 | 止损价: 89851.53999999999
   // M1: 侦测到看涨信号 @ K[232] | 收盘价: 89048.5 | 止损价: 88850.0
   // M1: 侦测到看跌信号 @ K[279] | 收盘价: 89380.0 | 止损价: 89843.0
   // M1: 侦测到看涨信号 @ K[356] | 收盘价: 88994.0 | 止损价: 88069.5

   ArrayResize(mock_signals, 4); // 确保数组大小为 5
   datetime current_time = Time[0];

   // 我们从最旧的信号（索引 4）开始定义，向最新（索引 0）填充

   // 信号 A (最旧，K[10]) - SL 4190.0
   // mock_signals[4].shift = 10;
   // mock_signals[4].signal_time = current_time - 10 * PeriodSeconds(_Period);
   // mock_signals[4].stop_loss = 4190.0;
   // mock_signals[4].type = OP_BUY;
   // mock_signals[4].confirmation_close = 4191.0;

   // 信号 B (K[8]) - SL 4192.0 (> 4190.0，保留)
   mock_signals[3].shift = 8;
   mock_signals[3].signal_time = current_time - 8 * PeriodSeconds(_Period);
   mock_signals[3].stop_loss = 88069.5;
   mock_signals[3].type = OP_BUY;
   mock_signals[3].confirmation_close = 88994.0;

   // 信号 C (K[6]) - SL 4192.0 (= 4192.0，预期过滤)
   mock_signals[2].shift = 6;
   mock_signals[2].signal_time = current_time - 6 * PeriodSeconds(_Period);
   mock_signals[2].stop_loss = 88850.0;
   mock_signals[2].type = OP_BUY;
   mock_signals[2].confirmation_close = 89048.5;

   // 信号 D (K[4]) - SL 4191.0 (< 4192.0，预期过滤)
   mock_signals[1].shift = 4;
   mock_signals[1].signal_time = current_time - 4 * PeriodSeconds(_Period);
   mock_signals[1].stop_loss = 89204.0;
   mock_signals[1].type = OP_BUY;
   mock_signals[1].confirmation_close = 89309.5;

   // 信号 E (最新，K[2]) - SL 4193.0 (> 4192.0，保留)
   mock_signals[0].shift = 2;
   mock_signals[0].signal_time = current_time - 2 * PeriodSeconds(_Period);
   mock_signals[0].stop_loss = 88911.11;
   mock_signals[0].type = OP_BUY;
   mock_signals[0].confirmation_close = 89173.99;

   return ArraySize(mock_signals);
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
    double threshold_close = source_signals[0].confirmation_close;

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
        threshold_close = older_signal.confirmation_close;
    }

    // 这里的 filtered_list 顺序已经是：最新 -> 较新 -> 老 -> 最老
    // 符合您 K[1] 往左寻找的直觉，不需要 ArrayReverse。
    
    return ArraySize(filtered_list);
}

//+------------------------------------------------------------------+
//| 测试 FilterWeakBullishSignals 函数的主入口点                     |
//+------------------------------------------------------------------+
void Test_FilterWeakBullishSignals()
{
    Print("=================================================");
    Print(">>> 单元测试：FilterWeakBullishSignals 开始 <<<");
    
    // 1. 构造模拟数据
    FilteredSignal mock_input_list[];
    CreateMockBullishSignalsForTest(mock_input_list);
    int original_size = ArraySize(mock_input_list);

    // 打印输入数据
    Print("\n--- 输入信号列表 (从 K[1] 往历史排序) ---");
    Print("原始信号数量: ", original_size);
    for (int i = 0; i < original_size; i++)
    {
        Print("输入 #", i + 1, " | K[", mock_input_list[i].shift, "] | SL: ", DoubleToString(mock_input_list[i].stop_loss, _Digits));
    }
    
    // 2. 执行过滤函数
    FilteredSignal filtered_output_list[];
    int final_count = FilterWeakBullishSignals(mock_input_list, filtered_output_list);

    // 3. 打印输出结果
    Print("\n--- 输出信号列表 (过滤后) ---");
    Print("最终有效信号数量: ", final_count);
    
    // 预期的有效信号应该是：E (4193.0) -> B (4192.0) -> A (4190.0)
    for (int i = 0; i < final_count; i++)
    {
        Print("输出 #", i + 1, " | K[", filtered_output_list[i].shift, "] | SL: ", DoubleToString(filtered_output_list[i].stop_loss, _Digits));
    }
    
    // 4. 最终验证结果
    if (final_count == 3 && 
        filtered_output_list[0].stop_loss == 88911.11 && // E
        filtered_output_list[1].stop_loss == 88850.0 && // B
        filtered_output_list[2].stop_loss == 88069.5)   // A
    {
        Print("\n✅ 单元测试通过：过滤结果与预期完全一致。");
    }
    else
    {
        Print("\n❌ 单元测试失败：过滤逻辑或数组处理存在错误。");
    }

    Print(">>> 单元测试：FilterWeakBullishSignals 结束 <<<");
    Print("=================================================");
}