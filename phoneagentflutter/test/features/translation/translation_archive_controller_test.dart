import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_archive_controller.dart';
import 'package:phone_agent/features/translation/data/preview_translation_archive.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_completion_preview_controller.dart';
import 'package:phone_agent/features/translation/data/preview_translation_session.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';

TranslationArchiveEntry sample({
  String id = 'call-1',
  int? connected = 1000,
  int? ended,
  List<TranslationTranscript> text = const [],
}) => TranslationArchiveEntry(
  accountId: 'synthetic',
  clientCallId: id,
  targetName: '合成目标',
  phone: '+12025550123',
  myLanguage: 'zh',
  peerLanguage: 'en',
  locator: const TranslationArchiveLocator('US', 'session', 'synthetic'),
  connectedAt: connected,
  lastObservedAt: 1500,
  endedAt: ended,
  stage: ended == null
      ? TranslationArchiveStage.active
      : TranslationArchiveStage.draining,
  transcripts: text,
);
TranslationTranscript line(String id, String text, {bool finalValue = false}) =>
    TranslationTranscript(
      id: id,
      leg: 'user',
      source: '源文',
      translated: text,
      isFinal: finalValue,
    );

class FailingStore extends PreviewTranslationArchive {
  bool failRead = false, failWrite = false;
  Completer<void>? remote;
  @override
  Future<List<TranslationArchiveEntry>> load() async {
    if (failRead) throw StateError('synthetic');
    return super.load();
  }

  @override
  Future<void> save(List<TranslationArchiveEntry> entries) async {
    if (failWrite) throw StateError('synthetic');
    return super.save(entries);
  }

  @override
  Future<String> archive(TranslationArchiveEntry entry) async {
    if (remote != null) await remote!.future;
    return super.archive(entry);
  }
}

