//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 🌍 [新增] 市场时段可视化 (Market Sessions)
//+------------------------------------------------------------------+
input string   __Session_Settings__ = "=== 市场时段 (Sessions) ===";
input bool     Show_Sessions        = false;  // [开关] 显示市场时段色块
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

/*
//+------------------------------------------------------------------+
//| ✅ Market Session Visualization (Optional)
//+------------------------------------------------------------------+
input string   __Session_Settings__ = "=== Market Sessions ===";
input bool     Show_Sessions        = false;      // Show Market Sessions
input int      Session_Lookback     = 5;          // Session Days Lookback
input int      Server_Time_Offset   = 3;          // Server Time Offset (Hrs)

// --- Session 1: Asia / Tokyo ---
input string   Session1_Name        = "Asia";     // Session 1 Name
input string   Session1_Start       = "00:00";    // Sess 1 Start (HH:MM)
input string   Session1_End         = "09:00";    // Sess 1 End (HH:MM)
input color    Session1_Color       = clrBisque;  // Sess 1 Color

// --- Session 2: London / Europe ---
input string   Session2_Name        = "London";   // Session 2 Name
input string   Session2_Start       = "08:00";    // Sess 2 Start (HH:MM)
input string   Session2_End         = "17:00";    // Sess 2 End (HH:MM)
input color    Session2_Color       = clrLavender;// Sess 2 Color

// --- Session 3: New York / US ---
input string   Session3_Name        = "NewYork";  // Session 3 Name
input string   Session3_Start       = "13:00";    // Sess 3 Start (HH:MM)
input string   Session3_End         = "22:00";    // Sess 3 End (HH:MM)
input color    Session3_Color       = clrMistyRose;// Sess 3 Color
*/