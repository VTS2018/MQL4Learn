//+------------------------------------------------------------------+
//|                                     KTarget_SL_Test_Bot.mq4      |
//|                  KTarget_Finder5 SL/Reference Buffer 读取测试 EA |
//+------------------------------------------------------------------+
#property version "1.00"
#property strict
#property description "用于测试 KTarget_Finder5 指标 BullishTargetBuffer(0) 和 BearishTargetBuffer(1) 的绝对止损价是否正确传输。"
#include <K_Data.mqh>


//+------------------------------------------------------------------+
// --- Bot Core Settings ---
input bool   EA_Master_Switch       = true;     // 核心总开关：设置为 false 时，EA 不执行任何操作
//+------------------------------------------------------------------+
// --- 外部输入参数 (请确保与您的 KTarget_Finder5.mq4 中的参数匹配) ---
// ‼️ 重要: 您的指标必须有一个名为 Is_EA_Mode 的 bool 类型外部输入参数 ‼️
input string IndicatorName          = "KTarget_Finder5";

//+------------------------------------------------------------------+
// 对应 KTarget_Finder5.mq4 的输入参数
input bool     Indi_Is_EA_Mode        = true;  // 必须设置为 TRUE，以触发指标写入 SL 价格

input bool     Indi_Smart_Tuning      = true;  // Smart_Tuning_Enabled

input int      Indi_Scan_Range        = 500;   // Scan_Range
input int      Indi_Lookahead_Bottom  = 20;    // Lookahead_Bottom
input int      Indi_Lookback_Bottom   = 20;    // Lookback_Bottom
input int      Indi_Lookahead_Top     = 20;    // Lookahead_Top
input int      Indi_Lookback_Top      = 20;    // Lookback_Top

input int      Indi_Max_Signal_Look   = 20;    // Max_Signal_Lookforward
input int      Indi_DB_Threshold      = 3;     // DB_Threshold_Candles
input int      Indi_LLHH_Candles      = 3;     // FindAbsoluteLowIndex
input int      Indi_Timer_Interval_Seconds = 5; // OnTimer 触发间隔 (秒)
input bool     Indi_DrawFibonacci     = false;  // Is_DrawFibonacciLines
//+------------------------------------------------------------------+

// --- 全局变量 ---
datetime g_last_bar_time = 0;

input int    Indi_LastScan_Range      = 100;      // 扫描最近多少根 K 线 (Bot 1.0 逻辑)

KBarSignal GetIndicatorBarData(int shift);

//+------------------------------------------------------------------+
//| 自定义指标信号读取辅助函数 (GetIndicatorSignal)                   |
//+------------------------------------------------------------------+
double GetIndicatorSignal(int buffer_index, int shift)
{
   // Print("--->[KTarget_Test_Bot.mq4:40]: _Symbol: ", _Symbol);
   // Print("--->[KTarget_Test_Bot.mq4:41]: _Period: ", _Period);

   // iCustom 必须按照指标的输入参数顺序传递
   return iCustom(
       _Symbol,
       _Period,
       IndicatorName,

       // --- 传递 KTarget_Finder5 的所有输入参数 ---
       Indi_Is_EA_Mode,
       Indi_Smart_Tuning,
       Indi_Scan_Range,
       Indi_Lookahead_Bottom,
       Indi_Lookback_Bottom,
       Indi_Lookahead_Top,
       Indi_Lookback_Top,
       Indi_Max_Signal_Look,
       Indi_DB_Threshold,
       Indi_LLHH_Candles,
       Indi_Timer_Interval_Seconds,
       Indi_DrawFibonacci,
       // ... (在这里添加您指标所需的其他关键参数) ...

       // --- 缓冲区和 K 线位移 ---
       buffer_index,
       shift);
}

