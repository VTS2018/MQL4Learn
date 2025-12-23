//+------------------------------------------------------------------+
//|                          K-Target 突破信号识别指标 (XBreaking Signal)
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
//|                          版本迭代日志 (Changelog)
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
#property version   "1.5" 
#property strict
#property indicator_chart_window // 绘制在主图表窗口
#property indicator_buffers 4 // 两个锚点 + 两个最终信号
#property indicator_plots   4 // 对应四个绘图

//+------------------------------------------------------------------+
//| ✅ 配置 数据 工具函数
//+------------------------------------------------------------------+
#include <K5/K_Data.mqh>
#include <K5/K_Utils.mqh>
#include <K7/K_Logic.mqh>
#include <K7/K_Drawing_Funcs.mqh>

#include <Config7/Config_Core.mqh>
//+------------------------------------------------------------------+
//| ✅ 四个变量开始 将来可能会移除掉 调试控制
//+------------------------------------------------------------------+
// extern bool Debug_Print_Info_Once = true; // 是否仅在指标首次加载时打印调试信息 (如矩形范围等)
// static bool initial_debug_prints_done = false; // 内部标志：是否已完成首次加载时的调试打印

// extern bool Debug_LimitCalculations = true; // 限制运行次数 用于开发调试阶段
// static int g_run_count = 0; // 记录 OnCalculate 的运行次数

//+------------------------------------------------------------------+
//| ✅ 专门研究 (OnCalculate)
//+------------------------------------------------------------------+
extern int Timer_Interval_Seconds = 5; // OnTimer 触发间隔 (秒)

static datetime last_bar_time = 0;   // 记录上次计算时的 K 线时间
static datetime last_tick_time = 0;  // 记录上次 OnCalculate 触发的时间 (用于区分Tick)
static int on_calculate_count = 0;   // OnCalculate 【触发次数计数】
static bool is_initial_load = true;  // 标记是否为首次历史数据加载

// 两个字符串变量用于 OnCalculate 和 OnTimer 之间的通信
static string on_calc_output_segment = ""; // 存储 OnCalculate 的计算结果部分
static string on_timer_output_segment = ""; // 存储 OnTimer 的输出结果部分

//+------------------------------------------------------------------+
//| ✅ 唯一对象名前缀
//+------------------------------------------------------------------+
string g_object_prefix = ""; // [V1.32 NEW] 

//+------------------------------------------------------------------+
//| ✅ 绘图控制开关
//+------------------------------------------------------------------+
extern bool Is_DrawFibonacciLines = true; // 控制是否绘制 信号的 斐波那契回调线 (true=开启, false=关闭)

//+------------------------------------------------------------------+
//| ✅ 静态变量：用于检查两次点击之间的间隔，
//| 以模拟“双击” 将 LastClickTime 改为存储毫秒数 (unsigned long)
//+------------------------------------------------------------------+
// static datetime LastClickTime = 0;
static ulong LastClickTime_ms = 0;
const ulong DOUBLE_CLICK_TIMEOUT_MS = 500; // 500 毫秒内算作双击

//+------------------------------------------------------------------+
//| ✅ K_Logic v3.0 Parameters
//+------------------------------------------------------------------+
input string   __V3_Settings__   = "=== v3.0 智能增强 ===";
input bool     Enable_V3_Logic   = true;         // 是否开启 v3 增强逻辑
input ENUM_SIGNAL_GRADE Min_Alert_Grade = GRADE_B; // 报警最低门槛 (建议 B 或 A)

datetime g_LastAlertTime = 0; // 记录上一次成功报警的K线时间

//+------------------------------------------------------------------+
//| ✅ [新增] 斐波那契绘图过滤器
//+------------------------------------------------------------------+
input bool Show_History_Fibo   = false;  // [开关] 是否显示历史信号的斐波投影 (False=只看当前最新)
input bool Hide_Invalid_Fibo   = true;   // [智能] 是否隐藏已失效(止损)或已完成(止盈)的信号
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ [新增] 单元测试控制模块
//+------------------------------------------------------------------+
string   __TEST_SETTINGS__  = "=== 内核单元测试 ===";
bool     Run_Self_Test      = false;      // [开关] 是否在加载时运行 EvaluateSignal 自检
int      Test_History_Bars  = 1000;       // [范围] 测试扫描的历史K线数量
bool     Test_Print_Detail  = true;      // [日志] 是否打印每一笔信号的详情
#include <K7/K_Test.mqh>

