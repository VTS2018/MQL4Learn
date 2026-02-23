//+------------------------------------------------------------------+
//|                                          KTarget_Panel_EA.mq4    |
//|                                                                  |
//|                               带有可视化面板的EA交易程序          |
//+------------------------------------------------------------------+
#property copyright "KTarget"
#property link      ""
#property version   "1.00"
#property strict

#include <Controls/Dialog.mqh>
#include <Controls/Button.mqh>
#include <Controls/Edit.mqh>
#include <Controls/Label.mqh>

//+------------------------------------------------------------------+
//| 面板参数                                                          |
//+------------------------------------------------------------------+
input int    PanelX = 250;            // 面板X坐标
input int    PanelY = 20;            // 面板Y坐标
input color  PanelColor = clrWhite;  // 面板背景色
input color  BorderColor = clrNavy;  // 边框颜色

//+------------------------------------------------------------------+
//| 止损标签参数                                                      |
//+------------------------------------------------------------------+
input bool   Show_EA_SL_Labels = true;   // 显示EA止损标签
input int    SL_Distance_Dollars = 5;    // 止损距离（美金）
input double Label_Offset = 0.3;         // 标签偏移量（避免重叠）
input color  Buy_SL_Color = clrOrangeRed;   // 做多止损颜色
input color  Sell_SL_Color = clrLimeGreen; // 做空止损颜色

//+------------------------------------------------------------------+
//| 价格选择模式枚举                                                  |
//+------------------------------------------------------------------+
enum PriceSelectMode
{
   MODE_NONE = 0,         // 正常模式
   MODE_SELECT_SL = 1,    // 选择止损价格
   MODE_SELECT_TP = 2     // 选择止盈价格
};

//+------------------------------------------------------------------+
//| 全局状态变量                                                      |
//+------------------------------------------------------------------+
PriceSelectMode g_priceSelectMode = MODE_NONE;     // 价格选择模式
uint g_lastButtonClickTime = 0;                     // 上次按钮点击时间戳（防穿透）

//+------------------------------------------------------------------+
//| 今日订单记录面板                                                  |
//+------------------------------------------------------------------+
#define ORDERS_ROWS 100  // 绝对上限，今日订单实际不会超过此数

class COrdersPanel : public CAppDialog
{
private:
   CLabel           m_lblTitle;
   CLabel           m_lblHdr;
   CLabel           m_lblRows[ORDERS_ROWS];
   int              m_rowCount;   // 当前实际显示行数
   int              m_maxRows;    // 本次创建时预分配的行数（由外部按实际订单数设置）

public:
                    COrdersPanel() { m_rowCount = 0; m_maxRows = ORDERS_ROWS; }
                   ~COrdersPanel() {}

   void             SetMaxRows(int n) { m_maxRows = MathMin(MathMax(n, 1), ORDERS_ROWS); }
   virtual bool     Create(const long chart, const string name, const int subwin,
                           const int x1, const int y1, const int x2, const int y2);
   void             RefreshOrders(void);

protected:
   virtual bool     CreateControls(void);
};

//--- COrdersPanel 创建面板
bool COrdersPanel::Create(const long chart, const string name, const int subwin,
                           const int x1, const int y1, const int x2, const int y2)
{
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return(false);
   Caption("Daily Orders");
   if(!CreateControls())
      return(false);
   return(true);
}

//--- COrdersPanel 创建控件
bool COrdersPanel::CreateControls(void)
{
   int x = 5;
   int w = ClientAreaWidth() - 10;

   // 标题行
   if(!m_lblTitle.Create(m_chart_id, m_name+"OrdTitle", m_subwin, x, 3, x+w, 20))
      return(false);
   m_lblTitle.Text("-- 今日订单 --");
   if(!Add(m_lblTitle)) return(false);

   // 表头行
   if(!m_lblHdr.Create(m_chart_id, m_name+"OrdHdr", m_subwin, x, 23, x+w, 40))
      return(false);
   m_lblHdr.Font("Courier New");
   m_lblHdr.FontSize(8);
   m_lblHdr.Text(" 时间    T Lots Open     SL       Exit     P/L    Pips  Dur   ");
   if(!Add(m_lblHdr)) return(false);

   // 数据行：仅创建本次实际需要的行数（m_maxRows），每行 17px
   for(int i = 0; i < m_maxRows; i++)
   {
      if(!m_lblRows[i].Create(m_chart_id, m_name+"OrdRow"+IntegerToString(i),
                               m_subwin, x, 43+i*17, x+w, 60+i*17))
         return(false);
      m_lblRows[i].Font("Courier New");
      m_lblRows[i].FontSize(8);
      m_lblRows[i].Text("");
      if(!Add(m_lblRows[i])) return(false);
   }

   return(true);
}

//--- COrdersPanel 刷新订单数据
void COrdersPanel::RefreshOrders(void)
{
   // 判断品种类型
   bool isMetals = (StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "XAG") >= 0 ||
                    StringFind(_Symbol, "GOLD") >= 0 || StringFind(_Symbol, "SILVER") >= 0);
   
   bool isCrypto = (StringFind(_Symbol, "BTC") >= 0 || StringFind(_Symbol, "ETH") >= 0 ||
                    StringFind(_Symbol, "LTC") >= 0 || StringFind(_Symbol, "XRP") >= 0 ||
                    StringFind(_Symbol, "BCH") >= 0 || StringFind(_Symbol, "ADA") >= 0 ||
                    StringFind(_Symbol, "DOT") >= 0 || StringFind(_Symbol, "DOGE") >= 0);
   
   // 根据报价位数动态计算 pip 单位（支持4位和5位报价）
   double pointsPerPip = (_Digits == 5 || _Digits == 3) ? 10.0 : 1.0;
   
   int      serverGMT = (int)((TimeCurrent() - TimeGMT()) / 3600);
   int      bjOffset  = (8 - serverGMT) * 3600;
   datetime bjNow     = (datetime)(TimeCurrent() + bjOffset);
   datetime bjToday0  = bjNow - (bjNow % 86400);
   datetime svrToday0 = (datetime)(bjToday0 - bjOffset);

   // 更新面板标题（品种 + 北京时间日期）
   m_lblTitle.Text(StringFormat("-- %s  %04d-%02d-%02d (BJ) --",
      _Symbol, TimeYear(bjNow), TimeMonth(bjNow), TimeDay(bjNow)));

   int    count    = 0;
   string rowTexts[ORDERS_ROWS];  // 静态上限缓冲，实际只填 m_maxRows 条

   // --- 1. 当前持仓（当前品种，标记 * ）---
   for(int i = 0; i < OrdersTotal() && count < m_maxRows; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      datetime bjOpen = (datetime)(OrderOpenTime() + bjOffset);
      string   tStr   = StringFormat("%02d:%02d",
                           TimeHour(bjOpen), TimeMinute(bjOpen));
      string   typ    = (OrderType() == OP_BUY) ? "B" : "S";
      double   exitPx = (OrderType() == OP_BUY) ? Bid : Ask;
      double   prof   = OrderProfit() + OrderSwap() + OrderCommission();
      double   diff   = (OrderType() == OP_BUY) ?
                           exitPx - OrderOpenPrice() :
                           OrderOpenPrice() - exitPx;
      double   pts    = (isMetals || isCrypto) ? diff : diff / (_Point * pointsPerPip);  // 贵金属/加密货币显示价格差，外汇显示pips
      int      dSec   = (int)(TimeCurrent() - OrderOpenTime());
      string   durStr;
      if(dSec < 60)              durStr = StringFormat("%d", dSec) + "s";
      else if(dSec < 3600)       durStr = StringFormat("%dm%02d", dSec/60, dSec%60) + "s";
      else                       durStr = StringFormat("%dh%02dm",     dSec/3600, (dSec%3600)/60);
      string   slStr  = (OrderStopLoss() > 0) ?
                           DoubleToString(OrderStopLoss(), _Digits) : "---";

      rowTexts[count++] = StringFormat("*%s %s %4.2f %-9s%-9s%-9s%+7.2f %+6.1f ",
         tStr, typ, OrderLots(),
         DoubleToString(OrderOpenPrice(), _Digits),
         slStr,
         DoubleToString(exitPx, _Digits),
         prof, pts) + durStr;
   }

   // --- 2. 历史订单（今日北京时间内已关闭）---
   for(int i = OrdersHistoryTotal()-1; i >= 0 && count < m_maxRows; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderCloseTime() < svrToday0) continue;

      datetime bjOpen = (datetime)(OrderOpenTime() + bjOffset);
      string   tStr   = StringFormat("%02d:%02d",
                           TimeHour(bjOpen), TimeMinute(bjOpen));
      string   typ    = (OrderType() == OP_BUY) ? "B" : "S";
      double   prof   = OrderProfit() + OrderSwap() + OrderCommission();
      double   diff   = (OrderType() == OP_BUY) ?
                           OrderClosePrice() - OrderOpenPrice() :
                           OrderOpenPrice() - OrderClosePrice();
      double   pts    = (isMetals || isCrypto) ? diff : diff / (_Point * pointsPerPip);  // 贵金属/加密货币显示价格差，外汇显示pips
      int      dSec   = (int)(OrderCloseTime() - OrderOpenTime());
      string   durStr;
      if(dSec < 60)              durStr = StringFormat("%d", dSec) + "s";
      else if(dSec < 3600)       durStr = StringFormat("%dm%02d", dSec/60, dSec%60) + "s";
      else                       durStr = StringFormat("%dh%02dm",     dSec/3600, (dSec%3600)/60);
      string   slStr  = (OrderStopLoss() > 0) ?
                           DoubleToString(OrderStopLoss(), _Digits) : "---";

      rowTexts[count++] = StringFormat(" %s %s %4.2f %-9s%-9s%-9s%+7.2f %+6.1f ",
         tStr, typ, OrderLots(),
         DoubleToString(OrderOpenPrice(), _Digits),
         slStr,
         DoubleToString(OrderClosePrice(), _Digits),
         prof, pts) + durStr;
   }

   // 更新所有行标签
   for(int i = 0; i < m_maxRows; i++)
      m_lblRows[i].Text(i < count ? rowTexts[i] : "");

   m_rowCount = count;
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 自定义面板类                                                      |
//+------------------------------------------------------------------+
class CTradePanel : public CAppDialog
{
private:
   // === 信息显示容器（模块1之前） ===
   CEdit            m_edtDailyProfit;      // 今日盈亏容器
   CButton          m_btnToggleProfit;     // 盈亏容器显示/隐藏按钮
   bool             m_showProfit;          // 盈亏容器显示状态
   
   CEdit            m_edtPositions;        // 持仓价格容器
   CButton          m_btnTogglePositions;  // 持仓容器显示/隐藏按钮
   bool             m_showPositions;       // 持仓容器显示状态
   
   // 模块1: 开仓交易模块控件
   CLabel           m_lblStopLoss;    // 止损标签
   CEdit            m_edtStopLoss;    // 止损输入框
   CButton          m_btnSelectSL;    // 选择止损按钮 (NEW)
   
   CLabel           m_lblLots;        // 手数标签
   CButton          m_btnLotsDecrease;// 手数减少按钮
   CEdit            m_edtLots;        // 手数输入框
   CButton          m_btnLotsIncrease;// 手数增加按钮
   
