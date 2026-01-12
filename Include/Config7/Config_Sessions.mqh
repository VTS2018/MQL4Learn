//+------------------------------------------------------------------+
//|                                                  Config_Risk.mqh |
//|                                         Copyright 2025, YourName |
//|                                                 https://mql5.com |
//| 14.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ Market Session Visualization (Optional)
//+------------------------------------------------------------------+
input string   __Session_Settings__ = "=== Market Sessions ===";
input bool     Show_Sessions        = false;      // Show Market Sessions
input int      Session_Lookback     = 5;          // Session Days Lookback
input int      Server_Time_Offset   = 3;          // Server Time Offset (Hrs)

// --- Session 1: Asia / Tokyo ---
input string   Session1_Name        = "Asia";     // Session 1 Name
input string   Session1_Start       = "00:00";    // Sess 1 Start (HH:MM)
input string   Session1_End         = "09:00";    // Sess 1 End (HH:MM)
input color    Session1_Color       = clrSteelBlue;  // Sess 1 Color

// --- Session 2: London / Europe ---
input string   Session2_Name        = "London";   // Session 2 Name
input string   Session2_Start       = "08:00";    // Sess 2 Start (HH:MM)
input string   Session2_End         = "17:00";    // Sess 2 End (HH:MM)
input color    Session2_Color       = clrSeaGreen;// Sess 2 Color

// --- Session 3: New York / US ---
input string   Session3_Name        = "NewYork";  // Session 3 Name
input string   Session3_Start       = "13:00";    // Sess 3 Start (HH:MM)
input string   Session3_End         = "22:00";    // Sess 3 End (HH:MM)
input color    Session3_Color       = clrIndianRed;// Sess 3 Color