//+------------------------------------------------------------------+
//| Expert Tick 函数 (核心测试逻辑)                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   // 🚨 1. 全局开关控制 🚨
   if (!EA_Master_Switch)
   {
      // 可以在这里添加一个可选的日志，但频繁打印会影响性能
      // Print("EA Master Switch is OFF. Operations suspended.");
      return; // 开关未启用，立即退出 OnTick，不执行任何逻辑。
   }

    // --- 1. 新 K 线检测 (仅在新 K 线收盘时执行读取) ---
    if(Time[0] == g_last_bar_time) return; 
    g_last_bar_time = Time[0]; 

    /*
    // --- 2. 读取 SL 缓冲区 (shift=1, 已收盘 K 线) ---
    double bullish_sl_price = GetIndicatorSignal(0, 1); // Buffer 0 (BullishTargetBuffer)
    Print("--->[KTarget_Test_Bot.mq4:80]: bullish_sl_price: ", bullish_sl_price);

    double bearish_sl_price = GetIndicatorSignal(1, 1); // Buffer 1 (BearishTargetBuffer)
    Print("--->[KTarget_Test_Bot.mq4:83]: bearish_sl_price: ", bearish_sl_price);

    Print("--->[KTarget_Test_Bot.mq4:90]: EMPTY_VALUE: ", (double)EMPTY_VALUE);
    
    // --- 3. 打印结果到日志 ---
    string log_message = "新 K 线 @ " + TimeToString(Time[1], TIME_DATE|TIME_SECONDS);
    bool signal_found = false;
    
    if (bullish_sl_price != (double)EMPTY_VALUE && bullish_sl_price != 0)
    {
        log_message += " | 看涨 SL (Buffer 0): " + DoubleToString(bullish_sl_price, _Digits);
        signal_found = true;
    }
    
    if (bearish_sl_price != (double)EMPTY_VALUE && bearish_sl_price != 0)
    {
        log_message += " | 看跌 SL (Buffer 1): " + DoubleToString(bearish_sl_price, _Digits);
        signal_found = true;
    }

    if (!signal_found)
    {
        log_message += " | 未侦测到 SL 价格。";
    }
    
    Print(log_message);
    */

    // --- 1. 🚨 扫描循环：寻找最新的有效信号 (Bot 1.0 模式) 🚨
    for (int shift = 1; shift <= Indi_LastScan_Range; shift++)
    {
       // A. 批量读取所有缓冲区数据
       // 🚨 集中获取所有信号数据和 SL 价格 🚨
       KBarSignal last_bar_data = GetIndicatorBarData(shift); // 获取 shift=1 (已收盘 K 线) 的数据

       // B. 检查信号质量/存在性 (使用 Buffer 2/3 - ReferencePrice)
       // 注意：现在 Buffer 2/3 是信号质量代码 (3.0/2.0/1.0)
       bool bullish_signal_exists = (last_bar_data.BullishReferencePrice != (double)EMPTY_VALUE && last_bar_data.BullishReferencePrice != 0.0);
       bool bearish_signal_exists = (last_bar_data.BearishReferencePrice != (double)EMPTY_VALUE && last_bar_data.BearishReferencePrice != 0.0);

       /*
      if (last_bar_data.BullishSignalPrice != (double)EMPTY_VALUE && last_bar_data.BullishSignalPrice != 0)
      {
         Print(">>> 侦测到看涨信号 @ ", Time[1]);
         // A. 止损价直接读取 Buffer 0
         double sl_price = last_bar_data.BullishTargetPrice;
         Print("---->[KTarget_Test_Bot.mq4:121]: sl_price: ", sl_price); // 能否读取止损价格呢？我猜测不一定
         Print("---->[KTarget_Test_Bot.mq4:121]: BullishSignalPrice: ", last_bar_data.BullishSignalPrice);
      }

      if (last_bar_data.BearishSignalPrice != (double)EMPTY_VALUE && last_bar_data.BearishSignalPrice != 0)
      {
         Print(">>> 侦测到看跌信号 @ ", Time[1]);
         double sl_price = last_bar_data.BearishTargetPrice;
         Print("---->[KTarget_Test_Bot.mq4:129]: sl_price: ", sl_price);
         Print("---->[KTarget_Test_Bot.mq4:129]: last_bar_data.BearishSignalPrice: ", last_bar_data.BearishSignalPrice);
      }
      */

       if (bullish_signal_exists || bearish_signal_exists)
       {
          // C. 找到第一个信号，打印结果并退出循环/函数
          string log_message = ">>> 侦测到信号 @ K线索引 shift=" + IntegerToString(shift) + " (时间: " + TimeToString(last_bar_data.OpenTime) + ") <<<";

          if (bullish_signal_exists)
          {
             // 同时验证 Buffer 0 是否也有效 (绝对 SL 价格)
             if (last_bar_data.BullishStopLossPrice != (double)EMPTY_VALUE && last_bar_data.BullishStopLossPrice != 0.0)
             {
                log_message += " | 看涨 SL (Buffer 0): " + DoubleToString(last_bar_data.BullishStopLossPrice, _Digits);
                log_message += " | 质量 (Buffer 2): " + DoubleToString(last_bar_data.BullishReferencePrice, 1);
             }
          }

          if (bearish_signal_exists)
          {
             // 同时验证 Buffer 1 是否也有效 (绝对 SL 价格)
             if (last_bar_data.BearishStopLossPrice != (double)EMPTY_VALUE && last_bar_data.BearishStopLossPrice != 0.0)
             {
                log_message += " | 看跌 SL (Buffer 1): " + DoubleToString(last_bar_data.BearishStopLossPrice, _Digits);
                log_message += " | 质量 (Buffer 3): " + DoubleToString(last_bar_data.BearishReferencePrice, 1);
             }
          }

          Print(log_message);

          // 找到信号后，我们停止扫描（假设只需要最新信号）
          return;
       }
    }

    // 如果循环结束仍未找到信号
    Print("新 K 线 @ ", TimeToString(Time[1]), "：在扫描范围内 (", Indi_Scan_Range, " 根 K 线) 未发现信号。");
}

//+------------------------------------------------------------------+
//| Expert 初始化/反初始化函数 (仅为调试目的)                        |
//+------------------------------------------------------------------+
int OnInit(){ Print("KTarget SL 测试 EA 启动。请检查日志输出。"); return(INIT_SUCCEEDED); }
void OnDeinit(const int reason){ Print("KTarget SL 测试 EA 停止。"); }

// ------------
// KTarget_FinderBot.mq4

//+------------------------------------------------------------------+
//| 批量获取 KTarget_Finder5 所有缓冲区数据                          |
//+------------------------------------------------------------------+
KBarSignal GetIndicatorBarData(int shift)
{
    KBarSignal data;
    
    // 依次调用 iCustom 获取所有 4 个缓冲区的数据 (4次 iCustom 调用)
    data.BullishStopLossPrice = GetIndicatorSignal(0, shift); // Buffer 0
    data.BearishStopLossPrice = GetIndicatorSignal(1, shift); // Buffer 1
    data.BullishReferencePrice = GetIndicatorSignal(2, shift); // Buffer 2
    data.BearishReferencePrice = GetIndicatorSignal(3, shift); // Buffer 3
    
    data.OpenTime = Time[shift];
    return data;
}
//+------------------------------------------------------------------+