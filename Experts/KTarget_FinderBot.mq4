//+------------------------------------------------------------------+
//|                                            KTarget_FinderBot.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
#include <K_Data.mqh>
#include <KBot_Logic.mqh>

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
input bool     Indi_Smart_Tuning      = true; // Smart_Tuning_Enabled
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

input int Indi_LastScan_Range = 100; // 扫描最近多少根 K 线 (Bot 1.0 逻辑)

input int Trade_Start_Hour = 8; // 开始交易小时 (例如 8)
input int Trade_End_Hour = 20;  // 结束交易小时 (例如 20)

input double Daily_Max_Loss_Pips = 100.0;      // 日最大亏损 (点数)
input double Daily_Target_Profit_Pips = 200.0; // 日盈利目标 (点数)
input int Daily_Max_Trades = 5;                // 日最大交易次数

input int Min_Signal_Quality = 2; // 最低信号质量要求: 1=IB, 2=P1-DB, 3=P2

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
   // L3: 动态止盈追踪 (在每个 Tick 上运行 - 尚未实现)
   if (CountOpenTrades(MagicNumber) >= 1)
   {
      ManageOpenTrades(); // (下一步要实现的函数)
   }

   // --- 1. 新K线检测机制 (New Bar Check) ---
   // 我们只在 K 线收盘时交易，避免在一根 K 线上反复开仓
   if(Time[0] == g_last_bar_time) return; 
   g_last_bar_time = Time[0]; // 更新时间

   // 开始执行订单逻辑  两个价格 当前新k[0] 的开盘价格；上一根K线的 收盘价格 K[1]; 如果发生跳空 两个价格可能会不一样

   double p1 = Close[1];
   Print("--->[KTarget_FinderBot.mq4:97]: 上一根K线的 收盘价格: ", p1);

   double p2 = Open[0];
   Print("--->[KTarget_FinderBot.mq4:100]: 新一根K线的 开盘价格: ", p2);

   // --- 2. 🚨 交易管理政策：防止重复开仓 🚨
   // if (CountOpenTrades(MagicNumber) >= 1)
   // {
   //    return;
   // }

   // L3: 每日风控重置 (Placeholder)
   // CheckDailyReset();

   // -----------------------------------------------------------------------
   
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

   // 3.0 版本 必须使用扫描逻辑

   // 🚨 核心扫描逻辑：寻找最新的有效信号 🚨
   for (int shift = 1; shift <= Indi_Scan_Range; shift++)
   {
      // 1. 批量读取当前 shift 的数据 (iCustom 循环在此发生)
      KBarSignal data = GetIndicatorBarData(shift);

      // 2. 核心决策：检查信号并执行所有 L2/L3 过滤
      int trade_command = CheckSignalAndFilter(data, shift);

      if (trade_command != OP_NONE)
      {
         // 3. 找到最新信号，执行交易并退出扫描
         CalculateTradeAndExecute(data, trade_command);
         return; // 找到最新信号，立即停止扫描和决策
      }
   }

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
//| 函数: 寻找最近的结构性止损 (锚点价格)
//| buffer_index: 0=看涨锚点, 1=看跌锚点
//+------------------------------------------------------------------+
double FindStructuralSL_v1(int buffer_index, int start_shift)
{
   // 向左回溯查找最近的一个锚点
   // 限制回溯 Scan_Range 根，避免死循环
   for(int i = start_shift; i < start_shift + Indi_Scan_Range; i++)
   {
      double val = GetIndicatorSignal(buffer_index, i);
      
      if(val != (double)EMPTY_VALUE && val != 0)
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

// KTarget_FinderBot.mq4 (兼容 Bot 1.0 架构的修正)

double FindStructuralSL(int buffer_index, int start_shift)
{
    // 确定要读取的 SL 价格缓冲区和信号质量缓冲区
    int sl_price_buffer = buffer_index;      // 0 或 1
    int quality_buffer = buffer_index + 2;   // 2 或 3

    // 限制回溯 Scan_Range 根
    for(int i = start_shift; i < start_shift + Indi_Scan_Range; i++)
    {
        // 1. 读取信号质量 (Buffer 2 或 Buffer 3)
        // val 现在代表信号质量代码 (3.0, 2.0, 或 EMPTY_VALUE)
        double signal_quality = GetIndicatorSignal(quality_buffer, i); 
        
        // 2. 检查信号是否存在 (即质量代码已写入)
        if (signal_quality != (double)EMPTY_VALUE && signal_quality >= 2.0) // 假设我们只关心 P2 和 P1-DB 信号 (2.0/3.0)
        {
            // 3. 信号存在！现在读取已计算好的 SL 绝对价格 (Buffer 0 或 Buffer 1)
            double sl_price = GetIndicatorSignal(sl_price_buffer, i);
            
            // 4. 检查 SL 价格是否有效 (必须大于 0.0)
            if (sl_price != (double)EMPTY_VALUE && sl_price != 0.0)
            {
                // 找到了！返回绝对 SL 价格
                return sl_price; 
            }
        }
    }
    
    return 0.0; // 未找到有效的 SL 价格
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
   Print("--->[KTarget_FinderBot.mq4:252]: clrNONE: ", clrNONE);
   Print("--->[KTarget_FinderBot.mq4:252]: MagicNumber: ", MagicNumber);
   Print("--->[KTarget_FinderBot.mq4:252]: comment: ", comment);
   Print("--->[KTarget_FinderBot.mq4:252]: tp: ", tp);
   Print("--->[KTarget_FinderBot.mq4:252]: sl: ", sl);
   Print("--->[KTarget_FinderBot.mq4:252]: Slippage: ", Slippage);
   Print("--->[KTarget_FinderBot.mq4:252]: open_price: ", open_price);
   Print("--->[KTarget_FinderBot.mq4:252]: lots: ", lots);
   Print("--->[KTarget_FinderBot.mq4:252]: Symbol: ", Symbol());
   Print("--->[KTarget_FinderBot.mq4:252]: type: ", type);
   
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
             OrderSymbol() == Symbol() &&
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
int CheckSignalAndFilter(KBarSignal data)
{
    int trade_command = OP_NONE;

    // --- 1. 检查看涨信号 ---
    // 使用 ReferencePrice (现在是质量代码) 进行判断
    if (data.BullishReferencePrice != (double)EMPTY_VALUE && data.BullishReferencePrice != 0.0)
    {
        // A. 内部过滤：检查信号质量是否满足最低要求
        if ((int)data.BullishReferencePrice >= Min_Signal_Quality)
        {
            // B. 外部过滤：检查矩形区域、MA等外部条件 (暂未实现，默认通过)
            // if (IsExternalConditionMet(OP_BUY)) 
            // {
                trade_command = OP_BUY;
            // }
        }
    }

    // --- 2. 检查看跌信号 ---
    if (data.BearishReferencePrice != (double)EMPTY_VALUE && data.BearishReferencePrice != 0.0)
    {
        // A. 内部过滤：检查信号质量是否满足最低要求
        if ((int)data.BearishReferencePrice >= Min_Signal_Quality)
        {
            // B. 外部过滤：检查矩形区域、MA等外部条件 (暂未实现，默认通过)
            // if (IsExternalConditionMet(OP_SELL)) 
            // {
                trade_command = OP_SELL;
            // }
        }
    }
    
    return trade_command;
}

//+------------------------------------------------------------------+
//| 函数: 计算 SL/TP 并执行交易 (L3)
//| 职责: 最终的计算和 OrderSend 调用
//+------------------------------------------------------------------+
void CalculateTradeAndExecute(KBarSignal data, int type)
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

    // 4. 执行交易 (此处使用固定手数，未来需要加入资金管理)
    ExecuteTrade(type, FixedLot, sl_price, tp_price, entry_price, "Q" + IntegerToString((int)data.BullishReferencePrice) + " Trade"); 
    
    Print("交易执行: ", (type == OP_BUY ? "BUY" : "SELL"), 
          " | SL:", DoubleToString(sl_price, Digits), 
          " | TP(1.618):", DoubleToString(tp_price, Digits),
          " | 质量:", IntegerToString((int)data.BullishReferencePrice));
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
   int current_hour = Hour();

   // 检查是否在允许的时间窗口内
   if (current_hour >= Trade_Start_Hour && current_hour < Trade_End_Hour)
   {
      return true;
   }

   // 如果不在允许时间内，打印日志并禁止交易
   Print("风控过滤: 当前时间 ", current_hour, " 不在交易时间窗口 (", Trade_Start_Hour, "-", Trade_End_Hour, ")。");
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
    datetime current_date = iTime(NULL, PERIOD_D1, 0); // 获取当前交易日
    
    if (current_date != g_last_date)
    {
        // 跨日，执行重置
        g_today_profit_pips = 0;
        g_today_trades = 0;
        g_last_date = current_date;
        Print("--- 每日统计已重置 ---");
    }
}

//+------------------------------------------------------------------+
//| 函数: 日内整体风控过滤 (包括亏损/盈利/次数限制)                 |
//+------------------------------------------------------------------+
bool IsDailyRiskAllowed()
{
   // 1. 达到日盈利目标
   if (g_today_profit_pips >= Daily_Target_Profit_Pips)
   {
      Comment("日盈利目标达成，暂停交易。");
      return false;
   }

   // 2. 达到日最大亏损
   if (g_today_profit_pips <= -Daily_Max_Loss_Pips)
   {
      Comment("日最大亏损触发，暂停交易。");
      return false;
   }

   // 3. 达到日最大交易次数
   if (g_today_trades >= Daily_Max_Trades)
   {
      Comment("日交易次数已满，暂停交易。");
      return false;
   }

   return true;
}