//+------------------------------------------------------------------+
//|                                                   KBot_Logic.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 09.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ 函数: 读取 iCustom 指标值 (解决了通信问题)
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
//| ✅ 批量获取 KTarget_Finder5 所有缓冲区数据
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
//| ✅ L3c: 信号时效性过滤器 (只允许 shift=1 的信号通过)
//+------------------------------------------------------------------+
bool IsSignalTimely(int signal_shift)
{
   // 只有 shift=1 的信号被认为是“紧跟信号成立后的第一根 K 线”
   if (signal_shift == 1)
   {
      return true; // 允许通过 (时效性达标)
   }

   // 所有 shift >= 2 的信号都被视为滞后，即使它是合格且未交易的
   Print(" L3c 过滤：信号滞后。要求 shift=1，当前 shift=", signal_shift, "。阻止开仓。");
   return false; // 阻止
}

//+------------------------------------------------------------------+
//| ✅ L3a: 信号新鲜度过滤器 (只允许扫描到的第一个合格信号通过)
//| 必须在外层 for 循环开始前重置 Found_First_Qualified_Signal 为 false
//+------------------------------------------------------------------+
bool IsSignalFresh(int trade_command)
{
    // 如果 trade_command 是 OP_NONE，则这不是一个合格信号，不影响 Found_First_Qualified_Signal
    if (trade_command == OP_NONE)
    {
        return true; // 保持新鲜，继续扫描
    }

    // 程序运行到这里，说明 trade_command 是 OP_BUY 或 OP_SELL

    // 检查：这是不是我们发现的第一个合格信号？
    if (Found_First_Qualified_Signal == false)
    {
        // 发现第一个合格信号！将其标记为已找到，并允许它通过。
        Found_First_Qualified_Signal = true;
        return true; // 允许通过 (新鲜)
    }

    // 如果 Found_First_Qualified_Signal 已经是 true，说明这不是第一个合格信号
    return false; // 阻止 (不新鲜)
}

//+------------------------------------------------------------------+
//| ✅ 函数: 检查信号是否已交易 (核心追踪函数)
//| 职责: 扫描所有持仓和历史订单，防止重复交易。
//| L3: 检查信号是否已被交易 (防重复交易过滤器)
//| 必须分两步检查：1. 持仓订单 (MODE_TRADES) 2. 历史订单 (MODE_HISTORY)
//+------------------------------------------------------------------+
bool IsSignalAlreadyTraded(string signal_id)
{
   // 🚨 1. 检查当前未平仓订单 (MODE_TRADES) 🚨
   // 循环次数: OrdersTotal()
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      // 关键: 使用 MODE_TRADES 选择持仓订单
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         // 匹配品种和 MagicNumber
         if (OrderSymbol() == _Symbol && OrderMagicNumber() == MagicNumber)
         {
            // 检查订单注释是否包含该信号 ID
            if (StringFind(OrderComment(), signal_id, 0) != -1)
            {
               Print(">>> 防重复：信号 ID (", signal_id, ") 已在当前持仓订单中找到。阻止开仓。");
               return true;
            }
         }
      }
   }

   // 🚨 2. 检查历史已平仓订单 (MODE_HISTORY) 🚨
   // 循环次数: OrdersHistoryTotal()
   // 注意：在历史订单中，我们只关心该信号是否已经导致过一次交易

   // 必须确保历史数据已加载 (通常在 OnInit() 或 OnTick() 早期)
   // HistorySelect(0, TimeCurrent()); // 如果担心加载问题，可以解除此行注释

   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      // 关键: 使用 MODE_HISTORY 选择历史订单
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         // 匹配品种和 MagicNumber
         if (OrderSymbol() == _Symbol && OrderMagicNumber() == MagicNumber)
         {
            // 检查订单注释是否包含该信号 ID
            if (StringFind(OrderComment(), signal_id, 0) != -1)
            {
               Print(">>> 防重复：信号 ID (", signal_id, ") 已在历史已平仓订单中找到。阻止开仓。");
               return true;
            }
         }
      }
   }

   return false; // 没有找到任何匹配的订单，允许开仓
}

//+------------------------------------------------------------------+
//| 开始 下面这些函数 暂时不用了 留着做个备份而已
//+------------------------------------------------------------------+
/* ****
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
*/
//+------------------------------------------------------------------+
//| 结束 下面这些函数 暂时不用了 留着做个备份而已
//+------------------------------------------------------------------+

