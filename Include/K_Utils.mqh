//+------------------------------------------------------------------+
//|                                                      K_Utils.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 25.11.2025 - Initial release                                     |
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

//========================================================================
// 14. ShortenObjectName: 辅助函数，移除对象名中的指定字符串以缩短名称 (修正版)
//========================================================================
/**
 * 从对象名称中移除 "arget_Finder" 字符串以缩短名称。
 * @param original_name: 完整的对象名称字符串。
 * @return (string) 缩短后的新名称。
 */
string ShortenObjectName(string original_name)
{
    // 定义要移除的子字符串
    string substring_to_remove = "arget_Finder";
    
    // 1. 创建一个字符串副本，因为 StringReplace 会通过引用直接修改它的第一个参数。
    string new_name = original_name; 
    
    // 2. 🚨 关键修正：直接调用 StringReplace，它会修改 new_name 变量，
    //    并且我们忽略它的 INT 类型返回值。
    StringReplace(new_name, substring_to_remove, "");
    
    // 3. 返回修改后的字符串。
    return new_name;
}

//========================================================================
// 16. GetBarTimeID: 获取 K 线时间戳作为唯一对象标识符 (V2.07)
//========================================================================
/**
 * 根据 K 线索引获取其开盘时间，并格式化为 "YYYY_MM_DD_HH_MM_SS" 格式的字符串。
 * 如果索引无效，则使用当前服务器时间。
 * * @param bar_index 要获取时间的 K 线索引 (0 为当前 K线)
 * @return (string) 格式化后的唯一时间标识符，例如 "2025_11_24_06_00_00"
 */
string GetBarTimeID(int bar_index)
{
    datetime target_time;
    
    // --- 1. 确定目标时间 ---
    
    // 检查索引是否有效。如果索引无效 (例如 < 0)，则使用当前服务器时间。
    if (bar_index < 0 || bar_index >= Bars)
    {
        target_time = TimeCurrent();
        // Print("DEBUG: GetBarTimeID used TimeCurrent() due to invalid index: ", bar_index);
    }
    else
    {
        // 索引有效，使用 K 线的开盘时间
        target_time = Time[bar_index];
    }
    
    // --- 2. 将 datetime 转换为结构体，方便格式化 ---
    MqlDateTime dt;
    TimeToStruct(target_time, dt);

    // --- 3. 构造 "YYYY_MM_DD_HH_MM_SS" 格式的字符串 ---
    
    string time_id_str = 
        // 年份 (例如 2025)
        IntegerToString(dt.year) + "_" + 
        
        // 月份 (确保两位数，例如 01)
        IntegerToString(dt.mon, 2, '0') + "_" + 
        
        // 日期 (确保两位数)
        IntegerToString(dt.day, 2, '0') + "_" + 
        
        // 小时 (确保两位数)
        IntegerToString(dt.hour, 2, '0') + "_" + 
        
        // 分钟 (确保两位数)
        IntegerToString(dt.min, 2, '0') + "_" + 
        
        // 秒钟 (确保两位数)
        IntegerToString(dt.sec, 2, '0');
        
    return time_id_str;
}

//========================================================================
// 18. ParseRectangleName: 解析矩形名称，提取 K 线时间 (V3.00)
//========================================================================
/**
 * 从对象名称中解析出 K 线时间戳和看涨/看跌类型。
 * @param rect_name 被点击的矩形对象的完整名称
 * @param info 引用传递的结构体，用于存储解析结果
 * @return (bool) 成功解析返回 true，否则返回 false
 */
bool ParseRectangleName(const string rect_name, ParsedRectInfo &info)
{
    // 1. 检查类型并确定字符串起始位置
    int start_pos = -1;
    if (StringFind(rect_name, "Rect_B_", 0) != -1)
    {
        info.is_bullish = true;
        start_pos = StringFind(rect_name, "Rect_B_", 0) + StringLen("Rect_B_");
    }
    else if (StringFind(rect_name, "Rect_S_", 0) != -1)
    {
        info.is_bullish = false;
        start_pos = StringFind(rect_name, "Rect_S_", 0) + StringLen("Rect_S_");
    }
    else
    {
        // 无法识别的名称类型
        return false;
    }
    
    // 2. 提取 P1 和 P2 时间字符串
    string time_segment = StringSubstr(rect_name, start_pos);
    int separator_pos = StringFind(time_segment, "#", 0);
    
    if (separator_pos == -1) return false; // 缺少分隔符
    
    string P1_time_str = StringSubstr(time_segment, 0, separator_pos);
    string P2_time_str = StringSubstr(time_segment, separator_pos + 1);
    
    // 3. 将 "YYYY_MM_DD_HH_MM_SS" 格式转换成 MQL4 可识别的 "YYYY.MM.DD HH:MM:SS"
    string P1_standard_format = 
        StringSubstr(P1_time_str, 0, 4) + "." + // YYYY.
        StringSubstr(P1_time_str, 5, 2) + "." + // MM.
        StringSubstr(P1_time_str, 8, 2) + " " + // DD<space>
        StringSubstr(P1_time_str, 11, 2) + ":" + // HH:
        StringSubstr(P1_time_str, 14, 2) + ":" + // MM:
        StringSubstr(P1_time_str, 17, 2);       // SS
                                
    string P2_standard_format = 
        StringSubstr(P2_time_str, 0, 4) + "." + 
        StringSubstr(P2_time_str, 5, 2) + "." + 
        StringSubstr(P2_time_str, 8, 2) + " " + 
        StringSubstr(P2_time_str, 11, 2) + ":" + 
        StringSubstr(P2_time_str, 14, 2) + ":" + 
        StringSubstr(P2_time_str, 17, 2); 

    // 4. 执行转换
    info.P1_time = StringToTime(P1_standard_format);
    info.P2_time = StringToTime(P2_standard_format);
    
    if (info.P1_time == 0 || info.P2_time == 0) return false; // 转换失败
    
    return true;
}

// K_Drawing_Funcs.mqh 或 K_Utils.mqh

// 这是一个辅助函数，将 _Period 的分钟数转换为 MT4 期望的位标志
int GetTimeframeFlag(int timeframe_period)
{
    // MQL4 中 _Period 返回的值是分钟数
    if (timeframe_period == 1)      return(1);       // M1
    if (timeframe_period == 5)      return(2);       // M5
    if (timeframe_period == 15)     return(4);       // M15
    if (timeframe_period == 30)     return(8);       // M30
    if (timeframe_period == 60)     return(16);      // H1
    if (timeframe_period == 240)    return(32);      // H4
    
    // 🚨 核心修正：避免使用 43200 这种数值作为位标志 🚨
    if (timeframe_period == 1440)   return(64);      // D1
    if (timeframe_period == 10080)  return(128);     // W1
    if (timeframe_period == 43200)  return(256);     // MN1 (月线)
    
    // 如果是自定义周期或其他未知周期，返回 0 (表示所有周期可见或不设置)
    return(0); 
}