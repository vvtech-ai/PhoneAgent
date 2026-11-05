import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_page_header.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$platform $width scale $scale symmetric actions', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 820);
          addTearDown(tester.view.reset);
          var backs = 0, actions = 0;
          const title = '这是一个很长很长的完整导航栏标题用于验证单行末尾省略';
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Column(
                    children: [
                      NativePageHeader(
                        title: title,
                        onBack: () => backs++,
                        trailing: TextButton(
                          onPressed: () => actions++,
                          child: const Text('订单与发票'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          final heading = find.text(title);
          final titleRect = tester.getRect(heading);
          expect(titleRect.center.dx, closeTo(width / 2, .01));
          expect(titleRect.left, closeTo(width - titleRect.right, .01));
          expect(
            titleRect.right,
            lessThanOrEqualTo(tester.getTopLeft(find.byType(TextButton)).dx),
          );
          final text = tester.widget<Text>(heading);
          expect(text.maxLines, 1);
          expect(text.overflow, TextOverflow.ellipsis);
          expect(
            tester.renderObject<RenderParagraph>(heading).didExceedMaxLines,
            isTrue,
          );
          expect(tester.getSize(find.byTooltip('返回')), const Size.square(44));
          expect(
            tester.getSize(find.byType(NativePageHeader)).height,
            greaterThanOrEqualTo(64),
          );
          await tester.tap(find.byTooltip('返回'));
          await tester.tap(find.text('订单与发票'));
          expect(backs, 1);
          expect(actions, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'actions change in same layout; absent and disabled back differ',
    (tester) async {
      late StateSetter update;
      var hasBack = false, disabled = false, wide = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Column(
                  children: [
                    NativePageHeader(
                      title: '标题',
                      showBack: hasBack,
                      onBack: disabled ? null : () {},
                      trailing: wide
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.add),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text('右侧操作'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      expect(find.byTooltip('返回'), findsNothing);
      final initial = tester.getRect(find.text('标题'));
      update(() {
        hasBack = true;
        disabled = true;
        wide = true;
      });
      await tester.pump();
      final next = tester.getRect(find.text('标题'));
      expect(next.center.dx, initial.center.dx);
      expect(next.width, lessThan(initial.width));
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byIcon(Icons.keyboard_arrow_left),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AppBar keeps original background and a single system inset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 820);
    tester.view.padding = const FakeViewPadding(top: 30);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          appBarTheme: const AppBarTheme(backgroundColor: Colors.pink),
        ),
        home: const Scaffold(
          appBar: NativePageAppBar(title: '会员与积分'),
          body: SizedBox.expand(key: ValueKey('body')),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('body'))).dy, 94);
    expect(tester.getTopLeft(find.byType(NativePageHeader)).dy, 30);
    expect(find.byTooltip('返回'), findsNothing);
    expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, isNull);
    final material = tester.widget<Material>(
      find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first,
    );
    expect(material.color, Colors.pink);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(appBar: NativePageAppBar(title: '操作中', showBack: true)),
      ),
    );
    expect(
      tester.widget<NativePageHeader>(find.byType(NativePageHeader)).showBack,
      isTrue,
    );
    expect(
      tester.widget<NativePageHeader>(find.byType(NativePageHeader)).onBack,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
