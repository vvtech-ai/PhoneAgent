import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/home/presentation/controller/home_controller.dart';
import 'package:phone_agent/features/home/presentation/pages/home_page.dart';
import 'package:phone_agent/features/shell/presentation/widgets/floating_navigation.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform home retains model/card actions at 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var models = 0;
      var entries = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: HomePage(
              state: const HomeState(),
              modelName: '很长的通话模型名称用于布局检查',
              onModels: () => models++,
              onEntry: (_) => entries++,
              onRefresh: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PhoneAgent'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('homeVoiceModelChip')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('homeVoiceModelChip')));
      expect(models, 1);
      await tester.ensureVisible(
        find.byKey(const ValueKey('skill-restaurant_booking')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('skill-restaurant_booking')));
      expect(entries, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$platform raised dial button entire visible area is clickable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var dials = 0;
        final tabs = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: FloatingNavigation(
                  selected: 0,
                  onSelected: tabs.add,
                  onDial: () => dials++,
                ),
              ),
            ),
          ),
        );
        final rect = tester.getRect(find.byKey(const ValueKey('assistantFab')));
        await tester.tapAt(Offset(rect.center.dx, rect.top + 3));
        expect(dials, 1);
        await tester.tap(find.byKey(const ValueKey('tab-3')));
        expect(tabs, [3]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
