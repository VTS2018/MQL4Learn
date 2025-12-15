//+------------------------------------------------------------------+
//|                                                   KBot_Utils.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 09.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| MQL4 缺失函数：StringTrim (用于移除字符串首尾空格)                |
//+------------------------------------------------------------------+
string StringTrim(string str)
{
   int len = StringLen(str);
   if (len == 0) return str;
   
   // 移除开头的空格
   int start = 0;
   while (start < len && StringGetChar(str, start) == ' ')
   {
      start++;
   }
   
   // 如果整个字符串都是空格
   if (start == len) return "";
   
   // 移除末尾的空格
   int end = len - 1;
   while (end > start && StringGetChar(str, end) == ' ')
   {
      end--;
   }
   
   // 返回修剪后的子字符串
   return StringSubstr(str, start, end - start + 1);
}

//+------------------------------------------------------------------+
//| Helper: 解析单个斐波那契区域字符串 (例如 "1.618, 1.88")         |
//+------------------------------------------------------------------+
bool ParseFiboZone(string fibo_str, double &level1, double &level2)
{
    string tokens[];
    // 使用逗号作为分隔符分割字符串
    int count = StringSplit(fibo_str, ',', tokens);
    
    // 必须正好包含两个级别
    if (count != 2) return false;
    
    // 将字符串转换为双精度浮点数
    level1 = StringToDouble(StringTrim(tokens[0]));
    level2 = StringToDouble(StringTrim(tokens[1]));
    
    // 简单验证：级别不能小于或等于 0
    if (level1 <= 0 || level2 <= 0) return false; 
    
    // 成功解析
    return true;
}

//+------------------------------------------------------------------+
//| 辅助函数：生成绝对唯一的信号 ID (品种前缀_周期_日时分)
//| 新格式: BTC_M1021806
//+------------------------------------------------------------------+
string GenerateSignalID(datetime signal_time)
{
   // --- 定义辅助变量 (保持不变) ---
   string find_underscore = "_" + "";
   string find_dot = "." + "";
   string find_colon = ":" + "";
   string replace_empty = "" + "";
   
   // 1. 获取品种前缀 (例如: BTCUSD -> BTC) [cite: 47]
   string symbol_prefix = _Symbol;
   if (StringLen(_Symbol) >= 3)
   {
      symbol_prefix = StringSubstr(_Symbol, 0, 3); // 截取前 3 个字符 [cite: 49]
   }

   // 2. 清理品种名中的下划线/点
   string temp_symbol = symbol_prefix;
   StringReplace(temp_symbol, find_underscore, replace_empty); // [cite: 50]
   StringReplace(temp_symbol, find_dot, replace_empty);        // [cite: 51]

   // ----------------------------------------------------
   // 3. 修正日期/时间获取逻辑 (新格式：日时分 DHHMM)
   // ----------------------------------------------------

   // 3.1 获取完整日期: "yyyy.mm.dd" (用于截取日) [cite: 51]
   string full_date = TimeToString(signal_time, TIME_DATE);

   // 3.2 截取日部分: 从第 8 位开始，长度为 2 ("dd")
   // 格式： yyyy.mm.dd
   // 索引： 0123456789
   string day = StringSubstr(full_date, 8, 2); 
   
   // 3.3 获取时间: "hh:mi" (时分) [cite: 53]
   string hour_minute = TimeToString(signal_time, TIME_MINUTES);

   // 4. 清理时间分隔符 (只清理时分)
   string temp_hour_minute = hour_minute;
   StringReplace(temp_hour_minute, find_colon, replace_empty); // [cite: 55]

   // ----------------------------------------------------
   // 5. 最终 ID 拼接
   // ----------------------------------------------------

   // 获取周期名称 (例如: "M1", "H4", "D1")
   string timeframe_name = GetTimeframeName(Period());
   
   // 格式: 品种前缀_周期_日时分 (例如：BTC_M1021806)
   // 注意：我们移除了下划线，直接连接
   return temp_symbol + "_" + timeframe_name + day + temp_hour_minute; 
}

