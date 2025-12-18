//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

// 定义仓位计算模式
enum ENUM_POS_SIZE_MODE
{
   POS_FIXED_LOT,       // 模式 A: 固定手数 (例如 0.01 手)
   POS_RISK_BASED       // 模式 B: 以损定仓 (根据止损距离计算)
};

// 定义风险计算模式
enum ENUM_RISK_MODE
{
   RISK_FIXED_MONEY,    // 单笔固定止损金额 (例如: $100)
   RISK_PERCENTAGE      // 单笔账户余额百分比 (例如: 3%)
};

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
