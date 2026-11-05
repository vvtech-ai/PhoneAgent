import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_text_dock.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(390, 844),
      const Size(430, 932),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final device in [(1.0, 0.0), (3.0, 34.0)]) {
          testWidgets(
            '$platform $size scale=$scale device=$device notice follows input and IME',
            (tester) async {
              tester.view.devicePixelRatio = device.$1;
              tester.view.physicalSize = size * device.$1;
              tester.view.padding = FakeViewPadding(
                bottom: device.$2 * device.$1,
              );
              tester.view.viewPadding = FakeViewPadding(
                bottom: device.$2 * device.$1,
              );
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

              void checkNotice(double boundary, [double? gap]) {
                final adjusted =
                    platform == TargetPlatform.iOS && device.$2 > 0;
                final bottomGap = gap ?? (adjusted ? 10.0 : 20.0);
                final notice = find.text('内容由AI生成');
                expect(notice, findsOneWidget);
                final rect = tester.getRect(notice);
                expect(rect.center.dx, closeTo(size.width / 2, 0.1));
                expect(rect.bottom, closeTo(boundary - bottomGap, .1));
                final text = tester.widget<Text>(notice);
                expect(text.style!.fontSize, 11);
                expect(text.style!.color, const Color(0xFFB0B4C3));
                expect(text.style!.fontWeight, FontWeight.w400);
                expect(
                  tester
                      .renderObject<RenderParagraph>(notice)
                      .textScaler
                      .scale(11),
                  11,
                );
                expect(tester.takeException(), isNull);
                if (!voiceMode) {
                  final input = tester.getRect(
                    find.byType(ConversationTextDock),
                  );
                  expect(
                    rect.top - input.bottom,
                    closeTo(adjusted ? 18 : 8, .1),
                  );
                }
              }

              checkNotice(size.height - device.$2);
              change(() => voiceMode = false);
              await tester.pumpAndSettle();
              await tester.enterText(
                find.byKey(const ValueKey('conversation-input')),
                '保留草稿',
              );
              tester.view.viewInsets = FakeViewPadding(bottom: 280 * device.$1);
              tester.view.padding = const FakeViewPadding();
              await tester.pumpAndSettle();
              checkNotice(size.height - 280, 8);
              change(() => voiceMode = true);
              await tester.pumpAndSettle();
              checkNotice(size.height - 280, 8);
              tester.view.viewInsets = const FakeViewPadding();
              tester.view.padding = FakeViewPadding(
                bottom: device.$2 * device.$1,
              );
              change(() => voiceMode = false);
              await tester.pumpAndSettle();
              checkNotice(size.height - device.$2);
              expect(find.text('保留草稿'), findsOneWidget);
            },
          );
        }
      }
    }
  }
}