//+------------------------------------------------------------------+
//| 获取当前品种的每手合约大小 (Contract Size)                       |
//+------------------------------------------------------------------+
double GetContractSize()
{
    // MarketInfo(symbol, type)
    // Symbol()      : 当前图表上的品种名称
    // MODE_LOTSIZE  : 请求每手合约大小 (例如: 100000 用于外汇标准手, 100 用于黄金)
    
    double contract_size = MarketInfo(Symbol(), MODE_LOTSIZE);
    
    // 检查返回值是否有效
    if (contract_size <= 0)
    {
        Print(" 错误: 无法获取品种 ", Symbol(), " 的合约大小，返回值: ", contract_size);
        // 通常会返回一个默认值或终止EA
        return 100000.0; // 返回一个标准外汇合约大小作为安全值
    }
    
    return contract_size;
}

//+------------------------------------------------------------------+
//| 方法1：基于合约大小的计算 (您的习惯方式)                         |
//+------------------------------------------------------------------+
double CalculateLots_ByContract(double entry_price, double sl_price, double risk_money)
{
   double price_diff = MathAbs(entry_price - sl_price); // 计算价格差 (10.15)
   double contract_size = MarketInfo(Symbol(), MODE_LOTSIZE); // 获取合约大小 (100)
   
   // 防止除以0
   if (price_diff == 0 || contract_size == 0) return 0;

   // 计算做1标准手会亏损的金额
   double loss_per_lot = contract_size * price_diff; // 100 * 10.15 = 1015
   
   // 计算手数
   double lots = risk_money / loss_per_lot; // 100 / 1015 = 0.0985...
   
   return NormalizeLots(lots); // ⚠️ 必须进行手数修正(见文末)
}

//+------------------------------------------------------------------+
//| 方法2：基于 TickValue 的通用计算 (推荐用于 EA)                   |
//+------------------------------------------------------------------+
double CalculateLots_ByTickValue(double entry_price, double sl_price, double risk_money)
{
   double price_diff = MathAbs(entry_price - sl_price);
   double tick_size  = MarketInfo(Symbol(), MODE_TICKSIZE);  // 例如 0.01
   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE); // 例如 1.0 (1手跳一下是多少钱)

   if (tick_size == 0 || tick_value == 0) return 0;

   // 1. 计算止损是多少个 "Tick" (微点)
   // 例如: 10.15 / 0.01 = 1015 个 Tick
   double ticks = price_diff / tick_size; 

   // 2. 计算手数
   // 公式: 风险 / (跳动次数 * 单次跳动价值)
   double lots = risk_money / (ticks * tick_value); 

   return NormalizeLots(lots); // ⚠️ 必须进行手数修正
}

/*
//+------------------------------------------------------------------+
//| 辅助函数：修正手数 (符合平台规则)                                |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double min_lot  = MarketInfo(Symbol(), MODE_MINLOT);  // 最小手数 (通常 0.01)
   double max_lot  = MarketInfo(Symbol(), MODE_MAXLOT);  // 最大手数
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP); // 手数步长 (通常 0.01)

   // 1. 向下取整到步长 (例如 0.098522 -> 0.09)
   // 也可以使用 MathRound 进行四舍五入，看您偏好风险控制的严格程度
   // 这里演示的是标准步长修正：
   lots = MathFloor(lots / lot_step) * lot_step; 

   // 2. 限制在最小和最大范围内
   if (lots < min_lot) lots = min_lot; // 如果算出来太小，至少开最小手 (或者您可以选择不开)
   if (lots > max_lot) lots = max_lot;

   return lots;
}
*/

//+------------------------------------------------------------------+
//| 资金管理模块：核心计算库                                           |
//+------------------------------------------------------------------+

// 定义仓位计算模式
enum ENUM_POS_SIZE_MODE
{
   POS_FIXED_LOT,       // 模式 A: 固定手数 (例如 0.01 手)
   POS_RISK_BASED       // 模式 B: 以损定仓 (根据止损距离计算)
};

