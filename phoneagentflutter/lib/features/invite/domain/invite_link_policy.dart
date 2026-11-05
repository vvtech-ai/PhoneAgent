class InviteLinkPolicy {
  const InviteLinkPolicy({
    required this.host,
    required this.path,
    required this.scheme,
    this.universalHost = '',
    this.compatibleWebHosts = const {},
  });
  final String host, path, scheme, universalHost;
  final Set<String> compatibleWebHosts;
  static bool validCode(String code) =>
      code.runes.length == 4 &&
      !code.runes.any(
        (r) =>
            r <= 32 ||
            (r >= 127 && r <= 159) ||
            RegExp(r'\s', unicode: true).hasMatch(String.fromCharCode(r)),
      );

  String? parse(String value) {
    try {
      final uri = Uri.parse(value);
      if (uri.userInfo.isNotEmpty || uri.hasFragment) return null;
      final https =
          uri.scheme == 'https' &&
          (!uri.hasPort || uri.port == 443) &&
          ((host.isNotEmpty &&
                  (uri.host == host || compatibleWebHosts.contains(uri.host)) &&
                  uri.path == path) ||
              (universalHost.isNotEmpty &&
                  uri.host == universalHost &&
                  uri.path == '/phoneagent/ios/invite/'));
      final custom =
          scheme.isNotEmpty &&
          uri.scheme == scheme &&
          uri.host == 'invite' &&
          uri.path == '/' &&
          !uri.hasPort;
      if (!https && !custom) return null;
      final codes = <dynamic>{
        ...?uri.queryParametersAll['code'],
        ...?uri.queryParametersAll['invite'],
      };
      return codes.length == 1 && validCode(codes.single) ? codes.single : null;
    } on FormatException {
      return null;
    }
  }
}
