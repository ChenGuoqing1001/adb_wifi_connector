import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'services/adb_service.dart';
import 'dart:io';
import 'l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // 检查并设置开机自启动
  await setupAutoStart();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 600),
    center: true,
    title: 'ADB WiFi Connector',
    minimumSize: Size(400, 600),
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

// 添加开机自启动相关函数
Future<void> setupAutoStart() async {
  if (Platform.isWindows) {
    final startupPath =
        '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs\\Startup';
    final shortcutPath = '$startupPath\\ADB WiFi Connector.lnk';
    final exePath =
        '${Directory.current.path}\\build\\windows\\runner\\Release\\adb_wifi_connector.exe';

    try {
      final shortcut = File(shortcutPath);
      if (!await shortcut.exists()) {
        // 创建快捷方式
        final result = await Process.run('powershell', [
          '-Command',
          '''
          \$WS = New-Object -ComObject WScript.Shell;
          \$SC = \$WS.CreateShortcut('$shortcutPath');
          \$SC.TargetPath = '$exePath';
          \$SC.Save();
          '''
        ]);

        if (result.exitCode != 0) {
          print('创建开机自启动快捷方式失败: ${result.stderr}');
        }
      }
    } catch (e) {
      print('设置开机自启动失败: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB WiFi Connector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  final AdbService _adbService = AdbService();
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  List<String> _history = [];
  final TextEditingController _ipController = TextEditingController();
  List<String> _devices = [];
  final Map<String, String> _deviceNames = {};
  String? _lastTrayMenuSignature;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeWithAutoConnect();
    _startDevicePolling();
  }

  Future<void> _initializeWithAutoConnect() async {
    await _initializeAdb();
    await _initSystemTray();
    _history = await _loadHistory();
    await _autoConnectDevices();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onWindowFocus() {
    windowManager.setPreventClose(true);
  }

  Future<List<String>> _loadHistory() async {
    try {
      final appDataPath = Platform.environment['APPDATA'];
      final filePath =
          '$appDataPath\\ADB WiFi Connector\\connection_history.txt';
      final file = File(filePath);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        return lines
            .where((ip) => ip.trim().isNotEmpty && ip.endsWith(':5555'))
            .toList();
      }
    } catch (e) {
      print('加载历史记录失败: $e');
    }
    return [];
  }

  Future<void> _autoConnectDevices() async {
    if (_history.isEmpty) return;

    for (String ip in _history) {
      try {
        _adbService.connectDevice(ip);
        print('自动连接设备: $ip');
      } catch (e) {
        print('自动连接设备失败: $ip - $e');
      }
    }

    await _updateDeviceList();
  }

  Future<void> _saveHistory(
      {required String ip, bool isWriteFile = true}) async {
    if (ip.trim().isEmpty) return;

    if (!_history.contains(ip)) {
      _history.insert(0, ip);
      if (_history.length > 10) {
        _history.removeLast();
      }
      setState(() {});
    }

    if (isWriteFile) {
      final List<String> _localHistory = await _loadHistory();
      if (_localHistory.contains(ip)) return;
      _localHistory.insert(0, ip);
      if (_localHistory.length > 10) {
        _localHistory.removeLast();
      }
      final appDataPath = Platform.environment['APPDATA'];
      final directoryPath = '$appDataPath\\ADB WiFi Connector';
      final filePath = '$directoryPath\\connection_history.txt';

      // 确保目录存在
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File(filePath);
      try {
        await file.writeAsString(_localHistory.join('\n'));
      } catch (e) {
        print('保存历史记录失败: $e');
      }
    }
  }

  Future<void> _initializeAdb() async {
    await _adbService.startAdbServer();
    _updateDeviceList();
  }

  Future<void> _updateDeviceList() async {
    _devices = await _adbService.getConnectedDevices();

    // 只为未缓存的设备获取名称
    for (String device in _devices) {
      if (!_deviceNames.containsKey(device)) {
        final name = await _adbService.getDeviceName(device);

        if (name != null) {
          setState(() {
            _deviceNames[device] = name;
          });
        }
      }
    }

    setState(() {
      // 更新状态
    });

    for (String device in _devices) {
      if (!_history.contains(device)) {
        await _adbService.open5555port(device);
      }
      _saveHistory(
          ip: device, isWriteFile: !device.endsWith(':5555') ? false : true);
    }
    await _updateTrayMenu();
  }

  Future<void> _initSystemTray() async {
    try {
      // 获取可执行文件所在目录
      final exePath = Platform.resolvedExecutable;
      final exeDir = Directory(exePath).parent.path;

      String iconPath = Platform.isWindows
          ? '$exeDir\\data\\flutter_assets\\assets\\app_icon.ico'
          : 'assets/app_icon.ico';

      if (!await File(iconPath).exists()) {
        iconPath = '$exeDir\\app_icon.ico';
        if (!await File(iconPath).exists()) {
          print('图标文件不存在: $iconPath');
          return;
        }
      }

      // 确保先销毁旧的系统托盘实例
      await _systemTray.destroy();
      await Future.delayed(const Duration(milliseconds: 100));

      // 初始化新的系统托盘
      await _systemTray.initSystemTray(
        title: "ADB WiFi Connector",
        iconPath: iconPath,
        toolTip: "ADB WiFi Connector", // 直接设置工具提示
      );

      // 更新菜单
      await _updateTrayMenu();

      // 使用更稳定的事件处理方式
      _systemTray.registerSystemTrayEventHandler((eventName) async {
        try {
          if (eventName == kSystemTrayEventClick) {
            await windowManager.show();
          } else if (eventName == kSystemTrayEventRightClick) {
            await _systemTray.popUpContextMenu();
          }
        } catch (e) {
          print('系统托盘事件处理错误: $e');
          // 尝试重新初始化系统托盘
          await _initSystemTray();
        }
      });

      // 添加定期检查系统托盘状态
      _startTrayHealthCheck();
    } catch (e) {
      print('初始化系统托盘失败: $e');
      // 延迟后重试
      await Future.delayed(const Duration(seconds: 1));
      await _initSystemTray();
    }
  }

  void _startTrayHealthCheck() {
    Future.doWhile(() async {
      try {
        // 每30分钟检查一次系统托盘状态
        await Future.delayed(const Duration(minutes: 30));
        await _systemTray.setToolTip("ADB WiFi Connector");
      } catch (e) {
        print('系统托盘状态检查失败: $e');
        // 如果检查失败，重新初始化系统托盘
        await _initSystemTray();
      }
      return true;
    });
  }

  Future<void> _updateTrayMenu() async {
    final l10n = AppLocalizations(
        PlatformDispatcher.instance.locale ?? const Locale('zh'));

    final String currentSignature = _buildTraySignature();
    if (_lastTrayMenuSignature == currentSignature) {
      return;
    }
    _lastTrayMenuSignature = currentSignature;

    List<MenuItemBase> items = [
      MenuItemLabel(label: l10n.deviceList, enabled: false),
    ];

    for (String device in _history) {
      final bool isConnected = _devices.contains(device);
      final String displayName = _deviceNames[device] ?? device;
      items.add(
        MenuItemCheckbox(
          label: '$displayName ($device)',
          checked: isConnected,
          onClicked: (menuItem) async {
            await _toggleConnection(device, isConnected);
          },
        ),
      );
    }

    items.addAll([
      MenuSeparator(),
      MenuItemLabel(label: l10n.exit, onClicked: (menuItem) => _quit()),
    ]);

    await _menu.buildFrom(items);
    await _systemTray.setContextMenu(_menu);
  }

  String _buildTraySignature() {
    final buffer = StringBuffer();
    for (final device in _history) {
      final name = _deviceNames[device] ?? '';
      final bool isConnected = _devices.contains(device);
      buffer.write('$device|$name|$isConnected;');
    }
    return buffer.toString();
  }

  void _startDevicePolling() {
    Future.doWhile(() async {
      await _updateDeviceList();

      // 检查设备IP并连接到ip:5555
      for (String device in _devices) {
        if (!device.endsWith(':5555')) {
          try {
            final ips = await _adbService.getDeviceIps(device);
            if (ips != null && ips.isNotEmpty) {
              for (final ip in ips) {
                if (_history.contains(ip)) {
                  continue;
                }
                print('尝试连接到IP: $ip');
                _adbService.connectDevice(ip);
                _saveHistory(ip: ip, isWriteFile: false);
                print('成功连接到设备: $ip');
              }
            } else {
              print('未获取到设备 $device 的IP地址');
            }
          } catch (e) {
            print('获取设备IP或连接失败: $device - $e');
          }
        }
      }
      await _updateDeviceList();

      await Future.delayed(const Duration(seconds: 5));
      return true;
    });
  }

  Future<void> _quit() async {
    try {
      // 断开所有设备连接
      for (String device in _devices) {
        await _adbService.disconnectDevice(device);
      }

      // 销毁系统托盘
      await _systemTray.destroy();

      // 强制退出程序
      exit(0);
    } catch (e) {
      print('退出程序失败: $e');
      // 确保程序退出
      exit(1);
    }
  }

  Future<void> _connectDevice() async {
    if (_ipController.text.isNotEmpty) {
      await _adbService.connectDevice(_ipController.text);
      await _saveHistory(ip: _ipController.text);
      await _updateDeviceList();
    }
  }

  Future<void> _removeFromHistory(String ip) async {
    await _adbService.disconnectDevice(ip);
    setState(() {
      _history.remove(ip);
    });
    List<String> _localHistory = await _loadHistory();
    _localHistory.remove(ip);
    final appDataPath = Platform.environment['APPDATA'];
    final filePath = '$appDataPath\\ADB WiFi Connector\\connection_history.txt';
    final file = File(filePath);
    await file.writeAsString(_localHistory.join('\n'));
    await _updateTrayMenu();
  }

  Future<void> _toggleConnection(String device, bool isConnected) async {
    if (isConnected) {
      await _adbService.disconnectDevice(device);
    } else {
      _ipController.text = device;
      await _connectDevice();
    }
    await _updateDeviceList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // 对历史记录进行排序，已连接的设备在前
    final sortedHistory = List<String>.from(_history)
      ..sort((a, b) {
        final isAConnected = _devices.contains(a);
        final isBConnected = _devices.contains(b);
        if (isAConnected == isBConnected) return 0;
        return isAConnected ? -1 : 1;
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(l10n.usbConnectionHint),
            const SizedBox(height: 20),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: l10n.inputIpHint,
                hintText: l10n.ipExample,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _connectDevice,
              child: Text(l10n.connectDevice),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: sortedHistory.length,  // 使用排序后的列表
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: 0.5,
                ),
                itemBuilder: (context, index) {
                  final device = sortedHistory[index];  // 使用排序后的列表
                  final bool isConnected = _devices.contains(device);
                  final String deviceName = _deviceNames[device] ?? '';

                  return ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device,
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                            )),
                        if (deviceName.isNotEmpty && isConnected)
                          Text(
                            deviceName,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                      ],
                    ),
                    subtitle:
                        Text(isConnected ? l10n.connected : l10n.disconnected),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isConnected ? Icons.link_off : Icons.link,
                            color: isConnected ? Colors.green : Colors.grey,
                          ),
                          onPressed: () async {
                            await _toggleConnection(device, isConnected);
                          },
                        ),
                        PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text(l10n.delete),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'delete') {
                              await _removeFromHistory(device);
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      await _toggleConnection(device, isConnected);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