/**
//+------------------------------------------------------------------+
//| CSL 驱动器：MQL4 原生版 (History Polling)
//| 通过扫描 OrdersHistoryTotal 更新连续止损状态
//| 该函数严重依赖 平仓时间 的排序 但是客户端不一定按照平仓时间展示列表
//+------------------------------------------------------------------+
void UpdateCSLByHistory()
{
    if (!Enable_CSL) return;

    // 1. 首次运行时，初始化检查时间
    if (g_LastCSLCheckTime == 0)
    {
       g_LastCSLCheckTime = TimeCurrent(); 
       return; // 首次运行不追溯，只记录当前时间作为起点
    }
    
    // 记录本次检查的开始时间 (用于更新 g_LastCSLCheckTime)
    datetime check_start_time = TimeCurrent();

    // 2. 获取历史订单总数
    int total_history = OrdersHistoryTotal(); 
    // Print("--->[KTarget_FinderBot.mq4:1736]: total_history: ", total_history);
    // return;
    
    // 3. 遍历历史订单
    // 建议从后往前遍历，因为最新的平仓通常在列表末尾
    for (int i = total_history - 1; i >= 0; i--)
    {
        // 使用 MODE_HISTORY 选择历史订单
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            // A. 筛选：确保是本 EA 的订单
            if (OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
            
            // B. 筛选：只关心 BUY 或 SELL 类型的订单 (排除挂单的删除记录)
            if (OrderType() > OP_SELL) continue; 

            // C. 核心筛选：平仓时间必须晚于上次检查时间
            if (OrderCloseTime() <= g_LastCSLCheckTime) 
            {
                // 因为我们是从后往前找的，如果发现一个订单的平仓时间比检查点还早，
                // 说明后面的订单只会更早，可以直接停止循环，节省资源。
                break; 
            }

            // 4. 获取利润 (OrderProfit + Swap + Commission)
            double deal_profit = OrderProfit() + OrderSwap() + OrderCommission();

            // 5. 更新 CSL 状态
            if (deal_profit < 0) // 亏损
            {
                g_ConsecutiveLossCount++;
                Print("CSL 追踪 (Ticket:", OrderTicket(), "): 亏损 $", DoubleToString(deal_profit, 2), " | 连亏计数: ", g_ConsecutiveLossCount);
                
                // 检查阈值
                if (g_ConsecutiveLossCount >= CSL_Max_Losses)
                {
                     int duration_seconds = CSL_Lockout_Duration * 3600; 
                     g_CSLLockoutEndTime = TimeCurrent() + duration_seconds;
                     Print("风险警报: 达到 ", CSL_Max_Losses, " 连亏! 锁定至: ", TimeToString(g_CSLLockoutEndTime, TIME_DATE|TIME_SECONDS));
                }
            }
            else // 盈利或平价
            {
                if (g_ConsecutiveLossCount > 0)
                {
                    Print("CSL 追踪 (Ticket:", OrderTicket(), "): 盈利，连亏清零。");
                }
                g_ConsecutiveLossCount = 0;
            }
        }
    }
    
    // 6. 更新时间戳
    g_LastCSLCheckTime = check_start_time;
}
*/

//+------------------------------------------------------------------+
//| CSL 锁定状态检查 (在 OnTick 或开仓前调用)                        |
//| 返回 true 表示当前交易被锁定，不应开仓。                           |
//+------------------------------------------------------------------+
bool IsTradingLocked()
{
   // 1. 如果功能关闭，则不锁定
   if (!Enable_CSL) return false;

   // 2. 如果没有锁定时间，则不锁定
   if (g_CSLLockoutEndTime == 0) return false;

   // 3. 检查锁定是否已解除
   if (TimeCurrent() >= g_CSLLockoutEndTime)
   {
      // 锁定时间已过，解除锁定并重置状态
      Print("风险解除: 连续止损锁定已到期，EA 恢复正常交易。");
      g_CSLLockoutEndTime = 0;
      // g_ConsecutiveLossCount = 0; // 锁定结束后，必须重置计数器===>2.0版本下此行代码注销
      return false;
   }

   // 4. 仍在锁定期间
   Print("交易锁定中: CSL 触发，等待解除时间: ", TimeToString(g_CSLLockoutEndTime, TIME_DATE | TIME_SECONDS));
   return true;
}

