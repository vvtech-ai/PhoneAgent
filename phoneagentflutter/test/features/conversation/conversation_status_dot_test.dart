import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_progress.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_wave.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform status wave keeps task stages independent at $scale',
        (tester) async {
          var stage = ConversationProgress.result;
          late StateSetter change;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    change = setState;
                    return MediaQuery(
                      data: MediaQueryData(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: ConversationHeaderDetails(
                        status: '合成状态',
                        progress: stage,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          final wave = find.byType(NativeConversationWave);
          expect(tester.getSize(wave), const Size(26, 27));
          expect(
            tester.widget<Text>(find.text('合成状态')).style!.color,
            const Color(0xFF0D84FC),
          );
          expect(
            find.descendant(of: wave, matching: find.byType(ExcludeSemantics)),
            findsOneWidget,
          );
          for (final next in ConversationProgress.values) {
            change(() => stage = next);
            await tester.pump();
            expect(
              tester.widget<NativeConversationWave>(wave).mode,
              NativeConversationWaveMode.standby,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
