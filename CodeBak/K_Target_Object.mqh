//+------------------------------------------------------------------+
//| K-Target Signal Data Structure (OOP 模拟)                        |
//| 文件名: K_Target_Object.mqh                                      |
//+------------------------------------------------------------------+
#property strict

// K-Target 信号所包含的所有信息，以结构体形式封装
struct KTarget_Signal
{
    // 1. 锚点数据 (Anchor Data)
    int      anchor_index;          // K-Target 锚点 K 线的索引 (例如 K[i])
    datetime anchor_time;           // 锚点 K 线的开始时间
    
    // 2. 突破数据 (Breakout Data)
    int      breakout_index;        // 突破发生的 K 线的索引 (例如 K[j])
    int      breakout_candle_count; // N 值 (突破K线到锚点的K线数)
    
    // 3. 价格水平 (Price Levels)
    double   P1_price;              // P1 基准价格 (锚点开盘价/收盘价)
    double   P2_price;              // P2 基准价格
    
    // [V1.33 O(1) 查找] 用于 P2 查找的绝对最低/最高 K 线索引
    int      true_anchor_index;     
    
    // 4. 信号分类 & 状态
    bool     is_bullish;            // 是否看涨信号 (true) / 看跌信号 (false)
    bool     is_confirmed;          // 信号是否最终确认 (突破成功)
    string   classification;        // IB / DB 分类 ("IB" or "DB")
    string   object_name_prefix;    // 用于绘图对象的唯一名称前缀
};

// --- OOP 模拟函数原型 (在 K_Target_Core.mqh 和 K_Target_Drawings.mqh 中实现) ---
// 核心处理函数 (Core Logic)
//bool KTarget_ProcessSignal(int anchor_index, KTarget_Signal& signal_obj, int total_bars, double DB_Threshold_Candles);

// 绘图函数 (Drawing Logic)
//void KTarget_Draw(const KTarget_Signal& signal_obj, double DB_Threshold_Candles);