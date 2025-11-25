//+------------------------------------------------------------------+
//|                                              K_Drawing_Funcs.mqh |
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
//========================================================================
// 11. DrawBreakoutTrendLine: 绘制突破趋势线 (P1)
//========================================================================
/**
   绘制一条从 K-Target.Open (P1) 开始，价格水平延伸到突破 K 线 
   时间 + 2 根 K 线的时间上。
   明确设置 OBJPROP_RAY = false，确保它是一条线段。

 * 根据看涨锚点的索引 和 P1 突破K线的索引  绘制趋势线，这是本程序绘制的第一条趋势线 非常关键
 * 绘制一条从 K-Target.Open (P1) 开始，价格水平延伸到突破 K 线
 * 时间 + 2 根 K 线的时间上。
 * 明确设置 OBJPROP_RAY = false，确保它是一条线段。
 * 
 * @param target_index: 看涨锚点的索引
 * @param breakout_index: P1 突破K线的索引
 * @param is_bullish: 阳线或者阴线
 * @param P2_price: 顺带着 展示出P2的价格 便于直观的对比
 */
void DrawP1Baseline(int target_index, int breakout_index, bool is_bullish, double P2_price)
{
    // K_Geo_Index 这个值在函数调用之前 需要检查 如果是-1 就不执行了，通过这个值确定是 DB 还是IB
    int breakout_candle_count = target_index - breakout_index;

    // Anchor 1 (起点): K-Target 锚点的 Open 价格和时间 (P1)
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
    
    // [V1.22 NEW] 突破类型分类
    string classification = breakout_candle_count < DB_Threshold_Candles ? "IB" : "DB";
    
    // 生成唯一的对象名称 
    string time_id_str = GetBarTimeID(target_index);
    string name = g_object_prefix + "IBDB_Line_" + classification + (is_bullish ? "B_" : "S_") + time_id_str;
    string comment;
    
    // 检查对象是否已存在，如果存在则直接返回
    if (ObjectFind(0, name) != -1) return; 
    
    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, price1))
    {
        Print("无法创建 P1 趋势线对象: ", name, ", 错误: ", GetLastError());
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
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID); // 实线 (P1)
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景 (线在 K 线后面)
    
    // [V1.22 UPD] 设置注释/描述，包含 IB/DB 分类和 P2 价格
    comment = classification + " P1 @" + DoubleToString(price1, Digits) + " (P2:" + DoubleToString(P2_price, Digits) + ")";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    
    // 将趋势线设置为不可选中
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

/**
 * DrawSecondBaseline: 绘制第二基准价格线 (P2)
 * 用P2 K线的索引来解耦这个函数,P2 K线的开盘价, 突破P2的索引+2，终点是 P2 突破K的索引 但是这个突破值是一个动态值
 * @param target_index: Argument 1
 * @param breakout_index: Argument 2
 * @param is_bullish: Argument 3
 */
void DrawP2Baseline(int target_index, int breakout_index, bool is_bullish)
{
    if (target_index == -1)
    {
        return;
    }

    double P2_price= Close[target_index];
    // 如果 P2 价格无效 (未找到)，则不绘制
    if (P2_price <= 0.0) return;
    
    // Anchor 1 (起点): P2 价格，K-Target 锚点时间
    datetime time1 = Time[target_index];
    
    // Anchor 2 (终点): P2 价格，延伸到突破 K 线 + 2
    int end_bar_index = breakout_index - 2; 
    if (end_bar_index < 1) end_bar_index = 1;
    datetime time2 = Time[end_bar_index];
    
    string time_id_str = GetBarTimeID(target_index);
    string name = g_object_prefix + "IBDB_P2_Line_" + (is_bullish ? "B_" : "S_") + time_id_str;
    string comment;

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1) return; 
    
    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, P2_price))
    {
        Print("无法创建 P2 趋势线对象: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 设置趋势线的第二个锚点 (终点)
    ObjectSetInteger(0, name, OBJPROP_TIME2, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, P2_price);
    
    // ** 明确设置它不是射线 **
    ObjectSetInteger(0, name, OBJPROP_RAY, false); 
    
    // 设置线条属性: 虚线，较细，不同颜色
    ObjectSetInteger(0, name, OBJPROP_COLOR, is_bullish ? clrDarkBlue : clrDarkRed); // 深色作为P2
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); 
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); // 点线/虚线
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景
    
    comment = "P2 Baseline" + " (P2:" + DoubleToString(P2_price, Digits) + ")";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//========================================================================