   CLabel           m_lblTakeProfit;  // 止盈标签
   CEdit            m_edtTakeProfit;  // 止盈输入框
   CButton          m_btnSelectTP;    // 选择止盈按钮 (NEW)
   
   CButton          m_btnBuy;         // 现价买入按钮
   CButton          m_btnSell;        // 现价卖出按钮
   
   // 模块2: 止盈止损管理模块控件
   CLabel           m_lblMod2;         // 模块2标题
   CLabel           m_lblSlPoints;     // 止损点数标签
   CEdit            m_edtSlPoints;     // 止损点数输入框
   CButton          m_btnSetSlPoints;  // 设置止损点数按钮
   CLabel           m_lblSlPrice2;     // 止损价格标签
   CEdit            m_edtSlPrice2;     // 止损价格输入框
   CButton          m_btnSetSlPrice;   // 设置止损价格按钮
   CLabel           m_lblTpPoints;     // 止盈点数标签
   CEdit            m_edtTpPoints;     // 止盈点数输入框
   CButton          m_btnSetTpPoints;  // 设置止盈点数按钮
   CLabel           m_lblTpPrice2;     // 止盈价格标签
   CEdit            m_edtTpPrice2;     // 止盈价格输入框
   CButton          m_btnSetTpPrice;   // 设置止盈价格按钮

   // 模块3: 比例平仓模块控件
   CLabel           m_lblMod3;          // 模块3标题
   CButton          m_btnClose50;       // 50%平仓按钮
   CButton          m_btnClose80;       // 80%平仓按钮
   CButton          m_btnClose100;      // 100%平仓按钮
   CLabel           m_lblClosePct;      // 自定义比例标签
   CEdit            m_edtClosePct;      // 自定义比例输入框
   CButton          m_btnCloseCustom;   // 执行自定义比例平仓按钮
   // 模块3子功能2: 按手数平仓
   CButton          m_btnCloseLot1;     // -1手平仓按钮
   CButton          m_btnCloseLot01;    // -0.1手平仓按钮
   CButton          m_btnCloseLot001;   // -0.01手平仓按钮
   CLabel           m_lblCloseLots;     // 自定义手数标签
   CEdit            m_edtCloseLots;     // 自定义手数输入框
   CButton          m_btnCloseByLots;   // 按手数执行平仓按钮
   CButton          m_btnCloseSymbol;   // 平当前品种按钮
   CButton          m_btnBreakEven;     // 一键保本按钮

   // 模块5: 自动减仓模块控件
   CLabel           m_lblScaleOut;         // 模块标题
   CLabel           m_lblTriggerPts;       // 触发点数标签
   CEdit            m_edtTriggerPts;       // 触发点数输入框
   CLabel           m_lblScalePct;         // 减仓比例标签
   CEdit            m_edtScalePct;         // 减仓比例输入框
   CLabel           m_lblScaleLots;        // 减仓手数标签
   CEdit            m_edtScaleLots;        // 减仓手数输入框
   CButton          m_btnToggleScaleOut;   // 开启/关闭按钮
   CButton          m_btnSmartCalc;        // 智能计算按钮
   
   // 自动减仓状态变量
   bool             m_scaleOutEnabled;     // 是否启用自动减仓
   datetime         m_scaledOpenTimes[100];// 已减仓订单的开仓时间
   int              m_scaledCount;         // 已减仓订单数量

   // 模块4: 订单记录模块控件
   CLabel           m_lblMod4;          // 模块4标题
   CButton          m_btnViewOrders;    // 查看今日订单按钮

public:
                    CTradePanel();
                   ~CTradePanel();
   virtual bool     Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   virtual bool     OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
   void             UpdateInfoContainers(void);  // 更新信息容器
   void             CheckAutoScaleOut(void);     // 检查并执行自动减仓（需要public以便在OnTick中调用）
   
   // 价格选择功能的公共方法（NEW）
   void             SetStopLossPrice(double price);    // 设置止损价格
   void             SetTakeProfitPrice(double price);  // 设置止盈价格
   void             ResetSelectButton(int mode);       // 重置选择按钮颜色
   
protected:
   bool             CreateControls(void);
   void             OnClickLotsDecrease(void);
   void             OnClickLotsIncrease(void);
   void             OnClickBuy(void);
   void             OnClickSell(void);
   void             OnClickSetSlPoints(void);
   void             OnClickSetSlPrice(void);
   void             OnClickSetTpPoints(void);
   void             OnClickSetTpPrice(void);
   void             CloseByPercent(double pct);
   void             OnClickClose50(void);
   void             OnClickClose80(void);
   void             OnClickClose100(void);
   void             OnClickCloseCustom(void);
   void             CloseLots(double lots);
   void             OnClickCloseLot1(void);
   void             OnClickCloseLot01(void);
   void             OnClickCloseLot001(void);
   void             OnClickCloseByLots(void);
   void             OnClickCloseSymbol(void);
   void             OnClickBreakEven(void);
   void             OnClickViewOrders(void);
   void             OnClickToggleProfit(void);        // 切换盈亏容器显示
   void             OnClickTogglePositions(void);     // 切换持仓容器显示
   double           CalculateDailyProfit(void);       // 计算今日盈亏
   string           GetCurrentPositions(void);        // 获取当前持仓价格
   
   // 自动减仓相关方法（内部）
   void             OnClickToggleScaleOut(void);      // 切换自动减仓开关
   void             OnClickSmartCalc(void);           // 智能计算保本参数
   void             ExecuteScaleOut(int ticket, double pct, double lots); // 执行减仓
   bool             IsOrderScaled(int ticket);        // 检查订单是否已减仓
   void             CleanupScaledOrders(void);        // 清理已关闭订单记录
   
   // 价格选择功能方法（NEW）
   void             OnClickSelectSL(void);            // 点击选择止损按钮
   void             OnClickSelectTP(void);            // 点击选择止盈按钮
};

//+------------------------------------------------------------------+
//| 构造函数                                                          |
//+------------------------------------------------------------------+
CTradePanel::CTradePanel()
{
   // 初始化自动减仓状态
   m_scaleOutEnabled = false;
   m_scaledCount = 0;
   ArrayInitialize(m_scaledOpenTimes, 0);
}

//+------------------------------------------------------------------+
//| 析构函数                                                          |
//+------------------------------------------------------------------+
CTradePanel::~CTradePanel()
{
}

//+------------------------------------------------------------------+
//| 创建面板                                                          |
//+------------------------------------------------------------------+
bool CTradePanel::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
{
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2))
      return(false);
      
   // 设置面板标题
   Caption("K-Trade");
      
   // 创建控件
   if(!CreateControls())
      return(false);
      
   return(true);
}