// 声明一个全局变量
SignalStatReport g_Stats;
//+------------------------------------------------------------------+

#include <Config7/Define_buffers.mqh>

//+------------------------------------------------------------------+
//| 函数原型
//+------------------------------------------------------------------+
// void FindAndDrawTargetCandles(int total_bars);
// bool CheckKTargetBottomCondition(int i, int total_bars);
// bool CheckKTargetTopCondition(int i, int total_bars);
// void DrawTargetBottom(int target_index);
// void DrawTargetTop(int target_index);

//| 流程协调者模式，传入所有几何参数，实现解耦
// void CheckBullishSignalConfirmation(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex);
// void CheckBearishSignalConfirmation(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_hightindex);

//========================================================================
// 1. OnInit: 指标初始化
//========================================================================
int OnInit()
{
    // 🚨 关键修正：显式地启用图形对象删除事件监听 🚨
    // 只有设置这个，OnChartEvent 才能接收到 CHARTEVENT_OBJECT_DELETE 事件
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);

    Init_Smart_Tuning();

    Init_Object_prefix();

    //+------------------------------------------------------------------+
    // 初始运行次数为0
    // g_run_count = 0;
    //+------------------------------------------------------------------+
    Init_Buffer();

    // 指标简称
    string shortName = "K-Target (B:"+IntegerToString(Lookback_Bottom)+" L:"+IntegerToString(Max_Signal_Lookforward)+") V1.23"; // [V1.22 UPD] 更新版本号
    IndicatorShortName(shortName);

    RunTest();

    // 非EA模式下 才启用 定时器和相关的打印逻辑
    if (!Is_EA_Mode)
    {
        // --- V1.31 NEW: 专门研究 (OnCalculate) ---
        // 2. 启动定时器：用于演示 OnTimer 函数的独立运行
        EventSetTimer(Timer_Interval_Seconds);

        // 3. 在图表上输出初始化信息 (使用 Comment 替代 Print 以获得图表反馈)
        string init_message =
            "*** INDICATOR INITIALIZED ***\n" +
            "Function: OnInit() executed.\n" +
            "Time: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n" +
            "Timer set to: " + IntegerToString(Timer_Interval_Seconds) + " seconds.";

        // Comment(init_message);
        Print("---->[KTarget_Finder_MT7:205]: init_message: ", init_message);
        // --- V1.31 NEW: 专门研究 (OnCalculate) ---

        Print("---->[KTarget_Finder_MT7.mq4:208]: ----OnInit 指标初始化完成---- ");
    }

    return(INIT_SUCCEEDED);
}

//========================================================================
// 2. OnDeinit: 指标卸载时调用 (清理图表对象)
//========================================================================
void OnDeinit(const int reason)
{
    if (!Is_EA_Mode)
    {
        // 停止定时器，避免内存泄漏
        EventKillTimer();

        // 清除图表上的 Comment 输出
        Comment("");
    }
    DeInit_DelObject();
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

    /** 如果将来调试代码，就将这里的注释去掉，让代码进入到Tick的执行模式 并开启上面的四个变量
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
    ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);
    
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
    */

    // ----------------- NEW 切换到真实环境 可以区分Tick触发类型的执行-----------------

    // --- 逻辑判断与计数 ---
    string trigger_type = "UNKNOWN";
    datetime current_time = TimeCurrent();
    on_calculate_count++;
    
    // 1. 判断是否是历史数据加载
    if (prev_calculated == 0 || is_initial_load)
    {
        //先清零统计数据
        g_Stats.Reset();

        trigger_type = "History Load/Initial Run";
        is_initial_load = false;

        // 清除缓冲区中的所有旧标记
        ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);

        // 寻找并绘制所有符合条件的 K-Target 及突破信号
        FindAndDrawTargetCandles(rates_total);

        Print("=================================================");
        Print(">>> KTarget 历史信号全量统计完成 <<<");
        Print(g_Stats.ToString());
        Print("=================================================");
    }
    // 2. 判断是否是新 K 线触发
    else if (time[0] > last_bar_time) 
    {
        g_Stats.Reset();
        trigger_type = "NEW BAR (收线触发)";
        if (!Is_EA_Mode)
        {
            Print("--->[KTarget_Finder5.mq4:332]: trigger_type: ", trigger_type);
        }

        // 清除缓冲区中的所有旧标记
        ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);

        // 寻找并绘制所有符合条件的 K-Target 及突破信号
        FindAndDrawTargetCandles(rates_total);
    }
    // 3. 判断是否是 Tick 触发
    else if (current_time > last_tick_time && rates_total == prev_calculated)
    {
        trigger_type = "TICK Update (Tick触发)";
    }
    else
    {
        trigger_type = "Tick Update (Same Time)";
    }
        
    // 4. 更新全局静态变量
    last_bar_time = time[0];
    last_tick_time = current_time;

    if (!Is_EA_Mode)
    {
        // 5. 构建 OnCalculate 的输出段，并存储到全局变量
        on_calc_output_segment =
            "*** OnCalculate Status ***\n" +
            "Count: " + IntegerToString(on_calculate_count) + "\n" +
            "Trigger: " + trigger_type + "\n" +
            "Trigger Time: " + TimeToString(current_time, TIME_SECONDS) + "\n" +
            "--------------------------------------\n" +
            "K[0] Start Time: " + TimeToString(time[0], TIME_MINUTES) + "\n" +
            "Current Bid: " + DoubleToString(Bid, Digits) + "\n" +
            "Current Ask: " + DoubleToString(Ask, Digits) + "\n" +
            "K-Line Total: " + IntegerToString(rates_total) + "\n" +
            "Last Calculated: " + IntegerToString(prev_calculated) + "\n";

        // 6. 将 OnCalculate 的结果和 OnTimer 的结果合并显示
        Comment(on_calc_output_segment + "\n" + on_timer_output_segment);
    }

    return(rates_total);  

    // ----------------- END 切换到真实环境 可以区分Tick触发类型的执行-----------------
}