// 15. DrawAbsoluteSupportLine: 绘制绝对支撑/阻力水平线 (V1.35 NEW)
//========================================================================
/**
 * 在绝对低点/高点上绘制一条水平趋势线，并带文字说明。
 * @param abs_index: 具有绝对低/高价的 K 线索引。
 * @param is_bullish: 看涨 (支撑线) 还是看跌 (阻力线)。
 * @param extend_bars: 向右延伸的 K 线数量 (例如 15)。
 */
void DrawAbsoluteSupportLine(int abs_index, bool is_bullish, int extend_bars)
{
    if (abs_index < 0)
        return;

    // 确定线条的锚点价格
    double price = is_bullish ? Low[abs_index] : High[abs_index];
    //Print("===>[KTarget_Finder4_FromGemini.mq4:1048]: price: ", price);

    // 确定线条的起点和终点时间
    datetime time1 = Time[abs_index]; // 起点时间：绝对极值 K 线的时间

    // 终点 K 线索引：从 abs_index 向右（较新 K 线）移动 extend_bars
    int end_bar_index = abs_index - extend_bars;
    if (end_bar_index < 0)
        end_bar_index = 0; // 边界检查

    datetime time2 = Time[end_bar_index]; // 终点时间

    // --- 对象创建与设置 ---
    string time_id_str = GetBarTimeID(abs_index);
    string name = g_object_prefix + (is_bullish ? "AbsLow_" : "AbsHigh_") + time_id_str;

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1)
        return;

    // 创建趋势线对象 (OBJ_TREND)
    if (!ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price))
    {
        Print("无法创建 绝对最低价对象: ", name, ", 错误: ", GetLastError());
        return;
    }

    // 设置属性
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); // 最细样式 (宽度 1)
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_BACK, true); // 背景
    ObjectSetInteger(0, name, OBJPROP_RAY, false); // 确保是线段

    // 设置文字说明 (可见文本)
    string comment = is_bullish ? "Absolute Low Support" : "Absolute High Resistance";
    ObjectSetString(0, name, OBJPROP_TEXT, comment);

    // **确保文字可见性**：将文字附加在趋势线的一端，并调整其位置。
    // 在 MQL4 中，OBJ_TREND 的 OBJPROP_TEXT 默认是可见的，我们只需要确保它没有被其他东西遮挡。

    // 3. 更新位置
    ObjectSetInteger(0, name, OBJPROP_TIME1, time1);
    ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
    ObjectSetInteger(0, name, OBJPROP_TIME2, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, price);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//========================================================================
// 12. DrawP1P2Rectangle: 绘制 P1 K线低价到 P2 K线收盘价的矩形区域 (V1.33 NEW)
// 修正绘制 看涨K-target 绝对最低价K的最低点  到 突破P1 K线 或者P2 K线满足 CB 信号的矩形
//========================================================================
/**
 * 绘制从 P1 K线的低/高价 到 P2 K线的收盘价 的矩形区域。
 *
 * @param target_index: P1 K线索引 (K-Target 锚点)
 * @param P2_index: P2 K线索引 (反转 K 线)
 * @param is_bullish: 看涨或者看跌
 */
