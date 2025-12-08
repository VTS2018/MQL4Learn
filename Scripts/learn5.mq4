//+------------------------------------------------------------------+
//|                                                       learn5.mq4 |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 08.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link      "https://mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+

void OnStart()
{
   //---
   // 在全局或函数内部定义一个 3 行 4 列的二维数组
   int matrix = {
       {10, 11, 12, 13},
       {20, 21, 22, 23},
       {30, 31, 32, 33}};

   // 获取第一维（行）的大小
   int totalRows = ArraySize(matrix);

   // 获取第二维（列）的大小。注意：对于静态二维数组，所有行的列数是相同的。
   int totalCols = ArraySize(matrix);

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
