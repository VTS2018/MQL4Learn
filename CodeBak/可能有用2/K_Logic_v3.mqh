//+------------------------------------------------------------------+
//|                                                   K_Logic_v3.mqh |
//|                         Core Logic for KTarget Finder & Bot v3.0 |
//|                                  Senior EA Architect Integration |
//+------------------------------------------------------------------+
// #property copyright "YourName"
// #property strict

/**
 * 根据当前图表周期 (_Period) 返回一组优化的参数。
 * 调优逻辑：在短周期增加K线数，在长周期减少K线数，以使时间范围更合理。
 */
TuningParameters GetTunedParameters()
{
    TuningParameters p;
    
    // 设置默认值 (如果周期不匹配，则使用 M15/H1 附近的基准值)
    p.Scan_Range             = 500;
    p.Lookahead_Bottom       = 20;
    p.Lookback_Bottom        = 20;
    p.Lookahead_Top          = 20;
    p.Lookback_Top           = 20;
    p.Max_Signal_Lookforward = 20;
    p.Look_LLHH_Candles      = 3;
    
    // 根据周期动态调整参数
    switch (_Period)
    {
        case PERIOD_M1: // M1：波动极快，需要更多的K线来定义结构
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 30;
            p.Lookahead_Top = p.Lookback_Top = 30;

            p.Max_Signal_Lookforward = 30;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M5: // M5：比 M1 稳定，但仍需比默认值大一些
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 25;
            p.Lookahead_Top = p.Lookback_Top = 25;

            p.Max_Signal_Lookforward = 25;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M15: // M15：基准周期，略低于默认值，专注于近期结构
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 18;
            p.Lookahead_Top = p.Lookback_Top = 18;

            p.Max_Signal_Lookforward = 18;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_M30: // M30：更稳定，可进一步减少
            p.Scan_Range = 1440;
            p.Lookahead_Bottom = p.Lookback_Bottom = 15;
            p.Lookahead_Top = p.Lookback_Top = 15;

            p.Max_Signal_Lookforward = 15;
            p.Look_LLHH_Candles = 3;
            break;

        case PERIOD_H1: // H1：稳定的中周期
            p.Scan_Range = 500;
            p.Lookahead_Bottom = p.Lookback_Bottom = 12;
            p.Lookahead_Top = p.Lookback_Top = 12;

            p.Max_Signal_Lookforward = 24;
            p.Look_LLHH_Candles = 3;
            break;
            
        case PERIOD_H4: // H4：长周期开始，K线代表的市场意义大增
            // 扫描范围覆盖约 2-3 周
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 8;
            p.Lookahead_Top = p.Lookback_Top = 8;

            // 也就是说 前瞻扫描的范围可以大一些 没关系 这个地方 会影响锚点的标注 如果过小会导致一些锚点 无法识别出来
            // 按说 不应该影响锚点的 标注，这里代码可能还有一些问题
            // 按理论上讲 锚点标注的逻辑 不应该收到前瞻 信号扫描的 范围影响的
            // 是不是由于 低开K线的影响导致的标注呢？
            p.Max_Signal_Lookforward = 15;
            p.Look_LLHH_Candles = 3;
            break;
            
        // 开始调整 日周期 确认K前瞻 是5根 5天    
        case PERIOD_D1: // D1：日周期，遵循您的思路 (约 1-1.5 周)
            // 扫描范围覆盖约 1 个月
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 2;
            p.Lookahead_Top = p.Lookback_Top = 2;

            p.Max_Signal_Lookforward = 5;
            //周期越大 数值可以设置的越小 如果是2 至少保证 5日内的最高价和最低价
            p.Look_LLHH_Candles = 2;
            break;
            
        case PERIOD_W1: // W1：周周期，只需要关注最近几周或几个月的结构
            // 扫描范围覆盖约 3 个月
            p.Scan_Range = 500; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 3;
            p.Lookahead_Top = p.Lookback_Top = 3;

            p.Max_Signal_Lookforward = 3;
            p.Look_LLHH_Candles = 3;
            break;
            
        // 月线调整为2    
        case PERIOD_MN1: // MN1：月周期，只需关注最近半年
            // 扫描范围覆盖约 6 个月
            p.Scan_Range = 300; 
            p.Lookahead_Bottom = p.Lookback_Bottom = 2;
            p.Lookahead_Top = p.Lookback_Top = 2;

            p.Max_Signal_Lookforward = 3;
            p.Look_LLHH_Candles = 2;
            break;
    }
    
    return p;
}