//+------------------------------------------------------------------+
//| 4. 定时器函数 (OnTimer)
//+------------------------------------------------------------------+
void OnTimer()
{
    if (!Is_EA_Mode)
    {
        // OnTimer 独立运行，不依赖Tick或K线收盘
        string timer_output =
            "**OnTimer Status**\n" +
            "Function: OnTimer() executed.\n" +
            "Time: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n" +
            "Current Bid: " + DoubleToString(Bid, Digits) + "\n" +
            "Note: OnTimer runs independently of OnCalculate.";

        // 1. 更新 OnTimer 的输出段，并存储到全局变量
        on_timer_output_segment = timer_output;

        // 2. 将 OnCalculate 的最新结果和 OnTimer 的结果合并显示
        // 即使 OnCalculate 触发频繁，我们总是用最新的两段信息进行组合
        Comment(on_calc_output_segment + "\n" + on_timer_output_segment);
    }
}

//+------------------------------------------------------------------+
//| ChartEvent function - 接收所有图表/对象事件的关键函数
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // 🚨 核心修正：在 EA 模式下，立即退出函数，不做任何处理 🚨
    if (Is_EA_Mode)
    {
        return; 
    }
    
    // 1. 打印所有事件的通用信息
    // Print("--- EVENT RECEIVED --- ID:", id, 
    //       ", lparam:", lparam, 
    //       ", dparam:", dparam, 
    //       ", sparam (Name/Key):", sparam);

    // --- 2. 针对特定事件进行处理和深入解析 ---
    switch(id)
    {
        case CHARTEVENT_OBJECT_CLICK:
        {
            HandleObjectClick(sparam);
            break;
        }

        case CHARTEVENT_KEYDOWN:
        {
            // 用户按下了键盘上的键
            // Print("    侦测到键盘按下事件 (CHARTEVENT_KEYDOWN)");
            // Print("    按下的键代码 (lparam): ", lparam);
            break;
        }
            
        case CHARTEVENT_CHART_CHANGE:
        {
            // 图表变动：例如窗口大小改变、缩放、切换周期
            // Print("    图表变动事件 (CHARTEVENT_CHART_CHANGE) 发生。");
            break;
        }

        case CHARTEVENT_OBJECT_DELETE:
        {
            HandleObjectDelete(sparam);
            break;
        }

        default:
            // 其他事件，例如 CHARTEVENT_MOUSE_MOVE (需要显式开启)
            // Print("    接收到其他事件...");
            break;
    }
}
//+------------------------------------------------------------------+

