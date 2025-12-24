//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ 唯一对象名前缀
//+------------------------------------------------------------------+
string g_object_prefix = "";

//+------------------------------------------------------------------+
//| ✅ 专门研究 (OnCalculate)
//+------------------------------------------------------------------+
static datetime last_bar_time = 0;   // 记录上次计算时的 K 线时间
static datetime last_tick_time = 0;  // 记录上次 OnCalculate 触发的时间 (用于区分Tick)
static int on_calculate_count = 0;   // OnCalculate 【触发次数计数】
static bool is_initial_load = true;  // 标记是否为首次历史数据加载

// 两个字符串变量用于 OnCalculate 和 OnTimer 之间的通信
static string on_calc_output_segment = ""; // 存储 OnCalculate 的计算结果部分
static string on_timer_output_segment = ""; // 存储 OnTimer 的输出结果部分

//+------------------------------------------------------------------+
//| ✅ 静态变量：用于检查两次点击之间的间隔，
//| 以模拟“双击” 将 LastClickTime 改为存储毫秒数 (unsigned long)
//+------------------------------------------------------------------+
// static datetime LastClickTime = 0;
static ulong LastClickTime_ms = 0;
const ulong DOUBLE_CLICK_TIMEOUT_MS = 500; // 500 毫秒内算作双击

// 声明一个全局变量
SignalStatReport g_Stats;
