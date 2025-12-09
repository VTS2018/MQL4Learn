//+------------------------------------------------------------------+
//|                                                   KBot_Utils.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 09.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
// #property copyright "Copyright 2025, YourName"
// #property link      "https://mql5.com"
// #property strict

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2025

//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+

// #import "user32.dll"
//    int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//    int      ExpertRecalculate(int wParam,int lParam);
// #import

//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+

// #import "stdlib.ex5"
//    string ErrorDescription(int error_code);
// #import

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| MQL4 缺失函数：StringTrim (用于移除字符串首尾空格)                |
//+------------------------------------------------------------------+
string StringTrim(string str)
{
   int len = StringLen(str);
   if (len == 0) return str;
   
   // 移除开头的空格
   int start = 0;
   while (start < len && StringGetChar(str, start) == ' ')
   {
      start++;
   }
   
   // 如果整个字符串都是空格
   if (start == len) return "";
   
   // 移除末尾的空格
   int end = len - 1;
   while (end > start && StringGetChar(str, end) == ' ')
   {
      end--;
   }
   
   // 返回修剪后的子字符串
   return StringSubstr(str, start, end - start + 1);
}

//+------------------------------------------------------------------+
//| Helper: 解析单个斐波那契区域字符串 (例如 "1.618, 1.88")         |
//+------------------------------------------------------------------+
bool ParseFiboZone(string fibo_str, double &level1, double &level2)
{
    string tokens[];
    // 使用逗号作为分隔符分割字符串
    int count = StringSplit(fibo_str, ',', tokens);
    
    // 必须正好包含两个级别
    if (count != 2) return false;
    
    // 将字符串转换为双精度浮点数
    level1 = StringToDouble(StringTrim(tokens[0]));
    level2 = StringToDouble(StringTrim(tokens[1]));
    
    // 简单验证：级别不能小于或等于 0
    if (level1 <= 0 || level2 <= 0) return false; 
    
    // 成功解析
    return true;
}
