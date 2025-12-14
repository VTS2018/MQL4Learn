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
#include <KBot_Utils6.mqh>
#include <KBot_Logic6.mqh>
#include <KBot_Test.mqh>
#include <KBot_Draw.mqh>

//+------------------------------------------------------------------+
//| ✅ --- Bot Core Settings ---
//+------------------------------------------------------------------+
input string EA_Version_Tag = "V5";     // 版本信息标签，用于订单注释追踪
input bool   EA_Master_Switch       = true;     // 核心总开关：设置为 false 时，EA 不执行任何操作
input bool   EA_Trading_Enabled     = true;    // 设置为 true 时，EA 才执行开仓和平仓操作
//+------------------------------------------------------------------+

//====================================================================
//| ✅ 策略参数设置 (Strategy Inputs)
//====================================================================
input string   __STRATEGY_SETTINGS__ = "--- Strategy Settings ---";
input int      MagicNumber    = 88888;       // 魔术数字 (EA的身份证)

#include <Config_CalcPosition.mqh>

#include <Config_Indicator.mqh>

//====================================================================
//| ✅ 全局变量
//====================================================================
datetime g_last_bar_time = 0; // 用于新K线检测

input int Indi_LastScan_Range = 300; // 扫描最近多少根 K 线 (Bot 1.0 逻辑)
input int Min_Signal_Quality = 2; // 最低信号质量要求: 1=IB, 2=P1-DB, 3=P2

// 下面这些还没有实现
// input int Trade_Start_Hour = 8; // 开始交易小时 (例如 8)
// input int Trade_End_Hour = 20;  // 结束交易小时 (例如 20)

// input double Daily_Max_Loss_Pips = 100.0;      // 日最大亏损 (点数)
// input double Daily_Target_Profit_Pips = 200.0; // 日盈利目标 (点数)
// input int Daily_Max_Trades = 5;                // 日最大交易次数

//+------------------------------------------------------------------+
//| ✅ 严格过滤版本 只有紧跟信号成立后的 第一根K线 才允许交易
//+------------------------------------------------------------------+
extern bool Found_First_Qualified_Signal = false; // 追踪是否已找到第一个合格的信号

#include <Config_Fibo.mqh>

//+------------------------------------------------------------------+
//| ✅ 调试/日志输出设置 (Debug/Logging)
//+------------------------------------------------------------------+
input string   __DEBUG_LOGGING__    = "--- Debug/Logging ---";
input bool     Debug_Print_Valid_List = false; // 是否在日志中打印清洗合并后的有效信号列表 (sorted_valid_signals)
// input int      Log_Level            = 1;      // 日志级别 (例如 0=关, 1=关键信息, 2=详细)

#include <Config_Risk.mqh>

//+------------------------------------------------------------------+
//| ✅ 唯一对象名前缀
//+------------------------------------------------------------------+
string g_object_prefix = "";

//+------------------------------------------------------------------+
//| ✅ 输入参数: 空间检查模块需要的 最小盈亏比阈值 (建议 1.0 到 1.5)
//+------------------------------------------------------------------+
input double Min_Reward_Risk_Ratio = 1.0; // 空间检查模块需要的 最小盈亏比阈值 (建议 1.0 到 1.5) 

//+------------------------------------------------------------------+
//| ✅ 输入参数建议
//| 在图表上实时显示当前周期下 品种的ATR数据
//+------------------------------------------------------------------+
input bool   Use_Hedge_Filter       = true;  // 开关：是否启用反向距离过滤
input int    Hedge_ATR_Period       = 14;    // ATR 计算周期
input double Min_Hedge_Dist_ATR     = 0.5;   // 最小距离系数 (建议 0.5 到 1.0)

//+------------------------------------------------------------------+
//| ✅ 全局常量与变量
//+------------------------------------------------------------------+
#define BTN_CLEANUP_NAME "Btn_CleanShadowData" // 按钮的对象名称

//====================================================================
// 函数声明
//====================================================================
// KBarSignal GetIndicatorBarData(int shift);

