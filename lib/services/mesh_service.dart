import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mesh_relay_service.dart';

class MeshDevice {
  final String peerId;
  final String name;
  final String host;
  final int port;
  final String transport;

  const MeshDevice({
    required this.peerId,
    required this.name,
    required this.host,
    required this.port,
    required this.transport,
  });

  factory MeshDevice.fromMap(Map<dynamic, dynamic> map) => MeshDevice(
        peerId: '${map['peerId'] ?? ''}',
        name: '${map['name'] ?? map['deviceName'] ?? 'JARVIS device'}',
        host: '${map['host'] ?? ''}',
        port: int.tryParse('${map['port'] ?? 0}') ?? 0,
        transport: '${map['transport'] ?? 'lan'}',
      );
}

class MeshEvent {
  final String type;
  final Map<String, dynamic> data;

  const MeshEvent(this.type, this.data);

  factory MeshEvent.fromDynamic(dynamic value) {
    final raw =
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    final type = '${raw.remove('type') ?? 'unknown'}';
    return MeshEvent(type, raw);
  }

  String get requestId => '${data['requestId'] ?? ''}';
  String get peerId => '${data['peerId'] ?? ''}';
  String get deviceName => '${data['deviceName'] ?? data['name'] ?? peerId}';

  Map<String, dynamic> get payload {
    final raw = data['payload'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}

class MeshService {
  static Map<String, dynamic> normalizeConnectResult(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) return {'requestId': raw};
    return <String, dynamic>{};
  }

  static const _mesh = MethodChannel('com.ultimate.jarvis/mesh');
  static const _events = EventChannel('com.ultimate.jarvis/mesh_events');
  static const _idKey = 'mesh_device_id';
  static const _nameKey = 'mesh_device_name';
  static const _codeKey = 'device_pair_code';

  final StreamController<MeshEvent> _eventController =
      StreamController<MeshEvent>.broadcast();
  final MeshRelayService _relay = MeshRelayService();
  final Map<String, String> _relaySessions = <String, String>{};
  final Map<String, String> _relayRequests = <String, String>{};
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _relayTimer;
  bool _started = false;

  Stream<MeshEvent> get events => _eventController.stream;

  Future<String> get deviceId async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      id =
          'J${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${Random().nextInt(9999).toRadixString(36)}';
      await prefs.setString(_idKey, id);
    }
    return id;
  }

  Future<String> get deviceName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey) ??
        'JARVIS-${(await deviceId).substring(0, 5)}';
  }

  Future<String> get pairingCode async {
    final prefs = await SharedPreferences.getInstance();
    var code = prefs.getString(_codeKey);
    if (code == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      code = (100000 + Random().nextInt(900000)).toString();
      await prefs.setString(_codeKey, code);
    }
    return code;
  }

  Future<void> start() async {
    if (!_started) {
      _eventSubscription = _events.receiveBroadcastStream().listen(
            _handleNativeEvent,
            onError: (Object error, StackTrace stack) => _eventController.add(
              MeshEvent('transport_error', {'message': error.toString()}),
            ),
          );
      _started = true;
      await _loadRelaySessions();
      _relayTimer =
          Timer.periodic(const Duration(seconds: 4), (_) => _pollRelay());
    }
    await _mesh.invokeMethod<void>('start', {
      'deviceId': await deviceId,
      'deviceName': await deviceName,
      'pairingCode': await pairingCode,
    });
  }

  Future<bool> discover() async {
    await start();
    return await _mesh.invokeMethod<bool>('startDiscovery') ?? false;
  }

  Future<Map<String, dynamic>> connect({
    required MeshDevice device,
    required String pairingCode,
    String? sessionToken,
  }) async {
    await start();
    final raw = await _mesh.invokeMethod<dynamic>('connect', {
      'host': device.host,
      'port': device.port,
      'peerId': device.peerId,
      'pairingCode': pairingCode,
      if (sessionToken != null && sessionToken.isNotEmpty)
        'sessionToken': sessionToken,
    });
    return normalizeConnectResult(raw);
  }

  Future<bool> approvePair({
    required String requestId,
    required bool approved,
    required bool anytime,
  }) async {
    return await _mesh.invokeMethod<bool>('approvePair', {
          'requestId': requestId,
          'approved': approved,
          'anytime': anytime,
        }) ??
        false;
  }

  Future<String> send({
    required String peerId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _mesh.invokeMethod<String>('send', {
            'peerId': peerId,
            'type': type,
            'payload': payload,
          }) ??
          '';
    } on PlatformException catch (error) {
      final token = _relaySessions[peerId];
      if (error.code != 'NOT_CONNECTED' || token == null) rethrow;
      final requestId = 'relay-${DateTime.now().microsecondsSinceEpoch}';
      _relayRequests[requestId] = peerId;
      await _relay.send(
        fromDeviceId: await deviceId,
        toDeviceId: peerId,
        token: token,
        envelope: {'type': type, 'requestId': requestId, 'payload': payload},
      );
      _eventController.add(MeshEvent('relay_sent',
          {'peerId': peerId, 'requestId': requestId, 'transport': 'internet'}));
      return requestId;
    }
  }

  Future<bool> respond({
    required String requestId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _mesh.invokeMethod<bool>('respond', {
            'requestId': requestId,
            'type': type,
            'payload': payload,
          }) ??
          false;
    } on PlatformException catch (error) {
      final peerId = _relayRequests[requestId];
      final token = peerId == null ? null : _relaySessions[peerId];
      if (error.code != 'REQUEST_NOT_FOUND' ||
          peerId == null ||
          token == null) {
        rethrow;
      }
      await _relay.send(
        fromDeviceId: await deviceId,
        toDeviceId: peerId,
        token: token,
        envelope: {'type': type, 'requestId': requestId, 'payload': payload},
      );
      return true;
    }
  }

  Future<List<Map<String, dynamic>>> pairedPeers() async {
    final raw = await _mesh.invokeMethod<List<dynamic>>('getPairedPeers') ??
        <dynamic>[];
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<bool> revoke(String peerId) async =>
      await _mesh.invokeMethod<bool>('revokePeer', {'peerId': peerId}) ?? false;

  Future<void> stop() async {
    await _mesh.invokeMethod<void>('stop');
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _relayTimer?.cancel();
    _relayTimer = null;
    _started = false;
  }

  void dispose() {
    _eventSubscription?.cancel();
    _relayTimer?.cancel();
    _relay.dispose();
    _eventController.close();
  }

  Future<void> _handleNativeEvent(dynamic value) async {
    final event = MeshEvent.fromDynamic(value);
    if ((event.type == 'pair_result' || event.type == 'paired') &&
        event.data['anytime'] == true) {
      final token = '${event.data['sessionToken'] ?? ''}';
      if (event.peerId.isNotEmpty && token.length >= 32) {
        _relaySessions[event.peerId] = token;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mesh_session_${event.peerId}', token);
        try {
          await _relay.register(
              deviceId: await deviceId, peerId: event.peerId, token: token);
          _eventController
              .add(MeshEvent('relay_registered', {'peerId': event.peerId}));
        } catch (error) {
          _eventController.add(MeshEvent('transport_error', {
            'peerId': event.peerId,
            'message': 'Internet relay registration failed: $error'
          }));
        }
      }
    }
    _eventController.add(event);
  }

  Future<void> _loadRelaySessions() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry
        in prefs.getKeys().where((key) => key.startsWith('mesh_session_'))) {
      final peerId = entry.substring('mesh_session_'.length);
      final token = prefs.getString(entry) ?? '';
      if (peerId.isNotEmpty && token.length >= 32) {
        _relaySessions[peerId] = token;
      }
    }
  }

  Future<void> _pollRelay() async {
    if (_relaySessions.isEmpty) return;
    final me = await deviceId;
    for (final entry in Map<String, String>.from(_relaySessions).entries) {
      try {
        final messages = await _relay.poll(
            deviceId: me, peerId: entry.key, token: entry.value);
        for (final message in messages) {
          final decoded = jsonDecode(message.envelope);
          if (decoded is Map) {
            final requestId = '${decoded['requestId'] ?? ''}';
            if (requestId.isNotEmpty) _relayRequests[requestId] = entry.key;
            final data = <String, dynamic>{
              'peerId': entry.key,
              'requestId': requestId,
              'type': '${decoded['type'] ?? 'unknown'}',
              'payload': decoded['payload'] ?? <String, dynamic>{},
              'transport': 'internet',
            };
            _eventController
                .add(MeshEvent(data.remove('type') as String, data));
          }
        }
        await _relay.acknowledge(
            deviceId: me,
            peerId: entry.key,
            token: entry.value,
            messageIds: messages.map((message) => message.id).toList());
      } catch (error) {
        _eventController.add(MeshEvent(
            'relay_error', {'peerId': entry.key, 'message': error.toString()}));
      }
    }
  }
}
