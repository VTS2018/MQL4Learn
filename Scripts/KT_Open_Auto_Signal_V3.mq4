//+------------------------------------------------------------------+
//|                                     Open_Auto_Signal_V2_Sync.mq4 |
//|                自动读取主图指标参数并寻找信号 (消除参数不一致风险)        |
//+------------------------------------------------------------------+
#property copyright "KTarget User"
#property strict
#property show_inputs

// --- 核心枚举 ---
enum ENUM_POS_SIZE_MODE { POS_FIXED_LOT, POS_RISK_BASED };
enum ENUM_RISK_MODE     { RISK_FIXED_MONEY, RISK_PERCENTAGE };
enum ENUM_TRADE_DIR     { DIR_AUTO, DIR_BUY, DIR_SELL }; 

//+------------------------------------------------------------------+
//| ✅ 智能交易设置
//+------------------------------------------------------------------+
input string         __TRADE_SET__    = "--- 智能交易指令 ---";
input ENUM_TRADE_DIR Trade_Direction  = DIR_AUTO;    
input int            Scan_Range_Bar   = 30;          // 脚本扫描最近多少根K线寻找信号
input int            SL_Lookback      = 50;          // 止损回溯范围
input double         Manual_SL_Price  = 0.0;         

//+------------------------------------------------------------------+
//| ✅ 资金管理设置
//+------------------------------------------------------------------+
input string         __MONEY_MGMT__   = "--- 资金管理设置 ---";
input ENUM_POS_SIZE_MODE Position_Mode = POS_RISK_BASED; 
input double   FixedLot       = 0.01;
input int      Slippage       = 3;
input double   RewardRatio    = 1.5;         
input ENUM_RISK_MODE Risk_Mode = RISK_FIXED_MONEY;
input double         Risk_Value      = 100.0; 

// --- 指标文件名 (必须一致) ---
const string IND_NAME = "KTarget_Finder_MT7"; 

// --- 全局变量用于存储从图表读取到的参数 ---
bool   P_Smart_Tuning;
int    P_Scan_Range;
int    P_La_B, P_Lb_B, P_La_T, P_Lb_T;
int    P_Max_Signal, P_DB_Thres, P_LLHH, P_Find_Model;

//+------------------------------------------------------------------+
//| 脚本主函数
//+------------------------------------------------------------------+
void OnStart()
{
   // 1. 🛡️ 读取图表参数 (核心步骤)
   if (!ReadParamsFromChart()) {
      Alert(" 错误：未读取到指标参数！\n请确保 KTarget_Finder_MT7 已加载到图表上。");
      return; 
   }

   int signal_bar = -1;
   int op_type = -1;
   
   // 2. 🤖 扫描信号 (使用读取到的参数)
   if (Trade_Direction == DIR_AUTO)
      signal_bar = ScanForSignal(Scan_Range_Bar, -1, op_type); // -1=Auto
   else if (Trade_Direction == DIR_BUY) {
      signal_bar = ScanForSignal(Scan_Range_Bar, 0, op_type);  // 0=Buy
      op_type = OP_BUY;
   }
   else if (Trade_Direction == DIR_SELL) {
      signal_bar = ScanForSignal(Scan_Range_Bar, 1, op_type);  // 1=Sell
      op_type = OP_SELL;
   }

   if (signal_bar == -1) {
      Alert(" 范围内未找到有效信号！(已使用图表同款参数扫描)");
      return;
   }
   
   // 3. 🔍 寻找结构性止损
   double auto_sl_price = 0.0;
   int sl_anchor_bar = -1;
   
   if (Manual_SL_Price <= 0)
   {
       // 做多找Buffer0, 做空找Buffer1
       int buffer_id_sl = (op_type == OP_BUY) ? 0 : 1;
       
       for (int k = signal_bar; k < signal_bar + SL_Lookback; k++)
       {
           double val = GetIndicatorValue(buffer_id_sl, k); // 使用统一的取值函数
           if (val != 0 && val != EMPTY_VALUE)
           {
               auto_sl_price = val;
               sl_anchor_bar = k;
               break;
           }
       }
       
       if (auto_sl_price == 0) {
           Alert(" 找到信号但未找到锚点止损！建议检查 SL_Lookback。");
           return;
       }
   }
   else auto_sl_price = Manual_SL_Price;

   // 4. 🛡️ 执行开仓 (复用原有风控逻辑)
   ExecuteTrade(op_type, signal_bar, sl_anchor_bar, auto_sl_price);
}

/*
//+------------------------------------------------------------------+
//| 🛠️ 核心功能：从隐藏对象读取参数
//+------------------------------------------------------------------+
bool ReadParamsFromChart()
{
   string obj_name = "KTarget_Param_Store";
   if (ObjectFind(0, obj_name) == -1) return false;
   
   string text = ObjectGetString(0, obj_name, OBJPROP_TEXT);
   string params[];
   int count = StringSplit(text, '|', params);
   
   // 必须匹配 Config_Core.mqh 中的参数数量 (10个非EA参数)
   if (count < 10) { 
      Print("参数解析失败，数量不匹配: ", count); 
      return false; 
   }
   
   // 按顺序解析 (顺序必须与指标 SaveParamsToChart 严格一致)
   P_Smart_Tuning = (bool)params[0];
   P_Scan_Range   = (int)StringToInteger(params[1]);
   P_La_B         = (int)StringToInteger(params[2]);
   P_Lb_B         = (int)StringToInteger(params[3]);
   P_La_T         = (int)StringToInteger(params[4]);
   P_Lb_T         = (int)StringToInteger(params[5]);
   P_Max_Signal   = (int)StringToInteger(params[6]);
   P_DB_Thres     = (int)StringToInteger(params[7]);
   P_LLHH         = (int)StringToInteger(params[8]);
   P_Find_Model   = (int)StringToInteger(params[9]);
   
   Print(" 成功同步参数: Scan=", P_Scan_Range, " DB=", P_DB_Thres, " Model=", P_Find_Model);
   return true;
}
*/