//====================================================================
// 函数引入
//====================================================================
#include <Lib_RiskControl.mqh>
#include <Lib_OrderTrack.mqh>
#include <KBot_Logic_Start.mqh>
#include <KBot_Logic_Second.mqh>
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 🚨 开启图表事件监听 (为了捕获按钮点击) 🚨
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true); // 可选

   // 🚨 检查能否找到指标文件 🚨
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

   // 🚨 g_object_prefix 🚨
   long full_chart_id = MathAbs(ChartID());
   // int short_chart_id = (int)full_chart_id;
   int short_chart_id = (int)(full_chart_id % 1000000);
   g_object_prefix = ShortenObjectNameBot(WindowExpertName()) + StringFormat("_%d_", MathAbs(short_chart_id));
   Print("--->[196]: g_object_prefix: ", g_object_prefix);

   // 🚨 斐波那契参数初始化 🚨
   InitializeFiboLevels(Fibo_Zone_1, Fibo_Zone_2, Fibo_Zone_3, Fibo_Zone_4);

   // 🚨 计算本机与服务器时间差值 🚨
   CalculateAndPrintTimeOffset();

   // 🚨 查看当前品种的一些基础信息 🚨
   Print("当前品种：Digits() ", Digits());
   Print("当前品种：Point() ", Point());
   Print("当前品种：Period() ", Period());
   Print("当前品种：Symbol() ", Symbol());

   Print("当前品种：GetContractSize() ", DoubleToString(GetContractSize(), _Digits));

   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);

   Print("当前品种：Symbol() ", DoubleToString(tick_value, _Digits));
   Print("当前品种：Symbol() ", DoubleToString(tick_size, _Digits));

   // 🚨 验证仓位计算的准确性 🚨
   Test_PositionSize_Logic();

   // 🚨 创建右下角的清理按钮 🚨
   CreateCleanupButton(BTN_CLEANUP_NAME);

   // 🚨 2. 启动长周期定时器：每 3 天触发一次 🚨
   // 3天 * 24小时 * 60分 * 60秒 = 259200 秒
   EventSetTimer(259200);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 1. 销毁定时器
   EventKillTimer();

   // 2. 删除按钮对象
   ObjectDelete(0, BTN_CLEANUP_NAME);
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

   // A. 🚨 CSL 状态更新（每个 Tick 都检查历史记录）🚨
   // UpdateCSLByHistory();
   UpdateCSLByHistory_V3();

   // 🚨 NEW: 日内盈亏增量更新
   // UpdateDailyProfit(); // 每次Tick都调用，更新 g_Today_Realized_PL
   UpdateDailyProfit_V4();

   // =======================================================
   // 🚨 3. 核心调用：持仓管理与追踪止损 (最重要！)
   // =======================================================
   // 必须放在 New Bar Check 之前！
   // 因为价格在K线内部跳动时，我们也要随时移动止损，不能等K线收盘才动。
   ManageOpenTrades();

   // 1. 检查是否在允许的交易时段
   if (!IsCurrentTimeInSlots())
   {
      // 如果不在时段内，显示注释并退出
      Print("当前为本地时间: ", TimeToString(TimeCurrent() + g_TimeOffset_Sec, TIME_DATE | TIME_MINUTES), " 不在允许的交易时段: ", Local_Trade_Slots, ",EA 暂停运行...");
      return; 
   }

   // B. CSL 锁定检查 (阻止所有交易)
   if (IsTradingLocked()) return;

   // 2. 日内亏损限额检查 (直接读取全局变量)
   // if (IsDailyLossLimitReached()) return;
   if (IsDailyLossLimitReached_V2()) return;

   // ----------------------------------------------------
   // 🚨 优先级 1.5: 最大持仓限制检查 (NEW!) 🚨
   // ----------------------------------------------------
   // 如果当前持仓数已达到或超过允许的最大值，则阻止开仓
   if (GetOpenPositionsCount() >= Max_Open_Orders)
   {
      // 打印信息（可选，用于调试）
      // Print("最大持仓限制触发: 当前持仓数已达 ", Max_Open_Orders, "，阻止新开仓。");
      return; // 退出 OnTick，阻止执行后面的信号逻辑
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

   // =======================================================
   // 🧹 1. 辞旧：清理上一根K线留下的所有“上下文连接线”
   // =======================================================
   CleanOldContextLinks();

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

   // ==========================================================================
   // 第二阶段：核心执行循环 (只针对精英信号进行决策)
   // ==========================================================================

   // 🚨 新版核心扫描逻辑：循环“有效信号列表 X” 🚨
   for (int i = 0; i < total_valid_signals; i++)
   {
      // 注意这里 上面的代码 会将最新且有效的信号 即K[1] 排在列表的 第一个元素
      // signal_item 就是当前最新的有效信号，full_data 则是信号的 另一个信息载体

      // A. 从列表中提取关键信息
      FilteredSignal signal_item = sorted_valid_signals[i];
      int current_shift = signal_item.shift;
      Print("===>[366]: 循环遍历过滤后的信号列表 查看是否包含K[1] 最新信号 current_shift: ", current_shift, " 信号时间: ", signal_item.signal_time, " 信号类型: ", (signal_item.type == OP_BUY ? "BUY 信号" : "SELL 信号"));

      // B. 重新获取完整的指标数据 (为了兼容 CheckSignalAndFilter)
      // 虽然 FilteredSignal 有部分数据，但 CheckSignalAndFilter 可能需要完整的 KBarSignal 结构
      KBarSignal full_data = GetIndicatorBarData(current_shift);

      // ----------------------------------------------------
      // 🚨 核心调用更新 🚨
      // 此时的逻辑是：位置优先原则的实现，先进行上下文的检查，只有上下文 位置通过 以后 才再次进行信号的过滤
      // ----------------------------------------------------
      // 将清洗过的两个列表传入函数
      int context_result = CheckSignalContext(current_shift, signal_item.type, clean_bulls, clean_bears);
      // Print("===>[378]: context_result: ", context_result);

      // 判定逻辑：
      // 如果返回 0，说明没有上下文支持，通常我们选择不做，或者降低手数
      // 如果返回 > 0 (1=反转, 2=回踩)，说明是优质信号
      if (context_result > 0)
      {
         // Print("===>[385]: context_result---上下文通过检查了 开始执行交易吧 ", context_result);
         Print("===> [Pass] 上下文检查通过 (代码:", context_result, ")。进入空间检查...");

         // ==========================================================================
         // 🚨 4.1 新增：利润空间检查 (Reward/Risk Check) 🚨
         // 位置对了，还要看有没有肉吃（盈亏比）
         // ==========================================================================
         
         bool is_space_sufficient = false;
         
         // 准备计算参数
         double check_entry = Close[current_shift]; // 假设以信号K线收盘价入场 有一定的误差但是影响不是很大  实际的入场价格 在执行逻辑里面
         double check_sl    = 0.0;
         
         // --- 分类检查 ---
         if (signal_item.type == OP_SELL)
         {
             check_sl = full_data.BearishStopLossPrice;// High[current_shift]; // 做空止损通常在K线高点
             
             // 检查做空空间：传入【看涨列表 clean_bulls】作为下方的障碍物
             is_space_sufficient = CheckProfitSpace(OP_SELL, check_entry, check_sl, clean_bulls);
         }
         else if (signal_item.type == OP_BUY)
         {
             check_sl = full_data.BullishStopLossPrice;// Low[current_shift];  // 做多止损通常在K线低点
             
             // 检查做多空间：传入【看跌列表 clean_bears】作为上方的障碍物
             is_space_sufficient = CheckProfitSpace(OP_BUY, check_entry, check_sl, clean_bears);
         }
         
         // --- 决策 ---
         if (!is_space_sufficient)
         {
             Print(" [RiskControl] 信号 K[", current_shift, "] 被拒绝：盈亏比空间不足 (Reward/Risk < 阈值)。");
             continue; // 🚨 跳过当前信号，继续循环检查下一个（如果有的话），或者直接退出循环
         }
         
         // ==========================================================================
         // 🚨 新增：反向距离震荡过滤
         if (CheckHedgeDistance(signal_item.type) == false)
         {
            return; // 距离太近，放弃本次开仓
         }

         // ==========================================================================

         // C. 核心决策：执行 L2 (趋势/斐波) 和 L3 (风险/新鲜度) 过滤
         // 注意：这里的 CheckSignalAndFilter 可能会再次检查 L2c (CheckSignalContext)
         // 此时它会基于这个 shift 进行上下文判断
         int trade_command = CheckSignalAndFilter_V2(full_data, current_shift);

         // 调试打印 (可选)
         // Print("检查有效信号 #", i, " (Shift ", current_shift, ") -> 结果: ", trade_command);

         if (trade_command != OP_NONE)
         {
            // D. 找到最新且通过所有检查的信号，执行交易
            CalculateTradeAndExecute_V2(full_data, trade_command);

            // E. 立即退出！
            // 因为 sorted_valid_signals 是按时间排序的，第一个通过检查的肯定是最新的合规信号。
            return;
         }

         return;
      }
   }

   //+------------------------------------------------------------------+
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // 定时自动清理 (防止忘记点按钮导致垃圾堆积)
   CleanUpShadowLedger();
   Print(" [定时器] 3天周期已到，已自动执行影子数据清理。");
}

