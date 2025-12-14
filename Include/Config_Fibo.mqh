//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ L2: 趋势过滤器参数 用处不是很大 以后升级成 150 100 或者21EMA/8ema
//+------------------------------------------------------------------+
input string   __Separator_9__ = "--- Separator  9 ---";
input bool   Use_Trend_Filter    = false;   // 是否开启均线大趋势过滤
input int    Trend_MA_Period     = 200;    // 均线周期 (默认200，牛熊分界线)
input int    Trend_MA_Method     = MODE_EMA; // 均线类型: 0=SMA, 1=EMA, 2=SMMA, 3=LWMA

//+------------------------------------------------------------------+
//| ✅ 让斐波阻力/支撑区域的参数可以实现配置
//| 斐波那契上下文设置 (Fibonacci Context Inputs)                     
//| 如果需要更多区域，可以仿照此格式继续添加 Fibo_Zone_4, Fibo_Zone_5..
//+------------------------------------------------------------------+
input string   __FIBO_CONTEXT__    = "--- Fibo Exhaustion Levels ---";
input string   Fibo_Zone_1         = "1.618, 1.88";     // 斐波那契衰竭区 1 (格式: Level_A, Level_B)
input string   Fibo_Zone_2         = "2.618, 2.88";     // 斐波那契衰竭区 2
input string   Fibo_Zone_3         = "4.236, 4.88";     // 斐波那契衰竭区 3
input string   Fibo_Zone_4         = "6.0, 7.0";        // 斐波那契衰竭区 4

// 定义全局存储空间和计数器
#define MAX_FIBO_ZONES 10 // 最大支持的斐波那契区域数量
double g_FiboExhaustionLevels[MAX_FIBO_ZONES][2]; // 全局数组用于存储解析结果
int    g_FiboZonesCount = 0;                     // 实际加载的区域数量

