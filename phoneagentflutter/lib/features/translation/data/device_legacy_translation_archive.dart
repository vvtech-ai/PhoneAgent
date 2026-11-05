import 'package:flutter/services.dart';
import '../domain/translation_archive.dart';
import 'legacy_translation_archive_codec.dart';

class DeviceLegacyTranslationArchive {
  const DeviceLegacyTranslationArchive();
  static const channel = MethodChannel(
    'phone_agent/legacy_translation_archive',
  );

  Future<List<TranslationArchiveEntry>?> read(String account) async {
    final data = await channel.invokeMapMethod<String, Object?>('read', {
      'accountId': account,
    });
    if (data == null) return null; // Not the production Android package.
    if (data['version'] != 1 || data['accountId'] != account) {
      throw const FormatException('Invalid legacy archive envelope');
    }
    if (data['pending'] == null && data.containsKey('pending')) return null;
    final raw = data['pending'];
    if (raw is! String) {
      throw const FormatException('Invalid legacy archive payload');
    }
    return LegacyTranslationArchiveCodec.decode(account, raw);
  }
}