//+------------------------------------------------------------------+
//| 获取本EA当前持仓数量                                             |
//| 返回值: 属于本EA的持仓单数量 (OP_BUY 或 OP_SELL)                 |
//+------------------------------------------------------------------+
int GetOpenPositionsCount()
{
   int count = 0;

   // 遍历当前所有订单（包括挂单和持仓）
   for (int i = 0; i < OrdersTotal(); i++)
   {
      // 尝试选择订单
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         // 1. 筛选：确保是本 EA 的订单
         if (OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
            continue;

         // 2. 筛选：只计算持仓单 (OP_BUY 或 OP_SELL)，排除挂单
         int type = OrderType();
         if (type == OP_BUY || type == OP_SELL)
         {
            count++;
         }
      }
   }

   return count;
}

/**
//+------------------------------------------------------------------+
//| 函数: 统计当前品种和 MagicNumber 下的持仓订单数量 暂时没有被调用
//+------------------------------------------------------------------+
int CountOpenTrades(int magic)
{
   int total = 0;

   // 遍历所有订单 (持仓和挂单)
   for (int i = 0; i < OrdersTotal(); i++)
   {
      // 选中订单
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         // 过滤条件：
         // 1. 必须是本 EA 的订单 (MagicNumber)
         // 2. 必须是当前图表品种的订单 (Symbol)
         // 3. 必须是持仓订单 (OP_BUY 或 OP_SELL，排除挂单 OP_BUYSTOP 等)
         if (OrderMagicNumber() == magic &&
             OrderSymbol() == _Symbol &&
             (OrderType() == OP_BUY || OrderType() == OP_SELL))
         {
            total++;
         }
      }
   }
   return total;
}
*/

/**
//+------------------------------------------------------------------+
//| 获取本EA当前交易日（从 00:00:00 开始）的已实现盈亏 (Realized P/L)
//| 有潜在的问题  历史列表 有可能不会按照时间进行排序
//+------------------------------------------------------------------+
double GetTodayRealizedProfit()
{
   // 获取当前图表品种的日线0柱（即今天 00:00:00）的时间戳
   // 这是 MQL4 中获取当前交易日开始时间的标准方法
   datetime TodayStartTime = iTime(Symbol(), PERIOD_D1, 0);
   //Print(">[KTarget_FinderBot.mq4:1777]: TodayStartTime: ", TodayStartTime);
   //return;

   double daily_profit = 0.0;

   // 遍历历史订单
   int total_history = OrdersHistoryTotal();

   for (int i = total_history - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         // 1. 筛选：只检查本 EA 的订单
         if (OrderMagicNumber() != MagicNumber) continue;

         // 2. 筛选：只检查当前交易日内的平仓订单
         // 只要订单的平仓时间早于今天的开始时间，就停止循环 (因为列表通常按时间排序)
         if (OrderCloseTime() < TodayStartTime)
         {
            break;
         }

         // 3. 累加已实现净盈亏：Profit + Swap + Commission
         daily_profit += (OrderProfit() + OrderSwap() + OrderCommission());
      }
   }

   return daily_profit;
}
*/

/** 旧的代码逻辑
//风控部分的函数
//+------------------------------------------------------------------+
//| 函数: 时间窗口过滤                                               |
//+------------------------------------------------------------------+
bool IsTimeWindowAllowed()
{
   // 功能说明：比如我是北京时间，我输入的是我北京时间，这时候 可能要考虑冬令时和夏令时的差别
   // 比如我想让EA 在上午时间段 北京时间 8-12 开始交易；和 下午 四点--6点 ；或者晚上 9-凌晨4点 ；一次性输入这几个时间段
   // EA只有在这些时间段里，才开始运行并交易
   // int current_hour = Hour();

   // // 检查是否在允许的时间窗口内
   // if (current_hour >= Trade_Start_Hour && current_hour < Trade_End_Hour)
   // {
   //    return true;
   // }

   // // 如果不在允许时间内，打印日志并禁止交易
   // Print("风控过滤: 当前时间 ", current_hour, " 不在交易时间窗口 (", Trade_Start_Hour, "-", Trade_End_Hour, ")。");
   return false;
}

// 连续止损 处理
// 出现订单的连续止损以后 如何处理？
// 暂停交易  减低手数或者开仓比例  等待一定时间以后才开始下一笔交易；停止 发送提示 人工确定是否还要继续交易
// UpdateLossStreak IsTradingAllowedByStreak GetAdjustedLotSize

// 日内整体风控 (Daily Cap Controls)
// 先将EA设置成全天运行 不限制  等各个环节和流程全部 测试通过以后 再来实现交易时间的限制

// KTarget_FinderBot.mq4 (g_last_date 是全局变量，用于存储上次运行的日期)

//+------------------------------------------------------------------+
//| 函数: 每日数据重置                                               |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   //  datetime current_date = iTime(NULL, PERIOD_D1, 0); // 获取当前交易日
    
   //  if (current_date != g_last_date)
   //  {
   //      // 跨日，执行重置
   //      g_today_profit_pips = 0;
   //      g_today_trades = 0;
   //      g_last_date = current_date;
   //      Print("--- 每日统计已重置 ---");
   //  }
}

//+------------------------------------------------------------------+
//| 函数: 日内整体风控过滤 (包括亏损/盈利/次数限制)                 |
//+------------------------------------------------------------------+
bool IsDailyRiskAllowed()
{
   // 1. 达到日盈利目标
   // if (g_today_profit_pips >= Daily_Target_Profit_Pips)
   // {
   //    Comment("日盈利目标达成，暂停交易。");
   //    return false;
   // }

   // // 2. 达到日最大亏损
   // if (g_today_profit_pips <= -Daily_Max_Loss_Pips)
   // {
   //    Comment("日最大亏损触发，暂停交易。");
   //    return false;
   // }

   // // 3. 达到日最大交易次数
   // if (g_today_trades >= Daily_Max_Trades)
   // {
   //    Comment("日交易次数已满，暂停交易。");
   //    return false;
   // }

   return true;
}
*/

