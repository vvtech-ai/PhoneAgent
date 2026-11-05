import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_page_background.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('home text fits width=$width scale=$scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: NativePageBackground(
                    child: HomePage(
                      state: const HomeState(),
                      modelName: '合成模型',
                      onModels: () {},
                      onEntry: (_) {},
                      onRefresh: () async {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('skill-meeting_invite'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final description = find.text('批量通知参会、确认回执');
        final style = tester.widget<Text>(description).style!;
        final painter = TextPainter(
          text: TextSpan(text: '批量通知参会、确认回执', style: style),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: (width - 32 - 12) / 2 - 34);
        expect(
          tester.getSize(description).height,
          greaterThanOrEqualTo(painter.height - .01),
        );
        painter.dispose();
        expect(
          tester.getRect(description).bottom,
          lessThanOrEqualTo(tester.getRect(card).bottom - 16),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
