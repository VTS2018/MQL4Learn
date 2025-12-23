//+------------------------------------------------------------------+
//|                                              K_Drawing_Funcs.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//========================================================================
// DrawBreakoutTrendLine: 绘制突破趋势线 (P1)
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
    if (Is_EA_Mode) return;
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
    if (Is_EA_Mode) return;
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
// DrawAbsoluteSupportLine: 绘制绝对支撑/阻力水平线 (V1.35 NEW)
//========================================================================
/**
 * 在绝对低点/高点上绘制一条水平趋势线，并带文字说明。
 * @param abs_index: 具有绝对低/高价的 K 线索引。
 * @param is_bullish: 看涨 (支撑线) 还是看跌 (阻力线)。
 * @param extend_bars: 向右延伸的 K 线数量 (例如 15)。
 */
void DrawAbsoluteSupportLine(int abs_index, bool is_bullish, int extend_bars)
{
    if (Is_EA_Mode) return;
    if (abs_index < 0) return;

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
// DrawP1P2Rectangle: 绘制 P1 K线低价到 P2 K线收盘价的矩形区域 (V1.33 NEW)
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
    if (Is_EA_Mode) return;
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
// DrawP1P2Fibonacci: 绘制 P1/P2 区域的斐波那契回调线 (V1.34 NEW)
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
    if (Is_EA_Mode) return;
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
    
    string time_p = GetTimeframeName(_Period);
    ObjectSetString(0, name, OBJPROP_TEXT, "P1/P2 Fibo " + time_p + (is_bullish ? " 多 " : " 空 "));

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

    // Print("--->[K_Drawing_Funcs.mqh:497]: _Period: ", _Period);
    // 1. 获取当前周期的正确位标志 (例如：传入 43200，返回 256)
    int current_tf_flag = GetTimeframeFlag(_Period);
    // Print("--->[K_Drawing_Funcs.mqh:498]: current_tf_flag: ", current_tf_flag);
    
    if (current_tf_flag != 0)
    {
        // 🚨 最终修正：使用转换后的正确的位标志 🚨
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, current_tf_flag);
    }
}


/**
 * 清理旧有的信号绘制的矩形对象
 * @param target_index: Argument 1
 * @param is_bullish: Argument 2
 */
/*
void ClearSignalRectangle(int target_index, bool is_bullish)
{
    // 构建可能存在的旧矩形名称
    string name_prefix = g_object_prefix + "Rect_" + (is_bullish ? "B_" : "S_");
    
    // 查找并删除唯一匹配该锚点时间戳的对象
    string target_name = name_prefix + GetBarTimeID(target_index);
    
    // 假设 ObjectDelete 函数已在 MQL4 环境中可用 (通常是 ObjectDelete(0, name))
    if (ObjectFind(0, target_name) != -1)
    {
        ObjectDelete(0, target_name);
        Print("DEBUG: Cleared old signal rectangle for target index: ", target_name);
    }
}
*/

/**
 * 清理旧有的信号绘制的矩形对象
 * @param target_index: 锚点K线的索引，不是锚点的索引 而是最低价和最高价K线的索引 这个函数先放到这里以后再解决
 * @param is_bullish: 是否为看涨信号 (true=看涨, false=看跌)
 */
/*
void ClearSignalRectangle_v2(int target_index, bool is_bullish)
{
    // 1. 构建要查找的矩形名称的唯一标识 (即 '#' 符号之前的所有部分)
    string name_prefix = g_object_prefix + "Rect_" + (is_bullish ? "B_" : "S_");
    
    // target_unique_id 示例：KT5_..._Rect_B_2025_11_26_04_31_00
    // 这是您保证唯一的、不带 '#' 的部分。
    string target_unique_id = name_prefix + GetBarTimeID(target_index); 
    
    // 2. 遍历图表对象并查找名称中包含该唯一标识的对象
    int total_objects = ObjectsTotal();
    string obj_name;

    for (int i = total_objects - 1; i >= 0; i--)
    {
        // 🚨 使用 MQL4 的 ObjectName(index) 获取名称 🚨
        obj_name = ObjectName(i);

        // 检查对象名称是否包含我们构建的 target_unique_id
        // 如果 StringFind 返回非 -1 的值，说明找到了包含该唯一标识的对象
        if (StringFind(obj_name, target_unique_id) != -1) 
        {
            // 找到了，执行删除。这个 obj_name 必然是完整的名称，例如 KT5_...#2025_...
            // ObjectDelete(0, obj_name);
            Print("--->DEBUG: Cleared signal rectangle 559: ", obj_name);
            
            // 找到即可退出，因为每个锚点只应有一个矩形需要清除
            // return;
        }
    }
}
*/

