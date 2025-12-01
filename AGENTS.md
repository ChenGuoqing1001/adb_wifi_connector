# Repository Guidelines

## 项目结构与模块组织
- `lib/main.dart`：桌面 Flutter 入口，窗口与系统托盘管理、自动启动、ADB 交互流程。
- `lib/services/adb_service.dart`：封装 `adb.exe` 调用（连接、断开、设备轮询、历史记录）。
- `lib/models/device_info.dart`：设备信息模型；`lib/l10n/app_localizations.dart` 管理文案与多语言。
- `assets/adb/`：随包提供的 Windows ADB 可执行文件及 DLL；`assets/app_icon.ico` 为应用图标。
- `test/widget_test.dart`：示例测试，可替换为实际业务测试。
- `windows/` 与 `build/windows/`：桌面打包模板与构建输出；`start_app.bat` 用于在启动目录创建快捷方式。

## 构建、测试与本地运行
- `flutter pub get`：安装依赖。
- `flutter analyze`：静态检查，需在合入前保持无告警。
- `flutter test`：运行全部 Dart/Widget 测试。
- `flutter run -d windows`：本地调试，确保连接设备可用。
- `flutter build windows --release`：生成 Release 可执行文件（`build/windows/runner/Release/adb_wifi_connector.exe`）。
- `flutter pub run msix:create`：按 `pubspec.yaml` 的 `msix_config` 打包 MSIX，如仅本地验证可改为 `store: false`。

## 编码风格与命名
- 遵循 `analysis_options.yaml` 与 `flutter_lints`；2 空格缩进，优先使用 `const`/`final`。
- 文件名使用下划线风格，类用帕斯卡命名，变量/方法用小驼峰；字符串默认单引号。
- UI 逻辑保持简洁，将 I/O、ADB 命令集中在 `AdbService`，便于测试与复用。

## 测试指南
- 框架：`flutter_test`。测试文件放在 `test/` 并以 `*_test.dart` 结尾。
- 覆盖重点：ADB 命令包装、历史记录持久化、系统托盘/窗口状态变更的副作用。
- 运行前确保本地 `adb` 不被占用，必要时用 `flutter test --test-randomize-ordering-seed random` 检查隐含依赖。

## 提交与 PR 规范
- 提交信息参考当前历史（如“排序”“托盘时间长了点击无效问题”），保持简洁中文动宾短语。
- 每个提交聚焦单一改动，避免混合格式化与功能更改。
- PR 请附：变更摘要、关联 issue/需求、测试结果（含 `flutter analyze`/`flutter test`/关键运行步骤）、必要的 UI 截图或录屏。
- 合入前自查打包是否受影响（MSIX/可执行文件体积、启动脚本路径）。

## 安全与配置提示
- 保持 `assets/adb` 与证书文件安全，勿上传新的密钥到公开仓库；签名配置修改需说明用途。
- 项目仅针对 Windows 桌面，调试时确认设备与电脑同网且已开启 USB 调试授权。
