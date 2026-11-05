import '../domain/translation_archive.dart';
import 'translation_archive_codec.dart';

/// Synthetic external ports only; shared codec, coordinator and page are real.
class PreviewTranslationArchive
    implements TranslationArchiveStore, TranslationArchiveGateway {
  String? journal;
  bool failArchive = false;
  int attempts = 0;
  final archived = <String, TranslationArchiveEntry>{};
  @override
  Future<List<TranslationArchiveEntry>> load() async =>
      TranslationArchiveCodec.decode('preview', 'synthetic', journal);
  @override
  Future<void> save(List<TranslationArchiveEntry> entries) async {
    journal = TranslationArchiveCodec.encode('preview', 'synthetic', entries);
  }

  @override
  Future<String> archive(TranslationArchiveEntry entry) async {
    attempts++;
    if (failArchive) throw StateError('Synthetic archive failure');
    archived[entry.clientCallId] = entry;
    return 'synthetic-${entry.clientCallId}';
  }
}
