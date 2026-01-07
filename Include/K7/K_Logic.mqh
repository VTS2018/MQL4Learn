//+------------------------------------------------------------------+
//|                                                      K_Logic.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
//+------------------------------------------------------------------+

bool IsKTargetBottom(int i, int total_bars)
{
    if (Find_Target_Model == 2)
    {
        return CheckKTargetBottomCondition(i, total_bars, Lookahead_Bottom, Lookback_Bottom);
    }

    return CheckKTargetBottom_Default(i, total_bars, Lookahead_Bottom, Lookback_Bottom);
}

bool IsKTargetTop(int i, int total_bars)
{
    if (Find_Target_Model == 2)
    {
        return CheckKTargetTopCondition(i, total_bars, Lookahead_Top, Lookback_Top);
    }

    return CheckKTargetTop_Default(i, total_bars, Lookahead_Top, Lookback_Top);
}

//========================================================================
// CheckKTargetBottom_Default: 检查目标反转阴线 (K-Target Bottom) (无变化)
//========================================================================
/*
   条件: 阴线，且收盘价是左右两侧周期内的最低收盘价。
*/
bool CheckKTargetBottom_Default(int i, int total_bars, int lookahead, int lookback)
{
    // 1. 必须是阴线 (Bearish Candle)
    if (Close[i] >= Open[i]) return false;
    
    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= lookahead; k++)
    {
        int future_index = i - k; 
        if (future_index < 0) break; 
        // 必须是最低收盘价
        if (Close[future_index] < Close[i]) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= lookback; k++)
    {
        int past_index = i + k; 
        if (past_index >= total_bars) break; 
        // 必须是最低收盘价
        if (Close[past_index] < Close[i]) return false;
    }
    
    return true;
}

//========================================================================
// CheckKTargetTop_Default: 检查目标反转阳线 (K-Target Top) (无变化)
//========================================================================
/*
   条件: 阳线，且收盘价是左右两侧周期内的最高收盘价。
*/
bool CheckKTargetTop_Default(int i, int total_bars, int lookahead, int lookback)
{
    // 1. 必须是阳线 (Bullish Candle)
    if (Close[i] <= Open[i]) return false;
    
    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= lookahead; k++)
    {
        int future_index = i - k; 
        if (future_index < 0) break; 
        // 必须是最高收盘价
        if (Close[future_index] > Close[i]) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= lookback; k++)
    {
        int past_index = i + k; 
        if (past_index >= total_bars) break; 
        // 必须是最高收盘价
        if (Close[past_index] > Close[i]) return false;
    }
    
    return true;
}

//========================================================================
// [V2 Upgrade] CheckKTargetBottomCondition
// 功能：查找看涨锚点 (底部被动买单区)
// 核心哲学：必须是阴线(主动卖盘撞击)，且引线创出区域最低点(流动性极限)
//========================================================================
bool CheckKTargetBottomCondition(int i, int total_bars, int lookahead, int lookback)
{
    // 1. 身份验证 (Identity Check)
    // 必须是阴线。
    // 含义：价格下跌，但这根K线所在的位置是被动买单(Limit Buys)的密集区。
    // 如果是阳线(Hammer)，说明当根K线买方已经反攻，不再是纯粹的"锚点"定义。
    if (Close[i] >= Open[i]) return false;

    // 2. 地位验证 (Geometry Check - V2 Upgrade)
    // 使用 Low (引线) 进行比较，而不是 Close。
    // 含义：我们要找的是被动买单防守的"极限位置"。
    double anchor_low = Low[i];

    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= lookahead; k++)
    {
        int future_index = i - k;
        if (future_index < 0) break;
        
        // 如果右边有K线的 Low 更低(或相等)，说明当前位置不是最低防守点
        if (Low[future_index] <= anchor_low) return false; 
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= lookback; k++)
    {
        int past_index = i + k;
        if (past_index >= total_bars) break; 
        
        // 如果左边有K线的 Low 更低(或相等)，说明当前位置不是新结构低点
        if (Low[past_index] <= anchor_low) return false;
    }
    
    return true;
}

//========================================================================
// [V2 Upgrade] CheckKTargetTopCondition
// 功能：查找看跌锚点 (顶部被动卖单区)
// 核心哲学：必须是阳线(主动买盘撞击)，且引线创出区域最高点(流动性极限)
//========================================================================
bool CheckKTargetTopCondition(int i, int total_bars, int lookahead, int lookback)
{
    // 1. 身份验证 (Identity Check)
    // 必须是阳线。
    // 含义：价格上涨，撞击上方的被动卖单(Limit Sells)。
    if (Close[i] <= Open[i]) return false;

    // 2. 地位验证 (Geometry Check - V2 Upgrade)
    // 使用 High (引线) 进行比较。
    double anchor_high = High[i];

    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= lookahead; k++)
    {
        int future_index = i - k;
        if (future_index < 0) break; 
        
        // 如果右边有更高的 High，说明这里没挡住，不是有效锚点
        if (High[future_index] >= anchor_high) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= lookback; k++)
    {
        int past_index = i + k;
        if (past_index >= total_bars) break; 
        
        // 如果左边有更高的 High，说明这里不是新结构高点
        if (High[past_index] >= anchor_high) return false;
    }
    
    return true;
}

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
// FindSecondBaseline: 查找第二基准价格线 (P2)
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
    // if (Debug_Print_Info_Once && !initial_debug_prints_done)
    // {
    //     Print("FindP2Index Info: P2_price = ", DoubleToString(P2_price, Digits), " points.", " P2_index = ", IntegerToString(P2_index));
    // }
    
    return P2_index; 
}

//========================================================================
// FindAbsoluteLowIndex: 查找指定范围内的绝对最低价/最高价K线索引 (V1.35 NEW)
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

/**
 * 根据当前图表周期和信号类型，返回高亮矩形应使用的颜色。
 * 颜色选择注重与黑色字体的高对比度。
 * @param is_bullish: 是否为看涨信号 (true=看涨, false=看跌)。
 * @return 最终确定的颜色常量。
 */
color GetHighlightColorByPeriod(bool is_bullish)
{
    color rect_color;
    int current_period = _Period; // 获取当前周期 (分钟数)
    
    // 1. 默认颜色
    rect_color = is_bullish ? HIGHLIGHT_COLOR_B : HIGHLIGHT_COLOR_S;

    // 2. 周期特定颜色覆盖
    if (current_period == PERIOD_D1) // 日周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_D1_B : HIGHLIGHT_COLOR_D1_S;
    }
    else if (current_period == PERIOD_H4) // 4H 周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_H4_B : HIGHLIGHT_COLOR_H4_S;
    }
    else if (current_period == PERIOD_H1) // 1H 周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_H1_B : HIGHLIGHT_COLOR_H1_S;
    }
    // 3. 未来扩展区域 (例如 W1, MN1)
    else if (current_period == PERIOD_W1) // 周周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_W1_B : HIGHLIGHT_COLOR_W1_S;
    }
    else if (current_period == PERIOD_MN1) // 月周期
    {
        rect_color = is_bullish ? HIGHLIGHT_COLOR_MN1_B : HIGHLIGHT_COLOR_MN1_S;
    }
    
    return rect_color;
}

/**
 * 根据当前图表周期 (_Period) 返回一组优化的参数。
 * 调优逻辑：在短周期增加K线数，在长周期减少K线数，以使时间范围更合理。
 */
