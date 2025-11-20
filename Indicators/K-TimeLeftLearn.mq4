//+------------------------------------------------------------------+
//|                                                   K-TimeLeft.mq4 |
//|                                          Copyright 2014,fxMeter. |
//|                            https://www.mql5.com/en/users/fxmeter |
//+------------------------------------------------------------------+
//2017-11-13 publish to MQL5.COM code base
//2014-11-15 create
#property copyright "Copyright 2014,fxMeter."
#property link      "https://www.mql5.com/en/users/fxmeter"
#property version   "1.00"
#property strict
#property indicator_chart_window // 指标将绘制在主图表窗口上

// --- 常量定义 (使用 #define 宏) ---
#define  OBJ_NAME "time_left_label" // 定义图表对象的唯一名称，方便查找和删除
#define  FONT_NAME "Microsoft YaHei" // 定义字体名称，确保文本显示清晰

// --- 定位模式枚举 ---
enum ENUM_POS_TL
  {
   FOLLOW_PRICE,   // 标签跟随价格变动 (OBJ_TEXT)
   FIXED_POSITION  // 标签固定在图表一角 (OBJ_LABEL)
  };

// --- 外部输入参数 (用户可配置) ---
input color  LabelColor=clrOrangeRed;          // 倒计时标签的颜色
input ENUM_POS_TL LabelPosition=FIXED_POSITION; // 标签的定位方式

//==================================================================
// 1. DeleteLabel: 清理图表对象 (自定义函数)
//==================================================================
void DeleteLabel()
{
   int try_count = 10; // 设置尝试次数，防止死循环
   // ObjectFind(0, OBJ_NAME) == 0 表示找到了对象
   while(ObjectFind(0,OBJ_NAME)==0) 
   {
      ObjectDelete(0,OBJ_NAME); // 删除找到的对象
      if(try_count--<=0)break;  // 达到最大尝试次数则退出循环
   }
}

//==================================================================
// 2. OnInit: 初始化函数
//==================================================================
int OnInit()
  {
//--- 1. 清理旧对象 (确保图表干净) ---
   DeleteLabel(); 

//--- 2. 启用定时器 (设置实时更新机制) ---
   // EventSetTimer(1): 设置定时器，每 1 秒触发一次 OnTimer() 函数
   EventSetTimer(1); 
   
//--- 3. 指标绘图缓冲区映射 (本指标无缓冲区，此部分留空) ---
   
//--- 成功返回 ---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+

//==================================================================
// 3. OnDeinit: 反初始化函数
//==================================================================
void OnDeinit(const int reason)
  {
//--- 1. 停止定时器 (释放系统资源) ---
   // EventKillTimer(): 停止 OnInit 中设置的定时器
   EventKillTimer(); 
   
//--- 2. 清理对象 (移除标签) ---
   DeleteLabel(); 
  }
//+------------------------------------------------------------------+

//==================================================================
// 4. OnCalculate: 主计算函数
//==================================================================
/*
  说明: 自定义指标的主计算函数，每当收到新 Tick 或 K 线收盘时被调用。
  本指标的倒计时逻辑放在了 OnTimer 中，因此此函数只返回 rates_total。
*/
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
//--- 返回 rates_total 用于下一次调用，表示所有 K 线都被计算过 ---
   return(rates_total);
  }
//+------------------------------------------------------------------+

//==================================================================
// 5. OnTimer: 定时器事件函数 (核心实时更新机制)
//==================================================================
/*
  说明: 每隔 EventSetTimer() 中设置的秒数 (此处是 1 秒) 自动被调用一次。
  用于驱动倒计时标签的实时更新。
*/
void OnTimer()
  {
   UpdateTimeLeft(); // 调用倒计时更新函数
  }
//+------------------------------------------------------------------+