void main() {
  late FailingStore ports;
  late TranslationArchiveController controller;
  var current = true;
  final completed = <String>[];
  setUp(() {
    ports = FailingStore();
    current = true;
    completed.clear();
    controller = TranslationArchiveController(
      accountId: 'synthetic',
      store: ports,
      gateway: ports,
      isCurrent: () => current,
      drainDuration: Duration.zero,
      onCompleted: (id, _) => completed.add(id),
    );
  });
  tearDown(() => controller.dispose());
  Future<void> drain() async {
    await Future<void>.delayed(Duration.zero);
    await controller.idle;
  }

  test(
    'late terminal observation never retries a sealed failed archive',
    () async {
      ports.failArchive = true;
      controller.observe(sample(ended: 2000, text: [line('a', 'final')]));
      await drain();
      expect(ports.attempts, 1);
      controller.observe(sample(ended: 2000, text: [line('a', 'late')]));
      await drain();
      expect(ports.attempts, 1);
      ports.failArchive = false;
      await controller.retry();
      expect(ports.attempts, 2);
    },
  );
  test(
    'connected terminal persists then archives once with frozen subtitles',
    () async {
      controller.observe(sample(text: [line('a', 'partial')]));
      await controller.idle;
      controller.observe(sample(ended: 2000, text: [line('a', 'complete')]));
      controller.observe(
        sample(ended: 2000, text: [line('a', 'last'), line('new', 'discard')]),
      );
      await drain();
      expect(
        ports.archived.values.single.transcripts.single.translated,
        'last',
      );
      expect(ports.archived.values.single.transcripts.single.isFinal, true);
      expect(await ports.load(), isEmpty);
      controller.observe(sample(ended: 2000));
      await drain();
      await controller.retry();
      expect(ports.attempts, 1);
      expect(completed, ['call-1']);
    },
  );
  test(
    'preconnect recovery discards; connected recovery uses last observation',
    () async {
      await ports.save([sample(id: 'pre', connected: null), sample()]);
      await controller.recover();
      expect(ports.archived.keys, ['call-1']);
      expect(ports.archived.values.single.endedAt, 1500);
      expect(await ports.load(), isEmpty);
    },
  );
  test(
    'failed PUT retains durable identity and retries only archive',
    () async {
      ports.failArchive = true;
      controller.observe(sample(ended: 2000));
      await drain();
      expect(controller.snapshot.failed, true);
      expect((await ports.load()).single.stage, TranslationArchiveStage.ready);
      ports.failArchive = false;
      await controller.retry();
      expect(ports.attempts, 2);
      expect(ports.archived.length, 1);
      expect(controller.snapshot.failed, false);
    },
  );
  test(
    'read failure never overwrites journal; retry recovers persisted active entry',
    () async {
      await ports.save([sample()]);
      final raw = ports.journal;
      ports.failRead = true;
      await controller.recover();
      expect(ports.journal, raw);
      expect(ports.attempts, 0);
      ports.failRead = false;
      await controller.retry();
      expect(ports.archived.length, 1);
    },
  );
  test(
    'write failure never sends unpersisted archive and explicit retry succeeds',
    () async {
      ports.failWrite = true;
      controller.observe(sample(ended: 2000));
      await drain();
      expect(ports.attempts, 0);
      expect(controller.snapshot.failed, true);
      ports.failWrite = false;
      await controller.retry();
      expect(ports.archived.length, 1);
    },
  );
  test('retry during active call does not seal it', () async {
    controller.observe(sample());
    await controller.idle;
    await controller.recover();
    await controller.retry();
    expect(ports.attempts, 0);
    expect((await ports.load()).single.endedAt, isNull);
  });
  test(
    'live terminal survives initial read failure and retries after recovery',
    () async {
      ports.failRead = true;
      controller.observe(sample());
      controller.observe(sample(ended: 2000));
      controller.observe(
        sample(
          id: 'pre',
          connected: null,
        ).copy(stage: TranslationArchiveStage.draining),
      );
      await drain();
      expect(ports.attempts, 0);
      expect(controller.snapshot.failed, true);
      ports.failRead = false;
      await controller.retry();
      expect(ports.archived.keys, ['call-1']);
      expect(ports.archived.values.single.endedAt, 2000);
      expect(await ports.load(), isEmpty);
      expect(controller.snapshot.failed, false);
    },
  );
  test(
    'terminal archive is captured before Finished callback disposes session',
    () async {
      final fixture = PreviewTranslationSession();
      late final TranslationSessionController call;
      call = TranslationSessionController(
        backend: fixture,
        mediaFactory: fixture.media,
        loadLanguages: fixture.languages,
        request: PreviewTranslationSession.request,
        onArchive: controller.observe,
        onFinished: (_) => call.dispose(),
      );
      final started = call.start();
      await Future<void>.delayed(Duration.zero);
      fixture.ready();
      await started;
      fixture.connected();
      fixture.disconnect();
      await drain();
      expect(ports.archived.length, 1);
      expect(call.mounted, false);
    },
  );
  test(
    'old account late response cannot remove journal or refresh new account',
    () async {
      ports.remote = Completer<void>();
      controller.observe(sample(ended: 2000));
      await Future<void>.delayed(Duration.zero);
      current = false;
      ports.remote!.complete();
      await controller.idle;
      expect((await ports.load()).length, 1);
      expect(completed, isEmpty);
    },
  );
  test(
    'shared call factory returns before archive completes and never replays call',
    () async {
      final flow = TranslationCompletionPreviewController();
      final fixture = PreviewTranslationSession();
      flow.archivePorts.failArchive = true;
      final call = flow.create(fixture);
      final start = call.start();
      await Future<void>.delayed(Duration.zero);
      fixture.ready();
      await start;
      fixture.connected();
      fixture.transcript();
      await call.hangup();
      call.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 550));
      await flow.archive.idle;
      expect(flow.archive.snapshot.failed, true);
      flow.archivePorts.failArchive = false;
      await flow.archive.retry();
      expect(flow.archivePorts.archived.length, 1);
      expect(
        flow.archivePorts.archived.values.single.locator!.sessionId,
        'mock-session',
      );
      expect(fixture.creates, 1);
      expect(fixture.merchants, 1);
      expect(fixture.hangups, 1);
      flow.dispose();
    },
  );
}