//+------------------------------------------------------------------+
//| 创建所有控件                                                      |
//+------------------------------------------------------------------+
bool CTradePanel::CreateControls(void)
{
   int x = 10;
   int y = 10;
   int width = ClientAreaWidth() - 20;
   int btnHeight = 25;
   int inputHeight = 22;
   int spacing = 10;
   
   //=== 信息容器区域 ===
   int infoY = y;
   int btnW = 50;                          // 按钮宽度
   int gap = 5;                            // 间距
   int editW = width - btnW - gap;         // 容器宽度
   int containerH = 35;                    // 容器高度
   
   // --- 容器1: 今日盈亏 ---
   if(!m_edtDailyProfit.Create(m_chart_id, m_name+"DailyProfit", m_subwin,
                                x, infoY, x+editW, infoY+containerH))
      return(false);
   m_edtDailyProfit.Text("[ 已隐藏 ]");
   m_edtDailyProfit.ReadOnly(true);
   m_edtDailyProfit.ColorBackground(clrLightGray);
   m_edtDailyProfit.ColorBorder(clrGray);
   if(!Add(m_edtDailyProfit)) return(false);
   
   // 按钮1（右侧）
   if(!m_btnToggleProfit.Create(m_chart_id, m_name+"BtnToggleProfit", m_subwin,
                                 x+editW+gap, infoY, x+width, infoY+containerH))
      return(false);
   m_btnToggleProfit.Text("显示");
   m_btnToggleProfit.ColorBackground(clrLightGray);
   if(!Add(m_btnToggleProfit)) return(false);
   
   m_showProfit = false;  // 初始状态：隐藏
   
   // --- 容器2: 持仓价格 ---
   infoY += containerH + 5;  // 向下移动
   
   if(!m_edtPositions.Create(m_chart_id, m_name+"Positions", m_subwin,
                              x, infoY, x+editW, infoY+containerH))
      return(false);
   m_edtPositions.Text("持仓: 加载中...");
   m_edtPositions.ReadOnly(true);
   m_edtPositions.ColorBackground(clrAliceBlue);
   m_edtPositions.ColorBorder(clrDodgerBlue);
   if(!Add(m_edtPositions)) return(false);
   
   // 按钮2（右侧）
   if(!m_btnTogglePositions.Create(m_chart_id, m_name+"BtnTogglePos", m_subwin,
                                    x+editW+gap, infoY, x+width, infoY+containerH))
      return(false);
   m_btnTogglePositions.Text("隐藏");
   m_btnTogglePositions.ColorBackground(clrLightGray);
   if(!Add(m_btnTogglePositions)) return(false);
   
   m_showPositions = true;  // 初始状态：显示
   
   // === 模块1起始位置向下移动 ===
   y = infoY + containerH + 15;
   
   //--- 模块1: 开仓交易模块 (三列横排: 止损 | 手数 | 止盈) ---

   // 列布局: 手数列占40%, 止损/止盈各占30%
   int cGap    = 10;
   int col2W   = width * 2 / 5;                     // 手数列宽(40%)
   int col1W   = (width - col2W - cGap * 2) / 2;   // 止损列宽(30%)
   int col3W   = width - col2W - col1W - cGap * 2; // 止盈列宽(余量)
   int col1X   = x;
   int col2X   = col1X + col1W + cGap;
   int col3X   = col2X + col2W + cGap;
   int lblRowH = 16;  // 标签行高
   int edtRowH = 25;  // 输入行高
   int lotsBW  = 28;  // +/- 按钮宽度

   // 第一行: 三列标签
   if(!m_lblStopLoss.Create(m_chart_id,m_name+"LblSL",m_subwin,col1X,y,col1X+col1W,y+lblRowH))
      return(false);
   if(!m_lblStopLoss.Text("止  损:")) return(false);
   if(!Add(m_lblStopLoss)) return(false);

   if(!m_lblLots.Create(m_chart_id,m_name+"LblLots",m_subwin,col2X,y,col2X+col2W,y+lblRowH))
      return(false);
   if(!m_lblLots.Text("手    数:")) return(false);
   if(!Add(m_lblLots)) return(false);

   if(!m_lblTakeProfit.Create(m_chart_id,m_name+"LblTP",m_subwin,col3X,y,col3X+col3W,y+lblRowH))
      return(false);
   if(!m_lblTakeProfit.Text("止  盈:")) return(false);
   if(!Add(m_lblTakeProfit)) return(false);

   // 第二行: 三列输入框 (手数列含 [-][输入][+])
   int rowY    = y + lblRowH + 3;
   int lotsEdtX = col2X + lotsBW + 5;
   int lotsEdtW = col2W - lotsBW * 2 - 10;

   // 止损: [输入框] [📍按钮]
   int selectBtnW = 35;  // 选择按钮宽度
   int slEditW = col1W - selectBtnW - 3;  // 止损输入框宽度
   
   if(!m_edtStopLoss.Create(m_chart_id,m_name+"EdtSL",m_subwin,col1X,rowY,col1X+slEditW,rowY+edtRowH))
      return(false);
   m_edtStopLoss.Text("0.00000");
   m_edtStopLoss.ReadOnly(false);
   if(!Add(m_edtStopLoss)) return(false);
   
   // 选择止损按钮
   if(!m_btnSelectSL.Create(m_chart_id,m_name+"BtnSelectSL",m_subwin,
                             col1X+slEditW+3,rowY,col1X+col1W,rowY+edtRowH))
      return(false);
   m_btnSelectSL.Text(">");
   m_btnSelectSL.ColorBackground(clrLightGray);
   if(!Add(m_btnSelectSL)) return(false);

   // 手数: [-] [输入框] [+]
   if(!m_btnLotsDecrease.Create(m_chart_id,m_name+"BtnLotsDecrease",m_subwin,
                                 col2X,rowY,col2X+lotsBW,rowY+edtRowH))
      return(false);
   if(!m_btnLotsDecrease.Text("-")) return(false);
   m_btnLotsDecrease.ColorBackground(clrLightBlue);
   if(!Add(m_btnLotsDecrease)) return(false);

   if(!m_edtLots.Create(m_chart_id,m_name+"EdtLots",m_subwin,lotsEdtX,rowY,lotsEdtX+lotsEdtW,rowY+edtRowH))
      return(false);
   m_edtLots.Text("0.01");
   m_edtLots.ReadOnly(false);
   if(!Add(m_edtLots)) return(false);

   if(!m_btnLotsIncrease.Create(m_chart_id,m_name+"BtnLotsIncrease",m_subwin,
                                 col2X+col2W-lotsBW,rowY,col2X+col2W,rowY+edtRowH))
      return(false);
   if(!m_btnLotsIncrease.Text("+")) return(false);
   m_btnLotsIncrease.ColorBackground(clrLightGreen);
   if(!Add(m_btnLotsIncrease)) return(false);

   // 止盈: [输入框] [📍按钮]
   int tpEditW = col3W - selectBtnW - 3;  // 止盈输入框宽度
   
   if(!m_edtTakeProfit.Create(m_chart_id,m_name+"EdtTP",m_subwin,col3X,rowY,col3X+tpEditW,rowY+edtRowH))
      return(false);
   m_edtTakeProfit.Text("0.00000");
   m_edtTakeProfit.ReadOnly(false);
   if(!Add(m_edtTakeProfit)) return(false);
   
   // 选择止盈按钮
   if(!m_btnSelectTP.Create(m_chart_id,m_name+"BtnSelectTP",m_subwin,
                             col3X+tpEditW+3,rowY,col3X+col3W,rowY+edtRowH))
      return(false);
   m_btnSelectTP.Text(">");
   m_btnSelectTP.ColorBackground(clrLightGray);
   if(!Add(m_btnSelectTP)) return(false);

   // y 推进到买卖按钮行
   y = rowY + edtRowH + 8;

   // 买入卖出按钮 (占满整行)
   int halfWidth = (width - 5) / 2;

   // 现价买入按钮
   if(!m_btnBuy.Create(m_chart_id,m_name+"BtnBuy",m_subwin,x,y,x+halfWidth,y+30))
      return(false);
   if(!m_btnBuy.Text("买  入"))
      return(false);
   m_btnBuy.ColorBackground(clrLimeGreen);
   m_btnBuy.ColorBorder(clrGreen);
   if(!Add(m_btnBuy))
      return(false);

   // 现价卖出按钮
   int sellX = x + halfWidth + 5;
   if(!m_btnSell.Create(m_chart_id,m_name+"BtnSell",m_subwin,sellX,y,sellX+halfWidth,y+30))
      return(false);
   if(!m_btnSell.Text("卖  出"))
      return(false);
   m_btnSell.ColorBackground(clrTomato);
   m_btnSell.ColorBorder(clrRed);
   if(!Add(m_btnSell))
      return(false);
   
   //=== 模块2: 止盈止损管理 (2列×2行, 标签内联) ===
   y += 30; // 补偿买卖按钮高度

   int rowH2   = 25;                              // 输入行高（模块3也使用此变量）
   int m2Gap   = 10;                              // 两列间距
   int m2ColW  = (width - m2Gap) / 2;             // 每列宽度
   int m2C1X   = x;                               // 左列起点X
   int m2C2X   = x + m2ColW + m2Gap;              // 右列起点X
   int m2LblW  = 45;                              // 内联标签宽度
   int m2BtnW  = 38;                              // Set按钮宽度
   int m2EdtW  = m2ColW - m2LblW - m2BtnW - 6;   // 输入框宽度（两侧各3px间距）
   int m2Edt1X = m2C1X + m2LblW + 3;             // 左列输入框X
   int m2Edt2X = m2C2X + m2LblW + 3;             // 右列输入框X
   int m2Btn1X = m2Edt1X + m2EdtW + 3;           // 左列Set按钮X
   int m2Btn2X = m2Edt2X + m2EdtW + 3;           // 右列Set按钮X

   // 模块2标题
   y += 10;
   if(!m_lblMod2.Create(m_chart_id,m_name+"LblMod2",m_subwin,x,y,x+width,y+20))
      return(false);
   if(!m_lblMod2.Text("-- SL/TP Mgmt --"))
      return(false);
   if(!Add(m_lblMod2))
      return(false);
   y += 28;

   //--- 第一行: [SL pts:][input][Set] | [TP pts:][input][Set] ---
   if(!m_lblSlPoints.Create(m_chart_id,m_name+"LblSlPts",m_subwin,m2C1X,y,m2C1X+m2LblW,y+rowH2))
      return(false);
   if(!m_lblSlPoints.Text("SL pts:")) return(false);
   if(!Add(m_lblSlPoints)) return(false);
   if(!m_edtSlPoints.Create(m_chart_id,m_name+"EdtSlPts",m_subwin,m2Edt1X,y,m2Edt1X+m2EdtW,y+rowH2))
      return(false);
   m_edtSlPoints.Text("500");
   m_edtSlPoints.ReadOnly(false);
   if(!Add(m_edtSlPoints)) return(false);
   if(!m_btnSetSlPoints.Create(m_chart_id,m_name+"BtnSetSlPts",m_subwin,m2Btn1X,y,m2Btn1X+m2BtnW,y+rowH2))
      return(false);
   if(!m_btnSetSlPoints.Text("Set")) return(false);
   m_btnSetSlPoints.ColorBackground(clrSteelBlue);
   if(!Add(m_btnSetSlPoints)) return(false);

   if(!m_lblTpPoints.Create(m_chart_id,m_name+"LblTpPts",m_subwin,m2C2X,y,m2C2X+m2LblW,y+rowH2))
      return(false);
   if(!m_lblTpPoints.Text("TP pts:")) return(false);
   if(!Add(m_lblTpPoints)) return(false);
   if(!m_edtTpPoints.Create(m_chart_id,m_name+"EdtTpPts",m_subwin,m2Edt2X,y,m2Edt2X+m2EdtW,y+rowH2))
      return(false);
   m_edtTpPoints.Text("1000");
   m_edtTpPoints.ReadOnly(false);
   if(!Add(m_edtTpPoints)) return(false);
   if(!m_btnSetTpPoints.Create(m_chart_id,m_name+"BtnSetTpPts",m_subwin,m2Btn2X,y,m2Btn2X+m2BtnW,y+rowH2))
      return(false);
   if(!m_btnSetTpPoints.Text("Set")) return(false);
   m_btnSetTpPoints.ColorBackground(clrDarkOrange);
   if(!Add(m_btnSetTpPoints)) return(false);
   y += rowH2 + 8;

   //--- 第二行: [SL $:][input][Set] | [TP $:][input][Set] ---
   if(!m_lblSlPrice2.Create(m_chart_id,m_name+"LblSlPrc2",m_subwin,m2C1X,y,m2C1X+m2LblW,y+rowH2))
      return(false);
   if(!m_lblSlPrice2.Text("SL $:")) return(false);
   if(!Add(m_lblSlPrice2)) return(false);
   if(!m_edtSlPrice2.Create(m_chart_id,m_name+"EdtSlPrc2",m_subwin,m2Edt1X,y,m2Edt1X+m2EdtW,y+rowH2))
      return(false);
   m_edtSlPrice2.Text("0.00000");
   m_edtSlPrice2.ReadOnly(false);
   if(!Add(m_edtSlPrice2)) return(false);
   if(!m_btnSetSlPrice.Create(m_chart_id,m_name+"BtnSetSlPrc",m_subwin,m2Btn1X,y,m2Btn1X+m2BtnW,y+rowH2))
      return(false);
   if(!m_btnSetSlPrice.Text("Set")) return(false);
   m_btnSetSlPrice.ColorBackground(clrSteelBlue);
   if(!Add(m_btnSetSlPrice)) return(false);

   if(!m_lblTpPrice2.Create(m_chart_id,m_name+"LblTpPrc2",m_subwin,m2C2X,y,m2C2X+m2LblW,y+rowH2))
      return(false);
   if(!m_lblTpPrice2.Text("TP $:")) return(false);
   if(!Add(m_lblTpPrice2)) return(false);
   if(!m_edtTpPrice2.Create(m_chart_id,m_name+"EdtTpPrc2",m_subwin,m2Edt2X,y,m2Edt2X+m2EdtW,y+rowH2))
      return(false);
   m_edtTpPrice2.Text("0.00000");
   m_edtTpPrice2.ReadOnly(false);
   if(!Add(m_edtTpPrice2)) return(false);
   if(!m_btnSetTpPrice.Create(m_chart_id,m_name+"BtnSetTpPrc",m_subwin,m2Btn2X,y,m2Btn2X+m2BtnW,y+rowH2))
      return(false);
   if(!m_btnSetTpPrice.Text("Set")) return(false);
   m_btnSetTpPrice.ColorBackground(clrDarkOrange);
   if(!Add(m_btnSetTpPrice)) return(false);

   //=== 模块3: 比例平仓 (2行紧凑布局) ===
   y += rowH2 + 10;

   // 模块3标题
   if(!m_lblMod3.Create(m_chart_id,m_name+"LblMod3",m_subwin,x,y,x+width,y+20))
      return(false);
   if(!m_lblMod3.Text("-- Close Position --"))
      return(false);
   if(!Add(m_lblMod3))
      return(false);
   y += 28;

   int m3BtnH = 28;                        // 行高
   int m3LW   = (width - 10) / 2;          // 左侧快捷按钮区宽
   int m3RX   = x + m3LW + 10;             // 右侧起点X
   int m3RW   = width - m3LW - 10;         // 右侧宽度
   int m3QB   = (m3LW - 10) / 3;           // 快捷按钮宽（内含5px间距）
   int m3LblW = 30;                         // 右侧标签宽
   int m3GoW  = 38;                         // Go按钮宽
   int m3EdtW = m3RW - m3LblW - m3GoW - 6; // 右侧输入框宽
   int m3EdtX = m3RX + m3LblW + 3;         // 右侧输入框X
   int m3GoX  = m3EdtX + m3EdtW + 3;       // 右侧Go按钮X

   //--- Row1: [50%][80%][100%] | [Pct:][input][Go] ---
   if(!m_btnClose50.Create(m_chart_id,m_name+"BtnClose50",m_subwin,
                            x, y, x+m3QB, y+m3BtnH))
      return(false);
   if(!m_btnClose50.Text("50%")) return(false);
   m_btnClose50.ColorBackground(clrGold);
   if(!Add(m_btnClose50)) return(false);

   if(!m_btnClose80.Create(m_chart_id,m_name+"BtnClose80",m_subwin,
                            x+m3QB+5, y, x+m3QB*2+5, y+m3BtnH))
      return(false);
   if(!m_btnClose80.Text("80%")) return(false);
   m_btnClose80.ColorBackground(clrGold);
   if(!Add(m_btnClose80)) return(false);

   if(!m_btnClose100.Create(m_chart_id,m_name+"BtnClose100",m_subwin,
                             x+m3QB*2+10, y, x+m3LW, y+m3BtnH))
      return(false);
   if(!m_btnClose100.Text("100%")) return(false);
   m_btnClose100.ColorBackground(clrOrangeRed);
   if(!Add(m_btnClose100)) return(false);

   if(!m_lblClosePct.Create(m_chart_id,m_name+"LblClosePct",m_subwin,
                             m3RX, y, m3RX+m3LblW, y+m3BtnH))
      return(false);
   if(!m_lblClosePct.Text("Pct:")) return(false);
   if(!Add(m_lblClosePct)) return(false);

   if(!m_edtClosePct.Create(m_chart_id,m_name+"EdtClosePct",m_subwin,
                             m3EdtX, y, m3EdtX+m3EdtW, y+m3BtnH))
      return(false);
   m_edtClosePct.Text("30");
   m_edtClosePct.ReadOnly(false);
   if(!Add(m_edtClosePct)) return(false);

   if(!m_btnCloseCustom.Create(m_chart_id,m_name+"BtnCloseCustom",m_subwin,
                                m3GoX, y, m3GoX+m3GoW, y+m3BtnH))
      return(false);
   if(!m_btnCloseCustom.Text("Go")) return(false);
   m_btnCloseCustom.ColorBackground(clrOrangeRed);
   if(!Add(m_btnCloseCustom)) return(false);
   y += m3BtnH + 8;

   //--- Row2: [-1][-0.1][-0.01] | [Lot:][input][Go] ---
   if(!m_btnCloseLot1.Create(m_chart_id,m_name+"BtnCloseLot1",m_subwin,
                              x, y, x+m3QB, y+m3BtnH))
      return(false);
   if(!m_btnCloseLot1.Text("-1")) return(false);
   m_btnCloseLot1.ColorBackground(clrMediumPurple);
   if(!Add(m_btnCloseLot1)) return(false);

   if(!m_btnCloseLot01.Create(m_chart_id,m_name+"BtnCloseLot01",m_subwin,
                               x+m3QB+5, y, x+m3QB*2+5, y+m3BtnH))
      return(false);
   if(!m_btnCloseLot01.Text("-0.1")) return(false);
   m_btnCloseLot01.ColorBackground(clrMediumPurple);
   if(!Add(m_btnCloseLot01)) return(false);

   if(!m_btnCloseLot001.Create(m_chart_id,m_name+"BtnCloseLot001",m_subwin,
                                x+m3QB*2+10, y, x+m3LW, y+m3BtnH))
      return(false);
   if(!m_btnCloseLot001.Text("-0.01")) return(false);
   m_btnCloseLot001.ColorBackground(clrMediumPurple);
   if(!Add(m_btnCloseLot001)) return(false);

   if(!m_lblCloseLots.Create(m_chart_id,m_name+"LblCloseLots",m_subwin,
                              m3RX, y, m3RX+m3LblW, y+m3BtnH))
      return(false);
   if(!m_lblCloseLots.Text("Lot:")) return(false);
   if(!Add(m_lblCloseLots)) return(false);

   if(!m_edtCloseLots.Create(m_chart_id,m_name+"EdtCloseLots",m_subwin,
                              m3EdtX, y, m3EdtX+m3EdtW, y+m3BtnH))
      return(false);
   m_edtCloseLots.Text("0.10");
   m_edtCloseLots.ReadOnly(false);
   if(!Add(m_edtCloseLots)) return(false);

   if(!m_btnCloseByLots.Create(m_chart_id,m_name+"BtnCloseByLots",m_subwin,
                                m3GoX, y, m3GoX+m3GoW, y+m3BtnH))
      return(false);
   if(!m_btnCloseByLots.Text("Go")) return(false);
   m_btnCloseByLots.ColorBackground(clrMediumPurple);
   if(!Add(m_btnCloseByLots)) return(false);
   y += m3BtnH + 8;

   //--- Row3: [平当前品种] [一键保本] ---
   int r3BtnW = (width - 5) / 2;
   if(!m_btnCloseSymbol.Create(m_chart_id,m_name+"BtnCloseSymbol",m_subwin,
                               x, y, x+r3BtnW, y+m3BtnH))
      return(false);
   if(!m_btnCloseSymbol.Text("平当前品种")) return(false);
   m_btnCloseSymbol.ColorBackground(clrCrimson);
   if(!Add(m_btnCloseSymbol)) return(false);

   if(!m_btnBreakEven.Create(m_chart_id,m_name+"BtnBreakEven",m_subwin,
                              x+r3BtnW+5, y, x+width, y+m3BtnH))
      return(false);
   if(!m_btnBreakEven.Text("一键保本")) return(false);
   m_btnBreakEven.ColorBackground(clrDarkCyan);
   if(!Add(m_btnBreakEven)) return(false);

   //=== 模块5: 自动减仓 ===
   y += m3BtnH + 10;
   
   // 模块标题
   if(!m_lblScaleOut.Create(m_chart_id,m_name+"LblScaleOut",m_subwin,x,y,x+width,y+20))
      return(false);
   if(!m_lblScaleOut.Text("-- Auto Scale-Out --"))
      return(false);
   if(!Add(m_lblScaleOut))
      return(false);
   y += 28;
   
   // 布局参数
   int m5BtnH = 25;                           // 控件高度
   int m5LblW = 35;                           // 标签宽度
   int m5Gap = 5;                             // 间距
   int m5Col1W = (width - m5Gap*2) / 3;      // 第一列宽度（触发点数）
   int m5Col2W = m5Col1W;                     // 第二列宽度（减仓比例）
   int m5Col3W = width - m5Col1W - m5Col2W - m5Gap*2; // 第三列宽度（减仓手数）
   int m5Col1X = x;
   int m5Col2X = m5Col1X + m5Col1W + m5Gap;
   int m5Col3X = m5Col2X + m5Col2W + m5Gap;
   int m5EdtW1 = m5Col1W - m5LblW - 3;
   int m5EdtW2 = m5Col2W - m5LblW - 3;
   int m5EdtW3 = m5Col3W - m5LblW - 3;
   
   // 第一行：[触发:][200]pts | [减仓:][80]% | [或][0.04]lots
   if(!m_lblTriggerPts.Create(m_chart_id,m_name+"LblTrigPts",m_subwin,
                               m5Col1X,y,m5Col1X+m5LblW,y+m5BtnH))
      return(false);
   if(!m_lblTriggerPts.Text("触发:")) return(false);
   if(!Add(m_lblTriggerPts)) return(false);
   
   if(!m_edtTriggerPts.Create(m_chart_id,m_name+"EdtTrigPts",m_subwin,
                              m5Col1X+m5LblW+3,y,m5Col1X+m5Col1W,y+m5BtnH))
      return(false);
   m_edtTriggerPts.Text("200");
   m_edtTriggerPts.ReadOnly(false);
   if(!Add(m_edtTriggerPts)) return(false);
   
   if(!m_lblScalePct.Create(m_chart_id,m_name+"LblScalePct",m_subwin,
                            m5Col2X,y,m5Col2X+m5LblW,y+m5BtnH))
      return(false);
   if(!m_lblScalePct.Text("减仓:")) return(false);
   if(!Add(m_lblScalePct)) return(false);
   
   if(!m_edtScalePct.Create(m_chart_id,m_name+"EdtScalePct",m_subwin,
                            m5Col2X+m5LblW+3,y,m5Col2X+m5Col2W,y+m5BtnH))
      return(false);
   m_edtScalePct.Text("80");
   m_edtScalePct.ReadOnly(false);
   if(!Add(m_edtScalePct)) return(false);
   
   if(!m_lblScaleLots.Create(m_chart_id,m_name+"LblScaleLots",m_subwin,
                             m5Col3X,y,m5Col3X+m5LblW,y+m5BtnH))
      return(false);
   if(!m_lblScaleLots.Text("或:")) return(false);
   if(!Add(m_lblScaleLots)) return(false);
   
   if(!m_edtScaleLots.Create(m_chart_id,m_name+"EdtScaleLots",m_subwin,
                             m5Col3X+m5LblW+3,y,m5Col3X+m5Col3W,y+m5BtnH))
      return(false);
   m_edtScaleLots.Text("0.04");
   m_edtScaleLots.ReadOnly(false);
   if(!Add(m_edtScaleLots)) return(false);
   
   y += m5BtnH + 8;
   
   // 第二行：[开启自动减仓] [智能计算保本]
   int m5Btn1W = (width - m5Gap) / 2;
   int m5Btn2W = width - m5Btn1W - m5Gap;
   
   if(!m_btnToggleScaleOut.Create(m_chart_id,m_name+"BtnToggleScaleOut",m_subwin,
                                   x,y,x+m5Btn1W,y+m5BtnH))
      return(false);
   if(!m_btnToggleScaleOut.Text("开启自动减仓")) return(false);
   m_btnToggleScaleOut.ColorBackground(clrLightGray);
   if(!Add(m_btnToggleScaleOut)) return(false);
   
   if(!m_btnSmartCalc.Create(m_chart_id,m_name+"BtnSmartCalc",m_subwin,
                             x+m5Btn1W+m5Gap,y,x+width,y+m5BtnH))
      return(false);
   if(!m_btnSmartCalc.Text("智能计算保本")) return(false);
   m_btnSmartCalc.ColorBackground(clrMediumSeaGreen);
   if(!Add(m_btnSmartCalc)) return(false);

   //=== 模块4: 订单记录模块 ===
   y += m3BtnH + 10;

   if(!m_lblMod4.Create(m_chart_id,m_name+"LblMod4",m_subwin,x,y,x+width,y+20))
      return(false);
   if(!m_lblMod4.Text("-- Order Log --"))
      return(false);
   if(!Add(m_lblMod4))
      return(false);
   y += 28;

   if(!m_btnViewOrders.Create(m_chart_id,m_name+"BtnViewOrders",m_subwin,x,y,x+width,y+28))
      return(false);
   if(!m_btnViewOrders.Text("查看今日订单记录"))
      return(false);
   m_btnViewOrders.ColorBackground(clrSlateGray);
   if(!Add(m_btnViewOrders))
      return(false);

   return(true);
}

