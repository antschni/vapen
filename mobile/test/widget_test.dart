import 'package:flutter_test/flutter_test.dart';
import 'package:vapen/core/duration_format.dart';

void main() {
  test('formatDurationMs uses German decimal comma', () {
    expect(formatDurationMs(2300), '2,3 s');
  });
}