// 定义风险计算模式
enum ENUM_RISK_MODE
{
   RISK_FIXED_MONEY,    // 单笔固定止损金额 (例如: $100)
   RISK_PERCENTAGE      // 单笔账户余额百分比 (例如: 3%)
};

//+------------------------------------------------------------------+
//| 1. 基础工具：修正手数 (符合平台规则)                                |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double min_lot  = MarketInfo(Symbol(), MODE_MINLOT);
   double max_lot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);

   // 向下取整到步长 (防止 0.138 -> 0.13 导致风险略微超标，宁可少开不可多开)
   // 如果偏好四舍五入，可改用 MathRound
   lots = MathFloor(lots / lot_step) * lot_step;

   // 边界检查
   if (lots < min_lot) return min_lot; // 注意：如果算出来比最小手数还小，通常建议不交易，这里返回最小手数需谨慎
   if (lots > max_lot) return max_lot;

   return lots;
}

//+------------------------------------------------------------------+
//| 2. 策略层：根据模式计算具体的“风险金额”                             |
//+------------------------------------------------------------------+
double CalculateRiskMoney(ENUM_RISK_MODE mode, double risk_value)
{
   double account_balance = AccountBalance();
   double final_risk_money = 0.0;

   switch(mode)
   {
      case RISK_FIXED_MONEY:
         // 直接使用固定金额，例如 100
         final_risk_money = risk_value;
         break;
         
      case RISK_PERCENTAGE:
         // 计算百分比金额，例如 10000 * 0.03 = 300
         // 输入 3 代表 3%，所以要除以 100
         final_risk_money = account_balance * (risk_value / 100.0);
         break;
         
      default:
         final_risk_money = 0.0;
   }
   
   return final_risk_money;
}

//+------------------------------------------------------------------+
//| 3. 核心层：以损定仓计算 (通用公式)                                  |
//| 参数:                                                            |
//|   entry_price: 入场价                                            |
//|   sl_price:    止损价                                            |
//|   risk_mode:   风险模式 (固定金额/百分比)                          |
//|   risk_value:  风险值 (如 100 或 3)                               |
//+------------------------------------------------------------------+
double GetPositionSize(double entry_price, double sl_price, ENUM_RISK_MODE risk_mode, double risk_value)
{
   // A. 计算具体的风险金额 (美元)
   double risk_money = CalculateRiskMoney(risk_mode, risk_value);
   
   if (risk_money <= 0) 
   {
      Print("Error: 计算出的风险金额无效 (<=0)");
      return 0;
   }

   // B. 获取市场数据
   double tick_size  = MarketInfo(Symbol(), MODE_TICKSIZE);  // 最小跳动点
   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE); // 单点价值
   
   if (tick_size == 0 || tick_value == 0)
   {
      Print("Error: 无法获取 TickSize 或 TickValue");
      return 0;
   }

   // C. 计算止损距离 (绝对值)
   double price_diff = MathAbs(entry_price - sl_price);
   
   // 防止止损过小 (例如 0 止损) 导致除零错误
   if (price_diff < tick_size) 
   {
      Print("Error: 止损距离太小，无法计算");
      return 0;
   }

   // D. 核心公式: 手数 = 风险金额 / ( (距离/TickSize) * TickValue )
   double ticks = price_diff / tick_size;
   double raw_lots = risk_money / (ticks * tick_value);

   // E. 修正手数
   return NormalizeLots(raw_lots);
}

