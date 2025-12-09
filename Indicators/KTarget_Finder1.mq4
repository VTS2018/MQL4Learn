//+------------------------------------------------------------------+
//|                          版本迭代日志 (Changelog)                  |
//+------------------------------------------------------------------+
/*
   日期           | 版本    | 描述
   ------------------------------------------------------------------
   2025.10.28     | v1.00   | 初始版本。初步实现 K-Target的查找逻辑，在左侧和右侧两边都去查找
   ------------------------------------------------------------------
*/
//+------------------------------------------------------------------+

#property copyright "Copyright 2025, MQL Developer"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window // 绘制在主图表窗口
#property indicator_buffers 1
#property indicator_plots   1

// --- 外部可调参数 (输入) ---
extern int Scan_Range = 500;           // 总扫描范围：向后查找 500 根 K 线以寻找 K-Target
extern int Min_Close_Period = 20;      // (右侧/未来) "最低收盘价"周期：K-Target 必须是其后 N 根 K 线中的最低价
extern int Min_Close_Lookback = 20;    // (左侧/历史) "最低收盘价"回顾周期：K-Target 必须是其前 N 根 K 线中的最低价

// --- 指标缓冲区 ---
double TargetBuffer[];

// --- 绘图属性 ---
#property indicator_label1 "目标K线"
#property indicator_type1  DRAW_ARROW
#property indicator_color1 clrBlue // 修正: 颜色改为蓝色
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1 // 修正: 宽度改为 1 (精瘦)
#define ARROW_CODE 233 // 向上箭头，用于标记底部反转的目标K线

// --- 函数原型 (用于编译器声明) ---
void FindAndDrawTargetCandles(int total_bars); 
void DrawTargetCandle(int target_index);

//========================================================================
// 1. OnInit: 指标初始化
//========================================================================
int OnInit()
{
    SetIndexBuffer(0, TargetBuffer);
    SetIndexStyle(0, DRAW_ARROW, STYLE_SOLID, 1, clrBlue); // 修正: 宽度和颜色
    SetIndexArrow(0, ARROW_CODE);
    
    // 初始化缓冲区数据为 0.0，以便正确绘图
    ArrayInitialize(TargetBuffer, EMPTY_VALUE);
    
    // 修正错误：使用 IntegerToString() 显式转换数字到字符串
    IndicatorShortName("目标K线查找器 (左"+IntegerToString(Min_Close_Lookback)+" / 右"+IntegerToString(Min_Close_Period)+")");
    return(INIT_SUCCEEDED);
}

//========================================================================
// 2. OnCalculate: 主计算函数
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
    // 检查是否有足够的数据进行计算
    if(rates_total < Scan_Range) return(0);

    // 清除缓冲区中的所有旧标记
    ArrayInitialize(TargetBuffer, EMPTY_VALUE);
    
    // 寻找并绘制所有符合条件的 K-Target
    FindAndDrawTargetCandles(rates_total);
    
    // 返回 rates_total 用于下一次调用
    return(rates_total);
}


//========================================================================
// 3. FindAndDrawTargetCandles: 寻找所有 K-Target 的核心逻辑
//========================================================================
/*
   逻辑: 寻找一个索引 'i' (目标 K 线)，使其满足：
   1. 必须是阴线 (Close[i] < Open[i])。
   2. 它的收盘价 Close[i] 必须是其左侧 Min_Close_Lookback 和右侧 Min_Close_Period 周期内的最低收盘价。
*/
void FindAndDrawTargetCandles(int total_bars)
{
    // 循环从第一根已收盘 K 线 (i=1) 开始，向左扫描至 Scan_Range
    for (int i = 1; i < Scan_Range; i++)
    {
        // 1. 基本筛选：K-Target 必须是阴线 (Bearish Candle)
        if (Close[i] < Open[i])
        {
            // 2. 最低收盘价锚定检查 (分为左右两侧)
            bool is_lowest_close = true;
            
            // --- A. 检查右侧 (未来/较新的K线) ---
            // 扫描 K-Target (i) 后续的 Min_Close_Period 根 K 线进行验证
            for (int k = 1; k <= Min_Close_Period; k++)
            {
                // future_index 索引越小，时间越近 ("后面"的K线)
                int future_index = i - k; 
                
                // 确保索引在安全范围内 (不越过 K[0])
                if (future_index < 0) break; 
                
                // 如果右侧 K 线的收盘价低于目标 K 线的收盘价，则 K[i] 锚定失败
                if (Close[future_index] < Close[i])
                {
                    is_lowest_close = false;
                    break; // 发现更低的收盘价，退出内层循环
                }
            }
            
            // 如果右侧检查失败，则跳过左侧检查，继续下一根 K 线
            if (!is_lowest_close) continue; 
            
            // --- B. 检查左侧 (历史/较旧的K线) ---
            // 扫描 K-Target (i) 前面的 Min_Close_Lookback 根 K 线进行验证
            for (int k = 1; k <= Min_Close_Lookback; k++)
            {
                // past_index 索引越大，时间越远 ("前面"的K线)
                int past_index = i + k; 
                
                // 确保索引在安全范围内 (检查 total_bars 而不是 Scan_Range)
                if (past_index >= total_bars) break; 
                
                // 如果左侧 K 线的收盘价低于目标 K 线的收盘价，则 K[i] 锚定失败
                if (Close[past_index] < Close[i])
                {
                    is_lowest_close = false;
                    break; // 发现更低的收盘价，退出内层循环
                }
            }
            
            // 3. 结果：如果通过了左右两侧的检查，它就是 K-Target
            if (is_lowest_close)
            {
                DrawTargetCandle(i); 
            }
        }
    }
}

//========================================================================
// 4. DrawTargetCandle: 绘图函数，用箭头标记 K 线
//========================================================================
void DrawTargetCandle(int target_index)
{
    // 将箭头标记在 K-Target 的最低价之下
    // 修正: 10 * Point() 增加距离，避免遮挡 K 线
    TargetBuffer[target_index] = Low[target_index] - 10 * Point(); 
}