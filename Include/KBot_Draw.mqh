//+------------------------------------------------------------------+
//|                                                    KBot_Draw.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 10.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ❌ -- 表示没有使用
//| 绘制：趋势线对象 (OBJ_TREND)
//| 职责：纯绘图，不包含任何交易逻辑或信号查找逻辑。
//+------------------------------------------------------------------+
// 参数：
// obj_name_prefix: 对象名称前缀，用于确保唯一性，且方便清理。
// color:           颜色。
// width:           线条宽度。
// time1, price1:   起点坐标。
// time2, price2:   终点坐标。
//--------------------------------------------------------------------+
void DrawTrendLineObject(
    string obj_name_prefix,
    color mycolor,
    int width,
    datetime time1,
    double price1,
    datetime time2,
    double price2
)
{
   // 使用时间戳作为后缀，确保对象名称的唯一性
   // string obj_name = obj_name_prefix + TimeToString(time1, TIME_DATE | TIME_SECONDS);
   string obj_name = obj_name_prefix;

   // 1. 创建对象 (OBJ_TREND)
   // 注意：OBJ_TREND 需要 4 个参数 (时间1, 价格1, 时间2, 价格2)
   // 但在 MQL4 中，ObjectCreate(chart_id, name, type, window_num, time1, price1, time2, price2...)
   // 我们先用默认坐标创建，再设置正确的坐标
   ObjectCreate(0, obj_name, OBJ_TREND, 0, time1, price1, time2, price2);

   // 2. 设置坐标
   ObjectSet(obj_name, OBJPROP_TIME1, time1);
   ObjectSet(obj_name, OBJPROP_PRICE1, price1);
   ObjectSet(obj_name, OBJPROP_TIME2, time2);
   ObjectSet(obj_name, OBJPROP_PRICE2, price2);

   // 3. 设置外观
   ObjectSet(obj_name, OBJPROP_COLOR, mycolor);
   ObjectSet(obj_name, OBJPROP_WIDTH, width);
   ObjectSet(obj_name, OBJPROP_STYLE, STYLE_DASH); // 使用虚线
   ObjectSet(obj_name, OBJPROP_RAY, false);        // 不向右延伸

   // 确保对象能被鼠标选中 (如果需要)
   // ObjectSet(obj_name, OBJPROP_SELECTABLE, true);
}

//+------------------------------------------------------------------+
//| ✅ 辅助绘图：绘制信号上下文连接线 (Context Link Line)
//+------------------------------------------------------------------+
void DrawContextLinkLine(string obj_name, datetime t1, double p1, datetime t2, double p2, color clr)
{
   // 1. 如果对象已存在，先删除（确保属性是最新的）
   if(ObjectFind(0, obj_name) != -1) ObjectDelete(0, obj_name);

   // 2. 创建趋势线对象
   ObjectCreate(0, obj_name, OBJ_TREND, 0, t1, p1, t2, p2);

   // 3. 设置属性
   ObjectSet(obj_name, OBJPROP_COLOR, clr);            // 颜色
   ObjectSet(obj_name, OBJPROP_STYLE, STYLE_DOT);      // 样式：点划线 (区分于普通趋势线)
   ObjectSet(obj_name, OBJPROP_WIDTH, 1);              // 宽度
   ObjectSet(obj_name, OBJPROP_RAY, false);            // 关键：关闭射线延伸，只连接两点
   ObjectSet(obj_name, OBJPROP_BACK, true);            // 背景显示，不遮挡K线
   ObjectSet(obj_name, OBJPROP_SELECTABLE, false);     // 不可选中
   // ObjectSet(obj_name, OBJPROP_HIDDEN, true);          // 隐藏在对象列表中(可选)
}

//+------------------------------------------------------------------+
//| ✅ 清理所有上下文连接线 (Context Link Lines)
//| 作用: 删除所有以前缀 "CtxLink_" 开头的临时连线
//+------------------------------------------------------------------+
void CleanOldContextLinks()
{
   // 构造连接线的专用前缀
   // 必须与 CheckSignalContext 中定义的 link_prefix 保持完全一致
   string link_prefix = g_object_prefix + "CtxLink_";
   
   // 删除所有以该前缀开头的对象
   // 参数说明: 
   // 0: 当前图表
   // link_prefix: 要删除的对象名称前缀
   // -1: 删除所有窗口中的对象 (主图和副图)
   // OBJ_TREND: 只删除趋势线类型 (更安全，防止误删其他同名前缀对象)
   ObjectsDeleteAll(0, link_prefix, -1, OBJ_TREND);
   
   // 强制刷新图表，让删除立即生效 (这里才需要 ChartRedraw)
   ChartRedraw(); 
}

