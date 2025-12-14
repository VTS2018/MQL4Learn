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

//+------------------------------------------------------------------+
//| 初始化
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 初始化斐波那契级别 (在 OnInit 中调用)
//| 将外部输入字符串解析并填充到全局数组 g_FiboExhaustionLevels
//+------------------------------------------------------------------+
void InitializeFiboLevels(string zone1, string zone2, string zone3, string zone4)
{
   g_FiboZonesCount = 0; // 重置计数器

   // 尝试解析 Zone 1
   if (ParseFiboZone(zone1, g_FiboExhaustionLevels[g_FiboZonesCount][0], g_FiboExhaustionLevels[g_FiboZonesCount][1]))
      g_FiboZonesCount++;

   // 尝试解析 Zone 2
   if (g_FiboZonesCount < MAX_FIBO_ZONES && ParseFiboZone(zone2, g_FiboExhaustionLevels[g_FiboZonesCount][0], g_FiboExhaustionLevels[g_FiboZonesCount][1]))
      g_FiboZonesCount++;

   // 尝试解析 Zone 3
   if (g_FiboZonesCount < MAX_FIBO_ZONES && ParseFiboZone(zone3, g_FiboExhaustionLevels[g_FiboZonesCount][0], g_FiboExhaustionLevels[g_FiboZonesCount][1]))
      g_FiboZonesCount++;

   if (g_FiboZonesCount < MAX_FIBO_ZONES && ParseFiboZone(zone4, g_FiboExhaustionLevels[g_FiboZonesCount][0], g_FiboExhaustionLevels[g_FiboZonesCount][1]))
      g_FiboZonesCount++;

   // 2.0
   // Print("斐波那契上下文区域初始化完成。共加载 ", g_FiboZonesCount, " 个区域。");
   // for (int z = 0; z < g_FiboZonesCount; z++)
   // {
   //    double level1 = g_FiboExhaustionLevels[z][0];
   //    Print("--->[KTarget_FinderBot.mq4:2294]: level1: ", level1);
   //    double level2 = g_FiboExhaustionLevels[z][1];
   //    Print("--->[KTarget_FinderBot.mq4:2296]: level2: ", level2);
   // }

   // 循环遍历方式 1.0
   // int rows = ArrayRange(g_FiboExhaustionLevels, 0);    // 获取行数 (3)
   // Print("--->[KTarget_FinderBot.mq4:2286]: rows: ", rows);

   // int cols = ArrayRange(g_FiboExhaustionLevels, 1); // 获取当前行的列数 (4)
   // Print("--->[KTarget_FinderBot.mq4:2289]: cols: ", cols);

   // for (int i = 0; i < rows; i++)
   // {
   //    // 遍历每一行
   //    for (int j = 0; j < cols; j++)
   //    {
   //       // 遍历每一列
   //       // 访问元素
   //       Print("Element at [", i, "][", j, "] is: ", g_FiboExhaustionLevels[i][j]);
   //    }
   // }
}