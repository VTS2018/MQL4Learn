//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 🧪 Unit Test: EvaluateSignal 内核自检系统
//| 功能: 扫描历史数据，验证评分函数的返回值有效性及分布
//| 依赖: 指标内部的 CheckKTarget... 函数及 K_Logic_v3.mqh
//+------------------------------------------------------------------+
void Run_EvaluateSignal_Unit_Test_v1()
{
   Print("=== [Start] EvaluateSignal Unit Test | Range: ", Test_History_Bars, " Bars ===");

   int count_S = 0;
   int count_A = 0;
   int count_B = 0;
   int count_C = 0;
   int count_D = 0;
   int count_F = 0;
   int total_signals = 0;
   int error_count = 0;
   
   // 限制测试范围不超过实际 K 线数
   int limit = MathMin(Test_History_Bars, Bars - Lookahead_Bottom - 1);

   // 开始历史循环扫描
   for (int i = limit; i >= 1; i--)
   {
      // -----------------------------------------------------------
      // [测试场景 A] 做多信号 (Bullish)
      // -----------------------------------------------------------
      // 直接调用指标内部现有的函数
      if (IsKTargetBottom(i, Bars))
      {
         double p1 = Open[i];
         
         // 模拟 P2 查找 (简化版，仅为了触发评分)
         double p2 = 0; 
         for(int k=1; k<50; k++) { if(Close[i+k] > Open[i+k]) { p2=Close[i+k]; break; } }
         if(p2==0) p2 = p1 * 1.001;
         
         // 模拟结构性止损 (搜索 Lookback + Lookahead 范围内的最低点)
         int search_start = MathMax(0, i - Lookahead_Bottom);
         int count_bars   = Lookback_Bottom + Lookahead_Bottom;
         int sl_index     = iLowest(NULL, 0, MODE_LOW, count_bars, search_start);
         if(sl_index < 0) sl_index = i;
         double sl = Low[sl_index];

         // 寻找突破点 j (Breakout)
         for (int j = i - 1; j >= MathMax(0, i - Max_Signal_Lookforward); j--)
         {
             if (Close[j] > p1) // 突破 P1
             {
                 // >>> 核心测试点：调用内核 EvaluateSignal <<<
                 SignalQuality sq = EvaluateSignal(Symbol(), Period(), i, j, p1, p2, sl, true);
                 
                 // 验证结果合法性
                 if (Test_ValidateGrade(sq.grade))
                 {
                     total_signals++;
                     Test_UpdateStats(sq.grade, count_S, count_A, count_B, count_C, count_D, count_F);
                     
                     if (Test_Print_Detail)
                        Print("Pass: [BUY] Time:", TimeToString(Time[j]), " Grade:", sq.description);
                 }
                 else
                 {
                     error_count++;
                     Print(" ERROR: [BUY] Invalid Enum Value! Val: ", (int)sq.grade, " @ ", TimeToString(Time[j]));
                 }
                 break; // 找到一个突破即跳出，避免重复
             }
         }
      }
      
      // -----------------------------------------------------------
      // [测试场景 B] 做空信号 (Bearish)
      // -----------------------------------------------------------
      if (IsKTargetTop(i, Bars))
      {
         double p1 = Open[i];
         
         double p2 = 0;
         for(int k=1; k<50; k++) { if(Close[i+k] < Open[i+k]) { p2=Close[i+k]; break; } }
         if(p2==0) p2 = p1 * 0.999;
         
         int search_start = MathMax(0, i - Lookahead_Top);
         int count_bars   = Lookback_Top + Lookahead_Top;
         int sl_index     = iHighest(NULL, 0, MODE_HIGH, count_bars, search_start);
         if(sl_index < 0) sl_index = i;
         double sl = High[sl_index];
         
         for (int j = i - 1; j >= MathMax(0, i - Max_Signal_Lookforward); j--)
         {
             if (Close[j] < p1)
             {
                 SignalQuality sq = EvaluateSignal(Symbol(), Period(), i, j, p1, p2, sl, false);
                 
                 if (Test_ValidateGrade(sq.grade))
                 {
                     total_signals++;
                     Test_UpdateStats(sq.grade, count_S, count_A, count_B, count_C, count_D, count_F);
                 }
                 else
                 {
                     error_count++;
                     Print(" ERROR: [SELL] Invalid Enum Value! Val: ", (int)sq.grade);
                 }
                 break;
             }
         }
      }
   }

   // 打印最终测试报告
   Print("----------------------------------------");
   Print(" 单元测试统计报告 (Total: ", total_signals, ")");
   Print("----------------------------------------");
   Print("GRADE_S (完美) : ", count_S);
   Print("GRADE_A (优秀) : ", count_A);
   Print("GRADE_B (良好) : ", count_B);
   Print("GRADE_C (勉强) : ", count_C);
   Print("GRADE_D (淘汰) : ", count_D);
   Print("GRADE_F (无效) : ", count_F);
   Print("非法错误数     : ", error_count);
   Print("----------------------------------------");
   
   if (error_count == 0) Print(" 测试通过：内核逻辑健壮。");
   else                  Print(" 测试失败：存在未定义的返回值！");
}

