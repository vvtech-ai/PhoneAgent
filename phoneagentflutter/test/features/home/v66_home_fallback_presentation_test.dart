import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform configuration failure retains cards without extra banner',
      (tester) async {
        tester.view.physicalSize = const Size(393, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var refreshed = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: HomePage(
                state: const HomeState(notice: '首页配置加载失败，请重试'),
                modelName: '测试模型',
                onModels: () {},
                onEntry: (_) {},
                onRefresh: () async {
                  refreshed++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('首页配置加载失败'), findsNothing);
        expect(find.text('重新加载首页'), findsNothing);
        expect(
          find.byKey(const ValueKey('skill-restaurant_booking')),
          findsOneWidget,
        );
        final indicator = tester.state<RefreshIndicatorState>(
          find.byType(RefreshIndicator),
        );
        indicator.show();
        await tester.pumpAndSettle();
        expect(refreshed, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
