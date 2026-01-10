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
//| 输入参数
//+------------------------------------------------------------------+

//--- 资金管理参数
input double   InpFixedLots      = 0.5;     // 固定手数 (Fixed Lots)
input double   InpAccountSize    = 10000;   // 账户基准资金 (Account Base Size)
input bool     InpUseMoneyMgmt   = false;   // 启用资金管理 (Use Money Management)

//--- 交易参数
input double   InpTargetProfit   = 2.0;     // 目标盈利金额 (Target Profit in $)
input double   InpATRMultiplier  = 1.5;     // 止损ATR倍数 (SL ATR Multiplier)
input int      InpATRPeriod      = 14;      // ATR周期 (ATR Period)
input int      InpPriceBuffer    = 1000;       // 价格触发缓冲点数 (Price Buffer in Points)

//--- 追踪减仓参数
input bool     InpEnableTrailing = true;    // 启用追踪减仓 (Enable Trailing)
input double   InpTrailStart     = 1.0;     // 追踪启动盈利 (Trail Start in $)
input double   InpTrailStep      = 0.5;     // 追踪步进 (Trail Step in $)

//--- 过滤参数
input bool     InpOnlyCurrentTF  = false;   // 仅当前周期线条 (Only Current Timeframe)
input int      InpMagicNumber    = 88888;   // EA魔术编号 (Magic Number)
input string   InpTradeComment   = "KT_GHH"; // 交易注释 (Trade Comment)

//--- 全局变量
struct KeyLevel
{
   string   objectName;     // 对象名称
   double   price;          // 价格
   int      timeframe;      // 周期
   bool     isHLine;        // 是否水平线（false=射线）
   datetime lastCheckTime;  // 最后检查时间
   int      tradeCount;     // 该位置的交易次数
};

KeyLevel g_keyLevels[];     // 存储所有关键位
datetime g_lastScanTime;    // 最后扫描时间

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
   Print("固定手数: ", InpFixedLots);
   Print("目标盈利: $", InpTargetProfit);
   Print("ATR倍数: ", InpATRMultiplier);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== KTarget Genesis Horizon Hunter 停止 ===");
   Comment("");
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
}