//+------------------------------------------------------------------+
//| ❌ 
//| 辅助函数：在图表固定角点显示交易状态信息
//| 职责：创建、更新或删除一个 OBJ_TEXT 对象。
//+------------------------------------------------------------------+
void DrawTradeStatusInfo(string status_text, string object_name, color text_color=clrRed)
{
    // 1. 如果传入的文本为空，则删除对象
    if (status_text == "")
    {
        ObjectDelete(0, object_name);
        return;
    }

    // 2. 检查对象是否存在
    if (ObjectFind(0, object_name) == -1)
    {
        // 如果不存在，则创建对象
        ObjectCreate(0, object_name, OBJ_TEXT, 0, Time[0], 0); 
        
        // 设置对象属性
        // 关键修正：将其固定在右下角
        ObjectSet(object_name, OBJPROP_CORNER, CORNER_RIGHT_LOWER); 
        ObjectSet(object_name, OBJPROP_XDISTANCE, 10);             // X轴向左偏移 10 像素
        ObjectSet(object_name, OBJPROP_YDISTANCE, 50);             // Y轴向上偏移 50 像素 (与下方边框保持距离)
        ObjectSet(object_name, OBJPROP_FONTSIZE, 12);              // 字体大小
        ObjectSet(object_name, OBJPROP_BACK, false);               // 背景透明
        ObjectSet(object_name, OBJPROP_SELECTABLE, false);         // 不可选
    }
    
    // 3. 更新对象内容和颜色
    ObjectSetText(object_name, status_text, 0, "Arial", text_color);
}

//+------------------------------------------------------------------+
//| 辅助函数：创建清理按钮 (UI)
//+------------------------------------------------------------------+
void CreateCleanupButton_V1(string btn_name)
{
   if (ObjectFind(0, btn_name) < 0)
   {
      // 创建按钮对象
      ObjectCreate(0, btn_name, OBJ_BUTTON, 0, 0, 0);
      
      // --- 定位设置 (右下角) ---
      ObjectSetInteger(0, btn_name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, btn_name, OBJPROP_XDISTANCE, 20);  // 距离右边框 20 像素
      ObjectSetInteger(0, btn_name, OBJPROP_YDISTANCE, 25);  // 距离下边框 25 像素
      
      // --- 尺寸设置 ---
      ObjectSetInteger(0, btn_name, OBJPROP_XSIZE, 100);     // 宽
      ObjectSetInteger(0, btn_name, OBJPROP_YSIZE, 30);      // 高
      
      // --- 样式设置 ---
      ObjectSetString(0, btn_name, OBJPROP_TEXT, "清理数据");
      ObjectSetString(0, btn_name, OBJPROP_FONT, "Microsoft YaHei");
      ObjectSetInteger(0, btn_name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, btn_name, OBJPROP_COLOR, clrWhite);           // 文字颜色
      ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, clrDimGray);       // 按钮背景色
      ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, clrSilver);   // 边框颜色
      
      // --- 属性设置 ---
      ObjectSetInteger(0, btn_name, OBJPROP_BACK, false);    // 前置显示
      ObjectSetInteger(0, btn_name, OBJPROP_STATE, false);   // 初始状态：未按下
      ObjectSetInteger(0, btn_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btn_name, OBJPROP_HIDDEN, true);   // 隐藏在对象列表中(防误删)
      ObjectSetInteger(0, btn_name, OBJPROP_ZORDER, 10);     // 优先级
   }
}

void CreateCleanupButton(string btn_name) 
{
   // 🚨 1. 为了确保属性生效，如果对象已存在，先彻底删除它再重建
   if (ObjectFind(0, btn_name) >= 0) 
   {
       ObjectDelete(0, btn_name);
   }

   // 2. 创建按钮对象
   ObjectCreate(0, btn_name, OBJ_BUTTON, 0, 0, 0);
   
   // --- 定位设置 (右下角) ---
   ObjectSetInteger(0, btn_name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, btn_name, OBJPROP_XDISTANCE, 120);  // 距离右边框 50 像素 (稍微往里挪一点)
   ObjectSetInteger(0, btn_name, OBJPROP_YDISTANCE, 40);  // 距离下边框 40 像素
   
   // --- 尺寸设置 ---
   ObjectSetInteger(0, btn_name, OBJPROP_XSIZE, 100);     // 宽
   ObjectSetInteger(0, btn_name, OBJPROP_YSIZE, 30);      // 高
   
   // --- 样式设置 ---
   // 🚨 注意：先去掉 Emoji 表情，部分 MT4 版本不支持会导致文字消失
   ObjectSetString(0, btn_name, OBJPROP_TEXT, "清理数据"); 
   
   // 字体尝试使用更通用的 SimHei (黑体) 或 Arial
   ObjectSetString(0, btn_name, OBJPROP_FONT, "Microsoft YaHei"); 
   ObjectSetInteger(0, btn_name, OBJPROP_FONTSIZE, 9);
   
   ObjectSetInteger(0, btn_name, OBJPROP_COLOR, clrWhite);           // 文字颜色 (白)
   ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, clrDimGray);       // 背景颜色 (深灰)
   ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, clrSilver);   // 边框颜色
   
   // --- 属性设置 ---
   ObjectSetInteger(0, btn_name, OBJPROP_BACK, false);    // 前置显示
   ObjectSetInteger(0, btn_name, OBJPROP_STATE, false);   // 初始状态：未按下
   ObjectSetInteger(0, btn_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btn_name, OBJPROP_HIDDEN, true);   
   ObjectSetInteger(0, btn_name, OBJPROP_ZORDER, 10);     
   
   // 🚨 3. 强制刷新图表，让文字立即渲染出来
   ChartRedraw();
}