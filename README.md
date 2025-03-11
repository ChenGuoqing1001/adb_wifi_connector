# ADB WiFi 连接器

一个基于 Flutter 开发的 ADB WiFi 连接工具，可以帮助开发者更方便地管理和连接 Android 设备。




![image](https://github.com/user-attachments/assets/566a0201-feb7-458e-b00c-1e99c2d28591)

## 主要功能

- 支持通过 WiFi 连接 Android 设备进行调试
- 系统托盘常驻，方便快速操作
- 自动保存连接历史记录
- 支持多设备同时连接
- 实时显示设备连接状态
- 支持一键连接/断开设备

## 系统要求

- Windows 操作系统
- 已安装 ADB 工具
- Android 设备需开启 USB 调试并与电脑在同一局域网

## 使用说明

1. 确保 Android 设备已开启 USB 调试模式
2. 通过 USB 连接设备并授权
3. 输入设备 IP 地址进行连接
4. 连接成功后即可拔掉 USB 线，使用 WiFi 调试

## 开发环境

- Flutter >= 3.0.0
- Dart SDK >= 3.0.0
- Windows SDK

## 依赖项

- window_manager: ^0.3.0
- system_tray: ^2.0.3
- cupertino_icons: ^1.0.2
