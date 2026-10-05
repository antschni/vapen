import 'package:intl/intl.dart';

/// German relative time similar to the web app (e.g. „vor 3 Minuten“).
String formatRelativeTimeDe(DateTime dateTime, {DateTime? now}) {
  final end = (now ?? DateTime.now()).toUtc();
  final start = dateTime.toUtc();
  final diff = end.difference(start);
  if (diff.isNegative || diff.inSeconds < 10) return 'gerade eben';
  if (diff.inSeconds < 45) return 'vor wenigen Sekunden';
  if (diff.inMinutes < 1) return 'vor ${diff.inSeconds} Sekunden';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return m == 1 ? 'vor 1 Minute' : 'vor $m Minuten';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return h == 1 ? 'vor 1 Stunde' : 'vor $h Stunden';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return d == 1 ? 'vor 1 Tag' : 'vor $d Tagen';
  }
  return DateFormat('d. MMM yyyy, HH:mm', 'de_DE').format(start.toLocal());
}
