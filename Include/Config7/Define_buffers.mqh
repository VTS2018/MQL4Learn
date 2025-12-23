//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
// --- 指标缓冲区 ---
double BullishTargetBuffer[]; // 0: 用于标记看涨K-Target锚点 (底部)
double BearishTargetBuffer[]; // 1: 用于标记看跌K-Target锚点 (顶部)
double BullishSignalBuffer[]; // 2: 最终看涨信号 (P2 或 P1-DB突破确认)
double BearishSignalBuffer[]; // 3: 最终看跌信号 (P2 或 P1-DB突破确认)

// --- 绘图属性 ---
// Plot 1: K-Target Bottom (锚点)
#property indicator_label1 "KTarget_Bottom"
#property indicator_type1  DRAW_ARROW
#property indicator_color1 clrBlue
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1
#define ARROW_CODE_UP 233 // 向上箭头

// Plot 2: K-Target Top (锚点)
#property indicator_label2 "KTarget_Top"
#property indicator_type2  DRAW_ARROW
#property indicator_color2 clrRed
#property indicator_style2 STYLE_SOLID
#property indicator_width2 1  // [V1.21 FIX] 修正了重复的 indicator_width1，确保正确设置 Plot 2 的宽度
#define ARROW_CODE_DOWN 234 // 向下箭头

// Plot 3: 最终看涨信号 
#property indicator_label3 "Bullish_Signal"
#property indicator_type3  DRAW_ARROW
#property indicator_color3 clrLimeGreen
#property indicator_style3 STYLE_SOLID
#property indicator_width3 1
#define ARROW_CODE_SIGNAL_UP 233 

// Plot 4: 最终看跌信号 
#property indicator_label4 "Bearish_Signal"
#property indicator_type4  DRAW_ARROW
#property indicator_color4 clrDarkViolet
#property indicator_style4 STYLE_SOLID
#property indicator_width4 1
#define ARROW_CODE_SIGNAL_DOWN 234

