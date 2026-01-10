//+------------------------------------------------------------------+
//|                                                     Console1.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    datetime current_time = TimeCurrent();
    Print("-->[Console1.mq4:16]: current_time: ", current_time);

    //---
    datetime P1_time = Time[1];
    string time_id_str = TimeToString(P1_time, TIME_DATE | TIME_SECONDS);
    Print("-->[Console1.mq4:18]: time_id_str: ", time_id_str);

    string ids = StringFormat("_%d_", ChartID());
    Print("-->[Console1.mq4:21]: ChartID(): ", ChartID());
    Print("-->[Console1.mq4:21]: ids: ", ids);

    // 在全局或函数内部定义一个 3 行 4 列的二维数组
    int matrix[][4] = {
        {10, 11, 12, 13},
        {20, 21, 22, 23},
        {30, 31, 32, 33}};

    // 获取第一维（行）的大小 - 使用 ArrayRange(数组名, 0)
    int totalRows = ArrayRange(matrix, 0);

    // 获取第二维（列）的大小 - 使用 ArrayRange(数组名, 1)
    int totalCols = ArrayRange(matrix, 1);

    Print("数组总行数: ", totalRows);
    Print("数组总列数: ", totalCols);
    Print("--- 开始遍历 ---");

    // 外部循环：遍历每一行
    for (int i = 0; i < totalRows; i++) // i 是行索引
    {
        // 内部循环：遍历当前行的每一列
        for (int j = 0; j < totalCols; j++) // j 是列索引
        {
            // 访问元素并打印到日志（专家日志或终端日志）
            // 使用 DoubleToString 是为了格式化输出，确保日志可读性
            Print("Element[", i, "][", j, "] = ", matrix[i][j]);
        }
    }

    Print("--- 遍历结束 ---");
}
//+------------------------------------------------------------------+