void DrawFiboHighlightRectangles(int target_index, int P2_index, bool is_bullish)
{
    // 根据信号类型，将对应的全局数组传递给核心函数
    // MQL4 会自动处理引用传递，没有复杂的语法
    
    if (is_bullish)
    {
        ExecuteDrawFiboRects(target_index, P2_index, is_bullish, BULLISH_HIGHLIGHT_ZONES);
    }
    else
    {
        ExecuteDrawFiboRects(target_index, P2_index, is_bullish, BEARISH_HIGHLIGHT_ZONES);
    }
}

/**
 * 绘制斐波那契扩展区域的高亮矩形
 * @param target_index: P1 (锚点K线) 索引
 * @param P2_index: P2 K线索引
 * @param is_bullish: 是否为看涨斐波那契
 */
void ExecuteDrawFiboRects(int target_index, int P2_index, bool is_bullish, const FiboZone &zones[])
{
    if (Is_EA_Mode) return;
    // 获取 P1 和 P2 的价格和时间
    double P1_price; // 假设 P1 价格是锚点的 Open

    // 1. 根据看涨/看跌确定 P1 侧的价格锚定点
    if (is_bullish)
    {
        // 看涨: 价格锚定 K-Target 的最低价 (Low)
        P1_price = Low[target_index];
    }
    else // is_bearish
    {
        // 看跌: 价格锚定 K-Target 的最高价 (High)
        P1_price = High[target_index];
    }

    double P2_price = Close[P2_index]; // 假设 P2 价格是 P2 K线的 Close

    // 确定矩形在时间上的跨度 (从 P1 锚点开始，到当前最新 K线)
    datetime time1 = Time[target_index];

    // 矩形应一直延伸到最新 K线
    datetime time2 = Time[0];

    //--------------------------------------------
    // 先调试价格
    // Print("-->[K_Drawing_Funcs.mqh:600]: P1_price: ", P1_price);
    // Print("-->[K_Drawing_Funcs.mqh:601]: P2_price: ", P2_price);
    // Print("-->[K_Drawing_Funcs.mqh:602]: time1: ", time1);
    // Print("-->[K_Drawing_Funcs.mqh:603]: time2: ", time2);
    //return; 价格全部对应得上 测试通过
    //--------------------------------------------

    // 确定要遍历的区域数组
    //const FiboZone& zones[] = is_bullish ? BULLISH_HIGHLIGHT_ZONES : BEARISH_HIGHLIGHT_ZONES;
    int zones_count = ArraySize(zones);
    
    // 确定颜色
    color rect_color = GetHighlightColorByPeriod(is_bullish);

    //-----
    // 1. 获取周期名称 (例如 "H4", "D1")
    string tf_name = GetTimeframeName(_Period);

    // 2. 确定区域类型描述
    string area_type = is_bullish ? "看涨斐波反转-做空-区域" : "看跌斐波反转-做多-区域";

    // 3. 组合最终的说明文本
    // 示例: "H4 看跌斐波反转区域"
    string description_text = tf_name + " " + area_type;
    //-----

    // 获取周期可见性标志
    // int tf_flag = GetTimeframeFlag(_Period);
    // Print("--->[K_Drawing_Funcs.mqh:643]: tf_flag: ", tf_flag);


    // 遍历所有高亮区域并绘制矩形
    for (int i = 0; i < zones_count; i++)
    {
        double level1 = zones[i].level1;
        double level2 = zones[i].level2;
        
        // 1. 计算价格坐标
        double price_start = CalculateFiboPrice(P1_price, P2_price, level1);
        // Print("===>[K_Drawing_Funcs.mqh:622]: price_start: ", price_start," level1: ",level1);

        double price_end   = CalculateFiboPrice(P1_price, P2_price, level2);
        // Print("===>[K_Drawing_Funcs.mqh:624]: price_end: ", price_end," level2: ",level2);


        // 🚨 修正2.0：确定文本的锚点 🚨
        // 时间锚点：使用 time2 (Time[0])，即矩形的右侧，实现右侧定位
        datetime time_anchor = Time[0];

        // 价格锚点：根据方向确定是矩形的高点还是低点
        double text_anchor_price;
        if (is_bullish)
        {
            // 看涨斐波 (文本在右下角): 锚定价格为矩形价格的较低点
            text_anchor_price = MathMin(price_start, price_end);
        }
        else
        {
            // 看跌斐波 (文本在右上角): 锚定价格为矩形价格的较高点
            text_anchor_price = MathMax(price_start, price_end);
        }

        // 1.0 注销
        // 矩形的顶部价格 (作为文本锚定点)
        // double price_top = price_end;

        // 2. 命名对象，使用特殊标记 "_FiboHL_" 满足周期切换不删除需求
        string name = g_object_prefix + "Rect_FiboHL_" + (is_bullish ? "B_" : "S_") + GetBarTimeID(target_index) + "#" + DoubleToString(level1, 3) + "_" + DoubleToString(level2, 3);
        // Print("===>[K_Drawing_Funcs.mqh:624]: name: ", name);

        string text_name = name + "_TXT";

        /*
        // 3. 创建/更新矩形
        if (ObjectFind(0, name) != -1)
        {
            ObjectDelete(0, name); // 如果已存在，先删除，再重新绘制
        }
        
        if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price_start, time2, price_end))
        {
            // 设置属性
            ObjectSetInteger(0, name, OBJPROP_COLOR, rect_color);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            
            // 🚨 设置填充和背景 (FILL and BACK)
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true); // 矩形在 K 线后面
            
            // 🚨 设置透明度 (MQL4/MT4 颜色函数)
            ObjectSetInteger(0, name, OBJPROP_COLOR, (int)rect_color | (HIGHLIGHT_ALPHA << 24)); // ARGB格式
            
            // 将对象设置为不可选中
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            
            // ** 关键设置：仅在当前周期可见 **
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, GetTimeframeFlag(_Period)); 
        }
        */

        if (ObjectFind(0, name) != -1) ObjectDelete(0, name);
        if (ObjectFind(0, text_name) != -1) ObjectDelete(0, text_name); // 确保旧文本对象被删除

        if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price_start, time2, price_end))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, (int)rect_color | (HIGHLIGHT_ALPHA << 24));
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);

            // 设置周期可见性
            int tf_flag = GetTimeframeFlag(_Period);
            if (tf_flag != 0)
                ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, tf_flag);
            else
                ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

            // ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            // 🚨 核心修正：设置 OBJPROP_TEXT 作为对象列表的“说明” 🚨
            ObjectSetString(0, name, OBJPROP_TEXT, description_text);

            string description_text_level = description_text + " " + DoubleToString(level1, 3);

            // 3. 🚨 调用新函数绘制图表文本 🚨 1.0
            // DrawFiboHighlightText(text_name, description_text_level, time1, price_top, tf_flag);

            // 3. 🚨 修正调用新函数绘制图表文本 🚨 2.0
            // 使用 time_anchor 和 text_anchor_price，并传入 is_bullish
            DrawFiboHighlightText(text_name, description_text_level, time_anchor, text_anchor_price, tf_flag, is_bullish);
        }
        else
        {
            Print("无法创建 高亮 矩形对象: ", name, ", 错误: ", GetLastError());
            return;
        }
    }
}

