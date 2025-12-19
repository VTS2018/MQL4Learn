//+------------------------------------------------------------------+
//|                                               KBot_UI_Panel.mqh |
//|                                        KTarget Manual Dashboard |
//+------------------------------------------------------------------+
#property strict

// UI 对象前缀，方便统一管理和删除
#define UI_PREFIX "KBot_UI_"

//+------------------------------------------------------------------+
//| 创建确认面板 (主入口)
//+------------------------------------------------------------------+
void CreateConfirmPanel(int type, double lots, double price, double sl, double tp, string grade, double risk_money)
{
   // 1. 基础坐标设置 (屏幕右中)
   int x_base = 100; // 距离右边距
   int y_base = 200; // 距离上边距
   color bg_color = (type == OP_BUY) ? clrMediumSeaGreen : clrIndianRed;
   string type_str = (type == OP_BUY) ? "BUY SIGNAL" : "SELL SIGNAL";
   
   // 2. 绘制背景板
   CreateRectLabel("BG_Main", -x_base-180, y_base, 180, 220, bg_color, CORNER_RIGHT_UPPER);
   
   // 3. 绘制标题信息
   CreateTextLabel("Lbl_Title", type_str, -x_base-90, y_base+10, clrWhite, 12, true);
   CreateTextLabel("Lbl_Grade", "Grade: " + grade, -x_base-90, y_base+35, clrYellow, 14, true);
   
   // 4. 绘制交易数据
   int y_start = y_base + 70;
   int step = 20;
   CreateTextLabel("Lbl_Lots", "Lots: " + DoubleToString(lots, 2), -x_base-160, y_start, clrWhite, 10, false);
   CreateTextLabel("Lbl_Risk", "Risk: $" + DoubleToString(risk_money, 1), -x_base-160, y_start+step, clrWhite, 10, false);
   CreateTextLabel("Lbl_Price", "Entry: " + DoubleToString(price, _Digits), -x_base-160, y_start+step*2, clrWhite, 10, false);
   CreateTextLabel("Lbl_SL", "SL: " + DoubleToString(sl, _Digits), -x_base-160, y_start+step*3, clrWhite, 10, false);
   
   // 5. 绘制交互按钮
   // 确认按钮 (绿色/深红)
   CreateButton("Btn_Confirm_Trade", "✅ EXECUTE", -x_base-160, y_base+170, 70, 30, clrWhite, clrDarkGreen);
   // 拒绝按钮 (灰色)
   CreateButton("Btn_Reject_Trade", "❌ IGNORE", -x_base-80, y_base+170, 70, 30, clrWhite, clrDimGray);
   
   // 6. 绘制图表预览线 (Preview Lines)
   DrawPreviewLine("Line_Entry", price, clrBlue, STYLE_SOLID);
   DrawPreviewLine("Line_SL", sl, clrRed, STYLE_DASH);
   DrawPreviewLine("Line_TP", tp, clrLime, STYLE_DASH);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| 清除面板和预览线
//+------------------------------------------------------------------+
void RemoveConfirmPanel()
{
   ObjectsDeleteAll(0, UI_PREFIX);
}

// --- 辅助绘图函数 (内部使用) ---

void CreateRectLabel(string name, int x, int y, int w, int h, color bg, int corner)
{
   string objName = UI_PREFIX + name;
   if(ObjectFind(0, objName) < 0) ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, MathAbs(x));
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
}

void CreateTextLabel(string name, string text, int x, int y, color clr, int fontsize, bool center)
{
   string objName = UI_PREFIX + name;
   if(ObjectFind(0, objName) < 0) ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, MathAbs(x));
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontsize);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   if(center) ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_UPPER);
}

void CreateButton(string name, string text, int x, int y, int w, int h, color txt_clr, color bg_clr)
{
   string objName = UI_PREFIX + name;
   if(ObjectFind(0, objName) < 0) ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, MathAbs(x));
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, txt_clr);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg_clr);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10); // 放在最上层
}

void DrawPreviewLine(string name, double price, color clr, int style)
{
   string objName = UI_PREFIX + name;
   if(ObjectFind(0, objName) < 0) ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
   else ObjectMove(0, objName, 0, 0, price);
   
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
}