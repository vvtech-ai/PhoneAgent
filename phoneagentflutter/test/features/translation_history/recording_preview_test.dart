import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/pages/developer_preview_page.dart';
import 'package:phone_agent/features/translation_history/data/preview_recording_audio.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/recording_preview_page.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/widgets/recording_audio_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('recording actions stay accessible at 2x on $platform', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var plays = 0, saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordingAudioCard(
                state: const RecordingAudioState(
                  phase: RecordingAudioPhase.ready,
                  durationMillis: 120000,
                ),
                onPrimary: () => plays++,
                onSave: () => saves++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(plays, 0);
      expect(find.text('02:00'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('recording-primary')))
            .shortestSide,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byTooltip('播放录音'));
      await tester.tap(find.byTooltip('保存录音'));
      expect(plays, 1);
      expect(saves, 1);
    });
  }
  Future<void> open(
    WidgetTester tester,
    RecordingPreviewScenario scenario,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: RecordingPreviewPage(scenario: scenario)),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  final primary = find.byKey(const ValueKey('recording-primary'));
  final save = find.byKey(const ValueKey('recording-save'));
  testWidgets('save asset is bundled with explicit SVG stroke', (tester) async {
    final svg = await rootBundle.loadString(
      'assets/images/translation/translation_0.svg',
    );
    expect(svg, contains('stroke="#ffffff"'));
    expect(svg, contains('fill="none"'));
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'shared history renders card and subtitles at $width without seek',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 720);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester, RecordingPreviewScenario.normal);
        expect(find.text('通话录音'), findsOneWidget);
        expect(find.text('00:12'), findsNWidgets(2));
        expect(find.byType(Slider), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(primary);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byTooltip('暂停录音'), findsOneWidget);
        await tester.tap(primary);
        await tester.pumpAndSettle();
        expect(find.byTooltip('播放录音'), findsOneWidget);
        expect(find.textContaining('营业时间'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'save dialog cancel preserves page; confirmation only simulates success',
    (tester) async {
      await open(tester, RecordingPreviewScenario.normal);
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('MOCK · 保存录音'), findsOneWidget);
      await tester.tap(find.text('取消保存'));
      await tester.pumpAndSettle();
      expect(find.text('录音已保存'), findsNothing);
      expect(find.text('通话录音'), findsOneWidget);
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('模拟保存'));
      await tester.pumpAndSettle();
      expect(find.text('录音已保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scenario in [
    RecordingPreviewScenario.loadFailure,
    RecordingPreviewScenario.playFailure,
    RecordingPreviewScenario.saveFailure,
  ]) {
    testWidgets('${scenario.name} is retryable and never removes subtitles', (
      tester,
    ) async {
      await open(tester, scenario);
      if (scenario == RecordingPreviewScenario.playFailure) {
        await tester.tap(primary);
        await tester.pumpAndSettle();
      }
      if (scenario == RecordingPreviewScenario.saveFailure) {
        await tester.tap(save);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('模拟保存'));
        await tester.pumpAndSettle();
      }
      expect(find.text('音频加载失败'), findsWidgets);
      expect(find.textContaining('营业时间'), findsOneWidget);
      await tester.tap(primary);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.byTooltip('播放录音'), findsOneWidget);
      await tester.tap(primary);
      await tester.pump(const Duration(seconds: 13));
      await tester.pump();
      expect(find.byTooltip('播放录音'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'processing disables buttons and then becomes ready without autoplay',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RecordingPreviewPage(
            scenario: RecordingPreviewScenario.processing,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('录音加载中'), findsOneWidget);
      expect(tester.widget<IconButton>(primary).onPressed, isNull);
      expect(tester.widget<IconButton>(save).onPressed, isNull);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byTooltip('播放录音'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'developer entry reaches scenarios, detail close pops to scenario list',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DeveloperPreviewPage()));
      final entry = find.text('翻译历史录音演练');
      // Entries below the viewport may not be built by the lazy list yet.
      await tester.scrollUntilVisible(entry, 240);
      await tester.pumpAndSettle();
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('MOCK · 历史录音场景'), findsOneWidget);
      await tester.tap(find.text('播放、暂停与保存取消'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(primary);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('close-translation')));
      await tester.pumpAndSettle();
      expect(find.text('MOCK · 历史录音场景'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