// ==========================================================================
// 1. 数据结构定义 (Data Structures)
// ==========================================================================

enum ENUM_SIGNAL_GRADE {
   GRADE_NONE = 0,
   GRADE_S    = 5, // DB + CB + 空间大
   GRADE_A    = 4, // IB + CB + 空间大 (斐波那契目标)
   GRADE_B    = 3, // DB + 空间大
   GRADE_C    = 2, // IB + 空间大
   GRADE_D    = 1, // 空间小 (建议过滤)
   GRADE_F    = -1 // 结构破坏
};

struct SignalQuality {
   ENUM_SIGNAL_GRADE grade;
   string description;
   bool is_IB;             // V型反转
   bool is_DB;             // 结构反转
   bool is_CB;             // 突破P2
   double space_factor;    // ATR因子
   double rr_ratio;        // 盈亏比
   double target_fib_1618; // 斐波目标1
};

// ==========================================================================
// 2. 核心计算引擎 (Calculation Engine)
// ==========================================================================

// 计算空间因子 (ATR Helper)
double Calculate_Space_Factor(string sym, int period, double p1, double p2, int shift) {
   double atr = iATR(sym, period, 14, shift);
   if(atr <= 0) return 0;
   return MathAbs(p2 - p1) / atr;
}

// 综合评分系统 (The Brain)
SignalQuality EvaluateSignal(
   string sym, int period, 
   int anchor_idx, int breakout_idx, 
   double p1, double p2, double sl, 
   bool is_bullish
) {
   SignalQuality sq;
   sq.grade = GRADE_NONE;
   
   // --- A. 基础计算 ---
   double atr = iATR(sym, period, 14, breakout_idx);
   if(atr==0) atr = Point;
   
   double close_price = iClose(sym, period, breakout_idx);
   int n_geo = breakout_idx - anchor_idx;
   
   sq.is_IB = (n_geo <= 2);
   sq.is_DB = (n_geo > 2);
   
   // --- B. 结构与CB判定 ---
   if (is_bullish) {
      if (p2 < p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2<P1)"; return sq; }
      sq.is_CB = (close_price > p2);
   } else {
      if (p2 > p1) { sq.grade = GRADE_F; sq.description = "结构破坏(P2>P1)"; return sq; }
      sq.is_CB = (close_price < p2);
   }

   // --- C. 空间与盈亏比 ---
   sq.space_factor = Calculate_Space_Factor(sym, period, p1, p2, breakout_idx);
   double risk = MathAbs(p1 - sl);
   double reward = MathAbs(p2 - p1);
   sq.rr_ratio = (risk > 0) ? (reward / risk) : 0;
   
   // --- D. 斐波那契目标计算 (针对 Grade A/S) ---
   double range = MathAbs(close_price - sl);
   if (is_bullish) sq.target_fib_1618 = sl + range * 1.618;
   else            sq.target_fib_1618 = sl - range * 1.618;

   // --- E. 最终定级逻辑 ---
   if (sq.is_CB) {
      // 突破了P2，且空间不是极其微小
      if (sq.is_DB) { sq.grade = GRADE_S; sq.description = "S级:主导突破(DB+CB)"; }
      else          { sq.grade = GRADE_A; sq.description = "A级:爆发突破(IB+CB)"; }
   } 
   else {
      // 没过P2，看空间
      if (sq.space_factor > 1.5) {
         if (sq.is_DB) { sq.grade = GRADE_B; sq.description = "B级:区间主导(DB)"; }
         else          { sq.grade = GRADE_C; sq.description = "C级:区间激进(IB)"; }
      } else {
         sq.grade = GRADE_D; sq.description = "D级:空间不足";
      }
   }
   
   return sq;
}

// ==========================================================================
// 3. 可视化与提醒 (Visuals & Alerts)
// ==========================================================================

