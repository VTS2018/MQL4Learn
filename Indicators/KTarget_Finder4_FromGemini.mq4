//+------------------------------------------------------------------+
//|                          K-Target 突破信号识别指标 (XBreaking Signal) |
//+------------------------------------------------------------------+
/*
   功能描述:
   本指标基于价格行为分析中的 K-Target (目标 K 线) 和 IB/DB (内部突破/外部突破) 概念设计。
   它旨在自动识别图表上的关键水平，并在价格首次有效突破这些水平时发出信号，并绘制辅助趋势线。

   核心逻辑:
   1. K-Target 锚点识别: 
      - 识别出一段时间周期内 (由 Lookback/Lookahead 参数控制) 具有最低收盘价的阴线 (看涨锚点)，或最高收盘价的阳线 (看跌锚点)。
      - 这些锚点通常代表市场反转的起点或关键支撑/阻力位。
   2. 突破确认 (IB/DB): 
      - **第一基准价格线 (P1):** K-Target 锚点的开盘价。
      - **第二基准价格线 (P2):** 锚点左侧第一根反转 K 线的收盘价。
      - 突破发生在 P1 之上，并且根据 K 线数量 (N) 分类为 IB (N<=2) 或 DB (N>=3)。
   3. 信号绘制: 
      - 在突破发生的 K 线上方/下方绘制最终信号箭头。
      - 绘制两条水平趋势线：一条是 P1 (实线)，一条是 P2 (虚线)。

   趋势线属性:
   - 始点: K-Target 锚点 K 线的 Open 价格和时间。
   - 终点: 突破 K 线的时间 + 2 根 K 线 (保证长度适中，非射线)。
*/
//+------------------------------------------------------------------+
//|                          版本迭代日志 (Changelog)                  |
//+------------------------------------------------------------------+
/*
   日期           | 版本    | 描述
   ------------------------------------------------------------------
   2025.10.28     | v1.17   | 初始版本。集成 K-Target 锚点识别 (Bottom/Top) 和 IB/DB 突破确认逻辑。
   2025.11.05     | v1.18   | 修复 `OnDeinit` 函数签名，以消除 MQL4 编译器警告。添加图表对象清理机制。
   2025.11.12     | v1.19   | 优化趋势线终点设置逻辑。终点从突破 K 线时间开始，向右延伸 2 根 K 线，避免线条过长。
   2025.11.18     | v1.20   | 明确设置趋势线为非射线 (`OBJPROP_RAY = false`)，确保其为固定长度的线段。
   2025.11.18     | v1.21   | 修正了 `#property` 绘图属性中的重复设置：将 Plot 2 的 `indicator_width1` 修正为 `indicator_width2`。
   2025.11.18     | v1.22   | **[当前版本]** 增加 IB/DB 突破分类和第二基准价格线 (P2) 查找逻辑，并在图表上绘制 P2 辅助线。
   ------------------------------------------------------------------
*/
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MQL Developer"
#property link      "https://www.mql5.com"
#property version   "1.23" 
#property strict
#property indicator_chart_window // 绘制在主图表窗口
#property indicator_buffers 4 // 两个锚点 + 两个最终信号
#property indicator_plots   4 // 对应四个绘图

// --- 外部可调参数 (输入) ---
extern int Scan_Range = 100;              // 总扫描范围：向后查找 N 根 K 线

// --- 看涨 K-Target (底部) 锚点参数 ---
extern int Lookahead_Bottom = 20;         // 看涨信号右侧检查周期 (未来/较新的K线)
extern int Lookback_Bottom = 20;          // 看涨信号左侧检查周期 (历史/较旧的K线)

// --- 看跌 K-Target (顶部) 锚点参数 ---
extern int Lookahead_Top = 20;            // 看跌信号右侧检查周期
extern int Lookback_Top = 20;             // 看跌信号左侧检查周期

// --- 信号确认参数 ---
extern int Max_Signal_Lookforward = 20;    // 最大信号确认前瞻 K 线数量 (P1 突破检查范围)
extern int DB_Threshold_Candles = 3;      // [V1.22 NEW] DB 突破的最小 K 线数量 (N >= 3 为 DB, N < 3 为 IB)