//==================================================================
// 6. UpdateTimeLeft: 倒计时计算与绘图函数
//==================================================================
void UpdateTimeLeft()
{
//--- 1. 获取当前时间信息 ---
   // 获取当前 K 线的开盘时间 (索引 0)
   datetime time  = iTime(Symbol(),Period(),0); 
   
   // 获取当前收盘价 (用于跟随价格定位)
   double   close = iClose(Symbol(),Period(),0); 
   
   // 获取当前服务器的实时时间 (GMT/UTC)
   datetime now   = TimeCurrent();              
   
   // 计算当前周期 (例如 M30 = 1800 秒)
   int      period_seconds = PeriodSeconds(Period()); 

//--- 2. 计算剩余秒数 ---
   // 已流逝时间 (秒) = 当前实时时间 - K 线开盘时间
   int elapsed_seconds = (int)(now - time);
   
   // 剩余秒数 = 周期总秒数 - 已流逝秒数
   // 使用 (int) 强制转换以避免可能的编译警告
   int seconds_left = (int)(period_seconds - elapsed_seconds);
   
//--- 3. 修正 K 线刚收盘时的显示问题 ---
   // 如果剩余时间 <= 0 (K线已经收盘或刚收盘)，则重新计算下一根 K 线的时间
   // 或者如果剩余时间大于周期秒数 (通常是 Tick 延迟造成的)，也需要修正
   if(seconds_left <= 0 || seconds_left > period_seconds)
   {
      // 重新计算下一根 K 线的开盘时间
      time = iTime(Symbol(),Period(),0) + period_seconds;
      
      // 再次计算剩余秒数
      seconds_left = (int)(time - now);
      
      // 再次检查，如果仍然 <= 0，则将剩余时间设为 1 秒，等待下一秒的 Tick
      if(seconds_left <= 0) seconds_left = 1;
   }
   
//--- 4. 格式化为 HH:MM:SS 字符串 ---
   int h = seconds_left / 3600; // 小时
   int m = (seconds_left % 3600) / 60; // 分钟
   int s = seconds_left % 60; // 秒
   
   // StringFormat() 将数值格式化为带有前导零的两位字符串 (例如 9 -> 09)
   string text = StringFormat("%02d:%02d:%02d",h,m,s);

//--- 5. 创建或更新图表对象 ---
   
   // 如果定位模式是跟随价格 (OBJ_TEXT)
   if(LabelPosition==FOLLOW_PRICE)
     {
      // ObjectFind(0, OBJ_NAME) != 0 表示对象不存在，需要创建
      if(ObjectFind(0,OBJ_NAME)!=0)
        {
         // ObjectCreate: 创建 OBJ_TEXT 对象 (坐标是时间-价格)
         // time, close+_Point: 定位在当前 K 线的开盘时间和收盘价上方一个点
         ObjectCreate(0,OBJ_NAME,OBJ_TEXT,0,time,close+Point); 
         ObjectSetString(0,OBJ_NAME,OBJPROP_TEXT,text);
         ObjectSetString(0,OBJ_NAME,OBJPROP_FONT,FONT_NAME);
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_COLOR,LabelColor);
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_SELECTABLE,false); // 不可选定
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_FONTSIZE,12);      // 字体大小

        }
      else // 对象已存在，直接更新文本和位置
        {
         ObjectSetString(0,OBJ_NAME,OBJPROP_TEXT,text);
         // ObjectMove: 移动对象到新的时间-价格坐标
         ObjectMove(0,OBJ_NAME,0,time,close+Point);
        }
     }
   // 如果定位模式是固定位置 (OBJ_LABEL)
   else if(LabelPosition==FIXED_POSITION)
     {
      // ObjectFind(0, OBJ_NAME) != 0 表示对象不存在，需要创建
      if(ObjectFind(0,OBJ_NAME)!=0)
        {
         // ObjectCreate: 创建 OBJ_LABEL 对象 (坐标是像素)
         ObjectCreate(0,OBJ_NAME,OBJ_LABEL,0,0,0);
         // OBJPROP_ANCHOR: 对象的锚点位置
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
         // OBJPROP_CORNER: 对象相对于哪个角点定位 (CORNER_RIGHT_UPPER = 右上角)
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
         // OBJPROP_XDISTANCE, OBJPROP_YDISTANCE: 相对角点的像素偏移
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_XDISTANCE,200); 
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_YDISTANCE,2);
         ObjectSetString(0,OBJ_NAME,OBJPROP_FONT,FONT_NAME);
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_COLOR,LabelColor);
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,OBJ_NAME,OBJPROP_FONTSIZE,12);
         ObjectSetString(0,OBJ_NAME,OBJPROP_TEXT,text);
        }
      else // 对象已存在，直接更新文本
        {
         ObjectSetString(0,OBJ_NAME,OBJPROP_TEXT,text);
        }
     }
}
//+------------------------------------------------------------------+