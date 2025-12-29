//+------------------------------------------------------------------+
//|                                        PA_Signal_System.mq4      |
//|                               Copyright 2024, PriceAction Master |
//|                                            Modular Architecture  |
//+------------------------------------------------------------------+
/**
客户想做一款识别如下信号的指标

1.孕线 Inside Bar 
2.吞没 Engulfing Bar 
3.Pin Bar
4.孕线假突破 Fakey Inside Bar 
5.Bar Reversal


功能1：识别标注
功能2：能提醒客户信号出现了
功能3：如果能在一些关键的支撑和阻力位上出现这些信号，就更加要提醒了

给参谋参谋 该如何用代码实现呢？

代码要解耦，独立，可以扩展，修改要方便
*/

/*
客户认为  不用扫描那么频繁，只需要在 每次旧K线结束，新K线开盘时扫描一次就行

信号的确认 肯定是 close价格以后才判断是否是信号的

注意修改代码时标注修改细节，客户需要对比代码修改了什么？
*/

/*
2025.12.26 18:09:02.642	PA_Signal_System_V2 GBPUSD,M5: array out of range in 'PA_Signal_System_V2.mq4' (135,11)
*/

#property strict
#property indicator_chart_window
#property indicator_buffers 2 
// 这里为了演示简单，只分配箭头Buffer，实际画图可能需要Object

//--- 输入参数
input bool   InpEnableInside    = true;  // 开启孕线识别
input bool   InpEnableEngulfing = true;  // 开启吞没识别
input bool   InpEnablePinBar    = true;  // 开启PinBar识别
input bool   InpEnableFakey     = true;  // 开启Fakey识别
input bool   InpFilterKeyLevel  = true;  // 开启关键位过滤(功能3)
input int    InpKeyLevelPeriod  = 20;    // 关键位判断周期(简易版)

//--- 信号类型枚举
enum E_SignalType {
   SIG_NONE,
   SIG_INSIDE_BAR,
   SIG_ENGULFING,
   SIG_PINBAR,
   SIG_FAKEY,
   SIG_REVERSAL
};

//--- 信号结构体 (数据解耦的关键)
struct PA_Signal {
   E_SignalType type;   // 信号类型
   int          dir;    // 方向: 1做多, -1做空
   int          barIdx; // 发生在哪根K线
   double       price;  // 信号价格
};

//--- 全局变量
double BufferBuy[];
double BufferSell[];
datetime lastAlertTime = 0;

//+------------------------------------------------------------------+
//| 初始化
//+------------------------------------------------------------------+
int OnInit() {
   SetIndexBuffer(0, BufferBuy);
   SetIndexBuffer(1, BufferSell);
   SetIndexStyle(0, DRAW_ARROW);
   SetIndexStyle(1, DRAW_ARROW);
   SetIndexArrow(0, 233); // 上箭头
   SetIndexArrow(1, 234); // 下箭头
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 主计算循环
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[]) {
   
   int limit = rates_total - prev_calculated;
   Print("--->[KT_PA_Signal_System.mq4:95]: limit: ", limit);

   if(limit > 1000) limit = 1000; // 首次加载只算最近1000根
   if(limit <= 0) return(rates_total);
   Print("--->[KT_PA_Signal_System.mq4:99]: limit: ", limit);

   // --- 循环检测每一根K线 ---
   for(int i = limit; i >= 1; i--) { // i=1 表示上一根收盘的K线（确认信号）
      
      PA_Signal signal;
      signal.type = SIG_NONE;
      
      // 1. 信号识别 (Signal Layer)
      if(InpEnableInside && CheckInsideBar(i, high, low, signal)) {}
      else if(InpEnableEngulfing && CheckEngulfing(i, open, close, high, low, signal)) {}
      else if(InpEnablePinBar && CheckPinBar(i, open, close, high, low, signal)) {}
      else if(InpEnableFakey && CheckFakey(i, high, low, close, open, signal)) {}
      // ... 可以继续扩展 Bar Reversal
      
      // 如果没有信号，跳过
      if(signal.type == SIG_NONE) continue;

      // 2. 关键位过滤 (Filter Layer - 功能3)
      if(InpFilterKeyLevel) {
         if(!IsKeyLevel(i, signal.dir, high, low)) continue; // 如果不在关键位，过滤掉
      }

      // 3. 执行层 (Action Layer)
      // 3.1 画图 (功能1)
      if(signal.dir == 1) BufferBuy[i] = low[i] - 10 * Point;
      if(signal.dir == -1) BufferSell[i] = high[i] + 10 * Point;
      
      // 3.2 报警 (功能2) - 仅针对刚收盘的K线(i=1)报警一次
      if(i == 1 && time[0] != lastAlertTime) {
         SendAlert(signal);
         lastAlertTime = time[0];
      }
   }
   return(rates_total);
}

//====================================================================
// 模块一：信号识别逻辑库 (解耦的核心，随意修改逻辑不影响主框架)
//====================================================================

