//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

void Init_GetInfo()
{
   // 🚨 查看当前品种的一些基础信息 🚨
   Print("当前品种：Digits() ", Digits());
   Print("当前品种：Point() ", Point());
   Print("当前品种：Period() ", Period());
   Print("当前品种：Symbol() ", Symbol());

   Print("当前品种：GetContractSize() ", DoubleToString(GetContractSize(), _Digits));

   double tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);

   Print("当前品种：Symbol() ", DoubleToString(tick_value, _Digits));
   Print("当前品种：Symbol() ", DoubleToString(tick_size, _Digits));

   // 🚨 验证仓位计算的准确性 🚨
   Test_PositionSize_Logic();
}