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
* #include <K_Data.mqh>
* #include <K_Utils.mqh>
* #include <K_Logic.mqh>
* #include <K_Drawing_Funcs.mqh>