// 1. 孕线识别
bool CheckInsideBar(int i, const double &high[], const double &low[], PA_Signal &out) {
   // 当前K线最高价小于前一根，最低价大于前一根
   if(high[i] < high[i+1] && low[i] > low[i+1]) {
      out.type = SIG_INSIDE_BAR;
      out.barIdx = i;
      out.dir = 0; // 孕线通常是中性信号，或者作为蓄势
      // 可以根据收盘价位置判断潜在方向，这里暂定0
      return true;
   }
   return false;
}

// 2. 吞没识别
bool CheckEngulfing(int i, const double &open[], const double &close[], const double &high[], const double &low[], PA_Signal &out) {
   // 看涨吞没
   if(close[i] > open[i] && close[i] > high[i+1] && open[i] < low[i+1]) {
      out.type = SIG_ENGULFING;
      out.dir = 1;
      return true;
   }
   // 看跌吞没
   if(close[i] < open[i] && close[i] < low[i+1] && open[i] > high[i+1]) {
      out.type = SIG_ENGULFING;
      out.dir = -1;
      return true;
   }
   return false;
}

// 3. Pin Bar 识别
bool CheckPinBar(int i, const double &open[], const double &close[], const double &high[], const double &low[], PA_Signal &out) {
   double range = high[i] - low[i];
   if(range == 0) return false;
   
   double body = MathAbs(open[i] - close[i]);
   double upperWick = high[i] - MathMax(open[i], close[i]);
   double lowerWick = MathMin(open[i], close[i]) - low[i];
   
   // 逻辑：影线占总长度的2/3以上，且实体很小
   // 看跌 Pin Bar (长上影)
   if(upperWick > range * 0.66 && body < range * 0.2 && lowerWick < range * 0.1) {
      out.type = SIG_PINBAR;
      out.dir = -1;
      return true;
   }
   // 看涨 Pin Bar (长下影)
   if(lowerWick > range * 0.66 && body < range * 0.2 && upperWick < range * 0.1) {
      out.type = SIG_PINBAR;
      out.dir = 1;
      return true;
   }
   return false;
}

// 4. Fakey (孕线假突破)
bool CheckFakey(int i, const double &high[], const double &low[], const double &close[], const double &open[], PA_Signal &out) {
   // 需要至少3根K线：i+2(母线), i+1(子线/孕线), i(假突破线)
   
   // 第一步：i+1 必须是 Inside Bar
   if(high[i+1] < high[i+2] && low[i+1] > low[i+2]) {
      
      // 看涨 Fakey：先跌破母线低点，然后收盘收回来
      if(low[i] < low[i+2] && close[i] > low[i+2] && close[i] > open[i]) {
         out.type = SIG_FAKEY;
         out.dir = 1;
         return true;
      }
      
      // 看跌 Fakey：先突破母线高点，然后收盘跌回来
      if(high[i] > high[i+2] && close[i] < high[i+2] && close[i] < open[i]) {
         out.type = SIG_FAKEY;
         out.dir = -1;
         return true;
      }
   }
   return false;
}

//====================================================================
// 模块二：过滤层 (关键位判断)
//====================================================================
bool IsKeyLevel(int i, int dir, const double &high[], const double &low[]) {
   // 这是一个简易的支撑阻力判断逻辑
   // 真正的高级用法应该调用ZigZag指标或分形指标
   
   // 逻辑：如果是做多信号，要求当前低点接近过去N根K线的最低点（支撑位）
   if(dir == 1) {
      double lowest = low[i];
      for(int k=1; k<=InpKeyLevelPeriod; k++) {
         if(low[i+k] < lowest) return false; // 如果前面有更低的，说明这里不是明显的底部支撑
      }
      return true;
   }
   
   // 逻辑：如果是做空信号，要求当前高点接近过去N根K线的最高点（阻力位）
   if(dir == -1) {
      double highest = high[i];
      for(int k=1; k<=InpKeyLevelPeriod; k++) {
         if(high[i+k] > highest) return false;
      }
      return true;
   }
   
   return true; // 如果是中性信号，不过滤
}

//====================================================================
// 模块三：报警执行
//====================================================================
void SendAlert(PA_Signal &sig) {
   string typeStr = "";
   switch(sig.type) {
      case SIG_INSIDE_BAR: typeStr = "Inside Bar"; break;
      case SIG_ENGULFING:  typeStr = "Engulfing"; break;
      case SIG_PINBAR:     typeStr = "Pin Bar"; break;
      case SIG_FAKEY:      typeStr = "Fakey"; break;
   }
   
   string dirStr = (sig.dir == 1) ? "BULLISH" : (sig.dir == -1 ? "BEARISH" : "NEUTRAL");
   string msg = StringFormat("PA Signal: %s [%s] on %s", typeStr, dirStr, Symbol());
   
   Alert(msg);
   // SendNotification(msg); // 如果配置了手机推送，取消注释
}