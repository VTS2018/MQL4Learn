//+------------------------------------------------------------------+
//|                          K-Target 突破信号识别指标 (XBreaking Signal) |
//+------------------------------------------------------------------+
/*
   功能描述:
   本指标基于价格行为分析中的 K-Target (目标 K 线) 和 IB/DB (内部突破/外部突破) 概念设计。
   它旨在自动识别图表上的关键水平，并在价格首次有效突破这些水平时发出信号，并绘制辅助趋势线。

   核心逻辑:
   1. K-Target 锚点识别: 
      - 识别出一段时间周期内 (由 Lookback/Lookahead 参数控制) 具有最低收盘价的阴线 (看涨锚点)，或最高收盘价的阳线 (看跌锚点)。
      - 这些锚点通常代表市场反转的起点或关键支撑/阻力位。
   2. 突破确认 (IB/DB): 
      - 在锚点K线出现后，检查随后 N 根 K 线内 (由 Max_Signal_Lookforward 控制) 是否发生突破。
      - 突破标准: K 线收盘价突破锚点 K 线的开盘价。
   3. 信号绘制: 
      - 在突破发生的 K 线上方/下方绘制最终信号箭头。
      - 绘制一条水平趋势线，始于锚点 K 线的开盘价，止于突破 K 线之后 2 根 K 线的位置，明确指示突破基准。

   趋势线属性:
   - 始点: K-Target 锚点 K 线的 Open 价格和时间。
   - 终点: 突破 K 线的时间 + 2 根 K 线 (保证长度适中，非射线)。

   技术要点:
   - 采用 OBJ_TREND 对象绘制突破基准线，并在指标卸载时自动清理，防止图表对象残留。
*/
//+------------------------------------------------------------------+
//|                          版本迭代日志 (Changelog)                  |
//+------------------------------------------------------------------+
/*
   日期           | 版本    | 描述
   ------------------------------------------------------------------
   2025.10.28     | v1.17   | 初始版本。集成 K-Target 锚点识别 (Bottom/Top) 和 IB/DB 突破确认逻辑。
   2025.11.05     | v1.18   | 修复 `OnDeinit` 函数签名，以消除 MQL4 编译器警告。添加图表对象清理机制。
   2025.11.12     | v1.19   | 优化趋势线终点设置逻辑。终点从突破 K 线时间开始，向右延伸 2 根 K 线，避免线条过长。
   2025.11.18     | v1.20   | 明确设置趋势线为非射线 (`OBJPROP_RAY = false`)，确保其为固定长度的线段。
   2025.11.18     | v1.21   | **[当前版本]** 修正了 `#property` 绘图属性中的重复设置：将 Plot 2 的 `indicator_width1` 修正为 `indicator_width2`。
   ------------------------------------------------------------------
*/
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MQL Developer"
#property link      "https://www.mql5.com"
#property version   "1.21" 
#property strict
#property indicator_chart_window // 绘制在主图表窗口
#property indicator_buffers 4 // 两个锚点 + 两个最终信号
#property indicator_plots   4 // 对应四个绘图

// --- 外部可调参数 (输入) ---
extern int Scan_Range = 500;              // 总扫描范围：向后查找 N 根 K 线

// --- 看涨 K-Target (底部) 锚点参数 ---
extern int Lookahead_Bottom = 20;         // 看涨信号右侧检查周期 (未来/较新的K线)
extern int Lookback_Bottom = 20;          // 看涨信号左侧检查周期 (历史/较旧的K线)

// --- 看跌 K-Target (顶部) 锚点参数 ---
extern int Lookahead_Top = 20;            // 看跌信号右侧检查周期
extern int Lookback_Top = 20;             // 看跌信号左侧检查周期

// --- 信号确认参数 ---
extern int Max_Signal_Lookforward = 20;    // 最大信号确认前瞻 K 线数量 (IB/DB 突破检查范围)

// --- 指标缓冲区 ---
double BullishTargetBuffer[]; // 0: 用于标记看涨K-Target锚点 (底部)
double BearishTargetBuffer[]; // 1: 用于标记看跌K-Target锚点 (顶部)
double BullishSignalBuffer[]; // 2: 最终看涨信号 (IB/DB突破确认)
double BearishSignalBuffer[]; // 3: 最终看跌信号 (IB/DB突破确认)

