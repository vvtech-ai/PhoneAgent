import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/call_models/domain/call_models.dart';
import 'package:phone_agent/features/call_models/presentation/controller/call_model_controller.dart';
import 'package:phone_agent/features/call_models/presentation/pages/call_models_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets('$platform quick model wraps content large=$large', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = large
            ? const Size(320, 568)
            : const Size(393, 820);
        addTearDown(tester.view.reset);
        var closes = 0, selections = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    key: const ValueKey('sheet'),
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 500,
                    ),
                    child: CallModelsPage(
                      sheet: true,
                      state: CallModelState(
                        catalog: CallModelCatalog('model-0', [
                          for (var i = 0; i < 3; i++)
                            CallModel(
                              id: 'model-$i',
                              name: '模型 $i',
                              description: '模型说明',
                              available: true,
                              active: i == 0,
                            ),
                        ]),
                      ),
                      onBack: () => closes++,
                      onRetry: () {},
                      onSelect: (_) => selections++,
                      onVoices: (_) {},
                      onRefreshQuality: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final sheet = tester.getRect(find.byKey(const ValueKey('sheet')));
        expect(sheet.height, lessThanOrEqualTo(500));
        expect(
          sheet.bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height),
        );
        if (!large) {
          expect(
            sheet.height,
            lessThan(420),
            reason: 'content must not fill 68% of a tall screen',
          );
          expect(
            tester.getTopLeft(find.text('选择 AI 通话模型')).dy - sheet.top,
            closeTo(24, .1),
          );
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('model-model-0'))).dy -
                sheet.top,
            closeTo(64, .1),
          );
        }
        for (var i = 0; i < 3; i++) {
          final row = find.byKey(ValueKey('model-model-$i'));
          await tester.scrollUntilVisible(
            row,
            100,
            scrollable: find.byType(Scrollable),
          );
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          await tester.tap(row);
        }
        expect(selections, 3);
        final hint = find.text('切换引擎后将在下次通话时生效');
        await tester.scrollUntilVisible(
          hint,
          100,
          scrollable: find.byType(Scrollable),
        );
        await tester.ensureVisible(hint);
        await tester.pumpAndSettle();
        expect(tester.getRect(hint).bottom, lessThanOrEqualTo(sheet.bottom));
        await tester.tap(find.byTooltip('关闭'));
        expect(closes, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
