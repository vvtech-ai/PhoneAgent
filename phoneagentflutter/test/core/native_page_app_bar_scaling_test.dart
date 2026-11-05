import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_page_header.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [0.8, 1.0, 2.0]) {
      testWidgets('$platform AppBar uses actual text scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        tester.view.padding = const FakeViewPadding(top: 30);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(
                padding: const EdgeInsets.only(top: 30),
                textScaler: TextScaler.linear(scale),
              ),
              child: Builder(
                builder: (context) => Scaffold(
                  appBar: NativePageAppBar(
                    title: '会员与积分',
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                  body: const SizedBox.expand(key: ValueKey('body')),
                ),
              ),
            ),
          ),
        );
        final title = tester.getRect(find.text('会员与积分'));
        expect(title.left, 46);
        expect(
          title.height,
          closeTo(
            scale == 0.8
                ? 32
                : scale == 1
                ? 40
                : 80,
            .01,
          ),
        );
        expect(
          tester.getSize(find.byType(NativePageHeader)).height,
          scale <= 1 ? 56 : 96,
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
          scale <= 1 ? 86 : 126,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('wide right operations can be reached without moving title', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    var first = 0, last = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              NativePageHeader(
                title: '标题',
                showBack: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => first++,
                      child: const Text('第一个操作'),
                    ),
                    TextButton(
                      onPressed: () => last++,
                      child: const Text('最后一个操作'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('第一个操作'));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('最后一个操作'));
    expect([first, last], [1, 1]);
    expect(tester.getTopLeft(find.text('标题')).dx, 46);
    expect(tester.takeException(), isNull);
  });
}