// 发送富文本提醒
void SendRichAlert(string sym, int period, string type, double price, double sl, SignalQuality &sq) {
   if (sq.grade <= GRADE_D) return; // 过滤低质量
   
   string msg = StringFormat(
      "%s M%d [%s] | %s\n现价: %.5f | SL: %.5f\n因子: %.1f | R:R: %.1f\n",
      sym, period, type, sq.description, price, sl, sq.space_factor, sq.rr_ratio
   );
   
   if(sq.grade >= GRADE_A) msg += StringFormat(">> 目标: %.5f (Fib 1.618)", sq.target_fib_1618);
   
   Alert(msg);
   SendNotification(msg);
}

/*
// 绘制斐波那契矩形 (仅供 Grade A/S 使用)
void DrawFiboGradeZones(string sym, int idx, double sl, double close, bool bullish) {
   string name = "KT_Fib_" + IntegerToString(idx);
   double range = MathAbs(close - sl);
   datetime t1 = iTime(sym, 0, idx);
   datetime t2 = t1 + PeriodSeconds(0) * 30; // 延伸30根
   
   double level1, level2;
   if (bullish) {
      level1 = sl + range * 1.618;
      level2 = sl + range * 1.88;
   } else {
      level1 = sl - range * 1.618;
      level2 = sl - range * 1.88;
   }
   
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, level1, t2, level2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (bullish ? clrLightGreen : clrLightPink));
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}
*/

//+------------------------------------------------------------------+
//| DrawFiboGradeZones_v3 (最终完整版)
//| ------------------------------------------------------------------
//| 改进点：
//| 1. 接收外部 prefix，统一对象管理
//| 2. 使用 iTime 时间戳替代 K线索引，防止对象随行情漂移
//| 3. 具备存在性检查 (ObjectFind)
//+------------------------------------------------------------------+
void DrawFiboGradeZones_v3(string sym, int idx, double sl, double close, bool bullish, string prefix)
{
   // 1. 基础计算
   double range = MathAbs(close - sl);
   
   // [关键改进] 获取该 K 线的精确时间作为唯一身份 ID
   // 使用 long 类型转换确保时间戳数字的完整性
   datetime bar_time = iTime(sym, 0, idx);
   string time_str = IntegerToString((long)bar_time);

   // 计算矩形的时间宽度 (默认向右延伸 30 根 K 线)
   datetime t2 = bar_time + PeriodSeconds(0) * 30; 
   
   // 定义斐波那契倍数 (TP1, TP2, TP3)
   double fib_levels[] = {1.618, 1.88,  2.618, 2.88,  4.236, 4.88};
   color  zone_colors[] = {clrLightGreen, clrSkyBlue, clrGold};
   
   // 如果是做空，调整颜色
   if (!bullish) {
       zone_colors[0] = clrLightPink; 
       zone_colors[1] = clrLightCoral; 
       zone_colors[2] = clrOrangeRed; 
   }

   // 循环绘制 3 个目标区域
   for(int k=0; k<3; k++)
   {
       // --- A. 构建基于时间的唯一对象名 ---
       // 格式: [前缀]Fib_[时间戳]_TP[k]
       // 例如: KTarget_v3_A1_Fib_167889200_TP1
       string obj_name = prefix + "Fib_" + time_str + "_TP" + IntegerToString(k+1);
       
       // --- B. 存在性检查与创建 ---
       if(ObjectFind(0, obj_name) < 0) 
       {
           ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, 0, 0, 0, 0);
           // 静态属性仅设置一次
           ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);     // 脚本列表中隐藏
           ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);// 不可选中
           ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);       // 背景显示
           ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);       // 开启填充
       }

       // --- C. 动态属性更新 (坐标/颜色) ---
       double level_start, level_end;
       if (bullish) {
           level_start = sl + range * fib_levels[k*2];
           level_end   = sl + range * fib_levels[k*2+1];
       } else {
           level_start = sl - range * fib_levels[k*2];
           level_end   = sl - range * fib_levels[k*2+1];
       }

       // 即使对象已存在，也更新坐标 (防止参数调整后位置不对)
       ObjectSetInteger(0, obj_name, OBJPROP_TIME1, bar_time);
       ObjectSetDouble (0, obj_name, OBJPROP_PRICE1, level_start);
       ObjectSetInteger(0, obj_name, OBJPROP_TIME2, t2);
       ObjectSetDouble (0, obj_name, OBJPROP_PRICE2, level_end);
       ObjectSetInteger(0, obj_name, OBJPROP_COLOR, zone_colors[k]);
   }
}

