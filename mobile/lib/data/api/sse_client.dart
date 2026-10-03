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
    final uri = Uri.parse('$origin/api/v1/groups/$groupId/live');
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.headers['Accept'] = 'text/event-stream';
    final client = http.Client();
    final response = await client.send(request);
    if (response.statusCode != 200) {
      client.close();
      throw StateError('SSE failed: ${response.statusCode}');
    }
    String? eventName;
    final buffer = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final lines = buffer.toString().split('\n');
      buffer.clear();
      if (lines.isNotEmpty && !chunk.endsWith('\n')) {
        buffer.write(lines.removeLast());
      }
      for (final line in lines) {
        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (eventName != null && data.isNotEmpty) {
            yield {'event': eventName, 'data': jsonDecode(data) as Map<String, dynamic>};
          }
        } else if (line.isEmpty) {
          eventName = null;
        }
      }
    }
    client.close();
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