//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
// double OnTester()
// {
//   //---
//   double ret = 0.0;
//   //---

//   //---
//   return (ret);
// }

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // 检测鼠标点击对象事件
   if (id == CHARTEVENT_OBJECT_CLICK)
   {
      // 检查被点击的是不是我们的清理按钮
      if (sparam == BTN_CLEANUP_NAME)
      {
         // 1. 执行清理逻辑
         CleanUpShadowLedger();

         // 2. 视觉反馈：让按钮弹起来 (取消按下状态)
         ObjectSetInteger(0, BTN_CLEANUP_NAME, OBJPROP_STATE, false);

         // 3. 强制刷新图表
         ChartRedraw();

         // 4. 弹出提示
         MessageBox("已成功清理失效的影子账本数据！\n保留了当前持仓的有效数据。", "系统提示", MB_OK | MB_ICONINFORMATION);
      }
   }
}
//+------------------------------------------------------------------+

//====================================================================
// 4. 核心辅助函数库 (The Engine Room)
//====================================================================

/*
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
*/

// 🚨 修正后的函数签名：增加 entry_price 参数 🚨
void ExecuteTrade(int type, double lots, double sl, double tp, double entry_price, string comment)
{
   if (!EA_Trading_Enabled)
   {
      Print("没有开启 EA_Trading_Enabled 开关，需要手动根据信号来决定是否开仓！！！");
      return;
   }
   
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

/**
 * 执行订单创建版本2
 * @param type: buy or sell
 * @param lots: 下单手数
 * @param cl: 信号确认的收盘价【用来计算】
 * @param sl: 止损价格
 * @param tp: 止盈价格
 * @param entry_price: 入场价
 * @param comment: 订单备注
 */
void ExecuteTrade_V2(int type, double lots, double cl, double sl, double tp, double entry_price, string comment)
{
   if (!EA_Trading_Enabled)
   {
      Print("没有开启 EA_Trading_Enabled 开关，需要手动根据信号来决定是否开仓！！！");
      return;
   }

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
      string var_prefix = ShortenObjectNameBot(WindowExpertName()) + "_";
      // 变量命名规则: 前缀_订单号_类型
      string var_name_E = var_prefix + IntegerToString(ticket) + "_E";
      string var_name_S = var_prefix + IntegerToString(ticket) + "_S";

      // 存储理论价格 (GlobalVariableSet 存的是 double，精度足够)
      GlobalVariableSet(var_name_E, cl);
      GlobalVariableSet(var_name_S, sl);

      Print(" [影子账本] 订单 #", ticket, " 数据已绑定: E=", cl, " S=", sl);

      Print("订单执行成功! Ticket: ", ticket, " 类型: ", (type == OP_BUY ? "BUY" : "SELL"), " SL: ", sl, " TP: ", tp);
   }
   else
   {
      Print("订单执行失败! 错误代码: ", GetLastError(), ", 预期入场价: ", entry_price);
   }
}