// --- 绘图属性 ---
// Plot 1: K-Target Bottom (锚点)
#property indicator_label1 "KTarget_Bottom"
#property indicator_type1  DRAW_ARROW
#property indicator_color1 clrBlue
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1
#define ARROW_CODE_UP 233 // 向上箭头

// Plot 2: K-Target Top (锚点)
#property indicator_label2 "KTarget_Top"
#property indicator_type2  DRAW_ARROW
#property indicator_color2 clrRed
#property indicator_style2 STYLE_SOLID
#property indicator_width2 1  // [V1.21 FIX] 修正了重复的 indicator_width1，确保正确设置 Plot 2 的宽度
#define ARROW_CODE_DOWN 234 // 向下箭头

// Plot 3: 最终看涨信号 
#property indicator_label3 "Bullish_Signal"
#property indicator_type3  DRAW_ARROW
#property indicator_color3 clrLimeGreen
#property indicator_style3 STYLE_SOLID
#property indicator_width3 2
#define ARROW_CODE_SIGNAL_UP 233 

// Plot 4: 最终看跌信号 
#property indicator_label4 "Bearish_Signal"
#property indicator_type4  DRAW_ARROW
#property indicator_color4 clrDarkViolet
#property indicator_style4 STYLE_SOLID
#property indicator_width4 2
#define ARROW_CODE_SIGNAL_DOWN 234

// --- 函数原型 ---
void FindAndDrawTargetCandles(int total_bars); 
bool CheckKTargetBottomCondition(int i, int total_bars);
bool CheckKTargetTopCondition(int i, int total_bars);
void DrawTargetBottom(int target_index);
void DrawTargetTop(int target_index);
void CheckBullishSignalConfirmation(int target_index); 
void CheckBearishSignalConfirmation(int target_index); 
void DrawBreakoutTrendLine(int target_index, int breakout_index, bool is_bullish); 

//========================================================================
// 1. OnInit: 指标初始化
//========================================================================
int OnInit()
{
    // 缓冲区映射设置
    SetIndexBuffer(0, BullishTargetBuffer);
    SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 1, clrBlue); 
    SetIndexArrow(0, ARROW_CODE_UP);
    
    SetIndexBuffer(1, BearishTargetBuffer);
    SetIndexStyle(1, DRAW_ARROW, STYLE_SOLID, 1, clrRed); 
    SetIndexArrow(1, ARROW_CODE_DOWN);
    
    SetIndexBuffer(2, BullishSignalBuffer);
    SetIndexStyle(2, DRAW_ARROW, STYLE_SOLID, 2, clrLimeGreen); 
    SetIndexArrow(2, ARROW_CODE_SIGNAL_UP);
    
    SetIndexBuffer(3, BearishSignalBuffer);
    SetIndexStyle(3, DRAW_ARROW, STYLE_SOLID, 2, clrDarkViolet); 
    SetIndexArrow(3, ARROW_CODE_SIGNAL_DOWN);
    
    // 初始化所有缓冲区数据为 0.0
    ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);
    
    // 指标简称
    string shortName = "K-Target (B:"+IntegerToString(Lookback_Bottom)+" L:"+IntegerToString(Max_Signal_Lookforward)+") V1.21";
    Print("---->[KTarget_Finder4.mq4:142]: shortName: ", shortName);
    IndicatorShortName(shortName);
    return(INIT_SUCCEEDED);
}

//========================================================================
// 2. OnDeinit: 指标卸载时调用 (清理图表对象)
//========================================================================
void OnDeinit(const int reason) 
{
    // 清理所有以 "IBDB_Line_" 为前缀的趋势线对象
    ObjectsDeleteAll(0, "IBDB_Line_"); 
    ChartRedraw();
    Print("---->[KTarget_Finder4.mq4:142]: OnDeinit ");
}