// --- 四个变量开始 将来可能会移除掉 ---
// [V1.25 NEW] 调试控制
extern bool Debug_Print_Info_Once = true; // 是否仅在指标首次加载时打印调试信息 (如矩形范围等)
// --- 全局变量/静态标志 ---
static bool initial_debug_prints_done = false; // [V1.25 NEW] 内部标志：是否已完成首次加载时的调试打印

//限制运行次数
extern bool Debug_LimitCalculations = true;
static int g_run_count = 0; // 记录 OnCalculate 的运行次数
// --- 四个变量结束 将来可能会移除掉 ---

string g_object_prefix = ""; // [V1.32 NEW] 唯一对象名前缀


// --- 指标缓冲区 ---
double BullishTargetBuffer[]; // 0: 用于标记看涨K-Target锚点 (底部)
double BearishTargetBuffer[]; // 1: 用于标记看跌K-Target锚点 (顶部)
double BullishSignalBuffer[]; // 2: 最终看涨信号 (P2 或 P1-DB突破确认)
double BearishSignalBuffer[]; // 3: 最终看跌信号 (P2 或 P1-DB突破确认)

// --- 绘图属性 ---
// Plot 1: K-Target Bottom (锚点)
#property indicator_label1 "KTarget_Bottom"
#property indicator_type1  DRAW_ARROW
#property indicator_color1 clrBlue
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1
#define ARROW_CODE_UP 233 // 向上箭头

// Plot 2: K-Target Top (锚点)
#property indicator_label2 "KTarget_Top"
#property indicator_type2  DRAW_ARROW
#property indicator_color2 clrRed
#property indicator_style2 STYLE_SOLID
#property indicator_width2 1  // [V1.21 FIX] 修正了重复的 indicator_width1，确保正确设置 Plot 2 的宽度
#define ARROW_CODE_DOWN 234 // 向下箭头

// Plot 3: 最终看涨信号 
#property indicator_label3 "Bullish_Signal"
#property indicator_type3  DRAW_ARROW
#property indicator_color3 clrLimeGreen
#property indicator_style3 STYLE_SOLID
#property indicator_width3 2
#define ARROW_CODE_SIGNAL_UP 233 

// Plot 4: 最终看跌信号 
#property indicator_label4 "Bearish_Signal"
#property indicator_type4  DRAW_ARROW
#property indicator_color4 clrDarkViolet
#property indicator_style4 STYLE_SOLID
#property indicator_width4 2
#define ARROW_CODE_SIGNAL_DOWN 234

// --- 函数原型 ---
void FindAndDrawTargetCandles(int total_bars);
bool CheckKTargetBottomCondition(int i, int total_bars);
bool CheckKTargetTopCondition(int i, int total_bars);
void DrawTargetBottom(int target_index);
void DrawTargetTop(int target_index);

void CheckBullishSignalConfirmation(int target_index);
void CheckBearishSignalConfirmation(int target_index);

// V1.31 UPD: 流程协调者模式，传入所有几何参数，实现解耦
void CheckBullishSignalConfirmationV1(int target_index, int P2_index, int K_Geo_Index, int N_Geo);
void CheckBearishSignalConfirmationV1(int target_index, int P2_index, int K_Geo_Index, int N_Geo);

void DrawP2Baseline(int target_index, int breakout_index, bool is_bullish);
void DrawP1Baseline(int target_index, int breakout_index, bool is_bullish, double P2_price);

int FindFirstP1BreakoutIndex(int target_index, bool is_bullish);
int FindP2Index(int target_index, bool is_bullish);

