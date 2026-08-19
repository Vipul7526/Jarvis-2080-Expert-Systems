import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TabLockPolicy {
  final int? id;
  final String domain;
  final String mode;
  final String? unlockSalt;
  final String? unlockVerifier;
  final String failurePage;
  final bool relockOnRefresh;

  const TabLockPolicy({
    this.id,
    required this.domain,
    required this.mode,
    this.unlockSalt,
    this.unlockVerifier,
    required this.failurePage,
    required this.relockOnRefresh,
  });

  factory TabLockPolicy.fromJson(Map<String, dynamic> json) => TabLockPolicy(
        id: json['id'] is int ? json['id'] as int : null,
        domain: json['domain']?.toString() ?? '',
        mode: json['mode']?.toString() ?? 'block',
        unlockSalt: json['unlockSalt']?.toString(),
        unlockVerifier: json['unlockVerifier']?.toString(),
        failurePage: json['failurePage']?.toString() ?? 'blocked',
        relockOnRefresh: json['relockOnRefresh'] != false,
      );
}

class TabLockDevice {
  final String deviceId;
  final String deviceType;
  final String deviceName;
  final bool paired;
  final bool revoked;

  const TabLockDevice({
    required this.deviceId,
    required this.deviceType,
    required this.deviceName,
    required this.paired,
    required this.revoked,
  });

  factory TabLockDevice.fromJson(Map<String, dynamic> json) => TabLockDevice(
        deviceId: json['deviceId']?.toString() ?? '',
        deviceType: json['deviceType']?.toString() ?? '',
        deviceName: json['deviceName']?.toString() ?? '',
        paired: json['paired'] == true,
        revoked: json['revoked'] == true,
      );
}

class TabLockSnapshot {
  final String groupId;
  final List<TabLockPolicy> policies;
  final List<TabLockDevice> devices;

  const TabLockSnapshot({
    required this.groupId,
    required this.policies,
    required this.devices,
  });