//+------------------------------------------------------------------+
//| 🧪 Unit Test: EvaluateSignal 内核自检系统 (修正版)
//| 修复日志: 补齐了 [SELL] 信号的详细日志输出
//+------------------------------------------------------------------+
void Run_EvaluateSignal_Unit_Test()
{
   Print("=== [Start] EvaluateSignal Unit Test | Range: ", Test_History_Bars, " Bars ===");

   int count_S = 0;
   int count_A = 0;
   int count_B = 0;
   int count_C = 0;
   int count_D = 0;
   int count_F = 0;
   int total_signals = 0;
   int error_count = 0;
   
   // 限制测试范围
   int limit = MathMin(Test_History_Bars, Bars - Lookahead_Bottom - 1);
   Print("--->[K_Test.mqh:154]: limit: ", limit);

   // 开始历史循环扫描
   for (int i = limit; i >= 1; i--)
   {
      // -----------------------------------------------------------
      // [测试场景 A] 做多信号 (Bullish)
      // -----------------------------------------------------------
      if (IsKTargetBottom(i, Bars))
      {
         double p1 = Open[i];
         
         double p2 = 0; 
         for(int k=1; k<50; k++) { if(Close[i+k] > Open[i+k]) { p2=Close[i+k]; break; } }
         if(p2==0) p2 = p1 * 1.001;
         
         int search_start = MathMax(0, i - Lookahead_Bottom);
         int count_bars   = Lookback_Bottom + Lookahead_Bottom;
         int sl_index     = iLowest(NULL, 0, MODE_LOW, count_bars, search_start);
         if(sl_index < 0) sl_index = i;
         double sl = Low[sl_index];

         for (int j = i - 1; j >= MathMax(0, i - Max_Signal_Lookforward); j--)
         {
             if (Close[j] > p1) 
             {
                 SignalQuality sq = EvaluateSignal(Symbol(), Period(), i, j, p1, p2, sl, true);
                 
                 if (Test_ValidateGrade(sq.grade))
                 {
                     total_signals++;
                     Test_UpdateStats(sq.grade, count_S, count_A, count_B, count_C, count_D, count_F);
                     
                     // [日志] 做多详情
                     if (Test_Print_Detail)
                        Print("Pass: [BUY] Time:", TimeToString(Time[j]), " Grade:", sq.description);
                 }
                 else
                 {
                     error_count++;
                     Print(" ERROR: [BUY] Invalid Enum! Val: ", (int)sq.grade, " @ ", TimeToString(Time[j]));
                 }
                 break; 
             }
         }
      }
      
      // -----------------------------------------------------------
      // [测试场景 B] 做空信号 (Bearish)
      // -----------------------------------------------------------
      if (IsKTargetTop(i, Bars))
      {
         double p1 = Open[i];
         
         double p2 = 0;
         // 查找左侧阴线作为 P2 (支撑)
         for(int k=1; k<50; k++) { if(Close[i+k] < Open[i+k]) { p2=Close[i+k]; break; } }
         if(p2==0) p2 = p1 * 0.999;
         
         int search_start = MathMax(0, i - Lookahead_Top);
         int count_bars   = Lookback_Top + Lookahead_Top;
         int sl_index     = iHighest(NULL, 0, MODE_HIGH, count_bars, search_start);
         if(sl_index < 0) sl_index = i;
         double sl = High[sl_index];
         
         for (int j = i - 1; j >= MathMax(0, i - Max_Signal_Lookforward); j--)
         {
             if (Close[j] < p1)
             {
                 SignalQuality sq = EvaluateSignal(Symbol(), Period(), i, j, p1, p2, sl, false);
                 
                 if (Test_ValidateGrade(sq.grade))
                 {
                     total_signals++;
                     Test_UpdateStats(sq.grade, count_S, count_A, count_B, count_C, count_D, count_F);

                     // ✅ [修复] 补齐做空信号的日志打印
                     if (Test_Print_Detail)
                        Print("Pass: [SELL] Time:", TimeToString(Time[j]), " Grade:", sq.description);
                 }
                 else
                 {
                     error_count++;
                     Print(" ERROR: [SELL] Invalid Enum! Val: ", (int)sq.grade);
                 }
                 break;
             }
         }
      }
   }

   // 打印最终测试报告
   Print("----------------------------------------");
   Print(" 单元测试统计报告 (Total: ", total_signals, ")");
   Print("----------------------------------------");
   Print("GRADE_S (完美) : ", count_S);
   Print("GRADE_A (优秀) : ", count_A);
   Print("GRADE_B (良好) : ", count_B);
   Print("GRADE_C (勉强) : ", count_C);
   Print("GRADE_D (淘汰) : ", count_D);
   Print("GRADE_F (无效) : ", count_F);
   Print("非法错误数     : ", error_count);
   Print("----------------------------------------");
   
   if (error_count == 0) Print(" 测试通过：内核逻辑健壮。");
   else                  Print(" 测试失败：存在未定义的返回值！");
}

// 辅助函数：验证 Grade 是否在 Enum 定义范围内
bool Test_ValidateGrade(int grade)
{
   switch(grade)
   {
      case GRADE_S: return true;
      case GRADE_A: return true;
      case GRADE_B: return true;
      case GRADE_C: return true;
      case GRADE_D: return true;
      case GRADE_F: return true;
      default: return false;
   }
}

// 辅助函数：更新统计
void Test_UpdateStats(int grade, int &s, int &a, int &b, int &c, int &d, int &f)
{
   switch(grade)
   {
      case GRADE_S: s++; break;
      case GRADE_A: a++; break;
      case GRADE_B: b++; break;
      case GRADE_C: c++; break;
      case GRADE_D: d++; break;
      case GRADE_F: f++; break;
   }
}