//+------------------------------------------------------------------+
//| 🛠️ 核心功能：从隐藏对象读取参数 (修正版)
//+------------------------------------------------------------------+
bool ReadParamsFromChart()
{
   string obj_name = "KTarget_Param_Store";
   if (ObjectFind(0, obj_name) == -1) return false;
   
   string text = ObjectGetString(0, obj_name, OBJPROP_TEXT);
   string params[];
   int count = StringSplit(text, '|', params);
   
   // 必须匹配 Config_Core.mqh 中的参数数量 (10个非EA参数)
   if (count < 10) { 
      Print("参数解析失败，数量不匹配: ", count); 
      return false; 
   }
   
   // 按顺序解析
   // 1. 修复 bool 类型转换错误: 使用 StringToInteger
   P_Smart_Tuning = (StringToInteger(params[0]) != 0);
   
   // 2. 其他 int 类型保持不变
   P_Scan_Range   = (int)StringToInteger(params[1]);
   P_La_B         = (int)StringToInteger(params[2]);
   P_Lb_B         = (int)StringToInteger(params[3]);
   P_La_T         = (int)StringToInteger(params[4]);
   P_Lb_T         = (int)StringToInteger(params[5]);
   P_Max_Signal   = (int)StringToInteger(params[6]);
   P_DB_Thres     = (int)StringToInteger(params[7]);
   P_LLHH         = (int)StringToInteger(params[8]);
   P_Find_Model   = (int)StringToInteger(params[9]);
   
   Print(" 成功同步参数: Scan=", P_Scan_Range, " DB=", P_DB_Thres, " Model=", P_Find_Model);
   return true;
}

//+------------------------------------------------------------------+
//| 🛠️ 核心功能：统一调用 iCustom (带完整参数)
//+------------------------------------------------------------------+
double GetIndicatorValue(int buffer_idx, int shift)
{
   // ⚠️ 这里的 Is_EA_Mode 强制设为 true，防止脚本删对象
   // ⚠️ 后面的参数使用我们刚读取到的全局变量
   return iCustom(NULL, 0, IND_NAME,
                  true,             // Is_EA_Mode (Script force TRUE)
                  P_Smart_Tuning,   // Smart_Tuning_Enabled
                  P_Scan_Range,     // Scan_Range
                  P_La_B,           // Lookahead_Bottom
                  P_Lb_B,           // Lookback_Bottom
                  P_La_T,           // Lookahead_Top
                  P_Lb_T,           // Lookback_Top
                  P_Max_Signal,     // Max_Signal_Lookforward
                  P_DB_Thres,       // DB_Threshold_Candles
                  P_LLHH,           // Look_LLHH_Candles
                  P_Find_Model,     // Find_Target_Model
                  buffer_idx, 
                  shift);
}

//+------------------------------------------------------------------+
//| 辅助：扫描信号
//+------------------------------------------------------------------+
int ScanForSignal(int range, int mode, int &out_type)
{
   for (int i = 1; i <= range; i++)
   {
      double buy = (mode == 1) ? 0 : GetIndicatorValue(2, i); // Buffer 2
      double sell = (mode == 0) ? 0 : GetIndicatorValue(3, i); // Buffer 3
      
      if (buy != 0 && buy != EMPTY_VALUE) { out_type = OP_BUY; return i; }
      if (sell != 0 && sell != EMPTY_VALUE) { out_type = OP_SELL; return i; }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| 风控与下单 (逻辑不变)
//+------------------------------------------------------------------+
void ExecuteTrade(int op_type, int sig_bar, int sl_bar, double sl_price)
{
   double entry = (op_type == OP_BUY) ? Ask : Bid;
   color clr = (op_type == OP_BUY) ? clrBlue : clrRed;
   
   // 简单的止损检查
   if (op_type == OP_BUY && sl_price >= entry) { Alert("止损错误"); return; }
   if (op_type == OP_SELL && sl_price <= entry) { Alert("止损错误"); return; }
   
   double dist = MathAbs(entry - sl_price);
   double tp_price = (op_type == OP_BUY) ? (entry + dist * RewardRatio) : (entry - dist * RewardRatio);
   
   // 计算仓位
   double lots = FixedLot;
   if (Position_Mode == POS_RISK_BASED) {
      double risk_money = (Risk_Mode == RISK_FIXED_MONEY) ? Risk_Value : AccountBalance() * Risk_Value / 100.0;
      double tick_val = MarketInfo(Symbol(), MODE_TICKVALUE);
      double loss_per_lot = (dist / Point) * tick_val; // 简易计算
      if(loss_per_lot > 0) lots = risk_money / loss_per_lot;
      
      // 规范化
      double step = MarketInfo(Symbol(), MODE_LOTSTEP);
      lots = MathFloor(lots / step) * step;
      double min = MarketInfo(Symbol(), MODE_MINLOT);
      if(lots < min) lots = min;
   }
   
   string comm = StringFormat("SyncK:%d_SL:%d", sig_bar, sl_bar);
   int ticket = OrderSend(Symbol(), op_type, lots, entry, Slippage, sl_price, tp_price, comm, 0, 0, clr);
   
   if(ticket > 0) Print("开仓成功 Ticket: ", ticket);
   else Alert("开仓失败: ", GetLastError());
}