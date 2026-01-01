//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//====================================================================
//| ✅ 指标参数映射 (Indicator Inputs)
//| 🚨 注意：为了让 iCustom 正确工作，这里的参数必须与指标的 extern 参数完全一致且顺序相同
//====================================================================
input string   __INDICATOR_SETTINGS__ = "--- Indicator Settings ---";
input string   IndicatorName          = "KTarget_Finder_MT7"; // 指标文件名(不带后缀)

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

// input int      Indi_Timer_Interval_Seconds = 5; // OnTimer 触发间隔 (秒)
// input bool     Indi_DrawFibonacci     = false;  // Is_DrawFibonacciLines