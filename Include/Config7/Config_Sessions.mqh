//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 🌍 [新增] 市场时段可视化 (Market Sessions)
//+------------------------------------------------------------------+
input string   __SESSION_SET__      = "=== 市场时段 (Sessions) ===";
input bool     Show_Sessions        = true;  // [开关] 显示市场时段色块
input int      Server_Time_Offset   = 3;     // [重要] 平台时区 (夏令时填3, 冬令时填2)
input int      Session_Lookback     = 5;     // [范围] 显示过去几天的时段

// 时段颜色配置 (推荐使用极淡的背景色)
// input color    Color_Sydney         = clrNONE;        // 悉尼 (通常忽略或合并到亚盘)
// input color    Color_Tokyo          = C'230,240,255'; // 亚盘 (淡蓝) - 对应北京上午
// input color    Color_London         = C'235,255,235'; // 欧盘 (淡绿) - 对应北京下午
// input color    Color_NewYork        = C'255,235,235'; // 美盘 (淡红) - 对应北京晚上

input color    Color_Sydney         = clrNONE;        // 悉尼 (不显示)
input color    Color_Tokyo          = clrSteelBlue;   // 亚盘 (深蓝钢色) - 适合虚线
input color    Color_London         = clrSeaGreen;    // 欧盘 (海绿色)   - 适合虚线
input color    Color_NewYork        = clrIndianRed;   // 美盘 (印度红)   - 适合虚线