//+------------------------------------------------------------------+
//| 事件处理                                                          |
//+------------------------------------------------------------------+
bool CTradePanel::OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   // 控件点击事件 id=1000
   if(id == 1000)
   {
      // 手数减少按钮
      if(sparam == m_name+"BtnLotsDecrease")
      {
         OnClickLotsDecrease();
         return(true);
      }
      // 手数增加按钮
      if(sparam == m_name+"BtnLotsIncrease")
      {
         OnClickLotsIncrease();
         return(true);
      }
      // 现价买入按钮
      if(sparam == m_name+"BtnBuy")
      {
         OnClickBuy();
         return(true);
      }
      // 现价卖出按钮
      if(sparam == m_name+"BtnSell")
      {
         OnClickSell();
         return(true);
      }
      // 按点数设置止损
      if(sparam == m_name+"BtnSetSlPts") { OnClickSetSlPoints(); return(true); }
      // 按价格设置止损
      if(sparam == m_name+"BtnSetSlPrc") { OnClickSetSlPrice();  return(true); }
      // 按点数设置止盈
      if(sparam == m_name+"BtnSetTpPts") { OnClickSetTpPoints(); return(true); }
      // 按价格设置止盈
      if(sparam == m_name+"BtnSetTpPrc")     { OnClickSetTpPrice();    return(true); }
      // 50%平仓
      if(sparam == m_name+"BtnClose50")      { OnClickClose50();       return(true); }
      // 80%平仓
      if(sparam == m_name+"BtnClose80")      { OnClickClose80();       return(true); }
      // 100%平仓
      if(sparam == m_name+"BtnClose100")     { OnClickClose100();      return(true); }
      // 自定义比例平仓
      if(sparam == m_name+"BtnCloseCustom")   { OnClickCloseCustom();   return(true); }
      // 按手数平仓 快捷按钮
      if(sparam == m_name+"BtnCloseLot1")     { OnClickCloseLot1();     return(true); }
      if(sparam == m_name+"BtnCloseLot01")    { OnClickCloseLot01();    return(true); }
      if(sparam == m_name+"BtnCloseLot001")   { OnClickCloseLot001();   return(true); }
      // 按手数平仓 自定义
      if(sparam == m_name+"BtnCloseByLots")   { OnClickCloseByLots();   return(true); }
      // 平当前品种
      if(sparam == m_name+"BtnCloseSymbol")   { OnClickCloseSymbol();   return(true); }
      // 一键保本
      if(sparam == m_name+"BtnBreakEven")     { OnClickBreakEven();     return(true); }
      // 查看今日订单记录
      if(sparam == m_name+"BtnViewOrders")    { OnClickViewOrders();    return(true); }
      // 切换盈亏容器显示
      if(sparam == m_name+"BtnToggleProfit")  { OnClickToggleProfit();  return(true); }
      // 切换持仓容器显示
      if(sparam == m_name+"BtnTogglePos")     { OnClickTogglePositions(); return(true); }
      // 切换自动减仓开关
      if(sparam == m_name+"BtnToggleScaleOut") { OnClickToggleScaleOut(); return(true); }
      // 智能计算保本参数
      if(sparam == m_name+"BtnSmartCalc")     { OnClickSmartCalc();     return(true); }
      // 选择止损价格按钮 (NEW)
      if(sparam == m_name+"BtnSelectSL")      { OnClickSelectSL();      return(true); }
      // 选择止盈价格按钮 (NEW)
      if(sparam == m_name+"BtnSelectTP")      { OnClickSelectTP();      return(true); }
   }
   
   return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
}

