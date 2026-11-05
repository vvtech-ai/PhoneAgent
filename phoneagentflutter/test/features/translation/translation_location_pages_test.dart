import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_location_preview_page.dart';

void main() {
  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TranslationLocationPreviewPage()),
    );
    await press(tester, find.text('打开国家和地区'));
  }

  Future<void> locate(WidgetTester tester) async {
    await press(tester, find.byKey(const Key('dial-location-request')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'location success requires explicit selection; back/reopen uses cache',
    (tester) async {
      await open(tester);
      expect(find.byKey(const Key('dial-location-select')), findsNothing);
      await locate(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('dial-location-select')),
          matching: find.text('美国'),
        ),
        findsOneWidget,
      );
      expect(find.text('选择国家或地区'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('手选区号：CN'), findsOneWidget);
      await press(tester, find.text('打开国家和地区'));
      expect(find.text('上次可信位置'), findsOneWidget);
      await press(tester, find.byKey(const Key('dial-location-select')));
      expect(find.text('手选区号：US'), findsOneWidget);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform trusted location names action and ignores repeat exit',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: const TranslationLocationPreviewPage(),
          ),
        );
        await press(tester, find.text('打开国家和地区'));
        await locate(tester);
        final action = find.bySemanticsLabel('当前位置，美国，+1');
        expect(
          tester.getSemantics(action),
          matchesSemantics(
            label: '当前位置，美国，+1',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        final oldTap = tester
            .widget<InkWell>(find.byKey(const Key('dial-location-select')))
            .onTap!;
        oldTap();
        oldTap();
        await tester.pumpAndSettle();
        expect(find.text('手选区号：US'), findsOneWidget);
        expect(find.text('打开国家和地区'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
  testWidgets(
    'blocked opens only simulated settings and requires explicit reacquisition',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TranslationLocationPreviewPage()),
      );
      await press(tester, find.text('需去设置'));
      await press(tester, find.text('打开国家和地区'));
      await locate(tester);
      expect(find.text('前往设置'), findsOneWidget);
      await press(tester, find.text('前往设置'));
      expect(find.textContaining('返回后，请点击获取'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('合成请求：1；模拟设置：1'), findsOneWidget);
    },
  );
  testWidgets(
    'unsupported country not selectable and search/manual choice still works',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TranslationLocationPreviewPage()),
      );
      await press(tester, find.text('未支持区号（德国）'));
      await press(tester, find.text('打开国家和地区'));
      await locate(tester);
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('dial-location-select')))
            .onTap,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('dial-country-search')),
        'JP',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dial-location-select')), findsOneWidget);
      await press(tester, find.text('日本'));
      expect(find.text('手选区号：JP'), findsOneWidget);
    },
  );
  testWidgets(
    'leaving during location ignores delayed result and never saves',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('dial-location-request')));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await press(tester, find.text('打开国家和地区'));
      expect(find.byKey(const Key('dial-location-select')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets(
      '$width short screen remains scrollable in cache failure state',
      (tester) async {
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const TranslationLocationPreviewPage(),
          ),
        );
        await press(tester, find.text('缓存读取失败'));
        await press(tester, find.text('打开国家和地区'));
        expect(find.text('重试读取缓存'), findsOneWidget);
        await locate(tester);
        await press(tester, find.byKey(const Key('dial-location-select')));
        await tester.scrollUntilVisible(
          find.byKey(const Key('location-preview-selected')),
          -200,
        );
        await tester.pumpAndSettle();
        expect(find.text('手选区号：JP'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