TuningParameters GetTunedParameters()
{
    TuningParameters p;
    
    // 设置默认值 (如果周期不匹配，则使用 M15/H1 附近的基准值)
    p.Scan_Range             = 500;
    p.Lookahead_Bottom       = 20;
    p.Lookback_Bottom        = 20;
    p.Lookahead_Top          = 20;
    p.Lookback_Top           = 20;
    p.Max_Signal_Lookforward = 20;
    p.Look_LLHH_Candles      = 3;
    
    // 根据周期动态调整参数
    switch (_Period)
    {
        case PERIOD_M1: // M1：波动极快，需要更多的K线来定义结构
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 30;
            p.Lookahead_Top = p.Lookback_Top = 30;

            p.Max_Signal_Lookforward = 30;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M5: // M5：比 M1 稳定，但仍需比默认值大一些
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 25;
            p.Lookahead_Top = p.Lookback_Top = 25;

            p.Max_Signal_Lookforward = 25;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M15: // M15：基准周期，略低于默认值，专注于近期结构
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 18;
            p.Lookahead_Top = p.Lookback_Top = 18;

            p.Max_Signal_Lookforward = 18;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M30: // M30：更稳定，可进一步减少
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 15;
            p.Lookahead_Top = p.Lookback_Top = 15;

            p.Max_Signal_Lookforward = 15;
            p.Look_LLHH_Candles = 3;
            break;

        case PERIOD_H1: // H1：稳定的中周期
            p.Scan_Range = 500;
            p.Lookahead_Bottom = p.Lookback_Bottom = 12;
            p.Lookahead_Top = p.Lookback_Top = 12;

            p.Max_Signal_Lookforward = 24;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_H4: // H4：长周期开始，K线代表的市场意义大增
            // 扫描范围覆盖约 2-3 周
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 8;
            p.Lookahead_Top = p.Lookback_Top = 8;

            // 也就是说 前瞻扫描的范围可以大一些 没关系 这个地方 会影响锚点的标注 如果过小会导致一些锚点 无法识别出来
            // 按说 不应该影响锚点的 标注，这里代码可能还有一些问题
            // 按理论上讲 锚点标注的逻辑 不应该收到前瞻 信号扫描的 范围影响的
            // 是不是由于 低开K线的影响导致的标注呢？
            p.Max_Signal_Lookforward = 15;
            p.Look_LLHH_Candles = 3;
            break;
            
        // 开始调整 日周期 确认K前瞻 是5根 5天    
        case PERIOD_D1: // D1：日周期，遵循您的思路 (约 1-1.5 周)
            // 扫描范围覆盖约 1 个月
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 2;
            p.Lookahead_Top = p.Lookback_Top = 2;

            p.Max_Signal_Lookforward = 5;
            //周期越大 数值可以设置的越小 如果是2 至少保证 5日内的最高价和最低价
            p.Look_LLHH_Candles = 2;
            break;
            
        case PERIOD_W1: // W1：周周期，只需要关注最近几周或几个月的结构
            // 扫描范围覆盖约 3 个月
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 3;
            p.Lookahead_Top = p.Lookback_Top = 3;

            p.Max_Signal_Lookforward = 3;
            p.Look_LLHH_Candles = 3;
            break;
            
        // 月线调整为2    
        case PERIOD_MN1: // MN1：月周期，只需关注最近半年
            // 扫描范围覆盖约 6 个月
            p.Scan_Range = 300; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 2;
            p.Lookahead_Top = p.Lookback_Top = 2;

            p.Max_Signal_Lookforward = 3;
            p.Look_LLHH_Candles = 2;
            break;
    }
    
    return p;
}

/**
 * ✅
 * 看涨阴线锚点的索引是开头，它一旦找到了 就可以找到 P1,接着就能找到P2,接着就能找到 最低价K线索引
 * @param target_index: 看涨阴线锚点的索引
 * @param P2_index: 突破P2的K线的索引
 * @param K_Geo_Index: 突破P1的K线的索引
 * @param N_Geo: 突破P1的K线的数量
 * @param abs_lowindex 最低价K线的索引  可能等于 target_index 锚点索引
 */
void CheckBullishSignalConfirmation_Default(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex)
{
    // *** 关键修改：在处理新信号之前，清除该锚点上可能存在的任何旧矩形 ***
    // ClearSignalRectangle_v2(abs_lowindex, true);

    // K_Geo_Index 必须有效，否则协调者已经跳过了。
    // P2_price 必须有效，否则协调者已经跳过了。

    // P1 价格，用于判断 P2 是否高于 P1 (安全检查)
    double P1_price = Open[target_index];
    
    double P2_price = Close[P2_index];

    // --- 阶段 A: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 突破 (K_P2)
    // P2 价格必须高于 P1 价格，否则 P2 突破不成立
    if (P2_price > P1_price)
    {
        // 查找范围从锚点右侧到 Max_Signal_Lookforward 结束
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            // 检查 P2 突破条件：收盘价高于 P2 价格
            if (Close[j] > P2_price) 
            {
                // **绘制 P2 辅助线** (职责：只有在 P2 突破时才绘制 P2 线)
                DrawP2Baseline(P2_index, j, true);

                if (abs_lowindex != -1)
                {
                    /* 只有信号成立才绘制矩形 */
                    DrawP1P2Rectangle(abs_lowindex, j, true);

                    //DrawP1P2Fibonacci(abs_lowindex, j, true); 这里会绘制出所有的 斐波所以我设置了一个开关 所以这里取消就行了
                }

                // 找到 K_P2。绘制 P2 箭头 (高偏移)

                if (Is_EA_Mode)
                {
                    // 🚨 修正：Buffer 0 和 Buffer 2 赋值必须同步且在 j 索引上 🚨
                    if (abs_lowindex != -1)
                    {
                        // 1. 写入 SL 价格 (Buffer 0) 到确认 K 线索引 'j'
                        BullishTargetBuffer[j] = Low[abs_lowindex];
                    }
                    BullishSignalBuffer[j] = 3.0;
                }
                else
                {
                    BullishSignalBuffer[j] = Low[j] - 30 * Point();
                }

                return; // 找到最高级别信号，立即退出函数
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB) - 检查第一次 P1 突破是否满足 DB 延迟
    // 如果代码执行到这里，说明整个 N=5 范围内都没有 P2 突破。同时还说明 没有找到P2突破 但是一定有P1突破的索引 一定有P1突破
    
    // 检查第一次 P1 突破是否满足 DB 延迟 (N >= 3)
    if (N_Geo >= DB_Threshold_Candles)
    {
        //**绘制 P2 辅助线** (职责：在 P1-DB 确认时也绘制 P2 线)
        DrawP2Baseline(P2_index, K_Geo_Index, true);

        if (abs_lowindex != -1)
        {
            /* 只有信号成立才绘制矩形 */
            DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);
        }

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        if (Is_EA_Mode)
        {
            // 🚨 修正：Buffer 0 和 Buffer 2 赋值必须同步且在 K_Geo_Index 索引上 🚨
            if (abs_lowindex != -1)
            {
                // 1. 写入 SL 价格 (Buffer 0) 到确认 K 线索引 K_Geo_Index
                BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];
            }
            BullishSignalBuffer[K_Geo_Index] = 2.0;
        }
        else
        {
            BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point();
        }

        return; // 找到次高级别信号，立即退出函数
    }
    
    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
}


void CheckBearishSignalConfirmation_Default(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_hightindex)
{
    // *** 关键修改：在处理新信号之前，清除该锚点上可能存在的任何旧矩形 ***
    // ClearSignalRectangle_v2(abs_hightindex, false);

    double P1_price = Open[target_index];
    double P2_price = Close[P2_index];

    // --- 阶段 B: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 突破 (K_P2)
    if (P2_price < P1_price) // 看跌信号 P2 < P1
    {
        // 只需检查到 K_Geo_Index (第一次 P1 突破点) 为止
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            if (Close[j] < P2_price) // 🚨 看跌：Close < P2
            {
                // 绘制P2线
                DrawP2Baseline(P2_index, j, false);
                if (abs_hightindex != -1)
                {
                    DrawP1P2Rectangle(abs_hightindex, j, false);
                }

                // 找到 K_P2。绘制 P2 箭头 (高偏移)
                if (Is_EA_Mode)
                {
                    if (abs_hightindex != -1)
                    {
                        BearishTargetBuffer[j] = High[abs_hightindex];
                    }

                    BearishSignalBuffer[j] = 3.0;
                }
                else
                {
                    BearishSignalBuffer[j] = High[j] + 30 * Point();
                }

                return; // 找到最高级别信号，立即退出函数
            }
        }
    }

    // 2. 次优先级: 查找 P1-DB 突破 (K_DB) - 检查第一次 P1 突破是否满足 DB 延迟
    // 如果代码执行到这里，说明整个 N=5 范围内都没有 P2 突破。
    
    // 检查第一次 P1 突破是否满足 DB 延迟 (N >= 3)
    if (N_Geo >= DB_Threshold_Candles)
    {
        // **绘制 P2 辅助线** (职责：在 P1-DB 确认时也绘制 P2 线)
        DrawP2Baseline(P2_index, K_Geo_Index, false);

        if (abs_hightindex != -1)
        {
            DrawP1P2Rectangle(abs_hightindex, K_Geo_Index, false);
        }

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        if (Is_EA_Mode)
        {
            if (abs_hightindex != -1)
            {
                BearishTargetBuffer[K_Geo_Index] = High[abs_hightindex];
            }
            BearishSignalBuffer[K_Geo_Index] = 2.0;
        }
        else
        {
            BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point();
        }
        
        return; // 找到次高级别信号，立即退出函数
    }

    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
}