//+------------------------------------------------------------------+
//| 现价买入                                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickBuy(void)
{
   // 检查交易权限
   if(!IsTradeAllowed())
   {
      Alert("交易未开启! 请在EA属性中勾选\"Allow live trading\"，并确认MT4右上角\"AutoTrading\"按钮已开启。");
      return;
   }
   
   double lots    = StringToDouble(m_edtLots.Text());
   double sl      = StringToDouble(m_edtStopLoss.Text());
   double tp      = StringToDouble(m_edtTakeProfit.Text());
   double price   = NormalizeDouble(Ask, _Digits);
   
   if(lots <= 0)
   {
      Alert("手数不能为0!");
      return;
   }
   
   // sl和tp为0时不设置
   double slPrice = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   double tpPrice = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
   
   int ticket = OrderSend(_Symbol, OP_BUY, lots, price, 3, slPrice, tpPrice,
                          "KTarget Panel Buy", 0, 0, clrBlue);
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "买入失败! 错误码=" + IntegerToString(err);
      if(err == 4109) errMsg += " (未开启交易权限，请开启AutoTrading)";
      if(err == 130)  errMsg += " (止损/止盈价格无效)";
      if(err == 131)  errMsg += " (手数无效)";
      if(err == 138)  errMsg += " (报价变动，重试)";
      Print(errMsg, " 价格=", price, " 止损=", slPrice, " 止盈=", tpPrice, " 手数=", lots);
      Alert(errMsg);
   }
   else
      Print("买入成功! 订单号=", ticket,
            " 价格=", price, " 止损=", slPrice, " 止盈=", tpPrice, " 手数=", lots);
}

//+------------------------------------------------------------------+
//| 现价卖出                                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSell(void)
{
   // 检查交易权限
   if(!IsTradeAllowed())
   {
      Alert("交易未开启! 请在EA属性中勾选\"Allow live trading\"，并确认MT4右上角\"AutoTrading\"按钮已开启。");
      return;
   }
   
   double lots    = StringToDouble(m_edtLots.Text());
   double sl      = StringToDouble(m_edtStopLoss.Text());
   double tp      = StringToDouble(m_edtTakeProfit.Text());
   double price   = NormalizeDouble(Bid, _Digits);
   
   if(lots <= 0)
   {
      Alert("手数不能为0!");
      return;
   }
   
   // sl和tp为0时不设置
   double slPrice = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   double tpPrice = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
   
   int ticket = OrderSend(_Symbol, OP_SELL, lots, price, 3, slPrice, tpPrice,
                          "KTarget Panel Sell", 0, 0, clrRed);
   if(ticket < 0)
   {
      int err = GetLastError();
      string errMsg = "卖出失败! 错误码=" + IntegerToString(err);
      if(err == 4109) errMsg += " (未开启交易权限，请开启AutoTrading)";
      if(err == 130)  errMsg += " (止损/止盈价格无效)";
      if(err == 131)  errMsg += " (手数无效)";
      if(err == 138)  errMsg += " (报价变动，重试)";
      Print(errMsg, " 价格=", price, " 止损=", slPrice, " 止盈=", tpPrice, " 手数=", lots);
      Alert(errMsg);
   }
   else
      Print("卖出成功! 订单号=", ticket,
            " 价格=", price, " 止损=", slPrice, " 止盈=", tpPrice, " 手数=", lots);
}

//+------------------------------------------------------------------+
//| 按点数设置止损（对当前品种所有持仓订单）                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSetSlPoints(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   
   int pts = (int)StringToInteger(m_edtSlPoints.Text());
   if(pts <= 0) { Alert("止损点数必须大于0!"); return; }
   
   int count = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      double newSL;
      if(OrderType() == OP_BUY)
         newSL = NormalizeDouble(OrderOpenPrice() - pts * _Point, _Digits);
      else
         newSL = NormalizeDouble(OrderOpenPrice() + pts * _Point, _Digits);
      
      if(OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrYellow))
         count++;
      else
      {
         Print("设置止损失败 订单=", OrderTicket(), " 错误=", GetLastError());
         failed++;
      }
   }
   if(count == 0 && failed == 0)
      Print("当前品种无持仓订单");
   else
      Print("按点数设置止损: 成功=", count, " 失败=", failed, " 点数=", pts);
   if(failed > 0) Alert("部分订单设置止损失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 按价格设置止损（对当前品种所有持仓订单）                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSetSlPrice(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   
   double slPrice = NormalizeDouble(StringToDouble(m_edtSlPrice2.Text()), _Digits);
   if(slPrice <= 0) { Alert("止损价格无效!"); return; }
   
   int count = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      if(OrderModify(OrderTicket(), OrderOpenPrice(), slPrice, OrderTakeProfit(), 0, clrYellow))
         count++;
      else
      {
         Print("设置止损失败 订单=", OrderTicket(), " 错误=", GetLastError());
         failed++;
      }
   }
   if(count == 0 && failed == 0)
      Print("当前品种无持仓订单");
   else
      Print("按价格设置止损: 成功=", count, " 失败=", failed, " 价格=", slPrice);
   if(failed > 0) Alert("部分订单设置止损失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 按点数设置止盈（对当前品种所有持仓订单）                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSetTpPoints(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   
   int pts = (int)StringToInteger(m_edtTpPoints.Text());
   if(pts <= 0) { Alert("止盈点数必须大于0!"); return; }
   
   int count = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      double newTP;
      if(OrderType() == OP_BUY)
         newTP = NormalizeDouble(OrderOpenPrice() + pts * _Point, _Digits);
      else
         newTP = NormalizeDouble(OrderOpenPrice() - pts * _Point, _Digits);
      
      if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), newTP, 0, clrAqua))
         count++;
      else
      {
         Print("设置止盈失败 订单=", OrderTicket(), " 错误=", GetLastError());
         failed++;
      }
   }
   if(count == 0 && failed == 0)
      Print("当前品种无持仓订单");
   else
      Print("按点数设置止盈: 成功=", count, " 失败=", failed, " 点数=", pts);
   if(failed > 0) Alert("部分订单设置止盈失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 按价格设置止盈（对当前品种所有持仓订单）                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSetTpPrice(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   
   double tpPrice = NormalizeDouble(StringToDouble(m_edtTpPrice2.Text()), _Digits);
   if(tpPrice <= 0) { Alert("止盈价格无效!"); return; }
   
   int count = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpPrice, 0, clrAqua))
         count++;
      else
      {
         Print("设置止盈失败 订单=", OrderTicket(), " 错误=", GetLastError());
         failed++;
      }
   }
   if(count == 0 && failed == 0)
      Print("当前品种无持仓订单");
   else
      Print("按价格设置止盈: 成功=", count, " 失败=", failed, " 价格=", tpPrice);
   if(failed > 0) Alert("部分订单设置止盈失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 比例平仓核心函数                                                   |
//+------------------------------------------------------------------+
void CTradePanel::CloseByPercent(double pct)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }
   if(pct <= 0 || pct > 100) { Alert("比例必须在 1~100 之间!"); return; }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // 先收集所有持仓信息，避免平仓后索引漂移
   int    tickets[];
   double lotsArr[];
   int    typesArr[];
   int    n = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      ArrayResize(tickets,  n+1);
      ArrayResize(lotsArr,  n+1);
      ArrayResize(typesArr, n+1);
      tickets[n]  = OrderTicket();
      lotsArr[n]  = OrderLots();
      typesArr[n] = OrderType();
      n++;
   }
   if(n == 0) { Print("当前品种无持仓订单"); return; }

   int count = 0, failed = 0;
   for(int i = 0; i < n; i++)
   {
      // 计算应平手数，向下取整到手数步长
      double closeLots = MathFloor(lotsArr[i] * pct / 100.0 / lotStep) * lotStep;
      closeLots = NormalizeDouble(closeLots, 2);
      if(closeLots < minLot)     closeLots = minLot;       // 至少平最小手
      if(closeLots > lotsArr[i]) closeLots = lotsArr[i];   // 不超过持仓手数

      double closePrice = (typesArr[i] == OP_BUY)
                          ? NormalizeDouble(Bid, _Digits)
                          : NormalizeDouble(Ask, _Digits);

      if(OrderClose(tickets[i], closeLots, closePrice, 3, clrOrange))
         count++;
      else
      {
         Print("平仓失败 订单=", tickets[i], " 手数=", closeLots,
               " 错误码=", GetLastError());
         failed++;
      }
   }
   Print("比例平仓完成: 比例=", pct, "% 成功=", count, " 失败=", failed);
   if(failed > 0) Alert("部分订单平仓失败! 失败数=" + IntegerToString(failed));
}

