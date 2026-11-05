import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [const Size(320, 568), const Size(390, 900)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$platform $size scale=$scale notice follows input and IME',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            tester.view.padding = const FakeViewPadding(bottom: 34);
            addTearDown(tester.view.reset);
            var voiceMode = true;
            late StateSetter change;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SafeArea(
                    child: Column(
                      children: [
                        const Expanded(child: SizedBox()),
                        StatefulBuilder(
                          builder: (context, setState) {
                            change = setState;
                            return ConversationComposer(
                              voiceMode: voiceMode,
                              canSend: true,
                              modelName: '测试模型',
                              onToggle: () =>
                                  setState(() => voiceMode = !voiceMode),
                              onSend: (_) => false,
                              onNotice: (_) {},
                              onModels: () {},
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );

            void checkNotice(double boundary) {
              final notice = find.text('内容由AI生成');
              expect(notice, findsOneWidget);
              final rect = tester.getRect(notice);
              expect(rect.center.dx, closeTo(size.width / 2, 0.1));
              expect(rect.bottom, lessThanOrEqualTo(boundary));
              expect(tester.takeException(), isNull);
              if (!voiceMode) {
                final input = tester.getRect(
                  find.byKey(const ValueKey('conversation-input')),
                );
                expect(rect.top, greaterThan(input.bottom));
              }
            }

            checkNotice(size.height - 34);
            change(() => voiceMode = false);
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('conversation-input')),
              '保留草稿',
            );
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            tester.view.padding = const FakeViewPadding();
            await tester.pumpAndSettle();
            checkNotice(size.height - 280);
            change(() => voiceMode = true);
            await tester.pumpAndSettle();
            checkNotice(size.height - 280);
            tester.view.viewInsets = const FakeViewPadding();
            tester.view.padding = const FakeViewPadding(bottom: 34);
            change(() => voiceMode = false);
            await tester.pumpAndSettle();
            checkNotice(size.height - 34);
            expect(find.text('保留草稿'), findsOneWidget);
          },
        );
      }
    }
  }
}
