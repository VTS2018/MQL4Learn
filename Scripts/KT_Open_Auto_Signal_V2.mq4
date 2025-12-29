//+------------------------------------------------------------------+
//|                                        Open_Auto_Signal_V2.mq4 |
//|          自动寻找 K-Target 信号并从 Buffer 0/1 读取结构性止损      |
//+------------------------------------------------------------------+
#property copyright "KTarget User"
#property strict
#property show_inputs  // 运行时弹出参数窗口

// --- 核心枚举定义 ---
enum ENUM_POS_SIZE_MODE { POS_FIXED_LOT, POS_RISK_BASED };
enum ENUM_RISK_MODE     { RISK_FIXED_MONEY, RISK_PERCENTAGE };
enum ENUM_TRADE_DIR     { DIR_AUTO, DIR_BUY, DIR_SELL }; 

//+------------------------------------------------------------------+
//| ✅ 智能交易设置
//+------------------------------------------------------------------+
input string         __TRADE_SET__    = "--- 智能交易指令 ---";
input ENUM_TRADE_DIR Trade_Direction  = DIR_AUTO;    // 交易方向
input int            Scan_Range       = 20;          // 信号扫描范围 (寻找最近N根K线内的信号)
input int            SL_Lookback      = 50;          // 止损回溯范围 (找到信号后，往回找多少根K线以匹配锚点)
input double         Manual_SL_Price  = 0.0;         // [可选] 手动止损价 (0=自动读取Buffer 0/1)

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
   int signal_bar = -1;
   int op_type = -1;
   
   // 1. 🤖 步骤一：扫描最近的信号 (Buffer 2 或 3)
   // ---------------------------------------------------------
   if (Trade_Direction == DIR_AUTO)
      signal_bar = ScanForLatestSignal(Scan_Range, op_type);
   else if (Trade_Direction == DIR_BUY) {
      signal_bar = ScanForSpecificSignal(Scan_Range, 0); // 0=Buy Mode
      op_type = OP_BUY;
   }
   else if (Trade_Direction == DIR_SELL) {
      signal_bar = ScanForSpecificSignal(Scan_Range, 1); // 1=Sell Mode
      op_type = OP_SELL;
   }

   if (signal_bar == -1) {
      Alert(" 范围内未找到有效信号 (Buffer 2/3 无数据)！");
      return;
   }
   
   // 2. 🔍 步骤二：寻找对应的结构性止损 (Buffer 0 或 1)
   // ---------------------------------------------------------
   double auto_sl_price = 0.0;
   int sl_anchor_bar = -1;
   
   // 如果没有设置手动止损，则自动去 Buffer 0/1 找
   if (Manual_SL_Price <= 0)
   {
       // 如果是做多，去 Buffer 0 找；如果是做空，去 Buffer 1 找
       int buffer_id_sl = (op_type == OP_BUY) ? 0 : 1;
       
       // 从信号K线开始，向历史回溯寻找最近的锚点
       // 因为 K-Target 的锚点 (SL) 一定在信号 (Signal) 之前或同期
       for (int k = signal_bar; k < signal_bar + SL_Lookback; k++)
       {
           double val = iCustom(NULL, 0, IND_NAME, true, buffer_id_sl, k);
           if (val != 0 && val != EMPTY_VALUE)
           {
               auto_sl_price = val;
               sl_anchor_bar = k;
               break; // 找到了最近的一个锚点，停止扫描
           }
       }
       
       if (auto_sl_price == 0) {
           Alert(" 找到信号(Bar ", signal_bar, ") 但未找到对应的止损锚点(Buffer ", buffer_id_sl, ")！请检查 SL_Lookback 设置。");
           return;
       }
   }
   else
   {
       auto_sl_price = Manual_SL_Price;
   }

   // 3. 🛡️ 步骤三：执行开仓与风控
   // ---------------------------------------------------------
   double entry_price, sl_price, tp_price;
   color arrow_color;
   
   if (op_type == OP_BUY)
   {
      entry_price = Ask;
      arrow_color = clrBlue;
      sl_price    = auto_sl_price;
      
      if (sl_price >= entry_price) { Alert(" 错误：多单止损价格(", sl_price, ")必须低于现价(", entry_price, ")"); return; }
      tp_price = entry_price + (entry_price - sl_price) * RewardRatio;
   }
   else
   {
      entry_price = Bid;
      arrow_color = clrRed;
      sl_price    = auto_sl_price; // 这里的 auto_sl_price 已经是 Buffer 1 的价格
      
      if (sl_price <= entry_price) { Alert(" 错误：空单止损价格(", sl_price, ")必须高于现价(", entry_price, ")"); return; }
      tp_price = entry_price - (sl_price - entry_price) * RewardRatio;
   }

   // 计算仓位
   double lots = (Position_Mode == POS_FIXED_LOT) ? FixedLot : CalculateRiskLotSize(sl_price, entry_price);
   
   // 修正备注信息：显示信号来自几根前，止损锚点来自几根前
   string comm = StringFormat("AutoK:%d_SL:%d", signal_bar, sl_anchor_bar);
   
   int ticket = OrderSend(Symbol(), op_type, lots, entry_price, Slippage, sl_price, tp_price, comm, 0, 0, arrow_color);
   
   if (ticket > 0) 
      Print(" 开仓成功! 信号K:", signal_bar, " 止损K:", sl_anchor_bar, " SL价:", sl_price, " Ticket:", ticket);
   else            
      Alert(" 开仓失败 Error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| 🔍 扫描器：寻找最近的任意信号 (返回 bar index, 引用传出 type)
//| 扫描 Buffer 2 (多) 和 Buffer 3 (空)
//+------------------------------------------------------------------+
int ScanForLatestSignal(int range, int &out_type)
{
   for (int i = 1; i <= range; i++)
   {
      double buy_sig  = iCustom(NULL, 0, IND_NAME, true, 2, i); // Buffer 2 = Bullish Signal Quality
      double sell_sig = iCustom(NULL, 0, IND_NAME, true, 3, i); // Buffer 3 = Bearish Signal Quality
      
      bool is_buy  = (buy_sig != 0 && buy_sig != EMPTY_VALUE);
      bool is_sell = (sell_sig != 0 && sell_sig != EMPTY_VALUE);
      
      if (is_buy) {
         out_type = OP_BUY;
         return i; 
      }
      if (is_sell) {
         out_type = OP_SELL;
         return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| 🔍 扫描器：寻找特定方向信号
//+------------------------------------------------------------------+
int ScanForSpecificSignal(int range, int mode) // mode 0=Buy, 1=Sell
{
   int buffer_idx = (mode == 0) ? 2 : 3; // 2=多信号, 3=空信号
   
   for (int i = 1; i <= range; i++)
   {
      double sig = iCustom(NULL, 0, IND_NAME, true, buffer_idx, i);
      if (sig != 0 && sig != EMPTY_VALUE) return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| 💰 风控计算模块 (复用 Bot7 逻辑)
//+------------------------------------------------------------------+
double CalculateRiskLotSize(double sl_price, double entry_price)
{
   double risk_money = (Risk_Mode == RISK_FIXED_MONEY) ? Risk_Value : AccountBalance() * (Risk_Value / 100.0);
   double dist_points = MathAbs(entry_price - sl_price) / Point;
   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tick_size  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if (tick_size == 0) tick_size = Point;
   
   // 简化通用公式
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