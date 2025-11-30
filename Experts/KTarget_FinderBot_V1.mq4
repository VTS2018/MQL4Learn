//+------------------------------------------------------------------+
//|                                           KTarget_FinderBot.mq4  |
//|                                         Copyright 2025, MQL Dev  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MQL Dev"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//====================================================================
// 1. 策略参数设置 (Strategy Inputs)
//====================================================================
input string   __STRATEGY_SETTINGS__ = "--- Strategy Settings ---";
input int      MagicNumber    = 88888;       // 魔术数字 (EA的身份证)
input double   FixedLot       = 0.01;        // 固定交易手数
input int      Slippage       = 3;           // 允许滑点 (点)
input double   RewardRatio    = 1.5;         // 盈亏比 (TP = SL距离 * Ratio)

//====================================================================
// 2. 指标参数映射 (Indicator Inputs)
// 🚨 注意：为了让 iCustom 正确工作，这里的参数必须与指标的 extern 参数完全一致且顺序相同
//====================================================================
input string   __INDICATOR_SETTINGS__ = "--- Indicator Settings ---";
input string   IndicatorName          = "KTarget_Finder5"; // 指标文件名(不带后缀)

// 对应 KTarget_Finder5.mq4 的输入参数
input bool     Indi_Smart_Tuning      = false; // Smart_Tuning_Enabled
input int      Indi_Scan_Range        = 500;   // Scan_Range
input int      Indi_Lookahead_Bottom  = 20;    // Lookahead_Bottom
input int      Indi_Lookback_Bottom   = 20;    // Lookback_Bottom
input int      Indi_Lookahead_Top     = 20;    // Lookahead_Top
input int      Indi_Lookback_Top      = 20;    // Lookback_Top
input int      Indi_Max_Signal_Look   = 20;    // Max_Signal_Lookforward
input int      Indi_DB_Threshold      = 3;     // DB_Threshold_Candles
input bool     Indi_DrawFibonacci     = true;  // Is_DrawFibonacciLines

//====================================================================
// 3. 全局变量
//====================================================================
datetime g_last_bar_time = 0; // 用于新K线检测

