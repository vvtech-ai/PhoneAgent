import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';
import '../../../tool/previews/migration_workbench.dart';
import '../../../tool/previews/workbench_catalog.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';

void main() {
  tearDown(dismissNativeNotice);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('call identity and hangup remain usable at 2x on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const state = TranslationCallView(
        phase: TranslationPhase.translating,
        elapsedSeconds: 65,
        dialPad: true,
        transcripts: [
          TranslationTranscript(
            id: 'one',
            leg: 'merchant',
            source: 'Hello',
            translated: '您好',
          ),
        ],
      );
      var hangups = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: TranslationCallPage(
            state: state,
            target: '+1 555 0100',
            controls: TranslationCallControls(
              state: state,
              onMute: () {},
              onSpeaker: () {},
              onPad: () {},
              onDigit: (_) {},
              onHangup: () => hangups++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('01:05'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('挂断'));
      expect(hangups, 1);
      var cancellations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: TranslationCallPage(
            state: const TranslationCallView(),
            target: '+1 555 0100',
            controls: TranslationCallControls(
              state: const TranslationCallView(),
              onMute: () {},
              onSpeaker: () {},
              onPad: () {},
              onDigit: (_) {},
              onHangup: () => cancellations++,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.bySemanticsLabel('挂断'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('挂断'));
      expect(cancellations, 1);
    });
  }
  Future<void> open(WidgetTester tester, {String scenario = 'normal'}) async {
    await tester.pumpWidget(
      MigrationWorkbench(
        scenes: [
          workbenchScenes.singleWhere((s) => s.id == 'translation-call'),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('scene-translation-call')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('进入翻译通话演练（MOCK）'));
    await tester.pumpAndSettle();
    expect(find.text('MOCK · 不使用输入号码、不发起通话'), findsOneWidget);
    final title = const {
      'normal': '正常通话与双语转写',
      'preflight': '环境检测失败',
      'hangup': '挂断失败与显式重试',
    }[scenario]!;
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      'translation call $width phases transcripts keypad and hangup',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester);
        expect(find.text('正在检测通话环境'), findsOneWidget);
        // Workbench owns an outer navigator; exercise the call route's
        // own back handling rather than leaving the preview directory.
        await Navigator.of(
          tester.element(find.byType(TranslationCallPage)),
        ).maybePop();
        await tester.pump();
        expect(find.text('正在检测通话环境'), findsOneWidget);
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.text('模拟下一阶段'));
          await tester.pump();
        }
        expect(find.text('实时翻译 · 已接通'), findsOneWidget);
        await tester.tap(find.text('添加合成双语'));
        await tester.pump();
        expect(find.text('我明白了。'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('静音'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('扬声器'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('拨号盘'));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('translation-dtmf-1')));
        await tester.tap(find.byKey(const Key('translation-dtmf-1')));
        await tester.pump();
        expect(find.text('MOCK DTMF：1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.bySemanticsLabel('挂断'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('挂断'));
        await tester.pumpAndSettle();
        expect(find.text('进入翻译通话演练（MOCK）'), findsOneWidget);
      },
    );
  }
  testWidgets('hangup failure stays then explicit retry returns', (
    tester,
  ) async {
    await open(tester, scenario: 'hangup');
    await tester.tap(find.text('模拟下一阶段'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('挂断'));
    await tester.pumpAndSettle();
    const failure = 'MOCK · 挂断失败，请确认状态后再次点击';
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsOneWidget);
    expect(find.text(failure), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nativeNoticeSurface')), findsNothing);
    expect(find.textContaining(failure), findsNothing);
    expect(find.bySemanticsLabel('挂断'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('挂断'));
    await tester.pumpAndSettle();
    expect(find.text('进入翻译通话演练（MOCK）'), findsOneWidget);
  });
  testWidgets(
    'preflight failure auto returns without showing domestic settlement',
    (tester) async {
      await open(tester, scenario: 'preflight');
      await tester.tap(find.text('模拟下一阶段'));
      await tester.pumpAndSettle();
      expect(find.text('进入翻译通话演练（MOCK）'), findsOneWidget);
      expect(find.text('通话结算'), findsNothing);
    },
  );
}