/*
//+------------------------------------------------------------------+
//| CheckBullishSignalConfirmationV2 (高级增强版)
//| ------------------------------------------------------------------
//| 变更日志：
//| 1. 引入 Enable_V3_Logic 开关
//| 2. 在信号确认点植入 EvaluateSignal 评分系统
//| 3. 集成 SendRichAlert 和 DrawFiboZones
//+------------------------------------------------------------------+
void CheckBullishSignalConfirmationV2(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex)
{
    // *** 关键修改：在处理新信号之前，清除该锚点上可能存在的任何旧矩形 ***
    // ClearSignalRectangle_v2(abs_lowindex, true);
    // ***************************************************************

    // 数据准备 (为 V3 内核准备原材料)
    double P1_price = Open[target_index];
    double P2_price = Close[P2_index];
    
    // 安全检查：如果没有找到绝对低点，使用锚点最低价作为止损兜底
    double SL_price = (abs_lowindex != -1) ? Low[abs_lowindex] : Low[target_index]; 

    // --- 阶段 A: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 突破 (K_P2)
    if (P2_price > P1_price)
    {
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            
            // [确认点] P2 突破
            if (Close[j] > P2_price) 
            {
                // 绘制基础线条 (原逻辑)
                DrawP2Baseline(P2_index, j, true);
                if (abs_lowindex != -1) DrawP1P2Rectangle(abs_lowindex, j, true);

                // =========================================================
                // 🔪 [手术切口 A] P2 强力突破 (CB) - V3 逻辑植入
                // =========================================================
                if (Enable_V3_Logic)
                {
                    // 1. 调用内核评分 (传入 j 作为突破索引)
                    SignalQuality sq = EvaluateSignal(Symbol(), Period(), target_index, j, P1_price, P2_price, SL_price, true);
                    
                    // 2. 执行高级动作 (仅处理非垃圾信号)
                    if (sq.grade >= GRADE_D)
                    {
                         // 打印 & 报警
                         if (sq.grade >= Min_Alert_Grade) 
                             SendRichAlert(Symbol(), Period(), "Bullish(P2-Break)", Close[j], SL_price, sq);
                         
                         // 斐波那契 (仅 Grade A/S)
                         if (sq.grade >= GRADE_A)
                             DrawFiboGradeZones(Symbol(), j, SL_price, Close[j], true, g_object_prefix);
                    }
                }
                // =========================================================

                // 设置 Buffer (原逻辑保持兼容)
                if (Is_EA_Mode)
                {
                    if (abs_lowindex != -1) BullishTargetBuffer[j] = Low[abs_lowindex];
                    BullishSignalBuffer[j] = 3.0; // 3.0 代表 P2 突破
                }
                else
                {
                    BullishSignalBuffer[j] = Low[j] - 30 * Point();
                }

                // 旧版报警 (互斥)
                if (!Enable_V3_Logic && Is_EA_Mode == false) 
                {
                    // 这里可以放原来的简单 Alert...
                }

                return; // 找到最高优信号，退出
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB)
    // 如果代码执行到这里，说明没有 P2 突破，但协调者确认有 P1 突破
    
    if (N_Geo >= DB_Threshold_Candles)
    {
        // 绘制基础线条 (原逻辑)
        DrawP2Baseline(P2_index, K_Geo_Index, true);
        if (abs_lowindex != -1) DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);

        // =========================================================
        // 🔪 [手术切口 B] P1 结构突破 (DB) - V3 逻辑植入
        // =========================================================
        if (Enable_V3_Logic)
        {
            // 1. 调用内核评分 (传入 K_Geo_Index 作为突破索引)
            // 注意：虽然这里是 DB，但也要评估是否顺便过了 P2 (内核会自动判断)
            SignalQuality sq = EvaluateSignal(Symbol(), Period(), target_index, K_Geo_Index, P1_price, P2_price, SL_price, true);
            
            // 2. 执行高级动作
            if (sq.grade >= GRADE_D)
            {
                 if (sq.grade >= Min_Alert_Grade) 
                     SendRichAlert(Symbol(), Period(), "Bullish(DB-Break)", Close[K_Geo_Index], SL_price, sq);
                 
                 if (sq.grade >= GRADE_A)
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], true, g_object_prefix);
            }
        }
        // =========================================================

        // 设置 Buffer (原逻辑保持兼容)
        if (Is_EA_Mode)
        {
            if (abs_lowindex != -1) BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];
            BullishSignalBuffer[K_Geo_Index] = 2.0; // 2.0 代表 DB 突破
        }
        else
        {
            BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point();
        }

        return; // 找到次优信号，退出
    }
    
    return;
}

//+------------------------------------------------------------------+
//| CheckBearishSignalConfirmationV2 (做空方向高级增强版)
//| ------------------------------------------------------------------
//| 核心逻辑：镜像 Bullish 版本，处理 P2 向下突破和 DB 向下突破
//+------------------------------------------------------------------+
void CheckBearishSignalConfirmationV2(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_highindex)
{
    // *** 清除旧矩形 (如有) ***
    // ClearSignalRectangle_v2(abs_highindex, false);
    // ***************************************************************

    // 数据准备
    double P1_price = Open[target_index]; // 锚点开盘价
    double P2_price = Close[P2_index];    // 左侧支撑价 (注意：做空时 P2 是支撑)
    
    // 安全检查：如果没有找到绝对高点，使用锚点最高价作为止损
    double SL_price = (abs_highindex != -1) ? High[abs_highindex] : High[target_index]; 

    // --- 阶段 A: 信号箭头标记 ---

    // 1. 最高优先级: 查找 P2 向下突破 (K_P2)
    // 逻辑：P2(支撑) 必须低于 P1，否则结构不成立 (或者您保留原始逻辑不做此检查)
    // 这里的 if 取决于您原始代码是否要求 P2 < P1。通常做空要求 P2 在下方。
    if (P2_price < P1_price) 
    {
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            
            // [确认点] P2 向下突破 (Close < P2)
            if (Close[j] < P2_price) 
            {
                // 绘制基础线条
                DrawP2Baseline(P2_index, j, false); // false 代表 Bearish
                if (abs_highindex != -1) DrawP1P2Rectangle(abs_highindex, j, false);

                // =========================================================
                // 🔪 [手术切口 A] P2 强力突破 (CB) - V3 逻辑植入
                // =========================================================
                if (Enable_V3_Logic)
                {
                    // 1. 调用内核评分 (注意最后参数 false 代表 Bearish)
                    SignalQuality sq = EvaluateSignal(Symbol(), Period(), target_index, j, P1_price, P2_price, SL_price, false);
                    
                    // 2. 执行高级动作
                    if (sq.grade >= GRADE_D)
                    {
                         if (sq.grade >= Min_Alert_Grade) 
                             SendRichAlert(Symbol(), Period(), "Bearish(P2-Break)", Close[j], SL_price, sq);
                         
                         if (sq.grade >= GRADE_A)
                             DrawFiboGradeZones(Symbol(), j, SL_price, Close[j], false, g_object_prefix);
                    }
                }
                // =========================================================

                // 设置 Buffer
                if (Is_EA_Mode)
                {
                    if (abs_highindex != -1) BearishTargetBuffer[j] = High[abs_highindex];
                    BearishSignalBuffer[j] = 3.0; 
                }
                else
                {
                    BearishSignalBuffer[j] = High[j] + 30 * Point(); // 箭头在K线上方
                }

                // 旧版报警 (互斥)
                if (!Enable_V3_Logic && Is_EA_Mode == false) 
                {
                    // Alert("Bearish P2 Break...");
                }

                return; 
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 向下突破 (K_DB)
    if (N_Geo >= DB_Threshold_Candles)
    {
        DrawP2Baseline(P2_index, K_Geo_Index, false);
        if (abs_highindex != -1) DrawP1P2Rectangle(abs_highindex, K_Geo_Index, false);

        // =========================================================
        // 🔪 [手术切口 B] P1 结构突破 (DB) - V3 逻辑植入
        // =========================================================
        if (Enable_V3_Logic)
        {
            // 调用内核评分 (is_bullish = false)
            SignalQuality sq = EvaluateSignal(Symbol(), Period(), target_index, K_Geo_Index, P1_price, P2_price, SL_price, false);
            
            if (sq.grade >= GRADE_D)
            {
                 if (sq.grade >= Min_Alert_Grade) 
                     SendRichAlert(Symbol(), Period(), "Bearish(DB-Break)", Close[K_Geo_Index], SL_price, sq);
                 
                 if (sq.grade >= GRADE_A)
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], false, g_object_prefix);
            }
        }
        // =========================================================

        if (Is_EA_Mode)
        {
            if (abs_highindex != -1) BearishTargetBuffer[K_Geo_Index] = High[abs_highindex];
            BearishSignalBuffer[K_Geo_Index] = 2.0; 
        }
        else
        {
            BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point();
        }

        return;
    }
    
    return;
}
*/