//+------------------------------------------------------------------+
//| OnInit: 初始化函数
//+------------------------------------------------------------------+
int OnInit()
{
   // 检查能否找到指标文件
   // 我们尝试读取一次，看是否报错
   double check = iCustom(NULL, 0, IndicatorName, 
                          Indi_Smart_Tuning, Indi_Scan_Range, 
                          Indi_Lookahead_Bottom, Indi_Lookback_Bottom,
                          Indi_Lookahead_Top, Indi_Lookback_Top,
                          Indi_Max_Signal_Look, Indi_DB_Threshold, Indi_DrawFibonacci,
                          2, 0); // 读取 Buffer 2, Index 0
   
   if(GetLastError() == 4802) // ERR_INDICATOR_CANNOT_LOAD
   {
      Alert("严重错误：无法加载指标 '", IndicatorName, "' ! 请检查文件名是否正确。");
      return(INIT_FAILED);
   }

   Print("KTarget_FinderBot 初始化成功。监控信号中...");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnTick: 核心逻辑循环 (每次报价跳动触发)
//+------------------------------------------------------------------+
void OnTick()
{
   // --- 1. 新K线检测机制 (New Bar Check) ---
   // 我们只在 K 线收盘时交易，避免在一根 K 线上反复开仓
   if(Time[0] == g_last_bar_time) return; 
   g_last_bar_time = Time[0]; // 更新时间

   // --- 2. 获取信号 (Communication) ---
   // 读取上根已收盘 K 线 (index 1) 的信号
   double buy_signal  = GetIndicatorSignal(2, 1); // Buffer 2 = Bullish Signal
   double sell_signal = GetIndicatorSignal(3, 1); // Buffer 3 = Bearish Signal

   // --- 3. 执行交易逻辑 ---
   
   // 3.1 处理买入信号
   if(buy_signal != EMPTY_VALUE && buy_signal != 0)
   {
      Print(">>> 侦测到看涨信号 @ ", Time[1]);
      
      // A. 寻找结构性止损 (寻找最近的 Buffer 0 锚点)
      double sl_price = FindStructuralSL(0, 1); 
      
      // 如果没找到锚点(极少情况)，就用最近低点做保护
      if(sl_price == 0) sl_price = Low[1] - 100 * Point; 

      // B. 计算止盈 (基于盈亏比)
      double risk = Ask - sl_price;
      double tp_price = Ask + (risk * RewardRatio);

      // C. 执行开仓
      ExecuteTrade(OP_BUY, FixedLot, sl_price, tp_price, "K-Target Buy");
   }

   // 3.2 处理卖出信号
   if(sell_signal != EMPTY_VALUE && sell_signal != 0)
   {
      Print(">>> 侦测到看跌信号 @ ", Time[1]);
      
      // A. 寻找结构性止损 (寻找最近的 Buffer 1 锚点)
      double sl_price = FindStructuralSL(1, 1);
      
      if(sl_price == 0) sl_price = High[1] + 100 * Point;

      // B. 计算止盈 (基于盈亏比)
      double risk = sl_price - Bid;
      double tp_price = Bid - (risk * RewardRatio);

      // C. 执行开仓
      ExecuteTrade(OP_SELL, FixedLot, sl_price, tp_price, "K-Target Sell");
   }
}

//====================================================================
// 4. 核心辅助函数库 (The Engine Room)
//====================================================================

//+------------------------------------------------------------------+
//| 函数: 读取 iCustom 指标值 (解决了通信问题)
//+------------------------------------------------------------------+
double GetIndicatorSignal(int buffer_index, int shift)
{
   // 注意：这里的参数列表必须非常精确，少一个都会导致读不到数据
   return iCustom(NULL, 0, IndicatorName, 
                  Indi_Smart_Tuning, 
                  Indi_Scan_Range, 
                  Indi_Lookahead_Bottom, Indi_Lookback_Bottom,
                  Indi_Lookahead_Top, Indi_Lookback_Top,
                  Indi_Max_Signal_Look, 
                  Indi_DB_Threshold, 
                  Indi_DrawFibonacci, // 即使不画线，为了函数签名匹配也要传
                  buffer_index, // 读取哪个缓冲区
                  shift);       // 读取哪根K线
}

//+------------------------------------------------------------------+
//| 函数: 寻找最近的结构性止损 (锚点价格)
//| buffer_index: 0=看涨锚点, 1=看跌锚点
//+------------------------------------------------------------------+
double FindStructuralSL(int buffer_index, int start_shift)
{
   // 向左回溯查找最近的一个锚点
   // 限制回溯 Scan_Range 根，避免死循环
   for(int i = start_shift; i < start_shift + Indi_Scan_Range; i++)
   {
      double val = GetIndicatorSignal(buffer_index, i);
      
      if(val != EMPTY_VALUE && val != 0)
      {
         // 找到了！
         // Buffer 0 存的是 Low - 偏移，Buffer 1 存的是 High + 偏移
         // 为了精确，我们直接取那一根K线的 Low 或 High
         if(buffer_index == 0) return Low[i];  // 看涨结构低点
         if(buffer_index == 1) return High[i]; // 看跌结构高点
      }
   }
   return 0; // 未找到
}

//+------------------------------------------------------------------+
//| 函数: 执行交易 (OrderSend 封装)
//+------------------------------------------------------------------+
void ExecuteTrade(int type, double lots, double sl, double tp, string comment)
{
   // 1. 规范化价格 (防止小数位错误)
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
   
   double open_price = (type == OP_BUY) ? Ask : Bid;
   open_price = NormalizeDouble(open_price, Digits);
   
   // 2. 发送订单
   int ticket = OrderSend(Symbol(), type, lots, open_price, Slippage, sl, tp, comment, MagicNumber, 0, clrNONE);
   
   // 3. 结果检查
   if(ticket > 0)
   {
      Print("订单执行成功! Ticket: ", ticket, " 类型: ", (type==OP_BUY?"BUY":"SELL"), " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("订单执行失败! 错误代码: ", GetLastError());
   }
}