//+------------------------------------------------------------------+
//| 函数: 检查信号质量和外部过滤 (L2 核心决策)
//| 职责: 协调所有内部和外部过滤规则
//| 返回: OP_BUY, OP_SELL, 或 0 (OP_NONE)
//+------------------------------------------------------------------+

/*
//+------------------------------------------------------------------+
//| 1.0
//| 核心决策函数：检查信号有效性并执行防重复过滤
//| 去除了 L3a (新鲜度) 和 L3b (最大风险)，仅保留核心逻辑
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
*/



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
    double tp_level = 1.0; 
    
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
//| CalculateTradeAndExecute V2.0
//| 功能：集成固定手数与以损定仓模式，执行交易
//+------------------------------------------------------------------+
void CalculateTradeAndExecute_V2(const KBarSignal &data, int type)
{
    // =================================================================
    // 1. 价格准备 (Entry & SL)
    // =================================================================
    double entry_price = Open[0]; // 始终在新K线开盘时入场
    double sl_price    = 0;
    
    // 获取止损价格 (根据信号结构)
    if (type == OP_BUY)
    {
        sl_price = data.BullishStopLossPrice;
    }
    else if (type == OP_SELL)
    {
        sl_price = data.BearishStopLossPrice;
    }
    
    // 安全检查：防止止损价格无效
    if (sl_price == 0) 
    {
        Print("错误：止损价格无效 (0)，取消开仓。");
        return;
    }

    // =================================================================
    // 2. 计算风险距离与止盈 (TP)
    // =================================================================
    double risk_dist = MathAbs(entry_price - sl_price);
    double tp_price  = 0;

    // 根据盈亏比 RewardRatio 计算 TP
    // TP = Entry +/- (RiskDistance * Ratio)
    if (type == OP_BUY)
    {
        tp_price = entry_price + (risk_dist * RewardRatio);
    }
    else if (type == OP_SELL)
    {
        tp_price = entry_price - (risk_dist * RewardRatio);
    }

    // =================================================================
    // 3. 仓位计算 (核心升级部分 🚀)
    // =================================================================
    double trade_lots = 0.0;

    // --- 分支 A: 固定手数模式 ---
    if (Position_Mode == POS_FIXED_LOT)
    {
        trade_lots = NormalizeLots(FixedLot);
    }
    // --- 分支 B: 以损定仓模式 (风险模型) ---
    else if (Position_Mode == POS_RISK_BASED)
    {
        // 调用我们编写的通用计算函数，传入当前的 Risk_Mode 和 Risk_Value
        trade_lots = GetPositionSize_V1(entry_price, sl_price, Risk_Mode, Risk_Value);
        
        // 记录日志，方便检查计算是否正确
        Print("[资金管理] 模式:", EnumToString(Risk_Mode), 
              " | 设定风险:", Risk_Value, 
              " | 止损差价:", DoubleToString(risk_dist, _Digits),
              " => 计算手数:", trade_lots);
    }

    // 最终检查：如果计算出的手数无效 (例如余额不足导致算出来是0)，则中止
    if (trade_lots <= 0)
    {
        Print("错误：计算出的手数无效 (<=0)，可能是资金不足或止损过小。取消交易。");
        return;
    }

    // =================================================================
    // 4. 信号 ID 与 注释生成
    // =================================================================
    string signal_id = GenerateSignalID(data.OpenTime);
    
    // 注释格式：版本 | 信号ID | 风险提示
    // 例如: "V2.0|20231010-0900|Risk:100"
    string risk_info = (Position_Mode == POS_FIXED_LOT) ? "FixLot" : ("Risk:" + DoubleToString(Risk_Value, 1));
    string comment   = EA_Version_Tag + "|" + signal_id + "|" + risk_info;

    // =================================================================
    // 写入订单的辅助信息
    // =================================================================
    // 2. 准备理论价格数据
    double theoretical_entry = Close[1]; // K[1] 收盘价
    double original_sl       = sl_price; // 原始止损

    // =================================================================
    // 5. 执行交易
    // =================================================================
    // 假设您已有 ExecuteTrade 封装函数，如果通过测试，可以直接使用
    // 注意：将 trade_lots 传入
    ExecuteTrade_V2(type, trade_lots, theoretical_entry, sl_price, tp_price, entry_price, comment);

    // 打印详细执行日志
    Print(" [交易执行 V2.0] 类型:", (type == OP_BUY ? "BUY" : "SELL"),
          " | 手数:", DoubleToString(trade_lots, 2),
          " | 入场:", DoubleToString(entry_price, _Digits),
          " | SL:", DoubleToString(sl_price, _Digits),
          " | TP(Ratio ", DoubleToString(RewardRatio, 1), "):", DoubleToString(tp_price, _Digits),
          " | 质量:", IntegerToString((int)((type == OP_BUY) ? data.BullishReferencePrice : data.BearishReferencePrice))
          );
}

