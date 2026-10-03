import 'package:flutter_test/flutter_test.dart';
import 'package:vapen/data/api/sse_client.dart';

void main() {
  test('deriveLiveStatus vaping when vaping_since is recent', () {
    final now = DateTime.utc(2026, 10, 3, 12, 0, 0);
    final status = deriveLiveStatus(
      vapingSince: now.subtract(const Duration(seconds: 5)),
      lastPuffAt: now.subtract(const Duration(minutes: 1)),
      now: now,
    );
    expect(status, LiveMemberStatus.vaping);
  });
}
