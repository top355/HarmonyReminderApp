# HarmonyOS 原生提醒 App

使用 HarmonyOS `reminderAgentManager`（后台代理提醒）实现的原生提醒应用。
即使 app 被系统杀死，系统也会代为弹出提醒通知。

## 功能

- 定时提醒（时:分）
- 每天重复 / 单次提醒
- 自定义提醒内容
- 提醒列表管理（添加/删除）
- 数据持久化（preferences）
- 全屏提醒 + 响铃 + 振动
- 贪睡功能（2次，间隔5分钟）

## 构建

需要安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)。

1. 用 DevEco Studio 打开 `HarmonyReminderApp/` 目录
2. 等待 sync 完成
3. 连接鸿蒙手机（开启开发者模式 + USB 调试）
4. 点击 Run 或 Build → Build Hap(s)/APP(s)

## 技术要点

- `reminderAgentManager.ReminderRequestAlarm` — 每天重复的闹钟提醒
- `reminderAgentManager.ReminderRequestCalendar` — 单次提醒（指定日期时间）
- 系统代理提醒，app 被杀也能触发
- `notificationManager.SlotType.SOCIAL_COMMUNICATION` — 最高优先级通知
- `maxScreenWantAgent` — 全屏弹出提醒界面
- `@kit.ArkData` preferences — 本地持久化提醒列表