/**
 * 绘制斐波那契高亮区域的文本说明 (OBJ_TEXT)
 * @param text_name: 文本对象的唯一名称 (应包含父矩形名称)
 * @param text_content: 要显示的文本内容 (例如 "H4 看跌斐波反转区域")
 * @param anchor_time: 文本的锚定时间 (矩形左侧时间)
 * @param anchor_price: 文本的锚定价格 (矩形顶部价格)
 * @param tf_flag: 文本对象的周期可见性位标志
 */
void DrawFiboHighlightText(string text_name, string text_content, datetime anchor_time, double anchor_price, int tf_flag, bool is_bullish)
{
    if (Is_EA_Mode) return;
    // 确保旧文本对象被删除
    if (ObjectFind(0, text_name) != -1) ObjectDelete(0, text_name);

    // 创建 OBJ_TEXT 对象
    if (ObjectCreate(0, text_name, OBJ_TEXT, 0, anchor_time, anchor_price))
    {
        ObjectSetString(0, text_name, OBJPROP_TEXT, text_content);
        
        // 设置颜色：确保与高亮背景色形成强烈对比 (使用黑色)
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, clrBlack); 
        
        // 设置字体和大小 (可根据需求调整)
        ObjectSetString(0, text_name, OBJPROP_FONT, "Arial"); 
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8); 
        
        // 默认1.0的设置
        // 设置锚点：左上角
        // ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        // ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

        // 🚨 修正2.0：根据看涨/看跌设置文本锚点 🚨
        if (is_bullish)
        {
            // 看涨斐波 (文本在 右下角)
            // 时间/价格锚点: CORNER_LEFT_UPPER (不变)
            ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            // 文本内部定位: 锚定在 文本自身的右下角
            ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
        }
        else
        {
            // 看跌斐波 (文本在 右上角)
            // 时间/价格锚点: CORNER_LEFT_UPPER (不变)
            ObjectSetInteger(0, text_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            // 文本内部定位: 锚定在 文本自身的右上角
            ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
        }
        
        // 关键优化：设置文本位置微调，稍微远离边角，以避免与边框重叠
        ObjectSetInteger(0, text_name, OBJPROP_XDISTANCE, 5); // 稍微右移 5 像素
        ObjectSetInteger(0, text_name, OBJPROP_YDISTANCE, 5); // 稍微下移 5 像素
        
        // 设置周期可见性
        if (tf_flag != 0) ObjectSetInteger(0, text_name, OBJPROP_TIMEFRAMES, tf_flag);
        else ObjectSetInteger(0, text_name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        
        // 确保文本对象不可选中
        ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, true);
    }
}

