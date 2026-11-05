import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_task_submit_button.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_voice_finalizing_dots.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final voiceControl in [true, false]) {
      testWidgets(
        '$platform voice=$voiceControl accepted stop uses waiting dots',
        (tester) async {
          var stopCalls = 0;
          var sendCalls = 0;

          Future<void> show({required bool stopping, required bool hasStop}) =>
              tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: Scaffold(
                    body: Center(
                      child: NativeTaskSubmitButton(
                        voiceControl: voiceControl,
                        canSend: !hasStop,
                        onSend: () => sendCalls++,
                        onStop: hasStop ? () => stopCalls++ : null,
                        stopping: stopping,
                      ),
                    ),
                  ),
                ),
              );

          final stop = find.byKey(const ValueKey('stop-current-processing'));
          void expectOriginalColor() {
            final button = tester.widget<IconButton>(stop);
            expect(
              button.style!.backgroundColor!.resolve(const {}),
              voiceControl ? Colors.transparent : const Color(0xFFE7EAEE),
            );
            final decoration =
                tester
                        .widget<DecoratedBox>(
                          find
                              .descendant(
                                of: find.byType(NativeTaskSubmitButton),
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration;
            expect(
              decoration.gradient?.colors,
              voiceControl
                  ? const [Color(0xFF2196F3), Color(0xFF1976D2)]
                  : null,
            );
          }

          await show(stopping: false, hasStop: true);
          expectOriginalColor();
          expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
          expect(find.byType(NativeVoiceFinalizingDots), findsNothing);
          await tester.tap(stop);
          expect(stopCalls, 1);

          await show(stopping: true, hasStop: true);
          expectOriginalColor();
          expect(stop, findsOneWidget);
          expect(find.byIcon(Icons.stop_rounded), findsNothing);
          expect(find.byType(NativeVoiceFinalizingDots), findsOneWidget);
          expect(tester.widget<IconButton>(stop).onPressed, isNull);
          await tester.tap(stop);
          expect(stopCalls, 1);

          await show(stopping: false, hasStop: false);
          expect(find.byType(NativeVoiceFinalizingDots), findsNothing);
          expect(find.byIcon(Icons.send_rounded), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('send-text')));
          expect(sendCalls, 1);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
