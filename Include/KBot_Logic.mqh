//+------------------------------------------------------------------+
//|                                                   KBot_Logic.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 09.12.2025 - Initial release                                     |
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


//+------------------------------------------------------------------+
//| 函数: 读取 iCustom 指标值 (解决了通信问题)
//+------------------------------------------------------------------+
double GetIndicatorSignal(int buffer_index, int shift)
{
   // iCustom 必须按照指标的输入参数顺序传递
   return iCustom(
       _Symbol,
       _Period,
       IndicatorName,

       // --- 传递 KTarget_Finder5 的所有输入参数 ---
       Indi_Is_EA_Mode,
       Indi_Smart_Tuning,
       Indi_Scan_Range,
       Indi_Lookahead_Bottom,
       Indi_Lookback_Bottom,
       Indi_Lookahead_Top,
       Indi_Lookback_Top,
       Indi_Max_Signal_Look,
       Indi_DB_Threshold,
       Indi_LLHH_Candles,
       Indi_Timer_Interval_Seconds,
       Indi_DrawFibonacci, // 即使不画线，为了函数签名匹配也要传
       // ... (在这里添加您指标所需的其他关键参数) ...

       // --- 缓冲区和 K 线位移 ---
       buffer_index, // 读取哪个缓冲区
       shift);       // 读取哪根K线
}