/**
//+------------------------------------------------------------------+
//| 每日盈亏增量更新函数 (UpdateDailyProfit)                         |
//| 负责日初重置累计值，并在每个Tick上累加新的平仓盈亏                |
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
    // 获取当前日期 (精确到天 即今天 00:00:00 的时间戳)
    datetime today = iTime(Symbol(), PERIOD_D1, 0); 
    
    // 1. 检查是否需要隔日重置
    if (g_Last_Calc_Date != today)
    {
        g_Today_Realized_PL = 0.0; // 累计盈亏清零
        g_Last_Daily_Check_Time = today; // 检查时间点设为今天开始
        g_Last_Calc_Date = today; 
        
        // 确保在隔日重置时，上次检查时间从今天 00:00:00 开始
        Print(" 日内盈亏追踪已重置，新的一天开始。");
    }
    
    // 2. 首次启动初始化检查时间
    if (g_Last_Daily_Check_Time == 0)
    {
        // 第一次运行时，将检查时间点设置为当前时间，避免扫描所有历史订单
        g_Last_Daily_Check_Time = TimeCurrent(); 
        return; 
    }
    
    datetime current_time = TimeCurrent();

    // 3. 遍历历史订单，只检查上次检查时间之后的新交易
    // (逻辑与 UpdateCSLByHistory 类似)
    int total_history = OrdersHistoryTotal(); 

    // 从最新的历史订单开始向前遍历
    for (int i = total_history - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            if (OrderMagicNumber() != MagicNumber) continue;
            
            // 🚨 CSL/日内限额 的核心：只检查最新平仓的订单
            // 如果订单平仓时间早于或等于上次检查时间，就可以停止循环（假设列表大致按时间排序）
            if (OrderCloseTime() <= g_Last_Daily_Check_Time)
            {
                break; // 遇到旧订单，停止遍历（因为只关注增量更新，可以假定大部分时间列表是按时间排序的）
            }
            
            // 累加新增的已实现盈亏
            double deal_profit = OrderProfit() + OrderSwap() + OrderCommission();
            g_Today_Realized_PL += deal_profit;
            
            // 打印增量更新日志
            Print(" 日内盈亏更新: Ticket ", OrderTicket(), " P/L:", DoubleToString(deal_profit, 2), " | 今日累计:", DoubleToString(g_Today_Realized_PL, 2));
        }
    }
    
    // 4. 更新检查时间戳
    g_Last_Daily_Check_Time = current_time;
}

//+------------------------------------------------------------------+
//| 检查是否达到日内亏损限制 (Daily Equity Stop)                       |
//| 直接读取全局变量，速度极快                                        |
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached()
{
    if (!Check_Daily_Loss_Strictly) return false;
    
    // 检查是否达到亏损阈值 (累计盈亏是负值，所以用 <=)
    // 例如：如果 Daily_Max_Loss_Amount=100，当 g_Today_Realized_PL 达到 -100.00 或更低时触发
    // 直接使用全局累计盈亏值
    if (g_Today_Realized_PL <= -Daily_Max_Loss_Amount)
    {
        Print(" 风险熔断: 今日已实现亏损 $", DoubleToString(g_Today_Realized_PL, 2), "，达到或超过日内亏损限制 $", Daily_Max_Loss_Amount, "。交易已停止！");
        return true;
    }
    
    return false;
}
*/

