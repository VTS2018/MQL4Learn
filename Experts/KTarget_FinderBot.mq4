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

input int    Indi_LastScan_Range      = 100;      // 扫描最近多少根 K 线 (Bot 1.0 逻辑)

KBarSignal GetIndicatorBarData(int shift);
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
   // --- 1. 新K线检测机制 (New Bar Check) ---
   // 我们只在 K 线收盘时交易，避免在一根 K 线上反复开仓
   if(Time[0] == g_last_bar_time) return; 
   g_last_bar_time = Time[0]; // 更新时间

   // 开始执行订单逻辑  两个价格 当前新k[0] 的开盘价格；上一根K线的 收盘价格 K[1]; 如果发生跳空 两个价格可能会不一样

   double p1 = Close[1];
   Print("--->[KTarget_FinderBot.mq4:97]: 上一根K线的 收盘价格: ", p1);

   double p2 = Open[0];
   Print("--->[KTarget_FinderBot.mq4:100]: 新一根K线的 开盘价格: ", p2);

   // -----------------------------------------------------------------------

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

   // 3.0 版本 必须使用扫描逻辑

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

// -------------------------------------------------------
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

