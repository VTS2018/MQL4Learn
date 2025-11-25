//+------------------------------------------------------------------+
//|                                                      K_Logic.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
//+------------------------------------------------------------------+
// #property copyright "Copyright 2025, YourName"
// #property link      "https://mql5.com"
// #property strict

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2025

//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+

// #import "user32.dll"
//    int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//    int      ExpertRecalculate(int wParam,int lParam);
// #import

//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+

// #import "stdlib.ex5"
//    string ErrorDescription(int error_code);
// #import

//+------------------------------------------------------------------+
/**
 * 根据看涨K-target阴线锚点 寻找出收复P1的第一根K线的索引
 * @param target_index: 看涨K-target阴线锚点
 * @param is_bullish: 阳线还是阴线
 * @return ( int ) P1的K线索引。注意P1和P2 可能是同一根K线
 */
int FindFirstP1BreakoutIndex(int target_index, bool is_bullish)
{
    double P1_price = Open[target_index];
    //Print(">[KTarget_Finder4_FromGemini.mq4:771]: P1_price: ", P1_price);

    //向右边寻找 初始索引减去1 然后到最大前瞻
    for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
    {
        if (j < 0) break;

        if (is_bullish)
        {
            // 看涨突破 P1: Close > P1_price
            if (Close[j] > P1_price) return j;
        }
        else
        {
            // 看跌突破 P1: Close < P1_price
            if (Close[j] < P1_price) return j;
        }
    }
    return -1; // 未找到 P1 突破
}

//========================================================================
// 9. FindSecondBaseline: 查找第二基准价格线 (P2)
//========================================================================
/**
   查找 P2 价格：从 K-Target 锚点向左回溯，直到找到第一根符合条件的 K 线。
   看涨 (Bullish): 锚点左侧第一根阳线 (Close > Open) 的收盘价。
   看跌 (Bearish): 锚点左侧第一根阴线 (Close < Open) 的收盘价。
   约束条件 [V1.23 NEW]: P2 价格必须在 P1 价格之外 (看涨 P2 > P1, 看跌 P2 < P1)。

 * 根据看涨K-target阴线锚点，寻找到反向P2的索引，同时P2的价格一定要大于P1的价格（看涨），反之P2<P1(看跌)
 * @param target_index: 看涨K-target阴线锚点
 * @param is_bullish: 看涨或者看跌
 * @return ( int ) P2 反向K线的索引
 */
int FindP2Index(int target_index, bool is_bullish)
{
    double P1_price = Open[target_index];

    // P2 价格 (初始为 0.0)
    double P2_price = 0.0;

    int P2_index = -1;

    // 从锚点 K 线的左侧 (历史 K 线，索引 i+k) 开始回溯
    // 使用外部参数 Scan_Range 作为回溯上限
    for (int k = 1; k <= Scan_Range; k++)
    {
        int past_index = target_index + k;
        
        if (past_index >= Bars) break; // 边界检查
        
        bool condition_met = false;
        double candidate_P2 = 0.0;
        
        if (is_bullish)
        {
            // 看涨 P2: 锚点左侧第一根阳线 (Close > Open) 的收盘价
            if (Close[past_index] > Open[past_index])
            {
                candidate_P2 = Close[past_index];
                // 2. [新增约束] P2 价格必须高于 P1 价格
                if (candidate_P2 > P1_price)
                {
                    P2_price = candidate_P2;
                    P2_index = past_index;
                    condition_met = true;
                }
            }
        }
        else // is_bearish
        {
            // 看跌 P2: 锚点左侧第一根阴线 (Close < Open) 的收盘价
            if (Close[past_index] < Open[past_index])
            {
                candidate_P2 = Close[past_index];
                // 2. [新增约束] P2 价格必须低于 P1 价格
                if (candidate_P2 < P1_price)
                {
                    P2_price = candidate_P2;
                    P2_index = past_index;
                    condition_met = true;
                }
            }
        }

        if (condition_met) 
        {
            break; // 找到即退出
        }
    }

    // 3. 打印差值信息到日志 [V1.25 FIX]：仅在首次调试运行时打印
    if (Debug_Print_Info_Once && !initial_debug_prints_done)
    {
        Print("FindP2Index Info: P2_price = ", DoubleToString(P2_price, Digits), " points.", " P2_index = ", IntegerToString(P2_index));
    }
    
    return P2_index; 
}

//========================================================================
// 14. FindAbsoluteLowIndex: 查找指定范围内的绝对最低价/最高价K线索引 (V1.35 NEW)
//========================================================================
/**
 * 查找以 target_index 为中心，左右两侧 K 线内的绝对最低价 K 线索引。
 * * @param target_index: K-Target 锚点索引。
 * @param lookback_range: 向左（历史）回溯的 K 线数量 (例如 20)。
 * @param lookahead_range: 向右（较新）前瞻的 K 线数量 (例如 20)。
 * @param is_bullish: 查找最低价 (true) 还是最高价 (false)。
 * @return ( int ) 具有绝对最低/最高价的 K 线索引。
 */
int FindAbsoluteLowIndex(int target_index, int lookback_range, int lookahead_range, bool is_bullish)
{
    // 初始化
    double extreme_price = is_bullish ? Low[target_index] : High[target_index]; // 初始值使用 K-Target 本身的价格
    //Print("-->[KTarget_Finder4_FromGemini.mq4:959]: extreme_price: ", extreme_price);//先测试看涨的是否能 找到最低价格
    int extreme_index = target_index;

    // 1. 向右 (较新 K 线, i-k) 查找
    for (int k = 1; k <= lookahead_range; k++)
    {
        int current_index = target_index - k;
        if (current_index < 0) break;

        if (is_bullish) // 查找绝对最低价 (Lowest Low)
        {
            if (Low[current_index] < extreme_price)
            {
                extreme_price = Low[current_index];
                extreme_index = current_index;
            }
        }
        else // 查找绝对最高价 (Highest High)
        {
            if (High[current_index] > extreme_price)
            {
                extreme_price = High[current_index];
                extreme_index = current_index;
            }
        }
    }

    // 2. 向左 (历史 K 线, i+k) 查找
    for (int k = 1; k <= lookback_range; k++)
    {
        int current_index = target_index + k;
        if (current_index >= Bars) break;

        if (is_bullish) // 查找绝对最低价 (Lowest Low)
        {
            if (Low[current_index] < extreme_price)
            {
                extreme_price = Low[current_index];
                extreme_index = current_index;
            }
        }
        else // 查找绝对最高价 (Highest High)
        {
            if (High[current_index] > extreme_price)
            {
                extreme_price = High[current_index];
                extreme_index = current_index;
            }
        }
    }

    return extreme_index;
}