//+------------------------------------------------------------------+
//| 扫描图表上的关键位（水平线和射线）
//+------------------------------------------------------------------+
void ScanKeyLevels()
{
   // 保存旧状态（防止重新扫描时丢失 lastCheckTime 和 tradeCount）
   KeyLevel oldLevels[];
   int oldSize = ArraySize(g_keyLevels);
   ArrayResize(oldLevels, oldSize);
   for(int i = 0; i < oldSize; i++)
   {
      oldLevels[i].objectName = g_keyLevels[i].objectName;
      oldLevels[i].lastCheckTime = g_keyLevels[i].lastCheckTime;
      oldLevels[i].tradeCount = g_keyLevels[i].tradeCount;
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
      for(int j = 0; j < oldSize; j++)
      {
         if(g_keyLevels[i].objectName == oldLevels[j].objectName)
         {
            // 恢复该关键位的历史记录
            g_keyLevels[i].lastCheckTime = oldLevels[j].lastCheckTime;
            g_keyLevels[i].tradeCount = oldLevels[j].tradeCount;
            break;
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
//| 检查关键位是否被触达
//+------------------------------------------------------------------+
void CheckKeyLevelHits()
{
   double currentAsk = Ask;
   double currentBid = Bid;
   
   // 基于点差计算缓冲区（适用不同品种）
   double spread = currentAsk - currentBid;
   double bufferPrice = spread * 0.5;  // 点差的一半
   
   for(int i = 0; i < ArraySize(g_keyLevels); i++)
   {
      double levelPrice = g_keyLevels[i].price;
      
      // 检查是否在触发区域内
      bool hitFromAbove = (currentBid <= levelPrice + bufferPrice) && 
                          (currentBid >= levelPrice - bufferPrice);
      bool hitFromBelow = (currentAsk >= levelPrice - bufferPrice) && 
                          (currentAsk <= levelPrice + bufferPrice);
      
      if(hitFromAbove || hitFromBelow)
      {
         // 防止同一位置短时间内重复开单
         if(TimeCurrent() - g_keyLevels[i].lastCheckTime < 60)
            continue;
         
         // 检查该位置是否已有持仓
         if(HasPositionAtLevel(levelPrice))
            continue;
         
         // 执行反向交易
         bool isHitFromAbove = hitFromAbove;
         ExecuteReverseTrade(g_keyLevels[i], isHitFromAbove);
         
         g_keyLevels[i].lastCheckTime = TimeCurrent();
         g_keyLevels[i].tradeCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| 检查某个价格位置是否已有持仓
//+------------------------------------------------------------------+
bool HasPositionAtLevel(double price)
{
   double tolerance = 10 * Point; // 10点容差
   
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
//| 执行反向交易
//+------------------------------------------------------------------+
void ExecuteReverseTrade(KeyLevel &level, bool hitFromAbove)
{
   // 先只打印，不实际下单
   Print("【触发信号】", level.objectName, 
         " 价格:", level.price, 
         " 方向:", (hitFromAbove ? "从上方触达" : "从下方触达"));
   // return; // 暂时不执行下单

   // 确定交易方向（反向）
   int orderType = hitFromAbove ? OP_BUY : OP_SELL;
   double entryPrice = (orderType == OP_BUY) ? Ask : Bid;
   
   // 计算止损
   double stopLoss = CalculateStopLoss(orderType, level.timeframe);
   
   // 计算手数
   double lots = CalculateLotSize();
   
   // 计算止盈（基于目标盈利金额）
   double takeProfit = CalculateTakeProfit(orderType, entryPrice, lots);

   // 详细日志输出
   Print("【触发信号】", level.objectName, 
         " 价格:", level.price, 
         " 方向:", (hitFromAbove ? "从上方触达→买入" : "从下方触达→卖出"));
   Print("  入场:", entryPrice, 
         " 止损:", stopLoss, 
         " 止盈:", takeProfit);
   Print("  止损距离:", MathAbs(entryPrice - stopLoss) / Point, " 点",
         " 止盈距离:", MathAbs(takeProfit - entryPrice) / Point, " 点");
   Print("  手数:", lots, 
         " 预期盈利: $", InpTargetProfit,
         " 预期亏损: $", CalculatePotentialLoss(lots, entryPrice, stopLoss));
   
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
   // 基于目标盈利金额计算点数
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(tickValue <= 0)
      tickValue = 1.0;
   
   double pointsNeeded = InpTargetProfit / (tickValue * lots);
   
   // 计算止盈价格
   double tp = 0;
   if(orderType == OP_BUY)
   {
      tp = entryPrice + (pointsNeeded * Point);
   }
   else if(orderType == OP_SELL)
   {
      tp = entryPrice - (pointsNeeded * Point);
   }
   
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
      
      // 计算当前盈利
      double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      
      // 检查是否达到追踪启动条件
      if(currentProfit >= InpTrailStart)
      {
         TrailStop(OrderTicket(), currentProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| 追踪止损
//+------------------------------------------------------------------+
void TrailStop(int ticket, double currentProfit)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;
   
   double newSL = 0;
   double currentSL = OrderStopLoss();
   
   if(OrderType() == OP_BUY)
   {
      // 买单：止损向上追踪
      double trailPrice = Bid - (InpTrailStep / MarketInfo(Symbol(), MODE_TICKVALUE) * Point);
      
      if(trailPrice > currentSL || currentSL == 0)
      {
         newSL = NormalizeDouble(trailPrice, Digits);
         
         if(OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrBlue))
         {
            Print("【追踪止损】订单:", ticket, " 新止损:", newSL);
         }
      }
   }
   else if(OrderType() == OP_SELL)
   {
      // 卖单：止损向下追踪
      double trailPrice = Ask + (InpTrailStep / MarketInfo(Symbol(), MODE_TICKVALUE) * Point);
      
      if(trailPrice < currentSL || currentSL == 0)
      {
         newSL = NormalizeDouble(trailPrice, Digits);
         
         if(OrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrRed))
         {
            Print("【追踪止损】订单:", ticket, " 新止损:", newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| 更新界面显示
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   string info = "";
   info += "=== KTarget Genesis Horizon Hunter ===\n";
   info += "扫描关键位: " + IntegerToString(ArraySize(g_keyLevels)) + "\n";
   info += "持仓订单: " + IntegerToString(CountMyOrders()) + "\n";
   info += "账户余额: " + DoubleToString(AccountBalance(), 2) + " " + AccountCurrency() + "\n";
   info += "当前盈亏: " + DoubleToString(GetTotalProfit(), 2) + " " + AccountCurrency() + "\n";
   
   Comment(info);
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
   double points = MathAbs(entry - sl) / Point;
   return points * tickValue * lots;
}