//+------------------------------------------------------------------+
//| CheckSignalInvalidation_Pro
//| 功能：v3 主动风控计算引擎
//| 返回：0=正常, 1=假突破(P1回归), 2=时间衰竭(僵尸单)
//+------------------------------------------------------------------+
int CheckSignalInvalidation_Pro(
      string sym,             // 品种
      int period,             // 周期
      int op_type,            // 订单类型 (OP_BUY / OP_SELL)
      double open_price,      // 开仓价格 (近似视为 P1 突破价)
      datetime open_time,     // 开仓时间
      double current_profit_pts, // 当前盈利点数
      // --- 策略参数 ---
      int buffer_mode,        // 0=固定点数, 1=ATR动态
      double tolerance,       // 容忍阈值
      int confirm_bars,       // 确认K线数 (连续 N 根破位才算死)
      int max_time_bars,      // 时间止损阈值
      double time_profit_filter // 时间止损的利润保护线
      )
{
   // 1. 获取基础数据
   // 我们检测刚刚收盘的 K 线 (Shift 1) 以及当前的 ATR
   double close_1 = iClose(sym, period, 1); 
   
   // ==============================================================
   // A. P1 假突破检测 (Fakeout / P1 Rejection)
   // ==============================================================
   
   // A.1 计算“护城河”宽度 (容忍距离)
   double buffer_dist = 0;
   if (buffer_mode == 0) 
   {
       // 模式0: 固定点数 (例如 50 点)
       buffer_dist = tolerance * Point; // 注意：如果 input 是 50，这里需要确认 Point 转换
       // *修正：通常 input 0.5 代表点数太小，如果是 ATR 倍数 0.5 正常。
       // 假设 tolerance 在 input 里填的是 ATR 倍数 (如 0.5) 或 点数 (如 50)
       // 建议统一逻辑：如果 buffer_mode=0，tolerance 代表 Points
   }
   else 
   {
       // 模式1: ATR 动态倍数 (例如 0.5 倍 ATR)
       double atr = iATR(sym, period, 14, 1);
       buffer_dist = tolerance * atr;
   }
   
   // A.2 破位判断逻辑
   bool is_broken = false;
   
   // 确认机制：如果 confirm_bars > 1，我们需要回溯检查
   // 例如：要求连续 2 根 K 线都收在 P1 里面才算假突破
   int broken_count = 0;
   
   for (int k = 1; k <= confirm_bars; k++)
   {
       double check_close = iClose(sym, period, k);
       bool bar_broken = false;
       
       if (op_type == OP_BUY)
       {
           // 做多：如果收盘价 < (开仓价 - 护城河)
           // 意味着价格不仅跌回了开仓价，还跌穿了容忍区
           if (check_close < (open_price - buffer_dist)) bar_broken = true;
       }
       else
       {
           // 做空：如果收盘价 > (开仓价 + 护城河)
           if (check_close > (open_price + buffer_dist)) bar_broken = true;
       }
       
       if (bar_broken) broken_count++;
   }
   
   // 只有当连续 N 根都破位，才判死刑
   if (broken_count >= confirm_bars) return 1; // 错误代码 1: P1 假突破

   // ==============================================================
   // B. 时间衰竭检测 (Time Decay / Zombie Trade)
   // ==============================================================
   
   // 计算持仓经过了多少根 K 线
   // iBarShift 返回从 open_time 到现在的 K 线数量
   int bars_held = iBarShift(sym, period, open_time);
   
   // 如果持仓时间超过了耐心极限
   if (bars_held > max_time_bars)
   {
       // 并不是所有超时的单子都要平，如果已经赚了不少，就让利润奔跑
       // 只有那些“要死不活”、利润微薄甚至亏损的单子才杀掉
       if (current_profit_pts < time_profit_filter) 
       {
           return 2; // 错误代码 2: 时间衰竭
       }
   }

   return 0; // 信号健康，继续持有
}