//+------------------------------------------------------------------+
//| 辅助函数：根据风险模型计算仓位 (以损定仓核心算法) 这是单独独立出来的函数
//+------------------------------------------------------------------+
double GetPositionSize_V1(double entry_price, double sl_price, ENUM_RISK_MODE risk_mode, double risk_val)
{
   // 1. 计算具体的风险金额 (美元)
   double money_to_risk = 0.0;
   
   if (risk_mode == RISK_FIXED_MONEY)
   {
      money_to_risk = risk_val; // 直接使用固定金额，例如 100
   }
   else if (risk_mode == RISK_PERCENTAGE)
   {
      // 账户余额 * 百分比 (输入 3.0 代表 3%)
      money_to_risk = AccountBalance() * (risk_val / 100.0);
   }

   // 安全检查
   if (money_to_risk <= 0) return 0;

   // 2. 获取市场数据
   double tick_size  = MarketInfo(Symbol(), MODE_TICKSIZE);  // 最小跳动点
   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE); // 单点价值

   if (tick_size == 0 || tick_value == 0) return 0;

   // 3. 计算止损距离 (绝对值)
   double price_diff = MathAbs(entry_price - sl_price);
   
   // 防止除以零
   if (price_diff < tick_size) return 0; 

   // 4. 核心公式: 手数 = 风险金额 / ( (距离/TickSize) * TickValue )
   // 计算止损包含多少个 Tick
   double ticks = price_diff / tick_size;
   // 计算手数
   double raw_lots = money_to_risk / (ticks * tick_value);

   return NormalizeLots(raw_lots);
}

//+------------------------------------------------------------------+
//| 单元测试：验证仓位计算的准确性                                      |
//+------------------------------------------------------------------+
void Test_PositionSize_Logic()
{
   Print("========== 开始单元测试: 仓位计算模块 ==========");

   // 模拟场景：XAUUSD
   // 假设：账户 $10,000
   // 假设：TickSize=0.01, TickValue=1.0 (标准黄金合约)
   // 假设：入场 2000.00, 止损 1990.00 (距离 $10)
   
   double entry = 2000.00;
   double sl    = 1990.00;
   
   // --- 测试案例 1: 固定金额 $100 ---
   // 预期: 1手亏$10*100=$1000。 总风险$100。 
   // 预期手数 = 100 / 1000 = 0.1 手
   double lot1 = GetPositionSize(entry, sl, RISK_FIXED_MONEY, 100);
   Print("测试 1 [固定金额 $100]: 预期 0.10, 实际: ", DoubleToString(lot1, 2));
   
   // --- 测试案例 2: 百分比风险 3% ---
   // 账户余额读取的是当前的 AccountBalance()，假设为 10000 (演示时请自行脑补或在模拟盘核对)
   // 预期风险 = 10000 * 3% = $300
   // 预期手数 = 300 / 1000 = 0.3 手
   double lot2 = GetPositionSize(entry, sl, RISK_PERCENTAGE, 3.0);
   Print("测试 2 [百分比 3%]: (基于当前余额 ", AccountBalance(), ") 实际计算手数: ", DoubleToString(lot2, 2));

   // --- 测试案例 3: 极小止损 (测试 Normalize) ---
   // 止损 $1 (1999.00), 风险 $100
   // 1手亏$100。需要 1.0 手。
   double lot3 = GetPositionSize(entry, 1999.00, RISK_FIXED_MONEY, 100);
   Print("测试 3 [窄止损 $1]: 预期 1.00, 实际: ", DoubleToString(lot3, 2));

   Print("========== 结束单元测试: 仓位计算模块 ==========");
}

//+------------------------------------------------------------------+
//| 功能函数 1: 计算本机与服务器时间差值 (封装独立函数)
//+------------------------------------------------------------------+
void CalculateAndPrintTimeOffset()
{
   datetime server_time = TimeCurrent(); // MT4 服务器时间 (K线时间)
   datetime local_time  = TimeLocal();   // 本机电脑时间
   
   // 计算差值 (本机 - 服务器)
   g_TimeOffset_Sec = local_time - server_time;
   
   // 计算小时差 (用于直观显示)
   double hour_diff = (double)g_TimeOffset_Sec / 3600.0;
   
   // 打印详细信息到日志
   Print("=======================================");
   Print("【时间同步系统启动】");
   Print("1. MT4服务器时间: ", TimeToString(server_time, TIME_DATE|TIME_SECONDS));
   Print("2. 本机电脑时间 : ", TimeToString(local_time, TIME_DATE|TIME_SECONDS));
   Print("3. 时间偏差值   : ", IntegerToString(g_TimeOffset_Sec), " 秒 (约 ", DoubleToString(hour_diff, 1), " 小时)");
   Print("4. 说明: 正数代表本机比服务器快，负数代表比服务器慢");
   Print("=======================================");
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