import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_progress.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets('$platform header without stage bar large=$large', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var closed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 400),
                textScaler: TextScaler.linear(large ? 2 : 1),
              ),
              child: Scaffold(
                body: ConversationHeader(
                  status: '合成待确认状态',
                  onClose: () => closed = true,
                ),
              ),
            ),
          ),
        );
        for (final stage in ConversationProgress.values) {
          expect(find.text(stage.label), findsNothing);
        }
        expect(find.text('合成待确认状态'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('close-conversation')));
        expect(closed, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
