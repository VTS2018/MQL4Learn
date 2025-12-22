//+------------------------------------------------------------------+
//|                                       Test_RealData_Evaluate.mq4 |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 22.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, YourName"
#property link "https://mql5.com"
#property version "1.00"
#property strict
#include <K5/K_Data.mqh>
#include <K7/K_Logic.mqh>
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+

void OnStart()
{
   //---
   Run_EvaluateSignal_Unit_Test();
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 🧪 Run_EvaluateSignal_Unit_Test (实盘数据驱动版)
//| 功能: 扫描历史K线，自动识别潜在的几何结构，并传入 EvaluateSignal 进行压力测试
//+------------------------------------------------------------------+
void Run_EvaluateSignal_Unit_Test()
{
   int history_depth = 1000; // 测试最近 1000 根 K 线
   Print("=== [Start] EvaluateSignal 实盘数据遍历测试 | Range: ", history_depth, " Bars ===");

   // 统计计数器
   int count_S=0, count_A=0, count_B=0, count_C=0, count_D=0, count_F=0;
   int valid_signals = 0;
   int error_count = 0;

   // 1. 确定扫描范围 (防止数组越界)
   int limit = MathMin(history_depth, Bars - 50); 

   // 2. 外层循环：寻找锚点 (Anchor / P1)
   // 从旧往新扫 (limit -> 1)
   for (int i = limit; i >= 20; i--)
   {
      // --- [测试场景 A] 寻找潜在的【看涨】结构 (Bottom) ---
      // 简单判别：当前是局部低点 (Swing Low)
      if (Low[i] < Low[i-1] && Low[i] < Low[i+1]) 
      {
         int anchor_idx = i;
         double p1 = Open[anchor_idx]; // 实盘 P1: 锚点开盘价
         double sl = p1;               // 实盘 SL: 设为 P1

         // 3. 内层循环：向右(未来)寻找 P2 和 突破点 (Breakout)
         // 搜索未来 20 根 K 线
         double current_p2 = Low[i]; // 初始 P2
         
         for (int k = 1; k <= 20; k++)
         {
            int j = i - k; // j 是比 i 更新的 K 线 (Breakout Candidate)
            if (j < 1) break;

            // 动态维护 P2 (i 到 j 之间的最高价)
            double high_in_range = High[iHighest(Symbol(), Period(), MODE_HIGH, k, j+1)];
            double p2 = high_in_range;

            // 检查突破: 收盘价 > P2 (CB)
            if (Close[j] > p2)
            {
               // 🔥 捕获到一个实盘的 "拟合信号" 🔥
               // 立即调用 EvaluateSignal 进行测试
               SignalQuality sq = EvaluateSignal(Symbol(), Period(), anchor_idx, j, p1, p2, sl, true);

               // 健壮性检查
               if (!Test_ValidateGrade(sq.grade)) {
                  Print(" [致命错误] BULL 信号返回非法 Grade: ", sq.grade, " @ Time: ", Time[j]);
                  error_count++;
               } else {
                  // 统计合法的评级分布
                  UpdateStats(sq.grade, count_S, count_A, count_B, count_C, count_D, count_F);
                  valid_signals++;
               }
               
               // 找到一个突破就跳出内层循环，继续找下一个锚点
               break; 
            }
         }
      }

      // --- [测试场景 B] 寻找潜在的【看跌】结构 (Top) ---
      // 简单判别：当前是局部高点 (Swing High)
      if (High[i] > High[i-1] && High[i] > High[i+1]) 
      {
         int anchor_idx = i;
         double p1 = Open[anchor_idx]; // 锚点开盘价
         double sl = p1;

         for (int k = 1; k <= 20; k++)
         {
            int j = i - k; 
            if (j < 1) break;

            // 动态维护 P2 (i 到 j 之间的最低价)
            double low_in_range = Low[iLowest(Symbol(), Period(), MODE_LOW, k, j+1)];
            double p2 = low_in_range;

            // 检查突破: 收盘价 < P2 (CB)
            if (Close[j] < p2)
            {
               // 🔥 调用 EvaluateSignal 测试看跌逻辑 🔥
               SignalQuality sq = EvaluateSignal(Symbol(), Period(), anchor_idx, j, p1, p2, sl, false);

               if (!Test_ValidateGrade(sq.grade)) {
                  Print(" [致命错误] BEAR 信号返回非法 Grade: ", sq.grade, " @ Time: ", Time[j]);
                  error_count++;
               } else {
                  UpdateStats(sq.grade, count_S, count_A, count_B, count_C, count_D, count_F);
                  valid_signals++;
               }
               break; 
            }
         }
      }
   }

   // 4. 打印最终测试报告
   Print("----------------------------------------");
   Print(" 实盘回溯测试报告 (Total Signals Tested: ", valid_signals, ")");
   Print("----------------------------------------");
   Print("GRADE_S (完美) : ", count_S);
   Print("GRADE_A (优秀) : ", count_A);
   Print("GRADE_B (良好) : ", count_B);
   Print("GRADE_C (勉强) : ", count_C);
   Print("GRADE_D (淘汰) : ", count_D);
   Print("GRADE_F (无效) : ", count_F);
   Print("非法错误数     : ", error_count);
   Print("----------------------------------------");
   
   if (error_count == 0 && valid_signals > 0) 
      Print(" 测试通过：EvaluateSignal 在实盘历史数据中运行稳定，无崩溃或非法返回值。");
   else if (valid_signals == 0)
      Print(" 警告：在指定范围内未找到符合条件的几何形态，请扩大 history_depth 或切换周期。");
   else
      Print(" 测试失败：存在未定义的返回值！请检查日志。");
}

// 辅助函数：验证 Grade 是否在 Enum 定义范围内
bool Test_ValidateGrade(int grade)
{
   // 使用 explicit cast 检查是否在枚举范围内
   switch(grade) {
      case GRADE_S: return true;
      case GRADE_A: return true;
      case GRADE_B: return true;
      case GRADE_C: return true;
      case GRADE_D: return true;
      case GRADE_F: return true;
      case GRADE_NONE: return true;
      default: return false; // 捕获未定义的整数 (如 999)
   }
}

// 辅助函数：更新统计数据
void UpdateStats(int grade, int &s, int &a, int &b, int &c, int &d, int &f)
{
   switch(grade) {
      case GRADE_S: s++; break;
      case GRADE_A: a++; break;
      case GRADE_B: b++; break;
      case GRADE_C: c++; break;
      case GRADE_D: d++; break;
      case GRADE_F: f++; break;
   }
}