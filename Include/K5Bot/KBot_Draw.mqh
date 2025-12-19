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
//| ❌ 
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

//+------------------------------------------------------------------+
//| ✅ 清理数据
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| 辅助函数：创建或更新屏幕上的文字标签
//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color clr, int fontSize=10)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER); // 设定在右上角 (不挡左边的开单按钮)
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER); // 对齐方式
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| 核心功能：更新商场显示屏 (Dashboard)
//+------------------------------------------------------------------+
void UpdateDashboard_V1()
{
   int start_x = 20; // 距离右边框的距离
   int start_y = 30; // 距离上边框的距离
   int step_y  = 20; // 行间距

   // --- 1. 标题 ---
   DrawLabel("Dash_Title", "=== 风控监控面板 ===", start_x, start_y, clrGold, 11);
   
   // --- 2. 交易时段状态 ---
   color timeColor = IsCurrentTimeInSlots() ? clrLime : clrRed;
   string timeText = IsCurrentTimeInSlots() ? "交易时段: ✅ 允许交易" : "交易时段: ⛔ 休息中";
   DrawLabel("Dash_Time", timeText, start_x, start_y + step_y*1, timeColor);

   // --- 3. 连续止损 (CSL) 状态 ---
   bool isCSLLocked = (g_CSLLockoutEndTime > TimeCurrent());
   color cslColor = isCSLLocked ? clrRed : clrLime;
   string cslText = "连损风控: " + IntegerToString(g_ConsecutiveLossCount) + " / " + IntegerToString(CSL_Max_Losses);
   
   if (isCSLLocked) cslText += " (锁定至 " + TimeToString(g_CSLLockoutEndTime, TIME_MINUTES) + ")";
   else cslText += " (正常)";
   
   DrawLabel("Dash_CSL", cslText, start_x, start_y + step_y*2, cslColor);

   // --- 4. 日内盈亏状态 ---
   bool isDailyLocked = (g_Today_Realized_PL <= -Daily_Max_Loss_Amount);
   color dailyColor = isDailyLocked ? clrRed : (g_Today_Realized_PL >= 0 ? clrLime : clrOrange);
   
   string dailyText = "今日盈亏: $" + DoubleToString(g_Today_Realized_PL, 2) + " / 限额: -$" + DoubleToString(Daily_Max_Loss_Amount, 0);
   if (isDailyLocked) dailyText += " (熔断)";
   
   DrawLabel("Dash_Daily", dailyText, start_x, start_y + step_y*3, dailyColor);
   
   // --- 5. 持仓数量 ---
   DrawLabel("Dash_Pos", "当前持仓: " + IntegerToString(GetOpenPositionsCount()) + " 单", start_x, start_y + step_y*4, clrWhite);
   
   ChartRedraw(); // 强制刷新图表，让文字立即更新
}