// 新的逻辑
int FindAbsoluteLowIndex(int target_index, int lookback_range, int lookahead_range, bool is_bullish);
void DrawAbsoluteSupportLine(int target_index, int abs_index, bool is_bullish, int extend_bars);
//========================================================================
// 1. OnInit: 指标初始化
//========================================================================
int OnInit()
{
    // [V1.32 NEW] 生成唯一的对象名前缀
    g_object_prefix = WindowExpertName() + StringFormat("_%d_", ChartID());
    Print("-->[KTarget_Finder4_FromGemini.mq4:138]: g_object_prefix: ", g_object_prefix);


    g_run_count = 0;
    // 缓冲区映射设置 (无变化)
    SetIndexBuffer(0, BullishTargetBuffer);
    SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 1, clrBlue); 
    SetIndexArrow(0, ARROW_CODE_UP);
    
    SetIndexBuffer(1, BearishTargetBuffer);
    SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 1, clrRed); 
    SetIndexArrow(1, ARROW_CODE_DOWN);
    
    SetIndexBuffer(2, BullishSignalBuffer);
    SetIndexStyle(2, DRAW_ARROW, STYLE_SOLID, 2, clrLimeGreen); 
    SetIndexArrow(2, ARROW_CODE_SIGNAL_UP);
    
    SetIndexBuffer(3, BearishSignalBuffer);
    SetIndexStyle(3, DRAW_ARROW, STYLE_SOLID, 2, clrDarkViolet); 
    SetIndexArrow(3, ARROW_CODE_SIGNAL_DOWN);
    
    // 初始化所有缓冲区数据为 0.0
    ArrayInitialize(BullishTargetBuffer, 0.0);
    ArrayInitialize(BearishTargetBuffer, 0.0);
    ArrayInitialize(BullishSignalBuffer, 0.0);
    ArrayInitialize(BearishSignalBuffer, 0.0);
    
    // 指标简称
    string shortName = "K-Target (B:"+IntegerToString(Lookback_Bottom)+" L:"+IntegerToString(Max_Signal_Lookforward)+") V1.23"; // [V1.22 UPD] 更新版本号
    IndicatorShortName(shortName);
    return(INIT_SUCCEEDED);
}

//========================================================================
// 2. OnDeinit: 指标卸载时调用 (清理图表对象)
//========================================================================
void OnDeinit(const int reason) 
{
    // 清理所有以 "IBDB_Line_" 为前缀的趋势线对象 (P1基准线)
    ObjectsDeleteAll(0, "IBDB_Line_"); 
    // [V1.22 NEW] 清理所有以 "IBDB_P2_Line_" 为前缀的趋势线对象 (P2基准线)
    ObjectsDeleteAll(0, "IBDB_P2_Line_"); 

    // [V1.32 UPD] 使用唯一的 g_object_prefix 进行清理
    for (int i = ObjectsTotal() - 1; i >= 0; i--)
    {
        string object_name = ObjectName(i);
        // 检查对象名称是否包含我们独有的前缀
        if (StringFind(object_name, g_object_prefix) != -1) 
        {
            ObjectDelete(0, object_name);
        }
    }
    
    ChartRedraw();
}


//========================================================================
// 3. OnCalculate: 主计算函数 (无变化)
//========================================================================
int OnCalculate(const int rates_total, 
                const int prev_calculated, 
                const datetime &time[], 
                const double& open[], 
                const double& high[], 
                const double& low[], 
                const double& close[], 
                const long& tick_volume[],
                const long& volume[],    
                const int& spread[])     
{

    if (Debug_LimitCalculations)
    {
        if (g_run_count >= 3)
        {
            // 如果达到限制，阻止进一步计算，直接返回
            return (rates_total);
        }
        g_run_count++; // 每次运行时增加计数
        // 打印提示信息到日志，便于调试确认
        Print("DEBUG LIMIT: OnCalculate Run #", g_run_count, " of 3");
    }

    // 检查是否有 K 线存在
    if(rates_total < 1) return(0); 

    // 清除缓冲区中的所有旧标记
    ArrayInitialize(BullishTargetBuffer, 0.0);
    ArrayInitialize(BearishTargetBuffer, 0.0);
    ArrayInitialize(BullishSignalBuffer, 0.0);
    ArrayInitialize(BearishSignalBuffer, 0.0);
    
    // 寻找并绘制所有符合条件的 K-Target 及突破信号
    FindAndDrawTargetCandles(rates_total);

    // [V1.25 NEW] 在第一次完整计算完成后，设置标志位，确保后续的 tick 不再触发调试打印。
    if (rates_total > prev_calculated) // 检查是否有新数据
    {
         if (!initial_debug_prints_done)
         {
              initial_debug_prints_done = true;
         }
    }
    
    // 返回 rates_total 用于下一次调用
    return(rates_total);
}


