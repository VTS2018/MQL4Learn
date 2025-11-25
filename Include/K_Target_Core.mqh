//+------------------------------------------------------------------+
//| K-Target Core Logic and O(1) Optimization                        |
//| 文件名: K_Target_Core.mqh                                        |
//| 包含 Check/Find/PreCalculate 等所有计算逻辑                      |
//+------------------------------------------------------------------+
#include <K_Target_Object.mqh> // 引入信号对象结构
#property strict

// --- 全局预计算数组 (V1.33: O(1) 查找依赖) ---
// 注意: 它们必须是全局 double 类型数组，才能被 SetIndexBuffer 绑定（虽然这里不绑定，但习惯用 double）
double MinClose_Past_Buffer[];      // O(1) 查找 Lookback 最低收盘价
double MinClose_Future_Buffer[];    // O(1) 查找 Lookahead 最低收盘价
double TrueLowAnchorIndex_Buffer[]; // O(1) 查找 Lookback+Lookahead 范围内最低价的 K 线索引

// --- OnCalculate 模式控制全局变量 ---
static int last_bars = 0; // 用于判断是否是新 K 线收盘

// --- 外部参数原型 (需要从主文件导入) ---
extern int Scan_Range; // 注意：FindSecondBaseline 中使用了 Scan_Range
extern int Lookahead_Bottom; 
extern int Lookback_Bottom;
extern int Lookahead_Top;
extern int Lookback_Top;
extern int Max_Signal_Lookforward;
extern int DB_Threshold_Candles;


//========================================================================
// O(N*W) 黑箱: PreCalculate_KTarget_Levels (只在新 K 线时运行)
//========================================================================
// [V1.33 NEW] 预计算 Lookback/Lookahead 范围内的所有指标答案
void PreCalculate_KTarget_Levels(int rates_total)
{
    // --- 0. 数组大小设置 ---
    ArrayResize(MinClose_Past_Buffer, rates_total);
    ArrayResize(MinClose_Future_Buffer, rates_total);
    ArrayResize(TrueLowAnchorIndex_Buffer, rates_total);
    
    // ----------------------------------------
    // 1. MinClose_Past_Buffer 预计算 (Lookback Lowest Close)
    // ----------------------------------------
    // O(N*W) 算法: 对每根 K 线 i，向前看 Lookback_Bottom 根 K 线的最低收盘价
    for (int i = 0; i < rates_total; i++)
    {
        double min_price = DBL_MAX;
        // 查找历史 (i+k)
        for (int k = 1; k <= Lookback_Bottom; k++)
        {
            int past_index = i + k;
            if (past_index >= rates_total) break;
            
            if (Close[past_index] < min_price) min_price = Close[past_index];
        }
        MinClose_Past_Buffer[i] = min_price;
    }
    
    // ----------------------------------------
    // 2. MinClose_Future_Buffer 预计算 (Lookahead Lowest Close)
    // ----------------------------------------
    // O(N*W) 算法: 对每根 K 线 i，向后看 Lookahead_Bottom 根 K 线的最低收盘价
    for (int i = 0; i < rates_total; i++)
    {
        double min_price = DBL_MAX;
        // 查找未来 (i-k)
        for (int k = 1; k <= Lookahead_Bottom; k++)
        {
            int future_index = i - k;
            if (future_index < 0) break;
            
            // 注意: K[0] 的价格必须是实时的，即 Close[0]
            if (Close[future_index] < min_price) min_price = Close[future_index];
        }
        MinClose_Future_Buffer[i] = min_price;
    }
    
    // ----------------------------------------
    // 3. TrueLowAnchorIndex_Buffer 预计算 (绝对最低价 K 线索引)
    // ----------------------------------------
    // O(N*W) 算法: 对每根 K 线 i，在总窗口内找到绝对最低价 Low 的索引
    int total_scan_window = Lookback_Bottom + Lookahead_Bottom + 1;
    
    for (int i = 0; i < rates_total; i++) 
    {
        int start_index = i - Lookahead_Bottom; // 从未来 Lookahead 处开始
        if (start_index < 0) start_index = 0;
        
        int count_to_scan = Lookahead_Bottom + Lookback_Bottom + 1; // 扫描 K 线总数
        
        // MQL4 内建 iLowest 函数: 
        // 查找总窗口内的绝对最低价 Low 的 K 线索引 (O(W) 内部优化)
        int true_low_index = iLowest(NULL, PERIOD_CURRENT, MODE_LOW, count_to_scan, start_index);
        
        // 存储结果
        TrueLowAnchorIndex_Buffer[i] = true_low_index;
    }
}


