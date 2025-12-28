//+------------------------------------------------------------------+
//|                                           Open_Auto_Signal.mq4 |
//|                自动寻找最近 K-Target 信号并计算风控开仓             |
//+------------------------------------------------------------------+

/**
 * 本脚本寻找止损点的时候有问题，使用的是信号的最高价和最低价
 * 但是逻辑是清晰的
 * 
 * 
*/

#property copyright "KTarget User"
#property strict
#property show_inputs  // 运行时弹出参数窗口

// --- 核心枚举定义 ---
enum ENUM_POS_SIZE_MODE { POS_FIXED_LOT, POS_RISK_BASED };
enum ENUM_RISK_MODE     { RISK_FIXED_MONEY, RISK_PERCENTAGE };
enum ENUM_TRADE_DIR     { DIR_AUTO, DIR_BUY, DIR_SELL }; // 新增 AUTO 模式

//+------------------------------------------------------------------+
//| ✅ 智能交易设置
//+------------------------------------------------------------------+
input string         __TRADE_SET__    = "--- 智能交易指令 ---";
input ENUM_TRADE_DIR Trade_Direction  = DIR_AUTO;    // 交易方向 (AUTO=自动识别最近信号)
input int            Scan_Range       = 20;          // 扫描范围 (自动回溯寻找最近N根K线)
input double         Manual_SL_Price  = 0.0;         // [可选] 手动止损价 (0=自动用信号K线极值)

//+------------------------------------------------------------------+
//| ✅ 资金管理设置 (复用 Bot7)
//+------------------------------------------------------------------+
input string         __MONEY_MGMT__   = "--- 资金管理设置 ---";
input ENUM_POS_SIZE_MODE Position_Mode = POS_RISK_BASED; 
input double   FixedLot       = 0.01;
input int      Slippage       = 3;
input double   RewardRatio    = 1.5;         // 盈亏比
input ENUM_RISK_MODE Risk_Mode = RISK_FIXED_MONEY;
input double         Risk_Value      = 100.0; 

// --- 指标名称常量 (必须与文件名一致) ---
const string IND_NAME = "KTarget_Finder_MT7"; 

