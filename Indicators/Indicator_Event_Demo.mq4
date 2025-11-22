//+------------------------------------------------------------------+
//|                        Indicator_Event_Demo.mq4                  |
//|                    MQL4 事件与运行机制可视化演示指标             |
//+------------------------------------------------------------------+
#property copyright "Expert MQL4 Developer"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0 // 不需要绘图缓冲区

//--- 外部参数 ---
extern int Timer_Interval_Seconds = 5; // OnTimer 触发间隔 (秒)

//--- 全局变量和静态标志 ---
static datetime last_bar_time = 0;   // 记录上次计算时的 K 线时间
static datetime last_tick_time = 0;  // 记录上次 OnCalculate 触发的时间 (用于区分Tick)
static int on_calculate_count = 0;   // OnCalculate 触发次数计数
static bool is_initial_load = true;  // 标记是否为首次历史数据加载

// [V1.01 FIX] 新增两个字符串变量用于 OnCalculate 和 OnTimer 之间的通信
static string on_calc_output_segment = ""; // 存储 OnCalculate 的计算结果部分
static string on_timer_output_segment = ""; // 存储 OnTimer 的输出结果部分

//+------------------------------------------------------------------+
//| 1. 初始化函数 (OnInit)                                           |
//+------------------------------------------------------------------+
int OnInit()
{
    // 1. 设置指标简称
    IndicatorShortName("MQL4 事件演示");

    // 2. 启动定时器：用于演示 OnTimer 函数的独立运行
    EventSetTimer(Timer_Interval_Seconds);

    // 3. 在图表上输出初始化信息 (使用 Comment 替代 Print 以获得图表反馈)
    string init_message = 
        "*** INDICATOR INITIALIZED ***\n" +
        "Function: OnInit() executed.\n" +
        "Time: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n" +
        "Timer set to: " + IntegerToString(Timer_Interval_Seconds) + " seconds.";

    Comment(init_message);
    Print("---->[Indicator_Event_Demo.mq4:44]: init_message: ", init_message);

    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| 2. 卸载函数 (OnDeinit)                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // 停止定时器，避免内存泄漏
    EventKillTimer();
    
    // 清除图表上的 Comment 输出
    Comment(""); 
    
    // 可以在这里 Print 一条信息到日志，确认 OnDeinit 被执行
    Print("Indicator_Event_Demo: OnDeinit executed. Reason: ", reason);
}
//+------------------------------------------------------------------+
//| 3. 核心计算函数 (OnCalculate)                                    |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // --- 逻辑判断与计数 ---
    string trigger_type = "UNKNOWN";
    datetime current_time = TimeCurrent();
    on_calculate_count++;
    
    // 1. 判断是否是历史数据加载
    if (prev_calculated == 0 || is_initial_load)
    {
        trigger_type = "History Load/Initial Run";
        is_initial_load = false;
    }
    // 2. 判断是否是新 K 线触发
    else if (time[0] > last_bar_time) 
    {
        trigger_type = "NEW BAR (收线触发)";
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

    /*
    // --- 构建输出信息 ---
    string output_message = 
        "*** OnCalculate Status ***\n" +
        "Count: " + IntegerToString(on_calculate_count) + "\n" +
        "Trigger: " + trigger_type + "\n" +
        "Trigger Time: " + TimeToString(current_time, TIME_SECONDS) + "\n" +
        "--------------------------------------\n" +
        "K[0] Start Time: " + TimeToString(time[0], TIME_MINUTES) + "\n" +
        "Current Bid: " + DoubleToString(Bid, Digits) + "\n" +
        "Current Ask: " + DoubleToString(Ask, Digits) + "\n" +
        "K-Line Total: " + IntegerToString(rates_total) + "\n" +
        "Last Calculated: " + IntegerToString(prev_calculated) + "\n" +
        "--------------------------------------\n" +
        "**OnTimer Status** (See below)";
        */
        
    // 4. 更新全局静态变量
    last_bar_time = time[0];
    last_tick_time = current_time;

    /*
    // 5. 将 OnCalculate 的结果和 OnTimer 的结果合并显示
    string timer_message = (string)ChartGetInteger(0, CHART_COMMENT);
    // 移除 OnInit 消息头，保留 OnTimer 消息体
    int start_pos = StringFind(timer_message, "**OnTimer Status**"); 
    if (start_pos != -1)
    {
        timer_message = StringSubstr(timer_message, start_pos);
        output_message = output_message + "\n" + timer_message;
    }
    
    Comment(output_message);
    */
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

    /*
    // 尝试获取 OnCalculate 输出的 Comment，并替换其中的 OnTimer 状态部分
    string current_comment = (string)ChartGetInteger(0, CHART_COMMENT);
    
    // 找到并替换 OnTimer 部分
    int start_pos = StringFind(current_comment, "**OnTimer Status**");
    if (start_pos != -1)
    {
        string new_comment = StringSubstr(current_comment, 0, start_pos) + timer_output;
        Comment(new_comment);
    }
    else
    {
        // 如果 OnCalculate 还没运行，直接显示 OnTimer 消息
        Comment(timer_output);
    }
    */
    
    // 1. 更新 OnTimer 的输出段，并存储到全局变量
    on_timer_output_segment = timer_output;
    
    // 2. 将 OnCalculate 的最新结果和 OnTimer 的结果合并显示
    // 即使 OnCalculate 触发频繁，我们总是用最新的两段信息进行组合
    Comment(on_calc_output_segment + "\n" + on_timer_output_segment);
}
//+------------------------------------------------------------------+
//| 5. 图表事件函数 (OnChartEvent) - 指标中通常不处理鼠标事件       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // **注意：在 MQL4 指标中，该函数默认不捕获鼠标双击等用户操作事件**
    // 仅用于演示它确实是 MQL4 运行时的一部分
    if (id == CHARTEVENT_KEYDOWN || id == CHARTEVENT_OBJECT_CREATE)
    {
        string event_name = "Unknown Event";
        if (id == CHARTEVENT_KEYDOWN) event_name = "Keyboard Event";
        if (id == CHARTEVENT_OBJECT_CREATE) event_name = "Object Create Event";
        
        // 由于Comment被OnCalculate和OnTimer频繁更新，我们使用Print到日志来展示OnChartEvent
        Print("Indicator_Event_Demo: OnChartEvent Triggered! Type: ", event_name, ", ID: ", id);
    }
}

//+------------------------------------------------------------------+