//+------------------------------------------------------------------+
//| 批量获取 KTarget_Finder5 所有缓冲区数据                          |
//+------------------------------------------------------------------+
KBarSignal GetIndicatorBarData(int shift)
{
    KBarSignal data;
    
    // 依次调用 iCustom 获取所有 4 个缓冲区的数据 (4次 iCustom 调用)
    data.BullishStopLossPrice = GetIndicatorSignal(0, shift); // Buffer 0
    data.BearishStopLossPrice = GetIndicatorSignal(1, shift); // Buffer 1
    data.BullishReferencePrice = GetIndicatorSignal(2, shift); // Buffer 2
    data.BearishReferencePrice = GetIndicatorSignal(3, shift); // Buffer 3
    
    data.OpenTime = Time[shift];
    return data;
}
//+------------------------------------------------------------------+
//| 开始 下面这些函数 暂时不用了 留着做个备份而已
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| L2c: 斐波那契反转区域过滤 (Context Filter)
//| 检查当前反转信号是否位于前一个趋势的 2.618-3.0 衰竭区
//| 1.0：这是初阶版本 只能用来查找一个斐波区域
//+------------------------------------------------------------------+
bool IsReversalInFibZone_V1(int current_shift, int current_type)
{
   // 1. 确定我们要找的前一个信号类型
   // 如果当前是 SELL，我们要找之前的 BUY；反之亦然。
   int search_type = (current_type == OP_SELL) ? OP_BUY : OP_SELL;

   // 2. 向历史回溯扫描 (从当前信号的前一根 K 线开始)
   // 我们限制回溯范围，比如最多往前找 100 根，太远就没有因果关系了
   int max_history_scan = 100;
   int found_prev_shift = -1;

   KBarSignal prev_data; // 用于存储找到的历史信号数据
   // 🚨 修正：初始化 prev_data 以解决 uninitialized variable 错误 🚨
   ZeroMemory(prev_data);

   for (int i = current_shift + 1; i < current_shift + max_history_scan; i++)
   {
      KBarSignal temp_data = GetIndicatorBarData(i);

      // 检查是否有由于 search_type 指定的信号
      bool is_target_found = false;

      if (search_type == OP_BUY)
      {
         // 找看涨信号 (有质量代码，且有有效的 SL)
         // if (temp_data.BullishReferencePrice > 0 && temp_data.BullishStopLossPrice > 0)
         if (temp_data.BullishReferencePrice != (double)EMPTY_VALUE && temp_data.BullishReferencePrice != 0.0)
            is_target_found = true;
      }
      else
      {
         // 找看跌信号
         // if (temp_data.BearishReferencePrice > 0 && temp_data.BearishStopLossPrice > 0)
         if (temp_data.BearishReferencePrice != (double)EMPTY_VALUE && temp_data.BearishReferencePrice != 0.0)
            is_target_found = true;
      }

      if (is_target_found)
      {
         found_prev_shift = i;
         prev_data = temp_data;
         Print("---->[KTarget_FinderBot.mq4:1098]: shift= ", i, "--", prev_data.BullishStopLossPrice, "--", prev_data.BearishStopLossPrice, "--", prev_data.BullishReferencePrice, "--", prev_data.BearishReferencePrice);
         break; // 找到了最近的一个反向信号，停止扫描
      }
   }
   
   // 如果没找到前一个反向信号，无法判断上下文，视策略而定 (这里默认返回 false 过滤掉，或者 true 放行)
   if (found_prev_shift == -1)
   {
       // Print("未找到前置反向信号，无法计算斐波那契区域。");
       return false; // 严格模式：没参考就不做
   }

   // 3. 计算前一个信号的风险波幅 (Risk)
   double prev_entry = Close[found_prev_shift]; // 假设信号 K 收盘价为入场
   double prev_sl = 0;
   double risk = 0;

   if (search_type == OP_BUY)
   {
      prev_sl = prev_data.BullishStopLossPrice;
      risk = prev_entry - prev_sl; // 看涨：入场 - 止损
   }
   else
   {
      prev_sl = prev_data.BearishStopLossPrice;
      risk = prev_sl - prev_entry; // 看跌：止损 - 入场
   }

   // 确保风险值有效
   if (risk <= 0) return false;

   // 4. 计算 2.618 - 3.00 区域
   // 注意：扩展是沿着前一个趋势方向延伸的
   double zone_low = 0;
   double zone_high = 0;

   if (search_type == OP_BUY)
   {
      // 前一个是涨势，目标位在上方
      zone_low  = prev_entry + (risk * 2.618);
      zone_high = prev_entry + (risk * 3.000);
   }
   else
   {
      // 前一个是跌势，目标位在下方
      // 下跌时，数值越小越远，所以 3.0 是 zone_low (数值小)，2.618 是 zone_high
      zone_low  = prev_entry - (risk * 3.000); 
      zone_high = prev_entry - (risk * 2.618);
   }

   // 1.0 的检查非常的严格
   // 5. 检查当前信号价格是否在区域内
   double current_price = Close[current_shift]; // 当前信号 K 线的收盘价

   // 添加一点容差 (例如 10% 的 Risk 距离)，这就是您说的“附近”
   double tolerance = risk * 0.1; 

   bool in_zone = false;
   if (current_price >= (zone_low - tolerance) && current_price <= (zone_high + tolerance))
   {
      in_zone = true;
   }

   if (in_zone)
   {
       string type_str = (current_type == OP_SELL) ? "看跌" : "看涨";
       Print(" L2c 斐波过滤通过: 当前", type_str, "信号 @ ", current_price, 
             " 位于前值 Fib [2.618-3.0] 区域 (", DoubleToString(zone_low, _Digits), "-", DoubleToString(zone_high, _Digits), ")");
       return true;
   }
   else
   {
       // Print("L2c 斐波过滤: 当前信号不在前值 Fib 衰竭区。");
       return false;
   }
}

