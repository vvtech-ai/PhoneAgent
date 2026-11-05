import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/task_voice_settings_providers.dart';
import 'package:phone_agent/app/task_voice_preview_providers.dart';
import 'package:phone_agent/features/settings/domain/task_voice.dart';
import 'package:phone_agent/features/settings/presentation/controller/task_voice_preview_controller.dart';
import 'package:phone_agent/features/settings/presentation/widgets/task_voice_settings_section.dart';

class Store implements TaskVoiceStore {
  TaskVoice value = TaskVoice.maia;
  bool failWrite = false;
  @override
  Future<TaskVoice> read() async => value;
  @override
  Future<void> write(TaskVoice voice) async {
    if (failWrite) throw StateError("write failed");
    value = voice;
  }
}

class TrackedPreview extends TaskVoicePreviewController {
  TrackedPreview()
    : super(
        (voice) =>
            (current, changed) => throw StateError('offline'),
      );
  int stops = 0;
  @override
  Future<void> stop() {
    stops++;
    return super.stop();
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform task voice saves at 320px scale $scale with safe failure',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final store = Store();
          final previews = <TrackedPreview>[];
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                loginEpochProvider.overrideWithValue(7),
                taskVoiceStoreProvider.overrideWithValue(store),
                taskVoicePreviewProvider.overrideWith((ref, owner) {
                  final preview = TrackedPreview();
                  previews.add(preview);
                  return preview;
                }),
              ],
              child: MaterialApp(
                theme: ThemeData(platform: platform),
                home: const Scaffold(body: TaskVoiceSettingsSection()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('task-voice-entry')));
          await tester.pumpAndSettle();
          expect(find.text('任务AI音色'), findsOneWidget);
          expect(find.text('温柔女声'), findsWidgets);
          await tester.tap(find.text('Andre'));
          await tester.pumpAndSettle();
          expect(store.value, TaskVoice.andre);
          expect(find.text('已选择 Andre'), findsOneWidget);
          expect(find.text('当前'), findsOneWidget);
          await tester.tap(find.byTooltip('试听Andre'));
          await tester.pumpAndSettle();
          expect(find.text('音色试听失败，请重试'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final beforePause = previews.last.stops;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pumpAndSettle();
          expect(previews.last.stops, greaterThan(beforePause));
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
          expect(find.text('任务AI音色'), findsNothing);
          expect(find.text('Andre'), findsOneWidget);
          expect(previews.first.stops, greaterThan(beforePause + 1));
          await tester.tap(find.byKey(const Key('task-voice-entry')));
          await tester.pumpAndSettle();
          store.failWrite = true;
          await tester.tap(find.text('Maia'));
          await tester.pumpAndSettle();
          expect(store.value, TaskVoice.andre);
          expect(find.text('任务音色保存失败，请重试'), findsWidgets);
          expect(find.text('已选择 Maia'), findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.text('任务AI音色'), findsNothing);
          await tester.tap(find.byKey(const Key('task-voice-entry')));
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(find.text('任务AI音色'), findsNothing);
          expect(previews.every((preview) => preview.stops > 0), isTrue);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
