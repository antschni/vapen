import 'package:intl/intl.dart';

/// German duration formatting, e.g. "2,3 s", "1 Min. 12 s".
String formatDurationMs(int ms) {
  if (ms < 1000) return '$ms ms';
  // Below 59.95 s the one-decimal format cannot round up to "60 s".
  if (ms < 59950) {
    final formatted = NumberFormat('#,##0.#', 'de_DE').format(ms / 1000);
    return '$formatted s';
  }
  final totalSeconds = (ms / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final restSec = totalSeconds % 60;
  if (restSec == 0) return '$minutes Min.';
  return '$minutes Min. $restSec s';
}