//+------------------------------------------------------------------+
//| CheckBullishSignalConfirmationV3 (做多方向最终完整版)
//| ------------------------------------------------------------------
//| 包含功能：
//| 1. v3 评分系统 (EvaluateSignal)
//| 2. 斐波那契自动绘图 (DrawFiboGradeZones)
//| 3. 智能战报 (SendRichAlert)
//| 4. [新增] 历史信号过滤 (j <= 1)
//| 5. [新增] 防重复报警时间锁 (g_LastAlertTime)
//+------------------------------------------------------------------+
void CheckBullishSignalConfirmation(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex)
{
    // *** 数据准备 ***
    double P1_price = Open[target_index];
    double P2_price = Close[P2_index];
    
    // 安全检查：如果没有找到绝对低点，使用锚点最低价作为止损兜底
    double SL_price = (abs_lowindex != -1) ? Low[abs_lowindex] : Low[target_index]; 

    // --- 阶段 A: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 突破 (K_P2)
    if (P2_price > P1_price)
    {
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            // >>>>>>>>> 【新增补丁】 <<<<<<<<<
            // 强制跳过当前正在跳动的 K 线 (Index 0)，只看已收盘的 (Index >= 1)
            if (j == 0) continue;
            // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

            // [确认点] P2 突破
            if (Close[j] > P2_price)
            {
                // [修复 1] 在 if (Enable_V3_Logic) 之前声明变量，提升作用域
                SignalQuality sq;
                sq.grade = GRADE_NONE; // 默认初始化

                // 绘制基础线条
                DrawP2Baseline(P2_index, j, true);

                if (abs_lowindex != -1)
                {
                    DrawP1P2Rectangle(abs_lowindex, j, true);
                    // 参数: 锚点索引, 信号索引, 类型字符串, 止损价, 确认收盘价, 方向
                    DrawSignalInfoText(abs_lowindex, j, "CB", SL_price, Close[j], true);
                }

                // =========================================================
                // 🔪 [手术切口 A] P2 强力突破 (CB) - V3 逻辑植入
                // =========================================================
                if (Enable_V3_Logic)
                {
                    // 1. 调用内核评分
                    sq = EvaluateSignal(Symbol(), Period(), N_Geo, j, P1_price, P2_price, SL_price, true);
                    g_Stats.Add(sq.grade);
                    // [日志] 做多详情
                    if (Test_Print_Detail)
                    {
                        Print("Pass: [BUY] Time:", TimeToString(Time[j]), " Grade:", sq.description);
                    }

                    // 2. 执行高级动作
                    if (sq.grade >= GRADE_D)
                    {
                         // -----------------------------------------------------------
                         // 🛡️ [报警过滤器] 核心风控逻辑
                         // -----------------------------------------------------------
                         // 规则1：只在最新K线(0)或刚收盘K线(1)触发，过滤历史
                         bool is_live_signal = (j <= 1); 
                         // 规则2：时间戳必须大于上一次报警时间，防止单根K线重复报
                         bool is_new_time    = (iTime(Symbol(), Period(), j) > g_LastAlertTime);
                         
                         if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time) 
                         {
                             // 发送战报
                             SendRichAlert(Symbol(), Period(), "Bullish(P2-Break)", Close[j], SL_price, sq);
                             
                             // 🔒 更新时间锁
                             g_LastAlertTime = iTime(Symbol(), Period(), j); 
                         }

                         // ---------------------------------------------------
                         // 🎨 [绘图控制] 智能斐波那契
                         // ---------------------------------------------------
                         // 1. 检查信号生存状态
                         bool is_active = CheckSignalStatus(j, SL_price, true); // true=做多

                         // 斐波那契绘图 (无需过滤历史，历史也要画)
                         // 传入 true (做多) 和 全局前缀
                         if (sq.grade >= GRADE_A && is_active)
                         {
                             DrawFiboGradeZones(Symbol(), j, SL_price, Close[j], true, g_object_prefix);
                         }
                    }
                }
                // =========================================================

                // 设置 Buffer
                if (Is_EA_Mode)
                {
                    if (abs_lowindex != -1) BullishTargetBuffer[j] = Low[abs_lowindex];
                    // BullishSignalBuffer[j] = 3.0; // 3.0 = P2 Break
                    // 核心修改：计算编码值
                    double grade_val = GetGradeWeight(sq.grade);
                    BullishSignalBuffer[j] = 3.0 + grade_val; // 例如 3.4
                }
                else
                {
                    BullishSignalBuffer[j] = Low[j] - 30 * Point();
                }

                // 旧版报警 (互斥)
                // if (!Enable_V3_Logic && Is_EA_Mode == false) 
                // {
                //     // Alert("Old Signal...");
                // }

                return; 
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB)
    if (N_Geo >= DB_Threshold_Candles)
    {
        SignalQuality sq;
        sq.grade = GRADE_NONE;

        DrawP2Baseline(P2_index, K_Geo_Index, true);

        if (abs_lowindex != -1)
        {
            DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);
            DrawSignalInfoText(abs_lowindex, K_Geo_Index, "DB", SL_price, Close[K_Geo_Index], true);
        }

        // =========================================================
        // 🔪 [手术切口 B] P1 结构突破 (DB) - V3 逻辑植入
        // =========================================================
        if (Enable_V3_Logic)
        {
            // 1. 调用内核评分 (传入 K_Geo_Index)
            sq = EvaluateSignal(Symbol(), Period(), N_Geo, K_Geo_Index, P1_price, P2_price, SL_price, true);
            g_Stats.Add(sq.grade);
            // [日志] 做多详情
            if (Test_Print_Detail)
            {
                Print("Pass: [BUY] Time:", TimeToString(Time[K_Geo_Index]), " Grade:", sq.description);
            }

            // 2. 执行高级动作
            if (sq.grade >= GRADE_D)
            {
                 // 🛡️ [报警过滤器]
                 bool is_live_signal = (K_Geo_Index <= 1); 
                 bool is_new_time    = (iTime(Symbol(), Period(), K_Geo_Index) > g_LastAlertTime);

                 if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time) 
                 {
                     SendRichAlert(Symbol(), Period(), "Bullish(DB-Break)", Close[K_Geo_Index], SL_price, sq);
                     g_LastAlertTime = iTime(Symbol(), Period(), K_Geo_Index);
                 }

                 bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, true); // true=做多
                 // 斐波那契绘图
                 if (sq.grade >= GRADE_A && is_active)
                 {
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], true, g_object_prefix);
                 }
            }
        }
        // =========================================================

        if (Is_EA_Mode)
        {
            if (abs_lowindex != -1) BullishTargetBuffer[K_Geo_Index] = Low[abs_lowindex];
            // BullishSignalBuffer[K_Geo_Index] = 2.0; // 2.0 = DB Break
            double grade_val = GetGradeWeight(sq.grade);
            BullishSignalBuffer[K_Geo_Index] = 2.0 + grade_val;
        }
        else
        {
            BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point();
        }

        return;
    }
    
    return;
}