//========================================================================
// 4. FindAndDrawTargetCandles: 寻找 K-Target 的核心逻辑 (双向) (无变化)
//========================================================================
void FindAndDrawTargetCandles(int total_bars)
{
    // 确定实际循环上限
    int max_bars_to_scan = MathMin(total_bars, Scan_Range);
    
    // 循环从第一根已收盘 K 线 (i=1) 开始
    for (int i = 1; i < max_bars_to_scan; i++)
    {
        // 1. 检查 K-Target Bottom (看涨) 锚定条件
        if (CheckKTargetBottomCondition(i, total_bars))
        {
            DrawTargetBottom(i); 
            // 检查信号确认逻辑 (IB/DB 突破)
            //CheckBullishSignalConfirmation(i);

            // --- V1.31 NEW: 流程协调 (看涨) ---

            // 查找 P2 索引和价格
            int P2_index = FindP2Index(i, true);
            if (P2_index == -1) continue; // P2 查找失败，跳过该锚点
            double P2_price = Close[P2_index];

            // 查找 P1 突破索引 K_Geo_Index (第一次 P1 突破点)
            int K_Geo_Index = FindFirstP1BreakoutIndex(i, true);
            if (K_Geo_Index == -1) continue; // P1 突破失败，跳过该锚点

            // 计算突破距离 N_Geo
            int N_Geo = i - K_Geo_Index;

            // 绘制 P1 辅助线 (几何绘制职责)
            DrawP1Baseline(i, K_Geo_Index, true, P2_price);

            // 调用信号标记器 (仅传入数据)
            CheckBullishSignalConfirmationV1(i, P2_index, K_Geo_Index, N_Geo);
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对低点支撑线 ---
            int AbsLowIndex = FindAbsoluteLowIndex(i, 20, 20, true);
            Print("====>[KTarget_Finder4_FromGemini.mq4:298]: AbsLowIndex: ", AbsLowIndex);

            double lowprice = Low[AbsLowIndex];
            Print("====>[KTarget_Finder4_FromGemini.mq4:301]: lowprice: ", lowprice);
            
            if (AbsLowIndex != -1)
            {
                // 绘制绝对低点支撑线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(i, AbsLowIndex, true, 15);
            }
            // --- END V1.35 NEW ---

        }
        
        // 2. 检查 K-Target Top (看跌) 锚定条件
        if (CheckKTargetTopCondition(i, total_bars))
        {
            DrawTargetTop(i); 
            // 检查信号确认逻辑
            //CheckBearishSignalConfirmation(i);

            // --- V1.31 NEW: 流程协调 (看跌) ---

            // 查找 P2 索引和价格
            int P2_index = FindP2Index(i, false);
            if (P2_index == -1) continue; // P2 查找失败，跳过该锚点
            double P2_price = Close[P2_index];

            // 查找 P1 突破索引 K_Geo_Index (第一次 P1 突破点)
            int K_Geo_Index = FindFirstP1BreakoutIndex(i, false);
            if (K_Geo_Index == -1) continue; // P1 突破失败，跳过该锚点

            // 计算突破距离 N_Geo
            int N_Geo = i - K_Geo_Index;

            // 绘制 P1 辅助线 (几何绘制职责)
            DrawP1Baseline(i, K_Geo_Index, false, P2_price);

            // 调用信号标记器 (仅传入数据)
            CheckBearishSignalConfirmationV1(i, P2_index, K_Geo_Index, N_Geo);
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对高点阻力线 ---
            int AbsHighIndex = FindAbsoluteLowIndex(i, 20, 20, false); // 查找绝对最高点
            if (AbsHighIndex != -1)
            {
                // 绘制绝对高点阻力线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(i, AbsHighIndex, false, 15);
            }
            // --- END V1.35 NEW ---
        }
    }
}


//========================================================================
// 5. CheckKTargetBottomCondition: 检查目标反转阴线 (K-Target Bottom) (无变化)
//========================================================================
/*
   条件: 阴线，且收盘价是左右两侧周期内的最低收盘价。
*/
bool CheckKTargetBottomCondition(int i, int total_bars)
{
    // 1. 必须是阴线 (Bearish Candle)
    if (Close[i] >= Open[i]) return false;
    
    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= Lookahead_Bottom; k++)
    {
        int future_index = i - k; 
        if (future_index < 0) break; 
        // 必须是最低收盘价
        if (Close[future_index] < Close[i]) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= Lookback_Bottom; k++)
    {
        int past_index = i + k; 
        if (past_index >= total_bars) break; 
        // 必须是最低收盘价
        if (Close[past_index] < Close[i]) return false;
    }
    
    return true;
}