//+------------------------------------------------------------------+
//| 核心功能：检查是否存在足够的利润空间 (Profit Space Check)
//| 返回值: true = 空间充足; false = 空间不足，过滤交易
//+------------------------------------------------------------------+
bool CheckProfitSpace(int type, double entry_price, double stop_loss_price, FilteredSignal &history_opponents[])
{
    // 1. 计算当前信号的风险 (Risk)
    double current_risk = MathAbs(entry_price - stop_loss_price);
    
    // 异常保护：防止风险为0导致除零错误
    if (current_risk <= Point()) return true; // 风险极小，默认放行
    
    // 2. 寻找最近的反向障碍物 (Nearest Obstacle)
    double target_price = 0.0;
    int opponent_idx = -1;
    
    int total_opponents = ArraySize(history_opponents);
    
    // 遍历反向信号列表 (history_opponents 应该是按 shift 排序的，index 0 是最新的)
    for (int i = 0; i < total_opponents; i++)
    {
        FilteredSignal opp = history_opponents[i];
        
        // 我们只关心那些在当前价格"前方"的障碍
        if (type == OP_SELL)
        {
            // 做空：障碍物必须在当前价格下方
            // 我们取反向看涨信号的【最低点(SL)】作为极限目标
            // 如果您想保守一点，可以取 opp.confirmation_close
            if (opp.stop_loss < entry_price) 
            {
                target_price = opp.stop_loss;
                opponent_idx = i;
                break; // 找到了最近的一个下方支撑，停止搜索
            }
        }
        else if (type == OP_BUY)
        {
            // 做多：障碍物必须在当前价格上方
            // 取反向看跌信号的【最高点(SL)】作为极限目标
            if (opp.stop_loss > entry_price)
            {
                target_price = opp.stop_loss;
                opponent_idx = i;
                break; // 找到了最近的一个上方阻力
            }
        }
    }
    
    // 3. 如果找不到任何历史反向信号作为障碍
    if (target_price == 0.0) 
    {
        // 说明前方是一片开阔地 (或者历史数据不足)，默认允许交易
        // Print(" [空间检查] 前方无障碍，通过。");
        return true; 
    }
    
    // 4. 计算剩余空间 (Space)
    double available_space = MathAbs(entry_price - target_price);
    
    // 5. 计算盈亏比 (Reward / Risk)
    double ratio = available_space / current_risk;
    
    // 6. 视觉调试 (可选)：在图表上画出这一段 空间 和 风险 的对比
    // 这里只打印日志，您也可以调用画线函数
    string direction = (type == OP_SELL) ? "看跌" : "看涨";
    
    if (ratio < Min_Reward_Risk_Ratio)
    {
        Print(" [空间过滤] ", direction, "信号被拒绝！风险: ", DoubleToString(current_risk/Point(), 0), 
              "pt | 剩余空间: ", DoubleToString(available_space/Point(), 0), 
              "pt | 盈亏比: ", DoubleToString(ratio, 2), " < ", Min_Reward_Risk_Ratio);
        return false; // 空间太小，拒绝
    }
    
    // 空间充足
    Print(" [空间充足] ", direction, "信号通过。盈亏比: ", DoubleToString(ratio, 2));
    return true;
}