void CTradePanel::OnClickClose50(void)     { CloseByPercent(50.0);  }
void CTradePanel::OnClickClose80(void)     { CloseByPercent(80.0);  }
void CTradePanel::OnClickClose100(void)    { CloseByPercent(100.0); }

void CTradePanel::OnClickCloseCustom(void)
{
   double pct = StringToDouble(m_edtClosePct.Text());
   if(pct <= 0 || pct > 100)
   {
      Alert("比例必须在 1~100 之间! 当前输入=" + m_edtClosePct.Text());
      return;
   }
   CloseByPercent(pct);
}

//+------------------------------------------------------------------+
//| 按手数平仓核心函数                                                  |
//+------------------------------------------------------------------+
void CTradePanel::CloseLots(double lots)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // 归一化到步长
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = NormalizeDouble(lots, 2);
   if(lots < minLot)
   {
      Alert("平仓手数不能小于最小手数 " + DoubleToString(minLot,2));
      return;
   }

   // 收集持仓，按手数从小到大排序（优先平手数小的单子）
   int    tickets[];
   double lotsArr[];
   int    typesArr[];
   int    n = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      ArrayResize(tickets,  n+1);
      ArrayResize(lotsArr,  n+1);
      ArrayResize(typesArr, n+1);
      tickets[n]  = OrderTicket();
      lotsArr[n]  = OrderLots();
      typesArr[n] = OrderType();
      n++;
   }
   if(n == 0) { Print("当前品种无持仓订单"); return; }

   double remaining = lots;
   int count = 0, failed = 0;

   for(int i = 0; i < n && remaining >= minLot; i++)
   {
      double closeThis = MathMin(lotsArr[i], remaining);
      closeThis = MathFloor(closeThis / lotStep) * lotStep;
      closeThis = NormalizeDouble(closeThis, 2);
      if(closeThis < minLot) continue;

      double closePrice = (typesArr[i] == OP_BUY)
                          ? NormalizeDouble(Bid, _Digits)
                          : NormalizeDouble(Ask, _Digits);

      if(OrderClose(tickets[i], closeThis, closePrice, 3, clrViolet))
      {
         remaining = NormalizeDouble(remaining - closeThis, 2);
         count++;
      }
      else
      {
         Print("平仓失败 订单=", tickets[i], " 手数=", closeThis,
               " 错误码=", GetLastError());
         failed++;
      }
   }
   if(remaining > minLot)
      Print("注意: 持仓不足, 尚有 ", remaining, " 手未平。共平仓单数=", count, " 失败=", failed);
   else
      Print("手数平仓完成: 平入=", lots, " 手 成功单数=", count, " 失败=", failed);
   if(failed > 0) Alert("部分订单平仓失败! 失败数=" + IntegerToString(failed));
}

void CTradePanel::OnClickCloseLot1(void)   { CloseLots(1.0);  }
void CTradePanel::OnClickCloseLot01(void)  { CloseLots(0.1);  }
void CTradePanel::OnClickCloseLot001(void) { CloseLots(0.01); }

void CTradePanel::OnClickCloseByLots(void)
{
   double lots = StringToDouble(m_edtCloseLots.Text());
   if(lots <= 0)
   {
      Alert("手数必须大于0! 当前输入=" + m_edtCloseLots.Text());
      return;
   }
   CloseLots(lots);
}

//+------------------------------------------------------------------+
//| 平当前品种所有持仓订单                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickCloseSymbol(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   int    tickets[];
   double lotsArr[];
   int    typesArr[];
   int    n = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      ArrayResize(tickets,  n+1);
      ArrayResize(lotsArr,  n+1);
      ArrayResize(typesArr, n+1);
      tickets[n]  = OrderTicket();
      lotsArr[n]  = OrderLots();
      typesArr[n] = OrderType();
      n++;
   }
   if(n == 0) { Print("当前品种无持仓订单"); return; }

   int count = 0, failed = 0;
   for(int i = 0; i < n; i++)
   {
      double closePrice = (typesArr[i] == OP_BUY)
                          ? NormalizeDouble(Bid, _Digits)
                          : NormalizeDouble(Ask, _Digits);
      if(OrderClose(tickets[i], lotsArr[i], closePrice, 3, clrRed))
         count++;
      else
      {
         Print("平仓失败 订单=", tickets[i], " 错误码=", GetLastError());
         failed++;
      }
   }
   Print("平当前品种完成: 成功=", count, " 失败=", failed);
   if(failed > 0) Alert("部分订单平仓失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 一键保本（将本品种所有持仓订单的止损设置为开仓价）          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickBreakEven(void)
{
   if(!IsTradeAllowed()) { Alert("交易未开启! 请开启AutoTrading"); return; }

   int count = 0, skipped = 0, failed = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      double openPrice = OrderOpenPrice();
      double curSL     = OrderStopLoss();

      // 已经是保本或止损优于开仓价则跳过
      if(OrderType() == OP_BUY  && curSL >= openPrice) { skipped++; continue; }
      if(OrderType() == OP_SELL && curSL <= openPrice && curSL > 0) { skipped++; continue; }

      double beSL = NormalizeDouble(openPrice, _Digits);
      if(OrderModify(OrderTicket(), openPrice, beSL, OrderTakeProfit(), 0, clrCyan))
         count++;
      else
      {
         Print("保本设置失败 订单=", OrderTicket(), " 错误=", GetLastError());
         failed++;
      }
   }
   if(count == 0 && failed == 0 && skipped == 0)
      Print("当前品种无持仓订单");
   else
      Print("一键保本: 成功=", count, " 跳过已保本=", skipped, " 失败=", failed);
   if(failed > 0) Alert("部分订单保本失败! 失败数=" + IntegerToString(failed));
}

//+------------------------------------------------------------------+
//| 查看今日订单（切换侧边订单面板）                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickViewOrders(void)
{
   if(!g_ordersCreated)
   {
      // 首次打开：统计今日订单数、动态计算高度、创建面板（只创建一次）
      int      serverGMT  = (int)((TimeCurrent() - TimeGMT()) / 3600);
      int      bjOffset   = (8 - serverGMT) * 3600;
      datetime bjNow      = (datetime)(TimeCurrent() + bjOffset);
      datetime bjToday0   = bjNow - (bjNow % 86400);
      datetime svrToday0  = (datetime)(bjToday0 - bjOffset);

      int todayCnt = 0;
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != _Symbol) continue;
         if(OrderType() == OP_BUY || OrderType() == OP_SELL) todayCnt++;
      }
      for(int i = OrdersHistoryTotal()-1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
         if(OrderSymbol() != _Symbol) continue;
         if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
         if(OrderCloseTime() >= svrToday0) todayCnt++;
      }
      int rows   = MathMax(todayCnt, 3);
      int panelH = 43 + rows * 17 + 36;

      int ox = PanelX + 510;
      int oy = PanelY;
      g_ordersPanel.SetMaxRows(rows);
      if(!g_ordersPanel.Create(0,"OrdersPanel",0,ox,oy,ox+600,oy+panelH))
      {
         Print("创建订单记录面板失败!");
         return;
      }
      g_ordersPanel.Run();
      g_ordersPanel.RefreshOrders();
      g_ordersCreated      = true;
      g_ordersPanelVisible = true;
      m_btnViewOrders.Text("隐藏今日订单记录");
      // Create() 完成后面板已可见，直接返回
      return;
   }

   // 面板已创建过：用 Hide/Show 切换，绝不调用 Destroy
   // （Destroy 会触发 ON_APP_CLOSE 自定义事件级联销毁主面板）
   if(!g_ordersPanelVisible)
   {
      g_ordersPanel.RefreshOrders();
      g_ordersPanel.Show();
      g_ordersPanelVisible = true;
      m_btnViewOrders.Text("隐藏今日订单记录");
   }
   else
   {
      g_ordersPanel.Hide();
      g_ordersPanelVisible = false;
      m_btnViewOrders.Text("查看今日订单记录");
   }
}

