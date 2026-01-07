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
#include <K5/K_Data.mqh>

// 缓冲区 核心配置 非核心配置 附属配置  会话配置  测试配置 全局变量
#include <Config7/Define_buffers.mqh>
#include <Config7/Config_Core.mqh>
#include <Config7/Config_Non_Core.mqh>
#include <Config7/Config_Add.mqh>
// 会话和测试是各自独立的
#include <Config7/Config_Sessions.mqh>
#include <Config7/Config_Test.mqh>
#include <Config7/Config_Global_var.mqh>
//+------------------------------------------------------------------+
//| ✅ 配置 数据 工具函数
//+------------------------------------------------------------------+
#include <K5/K_Utils.mqh>
#include <K7/K_Logic.mqh>
#include <K7/K_Drawing_Funcs.mqh>
#include <K7/K_Test.mqh>

//+------------------------------------------------------------------+
//| 函数原型
//+------------------------------------------------------------------+
// void FindAndDrawTargetCandles(int total_bars);
// bool CheckKTargetBottomCondition(int i, int total_bars);
// bool CheckKTargetTopCondition(int i, int total_bars);
// void DrawTargetBottom(int target_index);
// void DrawTargetTop(int target_index);

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

    SaveParamsToChart();

    // [新增] 探测服务器时区
    DetectServerTimeZone();

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
        Print(">>> KTarget 历史信号全量统计完成【prev_calculated】 <<<");
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
            Print("--->[234]: trigger_type: ", trigger_type);
        }

        // 清除缓冲区中的所有旧标记
        ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);

        // 寻找并绘制所有符合条件的 K-Target 及突破信号
        FindAndDrawTargetCandles(rates_total);

        // Print("=================================================");
        // Print(">>> KTarget 历史信号全量统计完成【NEW BAR (收线触发)】 <<<");
        // Print(g_Stats.ToString());
        // Print("=================================================");
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

    // ---------------------------------------------------------
    // [新增] 绘制市场时段模块
    // ---------------------------------------------------------
    if (Period() <= PERIOD_H1)
    {
        // 仅在历史加载或新K线时绘制，避免每个Tick都重绘，节省资源
        if (Show_Sessions && (prev_calculated == 0 || time[0] > last_bar_time))
        {
            DrawMarketSessions(Session_Lookback, Server_Time_Offset);
        }
    }
    UpdateATRDisplay();

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
            // 如果返回 0，说明是当前K线正在破，还没收盘，为了不重绘，暂时忽略
            if (K_Geo_Index == 0) continue;

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
            if (K_Geo_Index == 0) continue;

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
// FindAndDrawTargetCandles: 寻找 K-Target 的核心逻辑 (双向) (老实人过滤机制 (The Honest Filter))
//========================================================================
void FindAndDrawTargetCandles_The_Honest(int total_bars)
{
    // 确定实际循环上限
    int max_bars_to_scan = MathMin(total_bars, Scan_Range);
    // int LookAhead_Confirm_Bars = 20; // 老实人模式：必须等右边走出20根确认
    int LookAhead_Confirm_Bars = MathMax(Lookahead_Bottom, Lookahead_Top);

    // 循环从第一根已收盘 K 线 (i=1) 开始
    for (int i = 1; i < max_bars_to_scan; i++)
    {
        // -------------------------------------------------------------
        // 【新增逻辑】老实人过滤机制 (The Honest Filter)
        // -------------------------------------------------------------
        
        // 1. 如果当前的 i 小于我们需要的确认根数，说明“还没走完20根”，直接跳过
        // 这就是“滞后”的体现：最新的 20 根 K 线内，绝不画信号
        if (i < LookAhead_Confirm_Bars) 
            continue; 

        // 2. 强制检查右侧 (未来) 的 20 根 K 线
        bool is_strict_lowest = true;
        bool is_strict_highest = true;

        for (int k = 1; k <= LookAhead_Confirm_Bars; k++)
        {
            // 向右看 (索引减小)：i-k
            // 如果右边任何一根收盘价/最低价 比 i 还低，说明 i 根本不是底部
            if (Low[i-k] <= Low[i]) 
            {
                is_strict_lowest = false;
            }
            // 如果右边任何一根收盘价/最高价 比 i 还高，说明 i 根本不是顶部
            if (High[i-k] >= High[i])
            {
                is_strict_highest = false;
            }
        }
        // -------------------------------------------------------------

        // 1. 检查 K-Target Bottom (看涨) 锚定条件
        if (is_strict_lowest && IsKTargetBottom(i, total_bars))
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
            // 如果返回 0，说明是当前K线正在破，还没收盘，为了不重绘，暂时忽略
            if (K_Geo_Index == 0) continue;

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
        if (is_strict_highest && IsKTargetTop(i, total_bars))
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
            if (K_Geo_Index == 0) continue;

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