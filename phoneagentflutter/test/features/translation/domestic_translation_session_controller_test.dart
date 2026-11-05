import 'package:phone_agent/features/translation/domain/translation_call_environment.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_points_repository.dart';
import 'package:phone_agent/features/translation/domain/domestic_settlement_notice.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_session_route.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/controller/domestic_translation_session_controller.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_sip_call_coordinator.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_points_owner.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_call_plan.dart';
import 'package:phone_agent/features/translation/domain/translation_call_finished.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'package:phone_agent/features/translation/domain/recording/domestic_recording_attachment.dart';

class FakePoints implements DomesticPointsOwner {
  FakePoints([this.session]);
  @override
  final DomesticPointsSession? session;
  @override
  int get durationMs => 1234;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCoordinator implements DomesticSipCallCoordinator {
  FakeCoordinator(this.phase, this.transcript, this.stopped, this.environment);
  final void Function(TranslationCallEnvironment) environment;
  final void Function(TranslationPhase, String) phase;
  final void Function(TranslationTranscript) transcript;
  final void Function(int) stopped;
  bool closed = false, failSpeaker = false;
  int closes = 0;
  bool muted = false;
  final digits = <String>[];
  @override
  DomesticPointsOwner billing = FakePoints();
  @override
  Future<void> start() async {
    phase(TranslationPhase.connected, '');
    phase(TranslationPhase.translating, '');
  }

  @override
  void setMuted(bool value) {
    muted = value;
  }

  @override
  Future<void> setSpeaker(bool value) async {
    if (failSpeaker) throw const FormatException();
  }

  @override
  Future<void> sendDtmf(String digit) async {
    digits.add(digit);
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    closes++;
    stopped(1234);
    phase(TranslationPhase.ended, '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  DomesticPointsSession charge({
    String state = 'SETTLED',
    int points = 37,
    int duration = 1234,
  }) => DomesticPointsSession(
    id: 'synthetic',
    state: state,
    authorizedThroughMs: 60000,
    authorizationVersion: 1,
    connectedDurationMs: duration,
    chargedPoints: points,
    availableBalance: 963,
    heldBalance: 0,
    stopState: '',
    pricing: const DomesticPointsPricing(
      provider: 'p',
      modelId: 'm',
      firstMinutePoints: 37,
      blockDurationMs: 60000,
      blockPoints: 37,
      priceVersion: 'v',
    ),
  );
  test(
    'only actual positive connected settlement produces a charge notice',
    () {
      expect(domesticSettlementNotice(charge()), '本次扣除 ✦37 积分，剩余 ✦963 积分');
      expect(domesticSettlementNotice(null), isEmpty);
      expect(domesticSettlementNotice(charge(state: 'PREPARED')), isEmpty);
      expect(domesticSettlementNotice(charge(state: 'RELEASED')), isEmpty);
      expect(domesticSettlementNotice(charge(points: 0)), isEmpty);
      expect(domesticSettlementNotice(charge(duration: 0)), isEmpty);
    },
  );
  final plan = TranslationCallPlan.resolve(
    location: TrustedTranslationLocation('CN', 1),
    rawNumber: '13800138000',
    targetCountry: 'CN',
    preferences: const TranslationPreferences(),
    domestic: const DomesticTranslationPreferences(
      domesticAccountId: 'synthetic',
    ),
  );
  late FakeCoordinator coordinator;
  final entries = <TranslationArchiveEntry>[],
      finished = <TranslationCallFinished>[];
  var current = true;
  var timestamp = 10000;
  DomesticTranslationSessionController create({
    Future<DomesticRecordingAttachment?> Function(int)? recording,
    void Function()? onDtmfInput,
  }) => DomesticTranslationSessionController(
    accountId: 'synthetic',
    plan: plan,
    context: const TranslationCallContext(
      clientCallId: 'synthetic-call',
      targetName: '合成',
    ),
    isCurrent: () => current,
    now: () => DateTime.fromMillisecondsSinceEpoch(timestamp),
    onArchive: entries.add,
    onFinished: finished.add,
    finalizeRecording: recording,
    onDtmfInput: onDtmfInput,
    createCoordinator:
        ({
          required onPhase,
          required onTranscript,
          required onMediaStopped,
          required onEnvironment,
        }) => coordinator = FakeCoordinator(
          onPhase,
          onTranscript,
          onMediaStopped,
          onEnvironment,
        ),
  );
  setUp(() {
    current = true;
    timestamp = 10000;
    entries.clear();
    finished.clear();
  });
  testWidgets(
    'domestic DTMF sends without overseas enhanced history or haptics',
    (tester) async {
      var feedback = 0;
      final controller = create(onDtmfInput: () => feedback++);
      await controller.start();
      controller.dialPad();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: TranslationCallControls(
              state: controller.snapshot,
              onMute: () {},
              onSpeaker: () {},
              onPad: () {},
              onDigit: controller.digit,
              onHangup: () {},
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('translation-dtmf-history')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('translation-dtmf-1')));
      await tester.pumpAndSettle();
      expect(coordinator.digits, ['1']);
      expect(feedback, 0);
      await controller.hangup();
      controller.dispose();
    },
  );
  test('unconfirmed settlement reaches view without a charge notice', () async {
    final controller = create();
    await controller.start();
    coordinator.billing = FakePoints(charge(state: 'PREPARED'));
    coordinator.phase(TranslationPhase.failed, 'POINTS_SETTLEMENT_UNCONFIRMED');
    expect(controller.snapshot.phase, TranslationPhase.failed);
    expect(controller.snapshot.error, '通话已结束，但结算结果暂不可用，请稍后查看积分流水');
    expect(controller.snapshot.settlementNotice, isEmpty);
    controller.dispose();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final failed in [false, true]) {
      testWidgets(
        'domestic terminal uses Toast and returns $platform failed=$failed',
        (tester) async {
          addTearDown(dismissNativeNotice);
          late DomesticTranslationSessionController controller;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TranslationSessionRoute(
                          target: '合成联系人',
                          createController: () => controller = create(),
                        ),
                      ),
                    ),
                    child: const Text('开始'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('开始'));
          await tester.pumpAndSettle();
          coordinator.billing = FakePoints(charge());
          if (failed) {
            coordinator.phase(TranslationPhase.failed, 'BUSY');
            coordinator.phase(TranslationPhase.failed, 'BUSY');
          } else {
            await controller.hangup();
            coordinator.phase(TranslationPhase.ended, '');
          }
          await tester.pumpAndSettle();
          expect(find.byType(TranslationSessionRoute), findsNothing);
          expect(find.text('本次通话账单'), findsNothing);
          expect(find.text('开始'), findsOneWidget);
          const chargeText = '本次扣除 ✦37 积分，剩余 ✦963 积分';
          if (failed) {
            expect(find.text('对方正在通话中'), findsOneWidget);
            await tester.pump(const Duration(seconds: 4));
            await tester.pumpAndSettle();
            expect(find.text('对方正在通话中'), findsNothing);
          }
          expect(find.text(chargeText, findRichText: true), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('nativeNoticeSurface')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test(
    'environment updates the shared view and ignores terminal/logout events',
    () async {
      final controller = create();
      await controller.start();
      coordinator.environment(
        const TranslationCallEnvironment(
          version: 1,
          network: TranslationEnvironmentState.available,
          sip: TranslationEnvironmentState.available,
          model: TranslationEnvironmentState.available,
        ),
      );
      expect(
        controller.snapshot.environment.model,
        TranslationEnvironmentState.available,
      );
      coordinator.environment(
        const TranslationCallEnvironment(
          version: 2,
          network: TranslationEnvironmentState.unavailable,
          sip: TranslationEnvironmentState.available,
          model: TranslationEnvironmentState.available,
        ),
      );
      expect(
        controller.snapshot.environment.network,
        TranslationEnvironmentState.unavailable,
      );
      coordinator.transcript(
        const TranslationTranscript(
          id: 'blocked',
          leg: 'local',
          source: '不可用',
          translated: 'blocked',
        ),
      );
      expect(controller.snapshot.transcripts, isEmpty);
      current = false;
      coordinator.environment(const TranslationCallEnvironment(version: 3));
      expect(controller.snapshot.environment.version, 2);
      current = true;
      await controller.hangup();
      coordinator.environment(const TranslationCallEnvironment(version: 4));
      expect(controller.snapshot.environment.version, 2);
      controller.dispose();
    },
  );
  test(
    'final correction survives terminal/dispose, rejects new, expired and logged-out updates',
    () async {
      final controller = create();
      await controller.start();
      void subtitle(String id, String text) => coordinator.transcript(
        TranslationTranscript(
          id: id,
          leg: 'local',
          source: '合成',
          translated: text,
          isFinal: true,
        ),
      );
      subtitle('known', '初稿');
      subtitle('known', '通话中修正');
      expect(controller.snapshot.transcripts.single.translated, '通话中修正');
      await controller.hangup();
      expect(controller.snapshot.elapsedSeconds, 2);
      controller.dispose();
      subtitle('known', '最终补全');
      subtitle('new', '不得新增');
      expect(entries.last.transcripts.single.translated, '最终补全');
      current = false;
      subtitle('known', '过期账号');
      expect(entries.last.transcripts.single.translated, '最终补全');
      current = true;
      timestamp += 501;
      subtitle('known', '超时');
      expect(entries.last.transcripts.single.translated, '最终补全');
      expect(coordinator.closes, 1);
    },
  );
  testWidgets(
    'domestic missing settlement returns without a fabricated points display',
    (tester) async {
      late DomesticTranslationSessionController controller;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TranslationSessionRoute(
                      target: '合成联系人',
                      createController: () => controller = create(),
                    ),
                  ),
                ),
                child: const Text('开始合成流程'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('开始合成流程'));
      await tester.pumpAndSettle();
      expect(find.text('实时翻译 · 已接通'), findsOneWidget);
      expect(controller.snapshot.phase, TranslationPhase.translating);
      await tester.tap(find.bySemanticsLabel('挂断'));
      await tester.pumpAndSettle();
      expect(find.text('本次通话账单'), findsNothing);
      expect(find.textContaining('本次扣除', findRichText: true), findsNothing);
      expect(find.byType(TranslationSessionRoute), findsNothing);
      expect(finished.length, 1);
      expect(coordinator.closes, 1);
    },
  );
  test(
    'shared controls require explicit DTMF, preserve state after failed speaker',
    () async {
      final controller = create();
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.snapshot.speaker, true);
      await controller.mute();
      expect(controller.snapshot.muted, true);
      coordinator.failSpeaker = true;
      await controller.speaker();
      expect(controller.snapshot.speaker, true);
      await controller.digit('1');
      expect(coordinator.digits, isEmpty);
      controller.dialPad();
      await controller.digit('1');
      expect(coordinator.digits, ['1']);
      await controller.hangup();
      expect(controller.snapshot.terminal, true);
      expect(finished.single.endedAtMillis, 11234);
      expect(coordinator.closes, 1);
      expect(entries.last.route, TranslationArchiveRoute.domesticSip);
    },
  );
  test(
    'physical duration freezes and late encoding persists after route disposal',
    () async {
      final pending = Completer<DomesticRecordingAttachment?>();
      int? duration;
      final controller = create(
        recording: (value) {
          duration = value;
          return pending.future;
        },
      );
      await controller.start();
      await controller.hangup();
      expect(duration, 1234);
      expect(entries.last.recordingPending, true);
      controller.dispose();
      pending.complete(
        DomesticRecordingAttachment(
          durationMillis: 1234,
          checksumSha256: List.filled(64, 'a').join(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(entries.last.recordingPending, false);
      expect(entries.last.recording, isNotNull);
      expect(entries.last.endedAt, 11234);
      expect(finished.length, 1);
    },
  );
  test(
    'logout rejects late recording writes and unavailable recording does not keep phone alive',
    () async {
      final pending = Completer<DomesticRecordingAttachment?>();
      final controller = create(recording: (_) => pending.future);
      await controller.start();
      await controller.hangup();
      final count = entries.length;
      current = false;
      pending.completeError(
        const FormatException('synthetic encoding failure'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(entries.length, count);
      expect(controller.recordingWarning, '本次通话录音不可用');
      controller.dispose();
    },
  );
}
