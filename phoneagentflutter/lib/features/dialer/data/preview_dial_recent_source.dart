import '../domain/dial_recent_call.dart';
import '../domain/dial_recent_source.dart';

/// Explicit preview only: reserved fictional numbers, no account or I/O.
class PreviewDialRecentSource implements DialRecentCallSource {
  const PreviewDialRecentSource(this.source);
  final DialRecentSource source;
  @override
  Future<DialRecentSnapshot> load() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return DialRecentSnapshot(DialRecentAccess.ready, [
      if (source == DialRecentSource.system)
        DialRecentCall(
          id: 'preview-system',
          phone: '+12025550101',
          name: '普通通话 张三（合成）',
          startedAtMillis: now - 60000,
          source: source,
        )
      else ...[
        DialRecentCall(
          id: 'preview-translation',
          phone: '2025550103',
          name: '实时翻译 Alice（合成）',
          startedAtMillis: now - 120000,
          source: source,
          kind: DialRecentKind.translation,
          countryIso: 'US',
          callerLanguage: 'ja',
          peerLanguage: 'fr',
        ),
        DialRecentCall(
          id: 'preview-unknown',
          phone: '-1',
          name: '未知号码（合成，不可回填）',
          startedAtMillis: now - 86400000,
          source: source,
          kind: DialRecentKind.translation,
        ),
      ],
    ]);
  }
}
