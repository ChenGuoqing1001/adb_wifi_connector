import 'dart:convert';
import 'dart:io';
import '../utils/logger.dart';
import 'package:path/path.dart' as path;

class AdbService {
  static String? _adbPath;

  static bool _isConnectSuccess(ProcessResult result) {
    final stdoutStr = result.stdout.toString().toLowerCase();
    final stderrStr = result.stderr.toString().toLowerCase();
    final combined = '$stdoutStr $stderrStr';
    if (combined.contains('connected to') ||
        combined.contains('already connected')) {
      return true;
    }
    if (combined.contains('cannot connect') ||
        combined.contains('failed to connect') ||
        combined.contains('unable to connect') ||
        combined.contains('no route to host') ||
        combined.contains('10060') ||
        combined.contains('10061')) {
      return false;
    }
    return result.exitCode == 0;
  }

  static Future<ProcessResult> _runAdbCommand(
    List<String> args, {
    String? action,
    bool onlyOnError = false,
  }) async {
    final adbPath = await getAdbPath();
    final desc = action != null ? '($action)' : '';
    final commandLine = '$adbPath ${args.join(' ')}';

    if (!onlyOnError) {
      logWithTime('ADB$desc 执行: $commandLine');
    }

    ProcessResult result;
    if (Platform.isWindows) {
      // 在 Windows 下强制 PowerShell 输出 UTF-8，避免中文乱码
      final escapedPath = adbPath.replaceAll("'", "''");
      final escapedArgs =
          args.map((arg) => "'${arg.replaceAll("'", "''")}'").join(' ');
      final psCommand =
          "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '$escapedPath' $escapedArgs";
      result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', psCommand],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } else {
      result = await Process.run(
        adbPath,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    }
    final stdoutStr = result.stdout.toString().trim();
    final stderrStr = result.stderr.toString().trim();
    final shouldLog = !onlyOnError || result.exitCode != 0;

    if (shouldLog) {
      if (onlyOnError) {
        logWithTime('ADB$desc 执行: $commandLine');
      }
      logWithTime('ADB$desc 退出码: ${result.exitCode}');
      if (stdoutStr.isNotEmpty) {
        logWithTime('ADB$desc 输出: $stdoutStr');
      }
      if (stderrStr.isNotEmpty) {
        logWithTime('ADB$desc 错误: $stderrStr');
      }
    }

    return result;
  }
  
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

    if (!await File(_adbPath!).exists()) {
      logWithTime('ADB 可执行文件不存在: $_adbPath');
    } else {
      logWithTime('使用 ADB 路径: $_adbPath');
    }
    
    return _adbPath!;
  }

  static Future<Process> startServer() async {
    final adbPath = await getAdbPath();
    return await Process.start(adbPath, ['start-server']);
  }

  Future<bool> startAdbServer() async {
    try {
      final result = await _runAdbCommand(
        ['start-server'],
        action: '启动 ADB 服务器',
      );
      return result.exitCode == 0;
    } catch (e) {
      logWithTime('启动 ADB 服务器失败: $e');
      return false;
    }
  }

  Future<List<String>> getConnectedDevices() async {
    try {
      final result = await _runAdbCommand(
        ['devices'],
        action: '查询设备列表',
        onlyOnError: true,
      );
      if (result.exitCode != 0) {
        return [];
      }
      final lines = result.stdout.toString().split('\n');
      return lines
          .skip(1)
          .where((line) => line.trim().isNotEmpty && !line.contains('offline'))
          .map((line) => line.split('\t')[0])
          .toList();
    } catch (e) {
      logWithTime('获取设备列表失败: $e');
      return [];
    }
  }

  Future<bool> connectDevice(String ip) async {
    if (ip.trim().isEmpty) {
      logWithTime('连接设备失败: IP 为空');
      return false;
    }
    try {
      final result = await _runAdbCommand(
        ['connect', ip],
        action: '连接 $ip',
      );
      final success = _isConnectSuccess(result);
      if (!success) {
        logWithTime('连接 $ip 判定失败，stdout/stderr 已记录');
      }
      return success;
    } catch (e) {
      logWithTime('连接设备失败: $e');
      return false;
    }
  }

  Future<bool> open5555port(String device) async {
    if (device.trim().isEmpty) {
      logWithTime('打开 5555 端口失败: 设备序列号为空');
      return false;
    }
    try {
      final result = await _runAdbCommand(
        ['-s', device, 'tcpip', '5555'],
        action: '为 $device 打开 5555 端口',
      );
      return result.exitCode == 0;
    } catch (e) {
      logWithTime('打开5555端口失败: $e');
      return false;
    }
  }

  Future<bool> disconnectDevice(String ip) async {
    if (ip.trim().isEmpty) {
      return false;
    }
    try {
      final result = await _runAdbCommand(
        ['disconnect', ip],
        action: '断开 $ip',
      );
      return result.exitCode == 0;
    } catch (e) {
      logWithTime('断开设备失败: $e');
      return false;
    }
  }

  Future<List<String>> getDeviceIps(String device) async {
    Future<ProcessResult> runIpRoute() => _runAdbCommand(
          ['-s', device, 'shell', 'ip', 'route'],
          action: '获取设备路由信息 $device',
        );

    List<String> parseRoutes(ProcessResult result) {
      final matches = RegExp(r'src (\d+\.\d+\.\d+\.\d+)')
          .allMatches(result.stdout.toString());
      return matches.map((match) => '${match.group(1)}:5555').toList();
    }

    try {
      final result = await runIpRoute();
      List<String> ips = parseRoutes(result);

      // 若 ip route 因 tcpip 重启导致 closed，则延迟重试一次
      if (ips.isEmpty || result.exitCode != 0) {
        logWithTime('首次获取路由为空/失败，准备重试: $device');
        await Future.delayed(const Duration(seconds: 1));
        final retryResult = await runIpRoute();
        ips = parseRoutes(retryResult);
      }

      if (ips.isNotEmpty) {
        return ips;
      }

      // 兜底尝试直接读取 wlan0 IP
      final ipAddrResult = await _runAdbCommand(
        ['-s', device, 'shell', 'ip', '-f', 'inet', 'addr', 'show', 'wlan0'],
        action: '获取 WLAN IP ' + device,
        onlyOnError: true,
      );
      if (ipAddrResult.exitCode == 0) {
        final matches =
            RegExp(r'inet (\d+\.\d+\.\d+\.\d+)').allMatches(ipAddrResult.stdout.toString());
        final fallbackIps = matches.map((m) => '${m.group(1)}:5555').toList();
        if (fallbackIps.isNotEmpty) {
          logWithTime('通过 ip addr 获得 WLAN IP: ${fallbackIps.join(', ')}');
          return fallbackIps;
        }
      }
    } catch (e) {
      logWithTime('获取设备IP失败: $e');
    }
    return [];
  }

  Future<String?> getDeviceName(String deviceId) async {
    try {
      // 获取品牌名称
      final brandResult = await _runAdbCommand(
        ['-s', deviceId, 'shell', 'getprop', 'ro.product.brand'],
        action: '查询品牌 $deviceId',
      );
      
      // 获取型号名称
      final modelResult = await _runAdbCommand(
        ['-s', deviceId, 'shell', 'getprop', 'ro.product.model'],
        action: '查询型号 $deviceId',
      );
      
      // 获取Android版本
      final androidVersionResult = await _runAdbCommand(
        ['-s', deviceId, 'shell', 'getprop', 'ro.build.version.release'],
        action: '查询系统版本 $deviceId',
      );
      
      if (brandResult.exitCode == 0 && modelResult.exitCode == 0 && androidVersionResult.exitCode == 0) {
        String brand = brandResult.stdout.toString().trim();
        String model = modelResult.stdout.toString().trim();
        String androidVersion = androidVersionResult.stdout.toString().trim();
        
        // 组合品牌、型号和Android版本
        List<String> parts = [];
        if (brand.isNotEmpty) parts.add(brand);
        if (model.isNotEmpty) parts.add(model);
        if (androidVersion.isNotEmpty) parts.add('Android $androidVersion');
        
        return parts.join(' ');
      }
    } catch (e) {
      logWithTime('获取设备名称失败: $e');
    }
    return null;
  }
}
