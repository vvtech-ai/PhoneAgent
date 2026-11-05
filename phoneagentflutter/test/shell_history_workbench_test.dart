import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/recording_providers.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import '../tool/previews/auth_scenario.dart';
import 'package:phone_agent/features/translation_history/data/preview_recording_audio.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_history_preview.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  test('shell recording scenarios are explicit and reject unknown values', () {
    for (final scenario in RecordingPreviewScenario.values) {
      expect(shellRecordingScenario(scenario.name), scenario);
    }
    expect(() => shellRecordingScenario('production'), throwsArgumentError);
    expect(() => shellRecordingScenario(''), throwsArgumentError);
  });

  test('history fixture is ID-bound and rejects unknown records', () async {
    const repository = ShellHistoryPreview();
    final first = await repository.load('tr1');
    final second = await repository.load('tr2');
    expect(first.callId, 'tr1');
    expect(second.callId, 'tr2');
    expect(first.connectedAt, '2026-09-16T11:00:00');
    expect(first.endedAt, '2026-09-16T11:00:12');
    expect(second.connectedAt, '2026-09-16T10:30:00');
    expect(second.endedAt, '2026-09-16T10:30:12');
    expect(
      first.transcripts.first.sourceText,
      isNot(second.transcripts.first.sourceText),
    );
    await expectLater(repository.load('unknown'), throwsStateError);
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('task history and recording continuous flow at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MigrationWorkbench(
          scenes: [workbenchScenes.singleWhere((scene) => scene.id == 'app')],
        ),
      );
      Future<void> tap(Finder target, {bool settle = true}) async {
        await tester.pump(const Duration(milliseconds: 300));
        await tester.ensureVisible(target);
        await tester.tap(target);
        if (settle) {
          await tester.pumpUntilUiSettled();
        } else {
          // Saving remains busy until the visible destination dialog resolves.
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(tester.takeException(), isNull);
      }

      Future<void> key(String id, {bool settle = true}) =>
          tap(find.byKey(ValueKey(id)), settle: settle);
      await key('scene-app');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhoneAgentApp)),
      );
      final auth = container.read(sessionStoreProvider) as AuthScenario;
      expect(container.read(appConfigProvider).apiBaseUri, isNull);
      await key('tab-2');
      await key('call:translation');
      expect(find.text('请确认今天的营业时间。'), findsOneWidget);
      expect(find.text('今天营业到晚上八点。'), findsOneWidget);
      final provider = recordingAudioControllerProvider('tr1');
      final first = container.read(provider.notifier);
      expect(first.state.phase, RecordingAudioPhase.ready);
      await key('recording-primary');
      expect(first.state.phase, RecordingAudioPhase.playing);
      await tester.pump(const Duration(milliseconds: 750));
      expect(first.state.positionMillis, greaterThan(0));
      await key('recording-primary');
      expect(first.state.phase, RecordingAudioPhase.paused);
      await key('recording-save', settle: false);
      expect(find.text('MOCK · 保存录音'), findsOneWidget);
      await tap(find.text('取消保存'));
      expect(first.state.message, isEmpty);
      await key('recording-save', settle: false);
      await tap(find.text('模拟保存'));
      expect(first.state.message, contains('保存'));
      await key('recording-primary');
      await key('close-translation');
      expect(first.mounted, isFalse, reason: '离页自动停止合成计时');
      await key('call:translation-hotel');
      expect(find.text('下午三点可以办理入住。'), findsOneWidget);
      expect(find.text('9月16日 10:30'), findsOneWidget);
      expect(find.text('9月16日 11:00'), findsNothing);
      expect(find.text('今天营业到晚上八点。'), findsNothing);
      await key('close-translation');
      await key('call:translation');
      expect(container.read(provider.notifier), isNot(same(first)));
      expect(container.read(provider).positionMillis, 0);
      expect(container.read(provider).message, isEmpty);
      await key('workbench-home');
      expect(auth.sends, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    });
  }
}
