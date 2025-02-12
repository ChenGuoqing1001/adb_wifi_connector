import 'dart:io';

class AdbService {
  static const String _adbPath = 'adb';

  Future<void> startAdbServer() async {
    try {
      await Process.run(_adbPath, ['start-server']);
    } catch (e) {
      print('启动 ADB 服务器失败: $e');
    }
  }

  Future<List<String>> getConnectedDevices() async {
    try {
      final result = await Process.run(_adbPath, ['devices']);
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
      await Process.run(_adbPath, ['connect', ip]);
    } catch (e) {
      print('连接设备失败: $e');
    }
  }

  Future<void> open5555port(String device) async {
    try {
      await Process.run(_adbPath, ['-s', device, 'tcpip', '5555']);
    } catch (e) {
      print('打开5555端口失败: $e');
    }
  }

  Future<void> disconnectDevice(String ip) async {
    try {
      await Process.run(_adbPath, ['disconnect', ip]);
    } catch (e) {
      print('断开设备失败: $e');
    }
  }

  Future<List<String>> getDeviceIps(String device) async {
    try {
      final result =
          await Process.run(_adbPath, ['-s', device, 'shell', 'ip', 'route']);
      final matches = RegExp(r'src (\d+\.\d+\.\d+\.\d+)')
          .allMatches(result.stdout.toString());
      return matches.map((match) => '${match.group(1)}:5555').toList();
    } catch (e) {
      print('获取设备IP失败: $e');
    }
    return [];
  }
}