//+------------------------------------------------------------------+
//| 切换盈亏容器显示                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickToggleProfit(void)
{
   m_showProfit = !m_showProfit;
   
   if(m_showProfit)
   {
      UpdateInfoContainers();              // 重新加载数据
      m_btnToggleProfit.Text("隐藏");
   }
   else
   {
      m_edtDailyProfit.Text("[ 已隐藏 ]");
      m_edtDailyProfit.ColorBackground(clrLightGray);
      m_edtDailyProfit.ColorBorder(clrGray);
      m_btnToggleProfit.Text("显示");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 切换持仓容器显示                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickTogglePositions(void)
{
   m_showPositions = !m_showPositions;
   
   if(m_showPositions)
   {
      UpdateInfoContainers();              // 重新加载数据
      m_btnTogglePositions.Text("隐藏");
   }
   else
   {
      m_edtPositions.Text("[ 已隐藏 ]");
      m_edtPositions.ColorBackground(clrLightGray);
      m_edtPositions.ColorBorder(clrGray);
      m_btnTogglePositions.Text("显示");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 更新信息容器                                                      |
//+------------------------------------------------------------------+
void CTradePanel::UpdateInfoContainers(void)
{
   // 更新盈亏容器
   if(m_showProfit)
   {
      double dailyProfit = CalculateDailyProfit();
      double balance = AccountBalance();
      // === 【修复】正确计算百分比：相对于今日起始余额，而不是当前余额 ===
      double startBalance = balance - dailyProfit;  // 今日起始余额 = 当前余额 - 今日盈亏
      double profitPercent = (startBalance > 0) ? (dailyProfit / startBalance * 100) : 0;
      
      string profitText = StringFormat("今日盈亏: %s$%.2f (%s%.2f%%)",
         dailyProfit >= 0 ? "+" : "",
         dailyProfit,
         profitPercent >= 0 ? "+" : "",
         profitPercent);
      m_edtDailyProfit.Text(profitText);
      
      // 动态变色
      if(dailyProfit >= 0)
      {
         m_edtDailyProfit.ColorBackground(clrHoneydew);
         m_edtDailyProfit.ColorBorder(clrGreen);
      }
      else
      {
         m_edtDailyProfit.ColorBackground(clrMistyRose);
         m_edtDailyProfit.ColorBorder(clrRed);
      }
   }
   
   // 更新持仓容器
   if(m_showPositions)
   {
      string posText = GetCurrentPositions();
      m_edtPositions.Text(posText);
   }
}

//+------------------------------------------------------------------+
//| 计算今日盈亏                                                      |
//+------------------------------------------------------------------+
double CTradePanel::CalculateDailyProfit(void)
{
   // 计算今日北京时间起始点
   int      serverGMT  = (int)((TimeCurrent() - TimeGMT()) / 3600);
   int      bjOffset   = (8 - serverGMT) * 3600;
   datetime bjNow      = (datetime)(TimeCurrent() + bjOffset);
   datetime bjToday0   = bjNow - (bjNow % 86400);
   datetime svrToday0  = (datetime)(bjToday0 - bjOffset);
   
   double totalProfit = 0;
   
   // 统计当前持仓（今日开仓的）
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderOpenTime() >= svrToday0)  // 今日开仓
      {
         totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   
   // 统计今日已平仓订单
   for(int i = OrdersHistoryTotal()-1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderCloseTime() >= svrToday0)  // 今日平仓
      {
         totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| 获取当前持仓价格                                                  |
//+------------------------------------------------------------------+
string CTradePanel::GetCurrentPositions(void)
{
   string buyPrices = "";
   string sellPrices = "";
   int buyCount = 0;
   int sellCount = 0;
   
   // 遍历当前持仓
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      
      if(OrderType() == OP_BUY)
      {
         if(buyCount > 0) buyPrices += ", ";
         buyPrices += DoubleToString(OrderOpenPrice(), _Digits);
         buyCount++;
      }
      else if(OrderType() == OP_SELL)
      {
         if(sellCount > 0) sellPrices += ", ";
         sellPrices += DoubleToString(OrderOpenPrice(), _Digits);
         sellCount++;
      }
   }
   
   // 组装显示文本
   string result = "持仓: ";
   if(buyCount == 0 && sellCount == 0)
   {
      result += "无持仓";
   }
   else
   {
      if(buyCount > 0)
         result += "买" + IntegerToString(buyCount) + " [" + buyPrices + "]";
      if(buyCount > 0 && sellCount > 0)
         result += " | ";
      if(sellCount > 0)
         result += "卖" + IntegerToString(sellCount) + " [" + sellPrices + "]";
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| 切换自动减仓开关                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickToggleScaleOut(void)
{
   m_scaleOutEnabled = !m_scaleOutEnabled;
   
   if(m_scaleOutEnabled)
   {
      m_btnToggleScaleOut.Text("关闭自动减仓");
      m_btnToggleScaleOut.ColorBackground(clrOrangeRed);
      Print(" 自动减仓功能已开启");
   }
   else
   {
      m_btnToggleScaleOut.Text("开启自动减仓");
      m_btnToggleScaleOut.ColorBackground(clrLightGray);
      Print(" 自动减仓功能已关闭");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 智能计算保本参数                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSmartCalc(void)
{
   // 检查是否有持仓
   bool found = false;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      found = true;
      
      // 获取订单参数
      double openPrice = OrderOpenPrice();
      double stopLoss = OrderStopLoss();
      double lots = OrderLots();
      
      if(stopLoss == 0)
      {
         Alert("订单 ", OrderTicket(), " 没有设置止损，无法计算！");
         continue;
      }
      
      // 计算止损风险（点数）
      double slDiff = (OrderType() == OP_BUY) ? 
                      (openPrice - stopLoss) :
                      (stopLoss - openPrice);
      int slPts = (int)(slDiff / _Point);
      
      // 计算最大亏损金额
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double maxLoss = slDiff * lots / _Point * tickValue;
      
      // 智能计算：假设减仓 80%
      double scalePct = 80.0;
      double remainPct = 100.0 - scalePct;
      
      // 剩余仓位如果止损的亏损
      double remainLoss = maxLoss * remainPct / 100.0;
      
      // 计算需要走多少点（减仓部分获利 = 剩余部分风险）
      // scalePct% × triggerPts = remainPct% × slPts
      // triggerPts = remainPct × slPts / scalePct
      int triggerPts = (int)(remainPct * slPts / scalePct);
      
      // 更新UI
      m_edtTriggerPts.Text(IntegerToString(triggerPts));
      m_edtScalePct.Text(DoubleToString(scalePct, 0));
      
      string msg = StringFormat(
         "智能计算完成！\n\n"
         "订单: %d\n"
         "手数: %.2f\n"
         "止损点数: %d 点\n"
         "最大风险: $%.2f\n\n"
         "建议参数：\n"
         "触发点数: %d 点\n"
         "减仓比例: %.0f%%\n\n"
         "逻辑：走出 %d 点后减仓 %.0f%%，\n"
         "锁定利润 $%.2f，可覆盖剩余仓位风险 $%.2f",
         OrderTicket(), lots, slPts, maxLoss,
         triggerPts, scalePct,
         triggerPts, scalePct, remainLoss, remainLoss
      );
      
      Alert(msg);
      Print(msg);
      /*
      // === 自动开启减仓功能 ===
      if(!m_scaleOutEnabled)
      {
         m_scaleOutEnabled = true;
         m_btnToggleScaleOut.Text("关闭自动减仓");
         m_btnToggleScaleOut.ColorBackground(clrOrangeRed);
         Print(" [智能计算] 自动减仓功能已自动开启");
         
         // 更新提示信息
         Comment("【智能计算完成】\n参数已更新，自动减仓已启动！");
      }
      else
      {
         Print(" [智能计算] 自动减仓已在运行中，参数已更新");
         Comment("【智能计算完成】\n参数已更新，自动减仓继续运行！");
      }
      
      ChartRedraw();
      */
      break;  // 只计算第一个订单
   }
   
   if(!found)
   {
      Alert("当前品种没有持仓订单！");
   }
}

//+------------------------------------------------------------------+
//| 检查并执行自动减仓                                                |
//+------------------------------------------------------------------+
void CTradePanel::CheckAutoScaleOut(void)
{
   if(!m_scaleOutEnabled) return;  // 功能未开启
   
   // 读取参数
   int triggerPts = (int)StringToInteger(m_edtTriggerPts.Text());
   double scalePct = StringToDouble(m_edtScalePct.Text());
   double scaleLots = StringToDouble(m_edtScaleLots.Text());
   
   if(triggerPts <= 0)
   {
      Print(" 触发点数无效，已跳过检测");
      return;
   }
   
   // 定期清理已关闭订单
   CleanupScaledOrders();
   
   // 遍历所有持仓订单
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      int ticket = OrderTicket();
      
      // 检查是否已减仓
      if(IsOrderScaled(ticket)) continue;
      
      // 计算浮盈点数
      double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
      double diff = (OrderType() == OP_BUY) ? 
                    (currentPrice - OrderOpenPrice()) :
                    (OrderOpenPrice() - currentPrice);
      int profitPts = (int)(diff / _Point);
      
      // 达到触发条件？
      if(profitPts >= triggerPts)
      {
         ExecuteScaleOut(ticket, scalePct, scaleLots);
      }
   }
}

//+------------------------------------------------------------------+
//| 执行减仓                                                          |
//+------------------------------------------------------------------+
void CTradePanel::ExecuteScaleOut(int ticket, double pct, double lots)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   // 计算减仓手数
   double currentLots = OrderLots();
   double closeAmount = 0;
   
   // 优先使用比例，如果比例为0则使用固定手数
   if(pct > 0)
   {
      closeAmount = NormalizeDouble(currentLots * pct / 100.0, 2);
   }
   else if(lots > 0)
   {
      closeAmount = lots;
   }
   else
   {
      Print(" 减仓参数无效");
      return;
   }
   
   // 确保手数符合规范
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   closeAmount = MathFloor(closeAmount / lotStep) * lotStep;
   
   // 确保不超过当前手数，并至少保留最小手数
   if(closeAmount >= currentLots)
   {
      closeAmount = currentLots - minLot;
      if(closeAmount < minLot)
      {
         Print(" 订单 ", ticket, " 仓位太小，无法减仓");
         return;
      }
   }
   
   // 执行部分平仓
   double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
   bool result = OrderClose(ticket, closeAmount, closePrice, 3);
   
   if(result)
   {
      // 记录已减仓（使用开仓时间）
      m_scaledOpenTimes[m_scaledCount++] = OrderOpenTime();
      
      // === 详细调试信息（NEW）===
      Print("========== 自动减仓利润计算调试 ==========");
      Print(" OrderOpenPrice: ", DoubleToString(OrderOpenPrice(), _Digits));
      Print(" closePrice: ", DoubleToString(closePrice, _Digits));
      
      // 计算锁定利润
      double profit = (OrderType() == OP_BUY) ? 
                      (closePrice - OrderOpenPrice()) :
                      (OrderOpenPrice() - closePrice);
      Print(" profit (价格差): ", DoubleToString(profit, _Digits));
      Print(" closeAmount (减仓手数): ", DoubleToString(closeAmount, 2));
      Print(" _Point: ", DoubleToString(_Point, _Digits));
      
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      Print(" SYMBOL_TRADE_TICK_VALUE: ", DoubleToString(tickValue, 4));
      Print(" SYMBOL_TRADE_TICK_SIZE: ", DoubleToString(tickSize, _Digits));
      Print(" SYMBOL_TRADE_CONTRACT_SIZE: ", DoubleToString(contractSize, 0));
      
      double lockedProfit = profit * closeAmount / _Point * tickValue;
      Print(" lockedProfit (当前公式): ", DoubleToString(lockedProfit, 2));
      
      // 使用标准公式重新计算
      double standardProfit = profit * closeAmount * contractSize;
      Print(" standardProfit (标准公式): ", DoubleToString(standardProfit, 2));
      Print("==========================================");
      
      Print(" 自动减仓成功: Ticket=", ticket, 
            " 减仓=", closeAmount, " 手，锁定利润=$", DoubleToString(lockedProfit, 2));
      
      // 发送通知
      string msg = StringFormat(" 自动减仓\nTicket: %d\n减仓: %.2f 手\n利润: $%.2f",
                                ticket, closeAmount, lockedProfit);
      Comment(msg);
   }
   else
   {
      int error = GetLastError();
      Print(" 自动减仓失败: Ticket=", ticket, " Error=", error);
   }
}

//+------------------------------------------------------------------+
//| 检查订单是否已减仓                                                |
//+------------------------------------------------------------------+
bool CTradePanel::IsOrderScaled(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   datetime openTime = OrderOpenTime();
   
   for(int i = 0; i < m_scaledCount; i++)
   {
      if(m_scaledOpenTimes[i] == openTime) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| 清理已关闭订单记录                                                |
//+------------------------------------------------------------------+
void CTradePanel::CleanupScaledOrders(void)
{
   for(int i = m_scaledCount - 1; i >= 0; i--)
   {
      datetime openTime = m_scaledOpenTimes[i];
      bool found = false;
      
      // 检查这个开仓时间的订单是否还存在
      for(int j = 0; j < OrdersTotal(); j++)
      {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderOpenTime() == openTime)
         {
            found = true;
            break;
         }
      }
      
      // 如果订单已关闭，从数组中移除
      if(!found)
      {
         for(int j = i; j < m_scaledCount - 1; j++)
         {
            m_scaledOpenTimes[j] = m_scaledOpenTimes[j + 1];
         }
         m_scaledCount--;
      }
   }
}

//+------------------------------------------------------------------+
//| 手数减少                                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickLotsDecrease(void)
{
   double currentLots = StringToDouble(m_edtLots.Text());
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   currentLots -= lotStep;
   if(currentLots < minLot)
      currentLots = minLot;
   
   string newValue = DoubleToString(currentLots, 2);
   m_edtLots.Text(newValue);
   
   Print("手数减少: 当前值=", currentLots, " 最小=", minLot, " 步长=", lotStep);
   
   // 强制刷新控件
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 手数增加                                                          |
//+------------------------------------------------------------------+
void CTradePanel::OnClickLotsIncrease(void)
{
   double currentLots = StringToDouble(m_edtLots.Text());
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   currentLots += lotStep;
   if(currentLots > maxLot)
      currentLots = maxLot;
   
   string newValue = DoubleToString(currentLots, 2);
   m_edtLots.Text(newValue);
   
   Print("手数增加: 当前值=", currentLots, " 最大=", maxLot, " 步长=", lotStep);
   
   // 强制刷新控件
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 点击选择止损按钮                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSelectSL(void)
{
   // 激活止损选择模式
   g_priceSelectMode = MODE_SELECT_SL;
   g_lastButtonClickTime = GetTickCount();  // 记录时间戳（防穿透）
   
   // 视觉反馈：按钮高亮
   m_btnSelectSL.ColorBackground(clrYellow);
   
   // 禁用鼠标滚动（避免误操作）
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   
   // 显示提示
   Comment("【选择止损价格】\n请点击图表任意位置...\n(将自动磁吸到最近的High/Low)");
   
   ChartRedraw();
   PlaySound("tick.wav");
}

//+------------------------------------------------------------------+
//| 点击选择止盈按钮                                                  |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSelectTP(void)
{
   // 激活止盈选择模式
   g_priceSelectMode = MODE_SELECT_TP;
   g_lastButtonClickTime = GetTickCount();  // 记录时间戳（防穿透）
   
   // 视觉反馈：按钮高亮
   m_btnSelectTP.ColorBackground(clrYellow);
   
   // 禁用鼠标滚动（避免误操作）
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   
   // 显示提示
   Comment("【选择止盈价格】\n请点击图表任意位置...\n(将自动磁吸到最近的High/Low)");
   
   ChartRedraw();
   PlaySound("tick.wav");
}

//+------------------------------------------------------------------+
//| 设置止损价格（公共方法）                                          |
//+------------------------------------------------------------------+
void CTradePanel::SetStopLossPrice(double price)
{
   m_edtStopLoss.Text(DoubleToString(price, _Digits));
}

//+------------------------------------------------------------------+
//| 设置止盈价格（公共方法）                                          |
//+------------------------------------------------------------------+
void CTradePanel::SetTakeProfitPrice(double price)
{
   m_edtTakeProfit.Text(DoubleToString(price, _Digits));
}

//+------------------------------------------------------------------+
//| 重置选择按钮颜色（公共方法）                                      |
//+------------------------------------------------------------------+
void CTradePanel::ResetSelectButton(int mode)
{
   if(mode == MODE_SELECT_SL)
      m_btnSelectSL.ColorBackground(clrLightGray);
   else if(mode == MODE_SELECT_TP)
      m_btnSelectTP.ColorBackground(clrLightGray);
}

//+------------------------------------------------------------------+
//| 全局变量                                                          |
//+------------------------------------------------------------------+
CTradePanel  g_tradePanel;
COrdersPanel g_ordersPanel;
bool         g_ordersPanelVisible = false;  // 当前是否可见
bool         g_ordersCreated      = false;  // 是否已创建过（Create 只调用一次）
// bool        g_allowNextMouseMove = false; // 点击后允许下一次鼠标释放事件通过

//+------------------------------------------------------------------+
//| 全局常量：EA 对象命名前缀                                          |
//+------------------------------------------------------------------+
string EA_OBJECT_PREFIX = "KT_EA_Panel_";

//+------------------------------------------------------------------+
//| 更新EA止损标签（实时显示现价±5美金的止损位置）                    |
//+------------------------------------------------------------------+
void UpdateEA_SL_Display()
{
   if(!Show_EA_SL_Labels) return; // 用户关闭功能
   
   // 1. 计算止损价格（现价 ± SL_Distance_Dollars 美金）
   double current_price = (Bid + Ask) / 2.0;
   double sl_distance = SL_Distance_Dollars;
   
   // 应用偏移量避免与指标重叠
   double buy_sl_price = current_price - sl_distance - Label_Offset;  // 做多止损（下方）
   double sell_sl_price = current_price + sl_distance + Label_Offset; // 做空止损（上方）
   
   datetime current_time = Time[0]; // 当前K线时间
   
   // 2. 创建/更新 Buy SL 标签（做多止损，显示在下方）
   string buy_label_name = EA_OBJECT_PREFIX + "Buy_SL_Label";
   if(ObjectFind(0, buy_label_name) == -1)
   {
      // 首次创建
      ObjectCreate(0, buy_label_name, OBJ_ARROW_RIGHT_PRICE, 0, current_time, buy_sl_price);
      ObjectSetInteger(0, buy_label_name, OBJPROP_COLOR, Buy_SL_Color);
      ObjectSetInteger(0, buy_label_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, buy_label_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, buy_label_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, buy_label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, buy_label_name, OBJPROP_HIDDEN, true);
   }
   else
   {
      // 更新位置
      ObjectSetInteger(0, buy_label_name, OBJPROP_TIME, 0, current_time);
      ObjectSetDouble(0, buy_label_name, OBJPROP_PRICE, 0, buy_sl_price);
   }
   
   // 3. 创建/更新 Sell SL 标签（做空止损，显示在上方）
   string sell_label_name = EA_OBJECT_PREFIX + "Sell_SL_Label";
   if(ObjectFind(0, sell_label_name) == -1)
   {
      // 首次创建
      ObjectCreate(0, sell_label_name, OBJ_ARROW_RIGHT_PRICE, 0, current_time, sell_sl_price);
      ObjectSetInteger(0, sell_label_name, OBJPROP_COLOR, Sell_SL_Color);
      ObjectSetInteger(0, sell_label_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, sell_label_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, sell_label_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, sell_label_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, sell_label_name, OBJPROP_HIDDEN, true);
   }
   else
   {
      // 更新位置
      ObjectSetInteger(0, sell_label_name, OBJPROP_TIME, 0, current_time);
      ObjectSetDouble(0, sell_label_name, OBJPROP_PRICE, 0, sell_sl_price);
   }
}

//+------------------------------------------------------------------+
//| 清理EA止损标签                                                    |
//+------------------------------------------------------------------+
void CleanupEA_SL_Labels()
{
   // 删除所有以 EA_OBJECT_PREFIX 开头的对象
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string obj_name = ObjectName(i);
      if(StringFind(obj_name, EA_OBJECT_PREFIX) == 0) // 检查前缀
      {
         ObjectDelete(0, obj_name);
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 创建面板（高度638：原432 + 信息容器90 + 自动减仓模块116）
   if(!g_tradePanel.Create(0,"TradePanelEA",0,PanelX,PanelY,PanelX+500,PanelY+638))
   {
      Print("创建交易面板失败!");
      return(INIT_FAILED);
   }
   
   // 运行面板
   g_tradePanel.Run();
   
   Print("交易面板EA已启动");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // 清理EA止损标签
   CleanupEA_SL_Labels();
   
   // 销毁面板（OnDeinit 时 EA 本身已在退出，不会再处理图表事件，无级联风险）
   if(g_ordersCreated)
   {
      g_ordersPanel.Destroy(reason);
      g_ordersCreated      = false;
      g_ordersPanelVisible = false;
   }
   g_tradePanel.Destroy(reason);
   Print("交易面板EA已停止");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 更新信息容器（每次tick刷新数据）
   static datetime lastUpdate = 0;
   if(TimeCurrent() != lastUpdate)  // 每秒最多更新一次
   {
      g_tradePanel.UpdateInfoContainers();
      lastUpdate = TimeCurrent();
   }
   
   // 检查自动减仓（每个tick都检查）
   g_tradePanel.CheckAutoScaleOut();
   
   // 更新EA止损标签（实时显示）
   UpdateEA_SL_Display();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   /*
   // 每次有对象被点击，标记允许下一次鼠标释放事件通过
   // 原因：MQL4 Controls库的CButton是在收到鼠标释放(CHARTEVENT_MOUSE_MOVE sparam="0")
   // 之后才真正触发ON_CLICK(id=1000)，必须允许这个释放事件通过
   if(id == CHARTEVENT_OBJECT_CLICK)
      g_allowNextMouseMove = true;
   
   // 对于纯悬停移动事件(sparam="0"无按键按下)进行过滤
   if(id == CHARTEVENT_MOUSE_MOVE && sparam == "0")
   {
      if(!g_allowNextMouseMove)
         return; // 过滤纯悬停移动，避免触发控件重绘导致输入框闪烁
      g_allowNextMouseMove = false; // 允许过一次后重置，下次继续过滤
   }
   
   // sparam!="0"的鼠标移动（拖拽面板）正常传递
   g_tradePanel.ChartEvent(id,lparam,dparam,sparam);
   */

   // === [NEW] 处理图表点击事件（价格选择） ===
   if(id == CHARTEVENT_CLICK && g_priceSelectMode != MODE_NONE)
   {
      // 防穿透：如果距离按钮点击时间不到300ms，忽略
      if(GetTickCount() - g_lastButtonClickTime < 300)
         return;
      
      // 获取点击位置的价格
      datetime time;
      double price;
      int sub_window;
      
      if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, sub_window, time, price))
      {
         // === 可选：磁吸到最近的High/Low（提升精度） ===
         int barIndex = iBarShift(NULL, 0, time);
         double high = iHigh(NULL, 0, barIndex);
         double low = iLow(NULL, 0, barIndex);
         
         double finalPrice = price;
         // 简单磁吸：选最近的High或Low
         if(MathAbs(price - high) < MathAbs(price - low))
            finalPrice = high;
         else
            finalPrice = low;
         
         // 填入对应的输入框（使用公共方法）
         if(g_priceSelectMode == MODE_SELECT_SL)
         {
            g_tradePanel.SetStopLossPrice(finalPrice);
            g_tradePanel.ResetSelectButton(MODE_SELECT_SL);
         }
         else if(g_priceSelectMode == MODE_SELECT_TP)
         {
            g_tradePanel.SetTakeProfitPrice(finalPrice);
            g_tradePanel.ResetSelectButton(MODE_SELECT_TP);
         }
         
         // 退出选择模式
         g_priceSelectMode = MODE_NONE;
         Comment("");  // 清除提示
         ChartSetInteger(0, CHART_MOUSE_SCROLL, true);  // 恢复滚动
         
         PlaySound("ok.wav");  // 音效反馈
         ChartRedraw();
      }
      
      return;  // 不再传递给面板
   }
   
   // === 传递事件给面板处理（原有逻辑） ===
   g_tradePanel.ChartEvent(id,lparam,dparam,sparam);
   if(g_ordersCreated && g_ordersPanelVisible)
      g_ordersPanel.ChartEvent(id,lparam,dparam,sparam);
}
//+------------------------------------------------------------------+