//========================================================================
// 6. CheckKTargetTopCondition: 检查目标反转阳线 (K-Target Top) (无变化)
//========================================================================
/*
   条件: 阳线，且收盘价是左右两侧周期内的最高收盘价。
*/
bool CheckKTargetTopCondition(int i, int total_bars)
{
    // 1. 必须是阳线 (Bullish Candle)
    if (Close[i] <= Open[i]) return false;
    
    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= Lookahead_Top; k++)
    {
        int future_index = i - k; 
        if (future_index < 0) break; 
        // 必须是最高收盘价
        if (Close[future_index] > Close[i]) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= Lookback_Top; k++)
    {
        int past_index = i + k; 
        if (past_index >= total_bars) break; 
        // 必须是最高收盘价
        if (Close[past_index] > Close[i]) return false;
    }
    
    return true;
}

//========================================================================
// 7. CheckBullishSignalConfirmation: 检查看涨信号的突破/确认逻辑 (V1.23 Final Logic)
//========================================================================
void CheckBullishSignalConfirmation(int target_index)
{
    double P1_price = Open[target_index];
    // ---开始 从这里解耦代码---
    int P2_index = FindP2Index(target_index, true);
    if (P2_index == -1)
    {
        return;
    }

    // double P2_price = FindSecondBaseline(target_index, true, P1_price);
    double P2_price = Close[P2_index];

    // --- 阶段 A: 几何结构绘制 (找到第一个 P1 突破点) ---
    // K_Geo_Index 是第一个 Close[j] > P1_price 的 K 线索引,K_Geo_Index 仅用于确定绘制 P1/P2 水平线的终点，以及 P1-DB 的箭头位置
    int K_Geo_Index = FindFirstP1BreakoutIndex(target_index, true);
    
    if (K_Geo_Index == -1) return; // 未发生 P1 突破，函数退出。

    // 绘制 P1/P2 水平线 (即使是 IB 也要绘制)
    int N_Geo = target_index - K_Geo_Index; 

    //DrawBreakoutTrendLine(target_index, K_Geo_Index, true, N_Geo, P2_price);
    DrawP1Baseline(target_index, K_Geo_Index, true, P2_price);
    // ---结束 从这里解耦代码---

    // --- 阶段 B: 信号箭头标记 (瀑布式查找) ---
    
    // 1. 最高优先级: 查找 P2 突破 (K_P2) 查找整个 Max_Signal_Lookforward 范围 逻辑正确没有问题
    if (P2_price > P1_price)
    {
        // 只需检查到 K_Geo_Index (第一次 P1 突破点) 为止
        for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
        {
            if (j < 0) break;
            if (Close[j] > P2_price) 
            {
                //绘制P2线
                DrawP2Baseline(P2_index, j, true);
                // 找到 K_P2。绘制 P2 箭头 (高偏移)
                BullishSignalBuffer[j] = Low[j] - 30 * Point(); 
                return; // 找到最高级别信号，立即退出函数
            }
        }
    }

    /*
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB)
    // 只有 P2 未在范围内突破时，才执行到此处。
    // 检查范围只需到 K_Geo_Index 为止
    for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
    {
        if (j < 0) break;
        
        // 只关心 P1 突破 K-bar
        if (Close[j] > P1_price)
        {
            int N_DB = target_index - j;
            string classification = (N_DB < DB_Threshold_Candles) ? "IB" : "DB";
            
            if (classification == "DB")
            {
                // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
                BullishSignalBuffer[j] = Low[j] - 20 * Point(); 
                return; // 找到次高级别信号，立即退出函数
            }
            // 如果是 IB，则不绘制箭头，继续循环（寻找更晚的 DB）
        }
    }
    */
    
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB) - 检查第一次 P1 突破是否满足 DB 延迟
    // 如果代码执行到这里，说明整个 N=5 范围内都没有 P2 突破。同时还说明 没有找到P2突破 但是一定有P1突破的索引 一定有P1突破
    
    // 检查第一次 P1 突破是否满足 DB 延迟 (N >= 3)
    if (N_Geo >= DB_Threshold_Candles)
    {
        //绘制P2线
        DrawP2Baseline(P2_index, K_Geo_Index, true);

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point(); 
        return; // 找到次高级别信号，立即退出函数
    }
    
    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
}

