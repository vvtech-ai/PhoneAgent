import 'dart:convert';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/translation_history/data/api_translation_history_repository.dart';
import 'package:phone_agent/features/translation_history/domain/translation_history.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/recording_audio_card.dart';

Map<String, Object?> fixture() => {
  'callId': 'tr1',
  'route': 'WORLD_CALL',
  'targetName': '合成对象',
  'phoneNumber': '10000',
  'myLanguage': 'zh',
  'peerLanguage': 'en',
  'connectedAt': '2026-09-16T08:00:00Z',
  'endedAt': '2026-09-16T08:02:00Z',
  'durationMillis': 120000,
  'transcripts': [
    {
      'segmentId': 'a',
      'sourceLeg': 'remote',
      'sourceLanguage': 'en',
      'sourceText': 'Hello',
      'translatedLanguage': 'zh',
      'translatedText': '你好',
      'final': false,
    },
    {
      'segmentId': 'b',
      'sourceLeg': 'user',
      'sourceLanguage': 'zh',
      'sourceText': '可以',
      'translatedLanguage': 'en',
      'translatedText': 'Yes',
      'final': true,
    },
  ],
};
void main() {
  test(
    'metadata diagnostics distinguish absent and rejected without payloads',
    () {
      final events = <DiagnosticEvent>[];
      ApiTranslationHistoryRepository.decode(
        fixture(),
        'tr1',
        diagnostics: events.add,
      );
      final invalid = fixture()
        ..['recording'] = {
          'source': 'WORLD_CALL',
          'recordingAccessGrant': 'synthetic-private-grant',
        };
      ApiTranslationHistoryRepository.decode(
        invalid,
        'tr1',
        diagnostics: events.add,
      );
      expect(events.map((e) => e.result), [
        DiagnosticResult.received,
        DiagnosticResult.failed,
      ]);
      expect(
        jsonEncode(events.map((e) => e.toJson()).toList()),
        isNot(contains('synthetic-private-grant')),
      );
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'large history keeps failed recording separate on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var closed = 0, reloads = 0, audioRetries = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: SafeArea(
                child: TranslationHistoryPage(
                  state: const TranslationHistoryState(
                    failed: true,
                    content: TranslationHistoryContent(
                      '合成对象名称很长但关闭仍可操作',
                      '+1 555 0100',
                      '2026年10月6日 18:30',
                      '02:00',
                      [
                        TranslationRow(false, '你好', 'Hello'),
                        TranslationRow(true, '可以', 'Yes'),
                      ],
                      true,
                    ),
                  ),
                  onClose: () => closed++,
                  onRetry: () => reloads++,
                  recording: RecordingAudioCard(
                    state: const RecordingAudioState(
                      phase: RecordingAudioPhase.failed,
                    ),
                    onPrimary: () => audioRetries++,
                    onSave: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('你好'), findsOneWidget);
        expect(find.text('Hello'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('recording-primary')),
          160,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('recording-primary')));
        expect(audioRetries, 1);
        await tester.tap(find.byKey(const ValueKey('retry-translation')));
        expect(reloads, 1);
        await tester.tap(find.byKey(const ValueKey('close-translation')));
        expect(closed, 1);
      },
    );
  }
  TranslationHistory decode(Map<String, Object?> value) =>
      ApiTranslationHistoryRepository.decode(value, 'tr1');
  test('valid non-final subtitles retained and own language primary', () {
    final detail = decode(fixture());
    final view = TranslationHistoryContent.from(detail);
    expect(detail.transcripts.first.isFinal, isFalse);
    expect(view.rows, hasLength(2));
    expect(view.rows.first.primary, '你好');
    expect(view.rows.first.secondary, 'Hello');
    expect(view.rows.first.mine, isFalse);
    expect(view.rows.last.mine, isTrue);
    expect(view.duration, '02:00');
  });
  test('legacy domestic route allowed without enabling new domestic calls', () {
    expect(
      decode(fixture()..['route'] = 'DOMESTIC_ANDROID').route,
      TranslationRoute.domesticSip,
    );
    expect(
      () => decode(fixture()..['route'] = 'DOMESTIC_SIP'),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(
      () => decode(fixture()..['callId'] = 'another'),
      throwsA(ApiFailure.invalidResponse),
    );
  });
  test('invalid recording ignored but transcript retained', () {
    for (final value in [
      {
        'source': 'WORLD_CALL',
        'clusterId': 'cluster',
        'callSessionId': 'session',
      },
      {'source': 'PHONE_AGENT', 'sizeBytes': -1},
      {'source': 'OTHER'},
    ]) {
      final detail = decode(fixture()..['recording'] = value);
      expect(detail.recording, isNull);
      expect(detail.transcripts, hasLength(2));
    }
  });
  test(
    'world-call recording needs full locator; grant never enters presentation',
    () {
      final detail = decode(
        fixture()
          ..['recording'] = {
            'source': 'WORLD_CALL',
            'clusterId': 'cluster',
            'callSessionId': 'session',
            'recordingAccessGrant': 'synthetic-grant',
          },
      );
      expect(detail.recording!.clusterId, 'cluster');
      expect(TranslationHistoryContent.from(detail).recordingAvailable, isTrue);
      expect(
        TranslationHistoryContent.from(detail).toString(),
        isNot(contains('synthetic-grant')),
      );
    },
  );
  test('same language family duplicate translation suppressed', () {
    final dto = fixture();
    dto['transcripts'] = [
      {
        'segmentId': 'a',
        'sourceLeg': 'local',
        'sourceLanguage': 'en-US',
        'sourceText': 'Hello',
        'translatedLanguage': 'en_GB',
        'translatedText': 'Hallo',
        'final': false,
      },
    ];
    expect(
      TranslationHistoryContent.from(decode(dto)).rows.single.secondary,
      '',
    );
  });
  test('load error retry and dispose ignore late response', () async {
    final repo = _Repository(decode(fixture()))..fail = true;
    final controller = TranslationHistoryController(repo, 'tr1');
    await controller.load();
    expect(controller.state.failed, isTrue);
    repo.fail = false;
    await controller.load();
    expect(controller.state.content!.rows, hasLength(2));
    repo.gate = Completer<TranslationHistory>();
    final pending = controller.load();
    controller.dispose();
    repo.gate!.complete(repo.value);
    await pending;
  });
  testWidgets('history readable at small portrait with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.3),
            size: Size(320, 568),
          ),
          child: Scaffold(
            body: TranslationHistoryPage(
              state: TranslationHistoryState(
                content: TranslationHistoryContent.from(decode(fixture())),
              ),
              onClose: () {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('你好'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}

class _Repository implements TranslationHistoryRepository {
  _Repository(this.value);
  final TranslationHistory value;
  bool fail = false;
  Completer<TranslationHistory>? gate;
  @override
  Future<TranslationHistory> load(String callId) async {
    if (fail) throw ApiFailure.network;
    return gate == null ? value : await gate!.future;
  }
}
