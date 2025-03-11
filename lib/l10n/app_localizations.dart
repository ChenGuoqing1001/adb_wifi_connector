import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _localizedValues = {
    'en': {
      'appTitle': 'ADB WiFi Connector',
      'usbConnectionHint': 'USB connection required for first time or after device reboot',
      'inputIpHint': 'Enter device IP address and port',
      'ipExample': 'e.g. 192.168.1.100:5555',
      'connectDevice': 'Connect Device',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'delete': 'Delete',
      'deviceList': 'Device List',
      'exit': 'Exit',
    },
    'zh': {
      'appTitle': 'ADB WiFi Connector',
      'usbConnectionHint': '首次连接或重启手机之后需要用USB连接设备',
      'inputIpHint': '输入设备 IP 地址和端口',
      'ipExample': '例如: 192.168.1.100:5555',
      'connectDevice': '连接设备',
      'connected': '已连接',
      'disconnected': '未连接',
      'delete': '删除',
      'deviceList': '设备列表',
      'exit': '退出',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]!['appTitle']!;
  String get usbConnectionHint => _localizedValues[locale.languageCode]!['usbConnectionHint']!;
  String get inputIpHint => _localizedValues[locale.languageCode]!['inputIpHint']!;
  String get ipExample => _localizedValues[locale.languageCode]!['ipExample']!;
  String get connectDevice => _localizedValues[locale.languageCode]!['connectDevice']!;
  String get connected => _localizedValues[locale.languageCode]!['connected']!;
  String get disconnected => _localizedValues[locale.languageCode]!['disconnected']!;
  String get delete => _localizedValues[locale.languageCode]!['delete']!;
  String get deviceList => _localizedValues[locale.languageCode]!['deviceList']!;
  String get exit => _localizedValues[locale.languageCode]!['exit']!;
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}