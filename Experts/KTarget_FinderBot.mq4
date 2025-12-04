//+------------------------------------------------------------------+
//|                                            KTarget_FinderBot.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#define OP_NONE -1

#include <K_Data.mqh>
#include <K_Utils.mqh>
#include <KBot_Logic.mqh>

//+------------------------------------------------------------------+
// --- Bot Core Settings ---
input string EA_Version_Tag = "V3";     // 版本信息标签，用于订单注释追踪
input bool   EA_Master_Switch       = true;     // 核心总开关：设置为 false 时，EA 不执行任何操作
//+------------------------------------------------------------------+

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
input bool     Indi_Is_EA_Mode        = true;  // 必须设置为 TRUE，以触发指标写入 SL 价格
input bool     Indi_Smart_Tuning      = false; // Smart_Tuning_Enabled
input int      Indi_Scan_Range        = 500;   // Scan_Range
input int      Indi_Lookahead_Bottom  = 20;    // Lookahead_Bottom
input int      Indi_Lookback_Bottom   = 20;    // Lookback_Bottom
input int      Indi_Lookahead_Top     = 20;    // Lookahead_Top
input int      Indi_Lookback_Top      = 20;    // Lookback_Top
input int      Indi_Max_Signal_Look   = 20;    // Max_Signal_Lookforward
input int      Indi_DB_Threshold      = 3;     // DB_Threshold_Candles
input int      Indi_LLHH_Candles      = 3;     // FindAbsoluteLowIndex
input int      Indi_Timer_Interval_Seconds = 5; // OnTimer 触发间隔 (秒)
input bool     Indi_DrawFibonacci     = false;  // Is_DrawFibonacciLines

//====================================================================
// 3. 全局变量
//====================================================================
datetime g_last_bar_time = 0; // 用于新K线检测

input int Indi_LastScan_Range = 300; // 扫描最近多少根 K 线 (Bot 1.0 逻辑)

input int Trade_Start_Hour = 8; // 开始交易小时 (例如 8)
input int Trade_End_Hour = 20;  // 结束交易小时 (例如 20)

input double Daily_Max_Loss_Pips = 100.0;      // 日最大亏损 (点数)
input double Daily_Target_Profit_Pips = 200.0; // 日盈利目标 (点数)
input int Daily_Max_Trades = 5;                // 日最大交易次数

input int Min_Signal_Quality = 2; // 最低信号质量要求: 1=IB, 2=P1-DB, 3=P2

extern bool Found_First_Qualified_Signal = false; // 追踪是否已找到第一个合格的信号

//====================================================================
// --- L2: 趋势过滤器参数 ---
input bool   Use_Trend_Filter    = false;   // 是否开启均线大趋势过滤
input int    Trend_MA_Period     = 200;    // 均线周期 (默认200，牛熊分界线)
input int    Trend_MA_Method     = MODE_EMA; // 均线类型: 0=SMA, 1=EMA, 2=SMMA, 3=LWMA
//====================================================================
// 函数声明
//====================================================================
KBarSignal GetIndicatorBarData(int shift);
//====================================================================

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 检查能否找到指标文件
   // 我们尝试读取一次，看是否报错
   double check = iCustom(_Symbol, _Period, IndicatorName, Indi_Is_EA_Mode,
                          Indi_Smart_Tuning, Indi_Scan_Range, 
                          Indi_Lookahead_Bottom, Indi_Lookback_Bottom,
                          Indi_Lookahead_Top, Indi_Lookback_Top,
                          Indi_Max_Signal_Look, Indi_DB_Threshold, Indi_LLHH_Candles, Indi_Timer_Interval_Seconds, Indi_DrawFibonacci,
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
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //--- destroy timer
  // EventKillTimer();
}