//+------------------------------------------------------------------+
//| CheckBearishSignalConfirmationV3 (做空方向高级增强版)
//| ------------------------------------------------------------------
//| 核心逻辑：镜像 Bullish 版本，处理 P2 向下突破和 DB 向下突破
//| 集成了 v3 评分系统、斐波那契投影、以及历史报警过滤器
//+------------------------------------------------------------------+
void CheckBearishSignalConfirmation(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_highindex)
{
    // *** 1. 数据准备 (Data Prep) ***
    double P1_price = Open[target_index]; // 锚点开盘价
    double P2_price = Close[P2_index];    // 左侧支撑价 (做空时 P2 应为支撑)
    
    // 安全检查：如果没有找到绝对高点，使用锚点最高价作为止损兜底
    double SL_price = (abs_highindex != -1) ? High[abs_highindex] : High[target_index]; 

    // --- 阶段 A: 信号箭头标记 (瀑布式查找) ---

    // 1. 最高优先级: 查找 P2 向下突破 (K_P2)
    // 逻辑：P2(支撑) 通常应低于 P1，结构才顺畅 (此处保留原逻辑的结构判断)
    if (P2_price < P1_price) 
    {
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            if (j == 0) continue;
            
            // [确认点] P2 向下突破 (Close < P2)
            if (Close[j] < P2_price) 
            {
                SignalQuality sq;
                sq.grade = GRADE_NONE; // 默认初始化

                // 绘制基础线条 (原逻辑: false 代表 Bearish)
                DrawP2Baseline(P2_index, j, false);

                if (abs_highindex != -1)
                {
                    DrawP1P2Rectangle(abs_highindex, j, false);
                    DrawSignalInfoText(abs_highindex, j, "CB", SL_price, Close[j], false);
                }

                // =========================================================
                // 🔪 [手术切口 A] P2 强力突破 (CB) - V3 逻辑植入
                // =========================================================
                if (Enable_V3_Logic)
                {
                    // 1. 调用内核评分 (注意最后参数 false 代表 Bearish)
                    sq = EvaluateSignal(Symbol(), Period(), N_Geo, j, P1_price, P2_price, SL_price, false);
                    g_Stats.Add(sq.grade);
                    if (Test_Print_Detail)
                    {
                        Print("Pass: [SELL] Time:", TimeToString(Time[j]), " Grade:", sq.description);
                    }

                    // 2. 执行高级动作 (仅处理非垃圾信号)
                    if (sq.grade >= GRADE_D)
                    {
                         // -----------------------------------------------------------
                         // 🛡️ [报警过滤器] 只报实盘新信号 (Index 0或1)，且不重复
                         // -----------------------------------------------------------
                         bool is_live_signal = (j <= 1); 
                         bool is_new_time    = (iTime(Symbol(), Period(), j) > g_LastAlertTime);

                         if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time) 
                         {
                             // 发送做空战报
                             SendRichAlert(Symbol(), Period(), "Bearish(P2-Break)", Close[j], SL_price, sq);
                             // 更新全局时间锁
                             g_LastAlertTime = iTime(Symbol(), Period(), j);
                         }

                         // ---------------------------------------------------
                         // 🎨 [绘图控制] 智能斐波那契
                         // ---------------------------------------------------
                         // 1. 检查信号生存状态 (注意：is_bullish = false)
                         bool is_active = CheckSignalStatus(j, SL_price, false);

                         // 斐波那契绘图 (无需过滤历史，历史也要画)
                         // 传入 false (做空) 和 全局前缀
                         if (sq.grade >= GRADE_A && is_active)
                         {
                             DrawFiboGradeZones(Symbol(), j, SL_price, Close[j], false, g_object_prefix);
                         }
                    }
                }
                // =========================================================

                // 设置 Buffer (原 EA 逻辑保持兼容)
                if (Is_EA_Mode)
                {
                    if (abs_highindex != -1) BearishTargetBuffer[j] = High[abs_highindex];
                    // BearishSignalBuffer[j] = 3.0; // 3.0 = P2 Break
                    double grade_val = GetGradeWeight(sq.grade);
                    BearishSignalBuffer[j] = 3.0 + grade_val; 
                }
                else
                {
                    BearishSignalBuffer[j] = High[j] + 30 * Point(); // 箭头在K线上方
                }

                // 旧版报警 (互斥处理)
                // if (!Enable_V3_Logic && Is_EA_Mode == false) 
                // {
                //     // Alert("Old Bearish Signal...");
                // }

                return; // 找到最高优信号，退出
            }
        }
    }
    
    // 2. 次优先级: 查找 P1-DB 向下突破 (K_DB)
    // 如果代码执行到这里，说明没有 P2 突破，但协调者确认有 P1 突破 (K_Geo_Index)
    
    if (N_Geo >= DB_Threshold_Candles)
    {
        SignalQuality sq;
        sq.grade = GRADE_NONE;

        // 绘制基础线条
        DrawP2Baseline(P2_index, K_Geo_Index, false);
        if (abs_highindex != -1)
        {
            DrawP1P2Rectangle(abs_highindex, K_Geo_Index, false);
            DrawSignalInfoText(abs_highindex, K_Geo_Index, "DB", SL_price, Close[K_Geo_Index], false);
        }

        // =========================================================
        // 🔪 [手术切口 B] P1 结构突破 (DB) - V3 逻辑植入
        // =========================================================
        if (Enable_V3_Logic)
        {
            // 1. 调用内核评分 (传入 K_Geo_Index)
            sq = EvaluateSignal(Symbol(), Period(), N_Geo, K_Geo_Index, P1_price, P2_price, SL_price, false);
            g_Stats.Add(sq.grade);
            if (Test_Print_Detail)
            {
                Print("Pass: [SELL] Time:", TimeToString(Time[K_Geo_Index]), " Grade:", sq.description);
            }

            // 2. 执行高级动作
            if (sq.grade >= GRADE_D)
            {
                 // 🛡️ [报警过滤器]
                 bool is_live_signal = (K_Geo_Index <= 1); 
                 bool is_new_time    = (iTime(Symbol(), Period(), K_Geo_Index) > g_LastAlertTime);

                 if (sq.grade >= Min_Alert_Grade && is_live_signal && is_new_time) 
                 {
                     SendRichAlert(Symbol(), Period(), "Bearish(DB-Break)", Close[K_Geo_Index], SL_price, sq);
                     g_LastAlertTime = iTime(Symbol(), Period(), K_Geo_Index);
                 }

                 bool is_active = CheckSignalStatus(K_Geo_Index, SL_price, false);
                 // 斐波那契绘图
                 if (sq.grade >= GRADE_A && is_active)
                 {
                     DrawFiboGradeZones(Symbol(), K_Geo_Index, SL_price, Close[K_Geo_Index], false, g_object_prefix);
                 }
            }
        }
        // =========================================================

        if (Is_EA_Mode)
        {
            if (abs_highindex != -1) BearishTargetBuffer[K_Geo_Index] = High[abs_highindex];
            // BearishSignalBuffer[K_Geo_Index] = 2.0; // 2.0 = DB Break
            double grade_val = GetGradeWeight(sq.grade);
            BearishSignalBuffer[K_Geo_Index] = 2.0 + grade_val;
        }
        else
        {
            BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point();
        }

        return;
    }
    
    return;
}

/*
//+------------------------------------------------------------------+
//| CheckSignalStatus
//| 功能: 检查历史信号是否依然有效 (Active)
//| 返回: true=有效(应绘制), false=无效(已止损或已止盈，应隐藏)
//+------------------------------------------------------------------+
bool CheckSignalStatus_V1(int signal_index, double sl_price, bool is_bullish)
{
    // 1. 如果是当前最新信号 (0 或 1)，永远视为有效
    if (signal_index <= 1) return true;

    // 2. 如果用户不想看任何历史信号，直接返回 false
    if (!Show_History_Fibo) return false;

    // 3. 如果用户选择显示历史，但不隐藏失效的，那就都显示
    if (!Hide_Invalid_Fibo) return true;

    // 4. --- 智能判断逻辑 (Trader's Eye) ---
    // 遍历从信号发生后(signal_index - 1) 到 当前(0) 的所有K线
    // 注意：MT4索引越小越新
    
    // 设定“完美止盈”的标准：斐波那契 4.236 (动能耗尽点)
    // 估算 range
    double entry_price = (is_bullish ? High[signal_index] : Low[signal_index]); // 估算
    double range = MathAbs(entry_price - sl_price);
    
    for (int k = signal_index - 1; k >= 0; k--)
    {
        if (is_bullish)
        {
            // A. 检查止损 (失效)
            if (Low[k] <= sl_price) return false; // 价格跌破 SL，信号死亡

            // B. 检查止盈 (完成) -> 斐波 4.236
            double tp_final = sl_price + range * 4.236;
            if (High[k] >= tp_final) return false; // 价格到达终点，信号使命结束
        }
        else // 做空
        {
            // A. 检查止损
            if (High[k] >= sl_price) return false; // 价格涨破 SL

            // B. 检查止盈
            double tp_final = sl_price - range * 4.236;
            if (Low[k] <= tp_final) return false;
        }
    }

    // 如果没死也没毕业，那就是“依然在战斗中” (Active)
    return true;
}
*/