//+------------------------------------------------------------------+
//| ✅ 核心功能：检查是否距离反向持仓太近 (防止震荡磨损)                  |
//| 返回值: true = 距离足够(允许交易); false = 距离太近(禁止交易)      |
//+------------------------------------------------------------------+
bool CheckHedgeDistance(int new_signal_type)
{
   // 1. 如果开关关闭，直接放行
   if (!Use_Hedge_Filter) return true;

   // 2. 获取当前的 ATR 值 (衡量当前市场的波动尺度)
   // 使用 shift=1 (上一根收盘K线) 以保证数值稳定，不闪烁
   double current_atr = iATR(NULL, 0, Hedge_ATR_Period, 1);
   
   // 异常保护
   if (current_atr <= 0) return true;

   // 计算最小允许的物理距离 (价格)
   double min_distance = current_atr * Min_Hedge_Dist_ATR;

   // 3. 遍历所有持仓单
   int total = OrdersTotal();
   for (int i = 0; i < total; i++)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         // 筛选本 EA 的订单
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            // 4. 寻找【反向】持仓
            // 如果新信号是 BUY，我们要检查有没有很近的 SELL 单
            // 如果新信号是 SELL，我们要检查有没有很近的 BUY 单
            if (OrderType() != new_signal_type)
            {
               // 计算当前价格与那张持仓单开仓价的距离
               // 注意：这里用 Close[0] (当前价) 还是 OrderOpenPrice 均可
               // 建议比较：新信号的入场位(Close[0]) vs 老单子的入场位
               double distance = MathAbs(OrderOpenPrice() - Close[0]);
               
               // 5. 判定
               if (distance < min_distance)
               {
                  // 距离太近！也就是您遇到的 ETHUSD 只有 1.6 美金价差的情况
                  Print(" [震荡过滤] 距离反向持仓太近！");
                  Print("   -> 反向单号: ", OrderTicket(), " 类型: ", (OrderType()==OP_BUY?"BUY":"SELL"));
                  Print("   -> 当前距离: ", DoubleToString(distance, _Digits));
                  Print("   -> 最小要求: ", DoubleToString(min_distance, _Digits), " (ATR*", Min_Hedge_Dist_ATR, ")");
                  
                  return false; // 禁止交易
               }
            }
         }
      }
   }
   
   // 遍历完如果没有触发拦截，说明距离都足够，或者没有反向单
   return true;
}
//+------------------------------------------------------------------+
//| 重新实现 连续止损功能 获取订单以后 然后平仓时间排序以后才列入计数
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 辅助结构体：用于临时存储历史订单信息 (放在函数外部或最上方)
//+------------------------------------------------------------------+
struct CSL_TradeInfo
{
   int      ticket;
   datetime close_time;
   double   net_profit; // 净利润
};

//+------------------------------------------------------------------+
//| UpdateCSLByHistory V2.0 (健壮版)
//| 功能：扫描历史记录，计算连续止损次数，并更新全局锁定状态
//| 特性：抗手动排序干扰，自动计算手续费和库存费
//+------------------------------------------------------------------+
void UpdateCSLByHistory_V2()
{
   // 1. 如果功能没开，直接重置并返回
   if(!Enable_CSL) 
   {
      g_ConsecutiveLossCount = 0;
      g_CSLLockoutEndTime = 0;
      return;
   }

   // 初始化计数器
   g_ConsecutiveLossCount = 0;
   
   // 定义动态数组存储筛选出的本品种历史单
   CSL_TradeInfo trades[];
   
   // =========================================================
   // 步骤 1: 全量扫描 (Collect) - 不依赖 MT4 排序
   // =========================================================
   int total_history = OrdersHistoryTotal();
   
   for(int i = 0; i < total_history; i++)
   {
      // 必须循环所有订单，不能因为时间或者获利 break，因为顺序可能是乱的
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false) continue;
      
      // A. 基础过滤：只看本 EA、本品种的单子
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      // B. 类型过滤：只看多空单 (排除 Balance/Credit 等资金流水)
      if(OrderType() > OP_SELL) continue;
      
      // C. 收集数据到数组
      int size = ArraySize(trades);
      ArrayResize(trades, size + 1);
      
      trades[size].ticket     = OrderTicket();
      trades[size].close_time = OrderCloseTime();
      // 净利润 = 盘面盈亏 + 手续费 + 库存费
      trades[size].net_profit = OrderProfit() + OrderCommission() + OrderSwap();
   }
   
   // =========================================================
   // 步骤 2: 内部排序 (Sort) - 按平仓时间从近到远
   // =========================================================
   int count = ArraySize(trades);
   
   // 使用简单的冒泡排序 (因为历史单量通常不会造成性能瓶颈)
   for(int i = 0; i < count - 1; i++)
   {
      for(int j = 0; j < count - i - 1; j++)
      {
         // 如果前一个比后一个时间早 (Old < New)，则交换
         // 我们需要 Newest 在 Index 0
         if(trades[j].close_time < trades[j+1].close_time)
         {
            CSL_TradeInfo temp = trades[j];
            trades[j] = trades[j+1];
            trades[j+1] = temp;
         }
      }
   }
   
   // =========================================================
   // 步骤 3: 连损计算与锁定逻辑 (Calculate)
   // =========================================================
   datetime last_loss_time = 0; // 记录最近一次亏损的时间
   
   for(int i = 0; i < count; i++)
   {
      // 如果遇到盈利单 (净利润 >= 0)
      if(trades[i].net_profit >= 0)
      {
         // 连损被中断，计算结束
         break; 
      }
      else
      {
         // 遇到亏损单，计数器 +1
         g_ConsecutiveLossCount++;
         
         // 记录最新的一笔亏损时间 (用于计算锁定截止时间)
         if(last_loss_time == 0) last_loss_time = trades[i].close_time;
      }
   }
   
   // =========================================================
   // 步骤 4: 更新全局锁定状态 (Lockout Logic)
   // =========================================================
   if(g_ConsecutiveLossCount >= CSL_Max_Losses)
   {
      // 达到连损上限，计算锁定结束时间
      // 锁定结束时间 = 最近一笔亏损平仓时间 + 锁定小时数
      g_CSLLockoutEndTime = last_loss_time + (CSL_Lockout_Duration * 3600);
      
      // 调试日志 (可选)
      // Print("🚫 触发连续止损风控! 次数:", g_ConsecutiveLossCount, 
      //       " 解锁时间:", TimeToString(g_CSLLockoutEndTime));
   }
   else
   {
      // 未达到连损上限，清除锁定状态
      g_CSLLockoutEndTime = 0;
   }
   
   // 更新上次检查时间
   g_LastCSLCheckTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| UpdateCSLByHistory_V3 (防死锁修正版)
