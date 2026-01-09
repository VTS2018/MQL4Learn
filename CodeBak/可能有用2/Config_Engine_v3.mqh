//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

// ==========================================================================
// 🎛️ [步骤 2.2] 引擎控制台 (Engine Control)
// ==========================================================================
input string   __ENGINE_SETTINGS__    = "=== 核心引擎设置 ===";
input bool     Enable_V3_Engine       = true;       // [总开关] True=启用智能内核; False=使用原始逻辑
input bool     Enable_Active_Exit     = true;       // [风控] 是否启用主动离场 (假突破/时间止损)
input bool     Show_Debug_Marks       = true;       // [调试] 影子模式：仅画叉不平仓 (建议初期开启)

// v3 策略参数
input ENUM_SIGNAL_GRADE Min_Trade_Grade = GRADE_B;  // 最低开单评级 (建议 B 或 A)
input double   Min_Space_Factor       = 0.8;        // 最小空间因子 (ATR倍数)

// 主动风控参数 (之前设计的)
input bool     Use_P1_Break_Exit      = true;       // 跌回 P1 离场
input int      P1_Buffer_Mode         = 1;          // 0=点数, 1=ATR
input double   P1_Tolerance           = 0.5;        // 容忍阈值
input int      P1_Confirm_Bars        = 1;          // 确认K线数
input int      Max_Stagnant_Bars      = 12;         // 时间止损: 多少根K线滞涨
input double   Time_Exit_Min_Profit   = 100;        // 利润保护点数
input bool     Allow_Reentry          = true;       // 允许回头草
input int      Reentry_Cooldown       = 5;          // 冷却期