//+------------------------------------------------------------------+
//| OnTick: 核心逻辑循环 (每次报价跳动触发)
//+------------------------------------------------------------------+
void OnTick()
{

   //+------------------------------------------------------------------+
   // 🚨 1. 全局开关控制 🚨
   if (!EA_Master_Switch)
   {
      // 可以在这里添加一个可选的日志，但频繁打印会影响性能
      // Print("EA Master Switch is OFF. Operations suspended.");
      return; // 开关未启用，立即退出 OnTick，不执行任何逻辑。
   }

   // L3: 动态止盈追踪 (在每个 Tick 上运行 - 尚未实现)
   // if (CountOpenTrades(MagicNumber) >= 1)
   // {
   //    ManageOpenTrades(); // (下一步要实现的函数)
   // }

   // --- 1. 新K线检测机制 (New Bar Check) ---
   // 我们只在 K 线收盘时交易，避免在一根 K 线上反复开仓
   if(Time[0] == g_last_bar_time) return; 
   g_last_bar_time = Time[0]; // 更新时间

   // 开始执行订单逻辑  两个价格 当前新k[0] 的开盘价格；上一根K线的 收盘价格 K[1]; 如果发生跳空 两个价格可能会不一样 上一个收盘价格确定斐波那契计算

   // double p1 = Close[1];
   // Print("--->[KTarget_FinderBot.mq4:100]: 上一根K线的 收盘价格: ", p1);

   // double p2 = Open[0];
   // Print("--->[KTarget_FinderBot.mq4:100]: 新一根K线的 开盘价格: ", p2);
   //+------------------------------------------------------------------+

   // --- 2. 🚨 交易管理政策：防止重复开仓 🚨
   // if (CountOpenTrades(MagicNumber) >= 1)
   // {
   //    return;
   // }

   // L3: 每日风控重置 (Placeholder)
   // CheckDailyReset();

   //+------------------------------------------------------------------+
   
   /** 2.0 版本
   // 2.0 使用结构体版本 需要测试 是否能和1.0的版本同样执行下单功能 本质上其实和1.0 一样；1.0的FindStructuralSL
   // 函数 其实循环扫描K线 主要还是为了找到止损点，它和我们信号扫描是不一样的
   
   // --- 3. 批量获取信号数据 (集中 iCustom 调用) ---
   // 🚨 只需要调用一次，获取 shift=1 (已收盘 K 线) 的所有数据 🚨
   KBarSignal last_bar_data = GetIndicatorBarData(1);

   // --- 4. 执行交易逻辑 ---
   // 4.1 处理买入信号 (使用 ReferencePrice 判断信号存在)
   if (last_bar_data.BullishReferencePrice != (double)EMPTY_VALUE && last_bar_data.BullishReferencePrice != 0.0)
   {
      Print(">>> 侦测到看涨信号 @ ", Time[1], "。SL Price: ", last_bar_data.BullishStopLossPrice);

      // A. 止损价直接读取 Buffer 0 (绝对 SL 价)
      double sl_price = last_bar_data.BullishStopLossPrice;

      // B. 入场价：新 K 线的开盘价 (Close[1] == Open[0])
      double entry_price = Open[0];

      // C. 计算止盈
      double risk = entry_price - sl_price;
      double tp_price = entry_price + (risk * RewardRatio);

      // D. 执行开仓
      ExecuteTrade(OP_BUY, FixedLot, sl_price, tp_price, "K-Target Buy");
   }

   // 4.2 处理卖出信号 (使用 ReferencePrice 判断信号存在)
   if (last_bar_data.BearishReferencePrice != (double)EMPTY_VALUE && last_bar_data.BearishReferencePrice != 0.0)
   {
      Print(">>> 侦测到看跌信号 @ ", Time[1], "。SL Price: ", last_bar_data.BearishStopLossPrice);

      // A. 止损价直接读取 Buffer 1 (绝对 SL 价)
      double sl_price = last_bar_data.BearishStopLossPrice;

      // B. 入场价：新 K 线的开盘价 (Close[1] == Open[0])
      double entry_price = Open[0];

      // C. 计算止盈
      double risk = sl_price - entry_price;
      double tp_price = entry_price - (risk * RewardRatio);

      // D. 执行开仓
      ExecuteTrade(OP_SELL, FixedLot, sl_price, tp_price, "K-Target Sell");
   }
   */

   //+------------------------------------------------------------------+
   // 3.0 版本 必须使用扫描逻辑

   // 🚨 关键：在每次 OnTick 开始时，重置新鲜度追踪 🚨
   Found_First_Qualified_Signal = false;

   // 🚨 核心扫描逻辑：寻找最新的有效信号 🚨
   for (int shift = 1; shift <= Indi_LastScan_Range; shift++)
   {
      // 1. 批量读取当前 shift 的数据 (iCustom 循环在此发生)
      KBarSignal data = GetIndicatorBarData(shift);

      // 2. 核心决策：检查信号并执行所有 L2/L3 过滤
      int trade_command = CheckSignalAndFilter(data, shift);

      // Print("---->[KTarget_FinderBot.mq4:223]: shift: ", shift, "---trade_command:", trade_command, "--",
      //       data.BullishStopLossPrice, "--", data.BearishStopLossPrice, "--",
      //       data.BullishReferencePrice, "--", data.BearishReferencePrice);

      if (trade_command != OP_NONE)
      {
         // 3. 找到最新信号，执行交易并退出扫描
         CalculateTradeAndExecute(data, trade_command);
         return; // 找到最新信号，立即停止扫描和决策
      }
   }

   //+------------------------------------------------------------------+

   /** 1.0 版本
   // --- 2. 获取信号 (Communication) ---
   // 读取上根已收盘 K 线 (index 1) 的信号
   double buy_signal  = GetIndicatorSignal(2, 1); // Buffer 2 = Bullish Signal
   Print("--->[KTarget_FinderBot.mq4:110]: buy_signal: ", buy_signal);
   double sell_signal = GetIndicatorSignal(3, 1); // Buffer 3 = Bearish Signal
   Print("--->[KTarget_FinderBot.mq4:112]: sell_signal: ", sell_signal);
   // --- 3. 执行交易逻辑 ---
   
   // 3.1 处理买入信号
   if(buy_signal != (double)EMPTY_VALUE && buy_signal != 0.0)
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
   if(sell_signal != (double)EMPTY_VALUE && sell_signal != 0.0)
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
   */
  //+------------------------------------------------------------------+


}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
  //---
}

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
{
  //---
  double ret = 0.0;
  //---

  //---
  return (ret);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  //---
}
//+------------------------------------------------------------------+

