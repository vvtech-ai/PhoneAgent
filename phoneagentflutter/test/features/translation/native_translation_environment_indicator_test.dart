import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_environment.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_call_page.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_call_controls.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_environment_indicator.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform native environment geometry and honest states large=$large',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          if (large) {
            tester.platformDispatcher.textScaleFactorTestValue = 2;
          }
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final semantics = tester.ensureSemantics();
          try {
            for (final status in TranslationEnvironmentState.values) {
              final environment = TranslationCallEnvironment(
                network: status,
                sip: status,
                model: status,
                riskMessage: '合成环境风险说明',
              );
              for (final transcripts in [
                <TranslationTranscript>[],
                const [
                  TranslationTranscript(
                    id: 's',
                    leg: 'merchant',
                    source: 'Hello',
                    translated: '合成字幕',
                  ),
                ],
              ]) {
                final state = TranslationCallView(
                  phase: TranslationPhase.translating,
                  environment: environment,
                  transcripts: transcripts,
                  dialPad: large,
                );
                var hangups = 0;
                await tester.pumpWidget(
                  MaterialApp(
                    home: TranslationCallPage(
                      state: state,
                      target: '合成翻译对象',
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
                await tester.pumpAndSettle();
                if (transcripts.isEmpty &&
                    find.text('合成环境风险说明').evaluate().isEmpty) {
                  await tester.scrollUntilVisible(
                    find.text('合成环境风险说明'),
                    80,
                    scrollable: find.byType(Scrollable).first,
                  );
                  await tester.pumpAndSettle();
                }
                final indicator = tester.widget<Wrap>(
                  find.descendant(
                    of: find.byType(TranslationEnvironmentIndicator),
                    matching: find.byType(Wrap),
                  ),
                );
                expect(indicator.spacing, 8);
                for (final label in ['网络', 'SIP', '模型']) {
                  final node = tester.getSemantics(
                    find.bySemanticsLabel('$label ${status.label}'),
                  );
                  expect(node.hasFlag(SemanticsFlag.isButton), isFalse);
                  final bar = find.byKey(ValueKey('translation-health-$label'));
                  expect(tester.getSize(bar), const Size(16, 4));
                  expect(
                    (tester.widget<Container>(bar).decoration! as BoxDecoration)
                        .color,
                    translationEnvironmentColor(status),
                  );
                  final text = tester.widget<Text>(find.text(label));
                  expect(text.style!.fontSize, 10);
                }
                expect(
                  find.text('合成环境风险说明'),
                  transcripts.isEmpty ? findsOneWidget : findsNothing,
                );
                await tester.tap(find.bySemanticsLabel('挂断'));
                expect(hangups, 1);
                expect(tester.takeException(), isNull);
              }
            }
          } finally {
            await tester.pumpWidget(const SizedBox());
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
