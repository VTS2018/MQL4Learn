//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+


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
void UpdateCSLByHistory()
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
      // Print("风险解除: 连续止损锁定已到期，EA 恢复正常交易。");
      g_CSLLockoutEndTime = 0;
      // g_ConsecutiveLossCount = 0; // 锁定结束后，必须重置计数器===>2.0版本下此行代码注销
      return false;
   }

   // 4. 仍在锁定期间
   // Print("交易锁定中: CSL 触发，等待解除时间: ", TimeToString(g_CSLLockoutEndTime, TIME_DATE | TIME_SECONDS));
   return true;
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
//| UpdateDailyProfit V3.0 (逻辑安全 + 调试版)
//| 修复：防止因性能优化逻辑导致跨天重置被跳过
//+------------------------------------------------------------------+
void UpdateDailyProfit_V3()
{
   // =========================================================
   // 1. 获取基础数据
   // =========================================================
   datetime today_start = iTime(NULL, PERIOD_D1, 0); // 今天 00:00
   
   // =========================================================
   // 2. 🚨 跨天重置逻辑 (最高优先级 - 必须先执行) 🚨
   // =========================================================
   if (g_Last_Calc_Date != today_start)
   {
      Print("📅 [新的一天] 日期变更: ", TimeToString(g_Last_Calc_Date), " -> ", TimeToString(today_start));
      Print("   [重置前] 昨日盈亏: ", DoubleToString(g_Today_Realized_PL, 2));
      
      // 强制归零
      g_Today_Realized_PL = 0.0;
      
      // 更新日期标记
      g_Last_Calc_Date = today_start;
      
      Print("   [重置后] 今日盈亏已归零。");
   }

   // =========================================================
   // 3. 性能优化逻辑 (只有在处理完跨天重置后，才允许 Return)
   // =========================================================
   static int s_last_history_total = 0;
   int current_history_total = OrdersHistoryTotal();

   // 如果历史订单数没变，说明没有新平仓，不需要重新计算累加
   // 注意：这里 return 之前，上面的重置逻辑已经执行过了，所以是安全的。
   if (current_history_total == s_last_history_total) return;

   // =========================================================
   // 4. 全量扫描逻辑 (计算盈亏)
   // =========================================================
   double temp_daily_profit = 0.0;
   
   for (int i = 0; i < current_history_total; i++)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if (OrderType() > OP_SELL) continue;

      // 只计算今天产生的订单
      if (OrderCloseTime() < today_start) continue;

      temp_daily_profit += OrderProfit() + OrderCommission() + OrderSwap();
   }

   // =========================================================
   // 5. 更新全局状态
   // =========================================================
   g_Today_Realized_PL = temp_daily_profit;
   
   // 更新缓存快照
   s_last_history_total = current_history_total; 
   g_Last_Daily_Check_Time = TimeCurrent();
   
   // 仅在数据变化时打印，避免刷屏
   // Print("[盈亏变动] 最新今日盈亏: ", DoubleToString(g_Today_Realized_PL, 2));
}

//+------------------------------------------------------------------+
//| UpdateDailyProfit V4.0 (终极稳定版)
//| 核心思想：无状态计算。每一帧都根据当前时间，重新统计当日盈亏。
//| 修复：彻底解决 iTime 延迟和静态变量导致的数据冻结问题。
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
   // =========================================================
   // 1. 手动计算“今天 00:00:00”的时间戳 (不依赖 iTime)
   // =========================================================
   datetime current_time = TimeCurrent();
   
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   
   // 将时分秒归零，得到绝对的当天起始时间
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   
   datetime today_start = StructToTime(dt);

   // =========================================================
   // 2. 暴力全量扫描 (Stateless Calculation)
   // =========================================================
   // 放弃 static 缓存，确保只要时间变了，结果就能自动变。
   
   int total_history = OrdersHistoryTotal();
   double temp_daily_profit = 0.0;
   
   for (int i = 0; i < total_history; i++)
   {
      // 必须使用 continue，不能 break
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false) continue;
      
      // A. 基础过滤
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      // B. 类型过滤 (只计算交易单)
      if (OrderType() > OP_SELL) continue;

      // C. 核心时间过滤：只累加“今天0点”以后的单子
      // 关键点：如果到了新的一天，today_start 会自动变大，
      // 昨天的单子就会因为不满足这个条件，而被自动过滤掉。
      // temp_daily_profit 自然就归零了。
      if (OrderCloseTime() < today_start) continue;

      // D. 累加
      temp_daily_profit += OrderProfit() + OrderCommission() + OrderSwap();
   }

   // =========================================================
   // 3. 更新全局变量与调试
   // =========================================================
   
   // 如果发现数据发生了变化 (例如跨天了，数值突然归零)，打印一条日志
   if (g_Today_Realized_PL != temp_daily_profit)
   {
      // 只有在数值真正改变时才打印，防止刷屏
      // Print(" [盈亏刷新] " + TimeToString(current_time) + 
      //       " | 旧值: " + DoubleToString(g_Today_Realized_PL, 2) + 
      //       " -> 新值: " + DoubleToString(temp_daily_profit, 2));
      
      // 特别监测：如果变成了0，说明跨天成功
      if (g_Today_Realized_PL != 0 && temp_daily_profit == 0)
      {
         Print(" [新的一天] 跨天自动重置成功！今日盈亏已归零。");
      }
   }

   // 强制更新全局变量
   g_Today_Realized_PL = temp_daily_profit;
   g_Last_Daily_Check_Time = current_time;
}

