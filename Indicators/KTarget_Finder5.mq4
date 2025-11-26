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

// 配置 数据 工具函数
#include <K_Data.mqh>
#include <K_Utils.mqh>
#include <K_Logic.mqh>
#include <K_Drawing_Funcs.mqh>

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
extern int DB_Threshold_Candles = 3;      // DB 突破的最小 K 线数量 (N >= 3 为 DB, N < 3 为 IB)

// --- 四个变量开始 将来可能会移除掉 调试控制---
extern bool Debug_Print_Info_Once = true; // 是否仅在指标首次加载时打印调试信息 (如矩形范围等)
static bool initial_debug_prints_done = false; // 内部标志：是否已完成首次加载时的调试打印

extern bool Debug_LimitCalculations = true; // 限制运行次数 用于开发调试阶段
static int g_run_count = 0; // 记录 OnCalculate 的运行次数
// --- 四个变量结束 将来可能会移除掉 ---

// --- V1.31 NEW: 专门研究 (OnCalculate) ---

extern int Timer_Interval_Seconds = 5; // OnTimer 触发间隔 (秒)

static datetime last_bar_time = 0;   // 记录上次计算时的 K 线时间
static datetime last_tick_time = 0;  // 记录上次 OnCalculate 触发的时间 (用于区分Tick)
static int on_calculate_count = 0;   // OnCalculate 【触发次数计数】
static bool is_initial_load = true;  // 标记是否为首次历史数据加载

// 两个字符串变量用于 OnCalculate 和 OnTimer 之间的通信
static string on_calc_output_segment = ""; // 存储 OnCalculate 的计算结果部分
static string on_timer_output_segment = ""; // 存储 OnTimer 的输出结果部分

// --- V1.31 END: 专门研究 (OnCalculate) ---

string g_object_prefix = ""; // [V1.32 NEW] 唯一对象名前缀

//--- 绘图控制开关---
extern bool Is_DrawFibonacciLines = false; // 控制是否绘制 信号的 斐波那契回调线 (true=开启, false=关闭)

// 静态变量：用于检查两次点击之间的间隔，以模拟“双击” 将 LastClickTime 改为存储毫秒数 (unsigned long)
// static datetime LastClickTime = 0;
static ulong LastClickTime_ms = 0;
const ulong DOUBLE_CLICK_TIMEOUT_MS = 500; // 500 毫秒内算作双击

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

// V1.31 UPD: 流程协调者模式，传入所有几何参数，实现解耦
void CheckBullishSignalConfirmationV1(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex);
void CheckBearishSignalConfirmationV1(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_hightindex);

//========================================================================
// 1. OnInit: 指标初始化
//========================================================================
int OnInit()
{
    // long cid = ChartID();
    // Print("-->[KTarget_Finder5.mq4:152]: cid: ", cid);

    // 1. 获取 ChartID 的绝对值 (long 类型)
    long full_chart_id = MathAbs(ChartID());
    // Print("-->[KTarget_Finder5.mq4:156]: full_chart_id: ", full_chart_id);

    // 2. 强制截断 ChartID 到 32 位 int。
    // 仅保留 ID 的低位部分，使其长度大幅缩短，但仍具有高度唯一性。
    int short_chart_id = (int)full_chart_id;
    // Print("-->[KTarget_Finder5.mq4:161]: short_chart_id: ", MathAbs(short_chart_id));

    // [V1.32 NEW] 生成唯一的对象名前缀
    g_object_prefix = ShortenObjectName(WindowExpertName()) + StringFormat("_%d_", MathAbs(short_chart_id));
    // Print("-->[KTarget_Finder5.mq4:165]: g_object_prefix: ", g_object_prefix);

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
    ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);
    
    // 指标简称
    string shortName = "K-Target (B:"+IntegerToString(Lookback_Bottom)+" L:"+IntegerToString(Max_Signal_Lookforward)+") V1.23"; // [V1.22 UPD] 更新版本号
    IndicatorShortName(shortName);

    // --- V1.31 NEW: 专门研究 (OnCalculate) ---
    // 2. 启动定时器：用于演示 OnTimer 函数的独立运行
    EventSetTimer(Timer_Interval_Seconds);

    // 3. 在图表上输出初始化信息 (使用 Comment 替代 Print 以获得图表反馈)
    string init_message =
        "*** INDICATOR INITIALIZED ***\n" +
        "Function: OnInit() executed.\n" +
        "Time: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n" +
        "Timer set to: " + IntegerToString(Timer_Interval_Seconds) + " seconds.";

    Comment(init_message);
    Print("---->[KTarget_Finder5:214]: init_message: ", init_message);
    // --- V1.31 NEW: 专门研究 (OnCalculate) ---

    Print("---->[KTarget_Finder5.mq4:217]: OnInit 指标初始化完成 ");
    return(INIT_SUCCEEDED);
}

