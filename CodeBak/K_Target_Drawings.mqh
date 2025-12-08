//+------------------------------------------------------------------+
//| K-Target Drawings Logic                                          |
//| 文件名: K_Target_Drawings.mqh                                    |
//| 包含所有绘图函数，并添加 Enable_Drawing 开关                     |
//+------------------------------------------------------------------+
#include <K_Target_Object.mqh>
#property strict

// --- 外部参数原型 (需要从主文件导入) ---
extern bool Enable_Drawing;

// ... (定义 ARROW_CODE_UP, ARROW_CODE_DOWN, ARROW_CODE_SIGNAL_UP/DOWN 宏) ...

//========================================================================
// DrawTargetBottom: 绘图函数，用向上箭头标记 K-Target Bottom
//========================================================================
void DrawTargetBottom(int target_index, double &buffer[])
{
    if (!Enable_Drawing) return; // [V1.29 NEW] 禁用绘图时立即退出
    buffer[target_index] = Low[target_index] - 10 * Point();
}

// ... (此处省略 DrawTargetTop，逻辑类似) ...


//========================================================================
// DrawSecondBaseline: 绘制第二基准价格线 (P2)
//========================================================================
void DrawSecondBaseline(int target_index, int breakout_index, double P2_price, bool is_bullish)
{
    if (!Enable_Drawing) return; // [V1.29 NEW] 禁用绘图时立即退出
    
    // ... (从 5.txt 抽取 DrawSecondBaseline 的完整绘图逻辑) ...
    // ... (保留 ObjectCreate, ObjectSetInteger 等所有代码) ...
    // ... (注意使用 is_bullish 区分颜色) ...
}

//========================================================================
// DrawBreakoutTrendLine: 绘制突破趋势线 (P1)
//========================================================================
void DrawBreakoutTrendLine(int target_index, int breakout_index, bool is_bullish, int breakout_candle_count, double P2_price)
{
    if (!Enable_Drawing) return; // [V1.29 NEW] 禁用绘图时立即退出
    
    // ... (从 5.txt 抽取 DrawBreakoutTrendLine 的完整绘图逻辑) ...
    // ... (包含 IB/DB 分类和 ObjectCreate/ObjectSetInteger/ObjectSetDouble 等所有代码) ...
    
    // [V1.22 NEW] 绘制 P2 辅助线 (如果 Enable_Drawing 为 true，则继续绘制 P2)
    DrawSecondBaseline(target_index, breakout_index, P2_price, is_bullish);
}


//========================================================================
// KTarget_Draw: OOP 绘图封装 (调用所有绘图函数)
//========================================================================
void KTarget_Draw(const KTarget_Signal& signal_obj, double DB_Threshold_Candles)
{
    if (!Enable_Drawing) return; // [V1.29 NEW] 禁用绘图时立即退出
    if (!signal_obj.is_confirmed) return; // 信号未确认，不绘制
    
    // 1. 绘制 K-Target 锚点箭头
    if (signal_obj.is_bullish)
    {
        // BullishTargetBuffer[signal_obj.anchor_index] = Low[signal_obj.anchor_index] - 10 * Point(); // 绘图缓冲区赋值
        DrawTargetBottom(signal_obj.anchor_index, BullishTargetBuffer);
    }
    // ... (添加看跌 DrawTargetTop 逻辑) ...
    
    // 2. 绘制突破箭头
    if (signal_obj.is_bullish)
    {
        // BullishSignalBuffer[signal_obj.breakout_index] = Low[signal_obj.breakout_index] - 20 * Point(); // 绘图缓冲区赋值
    }
    // ... (添加看跌 BearishSignalBuffer 逻辑) ...
    
    // 3. 绘制 P1 和 P2 水平线
    DrawBreakoutTrendLine(
        signal_obj.anchor_index, 
        signal_obj.breakout_index, 
        signal_obj.is_bullish, 
        signal_obj.breakout_candle_count, 
        signal_obj.P2_price
    );
}