//+------------------------------------------------------------------+
//| L2c: 斐波那契反转区域过滤 (Context Filter)
//| 2.0：修改成区域触碰 降低严格程度
//+------------------------------------------------------------------+
bool IsReversalInFibZone_V2(int current_shift, int current_type)
{
   // 1. 确定我们要找的前一个信号类型
   // 如果当前是 SELL，我们要找之前的 BUY；反之亦然。
   int search_type = (current_type == OP_SELL) ? OP_BUY : OP_SELL;

   // 2. 向历史回溯扫描 (从当前信号的前一根 K 线开始)
   // 我们限制回溯范围，比如最多往前找 100 根，太远就没有因果关系了
   int max_history_scan = 100;
   int found_prev_shift = -1;

   KBarSignal prev_data; // 用于存储找到的历史信号数据
   // 🚨 修正：初始化 prev_data 以解决 uninitialized variable 错误 🚨
   ZeroMemory(prev_data);

   for (int i = current_shift + 1; i < current_shift + max_history_scan; i++)
   {
      KBarSignal temp_data = GetIndicatorBarData(i);

      // 检查是否有由于 search_type 指定的信号
      bool is_target_found = false;

      if (search_type == OP_BUY)
      {
         // 找看涨信号 (有质量代码，且有有效的 SL)
         // if (temp_data.BullishReferencePrice > 0 && temp_data.BullishStopLossPrice > 0)
         if (temp_data.BullishReferencePrice != (double)EMPTY_VALUE && temp_data.BullishReferencePrice != 0.0)
            is_target_found = true;
      }
      else
      {
         // 找看跌信号
         // if (temp_data.BearishReferencePrice > 0 && temp_data.BearishStopLossPrice > 0)
         if (temp_data.BearishReferencePrice != (double)EMPTY_VALUE && temp_data.BearishReferencePrice != 0.0)
            is_target_found = true;
      }

      if (is_target_found)
      {
         found_prev_shift = i;
         prev_data = temp_data;
         Print("---->[KTarget_FinderBot.mq4:1098]: shift= ", i, "--", prev_data.BullishStopLossPrice, "--", prev_data.BearishStopLossPrice, "--", prev_data.BullishReferencePrice, "--", prev_data.BearishReferencePrice);
         break; // 找到了最近的一个反向信号，停止扫描
      }
   }
   
   // 如果没找到前一个反向信号，无法判断上下文，视策略而定 (这里默认返回 false 过滤掉，或者 true 放行)
   if (found_prev_shift == -1)
   {
       // Print("未找到前置反向信号，无法计算斐波那契区域。");
       return false; // 严格模式：没参考就不做
   }

   // 3. 计算前一个信号的风险波幅 (Risk)
   double prev_entry = Close[found_prev_shift]; // 假设信号 K 收盘价为入场
   double prev_sl = 0;
   double risk = 0;

   if (search_type == OP_BUY)
   {
      prev_sl = prev_data.BullishStopLossPrice;
      risk = prev_entry - prev_sl; // 看涨：入场 - 止损
   }
   else
   {
      prev_sl = prev_data.BearishStopLossPrice;
      risk = prev_sl - prev_entry; // 看跌：止损 - 入场
   }
   // 确保风险值有效
   if (risk <= 0) return false;

   // 4. 计算 2.618 - 3.00 区域
   // 注意：扩展是沿着前一个趋势方向延伸的
   double zone_low = 0;
   double zone_high = 0;

   if (search_type == OP_BUY)
   {
      // 前一个是涨势，目标位在上方
      // zone_low  = prev_entry + (risk * 2.618);
      // Print("--->[KTarget_FinderBot.mq4:1127]: zone_low: ", zone_low);
      // zone_high = prev_entry + (risk * 3.000);
      // Print("--->[KTarget_FinderBot.mq4:1129]: zone_high: ", zone_high);

      // 2.0计算 1.618-1.88；2.618-2.88；4.236-4.88；6-7
      zone_low = prev_sl + (risk * 1.618);
      zone_low  = NormalizeDouble(zone_low, _Digits);
      Print("--->[KTarget_FinderBot.mq4:1133]: zone_low: ", DoubleToString(zone_low, _Digits));
      zone_high = prev_sl + (risk * 1.88);
      zone_high  = NormalizeDouble(zone_high, _Digits);
      Print("--->[KTarget_FinderBot.mq4:1135]: zone_high: ", DoubleToString(zone_high, _Digits));

      // zone_low = prev_sl + (risk * 2.618);
      // Print("--->[KTarget_FinderBot.mq4:1138]: zone_low: ", zone_low);
      // zone_high = prev_sl + (risk * 2.88);
      // Print("--->[KTarget_FinderBot.mq4:1140]: zone_high: ", zone_high);

      // zone_low = prev_sl + (risk * 4.236);
      // Print("--->[KTarget_FinderBot.mq4:1143]: zone_low: ", zone_low);
      // zone_high = prev_sl + (risk * 4.88);
      // Print("--->[KTarget_FinderBot.mq4:1145]: zone_high: ", zone_high);

      // zone_low = prev_sl + (risk * 5);
      // Print("--->[KTarget_FinderBot.mq4:1148]: zone_low: ", zone_low);
      // zone_high = prev_sl + (risk * 6);
      // Print("--->[KTarget_FinderBot.mq4:1150]: zone_high: ", zone_high);
   }
   else
   {
      // 前一个是跌势，目标位在下方
      // 下跌时，数值越小越远，所以 3.0 是 zone_low (数值小)，2.618 是 zone_high
      // zone_low  = prev_entry - (risk * 3.000); 
      // zone_high = prev_entry - (risk * 2.618);

      // 2.0 NormalizeDouble(raw_fibo_price, _Digits)
      zone_low  = prev_sl - (risk * 1.618);
      zone_low  = NormalizeDouble(zone_low, _Digits);
      Print("--->[KTarget_FinderBot.mq4:1161]: zone_low: ", DoubleToString(zone_low, _Digits));
      zone_high = prev_sl - (risk * 1.88);
      zone_high = NormalizeDouble(zone_high, _Digits);
      Print("--->[KTarget_FinderBot.mq4:1163]: zone_high: ", DoubleToString(zone_high, _Digits));

      // zone_low  = prev_sl - (risk * 2.618);
      // zone_low  = NormalizeDouble(zone_low, _Digits);
      // Print("--->[KTarget_FinderBot.mq4:1168]: zone_low: ", DoubleToString(zone_low, _Digits));
      // zone_high = prev_sl - (risk * 2.88);
      // zone_high = NormalizeDouble(zone_high, _Digits);
      // Print("--->[KTarget_FinderBot.mq4:1170]: zone_high: ", DoubleToString(zone_high, _Digits));
      
      // zone_low  = prev_sl - (risk * 4.236);
      // zone_low  = NormalizeDouble(zone_low, _Digits);
      // Print("--->[KTarget_FinderBot.mq4:1173]: zone_low: ", DoubleToString(zone_low, _Digits));
      // zone_high = prev_sl - (risk * 4.88);
      // zone_high = NormalizeDouble(zone_high, _Digits);
      // Print("--->[KTarget_FinderBot.mq4:1175]: zone_high: ", DoubleToString(zone_high, _Digits));

      // zone_low  = prev_sl - (risk * 5);
      // zone_low  = NormalizeDouble(zone_low, _Digits);
      // Print("--->[KTarget_FinderBot.mq4:1178]: zone_low: ", DoubleToString(zone_low, _Digits));
      // zone_high = prev_sl - (risk * 6);
      // zone_high = NormalizeDouble(zone_high, _Digits);
      // Print("--->[KTarget_FinderBot.mq4:1180]: zone_high: ", DoubleToString(zone_high, _Digits));
   }
   
   /*
   // 1.0 的检查非常的严格
   // 5. 检查当前信号价格是否在区域内
   double current_price = Close[current_shift]; // 当前信号 K 线的收盘价

   // 添加一点容差 (例如 10% 的 Risk 距离)，这就是您说的“附近”
   double tolerance = risk * 0.1;

   bool in_zone = false;
   if (current_price >= (zone_low - tolerance) && current_price <= (zone_high + tolerance))
   {
      in_zone = true;
   }

   if (in_zone)
   {
       string type_str = (current_type == OP_SELL) ? "看跌" : "看涨";
       Print(" L2c 斐波过滤通过: 当前", type_str, "信号 @ ", current_price, 
             " 位于前值 Fib [2.618-3.0] 区域 (", DoubleToString(zone_low, _Digits), "-", DoubleToString(zone_high, _Digits), ")");
       return true;
   }
   else
   {
       // Print("L2c 斐波过滤: 当前信号不在前值 Fib 衰竭区。");
       return false;
   }
   */

   // =========================================================================
   // 🚨 5. 核心修正：检查当前信号 K 线是否触碰了区域 (High/Low) 🚨
   // =========================================================================
   double current_low = Low[current_shift];
   double current_high = High[current_shift];
   // 添加容差 (例如 10% 的 Risk 距离)，即您说的“附近”
   double tolerance = risk * 0.1;
   tolerance = NormalizeDouble(tolerance, _Digits);
   Print("--->[KTarget_FinderBot.mq4:1174]: tolerance: ", DoubleToString(tolerance, _Digits));

   // 计算带容差的检查区域
   double check_zone_low  = zone_low - tolerance;
   double check_zone_high = zone_high + tolerance;
   
   bool is_touching = false;
   
   // K 线范围 [current_low, current_high] 是否与目标区域 [check_zone_low, check_zone_high] 有重叠
   // 只要 K 线的最低点低于区域的最高点 AND K 线的最高点高于区域的最低点，即视为触碰。
   if (current_low <= check_zone_high && current_high >= check_zone_low)
   {
      is_touching = true;
   }
   
   if (is_touching)
   {
       string type_str = (current_type == OP_SELL) ? "看跌" : "看涨";
       
       Print(" L2c 斐波过滤通过 (触碰): 当前", type_str, "信号 @ K[", current_shift, "] 触碰前值 Fib [2.618-3.0] 区域 (", 
             DoubleToString(zone_low, _Digits), "-", DoubleToString(zone_high, _Digits), ")");
       return true;
   }
   else
   {
       // Print("L2c 斐波过滤: 当前信号未触碰前值 Fib 衰竭区。");
       return false;
   }
}

