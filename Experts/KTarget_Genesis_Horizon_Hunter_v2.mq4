//+------------------------------------------------------------------+
//|                           KTarget_Genesis_Horizon_Hunter.mq4    |
//|                                Copyright 2026, KT Expert.        |
//|                                   https://www.mql5.com           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, KT Expert."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property description "半自动关键位反向交易EA"
#property description "扫描图表上的水平线/射线，在关键位置执行反向交易"
#property description "配合 KT_Drawing_Tool_V2 使用"

//+------------------------------------------------------------------+
//| 枚举定义
//+------------------------------------------------------------------+
enum ENUM_TP_MODE
{
   TP_MODE_PROFIT_AMOUNT,    // 账户盈利金额模式 (Account Profit Amount)
   TP_MODE_PRICE_DISTANCE    // 固定价格距离模式 (Fixed Price Distance)
};

//+------------------------------------------------------------------+
//| 输入参数
//+------------------------------------------------------------------+

//--- 资金管理参数
input double   InpFixedLots      = 0.01;     // 固定手数 (Fixed Lots)
input double   InpAccountSize    = 100;   // 账户基准资金 (Account Base Size)
input bool     InpUseMoneyMgmt   = false;   // 启用资金管理 (Use Money Management)

//--- 交易参数
input double   InpATRMultiplier  = 1.5;     // 止损ATR倍数 (SL ATR Multiplier)
input int      InpATRPeriod      = 14;      // ATR周期 (ATR Period)
//input int      InpPriceBuffer    = 1000;       // 价格触发缓冲点数 (Price Buffer in Points)

//--- 止盈设置
input string   __TakeProfit__ = "=== Take Profit Settings ===";
input ENUM_TP_MODE InpTPMode = TP_MODE_PRICE_DISTANCE;  // 止盈计算模式 (TP Calculation Mode)

input string   __Mode1__ = "--- Mode 1: Account Profit Amount ---";
input double   InpTargetProfit   = 2.0;     // 目标账户盈利 (Target Account Profit in $)

input string   __Mode2__ = "--- Mode 2: Fixed Price Distance ---";
input double   InpPriceDistance  = 2.0;     // 止盈价格距离 (TP Price Distance in $)

//--- 追踪减仓参数
input bool     InpEnableTrailing = true;    // 启用追踪减仓 (Enable Trailing)
input double   InpTrailStart     = 1.0;     // 追踪启动距离 (Trail Start Distance in $)
input double   InpTrailStep      = 0.5;     // 追踪步进距离 (Trail Step Distance in $)

//--- 过滤参数
input bool     InpOnlyCurrentTF  = false;   // 仅当前周期线条 (Only Current Timeframe)
input int      InpCooldownSeconds = 3600;     // 冷却时间(秒) (Cooldown Seconds)
input bool     InpCheckHistory   = false;   // 检查历史订单 (Check History Orders)
input int      InpMagicNumber    = 88888;   // EA魔术编号 (Magic Number)
input string   InpTradeComment   = "KT_GHH"; // 交易注释 (Trade Comment)

//--- 方向锁定模式
input bool     InpUseLockDirection = false;  // 启用方向锁定模式 (Use Direction Lock Mode)

//--- 可视化参数
input bool     InpShowKeyLevelInfo = true;   // 显示关键位信息 (Show KeyLevel Info)
input int      InpLabelUpdateSeconds = 3;    // 标签更新间隔秒数 (Label Update Interval)
input color    InpLabelColor = clrDodgerBlue; // 标签颜色 (Label Color)

//--- 全局变量
struct KeyLevel
{
   string   objectName;     // 对象名称
   double   price;          // 价格
   int      timeframe;      // 周期
   bool     isHLine;        // 是否水平线（false=射线）
   datetime lastCheckTime;  // 【时间】最后检查时间
   int      tradeCount;     // 【次数】该位置的交易次数
   int      lastTradeDirection; // 【方向】最后交易方向: 0=未交易, 1=从上触达(买入), -1=从下触达(卖出)
   int      lastPricePosition;  // 【位置】上次价格位置: -1=下方, 0=区域内, 1=上方
   int      lockedDirection;    // 【锁定】锁定的交易方向: 0=未锁定, 1=锁定BUY, -1=锁定SELL
};