/**
 * 7.1
 * @param target_index: Argument 1
 * @param P2_index: Argument 2
 * @param K_Geo_Index: Argument 3
 * @param N_Geo: Argument 4
 */
void CheckBullishSignalConfirmationV1(int target_index, int P2_index, int K_Geo_Index, int N_Geo)
{
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

                // 找到 K_P2。绘制 P2 箭头 (高偏移)
                BullishSignalBuffer[j] = Low[j] - 30 * Point(); 
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

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point(); 
        return; // 找到次高级别信号，立即退出函数
    }
    
    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
}


//========================================================================
// 8. CheckBearishSignalConfirmation: 检查看跌信号的突破/确认逻辑 (对称修改)
//========================================================================
void CheckBearishSignalConfirmation(int target_index)
{
    double P1_price = Open[target_index];
    // ---开始 从这里解耦代码---
    int P2_index = FindP2Index(target_index, false);
    if (P2_index == -1)
    {
        return;
    }

    // double P2_price = FindSecondBaseline(target_index, false, P1_price);
    double P2_price = Close[P2_index];

    // --- 阶段 A: 几何结构绘制 (找到第一个 P1 突破点) ---
    // K_Geo_Index 是第一个 Close[j] < P1_price 的 K 线索引 [V1.23 FIX] 明确传入 is_bullish = false
    int K_Geo_Index = FindFirstP1BreakoutIndex(target_index, false);
    
    if (K_Geo_Index == -1) return;

    // 绘制 P1/P2 水平线 (即使是 IB 也要绘制)
    int N_Geo = target_index - K_Geo_Index; 
    //DrawBreakoutTrendLine(target_index, K_Geo_Index, false, N_Geo, P2_price);
    DrawP1Baseline(target_index, K_Geo_Index, false, P2_price);
    // ---结束 从这里解耦代码---

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

                // 找到 K_P2。绘制 P2 箭头 (高偏移)
                BearishSignalBuffer[j] = High[j] + 30 * Point(); 
                return; // 找到最高级别信号，立即退出函数
            }
        }
    }

    /*
    // 2. 次优先级: 查找 P1-DB 突破 (K_DB)
    for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
    {
        if (j < 0) break;
        
        if (Close[j] < P1_price) // 🚨 看跌：Close < P1
        {
            int N_DB = target_index - j;
            string classification = (N_DB < DB_Threshold_Candles) ? "IB" : "DB";

            if (classification == "DB")
            {
                // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
                BearishSignalBuffer[j] = High[j] + 20 * Point(); 
                return; // 找到次高级别信号，立即退出函数
            }
        }
    }
    */

    // 2. 次优先级: 查找 P1-DB 突破 (K_DB) - 检查第一次 P1 突破是否满足 DB 延迟
    // 如果代码执行到这里，说明整个 N=5 范围内都没有 P2 突破。
    
    // 检查第一次 P1 突破是否满足 DB 延迟 (N >= 3)
    if (N_Geo >= DB_Threshold_Candles)
    {
        // 绘制P2线
        DrawP2Baseline(P2_index, K_Geo_Index, false);
        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point(); 
        return; // 找到次高级别信号，立即退出函数
    }

    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
}

void CheckBearishSignalConfirmationV1(int target_index, int P2_index, int K_Geo_Index, int N_Geo)
{
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

                // 找到 K_P2。绘制 P2 箭头 (高偏移)
                BearishSignalBuffer[j] = High[j] + 30 * Point(); 
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

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point(); 
        return; // 找到次高级别信号，立即退出函数
    }

    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
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

/**
 * DrawSecondBaseline: 绘制第二基准价格线 (P2)
 * 用P2 K线的索引来解耦这个函数,P2 K线的开盘价, 突破P2的索引+2，终点是 P2 突破K的索引 但是这个突破值是一个动态值
 * @param target_index: Argument 1
 * @param breakout_index: Argument 2
 * @param is_bullish: Argument 3
 */