  factory TabLockSnapshot.fromJson(Map<String, dynamic> json) =>
      TabLockSnapshot(
        groupId: json['groupId']?.toString() ?? '',
        policies: (json['policies'] as List? ?? [])
            .whereType<Map>()
            .map((item) =>
                TabLockPolicy.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        devices: (json['devices'] as List? ?? [])
            .whereType<Map>()
            .map((item) =>
                TabLockDevice.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class TabLockService {
  static const String baseUrl =
      'https://jarvisrecov-3mlp5xq9.manus.space/api/tab-lock';
  static const _deviceIdKey = 'tab_lock_device_id';
  static const _deviceNameKey = 'tab_lock_device_name';
  static const _tokenKey = 'tab_lock_token';
  static const _groupIdKey = 'tab_lock_group_id';
  static const _pairingCodeKey = 'tab_lock_pairing_code';
  static const _pairingExpiryKey = 'tab_lock_pairing_expiry';

  final http.Client _client;
  final Random _random = Random.secure();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  TabLockService({http.Client? client}) : _client = client ?? http.Client();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<String> _readToken(SharedPreferences prefs) async {
    final secureToken = await _secureStorage.read(key: _tokenKey);
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;
    final legacyToken = prefs.getString(_tokenKey) ?? '';
    if (legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      await prefs.remove(_tokenKey);
    }
    return legacyToken;
  }

  String _randomToken(int bytes) => base64UrlEncode(
        List<int>.generate(bytes, (_) => _random.nextInt(256)),
      ).replaceAll('=', '');

  String _randomSalt() => _randomToken(18);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final prefs = await _prefs();
    final token = await _readToken(prefs);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated && token.isEmpty) {
      throw StateError('Tab Lock controller is not registered.');
    }
    if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final uri = Uri.parse('$baseUrl$path');
    final response = method == 'GET'
        ? await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 20))
        : await _client
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    final result = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['success'] == false) {
      throw StateError(result['error']?.toString() ??
          'Tab Lock request failed (${response.statusCode}).');
    }
    return result;
  }

  Future<Map<String, dynamic>> registerController(
      {String deviceName = 'JARVIS Android'}) async {
    final prefs = await _prefs();
    final existing = await _readToken(prefs);
    if (existing != null && existing.isNotEmpty) {
      return {
        'deviceId': prefs.getString(_deviceIdKey) ?? '',
        'deviceName': prefs.getString(_deviceNameKey) ?? deviceName,
        'groupId': prefs.getString(_groupIdKey) ?? '',
        'pairingCode': prefs.getString(_pairingCodeKey) ?? '',
        'pairingExpiresAt': prefs.getInt(_pairingExpiryKey) ?? 0,
      };
    }
    final deviceId = 'android-${_randomToken(12)}';
    final result =
        await _request('POST', '/register', authenticated: false, body: {
      'deviceId': deviceId,
      'deviceType': 'android',
      'deviceName': deviceName,
    });
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_deviceNameKey, deviceName);
    await _secureStorage.write(
        key: _tokenKey, value: result['accessToken'].toString());
    await prefs.setString(_groupIdKey, result['groupId'].toString());
    await prefs.setString(_pairingCodeKey, result['pairingCode'].toString());
    await prefs.setInt(
      _pairingExpiryKey,
      DateTime.tryParse(result['pairingExpiresAt']?.toString() ?? '')
              ?.millisecondsSinceEpoch ??
          0,
    );
    return result;
  }

  Future<Map<String, dynamic>> pairExtension({
    required String pairingCode,
    required String deviceName,
  }) async {
    final prefs = await _prefs();
    final deviceId = prefs.getString(_deviceIdKey) ?? '';
    final result = await _request('POST', '/pair', body: {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'pairingCode': pairingCode.trim(),
    });
    await prefs.setString(_groupIdKey, result['groupId']?.toString() ?? '');
    return result;
  }

  Future<TabLockSnapshot> sync() async {
    final prefs = await _prefs();
    final deviceId = prefs.getString(_deviceIdKey) ?? '';
    final result = await _request(
        'GET', '/sync?deviceId=${Uri.encodeQueryComponent(deviceId)}');
    return TabLockSnapshot.fromJson(result);
  }

  String normalizeDomain(String value) {
    var domain = value.trim().toLowerCase();
    domain = domain.replaceFirst(RegExp(r'^[a-z]+://'), '');
    domain = domain.split('/').first.split(':').first;
    domain = domain
        .replaceFirst(RegExp(r'^www\.'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    if (!RegExp(r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$')
            .hasMatch(domain) ||
        domain.length > 253) {
      throw const FormatException('Enter a valid domain such as example.com.');
    }
    return domain;
  }

  String _verifier({
    required String domain,
    required String salt,
    required String secret,
  }) =>
      sha256.convert(utf8.encode('$salt|$domain|$secret')).toString();

  Future<TabLockSnapshot> upsertPolicy({
    required String domain,
    required String mode,
    String? secret,
    String failurePage = 'blocked',
    bool relockOnRefresh = true,
  }) async {
    final normalized = normalizeDomain(domain);
    if (mode != 'block' && mode != 'lock')
      throw const FormatException('Policy mode must be block or lock.');
    String? salt;
    String? verifier;
    if (mode == 'lock') {
      if (secret == null || secret.length < 4)
        throw const FormatException(
            'A 4+ character password, PIN, or passphrase is required.');
      salt = _randomSalt();
      verifier = _verifier(domain: normalized, salt: salt, secret: secret);
    }
    final prefs = await _prefs();
    final result = await _request('POST', '/policy/upsert', body: {
      'deviceId': prefs.getString(_deviceIdKey) ?? '',
      'domain': normalized,
      'mode': mode,
      'unlockSalt': salt,
      'unlockVerifier': verifier,
      'failurePage': failurePage,
      'relockOnRefresh': relockOnRefresh,
    });
    return TabLockSnapshot.fromJson(result);
  }

  Future<TabLockSnapshot> deletePolicy(String domain) async {
    final prefs = await _prefs();
    final result = await _request('POST', '/policy/delete', body: {
      'deviceId': prefs.getString(_deviceIdKey) ?? '',
      'domain': normalizeDomain(domain),
    });
    return TabLockSnapshot.fromJson(result);
  }

  Future<TabLockSnapshot> revokeDevice(String targetDeviceId) async {
    final prefs = await _prefs();
    final result = await _request('POST', '/device/revoke', body: {
      'deviceId': prefs.getString(_deviceIdKey) ?? '',
      'targetDeviceId': targetDeviceId,
    });
    return TabLockSnapshot.fromJson(result);
  }

  Future<Map<String, dynamic>> localState() async {
    final prefs = await _prefs();
    return {
      'deviceId': prefs.getString(_deviceIdKey) ?? '',
      'deviceName': prefs.getString(_deviceNameKey) ?? 'JARVIS Android',
      'groupId': prefs.getString(_groupIdKey) ?? '',
      'pairingCode': prefs.getString(_pairingCodeKey) ?? '',
      'pairingExpiresAt': prefs.getInt(_pairingExpiryKey) ?? 0,
      'registered': (await _readToken(prefs)).isNotEmpty,
    };
  }
}