//+------------------------------------------------------------------+
//| L2c: 斐波那契反转区域过滤 (Context Filter)
//| 3.0 修正：检查多个自定义斐波那契区域是否被触碰 (High/Low)
//+------------------------------------------------------------------+
bool IsReversalInFibZone(int current_shift, int current_type)
{
    // --- 定义需要检查的斐波那契区域 ---
    // 格式: {Level1, Level2}，可以根据需要自由添加/修改
    double FiboLevels[4][2] = {
        {1.618, 1.88},
        {2.618, 2.88},
        {4.236, 4.88},
        {6, 7}
        // 您可以添加更多区域，例如 {0.618, 0.786}
    };
    int zones_count = ArrayRange(FiboLevels, 0);
    // Print("--->[KTarget_FinderBot.mq4:1273]: zones_count: ", zones_count);

   // 1. 确定我们要找的前一个信号类型
   // 如果当前是 SELL，我们要找之前的 BUY；反之亦然。
   int search_type = (current_type == OP_SELL) ? OP_BUY : OP_SELL;

   // 2. 向历史回溯扫描 (从当前信号的前一根 K 线开始)
   // 我们限制回溯范围，比如最多往前找 100 根，太远就没有因果关系了
   int max_history_scan = 100;
   int found_prev_shift = -1;

   KBarSignal prev_data; // 用于存储找到的历史信号数据
   // 🚨 修正：初始化 prev_data 以解决 uninitialized variable 错误 🚨
   ZeroMemory(prev_data);

   for (int i = current_shift + 1; i < current_shift + max_history_scan; i++)
   {
      KBarSignal temp_data = GetIndicatorBarData(i);

      // 检查是否有由于 search_type 指定的信号
      bool is_target_found = false;

      if (search_type == OP_BUY)
      {
         // 找看涨信号 (有质量代码，且有有效的 SL)
         // if (temp_data.BullishReferencePrice > 0 && temp_data.BullishStopLossPrice > 0)
         if (temp_data.BullishReferencePrice != (double)EMPTY_VALUE && temp_data.BullishReferencePrice != 0.0)
            is_target_found = true;
      }
      else
      {
         // 找看跌信号
         // if (temp_data.BearishReferencePrice > 0 && temp_data.BearishStopLossPrice > 0)
         if (temp_data.BearishReferencePrice != (double)EMPTY_VALUE && temp_data.BearishReferencePrice != 0.0)
            is_target_found = true;
      }

      if (is_target_found)
      {
         found_prev_shift = i;
         prev_data = temp_data;
         // Print("---->[KTarget_FinderBot.mq4:1098]: shift= ", i, "--", prev_data.BullishStopLossPrice, "--", prev_data.BearishStopLossPrice, "--", prev_data.BullishReferencePrice, "--", prev_data.BearishReferencePrice);
         break; // 找到了最近的一个反向信号，停止扫描
      }
   }
   
   // 如果没找到前一个反向信号，无法判断上下文，视策略而定 (这里默认返回 false 过滤掉，或者 true 放行)
   if (found_prev_shift == -1)
   {
       // Print("未找到前置反向信号，无法计算斐波那契区域。");
       return false; // 严格模式：没参考就不做
   }

   // 3. 计算前一个信号的风险波幅 (Risk)
   double prev_entry = Close[found_prev_shift]; // 假设信号 K 收盘价为入场
   double prev_sl = 0;
   double risk = 0;

   if (search_type == OP_BUY)
   {
      prev_sl = prev_data.BullishStopLossPrice;
      risk = prev_entry - prev_sl; // 看涨：入场 - 止损
   }
   else
   {
      prev_sl = prev_data.BearishStopLossPrice;
      risk = prev_sl - prev_entry; // 看跌：止损 - 入场
   }
   // 确保风险值有效
   if (risk <= 0) return false;

   // =========================================================================
   // 🚨 5. 核心修正：检查当前信号 K 线是否触碰了区域 (High/Low) 🚨
   // =========================================================================
   double current_low = Low[current_shift];
   double current_high = High[current_shift];
   // 添加容差 (例如 10% 的 Risk 距离)，即您说的“附近”
   double tolerance = risk * 0.1;
   tolerance = NormalizeDouble(tolerance, _Digits);
   // Print("--->[KTarget_FinderBot.mq4:1174]: tolerance: ", DoubleToString(tolerance, _Digits));

    // 5. 🚨 核心逻辑：循环检查所有定义的斐波那契区域 🚨
    for (int z = 0; z < zones_count; z++)
    {
        double level1 = FiboLevels[z][0];
        double level2 = FiboLevels[z][1];
        
        double zone_low = 0;
        double zone_high = 0;

        // 计算该区域的绝对价格边界
        if (search_type == OP_BUY) // 前一个是涨势 (向上延伸)
        {
            zone_low  = prev_sl + (risk * level1);
            // Print("---->[KTarget_FinderBot.mq4:1368]: level1: ", level1);
            zone_high = prev_sl + (risk * level2);
            // Print("---->[KTarget_FinderBot.mq4:1370]: level2: ", level2);
        }
        else // 前一个是跌势 (向下延伸)
        {
            // 下跌时，数值越小越远 (prev_entry - risk * level)
            zone_low  = prev_sl - (risk * level2);
            // Print("--->[KTarget_FinderBot.mq4:1376]: level2: ", level2);// level2 更大，价格更低 -> zone_low
            zone_high = prev_sl - (risk * level1);
            // Print("--->[KTarget_FinderBot.mq4:1378]: level1: ", level1);// level1 更小，价格更高 -> zone_high
        }

        // ==========================================================
        // 🚨 核心修正：立即进行精度修正 🚨
        // 确保 zone_low 和 zone_high 在后续计算和打印中是干净的
        // ==========================================================
        zone_low = NormalizeDouble(zone_low, _Digits);
        zone_high = NormalizeDouble(zone_high, _Digits);

        // 关键修正 2：使用 DoubleToString 格式化输出 (解决打印问题)
        // Print("--->[KTarget_FinderBot.mq4:1383]: zone_low: ", DoubleToString(zone_low, _Digits));
        // Print("--->[KTarget_FinderBot.mq4:1384]: zone_high: ", DoubleToString(zone_high, _Digits));

        // 6. 应用容差，计算实际检查区域
        double check_zone_low  = NormalizeDouble(zone_low - tolerance, _Digits);
        double check_zone_high = NormalizeDouble(zone_high + tolerance, _Digits);
        
        // 7. 触碰检查 (Touching Check)：K 线范围是否与目标区域有重叠
        // 只要 K-bar Low <= Zone High AND K-bar High >= Zone Low，即为触碰。
        if (current_low <= check_zone_high && current_high >= check_zone_low)
        {
            string type_str = (current_type == OP_SELL) ? "看跌" : "看涨";
            
            Print(" L2c 斐波过滤通过 (触碰): 当前", type_str, "信号 @ K[", current_shift, "] 触碰前值 Fib [",
                  DoubleToString(level1, 3), "-", DoubleToString(level2, 3), 
                  "] 区域 (", DoubleToString(zone_low, _Digits), "-", DoubleToString(zone_high, _Digits), ")");
            
            return true; // 只要命中任意一个区域，即视为通过过滤
        }
    }
    // 循环结束后，如果没有命中任何区域
    return false;
}

