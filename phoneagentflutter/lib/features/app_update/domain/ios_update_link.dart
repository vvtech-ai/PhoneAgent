/// Distribution links are unrelated to Android APK downloads.
abstract final class IosUpdateLink {
  static const fallback = 'https://apps.apple.com/app/id6813455647';

  static String resolve(String value) {
    final link = value.trim().isEmpty ? fallback : value.trim();
    final uri = Uri.tryParse(link);
    if (uri == null ||
        !const {'https', 'itms-apps'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.path.toLowerCase().endsWith('.apk')) {
      throw const FormatException('Invalid iOS update link');
    }
    return link;
  }
}
