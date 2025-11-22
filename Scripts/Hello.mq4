//+------------------------------------------------------------------+
//|                                                        Hello.mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd." // 版权信息
#property link      "https://www.mql5.com"           // 链接
#property version   "1.00"                           // 版本
#property strict                                     // 启用严格编译模式 (推荐)

//==================================================================
// 1. OnInit: 初始化函数
//==================================================================
/*
  说明：EA 和自定义指标的初始化函数。对于脚本 (Script) 来说，
  OnInit() 并非必需，但如果存在，它会在脚本被加载时先于 OnStart() 执行一次。
*/
int OnInit()
{
   int a = 123;
   Print(">[Hello.mq4:21]: a: ", a);

   return(INIT_SUCCEEDED); // 返回 INIT_SUCCEEDED 表示初始化成功
}


//+------------------------------------------------------------------+
//| Script program start function (脚本主入口)                       |
//+------------------------------------------------------------------+
/*
  说明：脚本 (Script) 的核心函数。程序从这里开始执行，执行完毕后自动终止。
*/
void OnStart()
  {
//--- 脚本主逻辑开始 ---

//   High[0]; // 访问当前未收盘 K 线的最高价
//   Low[0];  // 访问当前未收盘 K 线的最低价
//   Volume[0]; // 访问当前未收盘 K 线的 Tick Volume
//   
//   int a = 5; // 定义一个局部变量
//   a++;       // 自增操作
//   
//   MessageBox(High[0]); // MessageBox 会弹出窗口，在实际交易中应少用
//   MessageBox(Low[0]);
   //MessageBox(Volume[0]);
//   MessageBox(Bars);
//   
//   MessageBox(AccountBalance());
//   MessageBox(PERIOD_D1);
//   MessageBox("Hello, World! There is some text.","caption");
   
// --- 交易品种和图表信息 (MQL4 内置预定义变量) ---
   Print("Symbol name of the current chart=",_Symbol);  // 当前图表的交易品种名称 (例如: EURUSD)。_Symbol 是内置全局变量。
   Print("Timeframe of the current chart=",_Period);   // 当前图表的时间周期 (例如: 15=M15, 60=H1)。_Period 是内置全局变量。
   
// --- 实时报价信息 (MQL4 内置预定义变量) ---
   Print("The latest known seller's price (ask price) for the current symbol=",Ask); // 卖价（Ask）: 交易者买入时支付的价格
   Print("The latest known buyer's price (bid price) of the current symbol=",Bid);   // 买价（Bid）: 交易者卖出时获得的价格
   
// --- 价格精度和点值信息 (MQL4 内置预定义变量) ---
   Print("Number of decimal places=",Digits);      // 价格小数位数 (例如: EURUSD=5, JPY=3)。
   Print("Number of decimal places=",_Digits);     // 与 Digits 相同 (MQL4 中存在两种命名习惯)。
   
   Print("Size of the current symbol point in the quote currency=",_Point); // 点 (Point) 的值，例如 0.00001
   Print("Size of the current symbol point in the quote currency=",Point);   // 与 _Point 相同 (MQL4 中存在两种命名习惯)。
   
// --- K线数据信息 (MQL4 内置预定义变量) ---
   Print("Number of bars in the current chart=",Bars); // 当前图表上加载的 K 线总根数
   
// --- K线价格数组 (MQL4 内置数组) ---
   // 索引 [0] 永远代表当前正在形成的 K 线（未收盘）
   Print("Open price of the current bar of the current chart=",Open[0]);  
   Print("Close price of the current bar of the current chart=",Close[0]); 
   Print("High price of the current bar of the current chart=",High[0]);   
   Print("Low price of the current bar of the current chart=",Low[0]);     
   
   Print("Time of the current bar of the current chart=",Time[0]);         // 当前 K 线的开盘时间 (GMT)
   Print("Tick volume of the current bar of the current chart=",Volume[0]); // 当前 K 线的交易量 (Tick Volume)
   
// --- 错误和环境状态 (MQL4 内置预定义变量) ---
   Print("Last error code=",_LastError);           // 上一次交易或 MQL 函数调用失败后的错误代码。
   Print("Random seed=",_RandomSeed);               // 随机数生成器的种子值。
   Print("Stop flag=",_StopFlag);                   // EA 正在停止的标志，通常用于 OnDeinit() 中。
   Print("Uninitialization reason code=",_UninitReason); // EA 或指标被终止的原因代码。 
   //MessageBox(AccountBalance()); // 再次注释掉 MessageBox，避免弹出窗口
  }
//+------------------------------------------------------------------+

//==================================================================
// 2. OnTick: 报价事件函数
//==================================================================
/*
  说明：OnTick() 仅用于 EA (Expert Advisor)。对于脚本，它不会被执行。
  当收到新的市场报价时，MT4 终端会调用此函数。
*/
void OnTick()
{
    // 这里可以编写基于市场报价的交易逻辑
    
    // 注意：在脚本 Hello.mq4 中，OnTick() 不会被执行，只有 OnStart() 会执行一次。
   Print("The latest known seller's price (ask price) for the current symbol=",Ask);
   Print("The latest known buyer's price (bid price) of the current symbol=",Bid);
   Print("Account Balance=",AccountBalance()); // AccountBalance() 是一个内置函数，返回账户净值
}