//========================================================================
// 2. OnDeinit: 指标卸载时调用 (清理图表对象)
//========================================================================
void OnDeinit(const int reason) 
{
    // 停止定时器，避免内存泄漏
    EventKillTimer();

    // 清除图表上的 Comment 输出
    Comment("");

    // 清理所有以 "IBDB_Line_" 为前缀的趋势线对象 (P1基准线)
    //ObjectsDeleteAll(0, "IBDB_Line_"); 
    // [V1.22 NEW] 清理所有以 "IBDB_P2_Line_" 为前缀的趋势线对象 (P2基准线)
    //ObjectsDeleteAll(0, "IBDB_P2_Line_"); 

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
    Print("---->[KTarget_Finder5.mq4:249]: OnDeinit 指标卸载 ");
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

    // ----------------- NEW 切换到真是环境 可以区分Tick触发类型的执行-----------------

    // --- 逻辑判断与计数 ---
    string trigger_type = "UNKNOWN";
    datetime current_time = TimeCurrent();
    on_calculate_count++;
    
    // 1. 判断是否是历史数据加载
    if (prev_calculated == 0 || is_initial_load)
    {
        trigger_type = "History Load/Initial Run";
        is_initial_load = false;

        // 清除缓冲区中的所有旧标记
        ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
        ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
        ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);

        // 寻找并绘制所有符合条件的 K-Target 及突破信号
        FindAndDrawTargetCandles(rates_total);
    }
    // 2. 判断是否是新 K 线触发
    else if (time[0] > last_bar_time) 
    {
        trigger_type = "NEW BAR (收线触发)";
        Print("--->[KTarget_Finder5.mq4:332]: trigger_type: ", trigger_type);

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
    return(rates_total);    

    // ----------------- END 切换到真是环境 可以区分Tick触发类型的执行-----------------
}

//+------------------------------------------------------------------+
//| 4. 定时器函数 (OnTimer)                                          |
//+------------------------------------------------------------------+
void OnTimer()
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

//+------------------------------------------------------------------+
//| ChartEvent function - 接收所有图表/对象事件的关键函数               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
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
                Print("===>[KTarget_Finder5.mq4:320]: current_time_ms: ", current_time_ms);
                Print("===>[KTarget_Finder5.mq4:321]: LastClickTime_ms: ", LastClickTime_ms);

                // 2. 计算毫秒差（直接相减就是毫秒数）
                // 注意：GetTickCount() 返回值可能循环，但对于 500ms 的短期差值是可靠的。
                ulong time_diff_ms = current_time_ms - LastClickTime_ms;
                Print("===>[KTarget_Finder5.mq4:326]: time_diff_ms: ", time_diff_ms);

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

                            // 确保 Fibo 立即显示
                            //ChartRedraw(0);
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
            break;
        }    
        case CHARTEVENT_KEYDOWN:
        {
            // 用户按下了键盘上的键
            Print("    侦测到键盘按下事件 (CHARTEVENT_KEYDOWN)");
            Print("    按下的键代码 (lparam): ", lparam);
            break;
        }
            
        case CHARTEVENT_CHART_CHANGE:
        {
            // 图表变动：例如窗口大小改变、缩放、切换周期
            // Print("    图表变动事件 (CHARTEVENT_CHART_CHANGE) 发生。");
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
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对低点支撑线 ---
            int AbsLowIndex = FindAbsoluteLowIndex(i, 20, 20, true);
            //Print("====>[KTarget_Finder4_FromGemini.mq4:298]: AbsLowIndex: ", AbsLowIndex);

            double lowprice = Low[AbsLowIndex];
            //Print("====>[KTarget_Finder4_FromGemini.mq4:301]: lowprice: ", lowprice);
            
            if (AbsLowIndex != -1)
            {
                // 绘制绝对低点支撑线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(AbsLowIndex, true, 15);
            }
            // --- END V1.35 NEW ---

            // 调用信号标记器 (仅传入数据)
            CheckBullishSignalConfirmationV1(i, P2_index, K_Geo_Index, N_Geo, AbsLowIndex);
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
            // --- END V1.31 NEW ---

            // --- V1.35 NEW: 绝对高点阻力线 ---
            int AbsHighIndex = FindAbsoluteLowIndex(i, 20, 20, false); // 查找绝对最高点
            if (AbsHighIndex != -1)
            {
                // 绘制绝对高点阻力线，向右延伸 15 根 K 线
                DrawAbsoluteSupportLine(AbsHighIndex, false, 15);
            }
            // --- END V1.35 NEW ---

            // 调用信号标记器 (仅传入数据)
            CheckBearishSignalConfirmationV1(i, P2_index, K_Geo_Index, N_Geo, AbsHighIndex);
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

/**
 * 7.1
 * @param target_index: Argument 1
 * @param P2_index: Argument 2
 * @param K_Geo_Index: Argument 3
 * @param N_Geo: Argument 4
 */
void CheckBullishSignalConfirmationV1(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_lowindex)
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

                if (abs_lowindex != -1)
                {
                    /* 只有信号成立才绘制矩形 */
                    DrawP1P2Rectangle(abs_lowindex, j, true);

                    //DrawP1P2Fibonacci(abs_lowindex, j, true); 这里会绘制出所有的 斐波所以我设置了一个开关 所以这里取消就行了
                }

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

        if (abs_lowindex != -1)
        {
            /* 只有信号成立才绘制矩形 */
            DrawP1P2Rectangle(abs_lowindex, K_Geo_Index, true);
        }

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        BullishSignalBuffer[K_Geo_Index] = Low[K_Geo_Index] - 20 * Point(); 
        return; // 找到次高级别信号，立即退出函数
    }
    
    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
}


void CheckBearishSignalConfirmationV1(int target_index, int P2_index, int K_Geo_Index, int N_Geo, int abs_hightindex)
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
                if (abs_hightindex != -1)
                {
                    /* code */
                    DrawP1P2Rectangle(abs_hightindex, j, false);
                }

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

        if (abs_hightindex != -1)
        {
            /* code */
            DrawP1P2Rectangle(abs_hightindex, K_Geo_Index, false);
        }

        // 找到 K_DB。绘制 P1-DB 箭头 (标准偏移)
        // 箭头标记在 K_Geo_Index (即第一次 P1 突破的 K 线)
        BearishSignalBuffer[K_Geo_Index] = High[K_Geo_Index] + 20 * Point(); 
        return; // 找到次高级别信号，立即退出函数
    }

    // 3. 最终退出: 仅 IB 突破发生 (线已绘制，无箭头) 或 循环耗尽。
    return;
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