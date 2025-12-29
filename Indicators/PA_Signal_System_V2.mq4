//+------------------------------------------------------------------+
//|                                   PA_Signal_System_Optimized.mq4 |
//|                               Copyright 2024, PriceAction Master |
//|                                            Modular Architecture  |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 2 

//--- 输入参数
input bool   InpEnableInside    = true;  // 开启孕线识别
input bool   InpEnableEngulfing = true;  // 开启吞没识别
input bool   InpEnablePinBar    = true;  // 开启PinBar识别
input bool   InpEnableFakey     = true;  // 开启Fakey识别
input bool   InpFilterKeyLevel  = true;  // 开启关键位过滤(功能3)
input int    InpKeyLevelPeriod  = 20;    // 关键位判断周期

//--- 信号类型枚举
enum E_SignalType {
   SIG_NONE,
   SIG_INSIDE_BAR,
   SIG_ENGULFING,
   SIG_PINBAR,
   SIG_FAKEY,
   SIG_REVERSAL
};

//--- 信号结构体
struct PA_Signal {
   E_SignalType type;
   int          dir;    // 1做多, -1做空
   int          barIdx;
   double       price;
};

//--- 全局变量
double BufferBuy[];
double BufferSell[];

// >>> [修改 1] 新增时间记录变量 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
datetime lastBarTime = 0;
// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

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
   
   // >>> [修改 2] 核心优化：新K线检测 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
   // 必须设置数组为序列，确保 time[0] 是最新K线时间
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true); // 其他数组也建议设置，防止逻辑混乱
   ArraySetAsSeries(BufferBuy, true);
   ArraySetAsSeries(BufferSell, true);

   // 如果不是第一次运行(有历史数据)，且当前K线时间没变，直接跳过！
   if(prev_calculated > 0 && time[0] == lastBarTime) {
       return(rates_total); 
   }
   // 更新时间戳
   lastBarTime = time[0];
   // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

   // --- 计算范围设定 ---
   // 如果是第一次运行(prev_calculated=0)，计算过去1000根
   // 如果是实时运行(新K线)，limit 通常等于 1 (或者少量几根)
   int limit = rates_total - prev_calculated;
   if(limit > 1000) limit = 1000; 
   if(limit < 1) limit = 1; // 确保至少计算刚收盘的那根(Index=1)

   // --- 循环检测 ---
   // 注意：i 从 limit 开始，到 1 结束。
   // i=0 是当前未收盘的K线，我们故意不检测它，只检测 i>=1 的已收盘K线
   for(int i = limit; i >= 1; i--) { 
      
      PA_Signal signal;
      signal.type = SIG_NONE;
      
      // 1. 信号识别 (传入 i，即检查已收盘的 K线)
      if(InpEnableInside && CheckInsideBar(i, high, low, signal)) {}
      else if(InpEnableEngulfing && CheckEngulfing(i, open, close, high, low, signal)) {}
      else if(InpEnablePinBar && CheckPinBar(i, open, close, high, low, signal)) {}
      else if(InpEnableFakey && CheckFakey(i, high, low, close, open, signal)) {}
      
      if(signal.type == SIG_NONE) continue;

      // 2. 关键位过滤
      if(InpFilterKeyLevel) {
         if(!IsKeyLevel(i, signal.dir, high, low)) continue;
      }

      // 3. 执行层
      // 3.1 画图
      if(signal.dir == 1) BufferBuy[i] = low[i] - 10 * Point;
      if(signal.dir == -1) BufferSell[i] = high[i] + 10 * Point;
      
      // 3.2 报警 (只在 i==1 时报警)
      // >>> [修改 3] 报警逻辑优化 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      // 因为代码限制了只在新K线开盘时运行，且循环包含了 i=1
      // 所以只要检测到 i==1 有信号，就可以直接报警，不用担心重复报警
      if(i == 1) {
         SendAlert(signal);
      }
      // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   }
   return(rates_total);
}

// ... (以下 CheckInsideBar, CheckEngulfing 等逻辑函数保持不变，无需修改) ...
// ... (为了节省篇幅，此处省略逻辑函数部分，直接复用上一版即可) ...

//====================================================================
// 模块一：信号识别逻辑库 (复用上一版)
//====================================================================
bool CheckInsideBar(int i, const double &high[], const double &low[], PA_Signal &out) {
   if(high[i] < high[i+1] && low[i] > low[i+1]) {
      out.type = SIG_INSIDE_BAR; out.barIdx = i; out.dir = 0; return true;
   }
   return false;
}

bool CheckEngulfing(int i, const double &open[], const double &close[], const double &high[], const double &low[], PA_Signal &out) {
   if(close[i] > open[i] && close[i] > high[i+1] && open[i] < low[i+1]) {
      out.type = SIG_ENGULFING; out.dir = 1; return true;
   }
   if(close[i] < open[i] && close[i] < low[i+1] && open[i] > high[i+1]) {
      out.type = SIG_ENGULFING; out.dir = -1; return true;
   }
   return false;
}

bool CheckPinBar(int i, const double &open[], const double &close[], const double &high[], const double &low[], PA_Signal &out) {
   double range = high[i] - low[i];
   if(range == 0) return false;
   double body = MathAbs(open[i] - close[i]);
   double upperWick = high[i] - MathMax(open[i], close[i]);
   double lowerWick = MathMin(open[i], close[i]) - low[i];
   if(upperWick > range * 0.66 && body < range * 0.2 && lowerWick < range * 0.1) {
      out.type = SIG_PINBAR; out.dir = -1; return true;
   }
   if(lowerWick > range * 0.66 && body < range * 0.2 && upperWick < range * 0.1) {
      out.type = SIG_PINBAR; out.dir = 1; return true;
   }
   return false;
}

bool CheckFakey(int i, const double &high[], const double &low[], const double &close[], const double &open[], PA_Signal &out) {
   if(high[i+1] < high[i+2] && low[i+1] > low[i+2]) {
      if(low[i] < low[i+2] && close[i] > low[i+2] && close[i] > open[i]) {
         out.type = SIG_FAKEY; out.dir = 1; return true;
      }
      if(high[i] > high[i+2] && close[i] < high[i+2] && close[i] < open[i]) {
         out.type = SIG_FAKEY; out.dir = -1; return true;
      }
   }
   return false;
}

bool IsKeyLevel(int i, int dir, const double &high[], const double &low[]) {
   if(dir == 1) {
      double lowest = low[i];
      for(int k=1; k<=InpKeyLevelPeriod; k++) if(low[i+k] < lowest) return false;
      return true;
   }
   if(dir == -1) {
      double highest = high[i];
      for(int k=1; k<=InpKeyLevelPeriod; k++) if(high[i+k] > highest) return false;
      return true;
   }
   return true; 
}

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
}