import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/initialization/domain/initialization_gateway.dart';
import 'package:phone_agent/features/initialization/presentation/widgets/initialization_fields.dart';

const catalog = InitializationCatalog('first', [
  InitializationModel('first', '模型甲', '合成说明', recommended: true),
  InitializationModel('second', '模型乙', '合成说明'),
  InitializationModel('disabled', '不可用', '合成说明', enabled: false),
]);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform model card compact at scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var selected = 'first', writes = 0;
        var busy = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform).copyWith(
              textTheme: ThemeData().textTheme.copyWith(
                bodyMedium: const TextStyle(letterSpacing: 9),
                titleMedium: const TextStyle(letterSpacing: 9),
                labelLarge: const TextStyle(letterSpacing: 9),
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return InitializationModelCards(
                        catalog: catalog,
                        selected: selected,
                        busy: busy,
                        onSelect: (value) => setState(() {
                          selected = value;
                          writes++;
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('init-model-first'));
        final second = find.byKey(const ValueKey('init-model-second'));
        expect(tester.getSize(first).height, closeTo(33 * scale + 35, .01));
        expect(tester.getRect(second).top - tester.getRect(first).bottom, 12);
        final radio = find.byKey(const ValueKey('init-model-radio-first'));
        expect(tester.getSize(radio), const Size(20, 20));
        expect(tester.getRect(first).right - tester.getRect(radio).right, 16);
        expect(
          tester.getRect(find.text('模型甲')).left - tester.getRect(first).left,
          16,
        );
        expect(
          tester.getRect(find.text('模型甲')).top - tester.getRect(first).top,
          15,
        );
        expect(tester.widget<Text>(find.text('模型甲')).style!.letterSpacing, 0);
        expect(
          tester.widget<Text>(find.text('合成说明').first).style!.letterSpacing,
          0,
        );
        await tester.tap(find.byKey(const ValueKey('init-model-radio-second')));
        await tester.pumpAndSettle();
        expect(selected, 'second');
        expect(writes, 1);
        await tester.tap(find.byKey(const ValueKey('init-model-disabled')));
        await tester.pumpAndSettle();
        expect(writes, 1);
        update(() => busy = true);
        await tester.pumpAndSettle();
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('$platform long model labels grow at large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SingleChildScrollView(
                child: InitializationModelCards(
                  catalog: const InitializationCatalog('long', [
                    InitializationModel(
                      'long',
                      '合成长名称模型用于验证自然换行',
                      '合成长描述用于验证内容完整展示与模型选择热区',
                      recommended: true,
                    ),
                  ]),
                  selected: 'long',
                  busy: false,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(
        find.byKey(const ValueKey('init-model-long')),
      );
      expect(card.height, greaterThan(101));
      for (final text in ['合成长名称模型用于验证自然换行', '合成长描述用于验证内容完整展示与模型选择热区']) {
        final box = tester.getRect(find.text(text));
        expect(box.left, greaterThanOrEqualTo(card.left + 16));
        expect(box.right, lessThanOrEqualTo(card.right - 16));
        expect(box.bottom, lessThanOrEqualTo(card.bottom - 15));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
