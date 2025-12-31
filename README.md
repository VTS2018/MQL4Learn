# My MQL4 Trading System

这是我的个人 MQL4 交易系统项目，专注于 K 线形态分析和自动化交易。

## 📁 目录结构
* **Experts/**: 包含主要的 EA (Expert Advisors)。
* **Scripts/**: 用于测试和辅助功能的脚本。
* **Include/**: 通用的 .mqh 头文件库。
* **CodeBak/**: 重要的历史代码备份。

## 🚀 安装说明
1. 将 .mq4 文件复制到 MT4 的 `MQL4/Experts` 目录。
2. 将 .mqh 文件复制到 `MQL4/Include` 目录。
3. 在 MetaEditor 中编译。

## 📝 笔记
* 当前主要开发分支：`master`
* 项目主要有 KTarget_Finder5.mq4
* 调用的子文件有 如下
* #include <K5/K_Data.mqh>
* #include <K5/K_Utils.mqh>
* #include <K5/K_Logic.mqh>
* #include <K5/K_Drawing_Funcs.mqh>
* 保证 KTarget_Finder5 的独立性

## 👿 指标和脚本的说明
* **Scripts\KT_Open_Auto_Signal_V3.mq4** 开仓脚本
* **Scripts\KT_Delete_Trade_Arrows.mq4** 删除主图表上 所有的“# 开头的交易订单箭头”
* **Scripts\KT_Force_Clear_All.mq4** 一键删除主图表上 所有的绘图对象
* **Scripts\KT_Close_All_Orders.mq4** 一键清空所有订单 (平仓 + 删挂单)
* **Scripts\Test_Fun.mq4** 当时用来测试函数功能用的
---
* **Indicators\KTarget_Finder_MT7.mq4** 正在使用的指标 信号探测IB，DB，CB信号
---

* **Indicators\KTarget_Finder1.mq4** 代码雏形1 从识别标注第一个锚点开始
* **Indicators\KTarget_Finder2.mq4**
* **Indicators\KTarget_Finder3.mq4**
* **Indicators\KTarget_Finder4.mq4**
---
* **Indicators\KTarget_Finder5.mq4** 版本5是历史过程中成型的第一个版本，之前的1-4 都是代码雏形
* **Indicators\KTarget_Finder6.mq4** 版本6是开始对代码进行文件分离的一个版本 第一次引入 K_Logic_v3
---
* **Indicators\KT_Drawing_Tool_V2.mq4**  带有周期 自动吸附 画水平线和射线的工具
* **Indicators\KT_Distance_Dashboard_Fixed.mq4** 实时显示 前高，前前高，前低，前前低距离点数的工具
* **Indicators\KT_PA_Signal_System.mq4** 识别标注 孕线 Pinbar 突破等相关信号的工具
* **Indicators\KT_SMC_Structure_IDM_V3.mq4** 识别SMC 的BOS和IDM的简单标注工具
* **Indicators\KT_Simple_Breakout_Line.mq4** 最简破位识别 + 破位价水平线标记
* **Indicators\KT_EasyTrend.mq4** 基于 H4 双均线的趋势看板

## ✨ EA相关的说明
* **Experts\KTarget_FinderBot_V1.mq4** 基于KTarget_Finder5运行
* **Experts\KTarget_FinderBot_V2.mq4** 基于KTarget_Finder5运行
* **Experts\KTarget_Test_Bot.mq4** 基于KTarget_Finder5运行

* **Experts\KTarget_FinderBot5.mq4**
* **Experts\KTarget_FinderBot6.mq4**
* **Experts\KTarget_FinderBot7.mq4**