//========================================================================
// 3. OnCalculate: 主计算函数
//========================================================================
int OnCalculate(const int rates_total, 
                const int prev_calculated, 
                const datetime &time[], 
                const double& open[], 
                const double& high[], 
                const double& low[], 
                const double& close[], 
                const long& tick_volume[],
                const long& volume[],    
                const int& spread[])     
{
    // 检查是否有 K 线存在
    if(rates_total < 1) return(0); 

    // 清除缓冲区中的所有旧标记
    ArrayInitialize(BullishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishTargetBuffer, EMPTY_VALUE);
    ArrayInitialize(BullishSignalBuffer, EMPTY_VALUE);
    ArrayInitialize(BearishSignalBuffer, EMPTY_VALUE);
    
    // 寻找并绘制所有符合条件的 K-Target 及突破信号
    FindAndDrawTargetCandles(rates_total);
    
    // 返回 rates_total 用于下一次调用
    return(rates_total);
}


//========================================================================
// 4. FindAndDrawTargetCandles: 寻找 K-Target 的核心逻辑 (双向)
//========================================================================
void FindAndDrawTargetCandles(int total_bars)
{
    // 确定实际循环上限
    int max_bars_to_scan = MathMin(total_bars, Scan_Range);
    
    // 循环从第一根已收盘 K 线 (i=1) 开始
    for (int i = 1; i < max_bars_to_scan; i++)
    {
        // 1. 检查 K-Target Bottom (看涨) 锚定条件
        if (CheckKTargetBottomCondition(i, total_bars))
        {
            DrawTargetBottom(i); 
            // 检查信号确认逻辑 (IB/DB 突破)
            CheckBullishSignalConfirmation(i);
        }
        
        // 2. 检查 K-Target Top (看跌) 锚定条件
        if (CheckKTargetTopCondition(i, total_bars))
        {
            DrawTargetTop(i); 
            // 检查信号确认逻辑
            CheckBearishSignalConfirmation(i);
        }
    }
}


//========================================================================
// 5. CheckKTargetBottomCondition: 检查目标反转阴线 (K-Target Bottom)
//========================================================================
/*
   条件: 阴线，且收盘价是左右两侧周期内的最低收盘价。
*/
bool CheckKTargetBottomCondition(int i, int total_bars)
{
    // 1. 必须是阴线 (Bearish Candle)
    if (Close[i] >= Open[i]) return false;
    
    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= Lookahead_Bottom; k++)
    {
        int future_index = i - k; 
        if (future_index < 0) break; 
        // 必须是最低收盘价
        if (Close[future_index] < Close[i]) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= Lookback_Bottom; k++)
    {
        int past_index = i + k; 
        if (past_index >= total_bars) break; 
        // 必须是最低收盘价
        if (Close[past_index] < Close[i]) return false;
    }
    
    return true;
}


//========================================================================
// 6. CheckKTargetTopCondition: 检查目标反转阳线 (K-Target Top)
//========================================================================
/*
   条件: 阳线，且收盘价是左右两侧周期内的最高收盘价。
*/
bool CheckKTargetTopCondition(int i, int total_bars)
{
    // 1. 必须是阳线 (Bullish Candle)
    if (Close[i] <= Open[i]) return false;
    
    // --- 检查右侧 (未来/较新的K线) ---
    for (int k = 1; k <= Lookahead_Top; k++)
    {
        int future_index = i - k; 
        if (future_index < 0) break; 
        // 必须是最高收盘价
        if (Close[future_index] > Close[i]) return false;
    }
    
    // --- 检查左侧 (历史/较旧的K线) ---
    for (int k = 1; k <= Lookback_Top; k++)
    {
        int past_index = i + k; 
        if (past_index >= total_bars) break; 
        // 必须是最高收盘价
        if (Close[past_index] > Close[i]) return false;
    }
    
    return true;
}

//========================================================================
// 7. CheckBullishSignalConfirmation: 检查看涨信号的突破/确认逻辑 
//========================================================================
void CheckBullishSignalConfirmation(int target_index)
{
    // K-Target 锚点的开盘价 (突破基准线)
    double target_open_price = Open[target_index];
    
    // 从 K-Target 的下一根 K 线 (target_index - 1) 开始向前检查
    for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
    {
        if (j < 0) break;
        
        // 突破确认条件: 突破 K 线的收盘价 > K-Target 的开盘价
        if (Close[j] > target_open_price)
        {
            // 1. 绘制信号箭头
            BullishSignalBuffer[j] = Low[j] - 20 * Point(); 
            
            // 2. 绘制水平延伸的趋势突破线 (Start: target_index, Breakthrough index: j)
            // DrawBreakoutTrendLine(target_index, j, true);
            
            // 找到第一个突破后，IB/DB 确认完成，立即退出循环
            return;
        }
    }
}

