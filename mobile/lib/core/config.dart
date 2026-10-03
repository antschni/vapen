/// Server base URL (origin only, no `/api/v1` suffix).
String defaultBaseUrl() {
  const fromEnv = String.fromEnvironment('VAPEN_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  return 'http://10.0.2.2:8080';
}

bool isHttpsRequired(bool isRelease) => isRelease;

bool isAllowedBaseUrl(String url, {required bool isRelease}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  if (isRelease) return uri.scheme == 'https';
  if (uri.scheme == 'https') return true;
  if (uri.scheme != 'http') return false;
  const allowedHosts = {'10.0.2.2', 'localhost', '127.0.0.1'};
  return allowedHosts.contains(uri.host);
}