//+------------------------------------------------------------------+
//| CheckSignalStatus (最终版)
//|
//| 功能: 检查历史信号是否依然有效 (Active)
//| 核心逻辑: 
//|   1. 止损标准 (IB失效): 价格实体收盘价 击穿 P1 (锚点开盘价) 即死。
//|   2. 止盈标准 (完结): 价格触及 4.236 扩展位 即完成使命。
//|
//| 参数:
//|   signal_index : 信号确认K线的索引 (P2突破或DB突破的那根K线)
//|   sl_price     : 必须传入 P1 (锚点开盘价) 作为止损基准
//|   is_bullish   : 多空方向
//+------------------------------------------------------------------+
bool CheckSignalStatus(int signal_index, double sl_price, bool is_bullish)
{
    // ---------------------------------------------------
    // 1. 基础可见性过滤
    // ---------------------------------------------------
    
    // 规则 A: 永远保留最新的正在进行的信号 (索引 0 或 1)
    // 这样保证实盘时信号不会突然闪烁消失
    if (signal_index <= 1) return true;

    // 规则 B: 如果用户彻底关闭历史显示，则所有旧信号都不画
    if (!Show_History_Fibo) return false;

    // 规则 C: 如果用户想看历史，且允许看失效的信号(复盘用)，则全部保留
    // Hide_Invalid_Fibo = true (默认) -> 隐藏死掉的，只留活的
    // Hide_Invalid_Fibo = false      -> 显示所有历史尸体
    if (!Hide_Invalid_Fibo) return true;


    // ---------------------------------------------------
    // 2. 智能生存状态检查 (从信号产生那一刻一直查到现在)
    // ---------------------------------------------------
    
    // 计算逻辑上的 "IB 区间动能幅度" (用于测算 TP)
    // 注意：这里使用信号K线的收盘价 vs P1 来计算幅度，与斐波那契绘制保持一致
    double entry_price = Close[signal_index]; 
    double range = MathAbs(entry_price - sl_price);

    // 遍历：从信号后一根K线 (signal_index - 1) 开始，一直查到当前K线 (0)
    for (int k = signal_index - 1; k >= 0; k--)
    {
        if (is_bullish) // [做多信号检查]
        {
            // A. 检查止损 (IB失效标准)
            // 逻辑：如果 K 线实体收盘价跌破 P1 (sl_price)，视为结构崩塌
            if (Close[k] < sl_price) 
            {
                return false; // 信号已死 (Invalid)
            }
            
            // (可选：如果您想要更严格的"引线触碰即死"，请解开下面这行)
            // if (Low[k] <= sl_price) return false;

            // B. 检查止盈 (完美毕业)
            // 逻辑：如果最高价触及 4.236 目标位
            double tp_final = sl_price + (range * 4.236);
            if (High[k] >= tp_final) 
            {
                return false; // 信号已完成使命 (Completed)
            }
        }
        else // [做空信号检查]
        {
            // A. 检查止损 (IB失效标准)
            // 逻辑：如果 K 线实体收盘价涨破 P1 (sl_price)
            if (Close[k] > sl_price) 
            {
                return false; // 信号已死 (Invalid)
            }

            // B. 检查止盈
            double tp_final = sl_price - (range * 4.236);
            if (Low[k] <= tp_final) 
            {
                return false; // 信号已完成使命 (Completed)
            }
        }
    }

    // 经历了九九八十一难（所有K线检查）都没死也没毕业，
    // 说明这个信号依然 "Active" (活着且未达终点)。
    return true;
}

// ==========================================================================
// 2. 核心计算引擎 (Calculation Engine)
// ==========================================================================

// 计算空间因子 (ATR Helper)
double Calculate_Space_Factor(string sym, int period, double p1, double p2, int shift) {
   double atr = iATR(sym, period, 14, shift);
   if(atr <= 0) return 0;
   return MathAbs(p2 - p1) / atr;
}

/*
// 综合评分系统 (The Brain)
SignalQuality EvaluateSignal_Bug(
   string sym, int period, 
   int anchor_idx, int breakout_idx, 
   double p1, double p2, double sl, 
   bool is_bullish
) {
   SignalQuality sq;
   sq.grade = GRADE_NONE;
   
   // --- A. 基础计算 ---
   double atr = iATR(sym, period, 14, breakout_idx);
   if(atr==0) atr = Point;
   
   double close_price = iClose(sym, period, breakout_idx);
   int n_geo = MathAbs(anchor_idx - breakout_idx);
   
   sq.is_IB = (n_geo <= 2);
   sq.is_DB = (n_geo > 2);
   
   // --- B. 结构与CB判定 ---
   if (is_bullish) {
      if (p2 < p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2<P1)"; return sq; }
      sq.is_CB = (close_price > p2);
   } else {
      if (p2 > p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2>P1)"; return sq; }
      sq.is_CB = (close_price < p2);
   }

   // --- C. 空间与盈亏比 ---
   sq.space_factor = Calculate_Space_Factor(sym, period, p1, p2, breakout_idx);
   double risk = MathAbs(p1 - sl);
   double reward = MathAbs(p2 - p1);
   sq.rr_ratio = (risk > 0) ? (reward / risk) : 0;
   
   // --- D. 斐波那契目标计算 (针对 Grade A/S) ---
   double range = MathAbs(close_price - sl);
   if (is_bullish) sq.target_fib_1618 = sl + range * 1.618;
   else            sq.target_fib_1618 = sl - range * 1.618;

   // --- E. 最终定级逻辑 ---
   if (sq.is_CB) {
      // 突破了P2，且空间不是极其微小
      if (sq.is_DB) { sq.grade = GRADE_S; sq.description = "S级:主导突破(DB+CB)"; }
      else          { sq.grade = GRADE_A; sq.description = "A级:爆发突破(IB+CB)"; }
   } 
   else {
      // 没过P2，看空间
      if (sq.space_factor > 1.5) {
         if (sq.is_DB) { sq.grade = GRADE_B; sq.description = "B级:区间主导(DB)"; }
         else          { sq.grade = GRADE_C; sq.description = "C级:区间激进(IB)"; }
      } else {
         sq.grade = GRADE_D; sq.description = "D级:空间不足";
      }
   }
   
   return sq;
}
*/

// 综合评分系统 (The Brain)
SignalQuality EvaluateSignal(
   string sym, int period, 
   int n_geo_input, int breakout_idx, 
   double p1, double p2, double sl, 
   bool is_bullish
) {
   SignalQuality sq;
   sq.grade = GRADE_NONE;
   
   // --- A. 基础计算 ---
   double atr = iATR(sym, period, 14, breakout_idx);
   if(atr==0) atr = Point;
   
   double close_price = iClose(sym, period, breakout_idx);
   int n_geo = n_geo_input;

   // ✅ 修复：使用全局参数 DB_Threshold_Candles 进行动态判断
   // 只有跨度达到或超过阈值 (例如 >= 3) 才算是 DB
   sq.is_DB = (n_geo >= DB_Threshold_Candles);

   // 否则就是 IB (快速爆发)
   sq.is_IB = (n_geo < DB_Threshold_Candles);
   
   // --- B. 结构与CB判定 ---
   if (is_bullish) {
      if (p2 < p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2<P1)"; return sq; }
      sq.is_CB = (close_price > p2);
   } else {
      if (p2 > p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2>P1)"; return sq; }
      sq.is_CB = (close_price < p2);
   }

   // --- C. 空间与盈亏比 ---
   sq.space_factor = Calculate_Space_Factor(sym, period, p1, p2, breakout_idx);
   double risk = MathAbs(p1 - sl);
   double reward = MathAbs(p2 - p1);
   sq.rr_ratio = (risk > 0) ? (reward / risk) : 0;
   
   // --- D. 斐波那契目标计算 (针对 Grade A/S) ---
   double range = MathAbs(close_price - sl);
   if (is_bullish) sq.target_fib_1618 = sl + range * 1.618;
   else            sq.target_fib_1618 = sl - range * 1.618;

   /*
   // --- E. 最终定级逻辑 ---
   if (sq.is_CB) {
      // 突破了P2，且空间不是极其微小
      if (sq.is_DB) { sq.grade = GRADE_S; sq.description = "S级:主导突破(DB+CB)"; }
      else          { sq.grade = GRADE_A; sq.description = "A级:爆发突破(IB+CB)"; }
   } 
   else {
      // 没过P2，看空间
      if (sq.space_factor > 1.5) {
         if (sq.is_DB) { sq.grade = GRADE_B; sq.description = "B级:区间主导(DB)"; }
         else          { sq.grade = GRADE_C; sq.description = "C级:区间激进(IB)"; }
      } else {
         sq.grade = GRADE_D; sq.description = "D级:空间不足";
      }
   }
   */

   // =================================================================
   // --- E. 最终定级逻辑 (Refactored Logic) ---
   // 核心思想：结构决定潜力，动作决定触发
   // =================================================================
   
   // 🟢 分支一：如果是 DB 结构 (深幅酝酿)
   if (sq.is_DB) 
   {
       // 既然结构已经满足 DB，我们看它发生了什么动作
       if (sq.is_CB) 
       {
           // 动作：强势突破 P2
           // 结论：结构深 + 动能足 = 完美 S 级
           sq.grade = GRADE_S; 
           sq.description = "S级:主导突破(DB+CB)"; 
       }
       else 
       {
           // 动作：未突破 P2 (但结构是 DB)
           // 检查：空间够不够挂单？
           if (sq.space_factor > 1.5) 
           {
               sq.grade = GRADE_B; 
               sq.description = "B级:区间主导(DB)"; 
           }
           else 
           {
               sq.grade = GRADE_D; 
               sq.description = "D级:空间不足"; 
           }
       }
   }
   // 🔵 分支二：如果是 IB 结构 (快速爆发)
   else // is_IB
   {
       // 结构较短，看看动作
       if (sq.is_CB) 
       {
           // 动作：强势突破 P2
           // 结论：虽然时间短，但动能极强 = 优秀 A 级
           sq.grade = GRADE_A; 
           sq.description = "A级:爆发突破(IB+CB)"; 
       }
       else 
       {
           // 动作：未突破 P2 且结构短
           // 结论：通常视为噪音，给 C 级 (或 D)
           if (sq.space_factor > 1.5) 
           {
               sq.grade = GRADE_C; 
               sq.description = "C级:区间激进(IB)"; 
           }
           else 
           {
               sq.grade = GRADE_D; 
               sq.description = "D级:空间不足"; 
           }
       }
   }
   return sq;
}

