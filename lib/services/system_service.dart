import 'package:flutter/services.dart';

class SystemService {
  static const MethodChannel _channel =
      MethodChannel('com.ultimate.jarvis/system');

  static Future<void> init() async {}
  static Future<void> requestPermissions() async {}

  static Future<Map<String, dynamic>> _map(String method,
      [Map<String, dynamic>? args]) async {
    try {
      final result = await _channel.invokeMethod<dynamic>(method, args);
      if (result is Map) return Map<String, dynamic>.from(result);
      return <String, dynamic>{'status': result?.toString() ?? 'unknown'};
    } catch (e) {
      return <String, dynamic>{'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> location() => _map('getLocation');
  static Future<Map<String, dynamic>> batteryStatus() =>
      _map('getBatteryStatus');
  static Future<Map<String, dynamic>> wifiState() => _map('getWifiState');
  static Future<Map<String, dynamic>> bluetoothState() =>
      _map('getBluetoothState');
  static Future<bool> openWifiSettings() async =>
      await _channel.invokeMethod<bool>('openWifiSettings') ?? false;
  static Future<bool> openHotspotSettings() async =>
      await _channel.invokeMethod<bool>('openHotspotSettings') ?? false;
  static Future<bool> openBluetoothSettings() async =>
      await _channel.invokeMethod<bool>('openBluetoothSettings') ?? false;
  static Future<bool> openAccessibilitySettings() async =>
      await _channel.invokeMethod<bool>('openAccessibilitySettings') ?? false;
  static Future<bool> openAppSettings() async =>
      await _channel.invokeMethod<bool>('openAppSettings') ?? false;
  static Future<Map<String, dynamic>> suggestWifi({
    required String ssid,
    required String password,
  }) =>
      _map('suggestWifi', {'ssid': ssid, 'password': password});
  static Future<Map<String, dynamic>> removeWifiSuggestions() =>
      _map('removeWifiSuggestions');
  static Future<Map<String, dynamic>> resolvePackage(String appName) =>
      _map('resolvePackage', {'appName': appName});
  static Future<Map<String, dynamic>> launchPackage(String packageName) =>
      _map('launchPackage', {'packageName': packageName});
  static Future<Map<String, dynamic>> dial(String number) =>
      _map('dial', {'number': number});
}