void DrawP2Baseline(int target_index, int breakout_index, bool is_bullish)
{
    if (target_index == -1)
    {
        return;
    }

    double P2_price= Close[target_index];
    // 如果 P2 价格无效 (未找到)，则不绘制
    if (P2_price <= 0.0) return;
    
    // Anchor 1 (起点): P2 价格，K-Target 锚点时间
    datetime time1 = Time[target_index];
    
    // Anchor 2 (终点): P2 价格，延伸到突破 K 线 + 2
    int end_bar_index = breakout_index - 2; 
    if (end_bar_index < 1) end_bar_index = 1;
    datetime time2 = Time[end_bar_index];
    
    string name = "IBDB_P2_Line_" + (is_bullish ? "B_" : "S_") + IntegerToString(target_index);
    string comment;

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1) return; 
    
    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, P2_price))
    {
        Print("无法创建 P2 趋势线对象: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 设置趋势线的第二个锚点 (终点)
    ObjectSetInteger(0, name, OBJPROP_TIME2, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, P2_price);
    
    // ** 明确设置它不是射线 **
    ObjectSetInteger(0, name, OBJPROP_RAY, false); 
    
    // 设置线条属性: 虚线，较细，不同颜色
    ObjectSetInteger(0, name, OBJPROP_COLOR, is_bullish ? clrDarkBlue : clrDarkRed); // 深色作为P2
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); 
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); // 点线/虚线
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景
    
    comment = "P2 Baseline" + " (P2:" + DoubleToString(P2_price, Digits) + ")";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//========================================================================
// 11. DrawBreakoutTrendLine: 绘制突破趋势线 (P1)
//========================================================================
/*
   绘制一条从 K-Target.Open (P1) 开始，价格水平延伸到突破 K 线 
   时间 + 2 根 K 线的时间上。
   明确设置 OBJPROP_RAY = false，确保它是一条线段。
*/
/**
 * 根据看涨锚点的索引 和 P1 突破K线的索引  绘制趋势线，这是本程序绘制的第一条趋势线 非常关键
 * 绘制一条从 K-Target.Open (P1) 开始，价格水平延伸到突破 K 线
 * 时间 + 2 根 K 线的时间上。
 * 明确设置 OBJPROP_RAY = false，确保它是一条线段。
 * 
 * @param target_index: 看涨锚点的索引
 * @param breakout_index: P1 突破K线的索引
 * @param is_bullish: 阳线或者阴线
 * @param P2_price: 顺带着 展示出P2的价格 便于直观的对比
 */
void DrawP1Baseline(int target_index, int breakout_index, bool is_bullish, double P2_price)
{
    // K_Geo_Index 这个值在函数调用之前 需要检查 如果是-1 就不执行了，通过这个值确定是 DB 还是IB
    int breakout_candle_count = target_index - breakout_index;

    // Anchor 1 (起点): K-Target 锚点的 Open 价格和时间 (P1)
    datetime time1 = Time[target_index];
    double price1 = Open[target_index]; 
    
    // --- Anchor 2 (终点) 计算 ---
    
    // 终点 K 线索引: 使用突破 K 线索引，并向右 (现价方向) 延伸 2 根 K 线
    int end_bar_index = breakout_index - 2; 
    
    // 边界检查：确保索引不小于 1 (1 是最新的已收盘 K 线)
    if (end_bar_index < 1) 
    {
        end_bar_index = 1; // 防止数组越界
    }
    
    datetime time2 = Time[end_bar_index]; // 使用推移后的时间
    double price2 = price1;                 // 价格与起点价格保持一致 (实现水平线效果)
    
    // [V1.22 NEW] 突破类型分类
    string classification = breakout_candle_count < DB_Threshold_Candles ? "IB" : "DB";
    
    // 生成唯一的对象名称 
    string name = "IBDB_Line_" + classification + (is_bullish ? "B_" : "S_") + IntegerToString(target_index);
    string comment;
    
    // 检查对象是否已存在，如果存在则直接返回
    if (ObjectFind(0, name) != -1) return; 
    
    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, price1))
    {
        Print("无法创建 P1 趋势线对象: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 设置趋势线的第二个锚点 (终点)
    ObjectSetInteger(0, name, OBJPROP_TIME2, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, price2);
    
    // ** 明确设置它不是射线 **
    ObjectSetInteger(0, name, OBJPROP_RAY, false); 
    
    // 设置线条属性
    ObjectSetInteger(0, name, OBJPROP_COLOR, is_bullish ? clrLimeGreen : clrDarkViolet); 
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); 
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); // 实线 (P1)
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景 (线在 K 线后面)
    
    // [V1.22 UPD] 设置注释/描述，包含 IB/DB 分类和 P2 价格
    comment = classification + " P1 @" + DoubleToString(price1, Digits) + " (P2:" + DoubleToString(P2_price, Digits) + ")";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    
    // 将趋势线设置为不可选中
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}


