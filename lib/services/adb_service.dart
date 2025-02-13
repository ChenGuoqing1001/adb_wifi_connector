import 'dart:io';
import 'package:path/path.dart' as path;

class AdbService {
  static String? _adbPath;
  
  static Future<String> getAdbPath() async {
    if (_adbPath != null) return _adbPath!;
    
    // 获取应用程序目录路径
    final String appDir = Platform.isWindows 
        ? path.dirname(Platform.resolvedExecutable)
        : Platform.resolvedExecutable;
        
    // 构建adb路径
    _adbPath = Platform.isWindows
        ? path.join(appDir, 'data', 'flutter_assets', 'assets', 'adb', 'adb.exe')
        : path.join(appDir, 'data', 'flutter_assets', 'assets', 'adb', 'adb');
    
    return _adbPath!;
  }

  static Future<Process> startServer() async {
    final adbPath = await getAdbPath();
    return await Process.start(adbPath, ['start-server']);
  }

  Future<void> startAdbServer() async {
    try {
      final adbPath = await getAdbPath();
      await Process.run(adbPath, ['start-server']);
    } catch (e) {
      print('启动 ADB 服务器失败: $e');
    }
  }

  Future<List<String>> getConnectedDevices() async {
    try {
      final adbPath = await getAdbPath();
      final result = await Process.run(adbPath, ['devices']);
      final lines = result.stdout.toString().split('\n');
      return lines
          .skip(1)
          .where((line) => line.trim().isNotEmpty && !line.contains('offline'))
          .map((line) => line.split('\t')[0])
          .toList();
    } catch (e) {
      print('获取设备列表失败: $e');
      return [];
    }
  }

  Future<void> connectDevice(String ip) async {
    try {
      final adbPath = await getAdbPath();
      await Process.run(adbPath, ['connect', ip]);
    } catch (e) {
      print('连接设备失败: $e');
    }
  }

  Future<void> open5555port(String device) async {
    try {
      final adbPath = await getAdbPath();
      await Process.run(adbPath, ['-s', device, 'tcpip', '5555']);
    } catch (e) {
      print('打开5555端口失败: $e');
    }
  }

  Future<void> disconnectDevice(String ip) async {
    try {
      final adbPath = await getAdbPath();
      await Process.run(adbPath, ['disconnect', ip]);
    } catch (e) {
      print('断开设备失败: $e');
    }
  }

  Future<List<String>> getDeviceIps(String device) async {
    try {
      final adbPath = await getAdbPath();
      final result =
          await Process.run(adbPath, ['-s', device, 'shell', 'ip', 'route']);
      final matches = RegExp(r'src (\d+\.\d+\.\d+\.\d+)')
          .allMatches(result.stdout.toString());
      return matches.map((match) => '${match.group(1)}:5555').toList();
    } catch (e) {
      print('获取设备IP失败: $e');
    }
    return [];
  }
}
