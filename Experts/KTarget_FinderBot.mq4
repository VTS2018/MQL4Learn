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

//====================================================================
// --- 严格过滤版本 只有紧跟信号成立后的 第一根K线 才允许交易
extern bool Found_First_Qualified_Signal = false; // 追踪是否已找到第一个合格的信号
//====================================================================
input string   __Separator_9__ = "--- Separator  9 ---";
// --- L2: 趋势过滤器参数 ---
input bool   Use_Trend_Filter    = false;   // 是否开启均线大趋势过滤
input int    Trend_MA_Period     = 200;    // 均线周期 (默认200，牛熊分界线)
input int    Trend_MA_Method     = MODE_EMA; // 均线类型: 0=SMA, 1=EMA, 2=SMMA, 3=LWMA
//====================================================================
// 函数声明
//====================================================================
KBarSignal GetIndicatorBarData(int shift);
double GetIndicatorSignal(int buffer_index, int shift);
string GenerateSignalID(datetime signal_time);
void CollectAllSignals(FilteredSignal &bullish_list[], FilteredSignal &bearish_list[]);
int FilterWeakBullishSignals(FilteredSignal &source_signals[], FilteredSignal &filtered_list[]);
void Test_FilterWeakBullish_And_BearishSignals(FilteredSignal &raw_bullish_list[], FilteredSignal &raw_bearish_list[], FilteredSignal &clean_bullish_list[], FilteredSignal &clean_bearish_list[]);
void MergeAndSortSignals(FilteredSignal &bulls[], FilteredSignal &bears[], FilteredSignal &result_list[]);
void Test_MergeAndSortSignals(FilteredSignal &merge_list[]);
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

   /*
   // 🚨 核心扫描逻辑：寻找最新的有效信号 🚨
   for (int shift = 1; shift <= Indi_LastScan_Range; shift++)
   {
      // 1. 批量读取当前 shift 的数据 (iCustom 循环在此发生)
      KBarSignal data = GetIndicatorBarData(shift);

      // 2. 核心决策：检查信号并执行所有 L2/L3 过滤
      int trade_command = CheckSignalAndFilter(data, shift);
      // Print("----> shift: ", shift, "---trade_command:", trade_command, "--", data.BullishStopLossPrice, "--", data.BearishStopLossPrice, "--", data.BullishReferencePrice, "--", data.BearishReferencePrice);

      if (trade_command != OP_NONE)
      {
         // 3. 找到最新信号，执行交易并退出扫描
         CalculateTradeAndExecute(data, trade_command);
         return; // 找到最新信号，立即停止扫描和决策
      }
   }
   */

   //+------------------------------------------------------------------+

   //+------------------------------------------------------------------+
   // 4.0
   // ==========================================================================
   // 第一阶段：数据准备 (收集 -> 清洗 -> 合并)
   // ==========================================================================
   // 1. 定义数组
   FilteredSignal raw_bulls[], raw_bears[];     // 原始信号
   FilteredSignal clean_bulls[], clean_bears[]; // 清洗后的信号
   FilteredSignal sorted_valid_signals[];       // 最终合并排序的列表 (X)

   // 2. 收集原始信号 (扫描 1 到 Indi_LastScan_Range)
   CollectAllSignals(raw_bulls, raw_bears);

   // 3. 执行“优胜劣汰”弱势过滤
   FilterWeakBullishSignals(raw_bulls, clean_bulls); // 看涨：新低优胜
   FilterWeakBearishSignals(raw_bears, clean_bears); // 看跌：新高优胜

   // 运行测试 查看结果
   Test_FilterWeakBullish_And_BearishSignals(raw_bulls,raw_bears,clean_bulls,clean_bears);

   
   // 4. 合并并排序 (生成列表 X)
   // 此时 sorted_valid_signals[0] 就是距离现价最近的那个有效结构信号
   MergeAndSortSignals(clean_bulls, clean_bears, sorted_valid_signals);

   int total_valid_signals = ArraySize(sorted_valid_signals);
   Test_MergeAndSortSignals(sorted_valid_signals);
   if (total_valid_signals <= 0)
   {
      // 没有找到历史信号数据 不交易
      Print("--- 没有找到历史信号数据 不交易!!! ---");
      return;
   }

   /*
   // ==========================================================================
   // 第二阶段：核心执行循环 (只针对精英信号进行决策)
   // ==========================================================================

   // 🚨 新版核心扫描逻辑：循环“有效信号列表 X” 🚨
   for (int i = 0; i < total_valid_signals; i++)
   {
      // A. 从列表中提取关键信息
      FilteredSignal signal_item = sorted_valid_signals[i];
      int current_shift = signal_item.shift;

      // B. 重新获取完整的指标数据 (为了兼容 CheckSignalAndFilter)
      // 虽然 FilteredSignal 有部分数据，但 CheckSignalAndFilter 可能需要完整的 KBarSignal 结构
      KBarSignal full_data = GetIndicatorBarData(current_shift);

      // C. 核心决策：执行 L2 (趋势/斐波) 和 L3 (风险/新鲜度) 过滤
      // 注意：这里的 CheckSignalAndFilter 可能会再次检查 L2c (CheckSignalContext)
      // 此时它会基于这个 shift 进行上下文判断
      int trade_command = CheckSignalAndFilter(full_data, current_shift);

      // 调试打印 (可选)
      // Print("检查有效信号 #", i, " (Shift ", current_shift, ") -> 结果: ", trade_command);

      if (trade_command != OP_NONE)
      {
         // D. 找到最新且通过所有检查的信号，执行交易
         CalculateTradeAndExecute(full_data, trade_command);

         // E. 立即退出！
         // 因为 sorted_valid_signals 是按时间排序的，第一个通过检查的肯定是最新的合规信号。
         return;
      }
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

//+------------------------------------------------------------------+
//| 核心决策函数：检查信号有效性并执行防重复过滤                     |
//| 去除了 L3a (新鲜度) 和 L3b (最大风险)，仅保留核心逻辑             |
//+------------------------------------------------------------------+
int CheckSignalAndFilter(const KBarSignal &data, int signal_shift)
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
             // trade_command = OP_BUY; // 顺势，通过！
             // ... (原来的日志打印代码)

             // 🚨 C. L2c: 斐波那契反转区域过滤 (新增调用位置) 🚨
             if (IsReversalInFibZone(signal_shift, OP_BUY))
             {
               trade_command = OP_BUY; // 顺势且在斐波区域内，通过！
               // ... (打印日志) ...
             }
             else
             {
                Print("L2c 过滤：看涨信号不在理想的斐波反转区域。当前:shift=", signal_shift);
             }
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
               // trade_command = OP_SELL; // 顺势，通过！
               // ... (原来的日志打印代码)

               // 🚨 C. L2c: 斐波那契反转区域过滤 (新增调用位置) 🚨
               if (IsReversalInFibZone(signal_shift, OP_SELL))
               {
                  trade_command = OP_SELL; // 顺势且在斐波区域内，通过！
               }
               else
               {
                  Print("L2c 过滤：看跌信号不在理想的斐波反转区域。当前:shift=", signal_shift);
               }
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

//+------------------------------------------------------------------+
//| L2c: 斐波那契反转区域过滤 (Context Filter)                       |
//| 检查当前反转信号是否位于前一个趋势的 2.618-3.0 衰竭区             |
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

// 修改成区域触碰 降低严格程度
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
//| L2c: 斐波那契反转区域过滤 (Context Filter)                       |
//| 修正：检查多个自定义斐波那契区域是否被触碰 (High/Low)            |
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
//| 收集所有合格信号：扫描历史K线并分离看涨和看跌信号                |
//| @param bullish_list: 引用 - 存储看涨信号列表                    |
//| @param bearish_list: 引用 - 存储看跌信号列表                    |
//+------------------------------------------------------------------+
void CollectAllSignals(FilteredSignal &bullish_list[], FilteredSignal &bearish_list[])
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
//| 信号弱势过滤 (看涨 - 新低优胜逻辑)                              |
//| 逻辑：从最新信号开始往历史回溯。                                 |
//|      如果 Newer.Close < Older.SL，则 Older 无效 (被击穿)。       |
//|      如果 Newer.Close >= Older.SL，则 Older 有效 (支撑有效)。    |
//+------------------------------------------------------------------+
int FilterWeakBullishSignals(FilteredSignal &source_signals[], FilteredSignal &filtered_list[])
{
    // 1. 初始化
    ArrayResize(filtered_list, 0);
    int total = ArraySize(source_signals);
    
    if (total == 0) return 0;

    // 2. 总是保留最新的信号 (索引 0，即 shift 最小的信号)
    // 因为它是离现价最近的市场事实，无论它长什么样，它都是最新的参考点
    ArrayResize(filtered_list, 1);
    filtered_list[0] = source_signals[0];

    // 3. 设定初始比较基准：使用最新信号的【收盘价】
    double threshold_close = source_signals[0].stop_loss;

    // 4. 向历史方向遍历 (从索引 1 开始，即次新的信号)
    for (int i = 1; i < total; i++)
    {
        FilteredSignal older_signal = source_signals[i];
        
        // -------------------------------------------------------------
        // 🚨 核心逻辑：新低优胜 🚨
        // 比较：最新有效信号的 Close vs 历史信号的 SL
        // -------------------------------------------------------------
        
        // 情况 A: 击穿 (Invalidation)
        // 如果较新的 Close 价格 低于 历史信号的 SL (最低价)
        // 说明最新的价格已经打破了该历史信号的结构，该历史信号失效。
        if (threshold_close < older_signal.stop_loss)
        {
            // Print("❌ 过滤 (看涨): 历史信号 K[", older_signal.shift, "] SL:", older_signal.stop_loss, 
            //       " 被较新信号 Close:", threshold_close, " 击穿。排除。");
            
            // 排除该信号，继续循环。
            // 阈值 threshold_close 保持不变 (继续用较新的这个低价去检验更老的信号)
            continue;
        }

        // 情况 B: 支撑有效 (Validation)
        // 如果较新的 Close 价格 高于或等于 历史信号的 SL
        // 说明虽然可能有回调，但没有打穿该历史信号的底，该历史信号依然作为阶梯存在。
        
        // 加入有效列表
        int new_index = ArraySize(filtered_list);
        ArrayResize(filtered_list, new_index + 1);
        filtered_list[new_index] = older_signal;

        // 🚨 关键更新：既然这个历史信号有效，它就成为更早信号的验证者 🚨
        // 我们更新阈值为这个历史信号的 Close
        threshold_close = older_signal.stop_loss;
    }

    // 这里的 filtered_list 顺序已经是：最新 -> 较新 -> 老 -> 最老
    // 符合您 K[1] 往左寻找的直觉，不需要 ArrayReverse。
    
    return ArraySize(filtered_list);
}
//+------------------------------------------------------------------+
//| 信号弱势过滤 (看跌 - 新高优胜逻辑)                              |
//| 逻辑：Newer.Close > Older.SL，则 Older 无效 (被涨破)。           |
//+------------------------------------------------------------------+
int FilterWeakBearishSignals(FilteredSignal &source_signals[], FilteredSignal &filtered_list[])
{
    ArrayResize(filtered_list, 0);
    int total = ArraySize(source_signals);
    
    if (total == 0) return 0;

    // 1. 保留最新信号
    ArrayResize(filtered_list, 1);
    filtered_list[0] = source_signals[0];

    // 2. 设定初始比较基准：使用最新信号的【收盘价】
    double threshold_close = source_signals[0].stop_loss;

    // 3. 向历史方向遍历
    for (int i = 1; i < total; i++)
    {
        FilteredSignal older_signal = source_signals[i];
        
        // -------------------------------------------------------------
        // 🚨 核心逻辑：新高优胜 🚨
        // 看跌信号的 SL 是最高价 (压力位)
        // -------------------------------------------------------------
        
        // 情况 A: 涨破 (Invalidation)
        // 如果较新的 Close 价格 高于 历史信号的 SL (最高价)
        // 说明最新的价格已经反向突破了该历史信号的压力位，该历史信号失效。
        if (threshold_close > older_signal.stop_loss)
        {
            // Print("❌ 过滤 (看跌): 历史信号 K[", older_signal.shift, "] SL:", older_signal.stop_loss, 
            //       " 被较新信号 Close:", threshold_close, " 涨破。排除。");
            continue;
        }

        // 情况 B: 压力有效 (Validation)
        // 较新的 Close 依然在 历史信号 SL 之下
        int new_index = ArraySize(filtered_list);
        ArrayResize(filtered_list, new_index + 1);
        filtered_list[new_index] = older_signal;

        // 更新阈值
        threshold_close = older_signal.stop_loss;
    }

    return ArraySize(filtered_list);
}
//+------------------------------------------------------------------+
//| 测试 FilterWeakBullishSignals 函数的主入口点                     |
//+------------------------------------------------------------------+
void Test_FilterWeakBullish_And_BearishSignals(FilteredSignal &raw_bullish_list[], FilteredSignal &raw_bearish_list[], FilteredSignal &clean_bullish_list[], FilteredSignal &clean_bearish_list[])
{
   Print("=================================================");
   Print(">>> 单元测试：FilterWeakBullishSignals 开始 <<<");

   // 1. 构造模拟数据
   int original_size = ArraySize(raw_bullish_list);

   // 打印输入数据
   Print("\n--- 输入信号列表 (从 K[1] 往历史排序) ---");
   Print("原始【看涨】信号数量: ", original_size);
   for (int i = 0; i < original_size; i++)
   {
      Print("输入 #", i + 1, " | K[", raw_bullish_list[i].shift, "] | SL: ", DoubleToString(raw_bullish_list[i].stop_loss, _Digits));
   }

   // 2. 执行过滤函数
   int final_count = ArraySize(clean_bullish_list);

   // 3. 打印输出结果
   Print("\n--- 输出信号列表 (过滤后) ---");
   Print("最终【看涨】有效信号数量: ", final_count);

   for (int i = 0; i < final_count; i++)
   {
      Print("输出 #", i + 1, " | K[", clean_bullish_list[i].shift, "] | SL: ", DoubleToString(clean_bullish_list[i].stop_loss, _Digits));
   }

   Print(">>> 单元测试：FilterWeakBullishSignals 结束 <<<");
   Print("=================================================");

   Print("==================================================================================================");
   
   Print("=================================================");
   Print(">>> 单元测试：FilterWeakBearishSignals 开始 <<<");

   // 1. 构造模拟数据
   int original_size_1 = ArraySize(raw_bearish_list);

   // 打印输入数据
   Print("\n--- 输入信号列表 (从 K[1] 往历史排序) ---");
   Print("原始【看跌】信号数量: ", original_size_1);
   for (int i = 0; i < original_size_1; i++)
   {
      Print("输入 #", i + 1, " | K[", raw_bearish_list[i].shift, "] | SL: ", DoubleToString(raw_bearish_list[i].stop_loss, _Digits));
   }

   // 2. 执行过滤函数
   int final_count_1 = ArraySize(clean_bearish_list);

   // 3. 打印输出结果
   Print("\n--- 输出信号列表 (过滤后) ---");
   Print("最终【看跌】有效信号数量: ", final_count_1);

   for (int i = 0; i < final_count_1; i++)
   {
      Print("输出 #", i + 1, " | K[", clean_bearish_list[i].shift, "] | SL: ", DoubleToString(clean_bearish_list[i].stop_loss, _Digits));
   }

   Print(">>> 单元测试：FilterWeakBearishSignals 结束 <<<");
   Print("=================================================");

}
//+------------------------------------------------------------------+
//| 辅助函数：合并看涨和看跌列表，并按 shift 从小到大 (由新到旧) 排序  |
//+------------------------------------------------------------------+
void MergeAndSortSignals(FilteredSignal &bulls[], FilteredSignal &bears[], FilteredSignal &result_list[])
{
   int size_bull = ArraySize(bulls);
   int size_bear = ArraySize(bears);
   int total_size = size_bull + size_bear;

   // 1. 重置结果数组大小
   ArrayResize(result_list, total_size);

   // 2. 合并数据
   int index = 0;
   // 先放入看涨信号
   for (int i = 0; i < size_bull; i++)
   {
      result_list[index] = bulls[i];
      index++;
   }
   // 再放入看跌信号
   for (int i = 0; i < size_bear; i++)
   {
      result_list[index] = bears[i];
      index++;
   }

   // 3. 排序 (冒泡排序 Bubble Sort)
   // 目标：按 shift 值从小到大排序 (shift 1 是最新，shift 100 是较旧)
   // 这样循环时，我们总是先处理离现价最近的有效信号
   if (total_size > 1)
   {
      for (int i = 0; i < total_size - 1; i++)
      {
         for (int j = 0; j < total_size - i - 1; j++)
         {
            // 如果前一个信号的 shift 比后一个大 (说明前一个更旧)，则交换
            if (result_list[j].shift > result_list[j + 1].shift)
            {
               FilteredSignal temp = result_list[j];
               result_list[j] = result_list[j + 1];
               result_list[j + 1] = temp;
            }
         }
      }
   }
}

void Test_MergeAndSortSignals(FilteredSignal &merge_list[])
{
   Print("=================================================");
   Print(">>> 单元测试：合并以后的看涨和看跌信号列表 开始 <<<");

   // 1. 构造模拟数据
   int original_size = ArraySize(merge_list);

   // 打印输入数据
   Print("\n--- 输入信号列表 (从 K[1] 往历史排序) ---");
   Print("【合并以后】信号数量: ", original_size);
   for (int i = 0; i < original_size; i++)
   {
      Print("输入 #", i + 1, " | K[", merge_list[i].shift, "] | SL: ", DoubleToString(merge_list[i].stop_loss, _Digits));
   }

   Print(">>> 单元测试：合并以后的看涨和看跌信号列表 结束 <<<");
   Print("=================================================");
}

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
   // 逻辑 A: 斐波那契反转检查 (Fibonacci Reversal)
   // 场景：当前是看跌 -> 检查是否触碰了历史【看涨】信号的延伸阻力区
   //       当前是看涨 -> 检查是否触碰了历史【看跌】信号的延伸支撑区
   // =================================================================

   if (current_type == OP_SELL)
   {
      // 我想实现 在循环中 连续查找三次 左右，如果这个有效列表有超过三个以上 就找最大的 那个 更旧的信号
   }
   else if (current_type == OP_BUY)
   {

   }
   

   // =================================================================
   // 逻辑 B: 同向区间回踩检查 (Zone Retest)
   // 场景：当前是看跌 -> 检查是否回踩了最近一个历史【看跌】信号的内部风险区
   //       当前是看涨 -> 检查是否回踩了最近一个历史【看涨】信号的内部风险区
   // =================================================================
   if (current_type == OP_SELL)
   {

   }
   else if (current_type == OP_BUY)
   {

   }

   // 如果都不满足
   return 0;
}