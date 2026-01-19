//+------------------------------------------------------------------+
//|                                             KT_Line_Analyzer.mq4 |
//|                                  Copyright 2024, CD_SMC_Analysis |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "CD_SMC_Analysis"
#property version   "1.00"
#property strict
#property indicator_chart_window

//--- 输入参数
input color  InpTextColor   = clrYellow;  // 统计文字颜色
input int    InpTextSize    = 10;         // 文字大小
input int    InpRefreshRate = 1;          // 刷新频率(秒) - 越小越流畅但耗资源

//--- 全局变量
string Prefix_Draw = "Draw_";
string Prefix_Mark = "Mark_";
string Prefix_Info = "Info_";

//+------------------------------------------------------------------+
//| 初始化函数
//+------------------------------------------------------------------+
int OnInit()
{
   // 开启定时器，定期扫描图表对象
   EventSetTimer(InpRefreshRate);
   
   IndicatorShortName("KT Line Analyzer (Crossover Counter)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 反初始化函数
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   // 移除所有由本指标生成的统计文字
   DeleteAllInfoObjects();
}

//+------------------------------------------------------------------+
//| 定时器事件 (核心驱动)
//+------------------------------------------------------------------+
void OnTimer()
{
   ScanAndAnalyzeLines();
}

//+------------------------------------------------------------------+
//| 主计算函数 (本次不需要，因为是基于对象的分析)
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // 如果不想用 Timer，也可以在这里调用 ScanAndAnalyzeLines();
   // 但为了性能，推荐用 OnTimer
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 核心功能：扫描水平线并计算穿越次数
//+------------------------------------------------------------------+
void ScanAndAnalyzeLines()
{
   // 获取图表上对象总数
   int total = ObjectsTotal(0, -1, -1);
   
   // 用于标记哪些 Info 对象是本次扫描有效的 (用于清理过期的 Info)
   // 由于 MQL4 没有简便的 Map/List，这里我们简化处理：
   // 每次直接根据 Draw 对象更新 Info。如果 Draw 对象没了，Info 需要单独清理。
   // 为了简单健壮，我们在 DeleteAllInfoObjects 中提供清理，或者依赖用户手动刷新。
   // 更高级的做法是维护一个列表，但对于辅助工具，实时扫描即可。

   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i);
      
      // 1. 筛选条件：必须是 KT 工具画出的水平线
      // 命名规则: Draw_TF_ID (例如 Draw_H1_12345678)
      if(StringFind(name, Prefix_Draw) == 0 && ObjectType(name) == OBJ_HLINE)
      // if(StringFind(name, Prefix_Draw) == 0 && ObjectType(0, name) == OBJ_HLINE)
      {
         // ==========================================
         // 步骤 A: 获取水平线信息
         // ==========================================
         double linePrice = ObjectGetDouble(0, name, OBJPROP_PRICE);
         
         // ==========================================
         // 步骤 B: 寻找配对的“磁吸K线” (通过 ID 匹配 Mark 对象)
         // ==========================================
         // 提取后缀 ID：从 "Draw_" 后面开始截取
         // Draw_ 长度是 5。
         // 例子：name = "Draw_H1_176231" -> suffix = "H1_176231"
         string suffix = StringSubstr(name, StringLen(Prefix_Draw)); 
         string markName = Prefix_Mark + suffix;
         
         // 检查对应的 Mark 对象是否存在 (如果画图工具删了 Mark，我们就不计算了)
         if(ObjectFind(0, markName) >= 0)
         {
            // 获取 Mark 对象的时间 (这就是磁吸 K 线的时间)
            datetime startTime = (datetime)ObjectGetInteger(0, markName, OBJPROP_TIME);
            
            // 将时间转换为 K 线索引 (Shift)
            int startIndex = iBarShift(NULL, 0, startTime);
            
            // 确保索引有效 (且不是当前K线本身，至少要有一根收盘的K线)
            if(startIndex > 0)
            {
               // ==========================================
               // 步骤 C: 统计穿越次数 (从磁吸K线右边一根开始，直到当前K线)
               // ==========================================
               int crossCount = CountCrossovers(linePrice, startIndex - 1);
               
               // ==========================================
               // 步骤 D: 显示结果
               // ==========================================
               string infoName = Prefix_Info + suffix;
               UpdateTextInfo(infoName, linePrice, crossCount, startTime);
            }
         }
         else
         {
            // 如果 Mark 没了 (可能被用户删了)，顺便把对应的 Info 也删了
            string infoName = Prefix_Info + suffix;
            if(ObjectFind(0, infoName) >= 0) ObjectDelete(0, infoName);
         }
      }
   }
   
   // 额外的清理逻辑：如果图表上存在 Info_ 对象，但对应的 Draw_ 对象不存在了，应该删除 Info_
   // 为了节省性能，这个操作可以不做，或者低频做。
   // 这里采用一种简单的策略：如果 UpdateTextInfo 没被调用，Info 对象会留在图表上。
   // 可以在 OnDeinit 统一清理。
}

//+------------------------------------------------------------------+
//| 算法：计算价格穿越次数 (实体穿越法)
//| 逻辑：判断 收盘价 是否从线上方变到线下方 (或反之)
//+------------------------------------------------------------------+
int CountCrossovers(double level, int startIdx)
{
   int count = 0;
   
   // 1. 确定起始状态 (前一根K线相对于线的位置)
   // startIdx 是我们要计算的第一根K线，我们需要看它 *之前* 那根的状态 (即 startIdx + 1)
   // 如果 startIdx 已经是历史最久远的一根，就用它自己。
   int prevBarIdx = startIdx + 1;
   if(prevBarIdx >= iBars(NULL, 0)) prevBarIdx = startIdx;
   
   // 1 = 上方, -1 = 下方
   int lastState = 0;
   if (iClose(NULL, 0, prevBarIdx) > level) lastState = 1;
   else lastState = -1;
   
   // 2. 向右循环遍历每一根K线，直到当前 K[0]
   for(int i = startIdx; i >= 0; i--)
   {
      int curState = 0;
      double closePrice = iClose(NULL, 0, i);
      
      if (closePrice > level) curState = 1;
      else curState = -1;
      
      // 如果当前状态与上一次状态不一致，说明发生了穿越
      if (curState != lastState)
      {
         count++;
         lastState = curState; // 更新状态
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| UI：在图表上创建/更新文字显示统计结果
//+------------------------------------------------------------------+
void UpdateTextInfo(string name, double price, int count, datetime time1)
{
   // 位置设定：显示在当前 K 线的右侧
   // 利用 Time[0] + 这里的周期秒数 * N 来往右偏移
   datetime timeCurrent = Time[0] + PeriodSeconds() * 3; 
   
   // 如果对象不存在，创建它
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TEXT, 0, timeCurrent, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpTextColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpTextSize);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER); // 左下锚点，文字在线上方
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true); // 在对象列表中隐藏，避免干扰
   }
   
   // 实时更新位置和内容
   ObjectSetInteger(0, name, OBJPROP_TIME, timeCurrent);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   
   // 组装显示文本
   // 格式：[ CR: 5 ] (CR = Cross Return)
   string text = "  [ Break: " + IntegerToString(count) + " ]";
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| 清理函数
//+------------------------------------------------------------------+
void DeleteAllInfoObjects()
{
   int total = ObjectsTotal(0, -1, -1);
   // 倒序删除，防止索引错乱
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, Prefix_Info) == 0)
      {
         ObjectDelete(0, name);
      }
   }
}