//+------------------------------------------------------------------+
//| 收集所有合格信号：扫描历史K线并分离看涨和看跌信号
//| @param bullish_list: 引用 - 存储看涨信号列表
//| @param bearish_list: 引用 - 存储看跌信号列表
//| 1.0 有可能造成 K[1] 确认信号的丢失
//+------------------------------------------------------------------+
void CollectAllSignals_V1(FilteredSignal &bullish_list[], FilteredSignal &bearish_list[])
{
    // 1. 清空数组，准备重新收集
    ArrayResize(bullish_list, 0); 
    ArrayResize(bearish_list, 0); 

    // -----------------------------------------------------------
    // 🚨 核心修正 1：获取现价基准 (使用当前 K 线的收盘价)
    // Close[0] 代表当前正在形成的 K 线的收盘价（或最新的价格）
    // -----------------------------------------------------------
    double current_price = Close[0];

    // 2. 开始扫描：从 K[1] 往历史左侧扫描
    for (int shift = 1; shift <= Indi_LastScan_Range; shift++)
    {
        // A. 批量读取所有缓冲区数据 (假设 GetIndicatorBarData 可用)
        KBarSignal data = GetIndicatorBarData(shift); 
        
        // -----------------------
        // 检查看涨信号
        // -----------------------
        if (data.BullishReferencePrice != (double)EMPTY_VALUE && 
            (int)data.BullishReferencePrice >= Min_Signal_Quality &&
            data.BullishStopLossPrice != (double)EMPTY_VALUE && data.BullishStopLossPrice != 0.0)
        {

            // --------------------------------------------------------
            // 🚨 核心修正 2：看涨信号价格区位过滤 (信号价必须低于现价)
            // 我们使用信号的确认收盘价 (Close[shift]) 作为其“价格”的代表
            // 为什么加入这个判断？就是为了保证 找到的 看涨信号 一定是小于现价的
            // 因为 如果扫描到 【高于现价的 历史做多信号】 是没有意义的
            // 扫描到的看跌信号 在现价的下方 则没有意义
            // 这里最纠结的两点 就是 K[1] 如果是信号 该如何处理的问题？
            // 如果我们不加判断 则一定能收集到K[1],但是会有无效的历史信号混入
            // 如果我们加了判断 则K[1] 信号有可能会丢失掉，如此在后续的上下文计算时就会bug
            // 上下文的算法 就是将当前确认信号 和 历史相对比
            // 这就要考虑 要不要 自己和自己对比的问题
            // --------------------------------------------------------

            if (Close[shift] < current_price)
            {
               int current_size = ArraySize(bullish_list);
               ArrayResize(bullish_list, current_size + 1);

               bullish_list[current_size].shift = shift;
               bullish_list[current_size].signal_time = data.OpenTime;
               bullish_list[current_size].confirmation_close = Close[shift];
               bullish_list[current_size].stop_loss = data.BullishStopLossPrice;
               bullish_list[current_size].type = OP_BUY;
            }
        }
        
        // -----------------------
        // 检查看跌信号
        // -----------------------
        if (data.BearishReferencePrice != (double)EMPTY_VALUE && 
            (int)data.BearishReferencePrice >= Min_Signal_Quality &&
            data.BearishStopLossPrice != (double)EMPTY_VALUE && data.BearishStopLossPrice != 0.0)
        {

            // --------------------------------------------------------
            // 🚨 核心修正 3：看跌信号价格区位过滤 (信号价必须高于现价)
            // --------------------------------------------------------

            if (Close[shift] > current_price)
            {
               int current_size = ArraySize(bearish_list);
               ArrayResize(bearish_list, current_size + 1);

               bearish_list[current_size].shift = shift;
               bearish_list[current_size].signal_time = data.OpenTime;
               bearish_list[current_size].confirmation_close = Close[shift];
               bearish_list[current_size].stop_loss = data.BearishStopLossPrice;
               bearish_list[current_size].type = OP_SELL;
            }
        }
    }
}
//+------------------------------------------------------------------+
//| 结束 下面这些函数 暂时不用了 留着做个备份而已
//+------------------------------------------------------------------+