void DrawP1P2Rectangle(int target_index, int P2_index, bool is_bullish)
{
    // --- 确保 P1/P2 索引有效 ---
    if (target_index < 0 || P2_index < 0) return;

    // --- 确定矩形的四个角点 ---
    
    // 角点 A (K-Target 锚点侧)
    datetime time1 = Time[target_index];
    double price1;
    
    // 角点 B (P2 侧)
    datetime time2 = Time[P2_index];
    double price2 = Close[P2_index]; // P2 侧的价格锚定 P2 K 线的收盘价

    // 1. 根据看涨/看跌确定 P1 侧的价格锚定点
    if (is_bullish)
    {
        // 看涨: 价格锚定 K-Target 的最低价 (Low)
        price1 = Low[target_index];
    }
    else // is_bearish
    {
        // 看跌: 价格锚定 K-Target 的最高价 (High)
        price1 = High[target_index];
    }

    // --- 对象创建与设置 ---
    // 名称使用唯一的对象名前缀
    // string time_id_str = GetBarTimeID(target_index);
    // string name = g_object_prefix + (is_bullish ? "Rect_B_" : "Rect_S_") + time_id_str;

    //---------2.0 升级矩形对象的名称 用来为 斐波绘制提供信息传送
    // --- 获取 P1 和 P2 K线时间的格式化字符串 ---
    // 例如: "2025_11_24_06_00_00"
    string P1_time_id_str = GetBarTimeID(target_index);
    string P2_time_id_str = GetBarTimeID(P2_index);
    // 🚨 V3.00 核心修正：命名格式包含 P1 和 P2 时间，用 # 分隔
    // 格式: [Prefix]_[Type]_[P1_TimeID]#[P2_TimeID]
    string name = g_object_prefix +
                  (is_bullish ? "Rect_B_" : "Rect_S_") +
                  P1_time_id_str +
                  "#" +
                  P2_time_id_str;
    //---------2.0 升级矩形对象的名称 用来为 斐波绘制提供信息传送

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1) return;

    // 创建对象 (使用矩形对象 OBJ_RECTANGLE)
    // 矩形需要四个点: (时间1, 价格1) 和 (时间2, 价格2)
    if (!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2))
    {
        Print("无法创建 P1/P2 矩形对象: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 2. 设置属性 (更新)
    // 确保矩形在 K 线后面 (背景)
    ObjectSetInteger(0, name, OBJPROP_BACK, true); 
    
    // 设置颜色和透明度
    color rect_color = is_bullish ? clrLightBlue : clrLightPink; // 浅蓝色/浅粉色
    
    ObjectSetInteger(0, name, OBJPROP_COLOR, rect_color);
    
    // 设置为半透明 (0-255, 0为完全透明, 255为不透明)
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrNONE); // 移除边框
    ObjectSetInteger(0, name, OBJPROP_FILL, 1); // 开启填充
    //ObjectSetInteger(0, name, OBJPROP_LEVEL, 120); // 透明度设置 (例如 120)
    
    ObjectSetString(0, name, OBJPROP_TEXT, "P1/P2 Area");
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false); // 不可选中
    
    // 3. 更新矩形位置 (用于 OnCalculate 循环更新)
    ObjectSetInteger(0, name, OBJPROP_TIME1, time1);
    ObjectSetDouble(0, name, OBJPROP_PRICE1, price1);
    ObjectSetInteger(0, name, OBJPROP_TIME2, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, price2);
}

//========================================================================
// 13. DrawP1P2Fibonacci: 绘制 P1/P2 区域的斐波那契回调线 (V1.34 NEW)
//========================================================================
/**
 * 绘制 P1 K线的低/高价 到 P2 K线的收盘价 的斐波那契回调线。
 *
 * @param target_index: P1 K线索引 (K-Target 锚点)
 * @param P2_index: P2 K线索引 (反转 K 线)
 * @param is_bullish: 看涨或者看跌
 */