//+------------------------------------------------------------------+
//| 核心功能：刷新风控显示屏 (UpdateDashboard)
//+------------------------------------------------------------------+
void UpdateDashboard_V2()
{
   // 定义位置参数 (您可以根据屏幕分辨率微调)
   int base_x = 30;  // 距离右边缘 30 像素
   int base_y = 50;  // 距离上边缘 50 像素
   int step_y = 22;  // 每行文字间隔 22 像素
   
   // -----------------------------------------------------------
   // 1. 标题栏
   // -----------------------------------------------------------
   DrawLabel("Dash_Title", "=== 🛡️ 智能风控面板 ===", base_x, base_y, clrGold, 11);
   
   // -----------------------------------------------------------
   // 2. 交易时段 (Time Slot)
   // -----------------------------------------------------------
   bool isTimeOK = IsCurrentTimeInSlots();
   string txtTime = isTimeOK ? "交易时段: ✅ 允许开仓" : "交易时段: 💤 休息中";
   color  clrTime = isTimeOK ? clrLime : clrGray; // 休息时显示灰色
   
   DrawLabel("Dash_Time", txtTime, base_x, base_y + step_y * 1, clrTime);
   
   // -----------------------------------------------------------
   // 3. 连续止损 (CSL) 监控
   // -----------------------------------------------------------
   // 直接读取全局变量判断状态
   bool isCSLLocked = (g_CSLLockoutEndTime > TimeCurrent());
   
   string txtCSL = "连损风控: " + IntegerToString(g_ConsecutiveLossCount) + " / " + IntegerToString(CSL_Max_Losses);
   color  clrCSL = clrLime; // 默认绿色
   
   if (isCSLLocked)
   {
      // 如果锁定了，显示红色，并告知解锁时间
      txtCSL += " ⛔ 锁定至 " + TimeToString(g_CSLLockoutEndTime, TIME_MINUTES);
      clrCSL  = clrRed;
   }
   else
   {
      txtCSL += " (运行中)";
   }
   
   DrawLabel("Dash_CSL", txtCSL, base_x, base_y + step_y * 2, clrCSL);

   // -----------------------------------------------------------
   // 4. 日内亏损 (Daily Limit) 监控
   // -----------------------------------------------------------
   // 直接计算是否触及红线
   bool isDailyLocked = (g_Today_Realized_PL <= -MathAbs(Daily_Max_Loss_Amount));
   
   string txtDaily = "今日盈亏: $" + DoubleToString(g_Today_Realized_PL, 2) + " / Limit: -$" + DoubleToString(Daily_Max_Loss_Amount, 0);
   color  clrDaily = clrLime; // 默认绿色
   
   if (isDailyLocked)
   {
      // 如果熔断了，显示红色大字
      txtDaily += " ⛔ [已熔断]";
      clrDaily  = clrRed;
   }
   else if (g_Today_Realized_PL < 0)
   {
      // 如果亏损但还没熔断，显示橙色警示
      clrDaily = clrOrange;
   }
   
   DrawLabel("Dash_Daily", txtDaily, base_x, base_y + step_y * 3, clrDaily);
   
   // -----------------------------------------------------------
   // 5. 总体状态汇总 (Summary)
   // -----------------------------------------------------------
   string txtStatus = "系统状态: 🟢 正常运行";
   color  clrStatus = clrWhite;
   
   if (!EA_Master_Switch) { txtStatus = "系统状态: ⚫ 总开关关闭"; clrStatus = clrGray; }
   else if (isCSLLocked)  { txtStatus = "系统状态: 🔴 连损风控暂停"; clrStatus = clrRed; }
   else if (isDailyLocked){ txtStatus = "系统状态: 🔴 日内风控暂停"; clrStatus = clrRed; }
   else if (!isTimeOK)    { txtStatus = "系统状态: 🟡 等待时段..."; clrStatus = clrYellow; }
   
   DrawLabel("Dash_Status", txtStatus, base_x, base_y + step_y * 4 + 5, clrStatus, 11); // 稍微隔开一点

   // 强制刷新图表
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| UpdateDashboard 2.0 (MT4 兼容版 - 纯字符风格)
//| 修复：移除导致乱码的 Emoji，改用 ASCII 字符模拟状态
//+------------------------------------------------------------------+
void UpdateDashboard_V3()
{
   // 定义位置参数
   int base_x = 30;  // 距离右边缘
   int base_y = 50;  // 距离上边缘
   int step_y = 22;  // 行间距
   
   // -----------------------------------------------------------
   // 1. 标题栏 (使用等号和中括号装饰)
   // -----------------------------------------------------------
   DrawLabel("Dash_Title", "[ SYSTEM MONITOR ]", base_x, base_y, clrGold, 10);
   
   // -----------------------------------------------------------
   // 2. 交易时段 (Time Slot)
   // -----------------------------------------------------------
   bool isTimeOK = IsCurrentTimeInSlots();
   string txtTime = isTimeOK ? "Time Check: [ OK ] Active" : "Time Check: [ -- ] Sleep";
   color  clrTime = isTimeOK ? clrLime : clrGray; 
   
   DrawLabel("Dash_Time", txtTime, base_x, base_y + step_y * 1, clrTime);
   
   // -----------------------------------------------------------
   // 3. 连续止损 (CSL) 监控
   // -----------------------------------------------------------
   bool isCSLLocked = (g_CSLLockoutEndTime > TimeCurrent());
   
   string txtCSL = "CSL Count : " + IntegerToString(g_ConsecutiveLossCount) + " / " + IntegerToString(CSL_Max_Losses);
   color  clrCSL = clrLime; 
   
   if (isCSLLocked)
   {
      // 锁定状态
      txtCSL += "  >>> [ LOCKED ] Until " + TimeToString(g_CSLLockoutEndTime, TIME_MINUTES);
      clrCSL  = clrRed;
   }
   else
   {
      // 正常状态
      txtCSL += "  [ RUNNING ]";
   }
   
   DrawLabel("Dash_CSL", txtCSL, base_x, base_y + step_y * 2, clrCSL);

   // -----------------------------------------------------------
   // 4. 日内亏损 (Daily Limit) 监控
   // -----------------------------------------------------------
   bool isDailyLocked = (g_Today_Realized_PL <= -MathAbs(Daily_Max_Loss_Amount));
   
   // 格式化金额显示
   string txtDaily = "Daily P/L : $" + DoubleToString(g_Today_Realized_PL, 2) + " / Limit: -$" + DoubleToString(Daily_Max_Loss_Amount, 0);
   color  clrDaily = clrLime;
   
   if (isDailyLocked)
   {
      txtDaily += "  >>> [ STOPPED ]"; // 熔断
      clrDaily  = clrRed;
   }
   else if (g_Today_Realized_PL < 0)
   {
      txtDaily += "  [ Warning ]"; // 亏损中
      clrDaily = clrOrange;
   }
   else
   {
      txtDaily += "  [ Profit ]"; // 盈利中
   }
   
   DrawLabel("Dash_Daily", txtDaily, base_x, base_y + step_y * 3, clrDaily);
   
   // -----------------------------------------------------------
   // 5. 总体状态汇总 (Summary)
   // -----------------------------------------------------------
   string txtStatus = "STATUS: [ OK ] System Online";
   color  clrStatus = clrWhite;
   
   if (!EA_Master_Switch) { txtStatus = "STATUS: [ OFF ] Master Switch is OFF"; clrStatus = clrGray; }
   else if (isCSLLocked)  { txtStatus = "STATUS: [ BLOCKED ] CSL Protection Active"; clrStatus = clrRed; }
   else if (isDailyLocked){ txtStatus = "STATUS: [ BLOCKED ] Daily Limit Hit"; clrStatus = clrRed; }
   else if (!isTimeOK)    { txtStatus = "STATUS: [ WAIT ] Waiting for Time Slot"; clrStatus = clrYellow; }
   
   DrawLabel("Dash_Status", txtStatus, base_x, base_y + step_y * 4 + 5, clrStatus, 10); 

   // 强制刷新
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| UpdateDashboard 2.1 (亮色背景专用版)
//| 适配：白色/浅色图表背景
//| 配色：深色字体 (黑色、深绿、暗红) 以增强对比度
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   // 定义位置参数
   int base_x = 30;  // 距离右边缘
   int base_y = 50;  // 距离上边缘
   int step_y = 22;  // 行间距
   
   // -----------------------------------------------------------
   // 1. 标题栏 (使用黑色，或者深蓝色增强专业感)
   // -----------------------------------------------------------
   DrawLabel("Dash_Title", "[ SYSTEM MONITOR ]", base_x, base_y, clrBlack, 10);
   
   // -----------------------------------------------------------
   // 2. 交易时段 (Time Slot)
   // -----------------------------------------------------------
   bool isTimeOK = IsCurrentTimeInSlots();
   string txtTime = isTimeOK ? "Time Check: [ OK ] Active" : "Time Check: [ -- ] Sleep";
   
   // 浅色背景下，用深绿色代表 OK，暗灰色代表休息
   color  clrTime = isTimeOK ? clrGreen : clrDimGray; 
   
   DrawLabel("Dash_Time", txtTime, base_x, base_y + step_y * 1, clrTime);
   
   // -----------------------------------------------------------
   // 3. 连续止损 (CSL) 监控
   // -----------------------------------------------------------
   bool isCSLLocked = (g_CSLLockoutEndTime > TimeCurrent());
   
   string txtCSL = "CSL Count : " + IntegerToString(g_ConsecutiveLossCount) + " / " + IntegerToString(CSL_Max_Losses);
   color  clrCSL = clrGreen; // 默认深绿
   
   if (isCSLLocked)
   {
      // 锁定状态
      txtCSL += "  >>> [ LOCKED ] Until " + TimeToString(g_CSLLockoutEndTime, TIME_MINUTES);
      clrCSL  = clrRed; // 红色在白底上也醒目
   }
   else
   {
      // 正常状态
      txtCSL += "  [ RUNNING ]";
   }
   
   DrawLabel("Dash_CSL", txtCSL, base_x, base_y + step_y * 2, clrCSL);

   // -----------------------------------------------------------
   // 4. 日内亏损 (Daily Limit) 监控
   // -----------------------------------------------------------
   bool isDailyLocked = (g_Today_Realized_PL <= -MathAbs(Daily_Max_Loss_Amount));
   
   // 格式化金额显示
   string txtDaily = "Daily P/L : $" + DoubleToString(g_Today_Realized_PL, 2) + " / Limit: -$" + DoubleToString(Daily_Max_Loss_Amount, 0);
   color  clrDaily = clrGreen;
   
   if (isDailyLocked)
   {
      txtDaily += "  >>> [ STOPPED ]"; // 熔断
      clrDaily  = clrRed;
   }
   else if (g_Today_Realized_PL < 0)
   {
      txtDaily += "  [ Warning ]"; // 亏损中
      // 浅色背景下，橙色如果太亮也看不清，建议用深橙色或巧克力色
      clrDaily = clrChocolate; 
   }
   else
   {
      txtDaily += "  [ Profit ]"; // 盈利中
   }
   
   DrawLabel("Dash_Daily", txtDaily, base_x, base_y + step_y * 3, clrDaily);
   
   // -----------------------------------------------------------
   // 5. 总体状态汇总 (Summary)
   // -----------------------------------------------------------
   string txtStatus = "STATUS: [ OK ] System Online";
   color  clrStatus = clrBlack; // 默认状态用黑色，最清晰
   
   if (!EA_Master_Switch) { txtStatus = "STATUS: [ OFF ] Master Switch is OFF"; clrStatus = clrDimGray; }
   else if (isCSLLocked)  { txtStatus = "STATUS: [ BLOCKED ] CSL Protection Active"; clrStatus = clrRed; }
   else if (isDailyLocked){ txtStatus = "STATUS: [ BLOCKED ] Daily Limit Hit"; clrStatus = clrRed; }
   else if (!isTimeOK)    { txtStatus = "STATUS: [ WAIT ] Waiting for Time Slot"; clrStatus = clrDarkGoldenrod; } // 暗金色代替黄色
   
   DrawLabel("Dash_Status", txtStatus, base_x, base_y + step_y * 4 + 5, clrStatus, 10); 

   // 强制刷新
   ChartRedraw();
}