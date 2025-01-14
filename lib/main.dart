import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'services/adb_service.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // 检查并设置开机自启动
  await setupAutoStart();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 600),
    center: true,
    title: 'ADB WiFi 连接器',
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
    final startupPath = '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs\\Startup';
    final shortcutPath = '$startupPath\\ADB WiFi连接器.lnk';
    final exePath = '${Directory.current.path}\\build\\windows\\runner\\Release\\adb_wifi_connector.exe';

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
      title: 'ADB WiFi 连接器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  String _status = '未连接';
  List<String> _devices = [];
  List<String> _history = [];
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initializeWithAutoConnect();
  }

  Future<void> _initializeWithAutoConnect() async {
    await _loadHistory();
    await _initializeAdb();
    await _initSystemTray();
    
    // 启动时自动最小化到托盘
    if (_history.isNotEmpty) {
      await windowManager.hide();
    }
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

  Future<void> _loadHistory() async {
    try {
      final file = File('${Directory.current.path}/connection_history.txt');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        setState(() {
          _history = lines.where((ip) => ip.trim().isNotEmpty).toList();
        });
        _autoConnectDevices();
      }
    } catch (e) {
      print('加载历史记录失败: $e');
    }
  }

  Future<void> _autoConnectDevices() async {
    if (_history.isEmpty) return;
    
    setState(() {
      _status = '正在尝试连接设备...';
    });

    for (String ip in _history) {
      try {
        await _adbService.connectDevice(ip);
        print('自动连接设备: $ip');
      } catch (e) {
        print('自动连接设备失败: $ip - $e');
      }
      // 添加短暂延迟，避免连接太快
      await Future.delayed(const Duration(seconds: 1));
    }

    await _updateDeviceList();
  }

  Future<void> _saveHistory(String ip) async {
    if (ip.trim().isEmpty) return;
    
    setState(() {
      if (!_history.contains(ip)) {
        _history.insert(0, ip);
        if (_history.length > 10) {
          _history.removeLast();
        }
      }
    });

    try {
      final file = File('${Directory.current.path}/connection_history.txt');
      await file.writeAsString(_history.join('\n'));
    } catch (e) {
      print('保存历史记录失败: $e');
    }
  }

  Future<void> _initializeAdb() async {
    await _adbService.startAdbServer();
    _updateDeviceList();
  }

  Future<void> _updateDeviceList() async {
    final devices = await _adbService.getConnectedDevices();
    setState(() {
      _devices = devices;
      _status = devices.isEmpty ? '未连接设备' : '已连接 ${devices.length} 个设备';
    });
    await _updateTrayMenu();
  }

  Future<void> _initSystemTray() async {
    try {
      // 获取可执行文件所在目录
      final exePath = Platform.resolvedExecutable;
      final exeDir = Directory(exePath).parent.path;
      
      // 构建图标路径
      String iconPath = Platform.isWindows
          ? '$exeDir\\data\\flutter_assets\\assets\\app_icon.ico'
          : 'assets/app_icon.ico';

      print('尝试加载图标: $iconPath'); // 调试用

      // 确保图标文件存在
      if (!await File(iconPath).exists()) {
        print('图标文件不存在，尝试备用路径');
        // 尝试备用路径
        iconPath = '$exeDir\\app_icon.ico';
        if (!await File(iconPath).exists()) {
          print('备用图标文件也不存在: $iconPath');
          return;
        }
      }

      // 先销毁可能存在的旧实例
      await _systemTray.destroy();
      
      // 重新初始化系统托盘
      await _systemTray.initSystemTray(
        title: "ADB WiFi 连接器",
        iconPath: iconPath,
      );

      // 确保图标显示
      await Future.delayed(const Duration(milliseconds: 500));
      await _systemTray.setToolTip("ADB WiFi 连接器");
      await _updateTrayMenu();
      
      // 注册事件处理
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          windowManager.show();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      _startDevicePolling();
    } catch (e) {
      print('初始化系统托盘失败: $e');
    }
  }

  Future<void> _updateTrayMenu() async {
    List<MenuItemBase> items = [
      MenuItemLabel(label: '显示窗口', onClicked: (menuItem) => windowManager.show()),
      MenuSeparator(),
      MenuItemLabel(label: '设备列表', enabled: false),
    ];
    
    // 合并历史记录和当前设备
    List<String> allDevices = [..._history];
    for (String device in _devices) {
      if (!allDevices.contains(device)) {
        allDevices.add(device);
      }
    }

    // 添加所有设备到菜单
    for (String device in allDevices) {
      final bool isConnected = _devices.contains(device);
      items.add(
        MenuItemCheckbox(
          label: device,
          checked: isConnected,
          onClicked: (menuItem) async {
            await _toggleConnection(device, isConnected);
          },
        ),
      );
    }
    
    items.addAll([
      MenuSeparator(),
      MenuItemLabel(label: '退出', onClicked: (menuItem) => _quit()),
    ]);

    await _menu.buildFrom(items);
    await _systemTray.setContextMenu(_menu);
  }

  void _startDevicePolling() {
    Future.doWhile(() async {
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
      await _saveHistory(_ipController.text);
      await _updateDeviceList();
    }
  }

  Future<void> _removeFromHistory(String ip) async {
    setState(() {
      _history.remove(ip);
    });
    final file = File('${Directory.current.path}/connection_history.txt');
    await file.writeAsString(_history.join('\n'));
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
    // 确保历史记录在前面显示
    List<String> allDevices = [..._history];
    // 添加未在历史记录中的已连接设备
    for (String device in _devices) {
      if (!allDevices.contains(device)) {
        allDevices.add(device);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ADB WiFi 连接器'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('状态: $_status'),
            const SizedBox(height: 20),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: '输入设备 IP 地址',
                hintText: '例如: 192.168.1.100',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _connectDevice,
              child: const Text('连接设备'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: allDevices.length,
                itemBuilder: (context, index) {
                  final device = allDevices[index];
                  final bool isConnected = _devices.contains(device);
                  
                  return ListTile(
                    title: Text(device),
                    subtitle: Text(isConnected ? '已连接' : '未连接'),
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
                              child: const Text('删除'),
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