KeyLevel g_keyLevels[];     // 存储所有关键位
datetime g_lastScanTime;    // 最后扫描时间
datetime g_lastLabelUpdateTime = 0;  // 最后标签更新时间

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 初始化全局变量
   ArrayResize(g_keyLevels, 0);
   g_lastScanTime = 0;
   
   // 扫描图表上的关键位
   ScanKeyLevels();
   
   Print("=== KTarget Genesis Horizon Hunter 启动 ===");
   Print("扫描到 ", ArraySize(g_keyLevels), " 个关键位置");
   Print("方向锁定模式: ", (InpUseLockDirection ? "已启用" : "未启用"));
   Print("固定手数: ", InpFixedLots);
   Print("止盈模式: ", (InpTPMode == TP_MODE_PRICE_DISTANCE ? "固定价格距离" : "账户盈利金额"));
   if(InpTPMode == TP_MODE_PRICE_DISTANCE)
      Print("止盈距离: $", InpPriceDistance);
   else
      Print("目标盈利: $", InpTargetProfit);
   Print("ATR倍数: ", InpATRMultiplier);
   DetectbasicInfo();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== KTarget Genesis Horizon Hunter 停止 ===");
   // 清理显示对象
   CleanupDisplayObjects();
   CleanupKeyLevelLabels();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 每10秒重新扫描一次关键位（防止新画的线）
   if(TimeCurrent() - g_lastScanTime > 10)
   {
      ScanKeyLevels();
      g_lastScanTime = TimeCurrent();
   }
   
   // 检查所有关键位是否触达
   CheckKeyLevelHits();
   
   // 管理现有订单
   ManageOpenTrades();
   
   // 更新界面显示
   UpdateDisplay();
   
   // 更新关键位标签（节流更新）
   if(InpShowKeyLevelInfo && TimeCurrent() - g_lastLabelUpdateTime >= InpLabelUpdateSeconds)
   {
      UpdateAllKeyLevelLabels();
      g_lastLabelUpdateTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| 扫描图表上的关键位（水平线和射线）
//+------------------------------------------------------------------+
void ScanKeyLevels()
{
   // 保存旧状态（防止重新扫描时丢失 lastCheckTime、tradeCount 和 lastTradeDirection）
   KeyLevel oldLevels[];
   int oldSize = ArraySize(g_keyLevels);
   ArrayResize(oldLevels, oldSize);
   for(int i = 0; i < oldSize; i++)
   {
      oldLevels[i].objectName = g_keyLevels[i].objectName;
      oldLevels[i].lastCheckTime = g_keyLevels[i].lastCheckTime;
      oldLevels[i].tradeCount = g_keyLevels[i].tradeCount;
      oldLevels[i].lastTradeDirection = g_keyLevels[i].lastTradeDirection;
      oldLevels[i].lastPricePosition = g_keyLevels[i].lastPricePosition;
      oldLevels[i].lockedDirection = g_keyLevels[i].lockedDirection;  // 恢复锁定方向
   }
   
   // 清空并重新扫描
   ArrayResize(g_keyLevels, 0);
   int total = ObjectsTotal(0, 0, -1);
   
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, -1);
      
      // 检查是否是 Draw_ 开头的对象（来自 KT_Drawing_Tool）
      if(StringFind(objName, "Draw_") == 0)
      {
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         // 处理水平线
         if(objType == OBJ_HLINE)
         {
            double price = ObjectGetDouble(0, objName, OBJPROP_PRICE);
            AddKeyLevel(objName, price, 0, true);
         }
         // 处理射线
         else if(objType == OBJ_TREND)
         {
            double price = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
            
            // 从名称中提取周期信息
            string parts[];
            int count = StringSplit(objName, '_', parts);
            int tf = 0;
            if(count >= 2)
            {
               tf = GetTimeframeFromString(parts[1]);
            }
            
            AddKeyLevel(objName, price, tf, false);
         }
      }
   }
   
   // 恢复旧状态（根据对象名称匹配）
   for(int i = 0; i < ArraySize(g_keyLevels); i++)
   {
      bool foundOld = false;
      for(int j = 0; j < oldSize; j++)
      {
         if(g_keyLevels[i].objectName == oldLevels[j].objectName)
         {
            // 恢复该关键位的历史记录
            g_keyLevels[i].lastCheckTime = oldLevels[j].lastCheckTime;
            g_keyLevels[i].tradeCount = oldLevels[j].tradeCount;
            g_keyLevels[i].lastTradeDirection = oldLevels[j].lastTradeDirection;
            g_keyLevels[i].lastPricePosition = oldLevels[j].lastPricePosition;
            g_keyLevels[i].lockedDirection = oldLevels[j].lockedDirection;  // 恢复锁定方向
            foundOld = true;
            break;
         }
      }
      
      // 如果是新关键位且启用了锁定模式，进行首次锁定
      if(!foundOld && InpUseLockDirection)
      {
         double currentBid = Bid;
         double levelPrice = g_keyLevels[i].price;
         
         if(currentBid < levelPrice)
         {
            // 现价在关键位下方 → 关键位是阻力位 → 锁定为SELL
            g_keyLevels[i].lockedDirection = -1;
            Print("【首次锁定】", g_keyLevels[i].objectName, " 价格:", levelPrice, 
                  " 现价:", currentBid, " → 锁定为SELL(阻力位)");
         }
         else if(currentBid > levelPrice)
         {
            // 现价在关键位上方 → 关键位是支撑位 → 锁定为BUY
            g_keyLevels[i].lockedDirection = 1;
            Print("【首次锁定】", g_keyLevels[i].objectName, " 价格:", levelPrice, 
                  " 现价:", currentBid, " → 锁定为BUY(支撑位)");
         }
         else
         {
            // 现价正好在关键位区域内，暂不锁定
            g_keyLevels[i].lockedDirection = 0;
            Print("【首次扫描】", g_keyLevels[i].objectName, " 价格:", levelPrice, 
                  " 现价:", currentBid, " → 在区域内，等待离开后锁定");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 添加关键位到数组
//+------------------------------------------------------------------+
void AddKeyLevel(string objName, double price, int tf, bool isHLine)
{
   // 过滤：仅当前周期
   if(InpOnlyCurrentTF && tf != 0 && tf != Period())
      return;
   
   int size = ArraySize(g_keyLevels);
   ArrayResize(g_keyLevels, size + 1);
   
   g_keyLevels[size].objectName = objName;
   g_keyLevels[size].price = price;
   g_keyLevels[size].timeframe = tf;
   g_keyLevels[size].isHLine = isHLine;
   g_keyLevels[size].lastCheckTime = 0;
   g_keyLevels[size].tradeCount = 0;
   g_keyLevels[size].lastTradeDirection = 0;  // 初始化为未交易
   g_keyLevels[size].lockedDirection = 0;     // 初始化为未锁定，等待ScanKeyLevels中处理
   
   // 初始化价格位置状态（关键修复：扫描时就确定当前位置）
   double currentBid = Bid;
   double spread = Ask - currentBid;
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double minBuffer = 3 * tickSize;
   double bufferPrice = MathMax(spread * 0.5, minBuffer);
   g_keyLevels[size].lastPricePosition = GetPricePosition(currentBid, price, bufferPrice);
}

//+------------------------------------------------------------------+
//| 从字符串获取周期
//+------------------------------------------------------------------+
int GetTimeframeFromString(string tfStr)
{
   if(tfStr == "M1")  return PERIOD_M1;
   if(tfStr == "M5")  return PERIOD_M5;
   if(tfStr == "M15") return PERIOD_M15;
   if(tfStr == "M30") return PERIOD_M30;
   if(tfStr == "H1")  return PERIOD_H1;
   if(tfStr == "H4")  return PERIOD_H4;
   if(tfStr == "D1")  return PERIOD_D1;
   if(tfStr == "W1")  return PERIOD_W1;
   if(tfStr == "MN")  return PERIOD_MN1;
   return 0;
}

//+------------------------------------------------------------------+
//| 判断价格相对关键位的位置
//+------------------------------------------------------------------+
int GetPricePosition(double bidPrice, double levelPrice, double buffer)
{
   if(bidPrice > levelPrice + buffer)
      return 1;   // 在关键位上方
   else if(bidPrice < levelPrice - buffer)
      return -1;  // 在关键位下方
   else
      return 0;   // 在关键位区域内
}

//+------------------------------------------------------------------+
//| 检查关键位是否被触达
//+------------------------------------------------------------------+
void CheckKeyLevelHits()
{
   double currentAsk = Ask;
   double currentBid = Bid;
   
   // 基于点差计算缓冲区（适用不同品种），添加最小缓冲保护
   double spread = currentAsk - currentBid;
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double minBuffer = 3 * tickSize;  // 最小缓冲：3个tick，防止点差为0时失效
   double bufferPrice = MathMax(spread * 0.5, minBuffer);
   
   for(int i = 0; i < ArraySize(g_keyLevels); i++)
   {
      double levelPrice = g_keyLevels[i].price;
      
      // 获取当前价格位置
      int currentPosition = GetPricePosition(currentBid, levelPrice, bufferPrice);
      int lastPosition = g_keyLevels[i].lastPricePosition;
      
      // 检查是否刚进入关键位区域（状态转换：非区域 → 区域内）
      bool justEntered = (lastPosition != 0 && currentPosition == 0);
      
      if(justEntered)
      {
         // 根据上次位置判断触达方向
         bool hitFromAbove = (lastPosition == 1);   // 从上方触达
         bool hitFromBelow = (lastPosition == -1);  // 从下方触达
         
         // 1. 防止同一位置短时间内重复开单（冷却期）
         if(TimeCurrent() - g_keyLevels[i].lastCheckTime < InpCooldownSeconds)
         {
            continue;  // 冷却期内不更新状态，保持原方向
         }
         
         // 2. 方向检查：防止同方向重复开单
         int currentDirection = hitFromAbove ? 1 : -1;  // 1=从上触达, -1=从下触达
         if(g_keyLevels[i].lastTradeDirection == currentDirection)
         {
            continue;  // 同方向已交易过，跳过（不更新状态）
         }
         
         // 3. 检查该位置是否已有持仓（动态容差）
         if(HasPositionAtLevel(levelPrice, spread))
         {
            continue;  // 已有持仓，跳过（不更新状态）
         }
         
         // 3.5. 检查历史订单（可选，防止EA重启后重复开仓）
         if(InpCheckHistory && HasTradedAtLevel(levelPrice, spread, g_keyLevels[i].objectName))
         {
            continue;  // 历史已交易，跳过（不更新状态）
         }
         
         // 4. 执行反向交易
         bool isHitFromAbove = hitFromAbove;
         ExecuteReverseTrade(g_keyLevels[i], isHitFromAbove);
         
         // 5. 更新状态（关键：交易后不更新lastPricePosition，保持触达前的方向）
         g_keyLevels[i].lastCheckTime = TimeCurrent();
         g_keyLevels[i].tradeCount++;
         g_keyLevels[i].lastTradeDirection = currentDirection;  // 记录交易方向
         // 不更新 lastPricePosition，保持触达前的位置（-1或1）
      }
      
      // 关键修复：只在价格明确离开区域时更新位置，避免快速穿越污染和状态丢失
      if(currentPosition != 0)
      {
         g_keyLevels[i].lastPricePosition = currentPosition;
      }
   }
}

//+------------------------------------------------------------------+
//| 检查某个价格位置是否已有持仓
//+------------------------------------------------------------------+
bool HasPositionAtLevel(double price, double spread)
{
   // 动态容差：至少是点差的1.5倍，确保不同品种都能正确检测
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tolerance = MathMax(spread * 1.5, 10 * tickSize);
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      
      double openPrice = OrderOpenPrice();
      if(MathAbs(openPrice - price) < tolerance)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 检查某个价格位置是否在历史订单中交易过
//+------------------------------------------------------------------+
bool HasTradedAtLevel(double price, double spread, string objectName)
{
   // 动态容差：至少是点差的1.5倍，确保不同品种都能正确检测
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tolerance = MathMax(spread * 1.5, 10 * tickSize);
   
   // 遍历历史订单
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      
      // 检查价格是否在容差范围内
      double openPrice = OrderOpenPrice();
      if(MathAbs(openPrice - price) < tolerance)
      {
         // 进一步检查订单注释是否包含该对象名称（更精确的匹配）
         string comment = OrderComment();
         if(StringFind(comment, objectName) >= 0)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 执行反向交易
//+------------------------------------------------------------------+
void ExecuteReverseTrade(KeyLevel &level, bool hitFromAbove)
{
   // 先只打印，不实际下单
   // Print("【触发信号】", level.objectName, 
   //       " 价格:", level.price, 
   //       " 方向:", (hitFromAbove ? "从上方触达" : "从下方触达"));
   // return; // 暂时不执行下单

   // 确定交易方向
   int orderType;
   
   if(InpUseLockDirection && level.lockedDirection != 0)
   {
      // 方向锁定模式：使用锁定的方向
      orderType = (level.lockedDirection == 1) ? OP_BUY : OP_SELL;
      Print("【使用锁定方向】", level.objectName, " 锁定方向:", 
            (level.lockedDirection == 1 ? "BUY" : "SELL"), 
            " 触达方向:", (hitFromAbove ? "从上" : "从下"));
   }
   else
   {
      // 原有逻辑：反向交易
      orderType = hitFromAbove ? OP_BUY : OP_SELL;
   }
   
   double entryPrice = (orderType == OP_BUY) ? Ask : Bid;
   
   // 计算止损
   double stopLoss = CalculateStopLoss(orderType, level.timeframe);
   
   // 计算手数
   double lots = CalculateLotSize();
   
   // 计算止盈（基于目标盈利金额）
   double takeProfit = CalculateTakeProfit(orderType, entryPrice, lots);

   // 详细日志输出
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   
   // 计算预期盈利（根据模式）
   double expectedProfit = 0;
   if(InpTPMode == TP_MODE_PRICE_DISTANCE)
   {
      double tpDistance = MathAbs(takeProfit - entryPrice);
      expectedProfit = tpDistance / tickSize * tickValue * lots;
   }
   else
   {
      expectedProfit = InpTargetProfit;
   }
   
   Print("【触发信号】", level.objectName, 
         " 价格:", level.price, 
         " 方向:", (hitFromAbove ? "从上方触达→买入" : "从下方触达→卖出"));
   Print("  入场:", entryPrice, 
         " 止损:", stopLoss, 
         " 止盈:", takeProfit);
   Print("  止损距离:", DoubleToString(MathAbs(entryPrice - stopLoss) / tickSize, 0), " 点",
         " 止盈距离:", DoubleToString(MathAbs(takeProfit - entryPrice) / tickSize, 0), " 点");
   Print("  手数:", lots, 
         " 预期盈利: $", DoubleToString(expectedProfit, 2),
         " 预期亏损: $", DoubleToString(CalculatePotentialLoss(lots, entryPrice, stopLoss), 2));
   
   // return; // 暂时不执行下单

   // 构建订单注释
   string comment = InpTradeComment + "_" + level.objectName;
   
   // 发送订单
   int ticket = OrderSend(
      Symbol(),
      orderType,
      lots,
      entryPrice,
      3,
      stopLoss,
      takeProfit,
      comment,
      InpMagicNumber,
      0,
      (orderType == OP_BUY) ? clrBlue : clrRed
   );
   
   if(ticket > 0)
   {
      Print("【成功开仓】订单:", ticket, 
            " 类型:", (orderType == OP_BUY ? "买入" : "卖出"),
            " 价格:", entryPrice,
            " 手数:", lots,
            " 止损:", stopLoss,
            " 止盈:", takeProfit,
            " 关键位:", level.objectName);
      
      PlaySound("alert.wav");
   }
   else
   {
      int error = GetLastError();
      Print("【开仓失败】错误代码:", error, " 描述:", ErrorDescription(error));
   }
}

//+------------------------------------------------------------------+
//| 计算止损价格
//+------------------------------------------------------------------+
double CalculateStopLoss(int orderType, int timeframe)
{
   // 使用指定周期或当前周期
   int tf = (timeframe > 0) ? timeframe : Period();
   
   // 获取ATR值
   double atr = iATR(Symbol(), tf, InpATRPeriod, 0);
   
   // 计算止损距离
   double slDistance = atr * InpATRMultiplier;
   
   // 计算止损价格
   double sl = 0;
   if(orderType == OP_BUY)
   {
      sl = Bid - slDistance;
   }
   else if(orderType == OP_SELL)
   {
      sl = Ask + slDistance;
   }
   
   // 标准化价格
   return NormalizeDouble(sl, Digits);
}

//+------------------------------------------------------------------+
//| 计算止盈价格
//+------------------------------------------------------------------+
double CalculateTakeProfit(int orderType, double entryPrice, double lots)
{
   double tp = 0;
   double priceDistance = 0;
   
   // 获取市场信息（用于调试）
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double contractSize = MarketInfo(Symbol(), MODE_LOTSIZE);
   
   // 根据模式计算止盈
   if(InpTPMode == TP_MODE_PRICE_DISTANCE)
   {
      // 模式2：固定价格距离
      priceDistance = InpPriceDistance;
      
      if(orderType == OP_BUY)
         tp = entryPrice + InpPriceDistance;
      else if(orderType == OP_SELL)
         tp = entryPrice - InpPriceDistance;
   }
   else
   {
      // 模式1：账户盈利金额
      if(tickValue <= 0) tickValue = 1.0;  // 容错处理
      
      double pointsNeeded = InpTargetProfit / (tickValue * lots);
      priceDistance = pointsNeeded * tickSize;
      
      if(orderType == OP_BUY)
         tp = entryPrice + (pointsNeeded * tickSize);
      else if(orderType == OP_SELL)
         tp = entryPrice - (pointsNeeded * tickSize);
   }
   /*
   // 调试输出
   Print("=== 止盈计算详情 ===");
   Print("  品种: ", Symbol(), " | 账户货币: ", AccountCurrency());
   Print("  止盈模式: ", (InpTPMode == TP_MODE_PRICE_DISTANCE ? "固定价格距离" : "账户盈利金额"));
   Print("  Point: ", Point, " | Digits: ", Digits);
   Print("  MODE_TICKSIZE: ", tickSize, " | MODE_TICKVALUE: ", tickValue);
   Print("  MODE_LOTSIZE: ", contractSize);
   Print("  入场价: ", entryPrice, " | 手数: ", lots);
   
   if(InpTPMode == TP_MODE_PRICE_DISTANCE)
   {
      Print("  配置价格距离: $", InpPriceDistance);
      double expectedProfit = priceDistance / tickSize * tickValue * lots;
      Print("  预期账户盈利: $", expectedProfit);
   }
   else
   {
      Print("  目标账户盈利: $", InpTargetProfit);
      double pointsNeeded = InpTargetProfit / (tickValue * lots);
      Print("  计算点数: ", pointsNeeded, " 点");
   }
   
   Print("  止盈价格: ", tp);
   Print("  止盈距离: $", priceDistance, " (", priceDistance/tickSize, " 点)");
   Print("========================");
   */
   return NormalizeDouble(tp, Digits);
}

//+------------------------------------------------------------------+
//| 计算手数
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lots = InpFixedLots;
   
   if(InpUseMoneyMgmt)
   {
      // 根据账户比例计算手数
      double accountBalance = AccountBalance();
      double ratio = accountBalance / InpAccountSize;
      lots = InpFixedLots * ratio;
   }
   
   // 标准化手数
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = NormalizeDouble(lots / lotStep, 0) * lotStep;
   
   return lots;
}

//+------------------------------------------------------------------+
//| 管理现有订单（追踪减仓等）
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
   if(!InpEnableTrailing)
      return;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      
      // 计算价格距离（浮动盈利距离）
      double entryPrice = OrderOpenPrice();
      double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
      double priceDistance = 0;
      
      if(OrderType() == OP_BUY)
         priceDistance = currentPrice - entryPrice;  // 买单：当前价 - 入场价
      else if(OrderType() == OP_SELL)
         priceDistance = entryPrice - currentPrice;  // 卖单：入场价 - 当前价
      
      // 检查是否达到追踪启动条件（价格移动距离）
      if(priceDistance >= InpTrailStart)
      {
         TrailStop(OrderTicket(), priceDistance);
      }
   }
}

//+------------------------------------------------------------------+
//| 追踪止损（纯价格距离模式）
//+------------------------------------------------------------------+
void TrailStop(int ticket, double priceDistance)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;
   
   double newSL = 0;
   double currentSL = OrderStopLoss();
   
   if(OrderType() == OP_BUY)
   {
      // 买单：止损向上追踪，保持InpTrailStep的价格距离
      double trailPrice = Bid - InpTrailStep;
      
      // 只有当新止损高于当前止损时才修改（向上追踪）
      if(trailPrice > currentSL || currentSL == 0)
      {
         newSL = NormalizeDouble(trailPrice, Digits);
         
         if(OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrBlue))
         {
            Print("【追踪止损】订单:", ticket, 
                  " 新止损:", newSL,
                  " 价格距离:", DoubleToString(priceDistance, 2),
                  " 追踪距离:", DoubleToString(Bid - newSL, 2));
         }
      }
   }
   else if(OrderType() == OP_SELL)
   {
      // 卖单：止损向下追踪，保持InpTrailStep的价格距离
      double trailPrice = Ask + InpTrailStep;
      
      // 只有当新止损低于当前止损时才修改（向下追踪）
      if(trailPrice < currentSL || currentSL == 0)
      {
         newSL = NormalizeDouble(trailPrice, Digits);
         
         if(OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrRed))
         {
            Print("【追踪止损】订单:", ticket, 
                  " 新止损:", newSL,
                  " 价格距离:", DoubleToString(priceDistance, 2),
                  " 追踪距离:", DoubleToString(newSL - Ask, 2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 更新界面显示（使用OBJ_LABEL替代Comment避免冲突）
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   // 使用OBJ_LABEL对象显示信息，避免与指标的Comment()冲突
   string prefix = "EA_Display_";
   int x = 150;        // 右边距（从右边缘向左的像素距离）
   int y_start = 140;  // 起始Y坐标（修改此值可调整距离顶部的位置，数值越大越靠下）
   int y_gap = 18;    // 行间距
   color text_color = clrBlack;  // 字体颜色：黑色
   int font_size = 9;
   string font_name = "Consolas";
   
   // 标题
   CreateLabel(prefix + "Title", x, y_start, "=== KT GHH EA ===", text_color, font_size + 1, font_name);
   
   // 信息行
   int y = y_start + y_gap + 5;
   CreateLabel(prefix + "KeyLevels", x, y, "关键位: " + IntegerToString(ArraySize(g_keyLevels)), text_color, font_size, font_name);
   
   y += y_gap;
   CreateLabel(prefix + "Orders", x, y, "持仓: " + IntegerToString(CountMyOrders()), text_color, font_size, font_name);
   
   y += y_gap;
   double profit = GetTotalProfit();
   color profit_color = (profit >= 0) ? clrDarkBlue : clrRed;
   CreateLabel(prefix + "Profit", x, y, "盈亏: " + DoubleToString(profit, 2) + " " + AccountCurrency(), profit_color, font_size, font_name);
   
   y += y_gap;
   CreateLabel(prefix + "Balance", x, y, "余额: " + DoubleToString(AccountBalance(), 2) + " " + AccountCurrency(), text_color, font_size, font_name);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 创建或更新Label对象
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int size, string font)
{
   if(ObjectFind(0, name) < 0)
   {
      // 创建新对象
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);  // 右上角锚点
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   }
   else
   {
      // 更新现有对象
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}

//+------------------------------------------------------------------+
//| 清理显示对象
//+------------------------------------------------------------------+
void CleanupDisplayObjects()
{
   string prefix = "EA_Display_";
   int total = ObjectsTotal(0, 0, OBJ_LABEL);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_LABEL);
      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 统计当前EA的订单数
//+------------------------------------------------------------------+
int CountMyOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| 计算总盈亏
//+------------------------------------------------------------------+
double GetTotalProfit()
{
   double total = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber)
      {
         total += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   return total;
}

//+------------------------------------------------------------------+
//| 错误描述
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
   switch(errorCode)
   {
      case 0:   return "无错误";
      case 1:   return "无错误，但结果未知";
      case 2:   return "一般错误";
      case 3:   return "无效参数";
      case 4:   return "交易服务器繁忙";
      case 129: return "无效价格";
      case 130: return "无效止损";
      case 131: return "无效手数";
      case 134: return "资金不足";
      case 136: return "无报价";
      case 138: return "新价格";
      default:  return "错误代码: " + IntegerToString(errorCode);
   }
}

//+------------------------------------------------------------------+
// 辅助函数
double CalculatePotentialLoss(double lots, double entry, double sl)
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double points = MathAbs(entry - sl) / tickSize;
   return points * tickValue * lots;
}

//+------------------------------------------------------------------+
void DetectbasicInfo()
{
   // 在计算止盈后添加：
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double contractSize = MarketInfo(Symbol(), MODE_LOTSIZE);
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);

   Print("=== 探测品种的基本信息 ===");
   Print("=== ", Symbol(), " 市场信息 ===");
   Print("  Point: ", Point);
   Print("  Point: ", Point, " | Digits: ", Digits);
   Print("  MODE_TICKSIZE: ", tickSize);
   Print("  MODE_TICKVALUE: ", tickValue);
   Print("  MODE_LOTSIZE: ", contractSize);
   Print("  MODE_MINLOT: ", minLot);
   Print("  账户货币: ", AccountCurrency());
   Print("========================");
}

//+------------------------------------------------------------------+
//| 更新所有关键位标签
//+------------------------------------------------------------------+
void UpdateAllKeyLevelLabels()
{
   for(int i = 0; i < ArraySize(g_keyLevels); i++)
   {
      // 检查画线是否仍然存在
      if(ObjectFind(0, g_keyLevels[i].objectName) < 0)
      {
         // 画线已被删除，清理对应的标签
         string labelName = "EA_KeyLevel_Info_" + g_keyLevels[i].objectName;
         if(ObjectFind(0, labelName) >= 0)
         {
            ObjectDelete(0, labelName);
         }
         continue;
      }
      
      UpdateKeyLevelLabel(g_keyLevels[i]);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 更新单个关键位标签
//+------------------------------------------------------------------+
void UpdateKeyLevelLabel(KeyLevel &level)
{
   double currentBid = Bid;
   double levelPrice = level.price;
   
   // 判断画线相对现价的位置
   bool lineAbovePrice = (levelPrice > currentBid);
   
   // 计算显示位置
   int firstBar = WindowFirstVisibleBar();
   int barOffset = (int)(firstBar * 0.15);  // 屏幕左侧15%位置
   if(barOffset < 5) barOffset = 5;
   if(barOffset > firstBar - 5) barOffset = firstBar - 5;
   
   datetime timePos = Time[barOffset];
   double priceOffset = 0.5;  // 距离画线的偏移量（美元）
   
   double textPrice;
   if(lineAbovePrice)
      textPrice = levelPrice - priceOffset;  // 画线下方
   else
      textPrice = levelPrice + priceOffset;  // 画线上方
   
   // 创建或更新文本对象
   string labelName = "EA_KeyLevel_Info_" + level.objectName;
   string displayText = FormatKeyLevelInfo(level);
   
   if(ObjectFind(0, labelName) < 0)
   {
      // 创建新对象
      ObjectCreate(0, labelName, OBJ_TEXT, 0, timePos, textPrice);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, InpLabelColor);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   
   // 更新内容和位置
   ObjectSetString(0, labelName, OBJPROP_TEXT, displayText);
   ObjectMove(0, labelName, 0, timePos, textPrice);
   
   // 根据交易状态调整颜色
   color labelColor = InpLabelColor;
   if(level.tradeCount > 0)
   {
      // 已交易过的关键位用不同颜色
      if(MathAbs(currentBid - levelPrice) > 5.0)
         labelColor = clrGray;  // 远离的淡化
      else
         labelColor = clrMediumBlue;  // 靠近的高亮
   }
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
}

//+------------------------------------------------------------------+
//| 格式化关键位信息
//+------------------------------------------------------------------+
string FormatKeyLevelInfo(KeyLevel &level)
{
   string info = "";
   
   // 0. 锁定状态（如果启用）
   if(InpUseLockDirection && level.lockedDirection != 0)
   {
      if(level.lockedDirection == 1)
         info += "[L↑] ";  // 锁定BUY
      else
         info += "[L↓] ";  // 锁定SELL
   }
   
   // 1. 交易次数
   info += "[" + IntegerToString(level.tradeCount) + "次] ";
   
   // 2. 交易方向
   if(level.lastTradeDirection == 1)
      info += "↓买 ";
   else if(level.lastTradeDirection == -1)
      info += "↑卖 ";
   else
      info += "- ";
   
   // 3. 价格位置
   info += "| 位:";
   if(level.lastPricePosition == 1)
      info += "上 ";
   else if(level.lastPricePosition == -1)
      info += "下 ";
   else
      info += "中 ";
   
   // 4. 时间差
   if(level.lastCheckTime > 0)
   {
      int secondsAgo = (int)(TimeCurrent() - level.lastCheckTime);
      if(secondsAgo < 60)
         info += "| " + IntegerToString(secondsAgo) + "s前";
      else if(secondsAgo < 3600)
         info += "| " + IntegerToString(secondsAgo/60) + "m前";
      else if(secondsAgo < 86400)
         info += "| " + IntegerToString(secondsAgo/3600) + "h前";
      else
         info += "| " + IntegerToString(secondsAgo/86400) + "d前";
   }
   else
   {
      info += "| 未检测";
   }
   
   return info;
}

//+------------------------------------------------------------------+
//| 清理关键位标签
//+------------------------------------------------------------------+
void CleanupKeyLevelLabels()
{
   string prefix = "EA_KeyLevel_Info_";
   int total = ObjectsTotal(0, -1, -1);  // 获取主窗口所有类型的对象
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   ChartRedraw();
}