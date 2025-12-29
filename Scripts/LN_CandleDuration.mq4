//+------------------------------------------------------------------+
//|                                                CandleDuration.mq4|
//|                                  Copyright 2025, MQL Learner.    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MQL Learner."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// --- 外部参数 (让用户可以调整需要查看的 K 线数量) ---
extern int Scan_Count = 20; // 要检查的 K 线数量

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- 声明和初始化变量 ---
    int count = Scan_Count; // 使用外部参数定义的 K 线数量
    int total_bars = Bars;  // 图表上的 K 线总数
    
    // 确保有足够的 K 线进行检查
    if (total_bars < count + 1) // +1 是因为 Time[i+1] 需要存在
    {
        Print("错误: 图表上的K线数量不足 (总数:", total_bars, ")，无法检查最近 ", count, " 根K线。");
        return; // 退出脚本
    }

    Print("==================== K线时间持续时间分析 ====================");
    Print("当前货币对: ", Symbol(), "，时间周期: ", Period());
    Print("-------------------------------------------------------------");
    
//--- 遍历 K 线数组 (从最近的已收盘 K 线 [1] 开始) ---
    // i=1 是最近收盘 K 线，i < count + 1 是为了检查到第 count 根 K 线
    for (int i = 1; i <= count; i++)
    {
        // K 线 Time[i] 是该 K 线的开盘时间
        datetime current_open_time = Time[i];
        
        // K 线 Time[i+1] 是前一根（更旧的）K 线的开盘时间
        datetime previous_open_time = Time[i+1];
        
        // 计算持续时间 (单位: 秒)
        // 持续时间 = 较新的时间 - 较旧的时间
        // FIX: 使用 (int) 强制类型转换来消除 "possible loss of data" 警告
        int duration_seconds = (int)(current_open_time - previous_open_time); 
        
        // 将开盘时间转换为可读的字符串
        // TIME_DATE|TIME_SECONDS 用于显示完整的日期和时间
        string time_str = TimeToString(current_open_time, TIME_DATE|TIME_SECONDS);
        
        // --- 输出结果 ---
        Print("K线 [", i, "] (开盘时间: ", time_str, ") | 持续时间: ", duration_seconds, " 秒");
        
        // 额外信息：将秒数转换为分钟和小时
        double duration_minutes = duration_seconds / 60.0;
        double duration_hours = duration_seconds / 3600.0;
        
        Print("   -> 分钟: ", DoubleToString(duration_minutes, 2), " | 小时: ", DoubleToString(duration_hours, 2));
    }
    
    Print("=============================================================");
    
//--- 保持在图表上显示当前的实时时间 ---
    Comment("当前 MT4/GMT 时间: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), 
            "\n最近K线时间已分析。");
  }
//+------------------------------------------------------------------+