//========================================================================
// FindAndDrawTargetCandles: 寻找 K-Target 的核心逻辑 (双向) (无变化)
//========================================================================
void FindAndDrawTargetCandles(int total_bars)
{
    // 确定实际循环上限
    int max_bars_to_scan = MathMin(total_bars, Scan_Range);
    
    // 循环从第一根已收盘 K 线 (i=1) 开始
    for (int i = 1; i < max_bars_to_scan; i++)
    {
        // 1. 检查 K-Target Bottom (看涨) 锚定条件
        if (IsKTargetBottom(i, total_bars))
        {
            // 1.0
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
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对低点支撑线 ---
            int AbsLowIndex = FindAbsoluteLowIndex(i, Look_LLHH_Candles, Look_LLHH_Candles, true);
            //Print("====>[KTarget_Finder4_FromGemini.mq4:298]: AbsLowIndex: ", AbsLowIndex);

            // double lowprice = Low[AbsLowIndex];
            //Print("====>[KTarget_Finder4_FromGemini.mq4:301]: lowprice: ", lowprice);
            
            if (AbsLowIndex != -1)
            {
                // 绘制绝对低点支撑线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(AbsLowIndex, true, 15);
            }
            // --- END V1.35 NEW ---

            // 调用信号标记器 (仅传入数据)
            CheckBullishSignalConfirmation(i, P2_index, K_Geo_Index, N_Geo, AbsLowIndex);
        }
        
        // 2. 检查 K-Target Top (看跌) 锚定条件
        if (IsKTargetTop(i, total_bars))
        {
            // 1.0
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
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对高点阻力线 ---
            int AbsHighIndex = FindAbsoluteLowIndex(i, Look_LLHH_Candles, Look_LLHH_Candles, false); // 查找绝对最高点
            if (AbsHighIndex != -1)
            {
                // 绘制绝对高点阻力线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(AbsHighIndex, false, 15);
            }
            // --- END V1.35 NEW ---

            // 调用信号标记器 (仅传入数据)
            CheckBearishSignalConfirmation(i, P2_index, K_Geo_Index, N_Geo, AbsHighIndex);
        }
    }
}

//========================================================================
// DrawTargetBottom: 绘图函数，用向上箭头标记 K-Target Bottom (无变化)
// BullishTargetBuffer[] 函数如果存储最低价格以后 本质上这两个函数就没用了
//========================================================================
void DrawTargetBottom(int target_index)
{
    if (Is_EA_Mode) return;
    // 将箭头标记在 K-Target 的最低价之下
    BullishTargetBuffer[target_index] = Low[target_index] - 10 * Point();

    /*
    // 2.0 修复看跌阴线锚点丢失的 问题 需要将锚点标注代码 放在这里
    // --- DrawTargetBottom 的真正逻辑 其实转到了这里
    if (Is_EA_Mode)
    {
        // 目标： 在 {EA}模式下，停止在锚点 {i} 处写入 {SL}价格，仅保留人工模式下的绘图价格赋值。
        // 🚨 修正：移除 EA 模式下的 BullishTargetBuffer[i] 赋值 🚨
        // 即EA模式下 不需要对看涨锚点和看跌锚点进行 缓冲区写入，只保留人工模式下的写入
        // BullishTargetBuffer[i] = Low[AbsLowIndex];
    }
    else
    {
        BullishTargetBuffer[i] = Low[i] - 10 * Point();
    }
    // --- 结束 DrawTargetBottom
    */
}

//========================================================================
// DrawTargetTop: 绘图函数，用向下箭头标记 K-Target Top (无变化)
//========================================================================
void DrawTargetTop(int target_index)
{
    if (Is_EA_Mode) return;
    // 将箭头标记在 K-Target 的最高价之上
    BearishTargetBuffer[target_index] = High[target_index] + 10 * Point();
    
    /*
    // 2.0 修复
    // --- DrawTargetTop 的真正逻辑 其实转到了这里
    if (Is_EA_Mode)
    {
        // BearishTargetBuffer[i] = High[AbsHighIndex];
    }
    else
    {
        BearishTargetBuffer[i] = High[i] + 10 * Point();
    }
    // --- 结束DrawTargetTop
    */
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

void RunTest()
{
    // =================================================================
    // 🧪 [新增] 执行单元测试
    // =================================================================
    if (Run_Self_Test)
    {
        // 延迟一小段时间或直接执行，确保环境已就绪
        Print(" 正在启动 EvaluateSignal 内核单元测试...");
        Run_EvaluateSignal_Unit_Test(); // 调用我们将要添加的测试函数
        Print(" 单元测试执行完毕。请查看【专家(Experts)】选项卡日志。");
    }
    // =================================================================
}