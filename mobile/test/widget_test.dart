import 'package:flutter_test/flutter_test.dart';
import 'package:vapen/core/duration_format.dart';

void main() {
  test('formatDurationMs uses German decimal comma', () {
    expect(formatDurationMs(2300), '2,3 s');
  });

  test('formatDurationMs never shows 60 seconds', () {
    expect(formatDurationMs(59950), '1 Min.');
    expect(formatDurationMs(119600), '2 Min.');
    expect(formatDurationMs(72000), '1 Min. 12 s');
  });
}