//+------------------------------------------------------------------+
// 🚨 注意：由于 Buffer 2/3 现在存储了信号质量代码，您必须在 GetIndicatorBarData 中：
// 1. 确保读取出来的 double 值在 CalculateTradeAndExecute 中被正确转换为 int (质量)。
// 2. 斐波那契的 Reference Price 必须改为直接使用 Close[1] 来获取，如 CalculateTradeAndExecute 中所示。
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 初始化斐波那契级别 (在 OnInit 中调用)                           |
//| 将外部输入字符串解析并填充到全局数组 g_FiboExhaustionLevels      |
//+------------------------------------------------------------------+
void InitializeFiboLevels(string zone1, string zone2, string zone3, string zone4)
{
   g_FiboZonesCount = 0; // 重置计数器

   // 尝试解析 Zone 1
   if (ParseFiboZone(zone1, g_FiboExhaustionLevels[g_FiboZonesCount][0], g_FiboExhaustionLevels[g_FiboZonesCount][1]))
      g_FiboZonesCount++;

   // 尝试解析 Zone 2
   if (g_FiboZonesCount < MAX_FIBO_ZONES && ParseFiboZone(zone2, g_FiboExhaustionLevels[g_FiboZonesCount][0], g_FiboExhaustionLevels[g_FiboZonesCount][1]))
      g_FiboZonesCount++;

   // 尝试解析 Zone 3
   if (g_FiboZonesCount < MAX_FIBO_ZONES && ParseFiboZone(zone3, g_FiboExhaustionLevels[g_FiboZonesCount][0], g_FiboExhaustionLevels[g_FiboZonesCount][1]))
      g_FiboZonesCount++;

   if (g_FiboZonesCount < MAX_FIBO_ZONES && ParseFiboZone(zone4, g_FiboExhaustionLevels[g_FiboZonesCount][0], g_FiboExhaustionLevels[g_FiboZonesCount][1]))
      g_FiboZonesCount++;

   // 2.0
   // Print("斐波那契上下文区域初始化完成。共加载 ", g_FiboZonesCount, " 个区域。");
   // for (int z = 0; z < g_FiboZonesCount; z++)
   // {
   //    double level1 = g_FiboExhaustionLevels[z][0];
   //    Print("--->[KTarget_FinderBot.mq4:2294]: level1: ", level1);
   //    double level2 = g_FiboExhaustionLevels[z][1];
   //    Print("--->[KTarget_FinderBot.mq4:2296]: level2: ", level2);
   // }

   // 循环遍历方式 1.0
   // int rows = ArrayRange(g_FiboExhaustionLevels, 0);    // 获取行数 (3)
   // Print("--->[KTarget_FinderBot.mq4:2286]: rows: ", rows);

   // int cols = ArrayRange(g_FiboExhaustionLevels, 1); // 获取当前行的列数 (4)
   // Print("--->[KTarget_FinderBot.mq4:2289]: cols: ", cols);

   // for (int i = 0; i < rows; i++)
   // {
   //    // 遍历每一行
   //    for (int j = 0; j < cols; j++)
   //    {
   //       // 遍历每一列
   //       // 访问元素
   //       Print("Element at [", i, "][", j, "] is: ", g_FiboExhaustionLevels[i][j]);
   //    }
   // }
}

