import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// SSE client for group live presence (`GET /api/v1/groups/{id}/live`).
class GroupLiveSseClient {
  GroupLiveSseClient({
    required this.baseUrl,
    required this.accessToken,
    required this.groupId,
  });

  final String baseUrl;
  final String accessToken;
  final String groupId;

  Stream<Map<String, dynamic>> connect() async* {
    final origin = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$origin/api/v1/groups/${Uri.encodeComponent(groupId)}/live');
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.headers['Accept'] = 'text/event-stream';
    final client = http.Client();
    // finally also runs when the listener cancels, so the connection never leaks.
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw StateError('SSE failed: ${response.statusCode}');
      }
      String? eventName;
      final buffer = StringBuffer();
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final lines = buffer.toString().split('\n');
        buffer.clear();
        // The last piece is an incomplete line ('' when the chunk ended on '\n').
        // Treating that '' as a blank line would drop the event split across chunks.
        buffer.write(lines.removeLast());
        for (final raw in lines) {
          final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
          if (line.startsWith('event:')) {
            eventName = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final data = line.substring(5).trim();
            final decoded = data.isEmpty ? null : _tryDecodeObject(data);
            if (eventName != null && decoded != null) {
              yield {'event': eventName, 'data': decoded};
            }
          } else if (line.isEmpty) {
            eventName = null;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic>? _tryDecodeObject(String data) {
    try {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

/// Member presence derived from SSE + local clock (A.9).
enum LiveMemberStatus { vaping, active, idle }

LiveMemberStatus deriveLiveStatus({
  DateTime? vapingSince,
  DateTime? lastPuffAt,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now().toUtc();
  if (vapingSince != null && clock.difference(vapingSince).inSeconds < 15) {
    return LiveMemberStatus.vaping;
  }
  if (lastPuffAt != null && clock.difference(lastPuffAt).inMinutes < 5) {
    return LiveMemberStatus.active;
  }
  return LiveMemberStatus.idle;
}
