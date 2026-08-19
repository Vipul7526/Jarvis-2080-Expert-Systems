import 'dart:convert';

import 'package:http/http.dart' as http;

class MeshRelayMessage {
  final int id;
  final String envelope;

  const MeshRelayMessage({required this.id, required this.envelope});

  factory MeshRelayMessage.fromJson(Map<String, dynamic> json) =>
      MeshRelayMessage(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        envelope: '${json['envelope'] ?? ''}',
      );
}

class MeshRelayService {
  static const String baseUrl =
      'https://jarvisrecov-3mlp5xq9.manus.space/api/mesh';
  final http.Client _client = http.Client();

  Future<void> register(
      {required String deviceId,
      required String peerId,
      required String token}) async {
    await _request('POST', '/register', token: null, body: {
      'deviceId': deviceId,
      'peerId': peerId,
      'token': token,
    });
  }

  Future<void> send(
      {required String fromDeviceId,
      required String toDeviceId,
      required String token,
      required Map<String, dynamic> envelope}) async {
    await _request('POST', '/send', token: token, body: {
      'fromDeviceId': fromDeviceId,
      'toDeviceId': toDeviceId,
      'peerId': toDeviceId,
      'envelope': envelope,
    });
  }

  Future<List<MeshRelayMessage>> poll(
      {required String deviceId,
      required String peerId,
      required String token}) async {
    final response = await _request(
      'GET',
      '/poll?${Uri(queryParameters: {
            'deviceId': deviceId,
            'peerId': peerId
          }).query}',
      token: token,
    );
    final raw = response['messages'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) =>
            MeshRelayMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> acknowledge(
      {required String deviceId,
      required String peerId,
      required String token,
      required List<int> messageIds}) async {
    await _request('POST', '/ack', token: token, body: {
      'deviceId': deviceId,
      'peerId': peerId,
      'messageIds': messageIds,
    });
  }

  Future<void> revoke(
      {required String deviceId,
      required String peerId,
      required String token}) async {
    await _request('POST', '/revoke', token: token, body: {
      'deviceId': deviceId,
      'peerId': peerId,
    });
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {required String? token, Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty)
      headers['Authorization'] = 'Bearer $token';
    late http.Response response;
    if (method == 'GET') {
      response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    } else {
      response = await _client
          .post(uri,
              headers: headers,
              body: jsonEncode(body ?? const <String, dynamic>{}))
          .timeout(const Duration(seconds: 20));
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
          'Mesh relay returned invalid JSON (${response.statusCode}).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map
          ? '${decoded['error'] ?? 'HTTP ${response.statusCode}'}'
          : 'HTTP ${response.statusCode}';
      throw Exception(error);
    }
    if (decoded is! Map) throw Exception('Unexpected mesh relay response.');
    return Map<String, dynamic>.from(decoded);
  }

  void dispose() => _client.close();
}