//====================================================================
// 4. 核心辅助函数库 (The Engine Room)
//====================================================================

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
//| 函数: 执行交易 (OrderSend 封装)
//+------------------------------------------------------------------+
void ExecuteTrade_V1(int type, double lots, double sl, double tp, string comment)
{
   // 1. 规范化价格 (防止小数位错误)
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double open_price = (type == OP_BUY) ? Ask : Bid;
   open_price = NormalizeDouble(open_price, _Digits);

   // 2. 发送订单
   int ticket = OrderSend(_Symbol, type, lots, open_price, Slippage, sl, tp, comment, MagicNumber, 0, clrNONE);

   Print("--->[KTarget_FinderBot.mq4:252]: clrNONE: ", clrNONE);
   Print("--->[KTarget_FinderBot.mq4:252]: MagicNumber: ", MagicNumber);
   Print("--->[KTarget_FinderBot.mq4:252]: comment: ", comment);
   Print("--->[KTarget_FinderBot.mq4:252]: tp: ", tp);
   Print("--->[KTarget_FinderBot.mq4:252]: sl: ", sl);
   Print("--->[KTarget_FinderBot.mq4:252]: Slippage: ", Slippage);
   Print("--->[KTarget_FinderBot.mq4:252]: open_price: ", open_price);
   Print("--->[KTarget_FinderBot.mq4:252]: lots: ", lots);
   Print("--->[KTarget_FinderBot.mq4:252]: Symbol: ", _Symbol);
   Print("--->[KTarget_FinderBot.mq4:252]: type: ", type);

   // 3. 结果检查
   if (ticket > 0)
   {
      Print("订单执行成功! Ticket: ", ticket, " 类型: ", (type == OP_BUY ? "BUY" : "SELL"), " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("订单执行失败! 错误代码: ", GetLastError());
   }
}

// 🚨 修正后的函数签名：增加 entry_price 参数 🚨
void ExecuteTrade(int type, double lots, double sl, double tp, double entry_price, string comment)
{
   // Print("DEBUG: Comment长度=", StringLen(comment), ", 内容='", comment, "'");

   // 1. 规范化价格
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   // 2. 确定实际开仓价 (仍然使用市价 Ask/Bid)
   double open_price = (type == OP_BUY) ? Ask : Bid;
   open_price = NormalizeDouble(open_price, _Digits);

   // 🚨 3. 可选：滑点检查 (如果实际开仓价 open_price 偏离预期入场价 entry_price 太远，则拒绝交易)
   /*
   if (MathAbs(open_price - entry_price) > Max_Allowed_Slippage * Point())
   {
       Print("交易被拒绝: 实际开仓价 (", open_price, ") 滑点过大，预期价 (", entry_price, ")");
       return;
   }
   */

   // 4. 发送订单 (使用 Ask/Bid 作为市价单 price)
   int ticket = OrderSend(_Symbol,
                          type,
                          lots,
                          open_price, // 实际开仓价
                          Slippage,   // 使用 input 定义的滑点
                          sl,
                          tp,
                          comment,
                          MagicNumber,
                          0,
                          (type == OP_BUY) ? clrGreen : clrRed);

   // 5. 结果检查 (使用 _Symbol 替代 Symbol()，使用 _Digits 替代 Digits)
   if (ticket > 0)
   {
      Print("订单执行成功! Ticket: ", ticket, " 类型: ", (type == OP_BUY ? "BUY" : "SELL"), " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("订单执行失败! 错误代码: ", GetLastError(), ", 预期入场价: ", entry_price);
   }
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
//| 函数: 统计当前品种和 MagicNumber 下的持仓订单数量
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

//+------------------------------------------------------------------+
//| 函数: 检查信号质量和外部过滤 (L2 核心决策)
//| 职责: 协调所有内部和外部过滤规则
//| 返回: OP_BUY, OP_SELL, 或 0 (OP_NONE)
//+------------------------------------------------------------------+
int CheckSignalAndFilter_V1(const KBarSignal &data, int signal_shift)
{
   return -1;
}

//+------------------------------------------------------------------+
//| 核心决策函数：检查信号有效性并执行防重复过滤                     |
//| 去除了 L3a (新鲜度) 和 L3b (最大风险)，仅保留核心逻辑             |
//+------------------------------------------------------------------+
int CheckSignalAndFilter(const KBarSignal &data, int signal_shift)
{
   int trade_command = OP_NONE; // 初始化为 -1

   // ------------------------------------------------------------------
   // 准备工作：计算当前的均线数值 (基于当前的 signal_shift)
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
   if (data.BullishReferencePrice != (double)EMPTY_VALUE && data.BullishReferencePrice != 0.0)
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
      if (data.BearishReferencePrice != (double)EMPTY_VALUE && data.BearishReferencePrice != 0.0)
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

//+------------------------------------------------------------------+
//| 函数: 计算 SL/TP 并执行交易 (L3)
//| 职责: 最终的计算和 OrderSend 调用
//+------------------------------------------------------------------+
void CalculateTradeAndExecute(const KBarSignal &data, int type)
{
    double sl_price = 0;
    double entry_price = Open[0]; // 始终在新K线开盘时入场
    double tp_price = 0;
    double reference_price = 0; // 斐波那契计算的基准价 (Close[1])
    double risk = 0;
    
    // 1. 获取 SL/Reference Price
    if (type == OP_BUY)
    {
        sl_price = data.BullishStopLossPrice;
        reference_price = data.BullishReferencePrice; // 🚨 注意：现在是质量代码，需要改为获取 Close[1]
    }
    else if (type == OP_SELL)
    {
        sl_price = data.BearishStopLossPrice;
        reference_price = data.BearishReferencePrice;
    }
    
    // 🚨 修正：由于 Buffer 2/3 现在是质量代码，我们不能再用它作为 Reference Price。
    // 我们必须回到之前的方法：直接使用 Close[1] 作为斐波那契的计算基准价。
    // 幸运的是，Reference Price 只是 Close[1]，EA 可以直接获取。
    reference_price = Close[1]; 
    
    // 2. 计算风险
    if (type == OP_BUY)
    {
        risk = entry_price - sl_price;
    }
    else if (type == OP_SELL)
    {
        risk = sl_price - entry_price;
    }
    
    // 3. 计算 TP (固定为 1.618 斐波那契级别)
    // 斐波那契轴线是 SL价格 到 Close[1] 的距离 (即 risk)
    // 假设我们使用 1.618 作为固定止盈位，为实现动态追踪准备。
    double tp_level = 1.618; 
    
    if (type == OP_BUY)
    {
        // TP = 斐波那契基准价 + 距离 * 斐波那契级别
        // 斐波那契基准价通常是 SL 对应的 K 线的 Low/High，但简化为 Entry Price
        tp_price = entry_price + (risk * tp_level); 
    }
    else if (type == OP_SELL)
    {
        tp_price = entry_price - (risk * tp_level);
    }

    // 1. 生成信号 ID (用于防重复和追踪)
    // string signal_id = TimeToString(data.OpenTime, TIME_DATE | TIME_MINUTES);
    string signal_id = GenerateSignalID(data.OpenTime);

    // 2. 订单注释：嵌入 版本标签、信号 ID 和初始追踪状态 (State 0: 刚开仓)
    // string comment = "[" + EA_Version_Tag + "] | ID:" + signal_id + " | State:0 | Risk:" + DoubleToString(Max_Risk_Per_Trade * 100, 2) + "%";
    // string oldcomment = "Q" + IntegerToString((int)data.BullishReferencePrice) + " Trade";
    // string comment = "[" + EA_Version_Tag + "] | ID:" + signal_id + " | State:0 ";

    // 2. 订单注释：嵌入 版本标签、信号 ID 和初始追踪状态
    string comment = EA_Version_Tag + "|" + signal_id;

    // 4. 执行交易 (此处使用固定手数，未来需要加入资金管理)
    ExecuteTrade(type, FixedLot, sl_price, tp_price, entry_price, comment);

    Print("交易执行: ", (type == OP_BUY ? "BUY" : "SELL"),
          " | SL:", DoubleToString(sl_price, _Digits),
          " | TP(1.618):", DoubleToString(tp_price, _Digits),
          " | 质量:", IntegerToString((int)((type == OP_BUY) ? data.BullishReferencePrice : data.BearishReferencePrice)));
}

//+------------------------------------------------------------------+
// 🚨 注意：由于 Buffer 2/3 现在存储了信号质量代码，您必须在 GetIndicatorBarData 中：
// 1. 确保读取出来的 double 值在 CalculateTradeAndExecute 中被正确转换为 int (质量)。
// 2. 斐波那契的 Reference Price 必须改为直接使用 Close[1] 来获取，如 CalculateTradeAndExecute 中所示。
//+------------------------------------------------------------------+

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

//+------------------------------------------------------------------+
//| 函数: 检查信号是否已交易 (核心追踪函数)
//| 职责: 扫描所有持仓和历史订单，防止重复交易。
//+------------------------------------------------------------------+
/*
bool IsSignalAlreadyTraded(string signal_id)
{
    // 遍历所有订单 (持仓和历史订单)
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) || OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderMagicNumber() == MagicNumber)
            {
                // 检查订单注释是否包含信号 ID
                if (StringFind(OrderComment(), signal_id) != -1) 
                {
                    return true; // 找到了，已交易
                }
            }
        }
    }
    return false; // 未找到，可以交易
}
*/

//+------------------------------------------------------------------+
//| L3: 检查信号是否已被交易 (防重复交易过滤器)                      |
//| 必须分两步检查：1. 持仓订单 (MODE_TRADES) 2. 历史订单 (MODE_HISTORY)|
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
//| 辅助函数：生成绝对唯一的信号 ID (品种前缀_月日_时分)             |
//+------------------------------------------------------------------+
string GenerateSignalID_V1(datetime signal_time)
{
   // --- 定义辅助变量 (用于 StringReplace，避免歧义) ---
   // 必须使用连接来确保 MQL4 编译器将其识别为明确的 string
   string find_underscore = "_" + "";
   string find_dot = "." + "";
   string find_colon = ":" + "";
   string replace_empty = "" + "";

   // 1. 获取品种前缀 (例如: BTCUSD -> BTC)
   string symbol_prefix = _Symbol;
   if (StringLen(_Symbol) >= 3)
   {
      symbol_prefix = StringSubstr(_Symbol, 0, 3); // 截取前 3 个字符
   }

   // 2. 清理品种名中的下划线/点
   // 将 symbol_prefix 赋值给一个临时变量，以便 StringReplace 进行修改 (引用传递)
   string temp_symbol = symbol_prefix;

   // 🚨 关键修正：StringReplace 仅作函数调用，不赋值给 string 变量 🚨
   StringReplace(temp_symbol, find_underscore, replace_empty); // 正确用法：修改 temp_symbol
   StringReplace(temp_symbol, find_dot, replace_empty);        // 正确用法：修改 temp_symbol

   // ----------------------------------------------------
   // 3. 修正日期/时间获取逻辑
   // ----------------------------------------------------

   // 3.1 获取完整日期: "yyyy.mm.dd" (使用 TIME_DATE 确保格式标准)
   string full_date = TimeToString(signal_time, TIME_DATE);

   // 3.2 截取月日部分: 从第 5 位开始，长度为 5 ("mm.dd")
   // 格式： yyyy.mm.dd
   // 索引： 0123456789
   string month_day = StringSubstr(full_date, 5, 5);

   // 3.3 获取时间: "hh:mi"
   string hour_minute = TimeToString(signal_time, TIME_MINUTES);

   // 4. 清理日期时间分隔符 (使用临时变量来处理 TimeToString 的结果)
   string temp_month_day = month_day;
   string temp_hour_minute = hour_minute;

   // 🚨 关键修正：StringReplace 仅作函数调用 🚨
   StringReplace(temp_month_day, find_dot, replace_empty);
   StringReplace(temp_hour_minute, find_colon, replace_empty);

   // 5. 最终 ID 拼接
   // 格式: 品种前缀_月日_时分 (例如：XAU_1201_1517)
   return temp_symbol + "_" + temp_month_day + "_" + temp_hour_minute;
}

//+------------------------------------------------------------------+
//| 辅助函数：生成绝对唯一的信号 ID (品种前缀_周期_日时分)         |
//| 新格式: BTC_M1021806                                             |
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
//| L3a: 信号新鲜度过滤器 (只允许扫描到的第一个合格信号通过)         |
//| 必须在外层 for 循环开始前重置 Found_First_Qualified_Signal 为 false |
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
//| L3c: 信号时效性过滤器 (只允许 shift=1 的信号通过)               |
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