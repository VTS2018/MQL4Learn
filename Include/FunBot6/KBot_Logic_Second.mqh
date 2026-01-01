//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 二阶段函数逻辑  上下文【位置】--空间--反向距离--核心逻辑
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| L2: 信号上下文环境检查 (统一版：包含 Fib反转 和 区间回踩)          |
//| 优化：直接使用过滤后的有效信号列表 (history_bulls/bears) 进行计算    |
//+------------------------------------------------------------------+
int CheckSignalContext(int current_shift, int current_type, FilteredSignal &history_bulls[], FilteredSignal &history_bears[])
{
   // 现在所有的信号列表都已经 准备好了 不用自己去查找了，只需要遍历和查找有效看涨列表和有效看跌列表
   // 这个函数的逻辑 就是满足我们 “见位”的核心思路，即不是所有的信号都要做，要有位置，要有位置的量化和
   // 判断，只有到了位置以后，我们看到了信号，才执行一笔交易，这极大的过滤的 无效的开仓 所以是非常重要的 一个进步

    // =================================================================
    // 1. 数据准备
    // =================================================================
    double current_high = High[current_shift];
    double current_low  = Low[current_shift];

    // --- 定义上下文关系绘图对象前缀 ---
    // 使用这个唯一的对象前缀，方便在 OnDeinit 或 OnTick 循环开始时进行清理
    // string context_line_prefix = g_object_prefix + "CRel_";
    string link_prefix = g_object_prefix + "CtxLink_";

    // --- 定义需要检查的斐波那契区域 ---
    // 格式: {Level1, Level2}，可以根据需要自由添加/修改
    /*
    double FiboLevels[4][2] = {
        {1.618, 1.88},
        {2.618, 2.88},
        {4.236, 4.88},
        {6, 7}
        // 您可以添加更多区域，例如 {0.618, 0.786}
    };
    int zones_count = ArrayRange(FiboLevels, 0);
    */

    // Print("--->[KTarget_FinderBot.mq4:1273]: zones_count: ", zones_count);
    // 2.0 代码讲上面的斐波区域 定义成了 可以输入和配置的

   // =================================================================
   // 逻辑 A: 斐波那契反转检查 (Fibonacci Reversal)
   // 场景：当前是看跌 -> 检查是否触碰了历史【看涨】信号的延伸阻力区
   //       当前是看涨 -> 检查是否触碰了历史【看跌】信号的延伸支撑区
   // =================================================================

   // --- 情况 A1: 当前是看跌 (OP_SELL) ---
   if (current_type == OP_SELL)
   {
      // 我想实现 在循环中 连续查找三次 左右，如果这个有效列表有超过三个以上 就找最大的 那个 更旧的信号
      // 1. 遍历历史【看涨】列表 (寻找阻力)
      int total_bulls = ArraySize(history_bulls);
      for (int i = 0; i < total_bulls; i++)
      {
         FilteredSignal prev = history_bulls[i];

         // 必须是历史信号 (shift 更大)
         if (prev.shift <= current_shift) continue;

         // 计算 Risk (入场 - 止损)
         double risk = prev.confirmation_close - prev.stop_loss;
         if (risk <= 0) continue;

         double tolerance = NormalizeDouble(risk * 0.1, _Digits);

         // 循环检查所有斐波那契区域
         for (int z = 0; z < g_FiboZonesCount; z++)
         {
            double level1 = g_FiboExhaustionLevels[z][0];
            double level2 = g_FiboExhaustionLevels[z][1];

            // 修正：基准价使用 prev.stop_loss (最低点)
            // 看涨延伸：基准 + Risk * Level
            double zone_low = prev.stop_loss + (risk * level1);
            double zone_high = prev.stop_loss + (risk * level2);

            // 精度修正
            zone_low = NormalizeDouble(zone_low, _Digits);
            zone_high = NormalizeDouble(zone_high, _Digits);

            // 应用容差
            double check_low = zone_low - tolerance;
            double check_high = zone_high + tolerance;

            // 触碰检查
            if (current_low <= check_high && current_high >= check_low)
            {
               // -----------------------------------------------------------
               // 🎨 可视化绘制：看跌信号 K[1] -> 受到 看涨锚点 K[prev] 的阻力
               // -----------------------------------------------------------

               // 1. 生成唯一名称 (使用时间戳，不要用 shift)
               // 格式: 前缀 + 当前时间(整数) + "_" + 历史时间(整数)
               string obj_name = link_prefix + (string)Time[current_shift] + "_" + (string)prev.signal_time;

               // 2. 确定坐标 (Close to Close)
               datetime t1 = Time[current_shift];  // 起点时间 (当前)
               double   p1 = Close[current_shift]; // 起点价格

               datetime t2 = prev.signal_time;            // 终点时间 (历史)
               double   p2 = prev.confirmation_close; // 终点价格 (历史收盘)

               // 3. 调用绘图 (红色虚线，代表受到阻力)
               DrawContextLinkLine(obj_name, t1, p1, t2, p2, clrRed);

               // -----------------------------------------------------------

               Print(" [上下文-反转] 当前看跌(K", current_shift, ") 触碰 历史看涨(K", prev.shift, ") Fib区间 [",
                     DoubleToString(level1, 3), "-", DoubleToString(level2, 3), "]");
               // 返回特定的上下文代码，或者简单的 true/false，这里假设返回由上层决定的指令
               // 为了简单，我们只返回 true 表示上下文有效
               return 1; // 上下文有效
            }
         }
      }
   }
   // --- 情况 A2: 当前是看涨 (OP_BUY) ---
   else if (current_type == OP_BUY)
   {
      // 1. 遍历历史【看跌】列表 (寻找支撑)
      int total_bears = ArraySize(history_bears);
      for (int i = 0; i < total_bears; i++)
      {
         FilteredSignal prev = history_bears[i];
         if (prev.shift <= current_shift) continue;

         // Risk (止损 - 入场)
         double risk = prev.stop_loss - prev.confirmation_close;
         if (risk <= 0) continue;

         double tolerance = NormalizeDouble(risk * 0.1, _Digits);

         for (int z = 0; z < g_FiboZonesCount; z++)
         {
            double level1 = g_FiboExhaustionLevels[z][0];
            double level2 = g_FiboExhaustionLevels[z][1];

            // 修正：基准价使用 prev.stop_loss (最高点)
            // 看跌延伸：基准 - Risk * Level (数值越小越远)
            double zone_low = prev.stop_loss - (risk * level2);  // level2 大，减得多，是低位
            double zone_high = prev.stop_loss - (risk * level1); // level1 小，减得少，是高位

            zone_low = NormalizeDouble(zone_low, _Digits);
            zone_high = NormalizeDouble(zone_high, _Digits);

            double check_low = zone_low - tolerance;
            double check_high = zone_high + tolerance;

            if (current_low <= check_high && current_high >= check_low)
            {
               // -----------------------------------------------------------
               // 🎨 可视化绘制：看涨信号 K[1] -> 受到 看跌锚点 K[prev] 的支撑
               // -----------------------------------------------------------

               string obj_name = link_prefix + (string)Time[current_shift] + "_" + (string)prev.signal_time;

               datetime t1 = Time[current_shift];
               double   p1 = Close[current_shift];
               datetime t2 = prev.signal_time;
               double   p2 = prev.confirmation_close;

               // 调用绘图 (绿色/蓝色虚线，代表受到支撑)
               DrawContextLinkLine(obj_name, t1, p1, t2, p2, clrDodgerBlue);

               // -----------------------------------------------------------
               Print(" [上下文-反转] 当前看涨(K", current_shift, ") 触碰 历史看跌(K", prev.shift, ") Fib区间 [",
                     DoubleToString(level1, 3), "-", DoubleToString(level2, 3), "]");
               return 1;
            }
         }
      }
   }


   // =================================================================
   // 逻辑 B: 同向区间回踩检查 (Zone Retest)
   // 场景：当前是看跌 -> 检查是否回踩了最近一个历史【看跌】信号的内部风险区
   //       当前是看涨 -> 检查是否回踩了最近一个历史【看涨】信号的内部风险区
   // =================================================================
   if (current_type == OP_SELL)
   {
      // 遍历历史【看跌】列表 (同向)
      int total_bears = ArraySize(history_bears);
      // 我们只关心最近的一个有效同向信号，假设列表按 shift 排序，我们找第一个比当前旧的
      for (int i = 0; i < total_bears; i++)
      {
         FilteredSignal prev = history_bears[i];
         if (prev.shift <= current_shift) continue; // 跳过

         // 基础区间：从 SL(最高) 到 Close(最低)
         double zone_top = prev.stop_loss;
         double zone_bottom = prev.confirmation_close;

         // 触碰检查 (K线是否进入了这个区间)
         if (current_low <= zone_top && current_high >= zone_bottom)
         {
            // -----------------------------------------------------------
            // 🎨 可视化绘制：看跌回踩 (同向确认) -> 绘制 深灰色 线条
            // -----------------------------------------------------------

            // 1. 生成唯一名称
            // 使用之前定义的 link_prefix (g_object_prefix + "CtxLink_")
            string obj_name = link_prefix + (string)Time[current_shift] + "_" + (string)prev.signal_time;

            // 2. 确定坐标 (Close to Close)
            datetime t1 = Time[current_shift];
            double p1 = Close[current_shift];

            datetime t2 = prev.signal_time;
            double p2 = prev.confirmation_close;

            // 3. 调用绘图 (使用深灰色 clrDarkGray，表示这是顺势的结构确认)
            // 注意：DrawContextLinkLine 函数必须已经包含在您的代码中
            DrawContextLinkLine(obj_name, t1, p1, t2, p2, clrDarkGray);

            // -----------------------------------------------------------

            Print(" [上下文-回踩] 当前看跌(K", current_shift, ") 回踩 历史看跌(K", prev.shift, ") 基础区间");
            return 2; // 返回不同的代码表示回踩
         }
         break; // 只检查最近的一个有效同向信号
      }
   }
   else if (current_type == OP_BUY)
   {
      // 遍历历史【看涨】列表 (同向)
      int total_bulls = ArraySize(history_bulls);
      for (int i = 0; i < total_bulls; i++)
      {
         FilteredSignal prev = history_bulls[i];
         if (prev.shift <= current_shift) continue;

         // 基础区间：从 Close(最高) 到 SL(最低)
         double zone_top = prev.confirmation_close;
         double zone_bottom = prev.stop_loss;

         if (current_low <= zone_top && current_high >= zone_bottom)
         {
            // -----------------------------------------------------------
            // 🎨 可视化绘制：看涨回踩 (同向确认) -> 绘制 深灰色 线条
            // -----------------------------------------------------------

            string obj_name = link_prefix + (string)Time[current_shift] + "_" + (string)prev.signal_time;

            datetime t1 = Time[current_shift];
            double p1 = Close[current_shift];
            datetime t2 = prev.signal_time;
            double p2 = prev.confirmation_close;

            // 调用绘图 (深灰色)
            DrawContextLinkLine(obj_name, t1, p1, t2, p2, clrDarkGray);

            // -----------------------------------------------------------

            Print(" [上下文-回踩] 当前看涨(K", current_shift, ") 回踩 历史看涨(K", prev.shift, ") 基础区间");
            return 2;
         }
         break;
      }
   }

   // 如果都不满足
   return 0;
}

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
//| 2.0 移除单一的简单判断上下文的逻辑 被CheckSignalContext 替代
//| 核心决策函数：检查信号有效性并执行防重复过滤
//| 去除了 L3a (新鲜度) 和 L3b (最大风险)，仅保留核心逻辑
//+------------------------------------------------------------------+
int CheckSignalAndFilter_V2(const KBarSignal &data, int signal_shift)
{
   int trade_command = OP_NONE; // 初始化为 -1

   // ------------------------------------------------------------------
   // 准备工作：计算当前的均线数值 (基于当前的 signal_shift) 1分钟测试效果不好 可以选择关闭它
   // ------------------------------------------------------------------
   double ma_value = 0;
   if (Use_Trend_Filter)
   {
      // iMA 函数详解见下文
      ma_value = iMA(_Symbol, 0, Trend_MA_Period, 0, Trend_MA_Method, PRICE_CLOSE, signal_shift);
      ma_value = NormalizeDouble(ma_value, Digits());
   }

   // ------------------------------------------------------------------
   // 步骤 1: L2 信号侦测与质量筛选 (Buffer 2 & 3)
   // ------------------------------------------------------------------

   // --- A. 优先检查看涨信号 ---
   // 检查 Buffer 2 是否有值 (不为空且不为0)
   if (data.BullishReferencePrice != (double)EMPTY_VALUE && data.BullishReferencePrice != 0.0 && data.BullishStopLossPrice != (double)EMPTY_VALUE && data.BullishStopLossPrice != 0.0)
   {
      // 调试日志：看到了原始信号
      // Print("[DEBUG] Shift=", signal_shift, " 发现看涨原始数据: ", data.BullishReferencePrice);

      // 质量门槛检查
      if ((int)data.BullishReferencePrice >= Min_Signal_Quality)
      {
         //1.0
         // trade_command = OP_BUY;
         // 找到符合质量的看涨信号，准备进入 L3c 检查

         //2.0
         // 🚨 B. 趋势过滤 (新增) 🚨
         // 如果开启了过滤，且 收盘价 < 均线，说明是逆势单，我们要过滤掉
         if (Use_Trend_Filter && Close[signal_shift] < ma_value)
         {
             Print("[趋势过滤] 忽略看涨信号 @ ", TimeToString(data.OpenTime), "。价格(", Close[signal_shift], ") 在均线(", ma_value, ")之下");
             // 不做任何操作，trade_command 保持 OP_NONE
         }
         else
         {
             // 3.0
             trade_command = OP_BUY; // 顺势，通过！
             // ... (原来的日志打印代码)
         }
      }
      else
      {
         // 调试日志：质量不够
         // Print("[DEBUG] Shift=", signal_shift, " 看涨被过滤。质量(", data.BullishReferencePrice, ") < 设定(", Min_Signal_Quality, ")");
      }
   }

   // --- B. 检查看跌信号 (仅当没有发现看涨信号时) ---
   if (trade_command == OP_NONE)
   {
      // 检查 Buffer 3 是否有值
      if (data.BearishReferencePrice != (double)EMPTY_VALUE && data.BearishReferencePrice != 0.0 && data.BearishStopLossPrice != (double)EMPTY_VALUE && data.BearishStopLossPrice != 0.0)
      {
         // 调试日志：看到了原始信号
         // Print("[DEBUG] Shift=", signal_shift, " 发现看跌原始数据: ", data.BearishReferencePrice);

         // 质量门槛检查
         if ((int)data.BearishReferencePrice >= Min_Signal_Quality)
         {
            // trade_command = OP_SELL;
            // 找到符合质量的看跌信号，准备进入 L3c 检查

            // 🚨 B. 趋势过滤 (新增) 🚨
            // 如果开启了过滤，且 收盘价 > 均线，说明是逆势单
            if (Use_Trend_Filter && Close[signal_shift] > ma_value)
            {
               // Print("[趋势过滤] 忽略看跌信号。价格在均线之上");
               Print("[趋势过滤] 忽略看跌信号 @ ", TimeToString(data.OpenTime), "。价格(", Close[signal_shift], ") 在均线(", ma_value, ")之上");
            }
            else
            {
               trade_command = OP_SELL; // 顺势，通过！
               // ... (原来的日志打印代码)
            }
         }
         else
         {
             // 调试日志：质量不够
             // Print("[DEBUG] Shift=", signal_shift, " 看跌被过滤。质量(", data.BearishReferencePrice, ") < 设定(", Min_Signal_Quality, ")");
         }
      }
   }

   // 如果 L2 检查完，trade_command 还是 -1，说明没有合格信号，直接返回，让循环继续找下一个 shift
   if (trade_command == OP_NONE) return OP_NONE;

   // ------------------------------------------------------------------
   // 步骤 2: L3c 信号重复性检查 (防重复交易)
   // ------------------------------------------------------------------
   
   // 程序运行到这里，说明 trade_command 已经是 OP_BUY 或 OP_SELL 了

   // 1. 🚨 L3c: 信号时效性过滤 (新增逻辑) 🚨
   // 检查 K[0] 是否紧跟信号成立 (即 signal_shift 必须为 1)
   if (!IsSignalTimely(signal_shift))
   {
      // 阻止开仓，让 for 循环继续寻找 shift=1 的信号
      return OP_NONE;
   }

   // 1. 🚨 L3a: 信号新鲜度过滤 (只允许扫描到的第一个合格信号通过) 🚨
   if (!IsSignalFresh(trade_command))
   {
      Print("L3a 过滤：这不是扫描到的第一个合格信号，阻止开仓。");
      return OP_NONE; // 阻止不新鲜的信号
   }

   // 1. 生成唯一 ID
   string signal_id = GenerateSignalID(data.OpenTime);
   
   // 2. 检查历史订单和持仓
   if (IsSignalAlreadyTraded(signal_id))
   {
      // 既然已交易，我们必须阻止这次开仓，返回 OP_NONE
      // 这会导致外层循环继续向历史回溯，寻找更早之前的未交易信号
      Print(">>> 信号 ID: ", signal_id, " 已在历史/持仓中找到，跳过此信号。 <<<");
      return OP_NONE; 
   }

   // ------------------------------------------------------------------
   // 步骤 3: 最终放行
   // ------------------------------------------------------------------
   
   // 只有到了这里，才说明：
   // 1. 信号存在且质量达标
   // 2. 信号没有被交易过
   
   // 打印最终确认日志
   Print(" 最终决策通过: Shift=", signal_shift, 
         " | 类型: ", (trade_command==OP_BUY?"BUY":"SELL"), 
         " | 质量: ", (trade_command==OP_BUY ? DoubleToString(data.BullishReferencePrice,1) : DoubleToString(data.BearishReferencePrice,1)),
         " | ID: ", signal_id);

   return trade_command; // 返回有效指令，这将导致外层 OnTick 循环立即停止！
}