import 'dart:io';

/// Server base URL (origin only, no `/api/v1` suffix).
String defaultBaseUrl() {
  const fromEnv = String.fromEnvironment('VAPEN_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  return 'http://10.0.2.2:8080';
}

String normalizeBaseUrl(String url) {
  var trimmed = url.trim();
  while (trimmed.length > 1 && trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

bool isHttpsRequired(bool isRelease) => isRelease;

bool isPrivateOrLocalHost(String host) {
  final lower = host.toLowerCase();
  if (lower == 'localhost' || lower == '10.0.2.2' || lower == '127.0.0.1') {
    return true;
  }
  final ip = InternetAddress.tryParse(host);
  if (ip == null) return false;
  if (ip.isLoopback) return true;
  if (ip.type != InternetAddressType.IPv4) return false;
  final b = ip.rawAddress;
  if (b[0] == 10) return true;
  if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
  if (b[0] == 192 && b[1] == 168) return true;
  return false;
}

bool isAllowedBaseUrl(String url, {required bool isRelease}) {
  final normalized = normalizeBaseUrl(url);
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  if (uri.scheme == 'https') return true;
  if (uri.scheme != 'http') return false;
  if (isPrivateOrLocalHost(uri.host)) return true;
  return !isRelease;
}
