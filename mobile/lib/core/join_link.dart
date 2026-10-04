import 'config.dart';

/// Invite URL from any self-hosted Vapen instance: `https://<host>/join/<code>`.
class JoinInviteLink {
  const JoinInviteLink({required this.origin, required this.code});

  final String origin;
  final String code;

  static JoinInviteLink? tryParse(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) return null;
    final segments = uri.pathSegments;
    final joinIndex = segments.indexOf('join');
    if (joinIndex < 0 || joinIndex + 1 >= segments.length) return null;
    final code = segments[joinIndex + 1];
    if (code.length != 10) return null;

    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    final portSuffix = uri.hasPort && uri.port != defaultPort ? ':${uri.port}' : '';
    final origin = normalizeBaseUrl('${uri.scheme}://${uri.host}$portSuffix');
    return JoinInviteLink(origin: origin, code: code);
  }

  bool isAllowedOrigin({required bool isRelease}) =>
      isAllowedBaseUrl(origin, isRelease: isRelease);
}