//========================================================================
// 12. DrawTargetBottom: 绘图函数，用向上箭头标记 K-Target Bottom (无变化)
//========================================================================
void DrawTargetBottom(int target_index)
{
    // 将箭头标记在 K-Target 的最低价之下
    BullishTargetBuffer[target_index] = Low[target_index] - 10 * Point(); 
}

//========================================================================
// 13. DrawTargetTop: 绘图函数，用向下箭头标记 K-Target Top (无变化)
//========================================================================
void DrawTargetTop(int target_index)
{
    // 将箭头标记在 K-Target 的最高价之上
    BearishTargetBuffer[target_index] = High[target_index] + 10 * Point(); 
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
    Print(">[KTarget_Finder4_FromGemini.mq4:771]: P1_price: ", P1_price);

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

// ----------------------新的绘图逻辑开始了----------------------
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
    //double extreme_price = is_bullish ? High[target_index] : Low[target_index]; // 初始值使用 K-Target 本身的价格
    double extreme_price = is_bullish ? Low[target_index] : High[target_index]; // 初始值使用 K-Target 本身的价格
    Print("-->[KTarget_Finder4_FromGemini.mq4:959]: extreme_price: ", extreme_price);//先测试看涨的是否能 找到最低价格
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

//========================================================================
// 15. DrawAbsoluteSupportLine: 绘制绝对支撑/阻力水平线 (V1.35 NEW)
//========================================================================
/**
 * 在绝对低点/高点上绘制一条水平趋势线，并带文字说明。
 * * @param target_index: K-Target 锚点索引 (用于命名)
 * @param abs_index: 具有绝对低/高价的 K 线索引。
 * @param is_bullish: 看涨 (支撑线) 还是看跌 (阻力线)。
 * @param extend_bars: 向右延伸的 K 线数量 (例如 15)。
 */
void DrawAbsoluteSupportLine(int target_index, int abs_index, bool is_bullish, int extend_bars)
{
    if (abs_index < 0)
        return;

    // 确定线条的锚点价格
    double price = is_bullish ? Low[abs_index] : High[abs_index];
    Print("===>[KTarget_Finder4_FromGemini.mq4:1048]: price: ", price);

    // 确定线条的起点和终点时间
    datetime time1 = Time[abs_index]; // 起点时间：绝对极值 K 线的时间

    // 终点 K 线索引：从 abs_index 向右（较新 K 线）移动 extend_bars
    int end_bar_index = abs_index - extend_bars;
    if (end_bar_index < 0)
        end_bar_index = 0; // 边界检查

    datetime time2 = Time[end_bar_index]; // 终点时间

    // --- 对象创建与设置 ---
    string name = g_object_prefix + (is_bullish ? "AbsLow_" : "AbsHigh_") + IntegerToString(target_index);

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1)
        return;

    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price))
    {
        Print("无法创建 绝对最低价对象: ", name, ", 错误: ", GetLastError());
        return;
    }

    // 设置属性
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); // 最细样式 (宽度 1)
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景
    ObjectSetInteger(0, name, OBJPROP_RAY, false); // 确保是线段

    // 设置文字说明 (可见文本)
    string comment = is_bullish ? "Absolute Low Support" : "Absolute High Resistance";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);

    // **确保文字可见性**：将文字附加在趋势线的一端，并调整其位置。
    // 在 MQL4 中，OBJ_TREND 的 OBJPROP_TEXT 默认是可见的，我们只需要确保它没有被其他东西遮挡。

    // 3. 更新位置
    ObjectSetInteger(0, name, OBJPROP_TIME1, time1);
    ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
    ObjectSetInteger(0, name, OBJPROP_TIME2, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, price);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}