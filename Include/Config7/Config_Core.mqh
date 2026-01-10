//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ 所有的指标打印日志行为 只能在!Is_EA_Mode 模式下运行
//+------------------------------------------------------------------+
/*
extern bool Is_EA_Mode = false; // 是否以EA后台模式运行 (关闭所有绘图和对象创建) true：EA静默模式；false：绘图模式
extern bool Smart_Tuning_Enabled = true;        // 【新增】启动智能周期调优

// --- 外部可调参数 (输入) ---
extern int Scan_Range = 500;              // 总扫描范围：向后查找 N 根 K 线

// --- 看涨 K-Target (底部) 锚点参数 ---
extern int Lookahead_Bottom = 20;         // 看涨信号右侧检查周期 (未来/较新的K线)
extern int Lookback_Bottom = 20;          // 看涨信号左侧检查周期 (历史/较旧的K线)

// --- 看跌 K-Target (顶部) 锚点参数 ---
extern int Lookahead_Top = 20;            // 看跌信号右侧检查周期
extern int Lookback_Top = 20;             // 看跌信号左侧检查周期

// --- 信号确认参数 ---
extern int Max_Signal_Lookforward = 20;    // 最大信号确认前瞻 K 线数量 (P1 突破检查范围)
extern int DB_Threshold_Candles = 3;       // DB 突破的最小 K 线数量 (N >= 3 为 DB, N < 3 为 IB)
extern int Look_LLHH_Candles = 3;          // 寻找绝对最低和最高价的K线范围查找数量(FindAbsoluteLowIndex)

extern int Find_Target_Model = 1;          // 锚点查找方式 1 是默认查找；2 是更加严格的查找
*/

//+------------------------------------------------------------------+
//| ✅ All indicator logging behaviors only run in !Is_EA_Mode
//+------------------------------------------------------------------+
extern bool Is_EA_Mode = false;           // EA Silent Mode (True=No GFX)
extern bool Smart_Tuning_Enabled = true;  // Enable Smart Tuning

// --- External Adjustable Parameters (Inputs) ---
extern int Scan_Range = 500;              // History Scan Range

// --- Bullish K-Target (Bottom) Anchor Parameters ---
extern int Lookahead_Bottom = 20;         // Bull: Right Check
extern int Lookback_Bottom = 20;          // Bull: Left Check

// --- Bearish K-Target (Top) Anchor Parameters ---
extern int Lookahead_Top = 20;            // Bear: Right Check
extern int Lookback_Top = 20;             // Bear: Left Check

// --- Signal Confirmation Parameters ---
extern int Max_Signal_Lookforward = 20;   // Signal Confirm Range
extern int DB_Threshold_Candles = 3;      // DB Min Bars (>=3)
extern int Look_LLHH_Candles = 3;         // Abs. High/Low Scan
extern int Find_Target_Model = 1;         // Search Mode (1=Std, 2=Strict)