//+------------------------------------------------------------------+
//| IsDailyLossLimitReached V2.0
//| 功能：检查是否触及日内亏损红线
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached()
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

//+------------------------------------------------------------------+
//| 功能函数 2: 检查当前时间是否在配置的时段内
//+------------------------------------------------------------------+
bool IsCurrentTimeInSlots()
{
   // 1. 如果设置为空，默认全天运行
   if (Local_Trade_Slots == "") return true;

   // 2. 获取当前的服务器时间，并转换为【对应的本地时间】
   datetime current_server_time = TimeCurrent();
   // datetime calculated_local_time = current_server_time + g_TimeOffset_Sec;
   datetime calculated_local_time = (datetime)(current_server_time + g_TimeOffset_Sec);
   
   // 3. 提取当前本地时间的小时数 (0-23)
   int current_local_hour = TimeHour(calculated_local_time);
   
   // 4. 解析输入字符串 (例如 "9-11, 16-18")
   string slots[];
   // 按逗号分割成多个组
   int count = StringSplit(Local_Trade_Slots, ',', slots);
   
   for (int i = 0; i < count; i++)
   {
      string current_slot = slots[i];
      StringTrimLeft(current_slot);  // 去除空格
      StringTrimRight(current_slot);
      
      // 按连字符 "-" 分割开始和结束时间
      int hyphen_pos = StringFind(current_slot, "-");
      if (hyphen_pos > 0)
      {
         string str_start = StringSubstr(current_slot, 0, hyphen_pos);
         string str_end   = StringSubstr(current_slot, hyphen_pos + 1);
         
         int start_h = (int)StringToInteger(str_start);
         int end_h   = (int)StringToInteger(str_end);
         
         // 检查是否在范围内
         // 逻辑: Start <= 当前小时 < End
         // 例如 9-11，包含 9:00, 9:59, 10:00, 10:59，但不包含 11:00
         if (current_local_hour >= start_h && current_local_hour < end_h)
         {
            return true; // 命中其中一个时段，允许交易
         }
      }
   }
   
   return false; // 遍历完所有时段都未命中，禁止交易
}

//+------------------------------------------------------------------+
//| 功能函数 2: 检查当前时间是否在配置的时段内 (V2.0 - 支持跨午夜) 暂时没有用 保留它
//+------------------------------------------------------------------+
bool IsCurrentTimeInSlots_V2()
{
   // 1. 如果设置为空，默认全天运行
   if (Local_Trade_Slots == "") return true;

   // 2. 获取当前的服务器时间，并转换为【对应的本地时间】
   datetime current_server_time = TimeCurrent();
   datetime calculated_local_time = (datetime)(current_server_time + g_TimeOffset_Sec);

   // 3. 提取当前本地时间的小时数 (0-23)
   int current_local_hour = TimeHour(calculated_local_time);

   // 4. 解析输入字符串
   string slots[];
   int count = StringSplit(Local_Trade_Slots, ',', slots);

   for (int i = 0; i < count; i++)
   {
      string current_slot = slots[i];
      StringTrimLeft(current_slot);
      StringTrimRight(current_slot);

      int hyphen_pos = StringFind(current_slot, "-");
      if (hyphen_pos > 0)
      {
         string str_start = StringSubstr(current_slot, 0, hyphen_pos);
         string str_end   = StringSubstr(current_slot, hyphen_pos + 1);

         int start_h = (int)StringToInteger(str_start);
         int end_h   = (int)StringToInteger(str_end);

         // --- 核心逻辑修改开始 ---

         // 情况 A: 普通时段 (例如 9-11) -> 结束时间 > 开始时间
         if (start_h < end_h)
         {
             // 逻辑: Start <= 当前 < End
             if (current_local_hour >= start_h && current_local_hour < end_h)
                 return true;
         }
         // 情况 B: 跨午夜时段 (例如 20-00 或 22-05) -> 结束时间 <= 开始时间
         else
         {
             // 逻辑: (当前 >= Start) 或者 (当前 < End)
             // 例子 20-00: 
             //   20, 21, 22, 23 点 -> 满足 >= 20 (True)
             //   0 点 -> 满足 < 0 (False) -> 所以 00:00 停止
             // 例子 22-05:
             //   22, 23 点 -> 满足 >= 22 (True)
             //   0, 1, 2, 3, 4 点 -> 满足 < 5 (True)
             if (current_local_hour >= start_h || current_local_hour < end_h)
                 return true;
         }

         // --- 核心逻辑修改结束 ---
      }
   }

   return false;
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