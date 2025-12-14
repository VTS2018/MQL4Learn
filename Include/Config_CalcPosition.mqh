//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ 资金管理设置
//+------------------------------------------------------------------+
input string         __MONEY_MGMT__ = "--- 资金管理设置 ---";

input ENUM_POS_SIZE_MODE Position_Mode = POS_FIXED_LOT;    // 仓位计算模式选择
input double   FixedLot       = 0.01;        // 固定交易手数
input int      Slippage       = 3;           // 允许滑点 (点)
input double   RewardRatio    = 1.0;         // 盈亏比 (TP = SL距离 * Ratio)

input ENUM_RISK_MODE Risk_Mode      = RISK_FIXED_MONEY; // 风险模式
input double         Risk_Value     = 10.0;            // 风险值 ($100 或 3%)