// ==========================================================================
// 3. 可视化与提醒 (Visuals & Alerts)
// ==========================================================================

// 发送富文本提醒
void SendRichAlert(string sym, int period, string type, double price, double sl, SignalQuality &sq) {
   if (Is_EA_Mode)
   {
      return;
   }
   
   if (sq.grade <= GRADE_D) return; // 过滤低质量
   
   string per_str = GetTimeframeName(period);

   // 把 M%d 修改为 %s
   string msg = StringFormat(
      "%s %s [%s] | %s\n现价: %.5f | SL: %.5f\n因子: %.1f | R:R: %.1f\n",
      sym, per_str, type, sq.description, price, sl, sq.space_factor, sq.rr_ratio
   );
   
   if(sq.grade >= GRADE_A) msg += StringFormat(">> 目标: %.5f (Fib 1.618)", sq.target_fib_1618);
   
   Alert(msg);
   SendNotification(msg);
}

// 将枚举等级转换为协议小数
double GetGradeWeight(ENUM_SIGNAL_GRADE grade)
{
   switch(grade)
   {
      case GRADE_S: return 0.5;
      case GRADE_A: return 0.4;
      case GRADE_B: return 0.3;
      case GRADE_C: return 0.2;
      case GRADE_D: return 0.1;
      default:      return 0.0;
   }
}

//+------------------------------------------------------------------+
//| 🛡️ 参数同步模块：将当前参数保存到隐藏对象，供脚本读取
//+------------------------------------------------------------------+
void SaveParamsToChart()
{
   if(Is_EA_Mode) return; // EA后台模式不需要保存

   string obj_name = "KTarget_Param_Store"; // 固定名称
   
   // 1. 如果对象不存在，创建它 (使用 OBJ_LABEL 作为数据容器)
   if(ObjectFind(0, obj_name) == -1) {
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
      // ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true); // 隐藏，不干扰视线
      // ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, -100); // 移出屏幕外
      // ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }

   // --- 核心修改：调整位置属性 (顶部居中) ---

   // 2. 设置锚点为顶部中心 (关键：这会让文字以 X 坐标为中心向两边分布)
   ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_TOP);

   // 3. 设置角部为左上角 (作为坐标计算的基准)
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);

   // 4. 动态计算 X 坐标：获取图表当前像素宽度，除以 2 得到中心点
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, chart_width / 2);

   // 5. 设置 Y 坐标：距离图表最顶部 20 像素，避免紧贴边缘
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, 10);

   // 6. 取消隐藏 (原代码设置为 true 且移出屏幕，现在改为可见)
   ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);

   // 2. 拼接核心参数 (顺序必须与 Config_Core.mqh 一致!)
   // 格式: Smart_Tuning|Scan_Range|La_B|Lb_B|La_T|Lb_T|Max_Look|DB_Thres|LLHH|Model
   string param_str = 
      (string)Smart_Tuning_Enabled + "|" +
      (string)Scan_Range + "|" +
      (string)Lookahead_Bottom + "|" +
      (string)Lookback_Bottom + "|" +
      (string)Lookahead_Top + "|" +
      (string)Lookback_Top + "|" +
      (string)Max_Signal_Lookforward + "|" +
      (string)DB_Threshold_Candles + "|" +
      (string)Look_LLHH_Candles + "|" +
      (string)Find_Target_Model;

   // 3. 写入对象描述
   ObjectSetString(0, obj_name, OBJPROP_TEXT, param_str);
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);

   // 打印日志方便确认
   Print("---->参数已同步至图表: ", param_str);
}

void Init_Smart_Tuning()
{
    //+------------------------------------------------------------------+
    // 🚨 检查是否启用智能调优 🚨
    if (Smart_Tuning_Enabled)
    {
        // 1. 获取周期调优后的参数集
        TuningParameters tuned_params = GetTunedParameters();

        // 2. 将全局外部变量的值覆盖为调优后的值
        // 这样，主逻辑中所有对这些变量的引用都将自动使用新值。
        Scan_Range = tuned_params.Scan_Range;
        Lookahead_Bottom = tuned_params.Lookahead_Bottom;
        Lookback_Bottom = tuned_params.Lookback_Bottom;
        Lookahead_Top = tuned_params.Lookahead_Top;
        Lookback_Top = tuned_params.Lookback_Top;
        Max_Signal_Lookforward = tuned_params.Max_Signal_Lookforward;
        Look_LLHH_Candles = tuned_params.Look_LLHH_Candles;

        // 可选：打印日志确认
        // Print("INFO: Smart Tuning Enabled. Parameters adjusted for Period ", GetTimeframeName(_Period));
    }
    //+------------------------------------------------------------------+
}

void Init_Object_prefix()
{
    // long cid = ChartID();
    // Print("-->[KTarget_Finder5.mq4:152]: cid: ", cid);

    // 1. 获取 ChartID 的绝对值 (long 类型)
    long full_chart_id = MathAbs(ChartID());
    // Print("-->[KTarget_Finder5.mq4:156]: full_chart_id: ", full_chart_id);

    // 2. 强制截断 ChartID 到 32 位 int。
    // 仅保留 ID 的低位部分，使其长度大幅缩短，但仍具有高度唯一性。
    // int short_chart_id = (int)full_chart_id;
    int short_chart_id = (int)(full_chart_id % 1000000);
    // Print("-->[KTarget_Finder5.mq4:161]: short_chart_id: ", MathAbs(short_chart_id));

    // [V1.32 NEW] 生成唯一的对象名前缀
    g_object_prefix = ShortenObjectName(WindowExpertName()) + StringFormat("_%d_", MathAbs(short_chart_id));
    // Print("-->[KTarget_Finder5.mq4:165]: g_object_prefix: ", g_object_prefix);
}

void Init_Buffer()
{
    //+------------------------------------------------------------------+
    // 缓冲区映射设置 (无变化)
    SetIndexBuffer(0, BullishTargetBuffer);
    SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 1, clrBlue);
    SetIndexArrow(0, ARROW_CODE_UP);

    SetIndexBuffer(1, BearishTargetBuffer);
    SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 1, clrRed);
    SetIndexArrow(1, ARROW_CODE_DOWN);

    SetIndexBuffer(2, BullishSignalBuffer);
    SetIndexStyle(2, DRAW_ARROW, STYLE_SOLID, 1, clrLimeGreen);
    SetIndexArrow(2, ARROW_CODE_SIGNAL_UP);

    SetIndexBuffer(3, BearishSignalBuffer);
    SetIndexStyle(3, DRAW_ARROW, STYLE_SOLID, 1, clrDarkViolet);
    SetIndexArrow(3, ARROW_CODE_SIGNAL_DOWN);

    // 初始化所有缓冲区数据为 0.0
    ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);
}

void DeInit_DelObject()
{
    // ------------------- 1.0 清理对象的迭代代码 -------------------
    // 清理所有以 "IBDB_Line_" 为前缀的趋势线对象 (P1基准线)
    // ObjectsDeleteAll(0, "IBDB_Line_");
    // [V1.22 NEW] 清理所有以 "IBDB_P2_Line_" 为前缀的趋势线对象 (P2基准线)
    // ObjectsDeleteAll(0, "IBDB_P2_Line_");

    if (!Is_EA_Mode)
    {
        /* 1.0
        // 使用唯一的 g_object_prefix 进行清理
        for (int i = ObjectsTotal() - 1; i >= 0; i--)
        {
            string object_name = ObjectName(i);
            // 检查对象名称是否包含我们独有的前缀
            if (StringFind(object_name, g_object_prefix) != -1)
            {
                ObjectDelete(0, object_name);
            }
        }
        */

        // 2.0 遍历图表上的所有对象，从后向前扫描
        for (int i = ObjectsTotal() - 1; i >= 0; i--)
        {
            string obj_name = ObjectName(i);

            // 1. 第一层筛选：必须是本指标创建的对象 (匹配前缀)
            if (StringFind(obj_name, g_object_prefix) != -1)
            {
                // 2. 第二层筛选：检查是否为【斐波那契相关对象】(白名单)
                // 根据名称特征：包含 "_Fibo_" 或 "_FiboHL_" 的都属于斐波组件
                bool is_fibo_line = (StringFind(obj_name, "_Fibo_") != -1);
                bool is_fibo_zone = (StringFind(obj_name, "_FiboHL_") != -1);

                // 3. 核心保护逻辑：如果是斐波对象，【跳过删除】，直接进入下一次循环
                if (is_fibo_line || is_fibo_zone)
                {
                    continue; // 🚨 关键语句：保留对象，不执行下面的删除
                }

                // 4. 只有非斐波对象 (如信号箭头、临时连线等) 才会被删除
                ObjectDelete(0, obj_name);
            }
        }

        // ------------------- 0.0 下面的代码保持不变 -------------------
        ChartRedraw();
        Print("---->[KTarget_Finder_MT7.mq4:1067]: OnDeinit 指标卸载 ");
    }
}