/*
// 绘制斐波那契矩形 (仅供 Grade A/S 使用)
void DrawFiboGradeZones(string sym, int idx, double sl, double close, bool bullish) {
   string name = "KT_Fib_" + IntegerToString(idx);
   double range = MathAbs(close - sl);
   datetime t1 = iTime(sym, 0, idx);
   datetime t2 = t1 + PeriodSeconds(0) * 30; // 延伸30根
   
   double level1, level2;
   if (bullish) {
      level1 = sl + range * 1.618;
      level2 = sl + range * 1.88;
   } else {
      level1 = sl - range * 1.618;
      level2 = sl - range * 1.88;
   }
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, level1, t2, level2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (bullish ? clrLightGreen : clrLightPink));
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}
*/

//+------------------------------------------------------------------+
//| DrawFiboGradeZones (最终完整版)
//| ------------------------------------------------------------------
//| 改进点：
//| 1. 接收外部 prefix，统一对象管理
//| 2. 使用 iTime 时间戳替代 K线索引，防止对象随行情漂移
//| 3. 具备存在性检查 (ObjectFind)
//+------------------------------------------------------------------+
void DrawFiboGradeZones(string sym, int idx, double sl, double close, bool bullish, string prefix)
{
   if (Is_EA_Mode)
   {
      return;
   }
   
   // 1. 基础计算
   double range = MathAbs(close - sl);
   
   // [关键改进] 获取该 K 线的精确时间作为唯一身份 ID
   // 使用 long 类型转换确保时间戳数字的完整性
   datetime bar_time = iTime(sym, 0, idx);
   string time_str = IntegerToString((long)bar_time);

   // 计算矩形的时间宽度 (默认向右延伸 30 根 K 线)
   datetime t2 = bar_time + PeriodSeconds(0) * 30; 
   
   // 定义斐波那契倍数 (TP1, TP2, TP3)
   double fib_levels[] = {1.618, 1.88,  2.618, 2.88,  4.236, 4.88};
   color  zone_colors[] = {clrLightGreen, clrSkyBlue, clrGold};
   
   // 如果是做空，调整颜色
   if (!bullish) {
       zone_colors[0] = clrLightPink; 
       zone_colors[1] = clrLightCoral; 
       zone_colors[2] = clrOrangeRed; 
   }

   // 循环绘制 3 个目标区域
   for(int k=0; k<3; k++)
   {
       // --- A. 构建基于时间的唯一对象名 ---
       // 格式: [前缀]Fib_[时间戳]_TP[k]
       // 例如: KTarget_v3_A1_Fib_167889200_TP1
       string obj_name = prefix + "Fib_" + time_str + "_TP" + IntegerToString(k+1);
       
       // --- B. 存在性检查与创建 ---
       if(ObjectFind(0, obj_name) < 0) 
       {
           ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, 0, 0, 0, 0);
           // 静态属性仅设置一次
           ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);     // 脚本列表中隐藏
           ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);// 不可选中
           ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);       // 背景显示
           ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);       // 开启填充
       }

       // --- C. 动态属性更新 (坐标/颜色) ---
       double level_start, level_end;
       if (bullish) {
           level_start = sl + range * fib_levels[k*2];
           level_end   = sl + range * fib_levels[k*2+1];
       } else {
           level_start = sl - range * fib_levels[k*2];
           level_end   = sl - range * fib_levels[k*2+1];
       }

       // 即使对象已存在，也更新坐标 (防止参数调整后位置不对)
       ObjectSetInteger(0, obj_name, OBJPROP_TIME1, bar_time);
       ObjectSetDouble (0, obj_name, OBJPROP_PRICE1, level_start);
       ObjectSetInteger(0, obj_name, OBJPROP_TIME2, t2);
       ObjectSetDouble (0, obj_name, OBJPROP_PRICE2, level_end);
       ObjectSetInteger(0, obj_name, OBJPROP_COLOR, zone_colors[k]);
   }
}