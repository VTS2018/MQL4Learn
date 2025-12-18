//+------------------------------------------------------------------+
//|                                                   K_Logic_v3.mqh |
//|                         Core Logic for KTarget Finder & Bot v3.0 |
//|                                  Senior EA Architect Integration |
//+------------------------------------------------------------------+

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
   int n_geo = MathAbs(anchor_idx - breakout_idx);
   
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