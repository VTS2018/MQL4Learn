//+------------------------------------------------------------------+
//|                                                       K_Data.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 辅助结构体：用于存储解析结果                                      |
//+------------------------------------------------------------------+
struct ParsedRectInfo
{
    bool     is_bullish; // 看涨 (true) / 看跌 (false)
    datetime P1_time;    // P1 K线开盘时间
    datetime P2_time;    // P2 K线开盘时间
};

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

//+------------------------------------------------------------------+
//| 定义扩展矩形的颜色                                                |
//+------------------------------------------------------------------+
// 默认颜色 (用于所有其他周期) 矩形颜色和透明度
#define HIGHLIGHT_COLOR_B C'240,248,255'
#define HIGHLIGHT_COLOR_S C'240,248,255'
#define HIGHLIGHT_ALPHA   50 // 透明度 (0-255，50为浅色)

// 月周期
#define HIGHLIGHT_COLOR_MN1_B C'0,255,0'
#define HIGHLIGHT_COLOR_MN1_S C'0,255,0'

// 周周期
#define HIGHLIGHT_COLOR_W1_B C'255,255,0'
#define HIGHLIGHT_COLOR_W1_S C'135,206,250'

// 日周期 (D1) 特有颜色：选择高亮的、对比度强的颜色
#define HIGHLIGHT_COLOR_D1_B clrGold          // 看涨使用金色 (高对比度)
#define HIGHLIGHT_COLOR_D1_S C'64,224,208'    // 看跌使用醒目的红橙色 (高对比度)

// 4H 周期 (H4) 特有颜色
#define HIGHLIGHT_COLOR_H4_B clrYellowGreen   // 看涨使用黄绿色
#define HIGHLIGHT_COLOR_H4_S C'127,255,212'    // 看跌使用深橙色

// 1H 周期 (H1) 特有颜色
#define HIGHLIGHT_COLOR_H1_B clrLightBlue     // 看涨使用浅蓝色
#define HIGHLIGHT_COLOR_H1_S clrHotPink       // 看跌使用亮粉色

//+------------------------------------------------------------------+
//| 定义用于智能调优的参数结构体                                      |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| 批量 K 线信号数据结构体 (Indicator Data Structure)                |
//+------------------------------------------------------------------+
struct KBarSignal
{
    // Buffer 0: 最终看涨绝对止损价 (SL Price)
    double BullishStopLossPrice;
    
    // Buffer 1: 最终看跌绝对止损价 (SL Price)
    double BearishStopLossPrice;
    
    // Buffer 2: 最终看涨信号质量代码
    double BullishReferencePrice;
    
    // Buffer 3: 最终看跌信号质量代码
    double BearishReferencePrice;

    datetime OpenTime;

    // 我们可以增加一个字段来存储开仓价 (即信号K线的收盘价)
    // double SignalClosePrice; // 存储 Close[shift] 这里看看如何更加精确的获取
};

//+------------------------------------------------------------------+
//| 一个轻量级的结构体来存储所有合格的信号，用于后续的比较             |
//+------------------------------------------------------------------+
struct FilteredSignal
{
    int      shift;              // K线索引 (1, 2, 3...)
    datetime signal_time;        // 信号发生时间
    double   confirmation_close; // 信号确认K线的收盘价 (Close[shift])
    double   stop_loss;          // 信号的止损价
    int      type;               // 交易类型 (OP_BUY 或 OP_SELL)
};

/*
//+------------------------------------------------------------------+
//| 1. 定义信号等级枚举 (清晰的阶级划分)
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_GRADE
{
   GRADE_NONE = 0,      // 无信号
   GRADE_S    = 5,      // 完美级 (DB + CB + 空间大) - 重仓
   GRADE_A    = 4,      // 优秀级 (IB + CB + 空间大) - 标准仓
   GRADE_B    = 3,      // 良好级 (DB only + 空间大) - 以 P2 为目标
   GRADE_C    = 2,      // 普通级 (IB only + 空间大) - 激进短线
   GRADE_D    = 1,      // 鸡肋级 (空间太小，建议过滤)
   GRADE_F    = -1      // 垃圾级 (结构破环，如 P2 < P1)
};

//+------------------------------------------------------------------+
//| 2. 定义信号详情结构体 (承载所有决策数据)
//+------------------------------------------------------------------+
struct SignalQuality
{
   ENUM_SIGNAL_GRADE grade;   // 最终评级 (S/A/B/C/D)
   string description;        // 文字描述 (方便调试打印)
   
   bool is_IB;                // 是否为 Initial Break (快速)
   bool is_DB;                // 是否为 Dominant Break (稳健)
   bool is_CB;                // 是否突破了 P2 (强力)
   
   double space_factor;       // P2与P1的距离因子 (基于ATR)
   double reward_risk_ratio;  // 预估盈亏比 (P2-P1) / (P1-StopLoss)
};
*/