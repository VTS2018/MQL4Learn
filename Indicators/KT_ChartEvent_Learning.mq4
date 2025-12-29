//+------------------------------------------------------------------+
//|                                        ChartEvent_Learning.mq4 |
//|                                                      [Generated] |
//+------------------------------------------------------------------+
#property copyright "Generated Code"
#property link      "https://gemini.google.com"
#property version   "1.00"
#property strict
#property indicator_chart_window // 在主图表窗口显示

// --- 全局变量 ---
string  g_trendline_name = "MyClickableTrendline";
long    g_chart_id       = 0;

//+------------------------------------------------------------------+
//| Indicator initialization function                                |
//+------------------------------------------------------------------+
int OnInit()
{
    // 1. 获取当前图表ID
    g_chart_id = ChartID();
    Print("--- OnInit: Indicator started. ChartID: ", g_chart_id, " ---");

    // 2. 创建一个可交互的图形对象 (趋势线)
    // 我们需要一个对象来演示 CHARTEVENT_OBJECT_CLICK
    if(ObjectFind(g_chart_id, g_trendline_name) == 0)
    {
        // 如果对象已存在，则删除，确保干净
        ObjectDelete(g_chart_id, g_trendline_name);
    }
    
    // 创建一条趋势线，使其在屏幕中央可见
    ObjectCreate(g_chart_id, g_trendline_name, OBJ_TREND, 0, Time[20], High[20], Time[10], Low[10]);
    ObjectSetInteger(g_chart_id, g_trendline_name, OBJPROP_COLOR, clrAqua);
    ObjectSetInteger(g_chart_id, g_trendline_name, OBJPROP_WIDTH, 2);
    
    // ** 关键设置：使对象可被点击和选中 **
    ObjectSetInteger(g_chart_id, g_trendline_name, OBJPROP_SELECTABLE, false); 
    
    Print("--- OnInit: Trendline created. Now try clicking the trendline. ---");
    
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // 清理创建的图形对象
    ObjectDelete(g_chart_id, g_trendline_name);
    Print("--- OnDeinit: Trendline deleted. ---");
}
//+------------------------------------------------------------------+
//| Indicator calculation function                                   |
//| (保留此函数，保持指标的基本结构，但不需要计算逻辑)                 |
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
    // 每次计算只打印一次，避免日志泛滥
    if (prev_calculated == 0)
    {
        Print("OnCalculate: Initial calculation done.");
    }
    return(rates_total);
}
//+------------------------------------------------------------------+
//| ChartEvent function - 接收所有图表/对象事件的关键函数               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // 1. 打印所有事件的通用信息
    Print("--- EVENT RECEIVED --- ID:", id, 
          ", lparam:", lparam, 
          ", dparam:", dparam, 
          ", sparam (Name/Key):", sparam);

    // --- 2. 针对特定事件进行处理和深入解析 ---
    switch(id)
    {
        case CHARTEVENT_OBJECT_CLICK:
            // 这是您的目标：用户点击了图表对象
            Print("    *** 侦测到对象点击事件 (CHARTEVENT_OBJECT_CLICK) ***");
            Print("    被点击对象名称 (sparam): ", sparam);
            
            // 检查是否点击了我们创建的趋势线
            if (sparam == g_trendline_name)
            {
                Print("    >>> 成功点击了我们的可交互趋势线！ <<<");
                // 此时您可以执行 DrawP1P2Fibonacci() 等自定义操作
            }
            break;
            
        case CHARTEVENT_KEYDOWN:
            // 用户按下了键盘上的键
            Print("    侦测到键盘按下事件 (CHARTEVENT_KEYDOWN)");
            Print("    按下的键代码 (lparam): ", lparam);
            break;
            
        case CHARTEVENT_CHART_CHANGE:
            // 图表变动：例如窗口大小改变、缩放、切换周期
            Print("    图表变动事件 (CHARTEVENT_CHART_CHANGE) 发生。");
            break;
            
        default:
            // 其他事件，例如 CHARTEVENT_MOUSE_MOVE (需要显式开启)
            // Print("    接收到其他事件...");
            break;
    }
}
//+------------------------------------------------------------------+