import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../app/translation_session_factory.dart';
import '../../../dialer/data/app_dial_recent_source.dart';
import '../../../dialer/data/preview_app_call_record_store.dart';
import '../../../dialer/domain/dial_recent_source.dart';
import '../../../dialer/presentation/controller/dial_recent_controller.dart';
import '../../data/preview_translation_session.dart';
import 'translation_finished_recorder.dart';
import 'translation_session_controller.dart';
import '../../domain/translation_dial_request.dart';
import '../../../settings/domain/original_audio_settings.dart';
import '../../data/preview_translation_archive.dart';
import 'translation_archive_controller.dart';

/// Replaces external ports only; the finish/save/reload path is shared.
class TranslationCompletionPreviewController extends ChangeNotifier {
  TranslationCompletionPreviewController() {
    recorder = TranslationFinishedRecorder(
      accountId: PreviewTranslationSession.request.userId,
      repository: store.repository,
      isCurrent: () => !_closed,
    );
    archive = TranslationArchiveController(
      accountId: 'synthetic',
      store: archivePorts,
      gateway: archivePorts,
      isCurrent: () => !_closed,
    );
    factory = TranslationSessionFactory(recorder, archive: archive);
    recent = DialRecentController(
      const _NoSystemRecords(),
      AppDialRecentSource(store.repository),
    );
    _remove = [
      archive.addListener((_) => _notify(), fireImmediately: false),
      recorder.addListener((value) {
        saveState = value;
        _notify();
      }),
      recent.addListener((value) {
        recentState = value;
        _notify();
      }),
    ];
    unawaited(recent.load());
  }
  final store = PreviewAppCallRecordStore();
  final archivePorts = PreviewTranslationArchive();
  late final TranslationArchiveController archive;
  late final TranslationFinishedRecorder recorder;
  late final TranslationSessionFactory factory;
  late final DialRecentController recent;
  late final List<VoidCallback> _remove;
  TranslationRecordSaveState saveState = const TranslationRecordSaveState();
  DialRecentState recentState = const DialRecentState();
  bool _closed = false;
  PreviewTranslationSession? activeFixture;
  TranslationDialRequest? lastDial;
  OriginalAudioSettings originalAudio = const OriginalAudioSettings();

  TranslationSessionController createDial(TranslationDialRequest dial) {
    lastDial = dial;
    final fixture = activeFixture = PreviewTranslationSession();
    return factory.create(
      backend: fixture,
      mediaFactory: fixture.media,
      loadLanguages: fixture.languages,
      request: dial.toCreateRequest(
        userId: recorder.accountId,
        originalAudio: originalAudio,
      ),
      targetName: dial.displayName,
      countryIso: dial.countryIso,
    );
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  void failWrite(bool value) {
    store.failWrite = value;
    _notify();
  }

  TranslationSessionController create(PreviewTranslationSession fixture) =>
      factory.create(
        backend: fixture,
        mediaFactory: fixture.media,
        loadLanguages: fixture.languages,
        request: PreviewTranslationSession.request,
        targetName: '合成翻译联系人',
        countryIso: 'US',
      );

  @override
  void dispose() {
    _closed = true;
    for (final remove in _remove) {
      remove();
    }
    recorder.dispose();
    archive.dispose();
    recent.dispose();
    store.repository.close();
    super.dispose();
  }
}

class _NoSystemRecords implements DialRecentCallSource {
  const _NoSystemRecords();
  @override
  Future<DialRecentSnapshot> load() async =>
      const DialRecentSnapshot(DialRecentAccess.unsupported);
}