void HandleObjectClick(string sparam)
{
    // sparam 包含了被点击对象的名称。
    string object_name = sparam;
    ParsedRectInfo info;

    // 这是您的目标：用户点击了图表对象
    // Print("    *** 侦测到对象点击事件 (CHARTEVENT_OBJECT_CLICK) ***");
    // Print("    被点击对象名称 (sparam): ", sparam);

    // 检查是否点击了我们创建的趋势线
    // if (sparam == g_trendline_name)
    // {
    //     Print("    >>> 成功点击了我们的可交互趋势线！ <<<");
    //     // 此时您可以执行 DrawP1P2Fibonacci() 等自定义操作
    // }

    // --- 3. 模拟双击检查 ---
    /* 这种方式没有通过
    datetime current_time = TimeCurrent();
    Print("-->[KTarget_Finder5.mq4:308]: current_time: ", current_time);

    Print("-->[KTarget_Finder5.mq4:313]: LastClickTime: ", LastClickTime);

    long time_diff_ms = (current_time - LastClickTime) * 1000; // 转换为毫秒
    Print("-->[KTarget_Finder5.mq4:311]: time_diff_ms: ", time_diff_ms);
    */

    // --- 2. 检查是否点击了我们的矩形对象 ---
    // 矩形对象的名称应该以我们定义的 "Rect_B_" 或 "Rect_S_" 开头
    if (StringFind(object_name, "Rect_B_", 0) != -1 || StringFind(object_name, "Rect_S_", 0) != -1)
    {
        // 1. 获取当前系统启动以来的毫秒数
        ulong current_time_ms = GetTickCount();
        // Print("===>[KTarget_Finder5.mq4:320]: current_time_ms: ", current_time_ms);
        // Print("===>[KTarget_Finder5.mq4:321]: LastClickTime_ms: ", LastClickTime_ms);

        // 2. 计算毫秒差（直接相减就是毫秒数）
        // 注意：GetTickCount() 返回值可能循环，但对于 500ms 的短期差值是可靠的。
        ulong time_diff_ms = current_time_ms - LastClickTime_ms;
        // Print("===>[KTarget_Finder5.mq4:326]: time_diff_ms: ", time_diff_ms);

        if (time_diff_ms > 0 && time_diff_ms < DOUBLE_CLICK_TIMEOUT_MS)
        {
            Print(">>> DEBUG: Detected Double Click on Rectangle: ", sparam);

            // 1. 检查是否点击了我们的矩形，并解析名称
            if (ParseRectangleName(object_name, info))
            {
                // 2. 🚨 核心步骤：将绝对时间转换为当前 K 线索引 🚨

                // iBarShift 查找给定时间对应的 K 线索引。
                // false 参数表示精确匹配 K 线开盘时间。
                int current_P1_index = iBarShift(NULL, 0, info.P1_time, false);
                int current_P2_index = iBarShift(NULL, 0, info.P2_time, false);

                // 检查索引是否有效 (通常 >= 0)
                if (current_P1_index >= 0 && current_P2_index >= 0)
                {
                    Print("成功解析并转换时间到索引：P1索引=", current_P1_index, ", P2索引=", current_P2_index);

                    // 3. 调用 DrawP1P2Fibonacci 函数绘制斐波那契线
                    DrawP1P2Fibonacci(current_P1_index, current_P2_index, info.is_bullish);

                    // 绘制斐波高亮的反转区域
                    DrawFiboHighlightRectangles(current_P1_index, current_P2_index, info.is_bullish);

                    // 确保 Fibo 立即显示
                    // ChartRedraw(0);
                }
                else
                {
                    Print("错误: 无法找到匹配的 K 线索引，数据可能已过期或被移除。");
                }
            }

            // 强制重绘，以确保 Fibo 立即显示
            // ChartRedraw(0);

            // 重置 LastClickTime，避免三次点击被识别为双击 -- 第一次编写的时候 使用 LastClickTime 没有成功 所以注销了
            // LastClickTime = 0;

            LastClickTime_ms = 0;
        }
        else
        {
            // 记录第一次点击时间
            // LastClickTime = current_time;

            // 记录第一次点击时间 (必须大于 0，避免系统启动时记录 0)
            LastClickTime_ms = current_time_ms;
        }
    }
}

void HandleObjectDelete(string sparam)
{
    string deleted_name = sparam;
    // Print("--->[KTarget_Finder5.mq4:595]: deleted_name: ", deleted_name);

    // 1. 过滤：检查被删除的对象是否为我们指标绘制的 '主' 斐波那契线
    // 条件：a) 必须包含指标前缀 g_object_prefix
    //       b) 必须包含 "_Fibo_" (斐波那契主线的标记)
    //       c) 必须不包含 "_FiboHL_" (排除高亮矩形本身)
    if (StringFind(deleted_name, g_object_prefix) != -1 &&
        StringFind(deleted_name, "_Fibo_") != -1 &&
        StringFind(deleted_name, "_FiboHL_") == -1)
    {
        // 2. 提取唯一的锚点 ID 部分: [B/S]_[LongTimeID]

        // 查找 "_Fibo_" 在名称中的起始位置
        int start_pos = StringFind(deleted_name, "_Fibo_");

        if (start_pos != -1)
        {
            // 查找 "_Fibo_" 后面的下划线的位置，即 Fibo_ 后面的下划线
            int id_start = StringFind(deleted_name, "_", start_pos + 5);

            if (id_start != -1)
            {
                // 提取唯一的锚点 ID，例如 "B_2025_11_20_04_00_00"
                // 从下划线后一位开始截取到字符串末尾
                string unique_anchor_id = StringSubstr(deleted_name, id_start + 1);
                // Print("--->[KTarget_Finder5.mq4:627]: unique_anchor_id: ", unique_anchor_id);

                // 3. 遍历图表对象并删除所有包含此 ID 的关联子对象
                int total_objects = ObjectsTotal(0, 0);
                string obj_name;

                for (int i = total_objects - 1; i >= 0; i--)
                {
                    obj_name = ObjectName(0, i);
                    // Print("--->[KTarget_Finder5.mq4:636]: obj_name: ", obj_name);

                    // 检查条件：
                    // a) 必须是 FiboHL 相关的对象 (Rect_FiboHL_...)
                    // b) 必须包含被删除主线对象的唯一锚点 ID (unique_anchor_id)

                    if (StringFind(obj_name, "_FiboHL_") != -1 &&
                        StringFind(obj_name, unique_anchor_id) != -1)
                    {
                        // Print("--->[KTarget_Finder5.mq4:646]: obj_name: ", obj_name);
                        // 找到了关联的矩形或文本 (因为文本名称是矩形名称 + _TXT)
                        ObjectDelete(0, obj_name);
                    }
                }

                Print("INFO: Fibo主线手动删除，自动清理相关对象: ", deleted_name);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 根据图表周期获取自适应 ATR 计算周期
//+------------------------------------------------------------------+
int GetAdaptiveATRPeriod(int period)
{
   switch(period)
   {
      case PERIOD_M1:  return 24; // M1 噪音大，使用更长周期平滑
      case PERIOD_M5:  return 20;
      case PERIOD_M15: return 14; // 标准周期
      case PERIOD_M30: return 14;
      case PERIOD_H1:  return 14;
      case PERIOD_H4:  return 20; // H4 波动较大，稍微平滑
      case PERIOD_D1:  return 20;
      case PERIOD_W1:  return 10; // 周线反应需灵敏
      default:         return 14;
   }
}

//+------------------------------------------------------------------+
//| 根据图表周期获取自适应 ATR 止损倍数 (Multiplier)
//+------------------------------------------------------------------+
double GetAdaptiveATRMultiplier(int period)
{
   switch(period)
   {
      case PERIOD_M1:  return 3.0; // M1 噪音极大，且点差影响大，给予宽倍数
      case PERIOD_M5:  return 2.5; // M5 仍属于高噪区
      case PERIOD_M15: return 2.0; // 短线标准
      case PERIOD_M30: return 1.8;
      case PERIOD_H1:  return 1.5; // H1 是非常标准的趋势周期，1.5倍较常用
      case PERIOD_H4:  return 1.2; // H4 波动值大，缩小倍数以优化盈亏比
      case PERIOD_D1:  return 1.0; // 日线一倍ATR通常已足够涵盖噪音
      case PERIOD_W1:  return 1.0;
      default:         return 1.5;
   }
}