void DrawP1P2Fibonacci(int target_index, int P2_index, bool is_bullish)
{
    if (!Is_DrawFibonacciLines) return;
    
    // --- V1.38 内部硬编码自定义设置 ---
    color FIBO_LINE_COLOR = clrBlack;

    // 自定义斐波那契级别的值 (例如，添加了 78.6%)
    double custom_values[] = {0.0, 1.0, 0.236, 0.382, 0.500, 0.618, 0.786, 0.880, 1.618, 1.786, 1.880, 2.618, 2.786, 2.880, 4.236, 4.786, 4.880, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
    int FIBO_CUSTOM_LEVELS_COUNT = ArraySize(custom_values);
    //Print("--->[KTarget_Finder4_FromGemini.mq4:1229]: FIBO_CUSTOM_LEVELS_COUNT: ", FIBO_CUSTOM_LEVELS_COUNT);

    // 自定义斐波那契级别的说明 (与上面的值一一对应)
    string custom_texts[] = {
        "Base %$",  // k=0 (0.0)
        "Setup %$", // k=1 (1.0)

        "0.236 Major %$", // k=2 (0.236)
        "0.382 Minor %$", // k=3 (0.382)
        "50 %$",          // k=4 (0.500)

        "0.618 PullBack %$", // k=5 (0.618)
        "0.786 PullBack %$", // k=6 (0.786)
        "0.880 PullBack %$",

        "TP11-%$",
        "1MAX-%$",
        "1MAX-%$",

        "TP21-%$",
        "2MAX-%$",
        "2MAX-%$",

        "TP31-%$",
        "3MAX-%$",
        "3MAX-%$",

        "1:1的位置-%$",
        "1:2的位置-%$",
        "1:3的位置-%$",
        "1:4的位置-%$",
        "1:5的位置-%$",
        "1:6的位置-%$",
        "1:7的位置-%$",
        "1:8的位置-%$",
        "1:9的位置-%$",
        "1:10的位置-%$",
        "1:11的位置-%$",
        "1:12的位置-%$",
        "1:13的位置-%$",
        "1:14的位置-%$",
        "1:15的位置-%$"};
    //int FIBO_CUSTOM_LEVELS_COUNT_TEXTS = ArraySize(custom_texts);
    //Print("-->[KTarget_Finder4_FromGemini.mq4:1272]: FIBO_CUSTOM_LEVELS_COUNT_TEXTS: ", FIBO_CUSTOM_LEVELS_COUNT_TEXTS);

    // --- 确保 P1/P2 索引有效 ---
    if (target_index < 0 || P2_index < 0) return;

    // --- 确定斐波那契的两个锚点 ---
    
    // 锚点 1 (Fib 0 位置 - P1 K-Target 锚点侧)
    datetime time1 = Time[target_index];
    double price1;
    
    // 锚点 2 (Fib 1 位置 - P2 K 线侧)
    datetime time2 = Time[P2_index];
    double price2 = Close[P2_index]; // P2 K 线的收盘价即为 Fib 1 的价格

    // 1. 根据看涨/看跌确定 P1 侧的价格 (Fib 0)
    if (is_bullish)
    {
        // 看涨: 价格锚定 K-Target 的最低价 (Low) 作为 0% (支撑)
        price1 = Low[target_index];
    }
    else // is_bearish
    {
        // 看跌: 价格锚定 K-Target 的最高价 (High) 作为 0% (阻力)
        price1 = High[target_index];
    }

    // --- 对象创建与设置 ---
    // 名称使用唯一的对象名前缀
    string time_id_str = GetBarTimeID(target_index);
    string name = g_object_prefix + (is_bullish ? "Fibo_B_" : "Fibo_S_") + time_id_str;
    //Print(">>> DrawP1P2Fibonacci: Drawing Fibo ", name);

    // 检查对象是否已存在
    if (ObjectFind(0, name) != -1) return;

    // 创建对象 (使用斐波那契回调线 OBJ_FIBO)
    if (!ObjectCreate(0, name, OBJ_FIBO, 0, time2, price2, time1, price1))
    {
        Print("无法创建 P1/P2 使用斐波那契回调线: ", name, ", 错误: ", GetLastError());
        return;
    }
    
    // 2. 设置属性 (更新)

    // 确保斐波那契线在 K 线后面 (背景)
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_RAY, false);
    // 不向未来延伸
    // ObjectSetInteger(0, name, OBJPROP_FIBO_EXTEND, false);
    // 确保斐波那契线不可选中
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);

    // 设置线条颜色和宽度
    color fibo_color = is_bullish ? clrGreen : clrMagenta;
    ObjectSetInteger(0, name, OBJPROP_COLOR, fibo_color);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    
    // 3. 更新位置
    ObjectSetInteger(0, name, OBJPROP_TIME1, time2);
    ObjectSetDouble(0, name, OBJPROP_PRICE1, price2);
    ObjectSetInteger(0, name, OBJPROP_TIME2, time1);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, price1);
    
    ObjectSetString(0, name, OBJPROP_TEXT, "P1/P2 Fibo");

    // 🚨 V1.48 关键修正: 显式设置斐波那契级别总数
    ObjectSetInteger(0, name, OBJPROP_LEVELS, FIBO_CUSTOM_LEVELS_COUNT);
    //Print(">>> DrawP1P2Fibonacci: Setting All 32 Levels for Fibo ", name);

    // 4. V1.38 核心：设置自定义斐波那契级别、文本和颜色

    // MT4 最多支持 32 个斐波那契级别 (索引 0 到 31)
    for (int k = 0; k < 32; k++)
    {
        // (1) 设置自定义级别 步骤 A: 设置我们定义的 32 个级别 (k=0 到 k=6)
        // if (k < FIBO_CUSTOM_LEVELS_COUNT)
        // {
            // 设置值 (百分比)
            ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, k, custom_values[k]);
            // 设置说明文本
            ObjectSetString(0, name, OBJPROP_LEVELTEXT, k, custom_texts[k]);
            
            // 🚨 强制设置级别颜色为硬编码的颜色 (解决了颜色被覆盖的问题)
            ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, k, FIBO_LINE_COLOR);
            
            // 确保级别线条样式和宽度与主线一致
            ObjectSetInteger(0, name, OBJPROP_LEVELSTYLE, k, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_LEVELWIDTH, k, 1);
        // }
        // // (2) 隐藏所有未使用的级别
        // else
        // {
        //     // 设置值为 0.0 或一个空文本可有效隐藏级别
        //     ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, k, 0.0);
        //     ObjectSetString(0, name, OBJPROP_LEVELTEXT, k, "");
        // }
    }
}