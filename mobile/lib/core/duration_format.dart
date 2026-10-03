import 'package:intl/intl.dart';

/// German duration formatting, e.g. "2,3 s", "1 Min. 12 s".
String formatDurationMs(int ms) {
  if (ms < 1000) return '$ms ms';
  final seconds = ms / 1000;
  if (seconds < 60) {
    final formatted = NumberFormat('#,##0.#', 'de_DE').format(seconds);
    return '$formatted s';
  }
  final minutes = ms ~/ 60000;
  final restSec = (ms % 60000) / 1000;
  if (restSec < 0.5) return '$minutes Min.';
  final secFormatted = NumberFormat('#,##0', 'de_DE').format(restSec.round());
  return '$minutes Min. $secFormatted s';
}
