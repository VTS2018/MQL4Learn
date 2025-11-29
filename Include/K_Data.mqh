//+------------------------------------------------------------------+
//|                                                       K_Data.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
//+------------------------------------------------------------------+
// #property copyright "Copyright 2025, YourName"
// #property link      "https://mql5.com"
// #property strict

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2025

//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+

// #import "user32.dll"
//    int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//    int      ExpertRecalculate(int wParam,int lParam);
// #import

//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+

// #import "stdlib.ex5"
//    string ErrorDescription(int error_code);
// #import

//+------------------------------------------------------------------+

// --- 辅助结构体：用于存储解析结果 ---
struct ParsedRectInfo
{
    bool     is_bullish; // 看涨 (true) / 看跌 (false)
    datetime P1_time;    // P1 K线开盘时间
    datetime P2_time;    // P2 K线开盘时间
};
//-----------------------------------
// 在 K_Data.mqh 或 K_Utils.mqh 中定义，此处仅用于示例
struct FiboZone {
    double level1; // 区域底部级别
    double level2; // 区域顶部级别
};

// 看涨斐波那契高亮区域
const FiboZone BULLISH_HIGHLIGHT_ZONES[] = {
    {1.618, 1.880},
    {2.618, 2.880},
    {4.236, 4.880},
    {5.000, 6.000}
};
// 看跌斐波那契高亮区域 (需要您提供，这里使用示例值)
const FiboZone BEARISH_HIGHLIGHT_ZONES[] = {
    {1.618, 1.880},
    {2.618, 2.880},
    {4.236, 4.880},
    {5.000, 6.000}
};
// 默认颜色 (用于所有其他周期) 矩形颜色和透明度
#define HIGHLIGHT_COLOR_B clrSeaGreen
#define HIGHLIGHT_COLOR_S clrIndianRed
#define HIGHLIGHT_ALPHA   50 // 透明度 (0-255，50为浅色)

// 日周期 (D1) 特有颜色：选择高亮的、对比度强的颜色
#define HIGHLIGHT_COLOR_D1_B clrGold          // 看涨使用金色 (高对比度)
#define HIGHLIGHT_COLOR_D1_S clrOrangeRed      // 看跌使用醒目的红橙色 (高对比度)

// 4H 周期 (H4) 特有颜色
#define HIGHLIGHT_COLOR_H4_B clrYellowGreen   // 看涨使用黄绿色
#define HIGHLIGHT_COLOR_H4_S clrDarkOrange    // 看跌使用深橙色

// 1H 周期 (H1) 特有颜色
#define HIGHLIGHT_COLOR_H1_B clrLightBlue     // 看涨使用浅蓝色
#define HIGHLIGHT_COLOR_H1_S clrHotPink       // 看跌使用亮粉色
//------------------

// 定义用于智能调优的参数结构体
struct TuningParameters
{
    int Scan_Range;
    int Lookahead_Bottom;
    int Lookback_Bottom;
    int Lookahead_Top;
    int Lookback_Top;
    int Max_Signal_Lookforward;
    int Look_LLHH_Candles;
};

//----------------------
//+------------------------------------------------------------------+
//| 批量 K 线信号数据结构体 (Indicator Data Structure)                   |
//+------------------------------------------------------------------+
struct KBarSignal
{
    // Buffer 0: 看涨锚点价格 (SL 参照)
    double BullishStopLossPrice;
    
    // Buffer 1: 看跌锚点价格 (SL 参照)
    double BearishStopLossPrice;
    
    // Buffer 2: 最终看涨信号价格 (开仓触发)
    double BullishReferencePrice;
    
    // Buffer 3: 最终看跌信号价格 (开仓触发)
    double BearishReferencePrice;

    datetime OpenTime;
};