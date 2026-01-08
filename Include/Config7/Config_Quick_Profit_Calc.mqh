//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ [新增] 融合 KT_Quick_Profit_Calc 的配置选项
//+------------------------------------------------------------------+
input string   __Quick_Profit_Calc__  = "=== Quick_Profit_Calc ===";
input double InpDefaultLots = 0.01;    // 测算手数 (默认 0.01)
input color  InpLineColor   = clrBlack; // 测距线颜色
input int    InpLineWidth   = 1;       // 测距线宽度
input int    InpFontSize    = 10;      // 显示字体大小
input color  InpTextColor   = clrWhite;// 字体颜色
input color  InpBgColor     = clrBlack;// 提示框背景色
//+------------------------------------------------------------------+
//--- 全局变量
string LineObjName = "KT_Calc_Line";
string RectObjName = "KT_Calc_Rect";
string TextObjName = "KT_Calc_Text";
bool   IsDragging = false;
int    Start_X = 0;
int    Start_Y = 0;
double Start_Price = 0;
datetime Start_Time = 0;
//+------------------------------------------------------------------+