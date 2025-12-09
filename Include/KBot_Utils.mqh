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

//+------------------------------------------------------------------+
//| 辅助函数：生成绝对唯一的信号 ID (品种前缀_周期_日时分)
//| 新格式: BTC_M1021806
//+------------------------------------------------------------------+
string GenerateSignalID(datetime signal_time)
{
   // --- 定义辅助变量 (保持不变) ---
   string find_underscore = "_" + "";
   string find_dot = "." + "";
   string find_colon = ":" + "";
   string replace_empty = "" + "";
   
   // 1. 获取品种前缀 (例如: BTCUSD -> BTC) [cite: 47]
   string symbol_prefix = _Symbol;
   if (StringLen(_Symbol) >= 3)
   {
      symbol_prefix = StringSubstr(_Symbol, 0, 3); // 截取前 3 个字符 [cite: 49]
   }

   // 2. 清理品种名中的下划线/点
   string temp_symbol = symbol_prefix;
   StringReplace(temp_symbol, find_underscore, replace_empty); // [cite: 50]
   StringReplace(temp_symbol, find_dot, replace_empty);        // [cite: 51]

   // ----------------------------------------------------
   // 3. 修正日期/时间获取逻辑 (新格式：日时分 DHHMM)
   // ----------------------------------------------------

   // 3.1 获取完整日期: "yyyy.mm.dd" (用于截取日) [cite: 51]
   string full_date = TimeToString(signal_time, TIME_DATE);

   // 3.2 截取日部分: 从第 8 位开始，长度为 2 ("dd")
   // 格式： yyyy.mm.dd
   // 索引： 0123456789
   string day = StringSubstr(full_date, 8, 2); 
   
   // 3.3 获取时间: "hh:mi" (时分) [cite: 53]
   string hour_minute = TimeToString(signal_time, TIME_MINUTES);

   // 4. 清理时间分隔符 (只清理时分)
   string temp_hour_minute = hour_minute;
   StringReplace(temp_hour_minute, find_colon, replace_empty); // [cite: 55]

   // ----------------------------------------------------
   // 5. 最终 ID 拼接
   // ----------------------------------------------------

   // 获取周期名称 (例如: "M1", "H4", "D1")
   string timeframe_name = GetTimeframeName(Period());
   
   // 格式: 品种前缀_周期_日时分 (例如：BTC_M1021806)
   // 注意：我们移除了下划线，直接连接
   return temp_symbol + "_" + timeframe_name + day + temp_hour_minute; 
}