//========================================================================
// 8. CheckBearishSignalConfirmation: 检查看跌信号的突破/确认逻辑 
//========================================================================
void CheckBearishSignalConfirmation(int target_index)
{
    // K-Target 锚点的开盘价 (突破基准线)
    double target_open_price = Open[target_index];
    
    // 从 K-Target 的下一根 K 线 (target_index - 1) 开始向前检查
    for (int j = target_index - 1; j >= target_index - Max_Signal_Lookforward; j--)
    {
        if (j < 0) break;
        
        // 突破确认条件: 突破 K 线的收盘价 < K-Target 的开盘价
        if (Close[j] < target_open_price)
        {
            // 1. 绘制信号箭头
            BearishSignalBuffer[j] = High[j] + 20 * Point();
            
            // 2. 绘制水平延伸的趋势突破线 (Start: target_index, Breakthrough index: j)
            // DrawBreakoutTrendLine(target_index, j, false);
            
            // 找到第一个突破后，确认完成，立即退出循环
            return;
        }
    }
}

//========================================================================
// 9. DrawBreakoutTrendLine: 绘制突破趋势线 (OBJ_TREND)
//========================================================================
/*
   绘制一条从 K-Target.Open 开始，价格水平延伸到突破 K 线 (breakout_index) 
   时间 + 2 根 K 线的时间上。
   明确设置 OBJPROP_RAY = false，确保它是一条线段。
*/
void DrawBreakoutTrendLine(int target_index, int breakout_index, bool is_bullish)
{
    // Anchor 1 (起点): K-Target 锚点的 Open 价格和时间
    datetime time1 = Time[target_index];
    double price1 = Open[target_index]; 
    
    // --- Anchor 2 (终点) 计算 ---
    
    // 终点 K 线索引: 使用突破 K 线索引，并向右 (现价方向) 延伸 2 根 K 线
    int end_bar_index = breakout_index - 2; 
    
    // 边界检查：确保索引不小于 1 (1 是最新的已收盘 K 线)
    if (end_bar_index < 1) 
    {
        end_bar_index = 1; // 防止数组越界
    }
    
    datetime time2 = Time[end_bar_index]; // 使用推移后的时间
    double price2 = price1;                 // 价格与起点价格保持一致 (实现水平线效果)
    
    // 生成唯一的对象名称 
    string name = "IBDB_Line_" + (is_bullish ? "B_" : "S_") + IntegerToString(target_index);
    string comment;
    
    // 检查对象是否已存在，如果存在则直接返回
    if (ObjectFind(0, name) != -1) return; 
    
    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, price1))
    {
        Print("无法创建突破趋势线对象: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 设置趋势线的第二个锚点 (终点)
    ObjectSetInteger(0, name, OBJPROP_TIME2, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, price2);
    
    // ** 明确设置它不是射线 **
    ObjectSetInteger(0, name, OBJPROP_RAY, false); 
    
    // 设置线条属性
    ObjectSetInteger(0, name, OBJPROP_COLOR, is_bullish ? clrLimeGreen : clrDarkViolet); 
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); 
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); // 实线
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景 (线在 K 线后面)
    
    // 设置注释/描述
    comment = "IB/DB K-Target @ " + DoubleToString(price1, Digits);
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    
    // 将趋势线设置为不可选中，避免误操作
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}


//========================================================================
// 10. DrawTargetBottom: 绘图函数，用向上箭头标记 K-Target Bottom
//========================================================================
void DrawTargetBottom(int target_index)
{
    // 将箭头标记在 K-Target 的最低价之下
    BullishTargetBuffer[target_index] = Low[target_index] - 10 * Point(); 
}

//========================================================================
// 11. DrawTargetTop: 绘图函数，用向下箭头标记 K-Target Top
//========================================================================
void DrawTargetTop(int target_index)
{
    // 将箭头标记在 K-Target 的最高价之上
    BearishTargetBuffer[target_index] = High[target_index] + 10 * Point(); 
}