//+------------------------------------------------------------------+
//| 脚本主函数
//+------------------------------------------------------------------+
void OnStart()
{
   // signal_bar是信号确认K线 但是不是止损K线
   int signal_bar = -1;
   int op_type = -1;
   
   // 1. 🤖 自动扫描信号
   if (Trade_Direction == DIR_AUTO)
   {
      // 寻找最近的任意信号
      signal_bar = ScanForLatestSignal(Scan_Range, op_type);
   }
   else if (Trade_Direction == DIR_BUY)
   {
      // 只找多头
      signal_bar = ScanForSpecificSignal(Scan_Range, 0); // 0=Buy Buffer
      op_type = OP_BUY;
   }
   else if (Trade_Direction == DIR_SELL)
   {
      // 只找空头
      signal_bar = ScanForSpecificSignal(Scan_Range, 1); // 1=Sell Buffer
      op_type = OP_SELL;
   }

   // 2. 检查是否找到
   if (signal_bar == -1)
   {
      Alert(" 范围内未找到有效信号！请检查指标是否加载，或扩大扫描范围。");
      return;
   }
   
   // 3. 准备开仓数据
   double entry_price, sl_price, tp_price;
   color arrow_color;

   double p1_from_indicator = 0; // 用于接收指标传来的精确止损
   
   if (op_type == OP_BUY)
   {
      entry_price = Ask;
      arrow_color = clrBlue;

      // ✅ [修改点 1]：尝试以 EA 模式向指标索要 P1 价格 (Buffer 0)
      // 注意：这里的参数顺序必须与指标输入参数完全一致！
      // 假设 Is_EA_Mode 是第一个参数，传 true
      // 如果您有其他参数，必须在这里补齐
      p1_from_indicator = iCustom(NULL, 0, IND_NAME, true, true, 0, signal_bar);

      // 自动止损：读取信号K线的最低价
      if (Manual_SL_Price > 0)
      {
         sl_price = Manual_SL_Price;
      }
      else
      {
         // sl_price = iLow(NULL, 0, signal_bar);

         // ✅ [修改点 2]：智能判断
         if (p1_from_indicator != 0 && p1_from_indicator != EMPTY_VALUE)
         {
            sl_price = p1_from_indicator; // 拿到完美的 P1 结构止损！
            Print(" 成功获取结构性止损 P1: ", sl_price);
         }
         else
         {
            // 兜底方案：万一读不到，就用 K 线最低价 (虽然不完美，但能保命)
            sl_price = iLow(NULL, 0, signal_bar);
            Print(" 警告：未获取到 P1，降级使用 K 线最低价: ", sl_price);
         }
      }

      if (sl_price >= entry_price) { Alert(" 错误：多单止损必须低于现价"); return; }
      tp_price = entry_price + (entry_price - sl_price) * RewardRatio;
   }
   else
   {
      entry_price = Bid;
      arrow_color = clrRed;
      p1_from_indicator = iCustom(NULL, 0, IND_NAME, true, true, 1, signal_bar);

      // 自动止损：读取信号K线的最高价
      if (Manual_SL_Price > 0)
      {
         sl_price = Manual_SL_Price;
      }
      else
      {
         // sl_price = iHigh(NULL, 0, signal_bar);
         // ✅ [修改点 2]：智能判断
         if (p1_from_indicator != 0 && p1_from_indicator != EMPTY_VALUE)
         {
            sl_price = p1_from_indicator; // 拿到完美的 P1 结构止损！
            Print(" 成功获取结构性止损 P1: ", sl_price);
         }
         else
         {
            sl_price = iHigh(NULL, 0, signal_bar);
            Print(" 警告：未获取到 P1，降级使用 K 线最高价: ", sl_price);
         }
      }

      if (sl_price <= entry_price) { Alert(" 错误：空单止损必须高于现价"); return; }
      tp_price = entry_price - (sl_price - entry_price) * RewardRatio;
   }

   // 4. 计算手数
   double lots = (Position_Mode == POS_FIXED_LOT) ? FixedLot : CalculateRiskLotSize(sl_price, entry_price);
   
   // 5. 发送订单
   string comm = "AutoK" + IntegerToString(signal_bar); // 备注: 信号在几根K线前
   int ticket = OrderSend(Symbol(), op_type, lots, entry_price, Slippage, sl_price, tp_price, comm, 0, 0, arrow_color);
   
   if (ticket > 0) 
      Print(" 开仓成功! 信号源自: ", signal_bar, " 根K线前. Ticket:", ticket);
   else            
      Alert(" 开仓失败 Error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| 🔍 扫描器：寻找最近的任意信号 (返回 bar index, 引用传出 type)
//+------------------------------------------------------------------+
int ScanForLatestSignal(int range, int &out_type)
{
   // KTarget_Finder_MT7 缓冲区索引: 
   // Buffer 2 = Bullish Signal (多)
   // Buffer 3 = Bearish Signal (空)
   
   for (int i = 1; i <= range; i++)
   {
      // 读取指标值 (使用默认参数)
      double buy_sig  = iCustom(NULL, 0, IND_NAME, true, true, 2, i);
      double sell_sig = iCustom(NULL, 0, IND_NAME, true, true, 3, i);
      
      // 检查是否有值 (非 0 且 非 EMPTY_VALUE)
      bool is_buy  = (buy_sig != 0 && buy_sig != EMPTY_VALUE);
      bool is_sell = (sell_sig != 0 && sell_sig != EMPTY_VALUE);
      
      if (is_buy)
      {
         out_type = OP_BUY;
         return i; // 找到最近的信号，返回索引
      }
      
      if (is_sell)
      {
         out_type = OP_SELL;
         return i;
      }
   }
   return -1; // 未找到
}

//+------------------------------------------------------------------+
//| 🔍 扫描器：寻找特定方向信号
//+------------------------------------------------------------------+
int ScanForSpecificSignal(int range, int mode) // mode 0=Buy, 1=Sell
{
   int buffer_idx = (mode == 0) ? 2 : 3; // 2是多, 3是空
   // 往历史方向上扫描
   for (int i = 1; i <= range; i++)
   {
      double sig = iCustom(NULL, 0, IND_NAME, true, true, buffer_idx, i);
      if (sig != 0 && sig != EMPTY_VALUE) return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| 💰 风控计算模块 (保持不变)
//+------------------------------------------------------------------+
double CalculateRiskLotSize(double sl_price, double entry_price)
{
   double risk_money = (Risk_Mode == RISK_FIXED_MONEY) ? Risk_Value : AccountBalance() * (Risk_Value / 100.0);
   double dist_points = MathAbs(entry_price - sl_price) / Point;
   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tick_size  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if (tick_size == 0) tick_size = Point;
   
   double loss_per_lot = (dist_points * Point / tick_size) * tick_value;
   if (loss_per_lot <= 0) return FixedLot;
   
   double raw_lots = risk_money / loss_per_lot;
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);
   raw_lots = MathFloor(raw_lots / step) * step;
   
   double min = MarketInfo(Symbol(), MODE_MINLOT);
   double max = MarketInfo(Symbol(), MODE_MAXLOT);
   if (raw_lots < min) raw_lots = min;
   if (raw_lots > max) raw_lots = max;
   
   return raw_lots;
}