//| 功能：扫描历史记录，计算连续止损次数，并更新全局锁定状态
//| 特性：抗手动排序干扰，自动计算手续费和库存费
//| 修复：解决了"过期锁定时间"导致的无限重置死锁问题
//+------------------------------------------------------------------+
void UpdateCSLByHistory_V3()
{
   // 1. 如果功能没开，直接重置并返回
   if(!Enable_CSL) 
   {
      g_ConsecutiveLossCount = 0;
      g_CSLLockoutEndTime = 0;
      return;
   }

   // 初始化计数器 (虽然下面会重算，但保持好习惯)
   g_ConsecutiveLossCount = 0;
   
   // 定义动态数组存储筛选出的本品种历史单
   CSL_TradeInfo trades[];
   
   // =========================================================
   // 步骤 1: 全量扫描 (Collect) - 不依赖 MT4 排序
   // =========================================================
   int total_history = OrdersHistoryTotal();
   
   for(int i = 0; i < total_history; i++)
   {
      // 必须循环所有订单，不能因为时间或者获利 break，因为顺序可能是乱的
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false) continue;
      
      // A. 基础过滤：只看本 EA、本品种的单子
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      // B. 类型过滤：只看多空单 (排除 Balance/Credit 等资金流水)
      if(OrderType() > OP_SELL) continue;
      
      // C. 收集数据到数组
      int size = ArraySize(trades);
      ArrayResize(trades, size + 1);
      
      trades[size].ticket     = OrderTicket();
      trades[size].close_time = OrderCloseTime();
      // 净利润 = 盘面盈亏 + 手续费 + 库存费
      trades[size].net_profit = OrderProfit() + OrderCommission() + OrderSwap();
   }
   
   // =========================================================
   // 步骤 2: 内部排序 (Sort) - 按平仓时间从近到远
   // =========================================================
   int count = ArraySize(trades);
   
   // 使用简单的冒泡排序 (因为历史单量通常不会造成性能瓶颈)
   for(int i = 0; i < count - 1; i++)
   {
      for(int j = 0; j < count - i - 1; j++)
      {
         // 如果前一个比后一个时间早 (Old < New)，则交换
         // 我们需要 Newest 在 Index 0
         if(trades[j].close_time < trades[j+1].close_time)
         {
            CSL_TradeInfo temp = trades[j];
            trades[j] = trades[j+1];
            trades[j+1] = temp;
         }
      }
   }
   
   // =========================================================
   // 步骤 3: 连损计算 (Calculate)
   // =========================================================
   // 重置计数器，开始严谨计算
   g_ConsecutiveLossCount = 0;
   datetime last_loss_time = 0; // 记录最近一次亏损的时间
   
   for(int i = 0; i < count; i++)
   {
      // 如果遇到盈利单 (净利润 >= 0)
      if(trades[i].net_profit >= 0)
      {
         // 连损被中断，计算结束
         break; 
      }
      else
      {
         // 遇到亏损单，计数器 +1
         g_ConsecutiveLossCount++;
         
         // 记录最新的一笔亏损时间 (用于计算锁定截止时间)
         // 因为是倒序排列，第一个遇到的亏损单肯定是最新的
         if(last_loss_time == 0) last_loss_time = trades[i].close_time;
      }
   }
   
   // =========================================================
   // 步骤 4: 更新全局锁定状态 (Lockout Logic - Fixed V3)
   // =========================================================
   if(g_ConsecutiveLossCount >= CSL_Max_Losses)
   {
      // 1. 先计算出"理论上"应该解锁的时间
      // 公式：最后亏损时间 + 锁定小时数
      datetime potential_unlock_time = last_loss_time + (CSL_Lockout_Duration * 3600);
      
      // 2. 🚨 核心修复：进行"未来性"检查
      // 只有当这个解锁时间 是"未来"的时候，我们才执行锁定。
      // 如果解锁时间已经是"过去"了 (比如是2020年的单子)，说明刑期已满，不要再锁了。
      
      if (potential_unlock_time > TimeCurrent())
      {
         // 确实需要锁定
         g_CSLLockoutEndTime = potential_unlock_time;
         
         // 调试日志 (仅在状态改变或调试时打开，避免刷屏)
         // Print("🚫 CSL风控激活: ", g_ConsecutiveLossCount, "连损. 锁定至: ", TimeToString(g_CSLLockoutEndTime));
      }
      else
      {
         // 虽然连损次数够了，但惩罚时间已过
         g_CSLLockoutEndTime = 0;
      }
   }
   else
   {
      // 未达到连损上限，清除锁定状态
      g_CSLLockoutEndTime = 0;
   }
   
   // 更新上次检查时间
   g_LastCSLCheckTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| 重新实现 每日的亏损金额限制
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| UpdateDailyProfit V2.0
//| 功能：计算当日已结盈亏 (抗排序干扰、包含手续费/库存费)
//+------------------------------------------------------------------+
void UpdateDailyProfit_V2()
{
   // =========================================================
   // 1. 跨天重置逻辑
   // =========================================================
   // 获取今天 00:00 的时间戳 (服务器时间)
   datetime today_start = iTime(NULL, PERIOD_D1, 0);
   
   // 如果记录的日期与今天不同 (说明跨天了)
   if (g_Last_Calc_Date != today_start)
   {
      g_Today_Realized_PL = 0.0;
      g_Last_Calc_Date = today_start; // 更新为今天的日期
   }

   // =========================================================
   // 2. 性能优化 (替代增量更新的更安全方案)
   // =========================================================
   // 使用 static 变量记录上次的历史订单总数 (只在本函数内有效，不污染全局)
   static int s_last_history_total = 0;
   int current_history_total = OrdersHistoryTotal();

   // 如果历史订单数没变，说明没有新平仓，直接跳过计算 (极大的性能节省)
   if (current_history_total == s_last_history_total) return;

   // =========================================================
   // 3. 全量扫描逻辑 (不依赖 break，抗乱序)
   // =========================================================
   double temp_daily_profit = 0.0;
   
   for (int i = 0; i < current_history_total; i++)
   {
      // 必须使用 continue，不能 break，防止因排序导致漏单
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false) continue;

      // A. 基础过滤 (本EA、本品种)
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      // B. 类型过滤 (只计算交易单，排除资金流水)
      if (OrderType() > OP_SELL) continue;

      // C. 关键时间过滤：只计算 平仓时间 >= 今天0点
      if (OrderCloseTime() < today_start) continue;

      // D. 累加净利润 (盈亏 + 佣金 + 库存费)
      temp_daily_profit += OrderProfit() + OrderCommission() + OrderSwap();
   }

   // =========================================================
   // 4. 更新全局状态
   // =========================================================
   g_Today_Realized_PL = temp_daily_profit;      // 更新盈亏
   s_last_history_total = current_history_total; // 更新缓存快照
   g_Last_Daily_Check_Time = TimeCurrent();      // 记录本次更新的时间 (复用此变量)

   // 调试打印 (可选)
   // Print("📊 [日报更新] 今日净盈亏: ", DoubleToString(g_Today_Realized_PL, 2));
}

//+------------------------------------------------------------------+
//| IsDailyLossLimitReached V2.0
//| 功能：检查是否触及日内亏损红线
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached_V2()
{
   // 1. 如果开关没开，直接放行
   if (!Check_Daily_Loss_Strictly) return false;

   // 2. 检查是否达到亏损限制
   // 逻辑：Daily_Max_Loss_Amount 通常输入正数 (如 100)
   // 如果今日盈亏 <= -100 (即亏损超过 100)
   if (g_Today_Realized_PL <= -MathAbs(Daily_Max_Loss_Amount))
   {
      // 触发风控，拦截交易
      // 可以在这里加上 Print 防止刷屏，或者由上层调用逻辑处理
      return true; 
   }

   // 3. 未触及红线，放行
   return false;
}