//========================================================================
// O(1) 检查: CheckKTargetBottomCondition_O1 (取代 5.txt 中的 CheckKTargetBottomCondition)
//========================================================================
bool CheckKTargetBottomCondition_O1(int i, int total_bars)
{
    // 1. 必须是阴线 (Bearish Candle)
    if (Close[i] >= Open[i]) return false;

    // 2. O(1) Lookback 检查 (最低收盘价检查)
    // K[i] 的收盘价必须低于过去的最低收盘价
    if (Close[i] > MinClose_Past_Buffer[i])
    {
        return false;
    }

    // 3. O(1) Lookahead 检查 (最低收盘价检查)
    // K[i] 的收盘价必须低于未来的最低收盘价 (包含 K[0])
    if (Close[i] > MinClose_Future_Buffer[i])
    {
        return false;
    }
    
    return true;
}

// ... (此处省略 CheckKTargetTopCondition_O1，逻辑类似，只需使用 Lookahead_Top/Lookback_Top 和最高收盘价数组) ...


//========================================================================
// FindSecondBaseline: 查找 P2 价格 (从 5.txt 抽取，保持 O(W) 循环)
//========================================================================
// 此处保留 O(W) 循环是合理的，因为 P2 价格是信号的关键约束，不能预计算。
double FindSecondBaseline(int target_index, bool is_bullish, double P1_price)
{
    // P2 价格 (初始为 0.0)
    double P2_price = 0.0;
    
    // 从锚点 K 线的左侧 (历史 K 线，索引 target_index + k) 开始回溯
    for (int k = 1; k <= Scan_Range; k++) // Scan_Range 作为回溯上限
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
                    condition_met = true;
                }
            }
        }

        if (condition_met) 
        {
            break; // 找到即退出
        }
    }
    
    return P2_price;
}


//========================================================================
// KTarget_ProcessSignal: OOP 封装和突破确认 (取代 FindAndDrawTargetCandles 内部逻辑)
//========================================================================
bool KTarget_ProcessSignal(int anchor_index, KTarget_Signal& signal_obj, int total_bars, double DB_Threshold_Candles)
{
    // 0. 初始化信号对象的基本信息
    signal_obj.anchor_index = anchor_index;
    signal_obj.anchor_time = Time[anchor_index];
    signal_obj.is_bullish = true;
    signal_obj.is_confirmed = false; // 初始为未确认
    
    // 1. 使用 O(1) 检查函数，判断是否为锚点
    if (CheckKTargetBottomCondition_O1(anchor_index, total_bars) == false) 
    {
        return false; 
    }
    
    // 2. 锚点已找到，填充基础价格和 True Anchor Index
    signal_obj.P1_price = Open[anchor_index]; // P1 价格
    
    // [V1.33 O(1) 查找] 从数组中 O(1) 获取 True Low Anchor Index
    // (注意: 这是一个基于 Lowest Low 的索引，与 P2 的查找起点不同，但可以用于矩形绘制等)
    signal_obj.true_anchor_index = (int)TrueLowAnchorIndex_Buffer[anchor_index];
    
    // 3. 查找 P2 价格 (FindSecondBaseline)
    signal_obj.P2_price = FindSecondBaseline(anchor_index, signal_obj.is_bullish, signal_obj.P1_price);
    
    // 4. 突破确认 (取代 CheckBullishSignalConfirmation 的核心循环)
    double target_open_price = signal_obj.P1_price;
    // 从 K-Target 的下一根 K 线 (anchor_index - 1) 开始向前检查
    for (int j = anchor_index - 1; j >= anchor_index - Max_Signal_Lookforward; j--)
    {
        if (j < 0) break;
        
        // 突破确认条件: 突破 K 线的收盘价 > P1
        if (Close[j] > target_open_price)
        {
            signal_obj.is_confirmed = true;
            signal_obj.breakout_index = j;
            signal_obj.breakout_candle_count = anchor_index - j;
            
            // 突破类型分类
            signal_obj.classification = (signal_obj.breakout_candle_count < DB_Threshold_Candles) ? "IB" : "DB";
            
            return true; // 信号成立并退出
        }
    }
    
    return false; // 锚点成立，但突破未确认
}